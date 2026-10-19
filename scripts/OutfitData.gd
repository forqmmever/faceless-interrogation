extends Node

# ============================================================
#  服装数据库 + 换装规则
#
#  槽位体系移植自 WTS 的 Doll.clothing_layers（18 个槽位），
#  按 zorder 从内到外排列；本项目额外加入 shoes（WTS 无鞋履槽）。
#
#  三值机制（原创，WTS 无此设计）：
#    - 暴露值 (exposure)      : 每件衣服一个数值，总和有上限
#    - 接受度 (acceptance)    : 每轮后提升，决定能否装备高门槛物品
#    - 反差值 (contrast)      : 与「推导形象」的差距，决定质问环节是否被直接识破
# ============================================================

# ---------- 槽位 ----------
# UI 显示顺序（自上而下，符合穿衣直觉）
# ★ 第二十六轮新增 `dress`（整件式）——
#   用户口径：「如果是一整件衣服 如晚礼服 不能分开成下装和上装 应该单开一个栏目」。
#   它排在 bottom 后面：上身 → 下装 → 整件式，一层层往外。
# ★ 第二十七轮改名为「成装」，并按用户口径「装备时应和上装和下装互斥」加了互斥
#   （见 EXCLUSIVE_GROUPS —— 成装 / 上装 / 下装三者只能穿其一）。
#
# ★★ 第三十七轮：**槽位从 19 个减到 18 个** —— 按用户口径「吊带袜和袜类归为一类」，
#   原来的 `garterbelt`（吊袜带，3 件）整个并入 `stockings`（袜类）。
#   这不是「下架」而是**真合并**：`garterbelt` 这个槽位定义、zorder、TRUE_POOL、
#   目击情报模板、相册取景框全部删掉，两件吊袜带（蕾丝 / 黑色皮革）改挂到
#   `stockings` 底下；`garter_none`（吊袜带的空件）直接删除 ——
#   袜类本来就有自己的空件 `stockings_none`，留着就是两个「（不穿）」。
#   合并后 `stockings` 一栏共 9 件（7 件袜 + 2 件吊袜带）。
const SLOT_ORDER := [
	"hair", "headgear", "glasses", "earrings", "makeup",
	"piercing", "tattoo", "neckwear", "top", "bra",
	"gloves", "accessory", "bottom", "dress", "panties",
	"stockings", "shoes", "robe", "tool",
]

# 图层绘制顺序（底 → 顶），严格对应 WTS 的 zorder 编号
const PREVIEW_ORDER := [
	"makeup", "accessory", "piercing", "tattoo",
	"stockings", "panties", "bottom", "tool",
	"bra", "top", "dress", "gloves", "shoes",
	"robe", "neckwear", "hair", "earrings",
	"glasses", "headgear",
]

# WTS 的 zorder 原值，保留用于对齐参考
const SLOT_ZORDER := {
	"makeup": 111, "accessory": 121, "piercing": 131, "tattoo": 141,
	"stockings": 161, "panties": 171, "bottom": 191,
	"bra": 201, "top": 211, "dress": 216, "gloves": 221, "shoes": 225,
	"robe": 231, "neckwear": 241, "hair": 251, "earrings": 261,
	"glasses": 271, "headgear": 281,
	# ★ 第三十九轮自创槽位（WTS 没有这一栏）：值取「bottom 191 之上、top 211 之下」——
	#   挂在身后的尾巴从腰后翘出来，压在下装之上、上装之下。
	#   ★ 这只是对齐参考表；真正决定渲染层序的是 data/doll_au.json 里的 z
	#     （由 tools/dol_map.py 的 SLOT_Z 烘出来）。
	"tool": 196,
}

const SLOT_NAMES := {
	"hair": "发型",
	"headgear": "头饰",
	"glasses": "眼镜",
	"earrings": "耳饰",
	"makeup": "妆容",
	"piercing": "穿环",
	"tattoo": "纹身",
	"neckwear": "颈饰",
	"top": "上衣",
	"bra": "上内衣",
	"gloves": "手套",
	"accessory": "配饰",
	"bottom": "下装",
	"dress": "成装",
	"panties": "下内衣",
	"stockings": "袜类",
	"shoes": "鞋履",
	"robe": "外袍",
	"tool": "妙妙工具",
}

# ---------- 暂时下架的槽位 ----------
# 外袍（robe）的贴图还没跟上 AU 人物，先整体下架：
#   · 换装界面不再出现这一区（分区标题、卡片、当前装备都不画）
#   · A 的原貌不再抽外袍，情报台也不再问这一处（情报条数随之少一条）
#   · 强制装备池里不会出现外袍
# 槽位定义、4 件物品、贴图**全部保留** —— 以后把 "robe" 从这张表里删掉即可恢复。
#
# ★ 第二十五轮：耳饰（earrings）按用户口径「去掉耳饰这一栏」一并下架。
#   走的是同一套机制，所以换装界面 / 原貌 / 情报 / 相册 / 强制池都会自动跳过它；
#   4 件物品与贴图同样一件没删，把 "earrings" 从表里删掉即可恢复。
#
# ★ 第二十七轮：手套（gloves）与头饰（headgear）按用户口径「手套一栏去掉」「头饰一栏去掉」
#   一并下架。同样只是槽位级下架 —— 4 件手套与 4 件头饰的定义、贴图、目击描述一件没删，
#   把 "gloves" / "headgear" 从这张表里删掉即可原样恢复。
#
# ★ 第三十七轮：穿环（piercing）按用户口径「去掉穿环一栏」一并下架。
#   和前几轮同一套机制 —— 4 件穿环（多孔耳钉组 / 黑色唇环 / 鼻中隔银环 / 空件）的
#   定义、贴图、目击描述一件没删，把 "piercing" 从这张表里删掉即可原样恢复。
#   ★ 注意：穿环的贴图本来就是**借头部小件**顶替的（DoL 没有这个槽位），
#     所以下架它不会连带影响任何别的槽位的贴图。
# ★ 第五十一轮：配饰（accessory）与妙妙工具（tool）按用户口径一并下架。
#   · 「去掉配饰一栏」—— 该栏原有的 5 件（束腰皮带 + 4 件项圈）**一件没删**，
#     走的就是这一套槽位级下架；栏里的 `acc_locket`（银质心形吊坠）**没随栏消失**，
#     它按用户另一句口径挪到「颈饰」去了（见上面 neckwear 那一节）。
#   · 「妙妙工具暂时去掉」—— 注意是**暂时**，所以更加要用下架而不是删除：
#     两件物品（空件 + 尼古喵尾）的定义、贴图、目击描述全部保留，
#     把 "tool" 从这张表里删掉即可原样恢复。
#     ★ 连带效果：尼古喵尾那套「带着就不涨怀疑值」的机制**在代码里照旧存在**
#       （`Interrogation._add_suspicion` 读 `GameData.carried_tool()`），
#       但槽位下架后玩家装不上它，于是 `carried_tools` 恒为空 —— 机制实际不可达。
#       这正是「暂时去掉」该有的样子：恢复只需删一个字符串，不用碰任何逻辑。
const DISABLED_SLOTS := ["robe", "earrings", "gloves", "headgear", "piercing", "accessory", "tool"]

# 玩家能看到的槽位（SLOT_ORDER 去掉下架的）。
# ★ 界面 / 原貌 / 情报 / 统计一律用它；SLOT_ORDER 只在需要完整数据表时用。
static func active_slots() -> Array:
	var out := []
	for s in SLOT_ORDER:
		if not DISABLED_SLOTS.has(s):
			out.append(s)
	return out

static func slot_enabled(slot: String) -> bool:
	return not DISABLED_SLOTS.has(slot)

# ---------- 只能手动装备的槽位（第三十九轮）----------
# 用户口径：「此栏专门为减少换装环节难度的设置的，只能手动装备，
#            调试计算反差值时请不要使用」。
#
# 现在的成员只有 `tool`（妙妙工具）。它和 DISABLED_SLOTS 是**两件不同的事**：
#   · DISABLED_SLOTS —— 玩家**看不到**这一栏（界面 / 原貌 / 情报 / 相册全跳过）
#   · MANUAL_SLOTS   —— 玩家**看得到、点得到**，但**任何自动流程都不碰它**：
#       · 原貌（RunData._roll_true_appearance）不抽 → 情报台不问、相册不拍
#       · 强制装备池（forced_pool）不抽
#       · 一键达标（WardrobeModel.auto_complete_outfit 的 DP）不用它凑数
#       · 「与原貌一致 / 已改掉 / 相似度」这些**统计**也不算它
#         → 所以它**不影响反差值与任何数值判定的口径**
#   换句话说：它是一件玩家自己决定要不要揣上的道具，系统从不代劳。
#
# ★ 为什么单开一张表而不是塞进 DISABLED_SLOTS：
#   下架会让整个槽位从换装界面消失，而用户要的恰恰是「界面上能看见、能点」。
#
# ★ 第五十一轮：「妙妙工具暂时去掉」把这个槽位放进了 DISABLED_SLOTS。
#   两边同时写着 `tool` 并不矛盾 —— `auto_slots()` 是「active_slots() 去掉 MANUAL_SLOTS」，
#   tool 在 active_slots() 那一步就已被滤掉，MANUAL_SLOTS 里这条成了空转。
#   **保留它**是为了「恢复只需删 DISABLED_SLOTS 里那一个字符串」，
#   不用同时想起这里还有一条要加回去。
const MANUAL_SLOTS := ["tool"]

static func is_manual_slot(slot: String) -> bool:
	return MANUAL_SLOTS.has(slot)

# 参与「自动抽取 / 数值统计」的槽位 = 玩家可见的那批去掉「只能手动」的。
# ★ 原貌 / 情报 / 相册 / 强制池 / 一键达标 / 一致数统计一律用它；
#   换装界面继续用 active_slots()（要能看见妙妙工具那一栏）。
static func auto_slots() -> Array:
	var out := []
	for s in active_slots():
		if not MANUAL_SLOTS.has(s):
			out.append(s)
	return out

# ---------- 可同时装备多件的槽位（第三十六轮）----------
# 用户口径：「可装备的纹身上限设为 2」。
#
# 值 = 这一槽位**同时**能装备几件。没写在这张表里的槽位一律 1 件。
# 只有 `tattoo` 是多件槽位 —— 一个人身上本来就能有不止一处纹身。
#
# ★ 多件槽位在模型层（WardrobeModel.equipped）里存的是 **Array**，
#   单件槽位存的是 **String**；读写一律走 WardrobeModel 的 ids_at / set_ids，
#   不要直接 `str(equipped.get(slot, ""))`。
const MULTI_SLOTS := {"tattoo": 2}

# 这一槽位最多同时装备几件
static func max_equip(slot: String) -> int:
	return int(MULTI_SLOTS.get(slot, 1))

# 这一槽位是不是「可同时装备多件」的
static func is_multi_slot(slot: String) -> bool:
	return MULTI_SLOTS.has(slot)

# ---------- 内衣内裤的「曝光门控」（第二十二轮）----------
# 用户口径：「内裤内衣的反差值和暴露值只有在**能够显示在人物身上**时才会计算，
#            如透明外衣能计算、直接外穿能计算、镂空开档能计算」
#
# 也就是说判定的不是「穿没穿外衣」，而是**这件内衣到底看不看得见**：
#   ① 透明外衣   —— 半透 / 薄纱 / 蕾丝，能透过去看见        → "sheer"
#   ② 镂空开档   —— 开衩 / 超短 / 露腰，从开口处直接看见    → "cutout"
#   ③ 直接外穿   —— 同侧外衣干脆没穿，内衣就是最外层        → 见 is_bare()
# 三条路都不成立（盖得严严实实），这件内衣就既不算暴露值、也不算反差值。
#
# ★ 值是「谁能把这件内衣露出来」——按**从内到外**排（判定时从后往前找最外层）：
#   上半身有三层（上衣 / 连衣裙 / 外袍），所以 bra 有三个开门人；
#   下半身两层（下装 / 连衣裙）。
#   ★ 第二十六轮加了 `dress`：连衣裙是一整件，上半截盖住 bra、下半截盖住 panties，
#     所以两边的开门人表里都要有它，否则穿着连衣裙时内衣会被当成「直接外穿」，
#     白白算进暴露值与反差值。
#   外袍目前下架（DISABLED_SLOTS），写在这里是为了将来恢复时不用再动判定逻辑
#   （外袍没穿时 item_at("robe") 是空字典，is_bare 自然为 true）。
const UNDER_GATE := {
	"bra": ["top", "dress", "robe"],
	"panties": ["bottom", "dress"],
}

# ---------- 互斥槽位（第二十七轮）----------
# 用户口径：「连衣裙那一栏改名为，成装并且装备时应和上装和下装互斥」。
#
# ★ 每一条是一条**二分互斥**：`[[左边一组], [右边一组]]` ——
#   左边任一槽位穿了实体衣物，右边那一组就全部脱下，反之亦然。
#   **同一组内部不互斥**（上装与下装本来就要一起穿）。
#
# 为什么不是「组内只能有一个」：`dress` / `top` / `bottom` 三者放一个组里做「只留一个」，
# 会把「上衣 + 下装」这套**完全正常**的搭配也拆掉（第二轮实测：开局原貌的上装下装
# 被归零，反差值不再是 0、一键达标求解器整片挂掉）。三者里真正的互斥关系只有
# 「成装 ↔ 上装 / 下装」这一对。
#
# ★ 成装（dress）本来就是「一整件」，它的上半截等于上装、下半截等于下装 ——
#   要么穿成装，要么穿「上装 + 下装」，二者取其一才是自洽的搭配。
const EXCLUSIVE_GROUPS := [
	[["dress"], ["top", "bottom"]],
]

static var _excl_peer_cache: Dictionary = {}

# 与这一槽位互斥的槽位（**对面那一组**；同组内部不互斥）。不在任何互斥关系里就返回空数组。
#
# ★ 带缓存：`_counts_with` 是热路径（DP / 贪心 / 界面每次刷新都要问上百遍），
#   每次都新建数组会把整个流程拖慢一倍以上（实测 WardrobeTest 从 1m30s 涨到 3m20s）。
static func exclusive_peers(slot: String) -> Array:
	if _excl_peer_cache.has(slot):
		return _excl_peer_cache[slot]
	var out := []
	for g in EXCLUSIVE_GROUPS:
		var pair := g as Array
		var left := pair[0] as Array
		var right := pair[1] as Array
		if left.has(slot):
			for s in right:
				out.append(str(s))
			break
		if right.has(slot):
			for s in left:
				out.append(str(s))
			break
	_excl_peer_cache[slot] = out
	return out

# 这一槽位的「空件」id（「（不穿上衣）」这类）。找不到就返回 ""。
# 空件由 ITEMS 里的 "bare": true 标注。
static func bare_id_of(slot: String) -> String:
	for it in ITEMS:
		if str(it.get("slot", "")) != slot:
			continue
		if bool(it.get("bare", false)):
			return str(it["id"])
	return ""

# 外衣能透出内衣的两种方式（写在 ITEMS 的 "see" 字段上）
const SEE_SHEER := "sheer"      # 透明 / 半透
const SEE_CUTOUT := "cutout"    # 镂空 / 开档 / 超短

# 这一件外衣怎么把里面的内衣露出来 —— 返回 "" 表示露不出来。
# **逐件显式标注**：只有 ITEMS 里带 "see" 的那几件算。
static func see_through_kind(item: Dictionary) -> String:
	return str(item.get("see", ""))

# 这一件外衣够不够「露」—— 会不会把里面的内衣内裤露出来
static func is_sheer(item: Dictionary) -> bool:
	return see_through_kind(item) != ""

# 这一件是不是「（不穿）」那一类空件 —— 穿上它等于这一层没有东西，
# 里面的内衣就是**最外层**（用户口径里的「直接外穿」）。
# 同样逐件显式标注（ITEMS 里的 "bare": true）。
static func is_bare(item: Dictionary) -> bool:
	return bool(item.get("bare", false))

# 这一槽位是不是受门控的内衣 / 内裤
static func is_gated_slot(slot: String) -> bool:
	return UNDER_GATE.has(slot)

# 能把这一槽位露出来的外衣槽位（不受门控的槽位返回空数组）
static func outer_slots_of(slot: String) -> Array:
	return UNDER_GATE.get(slot, [])

# 受门控的全部槽位
static func gated_slots() -> Array:
	return UNDER_GATE.keys()

# ---------- 纹身的「露出门控」（第三十六轮）----------
# 用户口径：「纹身与内衣内裤处理方法相同，不漏出来时，不计算暴露值反差度。」
#
# 与内衣内裤**同一条门控**（见 UNDER_GATE 与 WardrobeModel._item_counts），
# 唯一区别是纹身**按件**给开门人 —— 因为纹身长在不同部位，能盖住它的衣服不一样：
#   · 左 / 右大腿 → 下装、成装
#   · 下腹       → 下装、成装
#   · 胸口       → 上装、成装
#   · 颈侧       → 上装、成装、颈饰
#   · 面颊 / 额头 → 没有衣服盖得住，永远露着（不给 gate，恒计入）
#
# 没写 `gate` 的纹身 = 不受门控（面颊 / 额头那类）；
# 内衣内裤没写 `gate` → 退回槽位级门控 UNDER_GATE。
# 空数组常量 —— 给下面几个热路径函数当默认值。
# ★ 不要写成 `item.get("gate", [])`：那个 `[]` 每次调用都会新分配一个数组，
#   而这些函数在 DP 里一次要问几千万遍（实测 WardrobeTest 会从 3m39s 掉回 2m 以内）。
const NO_SLOTS: Array = []

static func outer_slots_of_item(item: Dictionary) -> Array:
	var g: Variant = item.get("gate")
	if g != null and not (g as Array).is_empty():
		return g
	return UNDER_GATE.get(str(item.get("slot", "")), NO_SLOTS)

# 这一件是不是受「露出门控」的（露不出来就不算数值）
static func is_gated_item(item: Dictionary) -> bool:
	return not outer_slots_of_item(item).is_empty()

static var _gate_dep_cache: Dictionary = {}

# 换掉 `slot` 这一层的衣服，会让哪些槽位的可见性跟着变 ——
# 含按件门控的纹身（见 outer_slots_of_item）。
# ★ `WardrobeModel._delta` 是热路径（求解器要问几万遍），所以带缓存。
func gate_dependents(slot: String) -> Array:
	if _gate_dep_cache.has(slot):
		return _gate_dep_cache[slot]
	var out := []
	# ★ 第三十九轮：扫 auto_slots() 而不是 active_slots() —— 妙妙工具的两件都没有
	#   `gate`，扫它纯属浪费（这是求解器的热路径）。
	for gs in auto_slots():
		var s := str(gs)
		var hit := false
		for it in get_items_for_slot(s):
			if outer_slots_of_item(it).has(slot):
				hit = true
				break
		if hit:
			out.append(s)
	_gate_dep_cache[slot] = out
	return out

# 够「露」的全部外衣（含下架的）—— 界面文案 / 测试用
static func sheer_items() -> Array:
	var out := []
	for it in ITEMS:
		if is_sheer(it):
			out.append(it)
	return out

# 够「露」、而且玩家看得见的那些
static func sheer_items_visible() -> Array:
	var out := []
	for it in sheer_items():
		if slot_enabled(str(it.get("slot", ""))):
			out.append(it)
	return out

# 反差值方向开关：
#   true  = 反差值越高越安全（与推导形象差距越大，越难被识别）
#   false = 反差值越低越安全（越贴合推导形象，越不容易引起注意）
const CONTRAST_HIGHER_IS_SAFER := true

# 暴露值上限公式：上限 = EXPOSURE_BASE + 接受度 * EXPOSURE_PER_ACCEPTANCE
# 槽位由 8 个扩到 18 个后，基础衣物本身就会占掉若干暴露值，故基数上调
const EXPOSURE_BASE := 10
const EXPOSURE_PER_ACCEPTANCE := 2

# ---------- 身体缺陷 ----------
# 每项缺陷有：部位、是否已被遮挡、需要哪些衣物标签才能遮住
# 注意：刻意不设"必须穿外袍"的缺陷，否则斗篷会挡住整套搭配，换装失去意义
#
# ★ 第二十三轮：这张表也外置了（story.json 的 "defects" 段，编辑器可增删改）。
#   `slot_hint` 是写给玩家看的位置提示（「手套 / 长袖」这种），
#   `cover_tags` 是判定用的标签 —— 只要身上有**任意一个**这些标签就算遮住。
#   标签本身来自 ITEMS 里每件衣服的 "tags"（见下），所以改标签要两处一起动。
const DEFAULT_DEFECTS := [
	{"id": "hand_tattoo", "name": "右手背黑帮血蛇刺青", "slot_hint": "手套 / 长袖", "cover_tags": ["glove", "long_sleeve"]},
	{"id": "neck_brand", "name": "颈侧奴隶烙印", "slot_hint": "颈饰 / 高领", "cover_tags": ["high_collar", "scarf"]},
]

# 运行时表（惰性从 story.json 读；出厂兜底 = DEFAULT_DEFECTS）
var DEFECTS: Array = []

func _ensure_defects() -> void:
	if not DEFECTS.is_empty():
		return
	# ★★ 第八十三轮（用户口径）：「情景一根本没有设置身体缺陷」——
	#   以前这里一律用 `DEFAULT_DEFECTS` 兜底：作者写了个空数组（= 这套没有缺陷），
	#   代码却给他补上出厂那 2 项，于是**编辑器里是空的、游戏里却真的要求遮刺青**。
	#
	# ★★ 第八十三轮（续 2）：**全局 defects 那一层也拆掉了**。
	#   全局那页（编辑器「流程」四页之一）已删，数据段也删了 —— 留一份「没有入口、
	#   却会在背景没写时生效」的数据，就是隐形脏数据。现在只有两级：
	#     ① 这套背景写过 defects（哪怕是 `[]`）→ 用它，**空就是没有**；
	#     ② 没有当前背景 / 这套没写 → 出厂 DEFAULT_DEFECTS（纯代码兜底，
	#        只在「压根没有 story.json」这种演示场景里才会出现）。
	var src: Array = _bg_defects if _bg_defects_declared else DEFAULT_DEFECTS
	DEFECTS = []
	for d in src:
		var dd: Dictionary = (d as Dictionary).duplicate()
		var did := str(dd.get("id", ""))
		if did == "":
			continue
		if str(dd.get("name", "")) == "":
			dd["name"] = did
		if typeof(dd.get("cover_tags", null)) != TYPE_ARRAY:
			dd["cover_tags"] = []
		if str(dd.get("slot_hint", "")) == "":
			dd["slot_hint"] = ""
		DEFECTS.append(dd)
	if DEFECTS.is_empty() and not _bg_defects_declared:
		# 没写过 defects（整段缺失）+ 每一项都写坏了 → 退回出厂，
		# 不能让「缺陷遮挡」整个失效。
		# ★ 作者**写过空数组**时不走这里 —— 那代表「这套就是没有缺陷」。
		for d in DEFAULT_DEFECTS:
			DEFECTS.append((d as Dictionary).duplicate())

func reload_defects() -> void:
	DEFECTS = []
	_ensure_defects()

# 玩家能看到的缺陷（下架槽位不参与 —— 目前没有槽位级缺陷，留着做扩展位）
func defects() -> Array:
	_ensure_defects()
	return DEFECTS

# ---------- 服装库（102 件）----------
# exposure      : 暴露值
# acceptance_req: 装备所需接受度
# contrast      : 反差值
# covers        : 可遮挡的缺陷 id 列表
# tags          : 用于判定遮挡是否成立的标签
# see           : ★ 第二十二轮 —— 这件外衣**怎么把里面的内衣内裤露出来**
#                 （见 UNDER_GATE / see_through_kind）：
#                   "sheer"  = 透明 / 半透（薄纱、蕾丝），透过去就能看见
#                   "cutout" = 镂空 / 开档 / 超短，从开口处直接看见
#                 不标 = 盖得严实，穿在它底下的内衣既不算暴露值也不算反差值。
# bare          : ★ 「（不穿）」那一类空件 —— 穿上它等于这一层没有东西，
#                 里面的内衣就是最外层（用户口径里的「直接外穿」），照算。
# ★ 第三十九轮改：`const ITEMS` → `static var ITEMS`。
#   为什么必须改：新增了「服装数值可从 data/story.json 覆写」这条通路
#   （见 apply_item_overrides），而 `const` 是编译期只读、运行时改不了。
#   选 `static var` 而不是普通 `var` 的原因：本文件里有 15 处 **static func**
#   在读 ITEMS，静态上下文访问不到实例成员。`static var` 两边都能用，
#   而且全项目原有的 `OutfitData.ITEMS` 写法**一行都不用改**。
#   ⚠ 覆写是**原地改这一张表**（不是换一张新的），所以只有在第一次读之前
#     调过 `_ensure_items()` 的地方才看得到新值 —— 见该函数的说明。
const ITEMS_BASE := [
	# ================= 发型（无「不戴」选项，始终有头发）=================
	{"id": "hair_short", "name": "利落短发", "slot": "hair", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "hair_braid", "name": "侧编辫", "slot": "hair", "exposure": 0, "acceptance_req": 1, "contrast": 1, "covers": [], "tags": []},
	{"id": "hair_long", "name": "垂肩长发", "slot": "hair", "exposure": 0, "acceptance_req": 2, "contrast": 1, "covers": [], "tags": []},
	{"id": "hair_up", "name": "高盘发髻", "slot": "hair", "exposure": 0, "acceptance_req": 5, "contrast": 3, "covers": [], "tags": []},
	# ★ 第四十六轮：按用户挑的三款补进来（AU 清点表里都是 A 档）。
	#   头发不吃暴露值（exposure 恒 0），所以这三件的作用是把**接受度门槛与反差值**
	#   的梯度铺开 —— 原来只有 0 / 1 / 2 / 5 四档，补完是 0 / 1 / 2 / 4 / 5 / 6 / 8 七档。
	{"id": "hair_pigtails", "name": "双马尾", "slot": "hair", "exposure": 0, "acceptance_req": 4, "contrast": 2, "covers": [], "tags": []},
	{"id": "hair_half_twin", "name": "半扎双马尾", "slot": "hair", "exposure": 0, "acceptance_req": 6, "contrast": 4, "covers": [], "tags": []},
	{"id": "hair_wave", "name": "公主大波浪", "slot": "hair", "exposure": 0, "acceptance_req": 8, "contrast": 5, "covers": [], "tags": []},

	# ================= 头饰 =================
	{"id": "head_none", "name": "（不戴）", "slot": "headgear", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "head_hat", "name": "宽檐旅行帽", "slot": "headgear", "exposure": 0, "acceptance_req": 0, "contrast": 2, "covers": [], "tags": []},
	{"id": "head_hood", "name": "深色兜帽", "slot": "headgear", "exposure": 0, "acceptance_req": 3, "contrast": 4, "covers": [], "tags": []},
	{"id": "head_veil", "name": "半面黑纱（遮面但极惹眼）", "slot": "headgear", "exposure": 1, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": []},

	# ================= 眼镜 =================
	{"id": "glasses_none", "name": "（不戴）", "slot": "glasses", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	# ★ 第二十七轮换血：删掉「单片金链眼镜」与「黑色墨镜」，从 AU 图包补两副新框
	#   （`cateye` 猫眼 / `square` 方框 —— 都是 512×256 的 AU 几何、纯灰度可染色）。
	#   用户口径：「单片金链眼睛和黑色墨镜去掉增加两副眼镜，两副眼镜已经现在的圆框眼镜
	#             反差值设定均设定为3」→ 三副眼镜的反差值统一 = 3。
	#   三副的门槛拉开一档，保留一点「越惹眼越难穿」的梯度（戴不戴都不影响可解性，
	#   因为 `glasses_none` 始终是 0 门槛）。
	{"id": "glasses_round", "name": "圆框眼镜", "slot": "glasses", "exposure": 0, "acceptance_req": 0, "contrast": 3, "covers": [], "tags": []},
	{"id": "glasses_square", "name": "方框眼镜", "slot": "glasses", "exposure": 0, "acceptance_req": 5, "contrast": 3, "covers": [], "tags": []},

	# ================= 耳饰 =================
	{"id": "ear_none", "name": "（不戴）", "slot": "earrings", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "ear_stud", "name": "素银耳钉", "slot": "earrings", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "ear_hoop", "name": "大圆环耳饰", "slot": "earrings", "exposure": 1, "acceptance_req": 4, "contrast": 3, "covers": [], "tags": []},
	{"id": "ear_diamond", "name": "钻石吊坠耳饰", "slot": "earrings", "exposure": 1, "acceptance_req": 8, "contrast": 5, "covers": [], "tags": []},

	# ================= 妆容 =================
	{"id": "makeup_none", "name": "（素颜）", "slot": "makeup", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "makeup_light", "name": "淡妆", "slot": "makeup", "exposure": 0, "acceptance_req": 1, "contrast": 1, "covers": [], "tags": []},
	{"id": "makeup_heavy", "name": "浓艳烟熏妆", "slot": "makeup", "exposure": 1, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	# ★★ 第三十四轮：按用户口径「从 au 中添加几个妆容」补的 3 件。
	#   三件都是 AU 图包**真实的面部图层**（眼影那一档原来只有「淡 / 烟熏」两件，
	#   而 AU 自己还画着口红 / 腮红 / 雀斑三张）。分工是按**改的是脸上哪个部位**分的：
	#     · 烈焰红唇   —— 只动嘴，最省的一档
	#     · 绯色腮红   —— 只动颊，比口红再进一步
	#     · 点出来的雀斑 —— 动的是**识别特征**（肤色纹理），落差最高
	#   数值刻意排成一条 2 / 3 / 4 的斜坡，接在「淡妆 1」与「烟熏 5」之间。
	#   ★ 暴露值全给 0：这一栏动的是脸，不涉及露肤（只有烟熏妆那件是 1，
	#     那是它连唇色一起压深、显得更「刻意」）。
	{"id": "makeup_lip", "name": "烈焰红唇", "slot": "makeup", "exposure": 0, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	{"id": "makeup_blush", "name": "绯色腮红", "slot": "makeup", "exposure": 0, "acceptance_req": 2, "contrast": 2, "covers": [], "tags": []},
	{"id": "makeup_freckles", "name": "点出来的雀斑", "slot": "makeup", "exposure": 0, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},

	# ================= 穿环 =================
	{"id": "piercing_none", "name": "（不穿）", "slot": "piercing", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "piercing_multi", "name": "多孔耳钉组", "slot": "piercing", "exposure": 1, "acceptance_req": 2, "contrast": 2, "covers": [], "tags": []},
	# ★ 第二十七轮：用户口径「眉钉去掉」→ 删掉 piercing_brow。
	#   连带影响：`dol_map.AU_OVERRIDE` 里 `piercing_brow` 那条覆盖也一并删掉
	#   （它是唯一换源成 goldhairpin 的一件，其余三件继续借用头部小件顶替）。
	{"id": "piercing_lip", "name": "哥特风黑色唇环", "slot": "piercing", "exposure": 2, "acceptance_req": 7, "contrast": 5, "covers": [], "tags": []},
	{"id": "piercing_nose", "name": "鼻中隔银环", "slot": "piercing", "exposure": 3, "acceptance_req": 10, "contrast": 7, "covers": [], "tags": []},

	# ================= 纹身 =================
	# ★ 第二十六轮：贴图从「借用头部小件 + 位置搬移」换成 AU 图包自己的
	#   bodywriting 图案（真正画在身上的纹样，见 tools/dol_map.py 的 AU_OVERRIDE）。
	#   可用位置只有 forehead / 左·右 cheek / 左·右 shoulder / 左·右 thigh /
	#   breasts / pubic —— **没有前臂**，所以原来那件「前臂藤蔓纹身」改名成大腿，
	#   否则名字和贴图对不上。
	#
	# ★★ 第三十六轮（用户口径两条）：
	#   ① 「可装备的纹身上限设为 2，将纹身暴露度设置为 2」
	#      → 本槽位进 MULTI_SLOTS（同时最多 2 件）；除「（无）」外每件 exposure 一律 2，
	#        所以穿满两件 = 4 点暴露值。
	#   ② 「纹身与内衣内裤处理方法相同，不漏出来时，不计算暴露值反差度」
	#      → 每件纹身挂 `gate`（能盖住它的外衣槽位），走与内衣同一条门控：
	#        外衣盖得严实 → 这一件既不算暴露值、也不算反差值。
	#        大腿 / 下腹看下装与成装，胸口看上装与成装，颈侧再多一个颈饰；
	#        面颊 / 额头没有衣服盖得住，不给 gate、恒计入。
	#   ③ 「（无）」标 bare —— 它是这一槽位的空件（和 top_none / dress_none 同一个语义）：
	#      装上它 = 把纹身全卸掉；模型层靠这个标记把它从「实体件」里剔出去。
	{"id": "tattoo_none", "name": "（无）", "slot": "tattoo", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": [], "bare": true},
	{"id": "tattoo_neck", "name": "颈侧暗纹", "slot": "tattoo", "exposure": 2, "acceptance_req": 3, "contrast": 2, "covers": [], "tags": [], "gate": ["top", "dress", "neckwear"]},
	{"id": "tattoo_cheek", "name": "面颊刺青", "slot": "tattoo", "exposure": 2, "acceptance_req": 6, "contrast": 4, "covers": [], "tags": []},
	{"id": "tattoo_thigh", "name": "大腿藤蔓纹身", "slot": "tattoo", "exposure": 2, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "gate": ["bottom", "dress"]},
	# ★ 第三十五轮按用户口径补两件，同样取 AU bodywriting 的真实图案、同样落左大腿：
	#   heart 在 AU 里是「沿大腿向下的一串小心形」（源图 14×78 竖条），
	#   paw print 是一枚 5×5 的小爪印（源图极小，烘焙时放大到约 20×20 才看得清）。
	#   三件大腿纹身共用同一档「可见度」，只按墨量给反差分档。
	{"id": "tattoo_heart", "name": "大腿心形纹身", "slot": "tattoo", "exposure": 2, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "gate": ["bottom", "dress"]},
	{"id": "tattoo_paw", "name": "大腿爪印", "slot": "tattoo", "exposure": 2, "acceptance_req": 8, "contrast": 5, "covers": [], "tags": [], "gate": ["bottom", "dress"]},
	# ★ 第四十七轮：把「爪印」从大腿扩到**胸口**与**脸颊**。
	#   用户还点了「小腿」，但那条**做不了** —— AU 的 bodywriting 里没有小腿这个位置，
	#   而且实测小腿那一段两条腿各只有 8~11 px 宽（鞋子从 y≈161 起就盖住了），
	#   塞不下一枚看得清的爪印。于是那一轮补了胸口与脸颊两件。
	#   gate 照惯例：胸口看上衣与成装（同 tattoo_slave）；脸颊没有衣服盖得住，不给 gate。
	#
	# ★ 第五十一轮：用户口径「脸颊爪印去掉」—— 脸颊那件**整件删除**
	#   （`tattoo_paw_face`：本条定义 + `dol_map` 的两条映射 + 烘焙产物一起清掉）。
	#   爪印这一系还剩两件：大腿 `tattoo_paw` / 胸口 `tattoo_paw_chest`。
	{"id": "tattoo_paw_chest", "name": "胸口爪印", "slot": "tattoo", "exposure": 2, "acceptance_req": 8, "contrast": 5, "covers": [], "tags": [], "gate": ["top", "dress"]},
	# ★ 第三十六轮新增 4 件「刻字」纹身 —— 取自 AU `bodywriting/text/` 下的四组字，
	#   按用户口径**分散到四个位置**（左大腿 / 右大腿 / 胸口 / 下腹），
	#   免得两件刻字叠在同一处、贴图互相盖住。
	#   `text/` 只有 5 个位置（forehead / 左·右 thigh / breasts / pubic），
	#   正好够这四件各占一处。
	{"id": "tattoo_bitch", "name": "左大腿刻字「bitch」", "slot": "tattoo", "exposure": 2, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": [], "gate": ["bottom", "dress"]},
	{"id": "tattoo_freeuse", "name": "右大腿刻字「free-use」", "slot": "tattoo", "exposure": 2, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": [], "gate": ["bottom", "dress"]},
	{"id": "tattoo_slave", "name": "胸口刻字「slave」", "slot": "tattoo", "exposure": 2, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": [], "gate": ["top", "dress"]},
	{"id": "tattoo_cumrag", "name": "下腹刻字「cum-rag」", "slot": "tattoo", "exposure": 2, "acceptance_req": 10, "contrast": 8, "covers": [], "tags": [], "gate": ["bottom", "dress"]},

	# ================= 颈饰 =================
	# ★ 第二十六轮按用户口径「增加几款项圈」补了 5 件（spiked / ringed / lace /
	#   bell / chain），全部取 AU 图包自己的 clothes/neck/* 贴图。
	#   neck_collar / neck_scarf 本来就取自 AU，本轮只是核查确认，没有换源。
	#   覆盖缺陷（covers）的口径不变：只有「高领」与「围巾」两类标签能挡住颈侧烙印。
	{"id": "neck_none", "name": "（不戴）", "slot": "neckwear", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "neck_collar", "name": "硬挺立领", "slot": "neckwear", "exposure": 0, "acceptance_req": 1, "contrast": 1, "covers": ["neck_brand"], "tags": ["high_collar"]},
	{"id": "neck_scarf", "name": "暗红羊毛围巾", "slot": "neckwear", "exposure": 0, "acceptance_req": 2, "contrast": 3, "covers": ["neck_brand"], "tags": ["scarf"]},
	{"id": "neck_choker", "name": "黑色皮革颈圈", "slot": "neckwear", "exposure": 1, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "neck_spiked", "name": "尖刺项圈", "slot": "neckwear", "exposure": 2, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": []},
	{"id": "neck_ringed", "name": "金属环扣项圈", "slot": "neckwear", "exposure": 1, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "neck_lace", "name": "蕾丝颈圈", "slot": "neckwear", "exposure": 1, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},
	{"id": "neck_chain", "name": "金色锁链项圈", "slot": "neckwear", "exposure": 2, "acceptance_req": 7, "contrast": 6, "covers": [], "tags": []},
	{"id": "neck_freeuse", "name": "刻字颈圈", "slot": "neckwear", "exposure": 2, "acceptance_req": 7, "contrast": 6, "covers": [], "tags": []},
	# ★ 第五十一轮：用户口径「爱心吊坠移到颈饰」—— 从**配饰栏**挪过来。
	#   它本来就挂在锁骨上（AU 源 `clothes/neck/lovelocket`），归颈饰才对。
	#   ★ 挪栏的连带效果（都是好的）：
	#     · 与其它项圈同槽互斥 —— 不会再出现「戴吊坠 + 戴项圈」叠在同一个位置；
	#     · 图层 z 由 `dol_map.SLOT_Z` 按槽位取（配饰 105 → 颈饰 103），
	#       两档都在 top(95) 之上，所以照旧压在衣服外面、不会被高领盖住；
	#     · 它**没有** `covers` / `tags`，对颈侧烙印没有任何遮挡作用，数值口径不变。
	#   ★ 烘焙脚本是**正则解析本文件**取槽位的（见 dol_prepare.item_slots），
	#     所以这里改完，z 会自动跟着走，不用另改 dol_map。
	{"id": "acc_locket", "name": "银质心形吊坠", "slot": "neckwear", "exposure": 0, "acceptance_req": 2, "contrast": 2, "covers": [], "tags": []},

	# ================= 上衣 =================
	# ★ 「（不穿上衣）」—— 用户口径里的「直接外穿」：这一层没有东西，
	#   里面的内衣就是最外层，于是它的暴露值 / 反差值照算（见 UNDER_GATE）。
	#   暴露值给到 9：上半身真的露着，这是全表最贵的一件。
	{"id": "top_none", "name": "（不穿上衣）", "slot": "top", "exposure": 9, "acceptance_req": 15, "contrast": 8, "covers": [], "tags": [], "bare": true},
	{"id": "top_highneck", "name": "高领长袖衬衫", "slot": "top", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": ["neck_brand", "hand_tattoo"], "tags": ["high_collar", "long_sleeve"]},
	{"id": "top_plain", "name": "素色棉质衬衫", "slot": "top", "exposure": 1, "acceptance_req": 0, "contrast": 2, "covers": [], "tags": []},
	{"id": "top_longsleeve", "name": "长袖丝绸衬衣", "slot": "top", "exposure": 2, "acceptance_req": 2, "contrast": 3, "covers": ["hand_tattoo"], "tags": ["long_sleeve"]},
	{"id": "top_sheer", "name": "朴素薄纱罩衫（高暴露低反差）", "slot": "top", "exposure": 7, "acceptance_req": 6, "contrast": 2, "covers": [], "tags": [], "see": "sheer"},
	{"id": "top_lace", "name": "蕾丝半透上衣", "slot": "top", "exposure": 6, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": [], "see": "sheer"},
	{"id": "top_corset", "name": "束身皮质马甲", "slot": "top", "exposure": 8, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": [], "see": "cutout"},
	# ★ 第二十二轮从 AU 图包补的 4 件 —— 都是「够露」的外衣（sheer），
	#   给同侧的内衣内裤开门。补它们的原因见 README「内衣内裤的曝光门控」：
	#   加门控之前只有 4 件外衣能开门（其中下装只有 bottom_mini 一件），
	#   panties 那条路几乎是死的。
	{"id": "top_crop", "name": "短款露脐上衣", "slot": "top", "exposure": 5, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": [], "see": "cutout"},
	{"id": "top_offshoulder", "name": "露肩短上衣", "slot": "top", "exposure": 6, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": [], "see": "cutout"},
	# ★ 第二十四轮从 AU 图包补的「两套校服」—— 每套 4 件：上衣 / 裙子 / 鞋 / 袜。
	#   第一套（藏青）的裙子是**全图包里裙长最短的校服裙**，按用户口径算「能把内裤露出来」
	#   （见 "see": "cutout"）；第二套（墨绿）是普通及膝校裙，盖得严实。
	#   两套颜色互不相同，也都不同于已有的 bottom_knee（褐色格子校裙）。
	{"id": "top_school_navy", "name": "藏青校服衬衫", "slot": "top", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "top_school_green", "name": "墨绿校服衬衫", "slot": "top", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	# ★ 第二十五轮：水手服两套（上装）+ 三件「够露」的上衣。
	#   水手服的下装是同一条 serafuku_dress（AU 里唯一的水手服裙），只换染色。
	# ★ 第二十六轮：原来的 top_sundress / top_eveninggown（连衣裙与晚礼服的上半层）
	#   已按用户口径合并进新的 `dress` 槽位 —— 一整件衣服不再拆成上装 + 下装。
	{"id": "top_sailor_white", "name": "白色水手服上衣", "slot": "top", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "top_sailor_navy", "name": "藏青水手服上衣", "slot": "top", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "top_bustier", "name": "黑色蕾丝胸衣", "slot": "top", "exposure": 7, "acceptance_req": 7, "contrast": 7, "covers": [], "tags": [], "see": "cutout"},
	{"id": "top_lolita", "name": "洛丽塔胸衣", "slot": "top", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},
	{"id": "top_keyhole", "name": "开胸上衣", "slot": "top", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},

	# ================= ★★ 第二十八轮：从 AU 补的三件上衣（解「遮缺陷 ↔ 拿反差」的死结）=================
	# 上一轮实测的最优解里 top 只能拿 3 分，因为「手背刺青」逼着上半身必须穿长袖；
	# 而一件普通长袖会连带压死两处：① 把 bra 盖住（门控不计）；② 因为不带高领，
	# 颈饰被迫去顶「颈侧烙印」，只能挑最朴素的围巾（3 分）。
	# 这三件分别开三条路，让玩家自己取舍：
	#   · top_mesh         网纱透视   —— `sheer`：透出 bra（+8 分的乳贴就在里面），
	#                                   但**遮不住手**，走这条路就得认了手背刺青露着。
	#   · top_virginkiller 紧身针织衫 —— `long_sleeve`：遮住刺青，自身也给到 7 分反差。
	#   · top_turtleneck   高领军毛衣 —— `high_collar` + `long_sleeve`：**同时遮两处**，
	#                                   把颈饰整栏解放出来（可以放心戴尖刺项圈拿 6 分）。
	# 三者互不压制（各是一条路线的解），所以都留着。
	{"id": "top_mesh", "name": "网纱透视上衣", "slot": "top", "exposure": 8, "acceptance_req": 9, "contrast": 6, "covers": [], "tags": [], "see": "sheer"},
	{"id": "top_virginkiller", "name": "紧身针织衫", "slot": "top", "exposure": 6, "acceptance_req": 9, "contrast": 7, "covers": ["hand_tattoo", "neck_brand"], "tags": ["high_collar", "long_sleeve"]},
	{"id": "top_turtleneck", "name": "高领军毛衣", "slot": "top", "exposure": 3, "acceptance_req": 8, "contrast": 6, "covers": ["hand_tattoo", "neck_brand"], "tags": ["high_collar", "long_sleeve"]},
	# ★ 这两件都标 `high_collar`，是**照贴图量的**、不是想当然：
	#   烘出来的 bbox 顶边分别是 y=49（针织衫）与 y=45（军毛衣），
	#   而颈侧那段是 y48~56（拿 neck_collar 的 bbox 当参照）—— 两件都真的盖住了。
	#   （对比：`top_highneck` 顶边 y=53、`top_longsleeve` y=53，前者照样算高领。）
	#   所以它们的取舍**不在「遮不遮颈」，而在数值梯度**：
	#     · 高领军毛衣   需接受度 8 → 较早穿得起，暴 3 差 6（保守）
	#     · 紧身针织衫   需接受度 9 → 晚一档解锁，暴 6 差 7（更露、更惹眼）
	#   —— 这也正好对上用户这一轮的口径「添加**暴露度高的**服装」。

	# ================= ★★ 第三十七轮：上衣从 18 件补到 26 件 =================
	# 用户口径「补充各个暴露度层级的衣服，使数量尽量平衡」。
	# 上衣是唯一**两个槽位都不受缺陷约束之外**的主战场（缺陷逼着它穿长袖遮手背刺青），
	# 所以补的这 8 件全部是「露」的一侧，把 3 / 4 / 5 / 7 / 8 / 9 六档都填上。
	# ★ 它们一律**不带** high_collar / long_sleeve 标签 —— 遮不住任何缺陷，
	#   想拿高暴露就得认下「手背刺青露着」，取舍关系没有被削弱。
	{"id": "top_tank", "name": "无袖针织背心", "slot": "top", "exposure": 3, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	{"id": "top_tube", "name": "无肩带抹胸", "slot": "top", "exposure": 4, "acceptance_req": 5, "contrast": 4, "covers": [], "tags": []},
	{"id": "top_swim", "name": "泳衣式上衣", "slot": "top", "exposure": 4, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "top_leathercrop", "name": "皮质短上衣", "slot": "top", "exposure": 5, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "top_chain", "name": "锁链挂脖上衣", "slot": "top", "exposure": 7, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},
	{"id": "top_graphiccrop", "name": "网眼印花短上衣", "slot": "top", "exposure": 8, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "see": "sheer"},
	# ★ 9 档两件：一件浴巾、一条床单 —— 都是「临时裹一下」，`see: sheer` 让内衣照算。
	{"id": "top_towel", "name": "只围一条浴巾", "slot": "top", "exposure": 9, "acceptance_req": 10, "contrast": 6, "covers": [], "tags": [], "see": "sheer"},
	{"id": "top_bedsheet", "name": "单披一条床单", "slot": "top", "exposure": 9, "acceptance_req": 10, "contrast": 5, "covers": [], "tags": [], "see": "sheer"},

	# ================= 上内衣 =================
	{"id": "bra_plain", "name": "素色无痕内衣", "slot": "bra", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "bra_lace", "name": "黑色蕾丝内衣", "slot": "bra", "exposure": 4, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "bra_none", "name": "（不穿）", "slot": "bra", "exposure": 6, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": []},

	# ================= ★★ 第二十八轮：从 AU 补的两件内衣 =================
	# bra 这一栏原来只有 3 件、反差上限 6 分，而且平时还被外衣门控压着 ——
	# 补两件「反差更高、但覆盖更少」的款，让走 `sheer` 路线（top_lace / top_mesh）
	# 的玩家真的能从这一栏拿到分。
	#   · 乳贴：比「（不穿）」盖得略多一点点（暴露 5 < 6），但**刻意感**强得多
	#     （反差 8 > 6）—— 一个「少露一点、但更不像自己」的取舍。
	{"id": "bra_microkini", "name": "微型比基尼上衣", "slot": "bra", "exposure": 4, "acceptance_req": 8, "contrast": 7, "covers": [], "tags": []},
	{"id": "bra_pasties", "name": "乳贴", "slot": "bra", "exposure": 5, "acceptance_req": 9, "contrast": 8, "covers": [], "tags": []},

	# ================= ★★ 第三十七轮：上内衣从 5 件补到 9 件 =================
	# 原来 4 / 5 两档各只有一件，6 档以上是空的（`bra_none` 一个人顶在 6 档）。
	# 补的 4 件把 4 / 8 / 9 三档填起来 —— 其中 9 档那件是刻意「比不穿更过分」的：
	# 暴露值 9 > `bra_none` 的 6，但反差也更高（刻意感更强）。
	# 它们照旧受 UNDER_GATE 门控：上面盖着严实上衣时一律不算数。
	#
	# ★★ 第五十一轮：用户口径「透明泳衣原本是整装吗 是的话移到整装」——
	#   查证结果：**是**。AU 图包里 `seethroughswimsuit` 在 `under-upper/` 与
	#   `under-lower/` 下**各有一份**，是「一整件连体泳衣被拆成上下两半存」，
	#   与 `dress_*` 那些成装的两层结构完全同构（实测烘焙后上半 y51..89、
	#   下半 y88..102，在 y88-89 精密衔接）。
	#   所以 `bra_seethrough`（透明泳衣上衣）与 `panties_seethrough`（透明连体泳裤）
	#   **两件一起撤掉**，合并成一件成装 `dress_seethrough`（见「成装」一节）——
	#   这正是用户那句「透明连体泳裤去掉」的由来：它不是被删，是被并进整装了。
	{"id": "bra_bikini", "name": "系带比基尼上衣", "slot": "bra", "exposure": 4, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "bra_latex", "name": "乳胶连体上衣", "slot": "bra", "exposure": 8, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": []},
	{"id": "bra_tape", "name": "胶带束胸", "slot": "bra", "exposure": 9, "acceptance_req": 10, "contrast": 8, "covers": [], "tags": []},

	# ================= 手套 =================
	{"id": "gloves_none", "name": "（不戴）", "slot": "gloves", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "gloves_leather", "name": "皮质长手套", "slot": "gloves", "exposure": 1, "acceptance_req": 0, "contrast": 2, "covers": ["hand_tattoo"], "tags": ["glove"]},
	{"id": "gloves_lace", "name": "蕾丝短手套", "slot": "gloves", "exposure": 1, "acceptance_req": 3, "contrast": 4, "covers": ["hand_tattoo"], "tags": ["glove"]},
	{"id": "gloves_oper", "name": "歌剧长手套", "slot": "gloves", "exposure": 2, "acceptance_req": 7, "contrast": 5, "covers": ["hand_tattoo"], "tags": ["glove"]},

	# ================= 配饰 =================
	# ★ 第三十四轮：用户口径「黄铜胸针去掉」→ `acc_brooch` **物品级删除**
	#   （和上一轮撤掉眉钉 `piercing_brow` 是同一档处理：整条从表里撤掉，
	#   连带 `dol_map.py` 的映射、`ScenarioData.ITEM_DESC` 的目击描述、
	#   `TRUE_POOL` 的候选、目录快照与烘焙产物一起清掉）。
	#   ★ 连带口径：A 的原貌从此**不再可能戴配饰**（`TRUE_POOL["accessory"]`
	#   只剩 `acc_none`）—— 少了胸针那件「A 也可能戴」的东西，就不要再补一件
	#   进来冒充，等用户点名再说。
	{"id": "acc_none", "name": "（不戴）", "slot": "accessory", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	# ★★ 第三十四轮：按用户口径「从 au 中添加几个配饰」补的 3 件，全部取 AU 真实贴图。
	#   三件刻意分在**身上三个不同的位置**，换一件就是换一个地方露东西：
	#     · 银质心形吊坠 —— 锁骨（AU `neck/lovelocket`，源图纯灰，乘一层旧银）
	#     · 金脚链       —— 脚踝（AU `legs/goldanklets`，源图本来就是金的，不再染色）
	#     · 金色手铐     —— 双腕 + 垂下来的链子（AU `hands/goldshackles`，左右手各一层）
	#   ★ 数值也排成 2 / 3 / 5 的斜坡：吊坠最便宜，脚链要裙短才露得出来，
	#     手铐最扎眼（也是这一栏唯一带暴露值的 —— 腕上那串链子本身就惹眼）。
	# ★★ 第四十六轮：按用户口径「金脚链和金色手铐删去」撤掉后两件
	#   （`acc_anklet` / `acc_shackle`）—— 整条从表里撤掉，与当初撤眉钉、
	#   撤黄铜胸针是同一档处理：`dol_map.py` 的映射、烘焙产物一起清掉。
	# ★★ 第五十一轮：用户口径「爱心吊坠移到颈饰 · 去掉配饰一栏」——
	#   · `acc_locket` **挪栏**（不删）：已并入上面的「颈饰」一节，slot 改成 neckwear；
	#   · `accessory` 槽位整体下架（见 `DISABLED_SLOTS`）。
	#
	#   ★ 那一栏剩下的 5 件（束腰皮带 + 4 件项圈）**一件没删** ——
	#     与本项目其它「去掉一栏」的处理完全一致：走槽位级下架，
	#     物品定义 / 贴图 / 目击描述全部保留，把 "accessory" 从 DISABLED_SLOTS 里
	#     删掉即可原样恢复。用户口径明确要的就是这个（「全部随栏下架，数据保留」）。
	{"id": "acc_belt", "name": "束腰皮带", "slot": "accessory", "exposure": 1, "acceptance_req": 4, "contrast": 3, "covers": [], "tags": []},
	# ★ 第四十八轮：按用户口径从「配饰候选」里挑的六件（腿环 2 + 颈圈 4）。
	#   全部实测为 A 档（AU 新几何 + 纯灰度），贴图直接用、没有搬运。
	#   数值口径照既有三件往上一档排：
	#     脚边的环带最轻（暴露 1 / 门槛 4~5）＜ 兔女郎项圈（门槛 6）
	#     ＜ Whitney 项圈（门槛 7）＜ 带牵引绳的两件（暴露 2 / 门槛 8~9，
	#     因为「拴着一条绳」本身就是要被人看见的）。
	# ★ 第四十九轮：用户口径「去掉搭扣腿环 皮质腿环」——
	#   两件腿环**整件删掉**（连同 `dol_map` 映射与烘焙产物），只留四件颈圈。
	#   （用户当时看了那张对照图后做的取舍：腿环在两条腿只有 8~11 px 宽的
	#     小腿段上，观感不理想。）
	{"id": "acc_choker_bunny", "name": "兔女郎项圈", "slot": "accessory", "exposure": 1, "acceptance_req": 6, "contrast": 4, "covers": [], "tags": []},
	{"id": "acc_choker_whitney", "name": "Whitney 的项圈", "slot": "accessory", "exposure": 1, "acceptance_req": 7, "contrast": 5, "covers": [], "tags": []},
	{"id": "acc_choker_leash", "name": "带牵引绳项圈", "slot": "accessory", "exposure": 2, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": []},
	{"id": "acc_choker_whitney_leash", "name": "Whitney 的牵引项圈", "slot": "accessory", "exposure": 2, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": []},

	# ================= 下装 =================
	# ★ 第三十一轮（用户口径「丁字裤归在下装」）：黑色丁字裤与牛仔丁字裤从
	#   「下内衣」移到了「下装」。它们本来就在 AU 图包的 under-lower/ 下，
	#   贴图不用换 —— 变的只是**算哪一栏**：
	#     · 画在哪一层：z 由槽位决定，所以从内衣层(67)挪到了下装层(90)；
	#     · 不再受内衣曝光门控（它们自己就是外面那层）；
	#     · 会跟成装(dress)互斥 —— 本来就是「上装+下装」那一组的成员。
	#   ★ 刻意**不**给它们 see: cutout：丁字裤当外裤穿时，里面的内裤仍按「被盖住」算。
	#     想改成「露出内裤」的话，给这两件补上 "see": "cutout" 即可。
	#
	# ★★ 第四十六轮（用户口径「黑色丁字裤归在下内衣」）：**只有黑色那条**挪回去，
	#   牛仔丁字裤留在下装。挪回下内衣之后它重新受 UNDER_GATE 门控（被下装盖住
	#   就不算数值），也不再与成装互斥 —— 也就是回到第三十一轮之前的状态。
	{"id": "panties_janties", "name": "牛仔丁字裤", "slot": "bottom", "exposure": 5, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	# ★ 同上：「（不穿下装）」= 下装这一层空着，里面的内裤直接外穿。
	{"id": "bottom_none", "name": "（不穿下装）", "slot": "bottom", "exposure": 9, "acceptance_req": 15, "contrast": 8, "covers": [], "tags": [], "bare": true},
	{"id": "bottom_longskirt", "name": "及地长裙", "slot": "bottom", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "bottom_trousers", "name": "直筒长裤", "slot": "bottom", "exposure": 1, "acceptance_req": 0, "contrast": 2, "covers": [], "tags": []},
	{"id": "bottom_knee", "name": "及膝百褶裙", "slot": "bottom", "exposure": 3, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	{"id": "bottom_mini", "name": "超短皮裙", "slot": "bottom", "exposure": 7, "acceptance_req": 7, "contrast": 7, "covers": [], "tags": [], "see": "cutout"},
	# ★ 第二十二轮从 AU 图包补的 2 件下装（同样是「够露」的外衣）
	{"id": "bottom_pleat", "name": "超薄百褶短裙", "slot": "bottom", "exposure": 5, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": [], "see": "sheer"},
	{"id": "bottom_cut", "name": "开衩短裙", "slot": "bottom", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": []},
	# ★ 第二十四轮的两套校服裙（配 top_school_* / shoes_school_* / stockings_school_*）：
	#   藏青那条是**图包里裙长最短的校服裙**，墨绿那条是普通及膝款，两条都不标 see。
	#
	# ★★ 第二十七轮：`bottom_cut` / `bottom_school_navy` / `bottom_slit` 三件**降级成普通下装**。
	#   用户口径就是「降级成普通下装」—— 这是第二十五轮遗留待议项的收尾。
	#   起因：这三件的 `see: "cutout"` 旗当年是拿**旧的高腰 `gstring`** 量出来的
	#   （把内裤叠在裙下量露出的像素：18 / 22 / 30 px）。第二十五轮把内裤换成
	#   `lacepanties` 之后，这三条裙子把内裤盖得严严实实（实测 **0 px**），
	#   旗子就不再成立 —— 留着等于「按款式语义白送一份暴露值与反差值」。
	#   → 去掉 `see` 之后，它们就只是普通下装：穿在内裤外面，内裤不算数。
	#   ★ 仍然是镂空/露的只有 `bottom_mini`（超短皮裙）、`bottom_pleat`（超薄百褶短裙，
	#     sheer）与 `bottom_hotpants`（黑色皮短裤）。
	{"id": "bottom_school_navy", "name": "藏青超短校服裙", "slot": "bottom", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": []},
	{"id": "bottom_school_green", "name": "墨绿及膝校服裙", "slot": "bottom", "exposure": 3, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	# ★ 第二十五轮：水手服裙两套（同一条贴图、两种染色）+
	#   三件「够露」的下装（各配上方 top_* 里那件）。
	# ★ 第二十六轮：原来的 bottom_sundress / bottom_eveninggown 已合并进 `dress`。
	{"id": "bottom_sailor_white", "name": "白色水手服裙", "slot": "bottom", "exposure": 3, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	{"id": "bottom_sailor_navy", "name": "藏青水手服裙", "slot": "bottom", "exposure": 3, "acceptance_req": 3, "contrast": 3, "covers": [], "tags": []},
	{"id": "bottom_hotpants", "name": "黑色皮短裤", "slot": "bottom", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},
	{"id": "bottom_slit", "name": "高开衩短裙", "slot": "bottom", "exposure": 6, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": []},

	# ================= ★★ 第二十八轮：从 AU 补的「高暴露」下装 =================
	# 用户口径：「遇见反差值不足的情况下，可以从au添加暴露度高的服装」。
	#
	# 为什么补在**下装**这一栏（而不是随便找几件塞进去）——
	# 先用 tests/_ProbeCeiling 量过「反差天花板到底卡在哪」，结论有点反直觉：
	#   各关 DP 最优解的反差爬到 54 就上不去了，而**暴露值预算大量闲置**
	#   （第 2/3/4 关分别只用了 21 / 32 上限中的 21、42 中的 21、54 中的 21）。
	#   也就是说「反差不足」的根因**不是暴露值不够**，而是「没有更强的件可换」。
	# 再往下拆，真正咬死天花板的是一对**互相冲突**的约束：
	#   · top 必须穿长袖遮「手背刺青」→ 只能贡献 1~3 分；
	#   · 而长袖又把 bra 盖死（门控），还逼得颈饰去顶「颈侧烙印」（也只能拿 3 分）。
	#
	# 下装这一栏是**唯一完全不受缺陷约束**的（两处缺陷都在上身），
	# 而且只要它带 `see`，内裤那一栏就能一起被解锁 —— 所以补在这里收益最大。
	{"id": "bottom_fishnet", "name": "网眼超短裙", "slot": "bottom", "exposure": 8, "acceptance_req": 8, "contrast": 7, "covers": [], "tags": [], "see": "cutout"},
	{"id": "bottom_pvc", "name": "漆皮迷你裙", "slot": "bottom", "exposure": 6, "acceptance_req": 8, "contrast": 8, "covers": [], "tags": [], "see": "cutout"},
	{"id": "bottom_qipao", "name": "开衩短旗袍", "slot": "bottom", "exposure": 7, "acceptance_req": 9, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},

	# ================= ★★ 第三十七轮：下装从 17 件补到 22 件 =================
	# 原来 4 档是空的、7 / 8 档各只有一两件。补的 5 件填 3 / 4 / 5 / 7 / 8 五档。
	# 下装这一栏完全不受缺陷约束（两处缺陷都在上身），是拿反差值的主力，
	# 所以新增件都带 `see`（除了三件普通款）—— 顺手把内裤那一栏也解锁。
	{"id": "bottom_pencil", "name": "包臀铅笔裙", "slot": "bottom", "exposure": 3, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},
	{"id": "bottom_shortshort", "name": "牛仔超短热裤", "slot": "bottom", "exposure": 4, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},
	{"id": "bottom_leathershort", "name": "皮质超短裤", "slot": "bottom", "exposure": 5, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": []},
	{"id": "bottom_chain", "name": "锁链短裙", "slot": "bottom", "exposure": 7, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},
	{"id": "bottom_sarong", "name": "一片式裹裙", "slot": "bottom", "exposure": 8, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},

	# ================= 成装（整件式）★ 第二十六轮新增的槽位 =================
	# 用户口径：「如果是一整件衣服 如晚礼服 不能分开成下装和上装 应该单开一个栏目」。
	# 所以成装各自只有**一件**，上、下两层贴图烘在同一张 PNG 里，
	# 走 `dress` 槽位（z 96，压在 top / bottom 之上，见 dol_map.SLOT_Z）。
	#
	# ★ 第二十七轮按用户口径改名为「成装」（原叫「连衣裙」），并且**装备时与上装 / 下装互斥**
	#   —— 见表头的 EXCLUSIVE_GROUPS。语义上这才自洽：成装的「上半截」就等于上装、
	#   「下半截」就等于下装，三者任取其一；否则会出现「上半身穿成装 + 下半身穿长裤」。
	#
	# ★ dress_none 的暴露值是 0，不是像 top_none / bottom_none 那样的 9 ——
	#   「没穿成装」只是穿着上衣 + 下装而已，一点都不暴露；
	#   它标 bare 是为了让门控把它当成「这一层没有东西」，内衣照常按 top / bottom 判定。
	{"id": "dress_none", "name": "（不穿成装）", "slot": "dress", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": [], "bare": true},
	{"id": "dress_sundress", "name": "吊带连衣裙", "slot": "dress", "exposure": 2, "acceptance_req": 2, "contrast": 3, "covers": [], "tags": []},
	{"id": "dress_eveninggown", "name": "晚礼服", "slot": "dress", "exposure": 2, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},

	# ================= ★★ 第三十七轮：成装从 2 件补到 10 件 =================
	# 用户口径「补充各个暴露度层级的衣服，使数量尽量平衡」。
	# 成装这一栏原来只有 2 件、而且都挤在 2 档 —— 是整个表里最薄的一栏，
	# 所以八件新衣服全部补在这里，一路铺满 3 / 4 / 5 / 7 / 8 / 9 六档。
	# 全部取 AU 图包里都有的款式（`upper/*`），所以不用写 alt 兜底。
	#
	# ★ 成装与上装 / 下装互斥（EXCLUSIVE_GROUPS），所以这些高暴露成装开的是
	#   **另一条路**：穿成装就不穿「上衣 + 下装」，两处的暴露值预算合到一件上。
	{"id": "dress_kimono", "name": "短款和服", "slot": "dress", "exposure": 3, "acceptance_req": 4, "contrast": 4, "covers": [], "tags": []},
	{"id": "dress_maid", "name": "黑白女仆装", "slot": "dress", "exposure": 3, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "dress_slip", "name": "缎面吊带睡裙", "slot": "dress", "exposure": 4, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "dress_nurse", "name": "粉色护士服", "slot": "dress", "exposure": 4, "acceptance_req": 6, "contrast": 6, "covers": [], "tags": []},
	{"id": "dress_cheongsam", "name": "开衩短旗袍", "slot": "dress", "exposure": 5, "acceptance_req": 7, "contrast": 6, "covers": [], "tags": [], "see": "cutout"},
	{"id": "dress_leather", "name": "皮质紧身裙", "slot": "dress", "exposure": 7, "acceptance_req": 8, "contrast": 7, "covers": [], "tags": []},
	{"id": "dress_swan", "name": "高开衩天鹅绒长裙", "slot": "dress", "exposure": 8, "acceptance_req": 9, "contrast": 7, "covers": [], "tags": [], "see": "cutout"},
	# ★ 9 档：一件「穿了等于没穿」的透明纱睡袍。`see: sheer` 让 bra / panties
	#   两栏都能被它透出来。
	{"id": "dress_transparent", "name": "透明纱睡袍", "slot": "dress", "exposure": 9, "acceptance_req": 15, "contrast": 7, "covers": [], "tags": [], "see": "sheer"},

	# ================= ★★ 第五十一轮：透明连体泳衣（由两件内衣合并而成）=================
	# 用户口径：「透明泳衣原本是整装吗 是的话移到整装」「透明连体泳裤去掉」。
	#
	#   查证（不是猜的）：AU 图包里 `seethroughswimsuit` 在 `under-upper/` 与
	#   `under-lower/` 下**各有一份** —— 这是「一整件连体泳衣被拆成上下两半存」，
	#   与 `dress_kimono` / `dress_nurse` 那些成装的两层结构**完全同构**。
	#   实测烘焙到 68×203 取景框后：上半 y51..89、下半 y88..102，
	#   在 **y88-89 精密衔接**（与成装那批 74→74 / 82→82 是同一种接缝）。
	#   → 结论：**原本就是整装**，于是两件合并成这一件。
	#
	#   合并后的取舍：
	#     · 数值沿用原来那两件的口径 —— 暴露 9（两件都是 9）、门槛 15
	#       （`panties_seethrough` 原本是 15，取两件里更严的那个）；
	#     · `see: "sheer"` —— 它本来就是透明的，`see` 字段的语义就是
	#       「外衣能透出内衣」。给了它，玩家既可以只穿这一件（内衣栏留空），
	#       也可以在底下继续穿内衣并**照样计入** —— 后者保住了原来
	#       「bra 9 + panties 9」那条数值路径，不会因为这次合并把天花板压下来。
	#       （不给 `see` 的话，成装会把内衣盖住，那两件的暴露值等于白丢。）
	#     · `dress_transparent` 的商品说明里原来写着「全表唯一一件同时给上下两处
	#       内衣开门的衣服」—— 加了这件之后那句要改成「唯二」。
	{"id": "dress_seethrough", "name": "透明连体泳衣", "slot": "dress", "exposure": 9, "acceptance_req": 15, "contrast": 7, "covers": [], "tags": [], "see": "sheer"},

	# ================= 吊袜带（第三十七轮已并入「袜类」，见下）=================
	# 原来这里是独立的一栏（garter_none / garter_lace / garter_black）。
	# 用户口径「吊带袜和袜类归为一类」之后：
	#   · 两件吊袜带（蕾丝 / 黑色皮革）→ 挪到下面「袜类」那一节，slot 改成 stockings；
	#   · garter_none（吊袜带的空件）→ **删除**（袜类本来就有 stockings_none，
	#     留着会出现两个「（不穿）」）。
	# 贴图不用换 —— 它们本来就取 AU 的 `clothes/legs/*`，和袜子同一层。

	# ================= 下内衣 =================
	# ★ 第二十六轮按用户口径「增加暴露度高的内裤款式」补了 4 件，全部取 AU 图包
	#   自己的 clothes/under-lower/* 贴图。它们照旧受 UNDER_GATE 门控：
	#   下面被普通下装盖住时一律不计入暴露 / 反差 —— 想让它真的算数，
	#   得配「（不穿下装）」或者标了 see 的下装。
	{"id": "panties_plain", "name": "素色棉质内裤", "slot": "panties", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	# ★★ 第四十六轮（用户口径「黑色丁字裤归在下内衣」）：从下装挪回来。
	#   贴图不用换（源图一直在 AU 的 `under-lower/gstring`），变的是三件事：
	#     · z 从下装层(90)回到内衣层(67)；
	#     · 重新受 UNDER_GATE 门控 —— 被普通下装盖住时不计暴露 / 反差；
	#     · 不再与成装(dress)互斥（那是「上装+下装」这一组的规矩）。
	#   ★ id 保留 `panties_thong`（本来就叫这个，第三十一轮移栏时没改名）。
	{"id": "panties_thong", "name": "黑色丁字裤", "slot": "panties", "exposure": 5, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "panties_lace", "name": "黑色蕾丝内裤", "slot": "panties", "exposure": 5, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "panties_micro", "name": "微型比基尼内裤", "slot": "panties", "exposure": 6, "acceptance_req": 7, "contrast": 6, "covers": [], "tags": []},
	{"id": "panties_crotchless", "name": "开裆蕾丝内裤", "slot": "panties", "exposure": 7, "acceptance_req": 8, "contrast": 7, "covers": [], "tags": []},
	{"id": "panties_none", "name": "（不穿）", "slot": "panties", "exposure": 8, "acceptance_req": 8, "contrast": 7, "covers": [], "tags": []},

	# ================= ★★ 第三十七轮：下内衣从 5 件补到 11 件 =================
	# 原来 0 / 5 / 6 / 7 / 8 各一件，4 档与 9 档是空的 —— 而 9 档（几乎不遮）恰恰是
	# 全表最缺的一档（整个表原来一件都没有）。补的 6 件把 4 档和 9 档填起来。
	# ★ 9 档那几件里门槛 15 的（= 原来第 4 关的门槛，第 50 轮起起始接受度是 14，
	#   所以它仍是这一栏最贵的一档）与门槛 10 的并存 —— 留了一条早一点的出路。
	#
	# ★★ 第五十一轮：用户口径「遮羞布去掉」「透明连体泳裤去掉」——
	#   撤掉 `panties_loincloth`（遮羞布）与 `panties_seethrough`（透明连体泳裤）。
	#   两件都是**整件删除**（定义 + dol_map 映射 + 烘焙产物）。
	#   ★ 后者不是「删了不要」，是**并进整装**了：它和 `bra_seethrough` 本来就是
	#     AU 那件 `seethroughswimsuit` 的上下两半，现在合成 `dress_seethrough`。
	#   ★ 于是这一栏的 9 档从 5 件变 3 件（细绳丁字裤 / 系带开衩比基尼 / 平坦贞操笼）。
	{"id": "panties_bikini", "name": "系带比基尼内裤", "slot": "panties", "exposure": 4, "acceptance_req": 5, "contrast": 5, "covers": [], "tags": []},
	{"id": "panties_shibari", "name": "绳缚式内裤", "slot": "panties", "exposure": 8, "acceptance_req": 9, "contrast": 8, "covers": [], "tags": []},
	{"id": "panties_gstring", "name": "细绳丁字裤", "slot": "panties", "exposure": 9, "acceptance_req": 10, "contrast": 8, "covers": [], "tags": []},
	{"id": "panties_tieside", "name": "系带开衩比基尼内裤", "slot": "panties", "exposure": 9, "acceptance_req": 15, "contrast": 8, "covers": [], "tags": []},

	# ---- ★★ 第三十九轮：从 AU 的 `clothes/genitals/` 引入一件 ----
	# 用户口径：「引入平坦贞操笼放在下内衣，暴露度取最高」。
	# 贴图取 AU 自己的 `genitals/flatchastitycage/full.png` —— 金属笼，正面几乎全开，
	# 所以它的暴露值就该是这一栏最高的那一档。
	# ★ 「取最高」的实现依据：`panties` 现有 9 档的几件里（细绳丁字裤 / 系带开衩比基尼 /
	#   平坦贞操笼，第 51 轮删掉遮羞布与透明连体泳裤后剩这三件；空件是 8）—— 这一件也取 9。
	{"id": "panties_flatcage", "name": "平坦贞操笼", "slot": "panties", "exposure": 9, "acceptance_req": 10, "contrast": 8, "covers": [], "tags": []},

	# ================= 袜类（第三十七轮起含「吊袜带」）=================
	# ★ 第三十七轮合并：原 `garterbelt` 一栏的两件（蕾丝 / 黑色皮革吊袜带）挪到这里，
	#   贴图照旧取 AU `clothes/legs/*`（asymmetricalgarter / harness garter stockings），
	#   本来就是和袜子同一层的图，换栏不用换图。
	{"id": "stockings_none", "name": "（不穿）", "slot": "stockings", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": []},
	{"id": "stockings_opaque", "name": "不透明连裤袜", "slot": "stockings", "exposure": 1, "acceptance_req": 2, "contrast": 2, "covers": [], "tags": []},
	{"id": "stockings_thigh", "name": "白色大腿袜", "slot": "stockings", "exposure": 2, "acceptance_req": 4, "contrast": 3, "covers": [], "tags": []},
	{"id": "stockings_net", "name": "黑色渔网袜", "slot": "stockings", "exposure": 3, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": []},
	# ★ 第二十四轮：两套校服的袜子（白色大腿袜 / 米色花边短袜）
	{"id": "stockings_school_navy", "name": "白色校服袜", "slot": "stockings", "exposure": 2, "acceptance_req": 4, "contrast": 3, "covers": [], "tags": []},
	{"id": "stockings_school_green", "name": "米色校服袜", "slot": "stockings", "exposure": 1, "acceptance_req": 2, "contrast": 2, "covers": [], "tags": []},
	# ---- 原「吊袜带」两件（第三十七轮并入）----
	{"id": "garter_lace", "name": "蕾丝吊袜带", "slot": "stockings", "exposure": 1, "acceptance_req": 5, "contrast": 4, "covers": [], "tags": []},
	{"id": "garter_black", "name": "黑色皮革吊袜带", "slot": "stockings", "exposure": 2, "acceptance_req": 7, "contrast": 5, "covers": [], "tags": []},
	# ---- 第三十七轮：按用户口径「补充各个暴露度层级的衣服」补的 4 件袜类 ----
	#   袜类这一栏原本最厚的一档只有 3（渔网袜），4 档以上整个是空的。
	#   四件一路铺到 9 档，让「露腿」这条路也有高暴露值可拿（但反差值只算 top / bottom，
	#   所以它们的作用是**给下装腾暴露值预算**，不是直接换分）。
	{"id": "stockings_sheer", "name": "超薄丝袜", "slot": "stockings", "exposure": 5, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "stockings_fishnettights", "name": "网眼连裤袜", "slot": "stockings", "exposure": 7, "acceptance_req": 8, "contrast": 6, "covers": [], "tags": []},
	{"id": "stockings_chainnet", "name": "金属环网眼腿套", "slot": "stockings", "exposure": 8, "acceptance_req": 9, "contrast": 6, "covers": [], "tags": []},
	{"id": "stockings_sheerskin", "name": "透肉连裤袜", "slot": "stockings", "exposure": 9, "acceptance_req": 10, "contrast": 6, "covers": [], "tags": []},

	# ================= 鞋履 =================
	{"id": "shoes_boots", "name": "及踝皮靴", "slot": "shoes", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": [], "tags": []},
	{"id": "shoes_heels", "name": "细跟高跟鞋", "slot": "shoes", "exposure": 2, "acceptance_req": 3, "contrast": 4, "covers": [], "tags": []},
	# ★ 第二十四轮：两套校服的鞋（藏青校服皮鞋 / 棕色便鞋）
	{"id": "shoes_school_navy", "name": "藏青校服皮鞋", "slot": "shoes", "exposure": 0, "acceptance_req": 1, "contrast": 1, "covers": [], "tags": []},
	{"id": "shoes_school_green", "name": "棕色校服皮鞋", "slot": "shoes", "exposure": 0, "acceptance_req": 1, "contrast": 1, "covers": [], "tags": []},
	# ★ 第四十六轮：按用户挑的五双补进来（AU 清点表里都是 A 档）。
	#   鞋槽原来最缺的是**高暴露**那一头（只有细跟高跟鞋一件在 2 档），
	#   所以补的两双凉鞋（露趾 + 露脚背）一路铺到 4 / 5 档 ——
	#   这样配「高暴露」那套搭配时，鞋也能出一份力。
	#   另外三双是包脚的（篮球鞋 / 运动鞋 + 已删的及膝靴），填的是中低档。
	# ★ 第四十九轮：用户口径「去掉户外及膝靴」—— `shoes_field` 整件删掉，
	#   五双变四双（运动鞋 / 篮球鞋 / 两双凉鞋）。
	{"id": "shoes_trainers", "name": "运动鞋", "slot": "shoes", "exposure": 1, "acceptance_req": 1, "contrast": 2, "covers": [], "tags": []},
	{"id": "shoes_basketball", "name": "篮球鞋", "slot": "shoes", "exposure": 1, "acceptance_req": 2, "contrast": 3, "covers": [], "tags": []},
	{"id": "shoes_dress_sandal", "name": "正装凉鞋", "slot": "shoes", "exposure": 4, "acceptance_req": 6, "contrast": 5, "covers": [], "tags": []},
	{"id": "shoes_open_sandal", "name": "露趾凉鞋", "slot": "shoes", "exposure": 5, "acceptance_req": 7, "contrast": 6, "covers": [], "tags": []},

	# ================= 外袍（暂时下架，见 DISABLED_SLOTS）=================
	# 这 4 件仍然定义着、贴图也照烘，只是玩家暂时看不到、也抽不到。
	# 恢复：把 "robe" 从 DISABLED_SLOTS 里删掉即可。
	{"id": "robe_none", "name": "（不穿外袍）", "slot": "robe", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": [], "bare": true},
	{"id": "robe_travel", "name": "厚重旅行斗篷", "slot": "robe", "exposure": 0, "acceptance_req": 0, "contrast": 1, "covers": ["neck_brand"], "tags": ["high_collar"]},
	{"id": "robe_lace", "name": "半透蕾丝罩袍", "slot": "robe", "exposure": 2, "acceptance_req": 4, "contrast": 5, "covers": [], "tags": [], "see": "sheer"},
	{"id": "robe_leather", "name": "黑皮长外套", "slot": "robe", "exposure": 2, "acceptance_req": 6, "contrast": 4, "covers": [], "tags": []},

	# ================= ★★ 第三十九轮：妙妙工具（只能手动装备）=================
	# 用户口径：「在服装最下面新增一栏名称为妙妙工具，此栏专门为减少换装环节难度的
	#   设置的，只能手动装备，调试计算反差值时请不要使用」。
	#
	# 这一栏与其余各栏的**根本区别**在 `OutfitData.MANUAL_SLOTS` —— 它是「看得到、
	# 点得到，但系统从不代劳」的一栏：
	#   · 不参与原貌抽取 → 情报台不会问、相册不会拍（`RunData` 一律走 `auto_slots()`）
	#   · 不进强制装备池（`forced_pool()` 直接跳过）
	#   · 一键达标（DP）不会替你装上它（`auto_complete_outfit()` 不把它排进分组）
	#   · **不进「与原貌一致 / 已改掉 / 相似度」这些统计** → 所以它不影响反差值口径，
	#     这正是用户说的「调试计算反差值时请不要使用」
	#   · 暴露值 0 —— 它藏在衣服底下，本身不扎眼；带与不带都不吃暴露值预算
	# 换句话说：它是一件**玩家自己决定要不要揣上**的道具，你不点它就当不存在。
	#
	# 贴图取 AU `clothes/back/fox tail butt plug/back.png`（挂在身后的那条尾巴，
	# 画布 bbox 从 x36 一路延伸到 x116 —— 侧后方翘出来的形状）。
	# `desc` 是这件物品的**介绍文字**，会出现在换装卡片的悬停提示里（见 Wardrobe._tip_for）。
	{"id": "tool_none", "name": "（不携带）", "slot": "tool", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": [], "bare": true},
	{"id": "tool_tail", "name": "尼古喵尾", "slot": "tool", "exposure": 0, "acceptance_req": 0, "contrast": 0, "covers": [], "tags": [], "desc": "喵什么错都没有"},
]

# ============================================================
#  运行期物品表（第四十轮）
#
#  初始 = `ITEMS_BASE` 的深拷贝；`data/story.json` 的 `item_overrides`
#  段可以在运行期原地覆盖其中任意几件的 `exposure` / `acceptance_req`。
#
#  ★ 为什么用 `static var` 而不是 `var`：本文件有 15 处 static func 在读它。
#  ★ 为什么覆写要「原地改」而不是「换一张新表」：
#    全项目有 33 处直接写 `OutfitData.ITEMS`（不做函数调用）。
#    换表的话那些引用点会拿到旧表；原地改（`ITEMS[i][field] = v`）则全都自动跟上。
#  ★ 唯一的时序要求：**必须在第一次读 ITEMS 之前应用覆写**。
#    由 `ScenarioData` 在它自己 _ready()（读完 story.json）里调
#    `OutfitData.apply_item_overrides(...)` 来保证 —— ScenarioData 的 autoload
#    顺序在 OutfitData 之后，那时 static var 已经初始化好了。
#    另外每个用到 ITEMS 的 static func 顶部都调一次 `_ensure_items()` 兜底
#    （防止有人绕过 autoload 直接用静态函数，比如测试里）。
# ============================================================
static var ITEMS: Array = ITEMS_BASE.duplicate(true)

static var _items_ready: bool = false
static var _applied_overrides: Dictionary = {}   # 真正生效过的覆写（供界面/测试查）

# 兜底：把「数值覆写还没应用」这件事补上。
#   ★ 正常路径是 ScenarioData 在读完 story.json 之后主动调 apply_item_overrides()。
#     这里只是给「绕过 autoload 直接用静态函数」的场合（测试里常见）兜一道。
#   ★ 拿不到 ScenarioData 或它还没读完 story 时**不标记完成**，下次再试 ——
#     否则会在「story 尚未加载」的那一刻把空覆写当成最终结果，覆写就永远丢了。
static func _ensure_items() -> void:
	if _items_ready:
		return
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return
	var sd: Node = (loop as SceneTree).root.get_node_or_null("ScenarioData")
	if sd == null:
		return
	# ScenarioData.story_from_file 为 false 表示它还没读完（或没打算读）story.json
	if not bool(sd.get("story_from_file")):
		return
	_items_ready = true
	var ov: Variant = sd.call("item_overrides_override")
	apply_item_overrides((ov as Dictionary) if typeof(ov) == TYPE_DICTIONARY else {})

# 应用「服装数值覆写」。第四十轮新增，由 ScenarioData 在读完 story.json 后调用。
#   overrides 形如 { "top_plain": {"exposure": 3, "acceptance_req": 4}, ... }
#   ★ 只认 exposure 与 acceptance_req 两个字段 —— 其余字段（槽位 / 标签 / 贴图）
#     改了会让贴图与门控对不上，编辑器也不开放它们。
#   ★ 未知 id、非数字值、越界值一律跳过（宁可少改，也不要让一份坏数据把游戏弄崩）。
static func apply_item_overrides(overrides: Dictionary) -> void:
	# ★ 这里**不能**调 _ensure_items()（那会反过来去拉 ScenarioData 的覆写，
	#   与「ScenarioData 正在调我」形成一层无谓的递归）。
	#   直接标记「覆写已经应用过」即可。
	_items_ready = true
	_applied_overrides = {}
	if overrides.is_empty():
		return
	var by_id := {}
	for it in ITEMS:
		by_id[str(it.get("id", ""))] = it
	var applied := 0
	for raw_id in overrides.keys():
		var id := str(raw_id)
		if not by_id.has(id):
			push_warning("item_overrides 里有未知物品 id「%s」，已跳过" % id)
			continue
		var patch: Variant = overrides[raw_id]
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = by_id[id]
		var rec := {}
		for field in ["exposure", "acceptance_req"]:
			if not (patch as Dictionary).has(field):
				continue
			var v: Variant = (patch as Dictionary)[field]
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				push_warning("item_overrides[%s][%s] 不是数字，已跳过" % [id, field])
				continue
			var n := int(v)
			# 暴露值允许 -1 ~ 12（1 是「换装环节的难度」，12 是留给以后加档的余量）；
			# 接受度允许 0 ~ 99（它是个门槛，没有理论上限，给个宽松的护栏即可）
			if field == "exposure" and (n < -1 or n > 12):
				push_warning("item_overrides[%s].exposure = %d 超出 -1~12，已跳过" % [id, n])
				continue
			if field == "acceptance_req" and (n < 0 or n > 99):
				push_warning("item_overrides[%s].acceptance_req = %d 超出 0~99，已跳过" % [id, n])
				continue
			it[field] = n
			rec[field] = n
		if not rec.is_empty():
			_applied_overrides[id] = rec
			applied += 1
	if applied > 0:
		# 索引缓存是「从 ITEMS 现算」的，覆写之后必须重建，否则按 id / 槽位查还是旧值
		_invalidate_item_index()
	print("[OutfitData] 服装数值覆写：%d 件生效" % applied)

# 已生效的覆写（编辑器 / 测试用）
static func applied_item_overrides() -> Dictionary:
	return _applied_overrides.duplicate(true)

# 把 ITEMS 恢复成内置表（测试用：一个用例改完数值后清干净）
static func reset_items_to_base() -> void:
	ITEMS = ITEMS_BASE.duplicate(true)
	_applied_overrides = {}
	_items_ready = true
	_invalidate_item_index()


# ---------- 轮次进度 ----------
# acceptance_gain : 通关后接受度提升值
# contrast_req    : 进入质问环节所需的最低反差值（低于此值会被直接识破）
# derived_profile : 审讯官依据线索「推导出的形象」
#
# 一局（run）最多 4 关。数值曲线固定，轮次名与「推导形象」由本局抽到的背景
# 提供（见 ScenarioData.BACKGROUNDS[].levels，由 RunData.levels() 合并）。
#
# 曲线是怎么定的：
#   START_ACCEPTANCE = 10  →  各关开局接受度 10 / 15 / 20 / 26
#   暴露值上限 = 10 + 接受度 × 2  →  30 / 40 / 50 / 62
#   contrast_req 取「最差种子的最优解」再留 6 点余量 —— 因为原貌是随机抽的，
#   不同种子能拿到的上限差得很开，标定必须按**最差**那个来，否则会有人抽到
#   无法达标的组合。实测（10 种子 × 4 轮，全槽位反差口径）：
#     最差种子最优 155 / 185 / 205 / 230  →  标成 149 / 179 / 199 / 224。
#
# ★★ 第四十九轮整条曲线重标过一次（这是本项目第二次「换算法 + 重标」）：
#   · 反差从「只算上衣与下装」改成**全槽位求和**（用户口径）——
#     可达上限从 ~90 涨到 ~260，旧的 24/27/30/33 会变成四关全部白送；
#   · 原貌池同时放开 5 件中高暴露候选 —— 否则全槽位求和会退化成
#     「暴露值 × 系数」（共线），新曲线就没有意义了；
#   · START_ACCEPTANCE 6 → 10 —— 旧值下 7~9 档的 32 件里第 1 关只有 1 件能穿，
#     可选项太少；10 之后 7 档解锁，第 1 关的取舍才成立。
#   三件事必须一起改：只改口径不改曲线 = 白送，只抬曲线不放池 = 共线。
#
#   ★ 旧的注释里有一句「注意第 1 关不能定得太高：接受度只有 6」——
#     那个约束现在换了形式：第 1 关的 149 仍然是最紧的一档（实测最差种子 155，
#     余量只有 6），因为 cap 30 限制了「靠穿得露拿分」这条路。
#
# ---------- 以下是**旧口径**（只算上衣与下装）的历史记录，仅供追溯 ----------
# ★ 外袍下架（DISABLED_SLOTS）之后重标过一次：robe_lace 原本能贡献 5 点反差，
#   去掉后「每轮能拿到的最大反差」整体掉了 5 点左右，第 4 关尤其紧
#   （120 个种子实测：各关最大反差下限 61 / 73 / 83 / 83）。
# ★★ 第二十七轮又重标了一次（62/72 → 50/52），原因是一连串删减把反差上限压下来了：
#     · 删掉眉钉（反差 4）、洛丽塔短裙（5）、单片金链眼镜（4）、黑色墨镜（6）；
#     · 眼镜三副统一成反差 3（原为 1 / 4 / 6）—— 最高的那档没了；
#     · 手套槽位下架（4 件分别 2 / 4 / 5 反差）；
#     · `bottom_cut` / `bottom_school_navy` / `bottom_slit` 降级成普通下装。
#   120 个种子实测（DP 精确解，下限 / 上限）：45~48 / 54~65 / 54~73 / 54~73。
#   ★ 第 3、4 关的下限**都卡在 54** —— 那就是旧第 4 关的暴露上限
#     （`10 + 22 × 2 = 54`）。旧口径下想再拉高反差就得穿更暴露的衣服，而暴露值封顶了。
#   ★ 当时写的结论是「想把这根曲线抬回去，只有两条路：① 恢复外袍 / 手套槽位；
#     ② 补高反差低暴露的新物件」—— **第四十九轮走的是第三条路**：
#     改口径（全槽位）+ 放开原貌池，于是上面这套数字与结论一并作废。
#
# ★ 第二十五轮又重标过一次（73 → 72）：新增的 6 件高暴露衣物让「强制装备池」
#   变大，抽取用的随机流随之重排 —— 120 个种子 480 关里出现 1 关差 1 点
#   （seed=447514 第 4 关，强制 panties_lace + bottom_pleat，反差 72 < 73）。
#
# ★ 第二十三轮：「一局几轮」不再写死 —— `LEVELS` 变成**运行时表**，
#   从 `data/story.json` 的 "levels" 段读（编辑器里可增删轮次、改每轮的数值）。
#   下面这份 DEFAULT_LEVELS 是出厂兜底；文件缺失 / 那一段为空时用它。
# ★ 第七十五轮：START_ACCEPTANCE 14 → 10 —— 它现在只是**兜底起点**
#   （某一轮没写 `acceptance` 时才用它 + 局内 gain）。出厂两轮都手写了，
#   所以实际值是 10 / 19（暴露上限 30 / 48）。
#   ★ 为什么是 10：实测「可穿件数」到 10 就**封顶**了（132 / 137，
#     剩下 5 件是 req15 的极端款）；再往上只涨反差余量，不再多出选择。
const START_ACCEPTANCE := 10

# 反差值要求曲线的出厂参数（编辑器「⚙️ 数值规则」里可改）
#   · base —— 第 1 关的要求（后面留空的关都从它往上加）
#   · step —— 每轮自增多少
# ★ 第四十九轮：全槽位口径之后可达上限大了约 2.9 倍，base/step 同步抬。
#   step 取 30 是四档实际增量（30 / 20 / 25）的近似 —— 它只在
#   「某一关的 contrast_req 被留空」时才参与，而 DEFAULT_LEVELS 与
#   story.json 里四档都是**逐关手写**的，所以这条兜底不影响实际曲线。
const CONTRAST_REQ_BASE := 125
const CONTRAST_REQ_STEP := 15

# 反差值换算系数（第三十一轮）：每一档「暴露度差」算多少反差分。
#   见 WardrobeModel._contrast_of —— 反差 = |你穿的暴露度 − 原貌那件| × 它。
const CONTRAST_PER_EXPOSURE := 5

# 反差值换算系数（可在编辑器「⚙️ 数值规则」里改）
func contrast_per_exposure() -> int:
	return int(ScenarioData.rule_i("contrast_per_exposure", CONTRAST_PER_EXPOSURE))

# ---------- 同暴露值、但换了不同一件时的加分（第八十五轮）----------
#  用户口径：「同暴露值的不同件衣服增加 2 分，发型、妆容多加点」。
#  以前反差只有 |暴露值差| × 5：换一件完全不同、暴露值却一样的衣服记 0 分，
#  而发型 7 件全是露 0、眼镜 3 件 / 妆 5 件 / 鞋 3 件也大多是 0 ——
#  这几栏「怎么换都不涨分」。现在补一档「确实换了人」的分。
#
#  ★ 只在**暴露值没变**时加（变了的话 |差|×系数 已经在给分了，
#    再加一档等于同一件事算两遍）。
const CONTRAST_SAME_EXPOSURE_BONUS := 2
# 槽位专属值：这两栏是「一眼看过去最像不像同一个人」的地方，多给一点。
const CONTRAST_BONUS_HAIR := 12
const CONTRAST_BONUS_MAKEUP := 10

# 某槽位「同暴露值、不同件」加多少分。
#   发型 / 妆容各有一项自己的（可在编辑器「⚙️ 数值规则 → ⑥ 反差」里改），
#   其余槽位统一用基础分。
func contrast_same_exposure_bonus(slot: String) -> int:
	match slot:
		"hair":
			return ScenarioData.rule_i("contrast_bonus_hair", CONTRAST_BONUS_HAIR)
		"makeup":
			return ScenarioData.rule_i("contrast_bonus_makeup", CONTRAST_BONUS_MAKEUP)
	return ScenarioData.rule_i("contrast_same_exposure_bonus", CONTRAST_SAME_EXPOSURE_BONUS)

# ---------- 轮次开放状态（第二十一轮）----------
# 「开始游戏」不再直接开局，而是先让玩家在**选关面板**上挑进哪一关。
#
# ★ 第五十九轮（用户口径）：「点击开始游戏后的选择界面现在不再对第一关以外上锁」。
#   所以这张表现在把**两轮都列进去** —— 面板上每一行都点得动。
#   列表本身保留：以后想只开放某几轮，改这一行就行，别处都不用动。
const OPEN_LEVELS := [0, 1]

# 轮次表 / 关数 —— 惰性从 story.json 读一次（见 ScenarioData.levels_override）
# ★ 第四十一轮：**本局背景可以覆写它**（见 apply_run_overrides / _bg_levels）。
#   背景覆写的语义有两条：
#     · 数组**长度** = 这一局打几轮（所以「给某套背景只配 3 关」只要写 3 条）
#     · 每一条是对全局第 i 关的**逐键覆写**（数值部分：acceptance_gain / contrast_req /
#       questions_per_level；名字与推导形象仍由 RunData.levels() 从背景里叠 —— 见那里）
var LEVELS: Array = []
var MAX_LEVELS: int = 0

# 全局那份轮次表（不含任何背景覆写）—— 背景覆写时拿它当逐键覆写的底
var _global_levels_cache: Array = []

func global_levels() -> Array:
	if _global_levels_cache.is_empty():
		var ov: Array = ScenarioData.levels_override()
		var src: Array = ov if not ov.is_empty() else DEFAULT_LEVELS
		for lv in src:
			_global_levels_cache.append((lv as Dictionary).duplicate())
	return _global_levels_cache

func _ensure_levels() -> void:
	if not LEVELS.is_empty():
		return
	var src: Array = global_levels()
	# ★ 背景覆写的那一份（空 = 不覆写，关数照全局）
	var bg: Array = _bg_levels
	var n: int = bg.size() if not bg.is_empty() else src.size()
	if n <= 0:
		n = DEFAULT_LEVELS.size()
	LEVELS = []
	for i in n:
		var base := {}
		if i < src.size():
			base = (src[i] as Dictionary).duplicate()
		elif not DEFAULT_LEVELS.is_empty():
			# 背景配得比全局还多 —— 多出来的关用出厂表兜底，保证每一项都有值
			base = (DEFAULT_LEVELS[mini(i, DEFAULT_LEVELS.size() - 1)] as Dictionary).duplicate()
		# 逐键兜底：编辑器里少写一项也不会让这一轮没有数值。
		# ★ contrast_req 不在这里兜底 —— 它留空是有意义的（= 自增），
		#   由下面的 _resolve_contrast_req 统一算出来。
		for k in ["name", "acceptance_gain", "derived_profile"]:
			if not base.has(k) or str(base.get(k, "")) == "":
				base[k] = DEFAULT_LEVELS[0].get(k) if k != "name" \
					else "第 %d 轮" % (i + 1)
		# ★ 背景这一轮的覆写（逐键；只认数值类的键，名字那两项交给 RunData 叠）
		if i < bg.size() and typeof(bg[i]) == TYPE_DICTIONARY:
			for k in (bg[i] as Dictionary).keys():
				if k == "name" or k == "derived_profile":
					continue          # 名字与推导形象由 RunData.levels() 叠，别在这儿抢先
				base[k] = (bg[i] as Dictionary)[k]
		LEVELS.append(base)
	MAX_LEVELS = maxi(1, LEVELS.size())
	_resolve_contrast_req()

# ============================================================
#  反差值要求：自增 + 可手写覆盖（★ 第二十九轮）
#
#  用户口径：「轮次的反差值要求自增同时也可以修改」。
#
#  约定：**留空（或 0/负数）= 自动**。
#    · 第 1 关留空 → 用 `rules.contrast_req_base`（出厂 20）；
#    · 后面每一关留空 → 上一轮的**最终值** + `rules.contrast_req_step`（出厂 10）；
#    · 写了正数 → 直接用，并成为它后面那些关自增的新起点。
#
#  ★ 之所以是「以上一个手写值为锚点」而不是「统一按关号套公式」：
#    实际能拿到的最大反差受**暴露值上限**卡着（第 28 轮实测：第 3/4 关都卡在 60），
#    所以曲线未必是一条笔直的斜线 —— 允许在某一关插一个数、后面跟着抬，
#    比逼着人把每一关都手写一遍要实用。
#
#  ★ 解析结果写回 LEVELS[i].contrast_req，所以**下游（判定 / 界面 / 测试）读到的
#    永远是最终值**，不需要每处都去判断「这一轮是不是自动的」。
# ============================================================
func _resolve_contrast_req() -> void:
	var base := int(ScenarioData.rule_i("contrast_req_base", CONTRAST_REQ_BASE))
	var step := int(ScenarioData.rule_i("contrast_req_step", CONTRAST_REQ_STEP))
	var prev := base
	for i in LEVELS.size():
		var d: Dictionary = LEVELS[i]
		var raw: Variant = d.get("contrast_req", null)
		var given := -1
		if raw != null:
			# 编辑器里留空会写成 0，所以 0 也算「没写」
			given = int(raw)
		if given > 0:
			prev = given                       # 手写的值：既是本轮的要求，也是后面的起点
		else:
			prev = prev + step if i > 0 else base
		d["contrast_req"] = prev

# 这一轮的要求是「手写的」还是「自增出来的」——
# 只给界面显示用（判定与测试都只读解析后的 contrast_req）。
func contrast_req_is_auto(li: int) -> bool:
	_ensure_levels()
	var ls: Array = ScenarioData.levels_override()
	if ls.is_empty():
		ls = DEFAULT_LEVELS
	if li < 0 or li >= ls.size():
		return true
	var raw: Variant = (ls[li] as Dictionary).get("contrast_req", null)
	return raw == null or int(raw) <= 0

func levels() -> Array:
	_ensure_levels()
	return LEVELS

func level_count() -> int:
	_ensure_levels()
	return MAX_LEVELS

# 测试 / 编辑器改完之后要让缓存失效
func reload_levels() -> void:
	_global_levels_cache = []
	LEVELS = []
	MAX_LEVELS = 0
	_ensure_levels()

# ============================================================
#  第四十一轮：按背景覆写「本局的流程配置」
#
#  用户口径：「每局游戏应该能够设置不同强制穿着，qte计划，身体缺陷，
#            轮次轮数，原貌」，并补充「原貌也是按背景的四关每轮都可以设置不同的」。
#
#  这五项都挂在背景上（`backgrounds[i]` 下同名键），默认（背景里不写）时
#  完全等于以前的行为。运行时由 `RunData.start_new_run()` 抽完背景后调
#  `apply_run_overrides(bg_id)` 灌进来 —— 走的是「原地改运行表」这条路，
#  和第四十轮的 `apply_item_overrides()` 同一个模式，
#  所以 `level_count()` / `forced_rules_at()` / `defects()` 这些既有入口
#  **一行都不用改**就自动看到本局那一份。
#
#  ★ 为什么不让各读取点自己去查背景：OutfitData 是 autoload，它不知道
#    「当前是哪一套背景」；而 RunData 知道。把「本局那份」灌进来，
#    比给每个读取函数加一个 bg_id 参数干净得多（后者要改几十个调用点）。
# ============================================================
var _bg_levels: Array = []       # 本局背景覆写的轮次表（长度 = 本局打几轮）
var _bg_forced: Array = []       # 本局背景覆写的强制穿着表
var _bg_defects: Array = []      # 本局背景覆写的缺陷表
var _bg_defects_declared: bool = false   # ★ 第八十三轮：这套背景写过 defects 吗（`[]` 也算）

func apply_run_overrides(bg_id: String) -> void:
	_bg_levels = ScenarioData.bg_levels(bg_id)
	_bg_forced = ScenarioData.bg_forced_rules(bg_id)
	_bg_defects = ScenarioData.bg_defects(bg_id)
	# ★ 第八十三轮：这套背景**写过** defects 吗？写了（哪怕是 `[]`）= 这套就是没有缺陷，
	#   不再回退到全局那份 —— 否则「作者明明没设，游戏却给他补了 2 处」。
	_bg_defects_declared = ScenarioData.bg_has_defects(bg_id)
	reload_run_tables()

# 回到「没有背景覆写」的状态（测试 / 退出局时用）
func clear_run_overrides() -> void:
	_bg_levels = []
	_bg_forced = []
	_bg_defects = []
	_bg_defects_declared = false
	reload_run_tables()

# 丢掉本局那三张表并让它们按当前覆写重建
func reload_run_tables() -> void:
	LEVELS = []
	MAX_LEVELS = 0
	_ensure_levels()
	FORCED_RULES = []
	_ensure_forced_rules()
	DEFECTS = []
	_ensure_defects()

# 本局生效的覆写（编辑器 / 测试用）
func run_levels_override() -> Array:
	return _bg_levels.duplicate(true)

func run_forced_override() -> Array:
	return _bg_forced.duplicate(true)

func run_defects_override() -> Array:
	return _bg_defects.duplicate(true)

# 越界的下标夹回合法范围
func level_at(li: int) -> Dictionary:
	_ensure_levels()
	return LEVELS[clampi(li, 0, MAX_LEVELS - 1)]

func level_unlocked(li: int) -> bool:
	return OPEN_LEVELS.has(li)

# 已开放的关数（面板 / 摘要文案用）
func open_level_count() -> int:
	var n := 0
	for i in level_count():
		if level_unlocked(i):
			n += 1
	return n

# ---------- 强制装备 ----------
#  设定：有些场合你没法自己决定穿什么 —— 府里发了号衣、海关要求穿查验服、
#        场子里给「新人」统一配的行头。这就是「强制服装要求」。
#
#  ★ 第二十三轮：每轮的强制要求改成**一张可编辑的规则表**
#    （见 FORCED_RULES / forced_groups_at）。三种模式：
#      · "none"   —— 本轮没有强制要求；
#      · "random" —— 沿用旧的随机抽 0~2 件高暴露（出厂默认的第 2~4 关）；
#      · "fixed"  —— 用 rules 里写死的规则，每条规则二选一：
#                      {"pick": "all", "items": [...]}  这几件**都要穿**（只有一件就是「固定一件」）
#                      {"pick": "any", "items": [...]}  这几件里**任选一件**
#                    多条规则自由叠加 —— 这就是用户口径里的「自由组合」。
#
#  随机抽（random 模式）的三条硬规则：
#    1. 只会抽「高暴露」的衣物 —— 朴素的没法糊过去，必须是露的那类；
#    2. 数量 0 ~ 2 件，最少可以一件都没有；
#    3. 必须是你当前接受度穿得起的。
#
#  注意强制装备本身也是一把双刃剑：它们暴露值高，吃预算；
#  但反差值同样高，反而帮你拉开与原貌的差距。
const FORCED_EXPOSURE_MIN := 5
const FORCED_MAX := 2

# ★ 第四十九轮：**永不被强制装备占用**的槽位。
#   理由与 `forced_locked_out_slots()` 同源 —— 锁死一格 = 本轮死局。
#   「下装」与「成装」被锁死时会同时废掉两条最大的反差杠杆：
#     · 「下装 → 不穿」这一格差 9 档（= 45 点反差）；
#     · 下装不够露时「内裤」整格不计数（再少 9 档）。
#   实测（40 种子 × 4 轮，真实求解器）：把 `bottom` 放进强制池时，
#   第 2 轮带强制件的可达下限是 **130**（中位 215）；排除后下限抬到 205 上下。
const FORCED_NEVER_SLOTS := ["bottom", "dress"]

const PICK_ALL := "all"      # 这几件都要穿（列一件 = 固定一件）
const PICK_ANY := "any"      # 这几件里任选一件

const FORCED_MODE_NONE := "none"
const FORCED_MODE_RANDOM := "random"
const FORCED_MODE_FIXED := "fixed"

# ★★ 第二十九轮：反差值要求改成「**自增 + 可手写覆盖**」。
#
#   用户口径：「轮次的反差值要求自增同时也可以修改」。
#
#   规则（见 _resolve_contrast_req）：
#     · 第 1 关写一个基线值（出厂 20）；
#     · 后面每一关**留空** → 自动 = 上一轮 + `rules.contrast_req_step`（出厂 10）；
#     · 任何一关**写了数字** → 就用它，并且成为它后面那些关自增的新起点。
#
#   所以「自增」不是固定公式，而是一条**以手写值为锚点**的阶梯 ——
#   你可以在任意一关插一个数，后面整段跟着抬起来。
const DEFAULT_LEVELS := [
	# ★★ 第七十五轮（用户口径「暂时不使用接受度全局累计，改为每轮可用的暴露值不同」）：
	#   每轮多了一个 `acceptance` —— **这一轮用多少接受度**（留空 = 起始值 + 局内累计）。
	#   它同时决定两件事：能穿哪些（`acceptance_req ≤ 接受度`）与**暴露值上限**
	#   （`10 + 接受度 × 2`）。想要某一轮上限 = 30，就写 acceptance = 10。
	#   ★ 这两个数是**实测定的**（第六背景 × 24 种子，真实求解器 `auto_complete_outfit`）：
	#     第 1 轮 acc10 cap30 → 可达反差 **145 ~ 185**（中位 165），要求 125 → 最差余量 +20；
	#        acc8 cap26 → 113 件可穿、最差**刚好 125**（零余量，不能再用）；
	#        acc10 起可穿件数**到顶**（132 / 137，只剩 5 件 req15 的极端款锁着）——
	#        所以 10 就是「衣服足够多」的那一档，再往上只涨余量、不涨选择。
	#     第 2 轮 acc19 cap48 → 与旧曲线完全一致（要求 150，最差余量 +5）。
	{"name": "第一轮", "acceptance": 10, "acceptance_gain": 5, "contrast_req": 125, "derived_profile": "一个不起眼的路人"},
	# ★★ 第五十二轮：**一局从 4 轮压成 2 轮**（用户口径「现在的四个背景改成两轮」）。
	#   于是这里只剩两条 —— 曲线也从 4 档压成 2 档。
	#   ★ 轮次名改成**通用**的「第一轮 / 第二轮」：原来每套背景在自己的
	#     `levels` 里写了按地点递进的 4 个名字（「外栅栏哨位 → 查验棚 → 哨所长官室 →
	#     关隘地牢前厅」），压成 2 轮之后留哪两个都是取舍，用户口径是
	#     「改成通用『第一轮 / 第二轮』，具体地点交给背景自己的场景描述」——
	#     所以每套背景的 `levels` 覆写**整段删掉**，统一回落到这里。
	#   ★ derived_profile 也一并回落：原来每套背景各写各的（「一个赶路的行商」这种），
	#     现在统一用这两条通用形象。
	#   ★ 曲线 125 / 150 —— **实测定的，不是拍的**。
	#     150 种子真实求解器（`auto_complete_outfit()`，DP + 缺陷掩码）量出的可达区间：
	#       第 1 轮 acc14 cap38 → **205 ~ 210**（中位 210）
	#       第 2 轮 acc19 cap48 → **155 ~ 215**（中位 215）
	#     所以第 2 轮**写不了 160** —— 最不利的那个原貌最多只能到 155，
	#     写 160 会让那批种子当场无解（卡关）。取 150 留 +5 余量。
	#     ★ 注意「中位 215」：绝大多数种子的余量其实很大（+65），
	#       只有最不利的那个原貌紧到 +5 —— 这是本作一贯的形态（原貌决定难度）。
	#   ★ 第 2 轮的上限为什么更低：原貌预设把 `stockings` 钉在 9 档
	#     （`stockings_sheerskin`），而 9 档是这一栏最露的 ——
	#     「脱到最露」的差反而是 0，只能改穿保守袜（+9），这一栏就封顶了。
	{"name": "第二轮", "acceptance": 19, "acceptance_gain": 5, "contrast_req": 150, "derived_profile": "有点来头的商贩"},
]

# 出厂兜底的强制规则表（下标 = 第几轮）。
#   第 1 轮刻意留空 —— 开局就被人按着头穿某件衣服不公平（见 RunData._roll_forced_items）；
#   后几轮沿用旧的随机抽，所以升级到「规则表」之后玩法一点没变。
#   ★ 第八十轮：这只管**出厂兜底**。作者在编辑器里写死（fixed）的规则，
#     第 1 轮也照办 —— 以前那句 `li <= 0` 把 fixed 也一起跳过了，
#     于是「背景里给第 1 轮配了强制穿着」永远不生效。
const DEFAULT_FORCED_RULES := [
	# ★ 第五十二轮：4 → 2 轮，跟着砍到两条。
	#   原口径是「第 1 轮不强制、第 2 轮起开始抽一件强制装备」——
	#   两轮的版本保留这个递进：第 1 轮 none、第 2 轮 random。
	{"mode": "none", "rules": []},
	{"mode": "random", "rules": []},
]

# ---------- 每题的 QTE 计划（第二十三轮，编辑器可改）----------
#  用户口径：「编辑器还应该具备编辑……每个问题的 qte 类型 出现时间」
#
#  一局里每一道题都可以指定用哪种 QTE、几秒后出现。取值：
#    "none"         —— 这道题不出 QTE —— **没写就是这个**（第八十轮用户口径：
#                      「未设置 qte 的题目不该冒 QTE」）；
#    "auto"         —— 按老规则自动判（表情 QTE 看 needs_expression_for，
#                      递话走计时器随机来）—— 必须**显式写**才生效；
#    "expression"   —— 强制出表情控制（长按顶条）；
#    "interference" —— 指定时间后出单键递话（按一下空格打断）；
#    "combo"        —— 指定时间后出组合干扰（依次敲 J → K → L）。
#
#  delay 单位是秒：表情类是「切题后多久弹出面板」，递话类是「切题后多久他开口」。
#  没写 delay（或 ≤ 0）→ 用该类型的出厂默认值（expr_qte_delay / interference_base）。
const QTE_AUTO := "auto"
const QTE_NONE := "none"
const QTE_EXPRESSION := "expression"
const QTE_INTERFERENCE := "interference"
const QTE_COMBO := "combo"

const QTE_KINDS := [QTE_AUTO, QTE_NONE, QTE_EXPRESSION, QTE_INTERFERENCE, QTE_COMBO]

const QTE_KIND_LABELS := {
	"auto": "自动（按暴露值判）",
	"none": "无",
	"expression": "表情控制 QTE（长按顶条）",
	"interference": "递话打断（按一下空格）",
	"combo": "组合干扰（依次敲 J→K→L）",
}

# 第 li 道题的 QTE 计划（读 story.json；越界 / 没写 = 「不出」）
func qte_plan_entry(li: int) -> Dictionary:
	var d := ScenarioData.qte_plan_at(li)
	if d.is_empty():
		return {"qte": QTE_NONE, "delay": -1.0}
	var kind := str(d.get("qte", QTE_NONE))
	if not QTE_KINDS.has(kind):
		kind = QTE_NONE
	return {"qte": kind, "delay": float(d.get("delay", -1.0))}

# 一道题**最终生效**的 QTE 安排（第八十轮）
#
#  优先级：题目自带的 `qte` ＞「按题号」的全局计划表 ＞ 不出。
#
#  ★ 用户口径：「未设置 qte 的题目为什么还会出现 qte 改掉」。
#    以前「没写」= auto（按暴露值随机出），于是每道题都可能突然冒一条 QTE 条。
#    现在「没写」= none；想按暴露值自动出，必须在编辑器里**显式**选「自动」。
#
#  ★ 编辑器第七十九轮之前把类型写在 `qte.qte` 里（现行是 `qte.kind`），
#    游戏只认 `kind` → 用户在编辑器里写「无」等于没写。
#    这里两个键都认，老数据不用重存。
func question_qte_plan(q: Dictionary, index: int) -> Dictionary:
	var base := qte_plan_entry(index)
	var out := {
		"qte": str(base.get("qte", QTE_NONE)),
		"delay": float(base.get("delay", -1.0)),
		"prompt": "",
	}
	if not q.has("qte"):
		return out
	var own: Variant = q.get("qte")
	if typeof(own) == TYPE_DICTIONARY:
		var od: Dictionary = own
		# 两个键都认：`kind` 是现行写法，`qte` 是旧版编辑器写的
		var k := str(od.get("kind", od.get("qte", ""))).strip_edges()
		if k == "":
			k = QTE_NONE          # 对象里什么都没写 = 没设置
		out["qte"] = k if QTE_KINDS.has(k) else QTE_NONE
		if od.has("delay"):
			out["delay"] = float(od.get("delay", -1.0))
		out["prompt"] = str(od.get("prompt", ""))
	elif typeof(own) == TYPE_STRING:
		var s := str(own).strip_edges()
		out["qte"] = s if QTE_KINDS.has(s) else QTE_NONE
	return out

# ---------- A 的原貌（True Appearance）----------
# 审讯官认识的是「A」—— 你真实的样子。他脑子里存着这张脸、这身打扮。
# 反差值的语义由此确定：**只有与原貌不同的槽位才贡献反差值**。
# 穿得和原貌一样 = 反差 0 = 一眼就被认出来。
#
# 多轮制之后，原貌不再是常量 —— **每一局都会重新随机**（见 RunData）。
# 下面这张 TRUE_POOL 就是随机池：每个槽位列出 1~3 件「A 有可能的样子」。
#
# 入池的硬性条件（测试会断言）：
#   1. 暴露值 ≤ 2 —— A 是个低调的人，而且第 1 关暴露值上限只有 22，
#      原貌本身绝不能一开局就超限；
#   2. 必须在 ScenarioData.ITEM_DESC 里有对应的目击描述，否则外貌情报拼不出来。
#
# 关键两难：原貌里可能有一件「高领长袖衬衫」，同时遮住颈侧烙印与手背刺青。
# 那就意味着想与它相反，必须把遮挡责任转移到别的槽位（颈饰 / 手套），
# 否则一脱下高领就露出烙印 —— 这正是本作的核心张力。
# 但原貌也可能是短袖 + 空脖子，那样你反而必须主动去遮 —— 每局都不一样。
const TRUE_POOL := {
	"hair": ["hair_short", "hair_braid", "hair_long"],
	"headgear": ["head_none", "head_hat"],
	"glasses": ["glasses_none", "glasses_round"],
	"earrings": ["ear_none", "ear_stud"],
	"makeup": ["makeup_none", "makeup_light"],
	"piercing": ["piercing_none", "piercing_multi"],
	"tattoo": ["tattoo_none", "tattoo_neck"],
	"neckwear": ["neck_none", "neck_collar", "neck_scarf"],
	# ★★ 第四十九轮：反差改成**全槽位求和**之后，这一池必须一起放开。
	#
	#   为什么：原貌池原来刻意只收「暴露值 ≤ 2」的件（理由是「A 是个低调的人」），
	#   于是 `Σ|你穿的 − 原貌|` 里原貌那一项几乎恒为 0，公式退化成 `Σ你穿的`
	#   —— 也就是**暴露值 × 系数**。实测（120 种子）口径 B 的最优值精确落在
	#   `暴露上限 × 5` 这条线上，一毫不差：反差不再是独立指标，只是暴露值的别名。
	#
	#   要打破它，唯一的路是让原貌**也可能穿得露** —— 那样「你比他保守」
	#   也能得分，而「穿保守」几乎不吃暴露值预算，曲线才立得住。
	#
	#   入池的 5 件都满足三条：
	#     ① 名字看起来是日常着装（不是乳贴 / 开档这种一眼就「不像 A」的东西），
	#        所以「A 平时也穿这些」在设定上说得通；
	#     ② 门槛 ≤ START_ACCEPTANCE(10)，第 1 轮就抽得到；
	#     ③ 全是**已在池外**的既有物品，一件新衣服都没有加。
	#
	#   ★ 为什么不把 bra_lace（黑色蕾丝内衣，暴露 4）也放进来：
	#     放进来之后「最坏情况原貌暴露合计」会到 33，而第 1 关的暴露上限只有
	#     `10 + 10 × 2 = 30` —— 原貌自己就超上限了，「穿得和他一模一样」
	#     这条路会被封死（情报台全中变得不可能）。去掉它正好压到 29 ≤ 30。
	#     这条约束由 `WardrobeTest._pool_within_first_cap()` 守着。
	"top": ["top_highneck", "top_plain", "top_longsleeve", "top_sheer"],
	"bra": ["bra_plain"],
	"gloves": ["gloves_none", "gloves_leather"],
	# ★ 第三十四轮：黄铜胸针被整件删掉，这一栏的候选也跟着收敛成**只有空件**。
	#   效果是「A 的原貌从此不戴配饰」—— 目击情报里这一句恒定是
	#   「没有一件多余的物件，干干净净」。
	"accessory": ["acc_none"],
	"bottom": ["bottom_longskirt", "bottom_trousers", "bottom_cut"],
	# ★ 第二十六轮新增的整件式槽位：A 的原貌可能穿着一件素色成装，
	#   也可能什么都没穿（dress_none 的暴露值是 0 —— 「没穿成装」只是穿着
	#   上衣 + 下装而已，不暴露）。晚礼服不入池：那件太扎眼，不像 A 的日常。
	#
	# ★★ 第二十七轮：成装与上装 / 下装互斥（EXCLUSIVE_GROUPS）之后，这一池**只剩下空件**。
	#   原因：原貌是一张「每槽位一件」的表，而互斥意味着「成装」与「上装+下装」是
	#   两种互斥的穿法 —— 若让 dress_sundress 入池，就必须在抽签后把落败的一方
	#   归一化掉，而落败方压成空件（top_none 暴露 9 / bottom_none 暴露 9 反差 8）
	#   反而会白送数值，情报台也会同时报出两条自相矛盾的目击（见 _counts_with 的互斥闸）。
	#   所以干脆不在源头制造冲突：**A 的原貌永远是「上衣 + 下装」**，
	#   成装留给玩家主动去穿 —— 那才是「单开一栏」的玩法价值。
	#   ★ 第四十九轮改全槽位反差之后这条**依然不变** —— 成装的暴露值很高
	#     （最高 9），放进池子会直接把「最坏情况原貌」顶穿第 1 关上限。
	"dress": ["dress_none"],
	"panties": ["panties_plain", "panties_thong"],
	"stockings": ["stockings_none", "stockings_opaque", "stockings_sheer"],
	"shoes": ["shoes_boots", "shoes_heels"],
	"robe": ["robe_none", "robe_travel"],
}

# 默认原貌（池中首项）—— 仅用于「没有 RunData 参与」的场合（单元测试等）。
# 正常游戏流程里请一律走 RunData.true_appearance()。
const TRUE_APPEARANCE := {
	"hair": "hair_short",
	"headgear": "head_none",
	"glasses": "glasses_none",
	"earrings": "ear_none",
	"makeup": "makeup_none",
	"piercing": "piercing_none",
	"tattoo": "tattoo_none",
	"neckwear": "neck_none",
	"top": "top_highneck",
	"bra": "bra_plain",
	"gloves": "gloves_none",
	"accessory": "acc_none",
	"bottom": "bottom_longskirt",
	"dress": "dress_none",
	"panties": "panties_plain",
	"stockings": "stockings_none",
	"shoes": "shoes_boots",
	"robe": "robe_none",
}

# ---------- 初始套装 ----------
# 开局即 A 的原貌 —— 你还没来得及伪装自己。
# 实际取值由 WardrobeModel 从「本局随机出的原貌」里取，这里只是兜底定义。
const DEFAULT_LOADOUT := TRUE_APPEARANCE

# 强制装备用独立随机流（见 RunData._roll_forced_items）
func forced_rng_seed_base() -> int:
	return 40503

# ---------- 每轮的强制规则表 ----------
# 惰性从 story.json 的 "forced_rules" 段读；出厂兜底见 DEFAULT_FORCED_RULES。
var FORCED_RULES: Array = []

func _ensure_forced_rules() -> void:
	if not FORCED_RULES.is_empty():
		return
	# ★ 第四十一轮：本局背景覆写优先（空则回退全局那份）
	var ov: Array = _bg_forced if not _bg_forced.is_empty() else ScenarioData.forced_rules_override()
	var src: Array = ov if not ov.is_empty() else DEFAULT_FORCED_RULES
	FORCED_RULES = []
	for e in src:
		var d: Dictionary = (e as Dictionary).duplicate()
		var mode := str(d.get("mode", FORCED_MODE_RANDOM))
		if not [FORCED_MODE_NONE, FORCED_MODE_RANDOM, FORCED_MODE_FIXED].has(mode):
			mode = FORCED_MODE_RANDOM
		var rules := []
		for r in d.get("rules", []):
			var rd: Dictionary = (r as Dictionary).duplicate()
			var pick := str(rd.get("pick", PICK_ALL))
			if pick != PICK_ANY:
				pick = PICK_ALL
			var items := []
			for id in rd.get("items", []):
				# 只收「真实存在、且当前槽位没下架」的物品 ——
				# 编辑器里写错一个 id 不该让整关崩掉
				var it: Dictionary = get_item(str(id))
				if it.is_empty() or not slot_enabled(str(it.get("slot", ""))):
					continue
				items.append(str(id))
			if not items.is_empty():
				rules.append({"pick": pick, "items": items})
		# ★★ 第八十三轮（用户口径）：「第一套同样为什么有强制穿着的要求」——
		#   第 80 轮这里干过一件事：`mode` 不是 fixed 但有规则时，**自动升级成 fixed**
		#   （当时怕「配了规则忘了改 mode，规则被静默丢掉」）。结果适得其反：
		#   数据里 `{"mode":"none","rules":[{"items":["hair_short"]}]}` 这种自相矛盾的
		#   残留，本来按 none 什么都不该强制，却因为升级变成了「必须穿利落短发」——
		#   「我明明选的是没有强制要求」和「实际被强制」直接打架。
		#   现在**不做任何升级**：mode 说 none 就是没有要求；写矛盾了由编辑器报错提醒。
		FORCED_RULES.append({"mode": mode, "rules": rules})
	for li in range(FORCED_RULES.size(), level_count()):
		FORCED_RULES.append({"mode": FORCED_MODE_NONE, "rules": []})

func reload_forced_rules() -> void:
	FORCED_RULES = []
	_ensure_forced_rules()

# 第 li 关的强制规则（越界夹回最后一关；轮次比规则表多时按「没有要求」处理）
func forced_rules_at(li: int) -> Dictionary:
	_ensure_forced_rules()
	if FORCED_RULES.is_empty():
		return {"mode": FORCED_MODE_NONE, "rules": []}
	return FORCED_RULES[clampi(li, 0, FORCED_RULES.size() - 1)]

# 第 li 关「写死」的那些规则（mode != fixed 时为空）
func forced_groups_at(li: int) -> Array:
	var e := forced_rules_at(li)
	if str(e.get("mode", "")) != FORCED_MODE_FIXED:
		return []
	return e.get("rules", [])

# ---------- 查询接口 ----------
# ★ 索引缓存：这两张表以前是**每次线性扫 ITEMS**（102 件）——
#   换装界面的贪心/DP 一次要问几万遍，实测能把测试拖到超时。
#   ★ 第四十轮：ITEMS 不再是 const（支持数值覆写），所以**覆写之后必须重建**
#     —— 见 _invalidate_item_index()。
# ★ 第四十轮：这三张缓存改成 static var —— apply_item_overrides() 是 static func，
#   实例成员它够不着。实例方法读 static var 完全合法，所以调用点不用改。
static var _by_slot: Dictionary = {}
static var _by_id: Dictionary = {}

func _build_index() -> void:
	if not _by_id.is_empty():
		return
	_ensure_items()
	for it in ITEMS:
		var id := str(it.get("id", ""))
		_by_id[id] = it
		var slot := str(it.get("slot", ""))
		if not _by_slot.has(slot):
			_by_slot[slot] = []
		_by_slot[slot].append(it)

# 丢掉索引缓存与满值缓存，下次访问时重建（数值覆写之后调）
static func _invalidate_item_index() -> void:
	_by_slot = {}
	_by_id = {}
	_stat_max = {}

func get_items_for_slot(slot: String) -> Array:
	if not slot_enabled(slot):
		return []           # 下架的槽位：对外就是「一件都没有」
	_build_index()
	return _by_slot.get(slot, [])

func get_item(id: String) -> Dictionary:
	if id == "":
		return {}
	_build_index()
	return _by_id.get(id, {})

func exposure_cap(acceptance: int) -> int:
	return EXPOSURE_BASE + acceptance * EXPOSURE_PER_ACCEPTANCE

# ---------- 三个数值的「满值」----------
#  卡片上那 7 颗点要按「这件东西的最大量级」切档，量表也要知道量程。
#  满值**从 ITEMS 现算**并缓存 —— 以后改物品数值不用回来改常量表。
static var _stat_max: Dictionary = {}

func stat_max_of(field: String) -> int:
	if _stat_max.is_empty():
		for f in ["exposure", "contrast", "acceptance_req"]:
			var mx := 1
			for it in ITEMS:
				if not slot_enabled(str(it.get("slot", ""))):
					continue    # 下架的槽位不参与「满值」标定
				mx = maxi(mx, int(it.get(f, 0)))
			_stat_max[f] = mx
	return maxi(1, int(_stat_max.get(field, 1)))

# ---------- 强制装备 ----------
func is_high_exposure(item: Dictionary) -> bool:
	return int(item.get("exposure", 0)) >= FORCED_EXPOSURE_MIN

# 本轮「可能被强制穿上」的物品池：高暴露 且 接受度够
#   ★ 排除 `bare` 的空件 —— 「强制你（不穿上衣）」不是一条说得通的指令，
#     那是「不许穿」而不是「必须穿」，语义和强制装备相反。
func forced_pool(acceptance: int) -> Array:
	var out := []
	var locked := forced_locked_out_slots()
	for it in ITEMS:
		var slot := str(it.get("slot", ""))
		if not slot_enabled(slot):
			continue        # 下架的槽位抽不出来 —— 否则会强制玩家穿一件他没得选的袍子
		if is_manual_slot(slot):
			continue        # ★ 第三十九轮：妙妙工具只能手动装备，永不强制
		if locked.has(slot):
			continue        # 见 forced_locked_out_slots()：锁死这个槽位 = 本轮死局
		if FORCED_NEVER_SLOTS.has(slot):
			continue        # 见 FORCED_NEVER_SLOTS：下装 / 成装一锁就废掉最大的反差杠杆
		if is_bare(it):
			continue
		if is_high_exposure(it) and can_equip(it, acceptance):
			out.append(it)
	return out

# ---------- 不准被强制装备占用的槽位（第二十七轮）----------
# 某个身体缺陷的**全部可用遮挡物**都集中在同一个槽位时，那个槽位就是它的唯一解 ——
# 强制装备一旦锁死它，玩家就再也遮不住这处缺陷，本轮直接变成死局。
#
# ★ 现在撞上的是 `hand_tattoo`（右手背黑帮血蛇刺青）：它的 `cover_tags` 是
#   `glove` / `long_sleeve`，而 `gloves` 槽位第二十七轮下架了 →
#   唯一还能遮它的只剩上衣槽那两件长袖（`top_highneck` / `top_longsleeve`）。
#   于是「强制穿 `top_lace` / `top_crop` / `top_offshoulder` 这类短袖款」
#   = 手背刺青必露 + 上衣被锁死换不掉 → 无解。
#   （实测：120 种子 × 4 关里出现 6 例，全都是这个原因。）
#
# ★ 这条规则是**算出来的**，不是写死的 —— 「唯一解」随可用物品自动变化：
#   将来把手套栏恢复，top 就不再是唯一解，它自动重新变成可强制的槽位。
#
# 注意 `neck_brand`（颈侧烙印）**不会**把 top 锁进去：它的 `cover_tags` 是
# `high_collar` / `scarf`，除了上装的长袖款，颈饰槽的 `neck_collar` / `neck_scarf`
# 也能遮 —— 集合是 {top, neckwear} 而不是单元素，所以 top 不必为它让路。
var _locked_slots_cache: Array = []

func forced_locked_out_slots() -> Array:
	if not _locked_slots_cache.is_empty():
		return _locked_slots_cache
	var out := []
	for d in defects():
		var need: Array = (d as Dictionary).get("cover_tags", [])
		if need.is_empty():
			continue
		var slots := []
		for it in ITEMS:
			var s := str(it.get("slot", ""))
			if not slot_enabled(s):
				continue
			var hit := false
			for t in it.get("tags", []):
				if need.has(str(t)):
					hit = true
					break
			if not hit:
				continue
			if not slots.has(s):
				slots.append(s)
		if slots.size() == 1:
			out.append(str(slots[0]))
	# ★ 第三十七轮补：把「互斥牵连」也算进来 —— 某个槽位被锁死时，
	#   与它互斥的槽位**同样不能**被强制装备占用。
	#   理由：成装与上装 / 下装互斥（见 EXCLUSIVE_GROUPS），穿上成装就会把上装清空。
	#   而手背刺青的唯一遮挡物就在上装（手套栏下架后只剩长袖上衣）——
	#   一旦强制穿成装，上装就永远穿不回来，本轮直接死局。
	#   实测：补了 8 件高暴露成装之后，120 种子 × 4 关里出现 1 例
	#   `forced=["dress_cheongsam", "bottom_pvc"]`（成装 + 下装本身也穿不到一起）。
	#   这条同样是**算出来的**：将来手套栏恢复，上装不再是唯一解，成装自动解锁。
	var with_peers := []
	for s in out:
		if not with_peers.has(str(s)):
			with_peers.append(str(s))
		for p in exclusive_peers(str(s)):
			if not with_peers.has(str(p)):
				with_peers.append(str(p))
	_locked_slots_cache = with_peers
	return with_peers

func can_equip(item: Dictionary, acceptance: int) -> bool:
	return acceptance >= int(item.get("acceptance_req", 0))

# 某槽位「最朴素」的物品（暴露值最低、同值时反差最低）
func cheapest_for_slot(slot: String) -> Dictionary:
	var best := {}
	for it in get_items_for_slot(slot):
		if best.is_empty():
			best = it
			continue
		var a := [int(it["exposure"]), int(it["contrast"])]
		var b := [int(best["exposure"]), int(best["contrast"])]
		if a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]):
			best = it
	return best
