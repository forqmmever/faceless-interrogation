class_name DolDoll
extends RefCounted

# ============================================================
#  小人渲染 —— 照 Degrees of Lewdity 的分层画布
#
#  用户口径：「小人形象和服装也要改成一样」。
#
#  DoL 的小人是 **128×128 的分层画布**：身体与脸是一张彩色底图，
#  每件衣物是一张**灰度遮罩**，运行时按选中的颜色乘上去
#  （Renderer.composeOverCutout：结果 = 颜色 × 蒙版灰度）。
#  图层按 ZIndices 里的 z 值从下往上叠。
#
#  AUfemale 是同一套分层规则的**社区重画包**：画布 512×256，一列全身像
#  （x0..127）+ 一列胸像（x128..255）+ 整块复制（x256..511）。烘的时候只用
#  全身像那一列，裁成 68×203 —— 人物比 DoL 高得多，有完整双腿。
#  （胸像一律不要，见 tools/dol_prepare.py 的 clip_to_body。）
#
#  这一层由 `tools/dol_prepare.py` 在**构建期**做完（取帧 / 染色 / 裁框），
#  产物落在 assets/dol/ 或 assets/dol_au/ 下，运行时只负责按 z 序把 PNG 铺成
#  TextureRect，由 GPU 去叠 —— 不用每帧在 CPU 上合成。
#
#  为什么要烘在构建期：
#    · 染色是逐像素乘法，GDScript 里做一次 128×128 就是几万次循环；
#      而颜色是**固定的**（一件衣服一个色），没必要每帧算。
#    · 取景框也是固定的 —— 所有图层都裁到同一个框，换装时小人才不会跳。
#
#  data/doll*.json 由同一个脚本产出，字段：
#    pack    : "dol" / "au"      这套产物来自哪个图包
#    size    : [宽, 高]          取景框尺寸（dol 41×92，au 68×203）
#    crop    : [x0,y0,x1,y1]     取景框在原精灵图里的位置（仅存档参考）
#    frame   : [宽, 高]          原精灵图的整张画布（dol 128×128，au 512×256）
#    base    : [{name, file, z}] 身体 / 脸 / 头发
#    items   : {物品 id: {layers:[{name,file,z}], z, icon}}
#    slot_z  : {槽位: z}         每个槽位的默认层号
# ============================================================

# ★ 用哪一套美术 —— 改这一个常量就能整包切换：
#     "dol" = Degrees of Lewdity 官方原版（人物矮胖、无腿，取景框 41×92）
#     "au"  = AUfemale 图包（人物更高、有完整双腿，取景框 68×203）
#   两套产物都由 tools/dol_prepare.py 烘出来（--pack dol / --pack au）。
#   界面上凡是要摆小人的地方都走 frame_size()，不要写死数字。
const PACK := "au"
const PACKS := {
	"dol": {"root": "res://assets/dol/", "data": "res://data/doll.json"},
	"au": {"root": "res://assets/dol_au/", "data": "res://data/doll_au.json"},
}
const FALLBACK_SIZE := Vector2(41.0, 92.0)

static var _data: Dictionary = {}
static var _tex_cache: Dictionary = {}

static func pack() -> String:
	return PACK

static func root() -> String:
	return str(PACKS.get(PACK, PACKS["dol"])["root"])

static func data_path() -> String:
	return str(PACKS.get(PACK, PACKS["dol"])["data"])

static func info() -> Dictionary:
	if _data.is_empty():
		var path := data_path()
		if not FileAccess.file_exists(path):
			return {}
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	return _data

# 构建期烘好的贴图。像素画必须**不过滤**放大，所以调用方要把
# TextureRect.texture_filter 设成 NEAREST（见 texture_filter()）。
static func tex(rel: String) -> Texture2D:
	if rel == "":
		return null
	if not _tex_cache.has(rel):
		var path := root() + rel
		_tex_cache[rel] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[rel]

static func icon(id: String) -> Texture2D:
	return tex("icons/" + id + ".png")

static func frame_size() -> Vector2:
	var d := info()
	var s: Array = d.get("size", [])
	if s.size() >= 2:
		return Vector2(float(s[0]), float(s[1]))
	return FALLBACK_SIZE

# 把取景框等比放进一个盒子 —— 预览区 / 卡片缩略图按这个算，
# 换图包时（41×92 → 68×203）不用改任何写死的尺寸。
static func fit_size(box: Vector2) -> Vector2:
	var f := frame_size()
	if f.x <= 0.0 or f.y <= 0.0:
		return box
	var k := minf(box.x / f.x, box.y / f.y)
	return (f * k).floor()

static func slot_z(slot: String) -> float:
	var d := info()
	var zs: Dictionary = d.get("slot_z", {})
	return float(zs.get(slot, 100.0))

# 一件衣物在小人身上占哪几层。发型是唯一跨层的：
# 后面的头发要压在小人**背后**（z 10），侧面与刘海在头前（z 60 / 132）。
static func layers_of(item_id: String) -> Array:
	var d := info()
	var items: Dictionary = d.get("items", {})
	var it: Dictionary = items.get(item_id, {})
	return it.get("layers", [])

# 这一身打扮要铺哪些图，按 z 从下到上排好。
#   equipped = {槽位: 物品 id}（空件、未知件的层数为 0）
#   返回 [{z, file, slot, name}]；slot == "" 的是基础层（身体 / 脸 / 头发以外的底图）
static func plan(equipped: Dictionary) -> Array:
	var d := info()
	var out: Array = []
	for L in d.get("base", []):
		out.append({"z": float(L.get("z", 0.0)), "file": str(L.get("file", "")),
			"slot": "", "name": str(L.get("name", ""))})
	var items: Dictionary = d.get("items", {})
	for slot in equipped.keys():
		var id := str(equipped[slot])
		if id == "":
			continue
		var info2: Dictionary = items.get(id, {})
		for L in info2.get("layers", []):
			out.append({"z": float(L.get("z", 0.0)), "file": str(L.get("file", "")),
				"slot": str(slot), "name": str(L.get("name", ""))})
	out.sort_custom(func(a, b): return float(a["z"]) < float(b["z"]))
	return out

# 把这一身打扮铺成一组 TextureRect（层序即 z 序）挂到 parent 上。
# 返回 {槽位: 第一个 TextureRect} —— 与旧版 layer_rects 的语义一致。
#
#   stage_size = 显示区尺寸；所有层都用同一个 stage_size + KEEP_ASPECT_CENTERED，
#   而它们的取景框本来就是一个，所以天然对齐。
static func stack_into(parent: Control, equipped: Dictionary, stage_size: Vector2) -> Dictionary:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var slot_rects: Dictionary = {}
	for L in plan(equipped):
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素画不糊
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture = tex(str(L["file"]))
		parent.add_child(tr)
		var slot := str(L["slot"])
		if slot != "" and not slot_rects.has(slot):
			slot_rects[slot] = tr
	return slot_rects
