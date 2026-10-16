class_name Interrogation
extends Control

# ============================================================
#  阶段二 · 高压盘问
#
#  审讯官 = 认识 A 的旧识（身份由本局背景决定）。他不确定眼前这个人是不是 A，
#  所以全程在试探。
#  同行者 = 知道你是 A，也知道你在装 B。他既不出手相助，也不当面揭穿，
#           只负责把审讯官的目光往对的地方引 —— 剩下的你自己扛。
#
#  干扰频率与「暴露值」挂钩：你穿得越暴露，同行者越有文章可做。
#  这是暴露值在质问环节的第二个作用（第一个是决定能不能穿）。
#
#  同行者有两条路子，分工明确：
#
#    · 提问 —— 他**会插一道正式的题**，和审讯官的题在同一个序列里、走同一套判定。
#              他刚听见你立下的说法，就立刻抛一个错的版本：「您那车货是布匹吧？」
#              你顺着他说 → 跟你自己的口径对不上 → 前后矛盾。
#              无论你怎么答，这句话都进了册子（plants +1）。
#
#    · 干扰 —— 他凑到审讯官耳边递半句话，你得在 2.6 秒窗口内按 [空格] 截断；
#              每 3 次里有 1 次是**组合干扰**：递的是一整句要紧的，得依次敲 J → K → L。
#              两种干扰都可以 QTE 抵抗。
#
#  多轮制：每一关从本局背景的题库里**确定性抽取** QUESTIONS_PER_LEVEL 道题。
#
#  ★ 换装的审判也在这里。
#    准备室只把数字摊开（反差值多少、缺陷遮没遮、强制装备穿没穿），
#    不下结论、不锁门。门一开、他抬眼的这一瞬间才是判决 ——
#    不合格，他当场念出 A 的真身名：「怎么是你，<名字>。」本轮结束
#    （第二十一轮起失败只作废本轮 —— 回到本轮的准备室重来）。
# ============================================================

signal interrogation_finished(success: bool)

# ★ 第五十轮：8 → 6（用户口径「目前计划每轮六个问题」）。
#   抽题结构是「该轮的固定题（说法 / 同行者 / 盲区各一）+ 1 道跨轮复问
#   + 从通用池补足到本数」，所以 6 道 = 3 + 1 + 2。
#   通用池里能抽的档案题一共 8 道，四轮各 2 道正好对齐。
const QUESTIONS_PER_LEVEL := 6
const PASS_SUSPICION := 60.0

# --- 说法题（前后矛盾）---
const CONTRADICTION_LIMIT := 2        # 累计矛盾到这个数 → 当场被识破
const CONTRADICTION_PENALTY := 35.0   # 前后矛盾：重罚（轮内只涨不跌，这刀最狠）
const IMPROVISE_PENALTY := 12.0       # 说法与官方口径不符（还没被抓到矛盾）
# ★ 第十三轮：轮内怀疑度只涨不跌 —— 「答对口径 / 复问一致」不再给负奖励，
#   这几条奖励常量直接删掉，_add_suspicion 也会把一切负增量拦在门外。

# ★ 第三十九轮：妙妙工具「尼古喵尾」的物品 id（对应 OutfitData 的 tool 栏，
#   那一栏只能手动装备、不进任何数值统计）。
#   装备它时，一切**非致命**的怀疑值增量都不生效；
#   会一击致命的那种选项（说漏嘴）照常结束游戏。判定见 _add_suspicion()。
const TOOL_TAIL_ID := "tool_tail"

# 盲区题（「完全没给信息的题」）：
#   档案里没有、短信里也没提 —— 硬答一个具体细节是恒定重罚，
#   因为编得越细，他越能顺着往下追问。真正的选择在「撒谎 / 回避」之间，
#   而哪个安全由审问官的性情决定（写在手机备忘录第一条）。
const BLIND_MADE_UP_DELTA := 24.0

const EXPR_QTE_TIME := 4.0
const EXPR_QTE_DECAY := 35.0
const EXPR_QTE_BOOST := 80.0
const EXPR_QTE_PASS := 60.0
const EXPR_QTE_FAIL := 24.0          # 表情没绷住 → 怀疑度 +24（调高）
# 按住型 QTE 在「切到新题」之后延迟这么久才开始 —— 让你先看清题目，
# 而不是题刚蹦出来就被迫按住空格。
const EXPR_QTE_DELAY := 2.5
# 暴露值到这儿，连寻常答话他都盯着你的脸看 —— 本来只有 A 类题 / 盲区题才压表情
# ★ 第三十三轮：暴露值换成「线性斜坡」——
#   ≤ EXPOSURE_QTE_MIN 一次都不出；≥ EXPOSURE_QTE_FULL 每题必出；中间线性。
const EXPOSURE_QTE_MIN := 10
const EXPOSURE_QTE_FULL := 60

# --- 档案题的第 4 个选项：沉默 ---
#  选项数量是**可变**的（2 ~ 4 个）：档案题 4 个、说法题 / 同行者题 3 个、
#  题面没给「硬答」的盲区题只有 2 个。题面数据里写了 silence 就用它，没写用这句。
const SILENCE_DELTA := 6.0
const SILENCE_TEXT := "（你什么也没说 —— 沉默着，没有接这个话头。）"
const OPTION_LETTERS := ["A. ", "B. ", "C. ", "D. "]

# --- 视角晃动 ---
#  有冲击的时候镜头抖一下：QTE 失败、被识破、掏手机被发现。
#  幅度（像素）与时长（秒）由调用点给，这里只放几档常用值。
const SHAKE_QTE_FAIL := 10.0
const SHAKE_QTE_PASS := 3.0
const SHAKE_HIT := 18.0

# --- 同行者干扰 ---
#  窗口 2.6 秒、最密 6 秒一次。
#  之前是 1.6 秒 / 2.5 秒 —— 太赶了：你明明看见了他凑过去，手却没跟上，
#  那就不是在考判断，是在考手速。现在留出「看清 → 反应 → 敲下去」的余量。
const INTERFERENCE_WINDOW := 2.6
const INTERFERENCE_BASE := 14.0

# --- 组合干扰（按顺序敲 3 个键）---
#  每 COMBO_EVERY 次干扰里有 1 次是组合：他递的不是半句话，是一整句要紧的，
#  你得连敲三个键才截得断。其余次数仍是单键（空格）。
const COMBO_LEN := 3
const COMBO_KEYS := [KEY_J, KEY_K, KEY_L]
const COMBO_EVERY := 3

# --- 底部两条提示条的位置 ---
#  表情 QTE 与同行者递话都是**覆盖层**（弹出来 / 收起来不动 root 布局），
#  代价是它们会盖住贴在底部的最后一个选项 ——
#  用户口径：「按住空格键的 QTE 挡住了最后一个选项」。
#  解法：在 root 末尾留一条**常驻占位带**（STRIP_BAND_H），
#  选项区就永远停在提示条上方；占位块一直在，所以照样不抖。
#
#  ★ 两条提示条**共用同一层**（都贴屏幕最下方）：
#    它们本来就互斥 —— 压表情期间不排递话（见 _process_interference_timer），
#    递话那 2.6 秒里也不会再弹 QTE（见 _start_interference 的护栏）。
#    分两层的话，上面那条要把占位带撑到 200 像素以上，720 的屏根本放不下
#    （实测：选项区 + 题面 + 反馈的最小高度已经吃掉 480）。
const QTE_FROM_BOTTOM := 16          # 表情 QTE 面板下沿离屏幕底边
const INTF_FROM_BOTTOM := 16         # 递话面板下沿离屏幕底边（与 QTE 同层，互斥）
const STRIP_BAND_H := 96             # 底部常驻占位带的高度（要盖过整条提示条）

# --- 盘问中「掏手机」---
#  回答问题时可以把手机掏出来瞄一眼（短信 / 相册 / 备忘录 / 备注）。
#  但他就坐在对面 —— 第二次掏出起，桌上那部手机会震一下，发信人是他本人。
#
#  ★ 第五十轮重标（用户口径：「手机拿出一次后，再次拿出增加怀疑值」）：
#    免罚 3 → 1、单价 15 → 8，**两件事必须一起改**。
#    账是这么算的：通过线 60、第 1 轮起点 20 → 一轮总共只有 40 点预算，
#    而单次代价里「前后矛盾 35 / QTE 失败 24 / 盲区硬答 24 / 干扰没拦 18」都已就位，
#    15 × n 在那张表里属于中档偏贵：
#      · 免罚 3 的时候只有第 4 次掏出（+15）真的兑现在预算里 —— 第 5 次 +30 就过线了。
#        也就是说「免罚 3 次」实际只兑现出 1 次宽限。
#      · 只把免罚降到 1、单价不动 → 第 3 次掏出 20+15+30 = 65 直接过线，一轮只能掏 2 次。
#        而一轮 6 道题里「必看的」就有 2~3 次（盲区题的解在备忘录第一条、
#        说法题 / 同行者题要对上短信口径）→ 手机当场变成废功能。
#    免罚 1 + 单价 8：掏出 3 次累计 24（20 → 44，余 16），第 4 次 +24 累计 48 才过线。
#    刚好「必需的 2~3 次」落在安全线内，想多瞄几眼就得拿别处的容错去换。
const PHONE_PULL_FREE := 1            # 第 1 次不追究
const PHONE_PULL_PENALTY := 8.0       # 第 n 次越界，怀疑度 +8 × n

var current_question_index: int = 0
var is_qte_active: bool = false          # 表情 QTE（保留旧字段名，测试依赖）
var qte_progress: float = 0.0
var qte_timer: float = 0.0
var qte_needed: bool = false             # 这一题需不需要压表情（在 _load_question 里算好）
var qte_delay_left: float = 0.0          # 延迟倒计时（EXPR_QTE_DELAY 起数到 0 才弹出来）
# ★ 第三十三轮：这一题的 QTE 提示文字。题目自带（qte.prompt）优先，留空则用全局那句。
var qte_prompt_used: String = ""
var qte_done: bool = false               # 本题的 QTE 已经做完 / 已取消（答完一题只做一次）

# ---- 每题的 QTE 计划（第二十三轮，编辑器可改）----
#  用户在编辑器里给每一道题指定「用哪种 QTE」+「几秒后出现」。
#  取值见 OutfitData.QTE_* ："" / "auto" = 按老规则自动判（needs_expression_for），
#  "none" = 本题不出，其余四种是强制指定。
#  ★ 递话类（interference / combo）走自己的排期 —— 原来是「每若干秒随机来一次」，
#    被指定时改成「切题后 delay 秒准点来一次」，所以另开一组字段，不跟计时器混。
var qte_plan_kind: String = ""
var qte_plan_delay: float = -1.0
var _intf_scheduled: bool = false        # 本题是否排了一次「准点递话」
var _intf_kind_forced: String = ""       # "" = 按老规则；"single" / "combo" = 指定
var _intf_delay_left: float = 0.0
var _intf_planned_used: bool = false     # 指定的那一次已经来过了 → 本题不再随机补

var interference_active: bool = false
var interference_time_left: float = 0.0
var interference_timer: float = 0.0
var interference_count: int = 0
var interference_blocked: int = 0
var interference_kind: String = "single"   # "single"（按一下空格）| "combo"（依次敲 3 个键）
var combo_index: int = 0                   # 组合干扰：已经敲对了几个键
var interference_line: String = ""         # 他这一次递的那句话（显示在干扰条上）

var current_options: Array = []
var _questions: Array = []               # 本轮实际要问的题（从背景题库里抽出来的）
var _ended: bool = false
var _running: bool = false               # 只有开局后才驱动计时器，避免未开局时干扰抢跑
var _success: bool = false               # 本轮盘问结果
var _result_shown: bool = false
var _end_reason: String = ""             # "recognized" / "exposure" / "caught" / "gameover" / ""

# --- 盘问中掏手机 ---
var phone_pulls: int = 0                 # 本轮掏了几次
var _phone_open: bool = false

# --- UI 引用（全部代码构建）---
var dialogue_label: Label
var feedback_label: Label
var suspicion_bar: ProgressBar
var suspicion_val: Label
var level_label: Label
var help_btn: Button
var option_btns: Array = []              # 复用池：2 ~ 4 个，多出来的隐藏
var opts_box: VBoxContainer              # 选项竖排容器（在掏手机按钮右边）
var qte_container: Control
var qte_strip: Control                  # 贴底的那个面板（断言位置用）
var qte_pass_mark: ColorRect            # 进度条上的通过线（断言用）
var qte_bar: ProgressBar
var qte_label: Label
var intf_container: Control
var intf_strip: Control                 # 同上
var intf_bar: ProgressBar
var intf_label: Label
var strip_band: Control                 # 底部常驻占位带（给两条提示条让位，不压选项）
var result_hint: Label
var result_btn: Button

# 视角晃动
var shake_target: Control                # 被抖的那一层（整屏内容）
var _shake_time: float = 0.0
var _shake_dur: float = 0.0
var _shake_mag: float = 0.0
var _shake_t: float = 0.0

# 掏手机
var phone_btn: Button
var phone_layer: Control
var phone_panel: PhoneDesk
var phone_notice: Label

func _ready() -> void:
	_build_ui()

# ============================================================
#  配置读取助手
#
#  上面那一堆 const 现在只是**出厂兜底**：真正生效的是 data/story.json 的
#  "rules"（数值）与 "ui"（界面文案），编辑器改完存盘、下一局直接生效。
#
#  每个助手都带一个「出厂默认」参数 —— JSON 里没写这个键 / 类型不对，
#  就退回那个常量。所以把 data/story.json 删了，游戏照样按出厂值跑。
# ============================================================
func _rf(key: String, dflt: float) -> float:
	return ScenarioData.rule_f(key, dflt)

func _ri(key: String, dflt: int) -> int:
	return ScenarioData.rule_i(key, dflt)

func _ut(path: String, dflt: String) -> String:
	return ScenarioData.ui_t(path, dflt)

func _et(key: String, dflt: String) -> String:
	return DossierData.end_t(key, dflt)

# 组合干扰的键位：数据里写的是字母（"J" / "K" / "L"），这里翻成键码。
# 翻不出来的（编辑器里填了个不存在的键名）→ 退回出厂那三个。
# 结果缓存起来 —— 每次敲键都重算一遍没必要。
var _combo_cache: Array = []

func combo_keys() -> Array:
	if not _combo_cache.is_empty():
		return _combo_cache
	var letters: Array = ScenarioData.rule_arr("combo_keys", [])
	var out := []
	for s in letters:
		var kc := OS.find_keycode_from_string(str(s))
		if kc != KEY_NONE:
			out.append(kc)
	_combo_cache = out if (not out.is_empty() and out.size() == letters.size()) else COMBO_KEYS
	return _combo_cache

# ---------------- UI ----------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.062, 0.068, 0.082)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	# 视角晃动就抖这一层 —— 它是 Interrogation 的直接子节点，
	# 不在任何 Container 里，改 position 不会被布局冲掉。
	shake_target = margin

	# ---- 顶栏：怀疑度 ----
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var hlab := Label.new()
	hlab.text = _ut("interrogation.suspicion_label", "审讯官怀疑度")
	hlab.add_theme_font_size_override("font_size", 13)
	header.add_child(hlab)

	suspicion_bar = ProgressBar.new()
	suspicion_bar.custom_minimum_size = Vector2(0, 22)
	suspicion_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	suspicion_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	suspicion_bar.show_percentage = false
	suspicion_bar.max_value = 100.0
	header.add_child(suspicion_bar)

	suspicion_val = Label.new()
	suspicion_val.custom_minimum_size = Vector2(46, 0)
	suspicion_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	suspicion_val.add_theme_font_size_override("font_size", 12)
	header.add_child(suspicion_val)

	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	header.add_child(level_label)

	# 「❓ 玩法说明」—— 教练式标注，把盘问界面每一处圈出来讲一遍
	help_btn = Button.new()
	help_btn.text = _ut("common.help_btn", "❓ 玩法说明")
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.custom_minimum_size = Vector2(120, 30)
	help_btn.add_theme_font_size_override("font_size", 12)
	help_btn.tooltip_text = _ut("common.help_tip", "用方框和编号把这一屏的每一处圈出来讲一遍。")
	header.add_child(help_btn)

	# ---- 主区 ----
	#  右栏（「同行者」那一块）已经删掉：他的台词现在只出现在
	#  干扰条 / 题面 / 反馈里，不再单独占一栏。整块地方留给题面与选项。
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	_build_left(main)

	# ---- 表情 QTE / 同行者干扰（★ 覆盖层，不参与 root 布局）----
	#  以前这两块直接塞进 root 这个 VBox，一 show() 就重新排版，
	#  把底部那排「掏出手机」按钮挤得往上跳。现在改成 anchor 固定的覆盖层：
	#  弹出来 / 收起来都不动布局。
	#
	#  ★ 两条都贴在**屏幕最下方**（用户口径：「qte改为显示在最下方」），
	#    而且是**同一层** —— 它们互斥（压表情时不排递话、递话那 2.6 秒不弹 QTE），
	#    不会同时出现；共用一层才能让底部占位带做得够矮、塞得进 720 的屏。
	qte_container = _make_bar_overlay(Color(0.22, 0.54, 0.87), QTE_FROM_BOTTOM)
	qte_label = qte_container.get_meta("label")
	qte_bar = qte_container.get_meta("bar")
	qte_strip = qte_container.get_meta("strip")

	intf_container = _make_bar_overlay(Color(0.90, 0.42, 0.30), INTF_FROM_BOTTOM)
	intf_label = intf_container.get_meta("label")
	intf_bar = intf_container.get_meta("bar")
	intf_strip = intf_container.get_meta("strip")

	qte_container.hide()
	intf_container.hide()

	# ---- 结算行 ----
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)

	result_hint = Label.new()
	result_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_hint.add_theme_font_size_override("font_size", 12)
	result_hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	result_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(result_hint)

	result_btn = Button.new()
	result_btn.custom_minimum_size = Vector2(210, 44)
	result_btn.focus_mode = Control.FOCUS_NONE
	result_btn.add_theme_font_size_override("font_size", 14)
	result_btn.pressed.connect(_on_result_pressed)
	foot.add_child(result_btn)

	result_hint.hide()
	result_btn.hide()

	# ---- 底部常驻占位带 ----
	#  两条提示条是覆盖层（弹出 / 收起不动布局），但「不动布局」的代价是
	#  它们会压在贴底的最后一个选项上（用户口径：「按住空格键的 qte 挡住了最后一个选项」）。
	#  这里在 root 末尾放一块**永远存在**的空占位：高度 = 提示条那一条带子。
	#  选项区因此永远停在提示条上方，而占位块一直在 —— 依旧不会抖。
	#  注意：占位块是普通 Control（不是 Container），show/hide 提示条都不会影响它。
	strip_band = Control.new()
	strip_band.name = "StripBand"
	strip_band.custom_minimum_size = Vector2(0, STRIP_BAND_H)
	strip_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip_band)

	_build_phone_layer()

# ---------------- 掏出手机（覆盖在右侧，左边选项照样能点）----------------
func _build_phone_layer() -> void:
	phone_layer = Control.new()
	phone_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 关键：整层**不挡鼠标** —— 手机只盖住右边，左边的三个选项照样能点。
	# 这样「掏出手机 → 瞄两眼 → 顺手选个答案 → 手机自动收回」才成立。
	phone_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_layer.visible = false
	add_child(phone_layer)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_layer.add_child(row)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)

	var m := MarginContainer.new()
	m.custom_minimum_size = Vector2(PhoneDesk.PHONE_W + 24, 0)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	row.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	m.add_child(col)

	phone_notice = Label.new()
	phone_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_notice.add_theme_font_size_override("font_size", 11)
	phone_notice.add_theme_color_override("font_color", Color(0.98, 0.62, 0.52))
	phone_notice.hide()
	col.add_child(phone_notice)

	phone_panel = PhoneDesk.new()
	phone_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(phone_panel)

	var close := Button.new()
	close.text = _ut("interrogation.phone_close_hint", "收起手机  ←（选答案时会自动收回）")
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 12)
	close.custom_minimum_size = Vector2(0, 32)
	close.pressed.connect(_close_phone)
	col.add_child(close)

# ---------------- 掏出手机 ----------------
#  ★ 表情 QTE 期间**手机用不了**（用户口径：「按住空格的 qte 时不再能够使用手机」——
#    这是**规定**，不是待修的 bug）。
#    理由：压表情本来就得一直按着空格，这时候再翻手机两头顾不上；
#    而且手机浮层盖在右侧，会把贴在底部的 QTE 进度条挡掉半截。
#    落地方式是「锁」而不是「静默失效」：手里那部自动收回，按钮同时变灰并改文案
#    （见 _set_phone_locked），玩家一眼看得出是「现在不行」而不是「按钮坏了」。
#    「同行者递话」那 2.6 秒同样锁着 —— 那个窗口要求你专心敲键。
func _toggle_phone() -> void:
	if _ended or is_qte_active or interference_active:
		return
	if _phone_open:
		_close_phone()
	else:
		_open_phone()

# QTE 期间把手机锁上 / 解锁。锁定 = 自动收回 + 按钮变灰 + 改文案。
func _set_phone_locked(locked: bool) -> void:
	if phone_btn == null:
		return
	if locked:
		_auto_retract_phone()
		phone_btn.disabled = true
		phone_btn.text = _ut("interrogation.phone_locked_btn", "📱 压表情时收起来")
	else:
		phone_btn.disabled = false
		phone_btn.text = _ut("interrogation.phone_close_btn", "📱 收起手机") if _phone_open \
			else _ut("interrogation.phone_open_btn", "📱 掏出手机")

func _open_phone() -> void:
	if phone_panel == null:
		return
	# 兜一层：QTE 期间谁也别想把手机打开（UI 走 _toggle_phone，这里防直接调用）
	if is_qte_active:
		return
	_phone_open = true
	phone_pulls += 1
	phone_panel.rebuild()
	phone_layer.show()
	phone_btn.text = _ut("interrogation.phone_close_btn", "📱 收起手机")
	# 第 1 次他当你是在整理行头。第 2 次起 —— 他看见了。
	if phone_pulls > _ri("phone_free_pulls", PHONE_PULL_FREE):
		_phone_pull_event()

func _close_phone() -> void:
	if not _phone_open:
		return
	_phone_open = false
	if phone_layer != null:
		phone_layer.hide()
	if phone_btn != null:
		phone_btn.text = _ut("interrogation.phone_open_btn", "📱 掏出手机")

# 回答完毕自动收回：每答一题、每换一题都把手机收起来。
# （不做「关掉手机才能答题」那一套 —— 掏出来瞄两眼、顺手选个答案，才是它该有的手感。）
func _auto_retract_phone() -> void:
	if _phone_open:
		_close_phone()

# 掏过头 → 他看见了。
#
#  ★ 第五十轮：取消「他给你发短信」这一步（用户口径：「免罚后的收到短信功能取消」）。
#    现在越界掏出只做三件事：震一下屏、涨怀疑度、弹一句即时反馈 + 手机面板上的通知条。
#    短信正文不再写入 —— `story.json` 里那 5 条 `interrogator_sms` 文案留着，
#    手机消息界面照旧能渲染这条线程（见 PhoneDesk.INTR_THREAD），只是不再由这里喂内容，
#    所以它在正常游戏里是空的、不显示（PhoneDesk._build_message_list 判空跳过）。
#
#    ★ 顺带修掉一个隐患：旧版这里是 `var text := interrogator_sms_at(n-1)`，
#      紧接着 `if text == "": return` —— 也就是**取不到短信文案时整个事件静默失效**，
#      连怀疑度都不涨。编译器把 5 条删了或改空，这条惩罚就会无声无息地消失。
func _phone_pull_event() -> void:
	var n := phone_pulls - _ri("phone_free_pulls", PHONE_PULL_FREE)   # 第几次越界：1, 2, 3 ...
	var penalty := _rf("phone_pull_penalty", PHONE_PULL_PENALTY) * float(n)
	shake(_rf("shake_phone_caught", 7.0), 0.32)
	_add_suspicion(penalty)
	if _ended:
		return
	if phone_notice != null:
		phone_notice.text = _ut("interrogation.phone_notice",
			"📱 他看见你掏手机了 —— 怀疑度 +%d") % int(round(penalty))
		phone_notice.show()
	feedback_label.add_theme_color_override("font_color", Color(0.96, 0.44, 0.40))
	feedback_label.text = _ut("interrogation.phone_caught",
		"【他看见了】你把手机从袖子里摸出来的时候，他手里的笔停了一下。\n"
		+ "他没抬头，只是把视线在你袖口停了两秒 —— 那点亮，他记住了。")

func _make_bar_panel(parent: VBoxContainer, fill: Color) -> Control:
	var panel := PanelContainer.new()
	parent.add_child(panel)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	vb.add_child(lab)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.show_percentage = false
	bar.max_value = 100.0
	_style_bar(bar, fill)
	vb.add_child(bar)

	panel.set_meta("label", lab)
	panel.set_meta("bar", bar)
	return panel

# 覆盖层版提示条：贴在**屏幕最下方**，不进任何 VBox 布局 ——
# 弹出来 / 收起来都不会把底下的「掏出手机」按钮挤走。
# 整层不挡鼠标（表情 QTE 本来就不该挡着你去点选项 / 掏手机）。
#
# from_bottom = 面板下沿离屏幕底边的距离：
#   表情 QTE 与同行者递话都用 QTE_FROM_BOTTOM / INTF_FROM_BOTTOM（同层、互斥）。
#   这条提示条占多高，就由 STRIP_BAND_H 在 root 末尾原样让出来 ——
#   所以选项区永远停在提示条上方，不会被压住。
#
# ★ 这里有个坑：**不能拿 MarginContainer 的 margin_bottom 当「外边距」用**。
#   那是内容的**内边距** —— 它只把内容往上推，容器自身照样贴到屏幕底边，
#   结果两条提示条都贴死在底边、叠在一起（试过，正是这个现象）。
#   正确做法是「贴底对齐的 VBox + 底部一个占位块」：占位块多高，面板就抬多高。
func _make_bar_overlay(fill: Color, from_bottom: int) -> Control:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)

	# 左右各留 170 —— 让面板别压住左下角的「掏出手机」按钮
	var side := MarginContainer.new()
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.add_theme_constant_override("margin_left", 170)
	side.add_theme_constant_override("margin_right", 170)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(side)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END     # 内容整体贴底
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(col)

	var panel := PanelContainer.new()
	# 提示条本身不吃鼠标：它是盖在选项上方的一层，
	# 万一将来位置又和哪个按钮撞上，点击也得穿过去落到按钮上。
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	for s2 in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s2, 10)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	vb.add_child(lab)

	# 进度条 + 一条**通过线**标记。
	# ★ 为什么要标出来：这条只显示一个 0~100 的进度，玩家看不出「按到哪里才算过」——
	#   压了半天不知道够不够，体感上就跟「按了没反应」差不多。
	#   在 EXPR_QTE_PASS 的位置画一道竖线，目标一眼可见。
	var bar_host := Control.new()
	bar_host.custom_minimum_size = Vector2(0, 24)
	bar_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bar_host)

	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.max_value = 100.0
	_style_bar(bar, fill)
	bar_host.add_child(bar)

	var pass_mark := ColorRect.new()
	pass_mark.color = Color(0.98, 0.96, 0.72, 0.95)
	pass_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frac: float = clampf(_rf("expr_qte_pass", EXPR_QTE_PASS) / 100.0, 0.0, 1.0)
	pass_mark.anchor_left = frac
	pass_mark.anchor_right = frac
	pass_mark.anchor_top = 0.0
	pass_mark.anchor_bottom = 1.0
	pass_mark.offset_left = -1.5
	pass_mark.offset_right = 1.5
	bar_host.add_child(pass_mark)
	if fill == Color(0.22, 0.54, 0.87):
		qte_pass_mark = pass_mark      # 只有表情 QTE 那条才有通过线

	col.add_child(panel)

	# 底部占位块 —— 它多高，面板就离底边多远
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, from_bottom)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	# meta 也挂到外层 host 上 —— 调用方拿到的是 host（show/hide 都作用在它身上）
	host.set_meta("label", lab)
	host.set_meta("bar", bar)
	host.set_meta("strip", panel)
	return host

func _build_left(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	m.add_child(vb)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 15)
	dialogue_label.custom_minimum_size = Vector2(0, 96)
	dialogue_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(dialogue_label)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.76))
	feedback_label.custom_minimum_size = Vector2(0, 64)
	feedback_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_child(feedback_label)

	# ---- 底部：左边「掏出手机」，右边选项（2 ~ 4 个）----
	#  掏手机按钮放在左下角、选项左边 —— 一手能同时够到，
	#  「掏出来瞄一眼 → 顺手选个答案 → 手机自动收回」这条动线才顺。
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(bottom)

	phone_btn = Button.new()
	phone_btn.text = _ut("interrogation.phone_open_btn", "📱 掏出手机")
	phone_btn.focus_mode = Control.FOCUS_NONE
	phone_btn.add_theme_font_size_override("font_size", 13)
	phone_btn.custom_minimum_size = Vector2(150, 40)
	# 贴在左下角（HBox 里 SHRINK_END = 贴底对齐）
	phone_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	phone_btn.tooltip_text = _ut("interrogation.phone_tip",
		"答题时也能掏出来看一眼。\n但他就坐在对面 —— 掏太多次他会发现。")
	phone_btn.pressed.connect(_toggle_phone)
	bottom.add_child(phone_btn)

	opts_box = VBoxContainer.new()
	opts_box.add_theme_constant_override("separation", 8)
	opts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_box.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(opts_box)
	# 按钮不预建 —— 数量随题目变（2 ~ 4），由 _refresh_option_buttons() 按需补齐。

# 选项按钮：统一工厂。数量可变，索引固定绑定到 _select_option。
func _make_option_button(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_select_option.bind(index))
	return b

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)

# ---------------- 开局 ----------------
func start_interrogation() -> void:
	show()
	_ended = false
	_result_shown = false
	_success = false
	_end_reason = ""
	_running = true
	current_question_index = 0
	interference_count = 0
	interference_blocked = 0
	interference_kind = "single"
	combo_index = 0
	interference_timer = interference_interval()
	feedback_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.76))

	# QTE 状态整块清掉 —— 上一轮残留的面板 / 延迟不能带过来
	_cancel_qte()

	# 掏手机的次数是「本轮」的 —— 换了关就重新数
	phone_pulls = 0
	_close_phone()
	if phone_btn != null:
		phone_btn.disabled = false
	if phone_notice != null:
		phone_notice.hide()

	# 本轮要问的题：从本局背景的题库里确定性抽 QUESTIONS_PER_LEVEL 道
	_questions = DossierData.questions_for_level(
		RunData.level_index, _ri("questions_per_level", QUESTIONS_PER_LEVEL))

	level_label.text = "%s ｜ 第 %d 局 · %s ｜ %s" % [
		RunData.background_name(), RunData.run_index,
		RunData.level_number(), RunData.level_name()]

	# 怀疑度（第十三轮）：
	#   第 1 关 = 基准值；之后各关 = 上一轮带过来的 × 衰减比例。
	#   用 GameData 里的同一条规则重算一遍，保证直接调 start_interrogation()
	#   的测试 / 截图脚本也拿到正确值。
	GameData.begin_level_suspicion()
	if GameData.suspicion_carry <= 0.0 and GameData.dossier_mistakes > 0:
		GameData.suspicion_level = clampf(
			GameData.SUSPICION_BASE + float(GameData.dossier_mistakes) * 3.0, 5.0, 85.0)

	result_hint.hide()
	result_btn.hide()

	_update_suspicion_ui()

	# ★ 换装的审判在**这里**：门一开，他抬眼的那一瞬间。
	#   准备室只把数字摊开（反差值 / 缺陷 / 强制装备），不下结论、也不锁门 ——
	#   能不能骗过他，由这一行说了算。
	if not GameData.outfit_passed:
		_recognized_on_sight()
		return

	_load_question(0)

# 本轮的题目（供测试与调试查看）
func level_questions() -> Array:
	return _questions

func _on_result_pressed() -> void:
	if not _result_shown:
		return
	interrogation_finished.emit(_success)

# 递话干扰的间隔。
#
# ★★ 第三十三轮（用户口径）：「暴露值现在**只会**影响按住空格的 QTE 即表情管理的 QTE」。
#    既然暴露值只该管表情 QTE，这里就不能再跟着它变密 ——
#    改成一个固定间隔（interference_base）。
#    （旧公式是 `base − 暴露值 × per_exposure`，下限 6 秒；想恢复就照这个加回来。）
func interference_interval() -> float:
	return _rf("interference_base", INTERFERENCE_BASE)

# ---------------- 视角晃动 ----------------
#  有冲击的时刻抖一下：QTE 失败、被识破、掏手机被发现。
#  抖动只作用在 shake_target（整屏内容那一层），背景色块不动 ——
#  看起来像「视线晃了一下」，而不是整块画布在平移。
func shake(mag: float, dur: float) -> void:
	if mag <= 0.0 or dur <= 0.0:
		return
	# 取更强的那一次，别让弱的盖掉强的
	if _shake_time <= 0.0 or mag >= _shake_mag:
		_shake_mag = mag
		_shake_dur = dur
		_shake_time = dur
	else:
		_shake_time = maxf(_shake_time, dur)

func _process_shake(delta: float) -> void:
	if shake_target == null:
		return
	if _shake_time <= 0.0:
		if shake_target.position != Vector2.ZERO:
			shake_target.position = Vector2.ZERO
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	_shake_t += delta
	# 线性衰减到 0，两个不同频率的正弦错开 —— 手抖的感觉
	var k := _shake_time / maxf(0.0001, _shake_dur)
	var m := _shake_mag * k
	shake_target.position = Vector2(
		sin(_shake_t * 63.0) * m,
		sin(_shake_t * 47.0 + 1.1) * m)

# ---------------- 开门即识破（阶段一不判定，判定落在这里）----------------
#  准备室把数字摊开之后，门开了。他抬眼 —— 看见的不是 B，是 A。
#  他念出那个名字，这一局当场结束。
func _recognized_on_sight() -> void:
	_ended = true
	_running = false
	_end_reason = "recognized"
	shake(SHAKE_HIT, 0.8)

	var true_name := RunData.true_name()
	var reasons := []
	for r in GameData.outfit_fail_reasons:
		reasons.append("· " + str(r))

	dialogue_label.text = _et("recognized_line",
		"%s抬起头，视线在你脸上停住了。\n\n"
		+ "他看了很久，久到旁边的人都安静下来。然后他放下手里的册子，"
		+ "念出了那个你早就不打算再听见的名字 ——\n\n"
		+ "「怎么是你，%s。」\n\n%s\n\n【潜伏失败 · 一眼认出】"
	) % [RunData.interrogator(), true_name, "\n".join(reasons)]

	feedback_label.add_theme_color_override("font_color", Color(0.94, 0.48, 0.42))
	feedback_label.text = _et("recognized_note",
		"这一身打扮没能把他记忆里的那个 A 盖住 —— "
		+ "门还没关上，他就叫出了你的名字。本轮到此为止。")

	for b in option_btns:
		b.disabled = true
		b.text = "——"
	_auto_retract_phone()
	phone_btn.disabled = true
	_cancel_qte()
	intf_container.hide()
	_show_result(false)

# ---------------- 直接识破 ----------------
func _instant_exposure(why: String) -> void:
	_ended = true
	_running = false
	if _end_reason == "":
		_end_reason = "exposure" if why != "前后矛盾" else "caught"
	shake(SHAKE_HIT, 0.8)
	var reasons: Array = []
	if why == "反差值不足":
		reasons.append(_et("exposure_reason_contrast",
			"你这一身几乎还是 A 本人的样子 —— 反差值 %d，低于要求的 %d 点（仍有 %d 处与原貌一致）。"
		) % [GameData.contrast_total, GameData.contrast_required,
		   GameData.matching_slots_count])
	if not GameData.defects_covered:
		var names := []
		for d in GameData.uncovered_defects:
			names.append(d["name"])
		reasons.append(_et("exposure_reason_defects", "而且以下缺陷暴露在外：") + "、".join(names))
	if why == "说漏嘴":
		reasons.append(_et("exposure_reason_leak",
			"你说出了只有 A 才会知道的细节。审讯官的手停在半空 —— 他认出来了。"))
	if why == "前后矛盾":
		reasons.append(_et("exposure_reason_contradiction",
			"【前后矛盾】同一件事，你前后说出了两套说法。审讯官把两页记录并排放在桌上 —— "
			+ "一个真在赶路的人，不会连自己上一句说了什么都记不住。"))

	dialogue_label.text = _et("exposure_line",
		"%s只扫了你一眼，脸色就变了。\n\n%s\n\n"
		+ "「把他拿下 —— 这个人根本不像他自己说的那样。」\n\n【潜伏失败 · 身份暴露】"
	) % [RunData.interrogator(), "\n\n".join(reasons)]

	for b in option_btns:
		b.disabled = true
		b.text = "——"
	_auto_retract_phone()
	phone_btn.disabled = true
	_cancel_qte()
	intf_container.hide()
	_show_result(false)

# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	# 晃动要一直衰减 —— 即使这一轮已经结束（识破 / 逮捕那一刻也要晃完）
	_process_shake(delta)
	if not _running or _ended:
		return
	# 延迟起手：切到新题之后先让玩家看清题目，到点才把 QTE 弹出来。
	# 它在「干扰」之后判 —— 干扰期间本来就不该再叠加一层 QTE。
	#
	# ★ 这里有个必须记住的坑（QTE 曾经因此完全失灵）：
	#    面板刚弹出来的那一帧，**超出的时间不能计入 QTE 窗口** ——
	#    它那 4 秒要从零开始算，否则一次大步进（测试 / 卡帧）会把 QTE 一帧走完。
	#    但「不计这一帧」不等于「永远传 0」：
	#    曾经写成 `var qte_delta := 0.0` 却没在别处分过值，
	#    结果每帧都拿 0 去推进度 —— 进度条纹丝不动、计时器不倒数、
	#    按住空格毫无反应，而且因为不会超时，QTE 永远不结束。
	#    现在改成：只有「本帧刚弹出」那一次传 0，之后一律传真实的 delta。
	var was_active := is_qte_active
	if not is_qte_active and qte_needed and not qte_done and not interference_active:
		if delta >= qte_delay_left:
			qte_delay_left = 0.0
			_begin_qte()
		else:
			qte_delay_left -= delta
	var qte_step: float = 0.0 if not was_active else delta
	if is_qte_active:
		_process_expression_qte(qte_step)
		# QTE 与干扰可以并行：QTE 只吃「按住」，干扰只吃「按下」事件，互不抢键。
		if interference_active:
			_process_interference(delta)
		else:
			_process_interference_timer(delta)
	elif interference_active:
		_process_interference(delta)
	else:
		_process_interference_timer(delta)

func _process_expression_qte(delta: float) -> void:
	qte_timer -= delta
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		qte_progress += _rf("expr_qte_boost", EXPR_QTE_BOOST) * delta
	else:
		qte_progress -= _rf("expr_qte_decay", EXPR_QTE_DECAY) * delta
	qte_progress = clampf(qte_progress, 0.0, 100.0)
	qte_bar.value = qte_progress
	if qte_timer <= 0.0:
		# 窗口走完 —— 本题的 QTE 就到此为止（单阶段，不再续下一轮）。
		_finish_qte_for_question()

func _process_interference_timer(delta: float) -> void:
	# 表情 QTE 期间先不排干扰 —— 空格既用来压表情、又用来打断，
	# 两个同时来只会互相打架。等 QTE 收掉再算这笔账。
	if is_qte_active:
		return
	# ★ 被编辑器指定的递话：准点来一次就完事，不走那个「每若干秒随机来」的循环
	#   （否则排期和编辑器里写的时间对不上）。
	if _intf_scheduled:
		_intf_delay_left -= delta
		if _intf_delay_left <= 0.0:
			_intf_scheduled = false
			_start_interference()
		return
	# 指定的那一次已经来过 → 本题不再随机补第二次
	if _intf_planned_used:
		return
	interference_timer -= delta
	if interference_timer <= 0.0:
		_start_interference()

func _process_interference(delta: float) -> void:
	interference_time_left -= delta
	intf_bar.value = interference_time_left / _rf("interference_window", INTERFERENCE_WINDOW) * 100.0
	# 只有单键干扰才吃空格 —— 组合干扰得去 _input 里敲那三个键
	if interference_kind == "single" and Input.is_action_just_pressed("ui_accept"):
		_end_interference(true)
	elif interference_time_left <= 0.0:
		_end_interference(false)

# ---------------- 问题 ----------------
# ============================================================
#  统一选项构建（★ 第二十九轮：题目不再分类）
#
#  用户口径：「阶段二的问题我想不再给问题分类，直接让我编辑对问题进行编辑」。
#
#  改造前，这一步是 `match q.kind` 的四分支（fact / companion / blind / 档案题），
#  每一类各有各的字段名与判定方式，玩家改不动任何一道题。
#  现在题目自带 `options[]`，每个选项靠自己的 `tone`（语义标签）说话 ——
#  这里只负责把 tone 翻译成盘问环节内部用的字段（kind / owner / delta / value / blind），
#  **判定逻辑（_select_option 及其下游）一行都没有改**。
#
#  怀疑值的两层写法：
#    · 选项自己写了 `suspicion` → 就用它（硬覆盖，逐题精调）；
#    · 没写 → 落回老规则（读 rules 里的全局值，或按审问官性情现算）。
#  所以「换个人来问、同一句话代价完全不同」这套机制原样保留。
# ============================================================
const TONE_CORRECT := "correct"     # 照实答（B 卡 / 对的那个版本）
const TONE_VERSION := "version"     # 事实题的一个版本：对错看「你之前立过什么说法」
const TONE_LEAK := "leak"           # 说漏嘴（A 卡的致命项，直接触发出局）
const TONE_BLUFF := "bluff"         # 撒谎
const TONE_EVADE := "evade"         # 回避
const TONE_SILENCE := "silence"     # 沉默（代价固定，与性情无关）
const TONE_MADE_UP := "made_up"     # 盲区题的「硬编一个不存在的细节」

# 这一道题是不是新格式（选项带 tone）
func _is_unified_question(q: Dictionary) -> bool:
	var raw: Array = q.get("options", [])
	if raw.is_empty():
		return false
	return (raw[0] as Dictionary).has("tone")

func _build_unified_options(q: Dictionary) -> Array:
	var raw: Array = q.get("options", [])
	var fid := str(q.get("fact", ""))
	var cid := str(q.get("card", ""))
	var is_companion := str(q.get("speaker", "")) == "companion"
	# 盲区题 = 既不挂事实、也不挂档案卡 —— 手里真的一点底都没有，
	# 所以判定不能比内容，只能比「有没有按他的脾性选」（见 _answer_blind）。
	# ★ 注意这不是「题目分类」，而是从题目挂了什么**推**出来的：
	#   你把一道题的事实引用删掉，它自然就变成盲区题。
	var is_blind := fid == "" and cid == "" and not is_companion

	var owner := "B"
	if cid != "":
		owner = str(DossierData.get_card(cid).get("owner", "B"))
	elif is_blind:
		owner = "?"

	# 撒谎 / 回避的代价由「审问者的情报」决定，所以先把它俩的文案收集出来，
	# 交给 _trait_options 去算 —— 它还会在「多疑」时给文案加上 ⚠ 前缀。
	var bluff_text := ""
	var evade_text := ""
	for o in raw:
		var d: Dictionary = o
		match str(d.get("tone", "")):
			TONE_BLUFF:
				bluff_text = str(d.get("text", ""))
			TONE_EVADE:
				evade_text = str(d.get("text", ""))
	var td := _trait_options(bluff_text, evade_text)

	var out := []
	for o in raw:
		var d: Dictionary = o
		var tone := str(d.get("tone", ""))
		var text := str(d.get("text", ""))
		var item := {"owner": owner}
		var delta := 0.0
		match tone:
			TONE_VERSION:
				item["kind"] = "companion" if is_companion else "fact"
				item["fact"] = fid
				item["value"] = str(d.get("value", ""))
				delta = float(d.get("suspicion", 0.0))
			TONE_CORRECT:
				item["kind"] = "ok"
				delta = float(d.get("suspicion", _rf("correct_delta", -6.0)))
			TONE_LEAK:
				item["kind"] = "leak"
				delta = float(d.get("suspicion", _rf("leak_delta", 100.0)))
			TONE_SILENCE:
				item["kind"] = "silence"
				delta = float(d.get("suspicion", _rf("silence_delta", SILENCE_DELTA)))
				if text == "":
					text = _ut("interrogation.silence_text", SILENCE_TEXT)
			TONE_BLUFF:
				item["kind"] = "bluff"
				item["danger"] = td["bluff_danger"]
				delta = float(d.get("suspicion", td["bluff_d"]))
				# ★ 必须用 td 里那份文本 —— 他在「多疑」时会给它加上 ⚠ 前缀，
				#   直接拿选项原文就把这个提示丢了（第二轮实测就是这条挂的）。
				text = td["bluff_text"]
			TONE_EVADE:
				item["kind"] = "evade"
				item["danger"] = td["evade_danger"]
				delta = float(d.get("suspicion", td["evade_d"]))
				text = td["evade_text"]
			TONE_MADE_UP:
				item["kind"] = "made_up"
				delta = float(d.get("suspicion",
					_rf("blind_made_up_delta", BLIND_MADE_UP_DELTA)))
			_:
				# tone 写错了也别让这道题空着 —— 当成「照实答」处理，并留个痕。
				item["kind"] = "ok"
				push_warning("未知的 tone「%s」（题 %s）" % [tone, str(q.get("id", "?"))])
		if is_blind:
			item["blind"] = true
		item["delta"] = delta
		# ★ 第二十九轮新增两个「选项自己说了算」的可选字段：
		#   · `shake`  —— 选了它震一下屏（力度，0/不填 = 不震；时长沿用 SHAKE_HIT 那套 0.8s）
		#   · `ending` —— 选了它直接收场（目前支持 "leak" = 说漏嘴暴露）
		if d.has("shake") and float(d.get("shake", 0.0)) > 0.0:
			item["shake"] = float(d["shake"])
		var eid := str(d.get("ending", ""))
		if eid != "":
			item["ending"] = eid
		item["_label"] = text
		out.append(item)
	return _letterize(out)

# 题面文本 —— 新格式叫 `text`，旧格式（内置常量）叫 `q`。
func _q_text(q: Dictionary) -> String:
	var t := str(q.get("text", ""))
	return t if t != "" else str(q.get("q", ""))

# 这道题是不是同行者问的 —— 新格式看 `speaker`，旧格式看 `kind`。
func _q_is_companion(q: Dictionary) -> bool:
	return str(q.get("speaker", "")) == "companion" or str(q.get("kind", "")) == "companion"

func _build_options(q: Dictionary) -> Array:
	# ★ 第二十九轮：新格式直接走统一实现（见上面的注释块）。
	if _is_unified_question(q):
		return _build_unified_options(q)

	match str(q.get("kind", "")):
		"fact":
			return _build_fact_options(q)
		"companion":
			return _build_companion_options(q)
		"blind":
			return _build_blind_options(q)

	# 档案题：考的是「这是不是 B 该知道的事」。
	#
	# 归类环节删掉之后，判定不再靠玩家事先分档 —— 改成**按卡的归属**：
	#   · A 卡（只有 A 才知道的事）→ 照实答就是当场说漏嘴，必死；
	#   · B 卡（属于 B 的档案范围）→ 照答即可，细节对得上。
	# 题面本身就是线索（「你颈侧那道印子」显然是雷区），
	# 选项 A 上写的就是那句话 —— 你得当场判断接不接。
	var card := DossierData.get_card(str(q.get("card", "")))
	var owner := str(card.get("owner", "B"))

	var primary := ""
	var delta := 0.0
	var kind := ""

	if owner == "A":
		primary = str(q.get("leak", ""))
		if primary == "":
			primary = _ut("interrogation.default_a_answer", "（你把这件事原原本本说了出来。）")
		delta = _rf("leak_delta", 100.0)
		kind = "leak"
	else:
		primary = str(q.get("answer", ""))
		if primary == "":
			primary = _ut("interrogation.default_b_answer", "（你照着「B」的档案，把细节对上了。）")
		delta = _rf("correct_delta", -6.0)
		kind = "ok"

	# 撒谎（B）/ 回避（C）的代价由「审问者的情报」决定 ——
	# 同一道题，换个人来问，风险完全不同：
	#   多疑 → 撒谎是死路；迟钝 → 撒谎反而安全；急躁 → 最恨被回避。
	var td := _trait_options(str(q.get("bluff", "")), str(q.get("evade", "")))

	# 第 4 项：沉默。一句话都不接 —— 不是撒谎，也不是回避。
	# 代价固定（比照 B 卡照答稍重一点），且与审问官的性情无关。
	# 题面数据里写了 silence 就用它，没写用通用那句。
	var silence := str(q.get("silence", ""))
	if silence == "":
		silence = _ut("interrogation.silence_text", SILENCE_TEXT)

	return _letterize([
		{"delta": delta, "kind": kind, "owner": owner, "_label": primary},
		{"delta": td["bluff_d"], "kind": "bluff", "owner": owner,
			"danger": td["bluff_danger"], "_label": td["bluff_text"]},
		{"delta": td["evade_d"], "kind": "evade", "owner": owner,
			"danger": td["evade_danger"], "_label": td["evade_text"]},
		{"delta": _rf("silence_delta", SILENCE_DELTA), "kind": "silence", "owner": owner, "_label": silence},
	])

# 给一组选项统一编上 A. / B. / C. / D. —— 数量随题目变（2 ~ 4 个）。
# 选项的正文放在临时的 `_label` 里传进来，编完就抹掉，免得留在数据里。
func _letterize(opts: Array) -> Array:
	var letters: Array = ScenarioData.ui_arr("common.option_letters", OPTION_LETTERS)
	if letters.is_empty():
		letters = OPTION_LETTERS
	for i in opts.size():
		var o: Dictionary = opts[i]
		var lab := str(o.get("_label", ""))
		o.erase("_label")
		o["text"] = str(letters[i % letters.size()]) + lab
	return opts

# ------------------------------------------------------------
#  「撒谎 / 回避」这两个选项的代价 —— 档案题与盲区题共用同一套算法。
#
#  代价来自审问官的性情（trait_delta），⚠ 标记则要求玩家**翻开过手机备忘录**
#  （情报读了才有用）。这两件事是分开的：就算没读过，代价照样生效 ——
#  只是你事先不知道而已。
# ------------------------------------------------------------
func _trait_options(bluff_text: String, evade_text: String) -> Dictionary:
	# 注意：局部变量不能叫 `trait` —— 那是 GDScript 保留字，会直接 Parse Error。
	var tr := DossierData.interrogator_trait()
	var known := GameData.interrogator_intel_read
	var bluff_danger := known and ScenarioData.trait_is_dangerous(tr, "bluff")
	var evade_danger := known and ScenarioData.trait_is_dangerous(tr, "evade")
	return {
		"bluff_d": ScenarioData.trait_delta(tr, "bluff"),
		"evade_d": ScenarioData.trait_delta(tr, "evade"),
		"bluff_danger": bluff_danger,
		"evade_danger": evade_danger,
		"bluff_text": ("⚠ " + bluff_text) if bluff_danger else bluff_text,
		"evade_text": ("⚠ " + evade_text) if evade_danger else evade_text,
	}

# ------------------------------------------------------------
#  盲区题 —— 「完全没给信息的题」
#
#  他问一件档案里没有、短信里也没提的事。题面不指向任何一张卡，
#  所以这里**没有「内容上的正确答案」**：
#
#    硬答（现编一个具体细节）→ 恒定重罚。编得越细，他越能顺着追问。
#    撒谎（给个模糊说法）    → 代价由性情决定
#    回避（把话头推回去）    → 代价由性情决定
#
#  唯一的安全解是「按他的脾性选」—— 而"该选哪个"**只能从手机备忘录
#  第一条推出来**（喜好 / 忌讳 / 该怎么答）。所以这一题的真正考点是：
#  你有没有读备忘录。
#
#  ★ 选项数量是可变的：题面给了 made_up（有东西可编）就摆三项，
#    没给就只有「撒谎 / 回避」两条路 —— 这是全篇最少的一项（2 个）。
#
#  判定时不比「内容」，只比撒谎与回避的代价谁低（见 _answer_blind）。
# ------------------------------------------------------------
func _build_blind_options(q: Dictionary) -> Array:
	var td := _trait_options(str(q.get("bluff", "")), str(q.get("evade", "")))
	var out := []
	# 题面给了「硬答」才摆这一项 —— 没给就只有撒谎 / 回避
	var made_up := str(q.get("made_up", ""))
	if made_up != "":
		out.append({"delta": _rf("blind_made_up_delta", BLIND_MADE_UP_DELTA), "kind": "made_up",
			"owner": "?", "blind": true, "_label": made_up})
	out.append({"delta": td["bluff_d"], "kind": "bluff",
		"owner": "?", "blind": true, "danger": td["bluff_danger"],
		"_label": td["bluff_text"]})
	out.append({"delta": td["evade_d"], "kind": "evade",
		"owner": "?", "blind": true, "danger": td["evade_danger"],
		"_label": td["evade_text"]})
	return _letterize(out)

# 说法题：三个版本摆在你面前，你得选一个 —— 选下去就是你的「口径」。
# 这里没有「正确答案」，只有「跟短信里对不对得上」和「跟你上次说的一不一样」。
func _build_fact_options(q: Dictionary) -> Array:
	var fid := str(q.get("fact", ""))
	var raw: Array = q.get("options", [])
	var letters: Array = ScenarioData.ui_arr("common.option_letters", OPTION_LETTERS)
	if letters.is_empty():
		letters = OPTION_LETTERS
	var out := []
	for i in raw.size():
		var o: Dictionary = raw[i]
		out.append({
			"text": str(letters[i % letters.size()]) + str(o.get("label", "")),
			"value": str(o.get("id", "")),
			"fact": fid,
			"kind": "fact",
			"owner": "B",
		})
	return out

# 同行者提问：和说法题结构一致 —— 每个选项带 value，所以走同一套口径判定。
# 区别只在于他多给一个 delta（他就是要让这句话进册子）和一段 plant 文案。
func _build_companion_options(q: Dictionary) -> Array:
	var fid := str(q.get("fact", ""))
	var raw: Array = q.get("options", [])
	var letters: Array = ScenarioData.ui_arr("common.option_letters", OPTION_LETTERS)
	if letters.is_empty():
		letters = OPTION_LETTERS
	var out := []
	for i in raw.size():
		var o: Dictionary = raw[i]
		out.append({
			"text": str(letters[i % letters.size()]) + str(o.get("text", "")),
			"delta": float(o.get("delta", 0.0)),
			"value": str(o.get("value", "")),
			"fact": fid,
			"kind": "companion",
			"owner": "B",
		})
	return out

func _ensure_questions() -> void:
	if _questions.is_empty():
		_questions = DossierData.questions_for_level(
			RunData.level_index, _ri("questions_per_level", QUESTIONS_PER_LEVEL))

func _load_question(index: int) -> void:
	_ensure_questions()
	if index >= _questions.size():
		_finish_interrogation()
		return

	current_question_index = index
	var q: Dictionary = _questions[index]

	# 换题了 —— 把上一题残留的 QTE / 干扰状态清干净。
	# ★ 按住型 QTE 的规则是「切到新题之后延迟几秒才开始，本题答完就结束」——
	#   所以每次换题都要把上一题的 QTE 收掉、重新排一个延迟。
	_auto_retract_phone()
	_cancel_qte()

	feedback_label.text = ""
	feedback_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.76))

	# ★ 第二十九轮：新格式的题目没有 `kind`，改看 `speaker` 字段（见 _q_is_companion）。
	var is_comp := _q_is_companion(q)
	var speaker := _ut("interrogation.speaker_companion", "同行者") if is_comp \
		else _ut("interrogation.speaker_interrogator", "审讯官")
	dialogue_label.text = speaker + "：" + _q_text(q)

	if is_comp:
		GameData.companion_asked += 1

	current_options = _build_options(q)
	_refresh_option_buttons()
	_set_options_enabled(true)
	interference_timer = interference_interval()

	# 这一题的 QTE 怎么排 —— 先读计划（编辑器可改），没写就按老规则自动判。
	# ★ 第二十九轮：新格式的题目没有 `kind`（传空串），但老的自动判定
	#   （needs_expression_for）还会遍历选项找 leak / made_up —— 所以照常有效。
	_apply_qte_plan(index, str(q.get("kind", "")), current_options)

# ------------------------------------------------------------
#  每题的 QTE 排期（第二十三轮，编辑器可改）
#
#  用户在编辑器里给每一道题指定「QTE 类型 + 出现时间」（data/story.json 的
#  "qte_plan"，门面见 OutfitData.qte_plan_entry）。五种取值：
#
#    "auto"（出厂默认）—— 完全按老规则：
#        · 表情 QTE 看 needs_expression_for（A 类题 / 盲区题 / 暴露值高）
#        · 递话干扰交给计时器，每若干秒随机来一次
#    "none"        —— 这道题什么都不出
#    "expression"  —— 强制出表情控制，delay 秒后弹
#    "interference"—— delay 秒后他递半句话（按一下空格打断）
#    "combo"       —— delay 秒后他递一整句（依次敲 J → K → L）
#
#  ★ 被指定的递话不再走计时器 —— 否则「准点来一次」之后还会随机再来，
#    和编辑器里写的时间对不上。所以换成 _intf_scheduled 这套排期。
# ------------------------------------------------------------
func _apply_qte_plan(index: int, kind: String, opts: Array) -> void:
	var plan := OutfitData.qte_plan_entry(index)
	# ★ 第二十九轮：**题目自带的 qte 优先**于「按题号」的全局计划表 ——
	#   每道题现在自己说了算（编辑器里逐题填类型与延迟）。
	#   支持两种写法：`"qte": "none"` 或 `"qte": {"kind": "...", "delay": 3.0}`。
	#   对象写法现在多认一个 `prompt` —— 这一道题专用的「QTE 上方提示文字」。
	var own: Variant = _current_question().get("qte", null)
	qte_prompt_used = ""
	if typeof(own) == TYPE_DICTIONARY:
		var od := own as Dictionary
		plan = {"qte": str(od.get("kind", OutfitData.QTE_AUTO)),
			"delay": float(od.get("delay", -1.0))}
		# ★ 第三十三轮（用户口径）：「QTE 上方显示的提示文字可以编辑」。
		#   题目自己写了就用它，留空则回落到全局那句（interrogation.qte_prompt）。
		qte_prompt_used = str(od.get("prompt", ""))
	elif typeof(own) == TYPE_STRING and str(own) != "":
		plan = {"qte": str(own), "delay": -1.0}
	var pk := str(plan.get("qte", OutfitData.QTE_AUTO))
	var pd := float(plan.get("delay", -1.0))
	qte_plan_kind = pk
	qte_plan_delay = pd
	_intf_scheduled = false
	_intf_kind_forced = ""
	_intf_delay_left = 0.0
	_intf_planned_used = false
	interference_timer = interference_interval()

	match pk:
		OutfitData.QTE_NONE:
			qte_needed = false
			qte_done = true
			qte_delay_left = 0.0
		OutfitData.QTE_EXPRESSION:
			qte_needed = true
			qte_done = false
			qte_delay_left = pd if pd >= 0.0 else _rf("expr_qte_delay", EXPR_QTE_DELAY)
		OutfitData.QTE_INTERFERENCE, OutfitData.QTE_COMBO:
			qte_needed = false
			qte_done = true
			qte_delay_left = 0.0
			_intf_scheduled = true
			_intf_kind_forced = "combo" if pk == OutfitData.QTE_COMBO else "single"
			_intf_delay_left = pd if pd >= 0.0 else interference_interval()
		_:
			# auto：老规则。要压表情的话不立刻弹 ——
			# 先让玩家看清题目，EXPR_QTE_DELAY 秒后才出现。
			qte_needed = needs_expression_for(index, kind, opts)
			qte_done = not qte_needed
			qte_delay_left = _rf("expr_qte_delay", EXPR_QTE_DELAY) if qte_needed else 0.0

# 这一题要不要压表情？（只有 "auto" 计划走这条路）
#
# ★★ 第三十三轮（用户口径）：「暴露值越高现在只会影响按住空格的 QTE 即表情管理的 QTE，
#    越高触发次数越多；表情管理 QTE 现在不会因为别的原因触发」。
#
#   于是触发条件**只剩两条**：
#     · 第 1 题恒不出 —— 开场先让你把第一句话说完（第十三轮定的，保留）；
#     · 其余看暴露值给出的概率（见 expression_qte_chance）。
#
#   ★ 本轮**删掉**的旧触发条件（就是那句「别的原因」）：
#     · 题目本身是盲区题（gap）/ 当场硬答（made_up）；
#     · 选项里有「说漏嘴」（leak）或「当场硬答」（made_up）。
#   ★ 「一个问题只会出现一次」是第十三轮定的设计，本轮**没动** ——
#     这里只决定「这一题出不出」，出与不出都由 qte_done 把这一题锁死。
#
#   ★ 题目**显式**写了 `qte: expression` 的仍然照出 —— 那是作者的手动安排，
#     不属于「自动触发」，见 _apply_qte_plan。
func needs_expression_for(index: int, kind: String, opts: Array) -> bool:
	if index <= 0:
		return false
	return _expr_qte_roll(index)

# 暴露值换算出的触发概率（0~1）：
#   p = (暴露值 − exposure_qte_min) / (exposure_qte_full − exposure_qte_min)
#   暴露 ≤ min → 一次都不出；≥ full → 每题必出；中间线性。
#   ★ 按当前接受度推算，四关穿到满暴露时大致是 24% / 44% / 64% / 88% ——
#     越往后越常被盯，同一关里穿得越露也越频繁。
func expression_qte_chance() -> float:
	var e := float(GameData.outfit_exposure)
	var lo := _rf("exposure_qte_min", EXPOSURE_QTE_MIN)
	var hi := _rf("exposure_qte_full", EXPOSURE_QTE_FULL)
	if hi <= lo:
		return 1.0 if e >= hi else 0.0
	return clampf((e - lo) / (hi - lo), 0.0, 1.0)

# 稳定摇一次：同一局 / 同一关 / 同一道题 → 结果固定。
#   ★ 不能用运行时 RNG：同一道题可能被反复装载（来回切题、重来本轮、测试里多次 _load），
#     每次现摇会变成「同一题有时出有时不出」，玩家莫名其妙、测试也没法断言。
func _expr_qte_roll(index: int) -> bool:
	var p := expression_qte_chance()
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	var key := "%d|%d|%d|expr" % [RunData.seed_value, RunData.level_index, index]
	var roll := float(absi(hash(key)) % 10000) / 10000.0
	return roll < p

# 把 current_options 刷到按钮池上 —— 数量可变（2 ~ 4），按需补齐、多余的藏起来。
func _refresh_option_buttons() -> void:
	var n := current_options.size()
	while option_btns.size() < n:
		var nb := _make_option_button(option_btns.size())
		opts_box.add_child(nb)
		option_btns.append(nb)
	for i in option_btns.size():
		var b: Button = option_btns[i]
		if i < n:
			var o: Dictionary = current_options[i]
			b.text = str(o["text"])
			b.disabled = false
			b.show()
			# 「读过情报才知道的雷区」用暖红标出来
			if bool(o.get("danger", false)):
				b.add_theme_color_override("font_color", Color(0.98, 0.60, 0.52))
			else:
				b.remove_theme_color_override("font_color")
		else:
			b.text = "——"
			b.disabled = true
			b.hide()
			b.remove_theme_color_override("font_color")

func _set_options_enabled(on: bool) -> void:
	for b in option_btns:
		b.disabled = not on

func _select_option(opt_index: int) -> void:
	if _ended or interference_active:
		return
	# ★ 按住型 QTE 期间**不拦答题** —— 你可以一边按着空格压表情，一边点选项。
	#   （手机这时是锁着的，见 _toggle_phone。）答案一落定，本题的 QTE 就结束。
	if opt_index < 0 or opt_index >= current_options.size():
		return
	# 回答完毕，手机自动收回 —— 不用先关掉手机才让你答题
	_auto_retract_phone()
	_record_answer(opt_index)

	var opt: Dictionary = current_options[opt_index]
	var kind := str(opt["kind"])
	var owner := str(opt["owner"])

	# ★ 第二十九轮：`ending` 是**选项自己指定**的收场方式 ——
	#   和 tone 分开，所以「照实答」这类选项也能被写成一句话把人送走。
	var ending := str(opt.get("ending", ""))
	if ending == "leak":
		_add_suspicion(_rf("leak_delta", 100.0))
		_instant_exposure("说漏嘴")
		return

	if kind == "leak":
		_add_suspicion(_rf("leak_delta", 100.0))
		_instant_exposure("说漏嘴")
		return

	if kind == "fact":
		_answer_fact(opt)
		return

	# 同行者的提问和审讯官的题走同一套判定
	if kind == "companion":
		_answer_companion(opt)
		return

	# 盲区题：不比内容，只比「有没有按他的脾性选」
	if bool(opt.get("blind", false)):
		_answer_blind(opt)
		return

	_add_suspicion(float(opt["delta"]))

	match kind:
		"ok":
			if owner == "A":
				feedback_label.text = _ut("feedback.card_ok_a",
					"你没有接这个话头。审讯官盯着你看了两秒，翻过一页。")
			else:
				feedback_label.text = _ut("feedback.card_ok_b",
					"你照着整理好的档案作答，细节对得上，审讯官在记录本上划掉了一项。")
		"gap":
			feedback_label.text = _ut("feedback.card_gap",
				"你答不出细节。审讯官的笔尖停了一下 —— 一个跑这条线多年的商人，不该记不住这些。")
		"bluff":
			# 撒谎的后果因人而异 —— 文案就是「审问者的情报」在盘问里的回声
			var bn := DossierData.trait_note("bluff")
			feedback_label.text = bn if bn != "" \
				else _ut("feedback.card_bluff_default",
					"你临时编了个说法。审讯官没接话，只是把它记了下来。")
		"evade":
			var en := DossierData.trait_note("evade")
			feedback_label.text = en if en != "" \
				else _ut("feedback.card_evade_default",
					"你把问题推了回去。这种回避本身也算一种回答。")
		"silence":
			feedback_label.text = _ut("feedback.card_silence",
				"你一个字都没接。他盯着你看了几秒，把这一页翻了过去 —— "
				+ "但翻之前，他在页角折了一下。")

	# ★ 第二十九轮：选项可以要求「选完震一下」（`shake` 填力度，不填就不震）
	if opt.has("shake"):
		shake(float(opt["shake"]), 0.8)

	_set_options_enabled(false)
	_after_answer()

# 记一笔「本轮问过什么、你怎么答的」—— 备注界面靠它按轮次回放。
func _record_answer(opt_index: int) -> void:
	var q := _current_question()
	# ★ 第二十九轮：备注只回放「他问你答」的那两类 ——
	#   档案题（挂了卡）与盲区题（既不挂卡也不挂事实）。
	#   事实题 / 同行者题问的是「口径」，不进备注。
	var has_card := str(q.get("card", "")) != ""
	var has_fact := str(q.get("fact", "")) != ""
	if _q_is_companion(q) or not (has_card or not has_fact):
		return
	var text := ""
	if opt_index >= 0 and opt_index < current_options.size():
		text = str((current_options[opt_index] as Dictionary).get("text", ""))
	var qtext := _q_text(q)
	GameData.answer_log.append({
		"level": RunData.level_index,
		"q": qtext,
		"answer": text,
	})

# 答完题的统一收尾（第十三轮）：
#   · 若这一题本来安排了 QTE —— 它**此刻就结束**（本题回答完毕 = QTE 结束）；
#     结束前按「玩家有没有一直按住」判定成败。
#   · 否则直接进下一题。
#  注意：QTE 可能还没到点弹出来（延迟中被答完），那也是「本题已结束」，
#  直接取消、不算失败 —— 你答得太快了，他没来得及盯你的脸。
func _after_answer() -> void:
	_finish_qte_for_question()
	_next_question_delay()

# ---------------- 口径一致性（说法题 / 同行者题共用）----------------
#  第一次说 → 这句话就是你的「口径」，写进册子。
#  再说一次时必须一样，否则就是前后矛盾。
#  返回 true 表示这一次构成了矛盾。
func _record_statement(fid: String, val: String) -> bool:
	var prev := str(GameData.stated_facts.get(fid, ""))
	if prev == "":
		GameData.stated_facts[fid] = val
		return false
	return val != prev

# 矛盾累计到上限 → 当场识破。返回 true 表示已经结束了本轮。
func _maybe_exposed_by_contradiction() -> bool:
	if GameData.contradictions < _ri("contradiction_limit", CONTRADICTION_LIMIT):
		return false
	_add_suspicion(_rf("leak_delta", 100.0))
	_instant_exposure("前后矛盾")
	return true

func _current_question() -> Dictionary:
	if current_question_index >= 0 and current_question_index < _questions.size():
		return _questions[current_question_index]
	return {}

# ---------------- 说法题：口径一致性 ----------------
#  ★ 第十三轮：一轮（一关）之内**不会**出现前后矛盾 ——
#    同一关里不会再问同一个事实第二遍（见 RunData 的出题编排），
#    所以这里的 `first` 分支在一关里至多走一次。
#    真正会翻车的只有「跨关复问」：翻出**前面几轮**立过的说法来问。
#    「前后矛盾」的判定仍然保留在 `else` 分支里 —— 那是跨关复问走的路。
#  轮内怀疑度只涨不跌：答对口径不再给负奖励，只写文案。
func _answer_fact(opt: Dictionary) -> void:
	var fid := str(opt.get("fact", ""))
	var val := str(opt.get("value", ""))
	var canonical := DossierData.canonical_value(fid)
	var prev := str(GameData.stated_facts.get(fid, ""))
	var label := DossierData.fact_value_label(fid, val)
	var recall: bool = bool(_current_question().get("recall", false))
	var first: bool = prev == ""

	if first:
		GameData.stated_facts[fid] = val
		if val == canonical:
			feedback_label.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
			if GameData.known_facts.has(fid):
				feedback_label.text = _ut("feedback.fact_correct_known",
					"你说的是短信里那个版本 —— 和东家、家人对得上。他点了点头。")
			else:
				feedback_label.text = _ut("feedback.fact_correct_unknown",
					"你随口给了个说法。听起来挺自然 —— "
					+ "但愿它跟别处对得上。（你还没在短信里确认过这一条）")
		else:
			GameData.improvised += 1
			_add_suspicion(_rf("improvise_penalty", IMPROVISE_PENALTY))
			feedback_label.add_theme_color_override("font_color", Color(0.94, 0.72, 0.34))
			feedback_label.text = _ut("feedback.fact_improvise",
				"你把「%s」说成了「%s」—— 这跟短信里的口径不一样。\n"
				+ "他现在还不知道。但这句话已经进了册子。") \
				% [DossierData.fact_prompt_name(fid), label]
	else:
		if val == prev:
			feedback_label.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
			feedback_label.text = _ut("feedback.fact_repeat_same",
				"你说得跟上次一模一样，一个字都没差。"
				+ "他抬了下眉毛，没说什么。")
		else:
			GameData.contradictions += 1
			_add_suspicion(_rf("contradiction_penalty", CONTRADICTION_PENALTY))
			feedback_label.add_theme_color_override("font_color", Color(0.96, 0.38, 0.36))
			feedback_label.text = _contradiction_text(fid, prev, val, recall)

	_set_options_enabled(false)
	if _ended:
		return
	if _maybe_exposed_by_contradiction():
		return
	_after_answer()

# 矛盾文案：把「跟哪条对不上」写明白 ——
#   哪件事、上次说的是什么、这次说成了什么、是哪一轮说的。
func _contradiction_text(fid: String, prev: String, now: String, recall: bool) -> String:
	var name := DossierData.fact_prompt_name(fid)
	var head := _ut("feedback.contradiction_head_recall",
		"【前后矛盾】这件事你在前面某一轮已经答过了 ——") if recall \
		else _ut("feedback.contradiction_head_plain",
			"【前后矛盾】同一件事，你前后说出了两套说法 ——")
	return (head + "\n" + _ut("feedback.contradiction_body",
		"  · 对不上的是：「%s」\n  · 上次你说的是：「%s」\n  · 这次你说成了：「%s」\n"
		+ "他翻回前一页，把两句话并排放在一起 —— 没有抬头，但笔尖停住了。") % [
		name, DossierData.fact_value_label(fid, prev), DossierData.fact_value_label(fid, now)])

# ---------------- 同行者提问 ----------------
#  他刚听见你立下的说法，立刻抛一个错的版本试你。
#  判定和说法题完全一样：顺着他说 = 跟自己的口径对不上 = 前后矛盾。
#  唯一的差别是：无论你怎么答，这句话都进了册子（plants +1）。
func _answer_companion(opt: Dictionary) -> void:
	var fid := str(opt.get("fact", ""))
	var val := str(opt.get("value", ""))
	var delta := float(opt.get("delta", 0.0))
	var q := _current_question()

	GameData.plants += 1
	_add_suspicion(delta)

	var prev := str(GameData.stated_facts.get(fid, ""))
	feedback_label.add_theme_color_override("font_color", Color(0.90, 0.68, 0.36))

	# ★ 第十三轮：**他这一问不再构成前后矛盾**。
	#   理由：他就在同一关里、你刚立完说法之后插这句话 ——
	#   在一轮之内给出「顺着他就前后矛盾」的选项，等于把跨轮的规则提前用掉，
	#   那不叫推理，叫陷阱。现在他这一问只做两件事：
	#     ① 把错版本塞进册子（plants +1，他从不做无用功）；
	#     ② 你若顺着他说，就按这个选项的代价涨怀疑度（立场动摇，但不算矛盾）。
	#   真正的「前后矛盾」只在**跨关复问**里出现（见 _answer_fact 的 else 分支）。
	if val == "":
		feedback_label.text = _ut("feedback.companion_no_value",
			"你没有正面接他这句话。他还是把话头留在了桌上 —— 审讯官都听见了。")
	elif prev == "":
		feedback_label.text = _ut("feedback.companion_first",
			"（你没接他的话头 —— 不认，也不否认。"
			+ "审讯官看了你一眼，没说什么；同行者笑了笑。）")
	elif val == prev:
		feedback_label.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
		feedback_label.text = _ut("feedback.companion_same",
			"你顶了回去，说的还是那套说法。他笑了一下，转头去看审讯官的表情。")
	else:
		feedback_label.add_theme_color_override("font_color", Color(0.96, 0.56, 0.36))
		feedback_label.text = _ut("feedback.companion_sway",
			"你顺着他的话说了下去 —— 这可跟你之前那句对不上。\n"
			+ "  · 你说过的是：「%s」\n  · 这次顺着他：「%s」\n"
			+ "（这一轮里还不算「前后矛盾」—— 但你的说法已经开始摇晃了。）") % [
			DossierData.fact_value_label(fid, prev), DossierData.fact_value_label(fid, val)]

	# 右侧栏删掉之后，他种下的那句话就接在反馈下面
	var plant := str(q.get("plant", ""))
	if plant != "":
		feedback_label.text += "\n\n" + plant

	_set_options_enabled(false)
	if _ended:
		return
	_after_answer()

# ------------------------------------------------------------
#  盲区题判定 —— 「完全没给信息的题」
#
#  这题**没有「内容上的正确答案」**：档案里没有、短信里也没提，
#  所以判定只做一件事 —— 比较 B（撒谎）与 C（回避）的代价，谁低谁对。
#  而"哪个低"完全由审问官的性情决定，性情写在手机备忘录第一条。
#
#  所以选完无论对错，都把备忘录第一条摆到反馈里 ——
#  这一题就是用来教玩家「备忘录有用」的，反馈里必须让他看见那两行。
# ------------------------------------------------------------
func _answer_blind(opt: Dictionary) -> void:
	var kind := str(opt.get("kind", ""))
	var delta := float(opt.get("delta", 0.0))
	_set_options_enabled(false)

	var bluff_d := DossierData.trait_delta("bluff")
	var evade_d := DossierData.trait_delta("evade")
	# 两个都不便宜时，选相对轻的那个 —— 这题考的从来不是「有没有零代价的选项」
	var right_kind := "bluff" if bluff_d < evade_d else "evade"

	var head := ""
	if kind == "made_up":
		feedback_label.add_theme_color_override("font_color", Color(0.96, 0.38, 0.36))
		head = _ut("feedback.blind_made_up",
			"你当场编了个具体的细节。他顺着往下追了两句 —— 你接不上。\n"
			+ "（这题你手里本来就没底：编得越细，他越能往下追。）")
	else:
		var note := DossierData.trait_note(kind)
		head = note if note != "" else _ut("feedback.blind_default", "你说完，他没有立刻接话。")
		if kind == right_kind:
			feedback_label.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
			head += _ut("feedback.blind_right", "\n（选对了 —— 他这种人吃的就是这一套。）")
		else:
			feedback_label.add_theme_color_override("font_color", Color(0.90, 0.68, 0.36))
			head += _ut("feedback.blind_wrong", "\n（选错了 —— 他这种人不吃这一套。）")

	# 把备忘录第一条原样贴出来：这一题的正解只能从它推出来
	var tail := _ut("feedback.blind_tail", "【备忘录第一条】%s · 忌讳：%s") % [
		DossierData.interrogator_trait_name(), DossierData.interrogator_hate()]
	var hint := DossierData.interrogator_hint()
	if hint != "":
		tail += _ut("feedback.blind_tail_hint", "\n该怎么答：") + hint

	# 先写反馈再扣分 —— 扣到 100 会直接 _game_over()，
	# 但玩家仍然该看到「为什么这一答就崩了」。
	feedback_label.text = head + "\n" + tail

	_add_suspicion(delta)
	if _ended:
		return
	_after_answer()

# ------------------------------------------------------------
#  表情 QTE（按住型）—— 第十三轮重做
#
#  规则（用户口径）：
#    · 切到新题之后**延迟 EXPR_QTE_DELAY 秒**才开始 —— 先让你看清题目，
#      而不是题刚蹦出来就被迫按住空格；
#    · **只有一个阶段**：一题一次，本题回答完毕（或答完最后一题）就结束；
#    · 面板是**覆盖层**，弹出来 / 收起来都不动布局 —— 底下那排
#      「掏出手机」按钮不会被挤走；
#    · QTE 期间**手机用不了**（用户口径：「按住空格的 qte 时不再能够使用手机」）：
#      手里那部自动收回、按钮变灰，压完表情才解锁。
#      答题本身不拦 —— 答案一落定，QTE 立刻结算。
# ------------------------------------------------------------
## 延迟到点 → 弹出面板。由 _process 调用。
func _begin_qte() -> void:
	if is_qte_active or qte_done or _ended:
		return
	is_qte_active = true
	qte_progress = 50.0
	qte_timer = _rf("expr_qte_time", EXPR_QTE_TIME)
	# ★ 第三十三轮：题目自带 `qte.prompt` 优先，否则用全局那句（两者在编辑器里都能改）。
	if qte_prompt_used.strip_edges() != "":
		qte_label.text = qte_prompt_used
	else:
		qte_label.text = _ut("interrogation.qte_prompt",
			"按住 [空格 / 鼠标左键] 压制心跳 —— "
			+ "把表情维持在绿色区间！（照常答题，手机得先收起来）")
	qte_bar.value = qte_progress
	qte_container.show()
	# 手机锁上：收回来 + 按钮变灰
	_set_phone_locked(true)

## 本题的 QTE 到此为止：算成败、收面板、标记做完。
## 三个入口都会走到这儿：答完题、超时、被识破 / 逮捕。
func _finish_qte_for_question() -> void:
	if not is_qte_active and not qte_needed:
		return
	if is_qte_active:
		is_qte_active = false
		qte_container.hide()
		if qte_progress >= _rf("expr_qte_pass", EXPR_QTE_PASS):
			# ★ 压住表情只是「没露破绽」—— 它不把怀疑度往下压。
			feedback_label.text = _ut("interrogation.qte_pass",
				"【表情控制成功】你的呼吸稳住了，脸上没有露出破绽。")
			shake(_rf("shake_qte_pass", SHAKE_QTE_PASS), 0.18)
		else:
			feedback_label.text = _ut("interrogation.qte_fail",
				"【表情控制失败】你的微表情抽动了一下 —— 他看见了。")
			_add_suspicion(_rf("expr_qte_fail", EXPR_QTE_FAIL))
			shake(_rf("shake_qte_fail", SHAKE_QTE_FAIL), 0.42)
	qte_done = true
	qte_delay_left = 0.0
	# 压完表情 → 手机解锁（整局已经结束时不解锁，那时按钮本来就该一直是灰的）
	if not _ended:
		_set_phone_locked(false)

## 换题 / 收尾时把上一题的 QTE 状态清干净（不算成败）。
func _cancel_qte() -> void:
	is_qte_active = false
	qte_needed = false
	qte_done = true
	qte_delay_left = 0.0
	qte_progress = 0.0
	# 被编辑器指定的「准点递话」跟着本题一起收掉 —— 它属于这一道题，
	# 不能带到下一题去（否则上一题排的那一次会在新题上冒出来）。
	_intf_scheduled = false
	_intf_delay_left = 0.0
	_intf_kind_forced = ""
	_intf_planned_used = false
	if qte_container != null:
		qte_container.hide()
	if not _ended:
		_set_phone_locked(false)

# 兼容旧调用名（测试与截图脚本还在用 _start_expression_qte）：
# 现在它等价于「立刻把这一题的 QTE 弹出来」。
func _start_expression_qte(_suspicion_on_fail: float = 0.0) -> void:
	qte_needed = true
	qte_done = false
	qte_delay_left = 0.0
	_begin_qte()

# 兼容旧调用名：把当前 QTE 结算掉（旧语义是「end_expression_qte」）。
func _end_expression_qte() -> void:
	_finish_qte_for_question()

# ---------------- 同行者干扰（可 QTE 抵抗）----------------
#  他凑到审讯官耳边递半句话 —— 2.6 秒内按 [空格] 截断。
#  每 3 次里有一次是**组合干扰**：他递的是一整句要紧的，得依次敲 J → K → L。
#  他的「提问」不走这里，那是正式题目（见 _answer_companion）。
func _start_interference() -> void:
	# 护栏：压表情期间不排递话 —— 两条提示条共用屏幕最下方那一层，
	# 真让它们同时出现就会叠在一起。（正常流程里 _process 已经把这条挡住了，
	# 这里再兜一层，截图脚本 / 测试直接调也不会把版式弄乱。）
	if is_qte_active:
		return
	interference_active = true
	interference_time_left = _rf("interference_window", INTERFERENCE_WINDOW)
	interference_count += 1
	# 第 3、6、9…… 次是组合干扰。规则是确定的 —— 同一局同一关可复现。
	# ★ 被编辑器指定类型时不看这个计数，就用指定的那一种。
	if _intf_kind_forced != "":
		interference_kind = _intf_kind_forced
		_intf_planned_used = true
	else:
		interference_kind = "combo" if (interference_count % _ri("combo_every", COMBO_EVERY)) == 0 else "single"
	combo_index = 0
	_set_options_enabled(false)

	var lines: Array = DossierData.interference_lines()
	var line: String = _ut("interrogation.intf_default_line", "（他凑到审讯官耳边，声音压得很低。）")
	if not lines.is_empty():
		line = str(lines[interference_count % lines.size()])
	# 右侧栏删掉之后，他递的那句话直接摆在干扰条上 ——
	# 你既看得见他递的是什么，也看得见该敲哪个键。
	interference_line = line
	_update_interference_prompt()
	intf_bar.value = 100.0
	intf_container.show()

# 干扰提示条：单键一种写法，组合一种写法（组合会把「敲到第几个」画出来）
#  ★ 一律排成**一行**：提示条和 QTE 条共用屏幕最下方那一层，
#    高度必须是确定的（两行就会高出一截，压到选项区去）。
func _update_interference_prompt() -> void:
	var head := ""
	if interference_line != "":
		head = interference_line + " "
	if interference_kind != "combo":
		intf_label.text = head + _ut("interrogation.intf_single", "⚠ 立刻按 [空格] 打断他！")
		return
	var keys := combo_keys()
	var n := mini(_ri("combo_len", COMBO_LEN), keys.size())
	var parts := []
	for i in n:
		var k := _key_text(int(keys[i]))
		if i < combo_index:
			parts.append(k + " ✓")
		elif i == combo_index:
			parts.append("【" + k + "】")
		else:
			parts.append(k)
	intf_label.text = head + _ut("interrogation.intf_combo_prefix", "⚠ 依次敲 ") \
		+ " → ".join(parts) + _ut("interrogation.intf_combo_suffix", " 打断他！")

func _key_text(keycode: int) -> String:
	return OS.get_keycode_string(keycode)

# 组合干扰的按键输入。
# 注意：_process 里那套「按住空格」是表情 QTE 的，这里必须是**按下**事件 ——
# 组合键没有「按住」的说法，敲完就算。
func _input(event: InputEvent) -> void:
	if not _running or _ended:
		return
	if not interference_active or interference_kind != "combo":
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	press_combo_key(k.keycode)

# 公开方法 —— 测试直接调它，不用伪造 InputEvent。
# 敲对一个键就往前推一格；敲错当场判负（组合干扰本来就没有「试错」的余地）。
func press_combo_key(keycode: int) -> void:
	if not interference_active or interference_kind != "combo":
		return
	var keys := combo_keys()
	var n := mini(_ri("combo_len", COMBO_LEN), keys.size())
	if combo_index < n and keycode == int(keys[combo_index]):
		combo_index += 1
		_update_interference_prompt()
		if combo_index >= n:
			_end_interference(true)
	else:
		_end_interference(false)

func _end_interference(success: bool) -> void:
	interference_active = false
	interference_kind = "single"
	combo_index = 0
	intf_container.hide()
	interference_timer = interference_interval()

	if success:
		interference_blocked += 1
		# 打断成功本来给 −3 的奖励 —— 第十三轮起轮内只涨不跌，
		# 这里的负增量会被 _add_suspicion 拦掉，所以干脆不给（省得读者误解）。
		feedback_label.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
		feedback_label.text = _ut("interrogation.intf_blocked",
			"（你把话头截了回去。他耸耸肩，把手收了回去。）")
	else:
		_add_suspicion(_rf("interference_fail_penalty", 18.0))
		feedback_label.add_theme_color_override("font_color", Color(0.96, 0.38, 0.36))
		feedback_label.text = _ut("interrogation.intf_failed",
			"（他成功把审讯官的目光引到了你身上。你慢了半拍。）")
		shake(_rf("shake_interference_fail", 8.0), 0.36)

	if not _ended:
		_set_options_enabled(true)

# ---------------- 结算 ----------------
func _next_question_delay() -> void:
	await get_tree().create_timer(1.8).timeout
	if _ended:
		return
	_load_question(current_question_index + 1)

# ★ 第十三轮：**轮内怀疑度只涨不跌**。
#   所有奖励性的负增量一律归零 —— 想靠一两次「答得漂亮」把怀疑度刷下去，不行。
#   唯一能让怀疑度降下来的地方是**轮次之间**的衰减（见 GameData.reset_level_state）。
#
# ★ 第三十九轮：妙妙工具「尼古喵尾」（见 OutfitData.MANUAL_SLOTS 的 tool 栏）。
#   用户口径：「效果装备时，无论选择什么选项都不会提高怀疑值，
#            但是触发游戏结束的选项依然会使游戏结束」。
#   所以这里只拦**非致命**的增量；一击必杀的那条路照旧放行。
func _add_suspicion(amount: float) -> void:
	# 「致命」的判据用 `leak_delta`（默认 100）：会直接把这一局送走的选项
	# （说漏嘴 / 指定 ending 的那些）都是拿它当增量 —— 一次顶满 100。
	# 其余**一切**增量（答错 / 沉默 / 编造 / 前后矛盾 / 表情 QTE 失败 / 掏手机越界……）
	# 都远小于这个数，装备尼古喵尾时一律不生效。
	# ★ 用规则里的值而不是写死 100 —— 编辑器把 leak_delta 调成别的数时这里自动跟上。
	if GameData.carried_tool(TOOL_TAIL_ID) \
			and amount < _rf("leak_delta", 100.0):
		return
	var delta := maxf(0.0, amount)
	GameData.suspicion_level = clampf(GameData.suspicion_level + delta, 0.0, 100.0)
	_update_suspicion_ui()
	if GameData.suspicion_level >= 100.0:
		_game_over()

func _update_suspicion_ui() -> void:
	suspicion_bar.value = GameData.suspicion_level
	var col: Color
	if GameData.suspicion_level < 40.0:
		col = Color(0.12, 0.62, 0.46)
	elif GameData.suspicion_level < 70.0:
		col = Color(0.94, 0.62, 0.15)
	else:
		col = Color(0.89, 0.29, 0.29)
	_style_bar(suspicion_bar, col)
	if suspicion_val != null:
		suspicion_val.text = "%d%%" % int(round(GameData.suspicion_level))
		suspicion_val.add_theme_color_override("font_color", col)

func _finish_interrogation() -> void:
	_ended = true
	_running = false
	_auto_retract_phone()
	_cancel_qte()
	phone_btn.disabled = true
	for b in option_btns:
		b.disabled = true
		b.text = "——"

	var who := RunData.interrogator()
	var passed: bool = GameData.suspicion_level < _rf("pass_suspicion", PASS_SUSPICION)
	# 这一轮结束时的怀疑度留给下一轮 —— 轮次之间按比例衰减（见 GameData.reset_level_state）
	GameData.suspicion_carry = GameData.suspicion_level
	if passed:
		dialogue_label.text = _et("success_line",
			"【潜伏成功】\n%s：「没有问题了，%s。你可以过去了。」\n\n"
			+ "你以 B 的身份通过了盘问。同行者站在一旁，什么也没说，只是看了你一眼。"
		) % [who, RunData.cover_role()]
	else:
		_end_reason = "suspicion"
		dialogue_label.text = _et("arrested_line",
			"【潜伏失败 · 被捕】\n%s：「逮捕他。他的身份漏洞百出。」\n\n"
			+ "同行者始终没有揭穿你 —— 但也没打算让你过关。"
		) % who

	feedback_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.76))
	feedback_label.text = _ut("feedback.summary",
		"同行者：插话提问 %d 次（钉子 %d 颗）· 递话干扰 %d 次（拦下 %d 次）；"
		+ "归类错误 %d 条；前后矛盾 %d 次。") % [
		GameData.companion_asked, GameData.plants,
		interference_count, interference_blocked,
		GameData.dossier_mistakes, GameData.contradictions]

	_show_result(passed)

# ---------------- 结果按钮 ----------------
func _show_result(success: bool) -> void:
	if _result_shown:
		return
	_result_shown = true
	_success = success

	var last_level: bool = RunData.level_index >= RunData.level_count() - 1
	if success:
		if last_level:
			result_hint.text = _et("result_last_hint", "这是本局最后一关。你已经把这一整段路走完了。")
			result_btn.text = _et("result_last_btn", "完成本局  ➔")
		else:
			result_hint.text = _et("result_next_hint",
				"本轮通过。接受度提升 %d，暴露值上限随之放宽 —— "
				+ "但下一轮要求的反差值也更高。") \
				% int(RunData.current_level().get("acceptance_gain", 0))
			result_btn.text = _et("result_next_btn", "进入下一轮  ➔")
	else:
		if _end_reason == "recognized":
			result_hint.text = _et("result_recognized_hint",
				"他一眼就叫出了你的名字 —— 这一身没能把 A 盖住。\n"
				+ "回到这一轮的准备室，重新改一遍打扮。")
			result_btn.text = _et("result_recognized_btn", "重来本轮  ↺")
		else:
			result_hint.text = _et("result_fail_hint",
				"这一轮到此为止 —— 回到这一轮的准备室重来。\n"
				+ "背景与他的记忆都不变，你已经查到的情报也还在。")
			result_btn.text = _et("result_fail_btn", "重来本轮  ↺")

	result_hint.show()
	result_btn.show()

func _game_over() -> void:
	_ended = true
	_running = false
	is_qte_active = false
	interference_active = false
	interference_kind = "single"
	combo_index = 0
	if _end_reason == "":
		_end_reason = "gameover"
	_cancel_qte()
	intf_container.hide()
	_auto_retract_phone()
	phone_btn.disabled = true
	shake(_rf("shake_hit", SHAKE_HIT), 0.8)
	dialogue_label.text = _et("caught_line",
		"【警告：怀疑度到达 100%】\n卫兵蜂拥而上将你当场扣押 —— 伪装彻底崩了。")
	for b in option_btns:
		b.disabled = true
		b.text = "——"
	_show_result(false)
