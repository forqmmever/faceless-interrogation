extends Node

# ============================================================
#  局内进度存档 —— 支撑开始界面上的「继续游戏」
#
#  与 ProfileData 的分工（两者都在 user:// 下，互不干扰）：
#    · ProfileData = **账号级元进度**：跨局累积的接受度、战绩。
#                    它永远不清零 —— 整局失败也不退还。
#    · RunSave     = **一局之内的进度**：打到第几关、那身打扮、手机里的进度。
#                    它只保留「最近一次停下的地方」，专门用来续玩。
#
#  为什么只存一个种子就够还原：
#    一局的背景、A 的原貌、外貌情报、相册、审讯官性情，全部由 seed_value
#    确定性生成（见 RunData.start_new_run / _level_rng）。所以存档只要记住
#    种子，重放一遍就一模一样。真正需要额外记的只有三样：
#      · 打到第几关（level_index / cleared_levels）
#      · 玩家自己换的那身衣服（equipped）
#      · 手机与情报的进度（读了哪几条短信、擦了哪几张照片、立过什么口径）
#
#  什么时候写：
#    每进一关的准备室写一次，玩家每改一次打扮再写一次。
#    这样**直接关掉窗口也不会丢** —— 不需要去拦退出事件。
#
#  什么时候清：
#    整局通关（4/4）就清掉 —— 「继续游戏」只在局内成立。
#    ★ **失败不清**（第二十一轮）：失败只作废本轮，玩家会回到本关准备室重来，
#      这一局还在进行中，存档当然要留着。
#
#  测试注意：
#    与 ProfileData 同理，测试开头要
#        RunSave.autosave_enabled = false
#        RunSave.clear()
#    否则断言会随这台机器上玩过什么而变。
# ============================================================

const SAVE_PATH := "user://runsave.json"
const SAVE_VERSION := 1

# ---------- 存档内容 ----------
var has_run: bool = false
var run_index: int = 0
var seed_value: int = 0
var level_index: int = 0
var cleared_levels: int = 0
var background_name: String = ""
var equipped: Dictionary = {}          # slot -> item id
var game: Dictionary = {}              # GameData 里与「本局」有关的那几个字段

# ---------- 运行时开关 ----------
var autosave_enabled: bool = true
var loaded: bool = false

func _ready() -> void:
	load_save()

# ============================================================
#  写
# ============================================================
# outfit 留空时沿用上一次记下的那身衣服（例如「进入盘问」那一刻只想刷新进度）
func save_progress(outfit: Dictionary = {}) -> void:
	if not autosave_enabled:
		return
	if RunData.seed_value == 0:
		return
	run_index = RunData.run_index
	seed_value = RunData.seed_value
	level_index = RunData.level_index
	cleared_levels = RunData.cleared_levels
	background_name = RunData.background_name()
	if not outfit.is_empty():
		equipped = outfit.duplicate()
	has_run = true
	_write()

func _write() -> void:
	var d := {
		"version": SAVE_VERSION,
		"has_run": has_run,
		"run_index": run_index,
		"seed_value": seed_value,
		"level_index": level_index,
		"cleared_levels": cleared_levels,
		"background_name": background_name,
		"equipped": equipped,
		"game": _capture_game(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("runsave.json 写不进去（user:// 不可写？）")
		return
	f.store_string(JSON.stringify(d, "\t", false))
	f.close()

func _capture_game() -> Dictionary:
	return {
		"sms_read": GameData.sms_read.duplicate(),
		"known_facts": GameData.known_facts.duplicate(),
		"photo_wipes": GameData.photo_wipes.duplicate(),
		"photos_revealed": GameData.photos_revealed.duplicate(),
		"interrogator_sms": GameData.interrogator_sms.duplicate(),
		"stated_facts": GameData.stated_facts.duplicate(),
		"contradictions": GameData.contradictions,
		"improvised": GameData.improvised,
		"plants": GameData.plants,
		"companion_asked": GameData.companion_asked,
		"interrogator_intel_read": GameData.interrogator_intel_read,
	}

# ============================================================
#  读
# ============================================================
func load_save() -> void:
	loaded = true
	has_run = false
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("runsave.json 打不开，按无存档处理")
		return
	var txt := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("runsave.json 解析失败，按无存档处理")
		return
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		return

	run_index = maxi(0, int(d.get("run_index", 0)))
	seed_value = int(d.get("seed_value", 0))
	level_index = maxi(0, int(d.get("level_index", 0)))
	cleared_levels = maxi(0, int(d.get("cleared_levels", 0)))
	background_name = str(d.get("background_name", ""))
	var eq: Variant = d.get("equipped", {})
	equipped = eq.duplicate() if typeof(eq) == TYPE_DICTIONARY else {}
	var g: Variant = d.get("game", {})
	game = g.duplicate() if typeof(g) == TYPE_DICTIONARY else {}

	has_run = bool(d.get("has_run", false)) and seed_value != 0
	# 关卡越界（存档被改坏 / 版本对不上）→ 当没有存档，别把玩家丢进一个不存在的关卡
	if level_index >= OutfitData.level_count():
		has_run = false

# 把存档里的「本局进度」灌回 GameData。
# 注意调用顺序：必须在 RunData.resume_run() 与 Wardrobe.start_run() 之后 ——
# 那两个都会 reset 一遍 GameData，先灌后 reset 就白灌了。
func apply_to_gamedata() -> void:
	if game.is_empty():
		return
	GameData.sms_read = _as_array(game.get("sms_read", []))
	GameData.known_facts = _as_dict(game.get("known_facts", {}))
	GameData.photo_wipes = _as_int_keyed(game.get("photo_wipes", {}))
	GameData.photos_revealed = _as_int_array(game.get("photos_revealed", []))
	GameData.interrogator_sms = _as_array(game.get("interrogator_sms", []))
	GameData.stated_facts = _as_dict(game.get("stated_facts", {}))
	GameData.contradictions = int(game.get("contradictions", 0))
	GameData.improvised = int(game.get("improvised", 0))
	GameData.plants = int(game.get("plants", 0))
	GameData.companion_asked = int(game.get("companion_asked", 0))
	GameData.interrogator_intel_read = bool(game.get("interrogator_intel_read", false))

# ============================================================
#  清
# ============================================================
# 整局通关 → 没有「进行中的一局」可以续了
# （失败**不**走这里 —— 失败只作废本轮，这一局还在进行中）
func clear() -> void:
	has_run = false
	run_index = 0
	seed_value = 0
	level_index = 0
	cleared_levels = 0
	background_name = ""
	equipped = {}
	game = {}
	if not autosave_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("{}")
	f.close()

# ============================================================
#  查询（给开始界面用）
# ============================================================
func summary() -> String:
	if not has_run:
		return "还没有进行中的一局 —— 从「开始游戏」起一局新的。"
	var bg := background_name
	if bg == "":
		bg = "（背景未知）"
	return "第 %d 局 ｜ %s ｜ 停在第 %d / %d 关的准备室" % [
		run_index, bg, level_index + 1, OutfitData.level_count()]

# ============================================================
#  类型兜底：JSON 往返会把 int 键变成字符串、Array 变成 Array[Variant]
# ============================================================
func _as_array(v: Variant) -> Array:
	return (v as Array).duplicate() if typeof(v) == TYPE_ARRAY else []

func _as_dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate() if typeof(v) == TYPE_DICTIONARY else {}

func _as_int_keyed(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = v
	for k in src.keys():
		out[int(str(k))] = int(src[k])
	return out

func _as_int_array(v: Variant) -> Array:
	var out := []
	if typeof(v) != TYPE_ARRAY:
		return out
	for x in (v as Array):
		out.append(int(x))
	return out
