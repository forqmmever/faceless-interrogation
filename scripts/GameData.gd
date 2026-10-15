extends Node

# --- Game Data Singleton / Autoload ---

# Character Attributes
var character_name: String = "伪装者·罗兰"
var body_defect: String = "右手背刺青 (无法轻易解释的黑帮标记)"
var defect_location: String = "right_hand" # right_hand, neck, torso

# Disguise Setup
# 注意：早期的"三选一伪装预设"已被完整的 18 槽位换装系统取代，
# 相关字段（selected_build / selected_clothing / selected_piercing / calculate_coverage）
# 已删除，改由 WardrobeModel 计算后写入下方结果区。
var is_defect_covered: bool = true
var visual_distraction_power: float = 0.4 # 转移审讯官注意力的数值（由反差值换算）

# Interrogation State
var suspicion_level: float = 20.0 # 0 ~ 100
var max_suspicion: float = 100.0

# ---- 怀疑度机制（第十三轮）----
#  · 轮内只涨不跌：所有「奖励」的负增量一律归零（见 Interrogation._add_suspicion）。
#  · 轮次之间按比例衰减：上一轮结束时带过来的怀疑度 × SUSPICION_DECAY，
#    作为下一轮的开局怀疑度。
#  · 怀疑度提升的数值整体调高了（见 Interrogation 各常量与 story.json 的性情表）。
const SUSPICION_BASE := 20.0      # 第 1 关开局怀疑度
const SUSPICION_DECAY := 0.5      # 轮次之间：怀疑度按此比例衰减（对折）
const SUSPICION_FLOOR := 10.0     # 衰减后的下限（不会一路归零）
var suspicion_carry: float = 0.0  # 上一轮**通过时**的结束怀疑度（供下一轮衰减用）

# --- 换装系统结果（由 WardrobeModel 写入）---
var acceptance: int = 0              # 接受度（每轮后提升）
var level_index: int = 0             # 当前轮次
var outfit_exposure: int = 0         # 暴露值总和
var outfit_exposure_cap: int = 10    # 暴露值上限
var contrast_total: int = 0          # 反差值总和
var contrast_required: int = 0       # 反差值要求
var contrast_sufficient: bool = false
var matching_slots_count: int = 0    # 仍与 A 原貌一致的槽位数
var defects_covered: bool = false
var uncovered_defects: Array = []

# --- 妙妙工具（第三十九轮）---
# 本轮**实际携带**的妙妙工具物品 id（由 Wardrobe.sync_outfit_verdict() 写入）。
# 这一栏是「只能手动装备」的：它不参与原貌 / 强制 / 一键达标 / 反差统计，
# 唯一的作用是在盘问环节生效 —— 目前是「尼古喵尾」（装备时不再提高怀疑值）。
# ★ 不携带时是空数组；判定一律走 has_any_tool() / carried_tool()，别直接比字符串。
var carried_tools: Array = []

# 身上有没有指定的妙妙工具
func carried_tool(item_id: String) -> bool:
	return carried_tools.has(item_id)

# --- 换装判定结果 ---
# 阶段一（准备室）**不再**替玩家下结论 —— 它只把「这身打扮算出来什么」写在这里，
# 真正的审判发生在阶段二：门一开，审讯官抬眼的那一瞬间。
# 不合格 → 他说出「怎么是你，<A 真身名>」，整局当场结束。
var outfit_passed: bool = true
var outfit_fail_reasons: Array = []

# --- 多轮制（由 RunData 写入）---
var run_index: int = 0               # 第几局
var run_seed: int = 0                # 本局种子（可复现）
var background_name: String = ""     # 本局背景名
var cleared_levels: int = 0          # 本局已通过关数

# --- 本局固定卡司（一局之内绝不改变，由 RunData 写入）---
# 审讯官 / 同行人 / A / B 都来自背景，而背景每局只抽一次、跨关不重抽。
var interrogator_name: String = ""   # 本局审讯官的称呼
var companion_name: String = ""      # 本局同行人的名字

# --- 审问者的情报（性情）---
var interrogator_trait: String = ""        # 本局审讯官的性情 id（由 RunData 抽）
var interrogator_intel_read: bool = false  # 玩家是否翻过手机备忘录读过这条情报（读过才会在选项上亮 ⚠）

# --- 情报整理（由换装阶段的手机浮层实时写入）---
var dossier_kept: Array = []         # 归入「B 的伪装档案」的情报 id
var dossier_sealed: Array = []       # 被标为「禁区 · 绝不能说」的情报 id
var dossier_mistakes: int = 0        # 归类错误数
var dossier_total: int = 0           # 身份情报总数
var revealed_slots: Array = []       # 已还原出原貌的槽位（外貌情报读过的部分）
var clues_total: int = 0             # 外貌情报总数

# --- 手机（短信 / 相册）---
# 短信里明明白白写着 B 的官方说法 —— 读短信 = 学到「我该怎么说」
var sms_read: Array = []             # 已读短信线程 id
var known_facts: Dictionary = {}     # fact id -> value id（B 的官方说法）
var photo_wipes: Dictionary = {}     # 照片序号 -> 已擦次数
var photos_revealed: Array = []      # 已经看清的照片（对应槽位因此还原）

# --- 盘问中「掏手机掏太多次」收到的短信 ---
# 这不是剧情短信（剧情短信是 B 的官方口径，逐关解锁、写在 story.json 里），
# 而是**事件短信**：你在答题时把手机掏出来看，他看见了，于是发消息过来。
# 手机「消息」App 里会多出一条来自审讯官本人的对话，正文就是这个数组。
var interrogator_sms: Array = []

# --- 前后矛盾（跨关累计，因为审讯官是同一个人，他记得你说过什么）---
var stated_facts: Dictionary = {}    # fact id -> value id（你第一次立下的说法，之后不许改口）
var contradictions: int = 0          # 前后矛盾次数
var improvised: int = 0              # 没按官方说法答的次数
var plants: int = 0                  # 同行者成功种下的钉子数
var companion_asked: int = 0         # 同行者已经反问过几次

# --- 逐轮问答记录（备注界面用，第十三轮）---
# 每条 = { level: 第几轮(0起), q: 问话, answer: 你选的那个选项 }
# 备注界面只显示「当前关之前」的记录：第 1 轮为空，第 2 轮显示第 1 轮，以此类推。
var answer_log: Array = []

# --- 本轮重来（第二十一轮）---
# 一关开始时拍一张快照；本轮失败重来时把这几个字段回滚到快照那一刻。
#
# ★ 「本轮重来」= 这一轮里发生的事全部回滚，但**准备室里做的功课留着** ——
#   读过的短信、擦清的照片、还原出来的外貌情报都属于「你查到的信息」，
#   不该因为你这一轮答砸了就作废。跨关立下的口径也在快照里（它们属于前面几轮）。
var _level_snapshot: Dictionary = {}

# Memory / Backstory Knowledge
var memorized_backstory = {
	"identity": "来自北方的香料商人",
	"birthplace": "寒霜港",
	"trade_route": "走陆路跨越黑石山脉",
	"scar_origin": "童年时在香料工坊不慎烫伤"
}

# 一局开始时调用：把整局相关的状态全部清空
# 注意：背景与原貌由 RunData 管，这里只管「玩家进度」这部分
func reset_run_state() -> void:
	level_index = 0
	cleared_levels = 0
	dossier_kept = []
	dossier_sealed = []
	dossier_mistakes = 0
	dossier_total = 0
	revealed_slots = []
	clues_total = 0
	sms_read = []
	known_facts = {}
	photo_wipes = {}
	photos_revealed = []
	interrogator_sms = []
	stated_facts = {}
	contradictions = 0
	improvised = 0
	plants = 0
	companion_asked = 0
	interrogator_trait = ""
	interrogator_intel_read = false
	interrogator_name = ""
	companion_name = ""
	suspicion_carry = 0.0
	answer_log = []
	_level_snapshot = {}
	reset_level_state()

# 一关开始时调用：只清「本轮」的状态
# 情报进度、手机进度、以及「你说过什么」都要跨关保留 —— 同一局里他还是那个人
func reset_level_state() -> void:
	begin_level_suspicion()
	outfit_exposure = 0
	outfit_exposure_cap = 10
	contrast_total = 0
	contrast_required = 0
	contrast_sufficient = false
	matching_slots_count = 0
	defects_covered = false
	uncovered_defects = []
	outfit_passed = true
	outfit_fail_reasons = []
	# ★ 第三十九轮：妙妙工具是「准备室点完之后带进来的东西」，换关要重新确认，
	#   所以这里清空 —— 界面层 `sync_outfit_verdict()` 会在每次确认换装时重写。
	carried_tools = []

func reset_game() -> void:
	reset_run_state()

# ============================================================
#  本轮重来：进关时拍快照 / 失败时回滚
#
#  为什么只回滚这几个字段：
#    · stated_facts / contradictions / improvised / plants —— 这一轮里说的话不算数了
#      （注意：快照里带着**前面几轮**立下的口径，所以跨关复问照样成立）；
#    · companion_asked —— 同行者在这一轮插了几次话，重来就重新数；
#    · answer_log —— 备注回放的是「你真正走过的那一轮」，答砸的那次不该留在上面；
#    · interrogator_sms —— 掏手机掏太多次收到的短信属于这一轮的事故；
#    · suspicion_carry —— 回滚到进这一轮时的底子，怀疑度才不会越重来越高。
#
#  不回滚的（刻意留着）：短信进度、相册、外貌情报、身份归类、接受度、装备池。
# ============================================================
func snapshot_level_state() -> void:
	_level_snapshot = {
		"stated_facts": stated_facts.duplicate(),
		"contradictions": contradictions,
		"improvised": improvised,
		"plants": plants,
		"companion_asked": companion_asked,
		"answer_log": answer_log.duplicate(),
		"interrogator_sms": interrogator_sms.duplicate(),
		"suspicion_carry": suspicion_carry,
	}

func restore_level_snapshot() -> void:
	if _level_snapshot.is_empty():
		return
	var sf: Variant = _level_snapshot.get("stated_facts", {})
	stated_facts = (sf as Dictionary).duplicate() if typeof(sf) == TYPE_DICTIONARY else {}
	contradictions = int(_level_snapshot.get("contradictions", 0))
	improvised = int(_level_snapshot.get("improvised", 0))
	plants = int(_level_snapshot.get("plants", 0))
	companion_asked = int(_level_snapshot.get("companion_asked", 0))
	var al: Variant = _level_snapshot.get("answer_log", [])
	answer_log = (al as Array).duplicate() if typeof(al) == TYPE_ARRAY else []
	var isms: Variant = _level_snapshot.get("interrogator_sms", [])
	interrogator_sms = (isms as Array).duplicate() if typeof(isms) == TYPE_ARRAY else []
	suspicion_carry = float(_level_snapshot.get("suspicion_carry", 0.0))

# 有快照可回滚吗（测试 / 边界用）
func has_level_snapshot() -> bool:
	return not _level_snapshot.is_empty()

# 轮次之间：把怀疑度按比例衰减一次。
#   第 1 关（没有 carry）用基准值；之后各关 = 上一轮带过来的 × SUSPICION_DECAY，
#   再被 SUSPICION_FLOOR 兜住下限（不会一路归零，越往后底子越差）。
# ★ 这是**唯一**能让怀疑度降下来的地方 —— 轮内只涨不跌。
func begin_level_suspicion() -> void:
	if suspicion_carry > 0.0:
		suspicion_level = clampf(suspicion_carry * SUSPICION_DECAY,
			SUSPICION_FLOOR, 100.0)
	else:
		suspicion_level = SUSPICION_BASE
