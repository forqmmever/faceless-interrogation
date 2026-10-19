extends Node

# ============================================================
#  多轮制编排 + 开始界面
#
#  一局（run）：
#    开始界面（开始 / 继续 / 退出）
#      ↓
#    选关面板（先挑一套背景 + 2 个入口；两轮都可以直接进 —— OutfitData.OPEN_LEVELS）
#      ↓
#    随机生成 A 的原貌（背景是玩家挑的，★ 第七十三轮起不再随机）
#      ↓
#    准备室（换装 + 手机）  ← 第 1 关
#      ↓
#    高压盘问
#      ├─ 开场：他抬眼，认出你 → 「怎么是你，<A 真身名>」
#      ├─ 通过 → 第 2 关（背景与原貌不变，接受度提升、反差要求提高）
#      ├─ 通过 → 第 3 关 … 第 4 关
#      ├─ 任何一关失败 → **回到本轮开始**（本轮的准备室，见 _retry_level）
#      └─ 第 4 关通过 → 整局结束，重新抽背景与原貌，从头再来
#
#  为什么这样切：
#    「本轮失败就回本轮重来」把每一次盘问都变成真赌注，又不至于让玩家
#    把前面几轮辛苦查到的情报一起赔进去 —— 他记忆里的那张脸没变，
#    要改的只是这一轮的打扮；
#    「背景与原貌每局重抽」则保证新的一局不是背答案，而是重新推理。
#
#  ★ 准备室**不判定**：它只把反差值 / 缺陷 / 强制装备摊开给你看，不锁门。
#    能不能骗过他，是门开那一刻才算的（见 Interrogation.start_interrogation）。
#
#  ★ 存档分两层：
#    ProfileData —— 账号级（跨局累积的接受度、战绩），失败也不退；
#    RunSave     —— 局内（打到第几轮、那身打扮、手机进度），供「继续游戏」。
#    每进一关、每改一次打扮都写一次 RunSave，所以直接关窗口也不会丢。
# ============================================================

@onready var wardrobe: Control = $Wardrobe
@onready var interrogation: Control = $Interrogation

# 制作人名单的出厂兜底（真身在 story.json 的 ui.title.credits_body，编辑器可改）
const DEFAULT_CREDITS := "美术素材：dol au美化包\n策划：hey_unmu  deepseek-V4-flash\n文案：hey_unmu\n代码 deepseek-V4-flash\n测试 deepseek-V4-flash\n\n灵感来源 千面人在此，Degrees of Lewdity，一诺千劫阿雅篇"

var overlay: Control
var overlay_title: Label
var overlay_body: RichTextLabel
var overlay_btn: Button

# ---- 开始界面 ----
var title_screen: Control
var title_info: Label
var title_start_btn: Button
var title_continue_btn: Button
var title_quit_btn: Button
var title_credits_btn: Button

# ---- 制作人名单（第六十四轮）----
var credits_layer: Control
var credits_body_label: Label
var credits_back_btn: Button

# ---- 选关面板（第二十一轮）----
# 「开始游戏」之后先出这一层：本局背景 + 各轮入口，只有开放的那几轮点得动。
var level_select: Control
var level_select_rows: Array = []      # [{btn, note, li}]
# ★ 第八十四轮：轮次行单独一个容器 —— 换背景时整个清掉重建（名字要跟着变）
var level_rows_box: VBoxContainer
var level_select_back_btn: Button
# ★ 第五十三轮：本局背景选择 —— [{btn, id}]
# ★ 第七十三轮：不再有 id 为空串的「随机」那一颗 —— 每颗都是具体背景。
var level_select_bg_btns: Array = []
# 选中的背景 id。★ 第七十三轮起它**不会是空串**（面板保证总有一套选中），
#   并且跟着实际开局走：`_start_new_run()` / `_continue_run()` 都会把它设成本局的背景，
#   所以「面板下次打开默认选谁」与「再来一局用哪套」都以它为准。
var _pending_bg_id: String = ""

var _pending_action: String = ""   # "next_level" | "retry_level" | "new_run"

# ---- 文案读取助手（都带出厂兜底）----
#  文案与数值的真身在 data/story.json 的 "ui" / "rules" 段，编辑器可改。
#  这里取不到就退回 ScenarioData.DEFAULT_UI 里那句 —— 所以文件删了也能跑。
func _ut(path: String, dflt: String = "") -> String:
	return ScenarioData.ui_t(path, dflt if dflt != "" else ScenarioData.ui_t_d(path))

# 结局文案 —— 每套背景一份（在 backgrounds[].endings 里）
# ★ 第八十一轮：没写就是空串（界面上不显示），不再有调用点兜底句。
func _et(key: String) -> String:
	return DossierData.end_t(key)

# 带占位符的结局文案：**空串直接返回空串** —— 不拿一堆参数去格式化 ""。
# （直接 `"" % [..]` 在 GDScript 里虽然不报错，但「没写就不显示」这条规则
#   不该依赖格式化函数的宽容度。）
func _etf(key: String, args: Array) -> String:
	var t := _et(key)
	if t == "":
		return ""
	return t % args

# ---- 开场介绍浮窗 + 玩法说明浮层 ----
var intro_layer: Control
var intro_body: Label
var intro_reopen_btn: Button       # 准备室里的「本局背景」按钮
var help_overlay: HelpOverlay      # 教练式标注（两个阶段共用）
var _intro_shown_this_run: bool = false

# ---- 启动声明（第八十七轮）----
#   用户口径：「进入游戏界面前显示这段文字 3 秒：本作品无色情内容，无不良引导，完全免费。」
#   ★ 实现方式是**盖在标题界面之上的一层**，不是「先不显示标题」：
#     标题照常在 `_ready()` 里就绪（测试与截图脚本在启动后一帧就会读
#     `title_screen.visible`），这层只负责挡住视线与鼠标，3 秒后自己收起。
#   ★ 文案在 `ui.common.splash_text`，编辑器「界面文案 → ① 通用」里可改。
var splash_layer: Control
var splash_label: Label
const SPLASH_SECONDS := 3.0

func _ready() -> void:
	# 顺序有讲究：开始界面先建（在下面），选关面板压在它上面，
	# 结果覆盖层最后建（盖在最上面）
	_build_title()
	_build_level_select()
	_build_overlay()
	_build_intro()
	help_overlay = HelpOverlay.new()
	add_child(help_overlay)
	# ★ 第八十七轮：启动声明 —— 放在最后建，保证盖在所有层之上
	_build_splash()

	wardrobe.wardrobe_confirmed.connect(_on_wardrobe_confirmed)
	interrogation.interrogation_finished.connect(_on_interrogation_finished)
	# ★ 第八十三轮：两个阶段都能「返回主界面」
	wardrobe.title_requested.connect(_return_to_title)
	interrogation.title_requested.connect(_return_to_title)
	# 玩家每改一次打扮就写一次档 —— 不用去拦退出事件
	wardrobe.model.changed.connect(_on_outfit_changed)
	# 两个阶段的「帮助」按钮
	if wardrobe.help_btn != null:
		wardrobe.help_btn.pressed.connect(_show_stage_help)
	if interrogation.help_btn != null:
		interrogation.help_btn.pressed.connect(_show_stage_help)
	# 手机拿在手里时的帮助入口（手机浮层自己那一个）
	if wardrobe.intel != null and wardrobe.intel.phone_help_btn != null:
		wardrobe.intel.phone_help_btn.pressed.connect(_show_stage_help)

	_show_title()
	_show_splash()

# ============================================================
#  启动声明（第八十七轮）
#
#  用户口径：「进入游戏界面前显示这段文字 3 秒 本作品无色情内容，无不良引导，完全免费。」
#
#  ★ 为什么是「盖一层」而不是「延后建标题」：标题必须在第一帧就就绪 ——
#    测试与截图脚本启动后一帧就会读 `title_screen.visible`、读按钮文案。
#    所以这层只做两件事：挡住视线、吃掉鼠标；3 秒后自己 hide。
#  ★ 文案为空（编辑器里清空）→ 这一层仍然挡住 3 秒，但屏幕上一片纯色。
#    界面文案的规矩是「留空 = 不显示」，这里不例外 —— 只是声明类文案清空没有意义。
# ============================================================
func _build_splash() -> void:
	splash_layer = Control.new()
	splash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 挡住鼠标：这 3 秒里点不到标题界面上的任何按钮
	splash_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.050, 0.062)
	splash_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_layer.add_child(center)

	var lab := Label.new()
	splash_label = lab
	lab.text = _ut("common.splash_text", "本作品无色情内容，无不良引导，完全免费。")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(620, 0)
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95))
	center.add_child(lab)

	splash_layer.hide()

func _show_splash() -> void:
	if splash_layer == null:
		return
	splash_layer.show()
	# ★ 计时器用 `create_timer`：不受 `set_process(false)` 影响（这一点测试里踩过），
	#   到点无条件收起 —— 哪怕这中间已经有人用 `_skip_splash()` 提前关掉了。
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	_hide_splash()

func _hide_splash() -> void:
	if splash_layer != null:
		splash_layer.hide()

# 测试 / 截图脚本用：不真等那 3 秒
func _skip_splash() -> void:
	_hide_splash()

# ============================================================
#  开始界面
# ============================================================
func _show_title() -> void:
	_hide_overlay()
	_hide_intro()
	_hide_level_select()
	_hide_credits()
	if help_overlay != null and help_overlay.is_open():
		help_overlay.close()
	wardrobe.hide()
	interrogation.hide()
	title_screen.show()
	_refresh_title()

# ★★★ 第八十三轮（用户口径）：「加一个返回主界面的功能」。
#   准备室 / 盘问都发 `title_requested`，统一走这里：
#     ① 先把这一局的进度存下来（不然「继续游戏」会退回到上一次存档点）；
#     ② 收掉可能挂着的浮层（结果面板 / 开场说明 / 帮助）；
#     ③ 回标题界面并刷新「继续游戏」按钮。
#   ★ 中途退出**不算失败**：不写 ProfileData 的失败计数，也不清 RunSave。
func _return_to_title() -> void:
	if wardrobe.visible:
		RunSave.save_progress(wardrobe.model.equipped)
	_show_title()

func _hide_title() -> void:
	if title_screen != null:
		title_screen.hide()

func _refresh_title() -> void:
	if title_continue_btn == null:
		return
	title_continue_btn.disabled = not RunSave.has_run
	if title_info != null:
		title_info.text = RunSave.summary() + "\n" + ProfileData.summary()

func _on_title_start() -> void:
	# ★ 第二十一轮：不再直接开局 —— 先让玩家挑进哪一关。
	_show_level_select()

func _on_title_continue() -> void:
	_continue_run()

func _on_title_quit() -> void:
	get_tree().quit()

# ============================================================
#  选关面板
#
#  用户口径：「四关不再是点击开始后随机，而是点击开始游戏后出现进入四关的选项」。
#  ★ 第五十九轮（用户口径）：「现在不再对第一关以外上锁」——
#    两轮都点得动，面板上不再有灰掉的入口。
#
#  · 每一行都在、名字都在、每一行都能点；
#  · 哪几轮开放由 OutfitData.OPEN_LEVELS 说了算，这里一行代码都不用改；
#  · 点某一轮 → 按那一轮开局（RunData.start_new_run(seed, li)）。
# ============================================================
func _build_level_select() -> void:
	level_select = Control.new()
	level_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_select.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(level_select)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.050, 0.062)
	level_select.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_select.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.085, 0.092, 0.112)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.24, 0.26, 0.32)
	panel.add_theme_stylebox_override("panel", ps)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	m.add_child(vb)

	var t := Label.new()
	t.text = _ut("title.select_title", "选择进入哪一关")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68))
	vb.add_child(t)

	var sub := Label.new()
	sub.text = _ut("title.select_sub",
		"一次一局，从选中的那一轮往后走。每一轮都可以直接进入。")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.56, 0.60, 0.68))
	vb.add_child(sub)

	vb.add_child(HSeparator.new())

	# ★★ 第五十三轮：本局背景 —— 可以在选关面板里自己挑一套。
	#   用户口径：「编辑器可以新增背景，不止现有的四个，点击开始游戏的界面同步更新」。
	#   ★ 按钮组是**动态生成**的（从 ScenarioData.enabled_backgrounds() 读），
	#     所以编辑器里新增一套背景、勾上「启用」，这里就自动多一个按钮，不用改代码。
	#   ★ 草稿背景不列出来（它们不参与抽取，列了点了也没用）。
	#   ★★ 第七十三轮（用户口径）：「玩家可以自行选择游玩哪个背景，现在却只能用随机，
	#     修复这个问题然后删掉随机的选项」—— 原来第一颗是「随机」（空 id = 每局随机抽），
	#     而且默认就选中它，所以不点的人永远是随机。现在：
	#       ① 面板上**没有「随机」**，每一颗都是具体的一套背景；
	#       ② 默认选中「上一局用的那套」（`_pending_bg_id`，见 _start_new_run），
	#          第一局则选第一套 —— 任何时刻都有一套是亮着的，不存在「没选」的状态。
	var bg_lab := Label.new()
	bg_lab.text = _ut("title.select_bg_title", "本局背景（点一套选中）")
	bg_lab.add_theme_font_size_override("font_size", 13)
	bg_lab.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	vb.add_child(bg_lab)

	var bg_flow := HFlowContainer.new()
	bg_flow.add_theme_constant_override("h_separation", 8)
	bg_flow.add_theme_constant_override("v_separation", 8)
	vb.add_child(bg_flow)

	level_select_bg_btns = []
	var bg_choices: Array = []
	for b in ScenarioData.enabled_backgrounds():
		bg_choices.append({"id": str((b as Dictionary).get("id", "")),
			"name": str((b as Dictionary).get("name", ""))})
	# 默认选中：`_pending_bg_id` 还在列表里就用它，否则退回第一套。
	#   ★ 用「列表里有没有」来判断，不能只判空 —— 编辑器里把某套背景停用之后，
	#     `_pending_bg_id` 可能是一个已经不存在的 id（甚至上次运行留下的）。
	var still_there := false
	for ch in bg_choices:
		if str((ch as Dictionary).get("id", "")) == _pending_bg_id:
			still_there = true
			break
	if not still_there:
		_pending_bg_id = str((bg_choices[0] as Dictionary).get("id", "")) if not bg_choices.is_empty() else ""
	for ch in bg_choices:
		var bid := str((ch as Dictionary).get("id", ""))
		var bbtn := Button.new()
		bbtn.text = str((ch as Dictionary).get("name", ""))
		bbtn.focus_mode = Control.FOCUS_NONE
		bbtn.custom_minimum_size = Vector2(0, 34)
		bbtn.add_theme_font_size_override("font_size", 13)
		bbtn.pressed.connect(_on_bg_choice.bind(bid))
		bg_flow.add_child(bbtn)
		level_select_bg_btns.append({"btn": bbtn, "id": bid})
	_sync_bg_choice_style()

	vb.add_child(HSeparator.new())

	# 轮次入口 —— ★★ 第八十四轮：改成「跟着选中的背景重建」。
	#   以前这里只在启动时建一次、名字取 `OutfitData.level_at(li)`（那是**上一局生效的那份**），
	#   所以在面板里换背景时，轮次名一直是旧的（用户报「切换背景，每轮的名字不会随之变化」）。
	#   现在把行放进一个独立容器，换背景就 `_rebuild_level_rows()` 重来一遍，
	#   名字取「这套背景自己的 levels[i].name」（见 `_levels_for_panel`）。
	level_rows_box = VBoxContainer.new()
	level_rows_box.add_theme_constant_override("separation", 12)
	vb.add_child(level_rows_box)
	_rebuild_level_rows()

	vb.add_child(HSeparator.new())

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(back_row)
	level_select_back_btn = _title_button(_ut("title.select_back", "◀  返回"), Color(0.30, 0.30, 0.36))
	level_select_back_btn.custom_minimum_size = Vector2(220, 44)
	level_select_back_btn.pressed.connect(_on_level_select_back)
	back_row.add_child(level_select_back_btn)

	level_select.hide()

# 点了某套背景（第七十三轮起没有「随机」那一颗了）
func _on_bg_choice(bid: String) -> void:
	_pending_bg_id = bid
	_sync_bg_choice_style()
	# ★★ 第八十四轮（用户口径）：「切换背景，每轮的名字不会随之变化」——
	#   以前只改了按钮的选中态，轮次那几行是启动时一次性建好的，名字一直停在上一套。
	#   现在换背景就把轮次行整个重建一遍。
	_rebuild_level_rows()

# 「如果这一局用的是 bg_id 这套背景，第 1..N 轮各叫什么」——**只读，不改运行时状态**。
#
#   不能直接用 `OutfitData.level_at()`：那是「当前这一局生效的那份」，
#   在选关面板里还没开局，读到的是上一套背景留下的东西（这就是名字不变的根因）。
#   也不能调 `RunData.levels()`：它同样取 `background()`（当前局的背景）。
#   所以这里照 `_ensure_levels()` + `RunData.levels()` 的叠加口径**重算一份**：
#     基线 = 全局轮次表（`story.levels`，为空才用出厂 DEFAULT_LEVELS）
#     轮数 = 这套背景自己的 levels 条数（没写才跟全局一样多）
#     名字 = 这套背景写了的优先，否则用基线那份。
#
# ★★ 第八十六轮（用户口径）：「选关界面在正常关卡名后多出现了一个不起眼的路人 /
#   有点来头的商贩」。以前这里连 `derived_profile` 一起拼进按钮文字，而绝大多数背景
#   **根本没写这一项** —— 拼上去的是全局表的兜底值（`OutfitData.DEFAULT_LEVELS[0]`），
#   于是每个关卡名后面都多出一句和这套背景毫无关系的话。
#   ★ 结论：选关面板的按钮**只显示轮次名**。`derived_profile` 是玩法内的东西
#     （`RunData.levels()` 照旧叠它），不属于「挑哪一轮」这件事。
func _levels_for_panel(bg_id: String) -> Array:
	var base: Array = OutfitData.global_levels()
	var own: Array = ScenarioData.bg_levels(bg_id)
	var n: int = own.size() if not own.is_empty() else base.size()
	if n <= 0:
		n = maxi(1, OutfitData.DEFAULT_LEVELS.size())
	var out := []
	for i in n:
		var name := ""
		if i < base.size() and typeof(base[i]) == TYPE_DICTIONARY:
			name = str((base[i] as Dictionary).get("name", ""))
		if name == "":
			name = "第 %d 轮" % (i + 1)
		if i < own.size() and typeof(own[i]) == TYPE_DICTIONARY:
			var own_name := str((own[i] as Dictionary).get("name", ""))
			if own_name != "":
				name = own_name
		out.append(name)
	return out

# 按当前选中的背景重建轮次那几行
func _rebuild_level_rows() -> void:
	if level_rows_box == null:
		return
	for c in level_rows_box.get_children():
		level_rows_box.remove_child(c)
		c.queue_free()
	level_select_rows = []

	var lvs := _levels_for_panel(_pending_bg_id)
	for li in lvs.size():
		var unlocked: bool = OutfitData.level_unlocked(li)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		level_rows_box.add_child(row)

		var btn := Button.new()
		var lv_name := str(lvs[li])
		btn.text = lv_name
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.42, 0.34) if unlocked else Color(0.13, 0.14, 0.17)
		sb.set_corner_radius_all(9)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.36, 0.66, 0.52) if unlocked else Color(0.24, 0.26, 0.31)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			btn.add_theme_stylebox_override(st, sb)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0.11, 0.12, 0.15)
		dsb.set_corner_radius_all(9)
		dsb.set_border_width_all(1)
		dsb.border_color = Color(0.22, 0.24, 0.29)
		btn.add_theme_stylebox_override("disabled", dsb)
		for c2 in ["font_color", "font_pressed_color", "font_hover_color",
				"font_hover_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(c2, Color(0.96, 0.98, 1.0))
		btn.add_theme_color_override("font_disabled_color", Color(0.44, 0.47, 0.53))
		btn.disabled = not unlocked
		if unlocked:
			btn.pressed.connect(_on_level_selected.bind(li))
		row.add_child(btn)

		var note := Label.new()
		note.text = _ut("title.select_open_note", "可以进入") if unlocked \
			else _ut("title.select_locked_note", "尚未开放")
		note.custom_minimum_size = Vector2(96, 0)
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color",
			Color(0.52, 0.86, 0.66) if unlocked else Color(0.52, 0.55, 0.61))
		row.add_child(note)

		level_select_rows.append({"btn": btn, "note": note, "li": li})

# 背景按钮的选中态：选中的那颗涂成主色，其余是暗色
func _sync_bg_choice_style() -> void:
	for e in level_select_bg_btns:
		var btn: Button = e["btn"]
		var on: bool = str(e["id"]) == _pending_bg_id
		var col := Color(0.24, 0.52, 0.38) if on else Color(0.18, 0.20, 0.25)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = col.lightened(0.30)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			btn.add_theme_stylebox_override(st, sb)
		btn.add_theme_color_override("font_color",
			Color(0.96, 0.98, 1.0) if on else Color(0.74, 0.78, 0.86))

func _show_level_select() -> void:
	_hide_overlay()
	_hide_intro()
	wardrobe.hide()
	interrogation.hide()
	if title_screen != null:
		title_screen.show()
	level_select.show()

func _hide_level_select() -> void:
	if level_select != null:
		level_select.hide()

func _is_level_select_open() -> bool:
	return level_select != null and level_select.visible

func _on_level_select_back() -> void:
	_hide_level_select()
	_show_title()

# 点了某一轮 → 按那一轮开局（背景用面板上选的那套；面板保证总有一套选中）
func _on_level_selected(li: int) -> void:
	if not OutfitData.level_unlocked(li):
		return
	_hide_level_select()
	_start_new_run(-1, li, _pending_bg_id)

# ---------------- 流程 ----------------
# seed_in >= 0 时用固定种子开新局（截图与测试需要可复现的随机结果）
# start_level：从第几轮开始（选关面板传进来；0 = 第一轮）
# bg_id：本局指定的背景（选关面板传进来；**空 = 随机抽**）
#   ★ 第五十三轮加的 bg_id。★ 第七十三轮：面板不再传空 —— 但**空串仍是「随机」**，
#     因为测试与截图脚本大量直接调 `_start_new_run(seed)`，它们需要覆盖四套背景。
#     玩家侧「随机」的入口（面板上那颗按钮）已经删了，见 _build_level_select()。
func _start_new_run(seed_in: int = -1, start_level: int = 0, bg_id: String = "") -> void:
	RunData.start_new_run(seed_in, start_level, bg_id)
	# ★ 第七十三轮：记住这一局真正用的背景 —— 面板下次打开默认选它，
	#   「再来一局」也沿用它（不再像以前那样换一套）。
	_pending_bg_id = RunData.background_id
	_hide_title()
	_hide_level_select()
	_hide_overlay()
	interrogation.hide()
	wardrobe.start_run()
	# ★ 本轮开始 → 拍快照。失败重来时按它回滚（见 _retry_level）。
	GameData.snapshot_level_state()
	RunSave.save_progress(wardrobe.model.equipped)
	_intro_shown_this_run = false
	_ensure_intro_shown()

# 继续上一局：把种子、轮次、那身打扮、手机进度一起接回来
func _continue_run() -> void:
	if not RunSave.has_run:
		return
	RunData.resume_run(RunSave.seed_value, RunSave.run_index,
		RunSave.level_index, RunSave.cleared_levels)
	# ★ 第七十三轮：续玩也把背景记到面板的选择上（这一局用的是哪套，面板就亮哪套）
	_pending_bg_id = RunData.background_id
	_hide_title()
	_hide_level_select()
	_hide_overlay()
	interrogation.hide()
	# start_run() 会把手机与情报重置一遍，所以手机进度必须**之后**再灌回去
	wardrobe.start_run()
	RunSave.apply_to_gamedata()
	wardrobe.apply_outfit(RunSave.equipped)
	wardrobe.intel.rebuild()
	wardrobe._refresh()
	# 续玩也算「本轮开始」—— 直接关窗口回来照样能按本轮重来
	GameData.snapshot_level_state()
	_ensure_intro_shown()

func _start_level() -> void:
	_hide_overlay()
	interrogation.hide()
	wardrobe.start_level()
	# ★ 轮次之间的怀疑度衰减：上一轮结束时的值 × 比例 → 本轮开局值
	GameData.begin_level_suspicion()
	# ★ 新一轮开始 → 重新拍快照（上一轮的快照就此作废）
	GameData.snapshot_level_state()
	RunSave.save_progress(wardrobe.model.equipped)
	# 一关刚通过 —— 再弹一次本轮的开场说明（换了一关，场景也换了）
	_ensure_intro_shown()

# ============================================================
#  本轮失败 → 回到本轮开始（第二十一轮）
#
#  用户口径：「失败后返回本轮开始」
#
#  与 _start_level() 的差别只有一处：**不推进关卡**，而是把本轮里发生的事
#  回滚到进这一轮那一刻（立过的说法、矛盾计数、怀疑度、问答记录）。
#  背景 / A 的原貌 / 情报进度 / 接受度 / 强制装备一概不动 ——
#  他记忆里的那张脸没变，你已经查到的也还在，要改的只是这一轮的打扮。
# ============================================================
func _retry_level() -> void:
	_hide_overlay()
	interrogation.hide()
	RunData.retry_level()          # 数据层回滚（含强制装备的再确认）
	wardrobe.start_level()         # 装备退回 A 的原貌，准备室重新可见
	GameData.begin_level_suspicion()
	RunSave.save_progress(wardrobe.model.equipped)
	_ensure_intro_shown()

func _on_outfit_changed() -> void:
	if wardrobe == null or not wardrobe.visible:
		return
	RunSave.save_progress(wardrobe.model.equipped)

func _on_wardrobe_confirmed() -> void:
	_sync_wardrobe_to_gamedata()
	RunSave.save_progress(wardrobe.model.equipped)
	_hide_intro()
	if help_overlay != null and help_overlay.is_open():
		help_overlay.close()
	# ★ 第八十九轮：原来这里要把这一身打扮交给盘问、重铺表情 QTE 旁边那块小图。
	#   那块图已删，所以这里不再传换装结果 —— 盘问只读 GameData 里的数值。
	wardrobe.hide()
	interrogation.start_interrogation()

func _on_interrogation_finished(success: bool) -> void:
	interrogation.hide()
	_hide_overlay()

	if not success:
		# ★ 第二十一轮：失败不再作废整局 —— 回到**本轮开始**。
		#   记一笔「本轮重来」（跨局存档）。注意：已经赚到的接受度**不退**，
		#   RunSave 也**不清** —— 这一局还在进行中，随时可以接着走。
		ProfileData.note_level_failed()
		_pending_action = "retry_level"
		_show_overlay(_et("overlay_fail_title"),
			_fail_body(), _et("overlay_fail_btn"), Color(0.92, 0.40, 0.40), "↺")
		return

	var passed_level := RunData.level_number()
	var last_level: bool = RunData.level_index >= RunData.level_count() - 1

	if last_level:
		# 先结算（把本局标记为通关），再展示结果 —— 顺序反了 overlay 里读到的进度会少一关
		RunData.advance_level()
		ProfileData.note_run_finished(RunData.cleared_levels, true)
		RunSave.clear()
		# ★★ 第八十六轮（用户口径）：「一局通关后点击按钮返回主界面」。
		#   以前这颗按钮是「再来一局」—— 直接开下一局，想换背景 / 换轮次得自己退出。
		#   现在按下它就回标题界面：RunSave 上一步已经清掉了，
		#   「继续游戏」会自动变灰，玩家从「开始游戏」重新挑背景与轮次。
		_pending_action = "home"
		_show_overlay(_et("overlay_win_title"),
			_win_body(), _et("overlay_win_btn"), Color(0.42, 0.90, 0.62), "➔")
		return

	# 本轮通过 → 推进到下一轮（同一局：背景不变、原貌不变）
	var gain := int(RunData.current_level().get("acceptance_gain", 0))
	RunData.advance_level()
	_pending_action = "next_level"
	_show_overlay(_etf("overlay_level_title", [passed_level]),
		_next_level_body(gain), _etf("overlay_level_btn", [RunData.level_number()]),
		Color(0.42, 0.90, 0.62), "➔")

func _on_overlay_pressed() -> void:
	if _pending_action == "next_level":
		_start_level()
	elif _pending_action == "retry_level":
		_retry_level()
	elif _pending_action == "home":
		# ★ 第八十六轮：通关后的按钮回标题界面（不直接开新局）
		_pending_action = ""
		_show_title()
	else:
		# ★ 第七十三轮：「再来一局」沿用**这一局用的那套背景**（以前是换一套新的）。
		#   玩家在选关面板里挑过背景之后，不该每打完一局就被换掉。
		# ★ 第八十六轮：通关流程不再走这里（改回标题界面），这条留着给
		#   测试 / 截图脚本显式把 `_pending_action` 设成 "new_run" 时用。
		_start_new_run(-1, 0, _pending_bg_id)

# ---------------- 覆盖层文案 ----------------
func _level_line() -> String:
	return "[color=#c8ccd4]第 [b]%d[/b] / %d 轮[/color] ｜ [color=#8fb8f0]接受度 [b]%d[/b][/color] ｜ [color=#c8ccd4]暴露值上限 [b]%d[/b][/color]" % [
		RunData.level_number(), RunData.level_count(),
		RunData.acceptance, RunData.exposure_cap_at(RunData.level_index)]

func _next_level_body(gain: int) -> String:
	var lv := RunData.current_level()
	# ★ 第八十一轮：文案只从数据来（没写 → 空串），所以兜底句删掉了。
	return _etf("overlay_next_body", [
		RunData.background_name(), RunData.cover_role(), str(lv.get("name", "")),
		gain, RunData.acceptance, RunData.exposure_cap_at(RunData.level_index),
		int(lv.get("contrast_req", 0))])

func _fail_body() -> String:
	return _etf("overlay_fail_body", [
		RunData.run_index, RunData.background_name(),
		RunData.cleared_levels, RunData.level_count()])

func _win_body() -> String:
	# ★ 第四十二轮：「4 / 4 关」是写死的，而第四十一轮起轮数可以按背景配置 ——
	#   所以文案改成动态的 %d / %d，参数用「已通过轮数 / 本局总轮数」。
	#   （文案本身在 story.json 的 endings.overlay_win_body 里，编辑器可改。）
	return _etf("overlay_win_body", [
		RunData.run_index, RunData.background_name(),
		RunData.true_role(), RunData.cover_role(),
		RunData.cleared_levels, RunData.level_count(), GameData.contradictions])

# ---------------- 开始界面 UI ----------------
func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(title_screen)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.050, 0.062)
	title_screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.085, 0.092, 0.112)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.24, 0.26, 0.32)
	panel.add_theme_stylebox_override("panel", ps)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)

	var t := Label.new()
	t.text = _ut("title.title", "千面人 · 换装与盘问")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68))
	vb.add_child(t)

	var sub := Label.new()
	sub.text = _ut("title.subtitle", "把 A 藏进 B 的皮里。改的是打扮，赌的是命。")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.56, 0.60, 0.68))
	# ★★ 第七十四轮（用户口径）：「界面上会留下空白的地方全部去掉……不再需要填入文字」——
	#   副标被清空时**整行收起来**（VBoxContainer 会跳过隐藏子节点），
	#   不留一条空行。同理见 Interrogation 的反馈区（空串 = 什么都不写）。
	sub.visible = sub.text.strip_edges() != ""
	vb.add_child(sub)

	vb.add_child(HSeparator.new())

	title_info = Label.new()
	title_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_info.add_theme_font_size_override("font_size", 12)
	title_info.add_theme_color_override("font_color", Color(0.68, 0.72, 0.80))
	title_info.custom_minimum_size = Vector2(0, 56)
	vb.add_child(title_info)

	title_start_btn = _title_button(_ut("title.start_btn", "▶  开始游戏"), Color(0.24, 0.52, 0.38))
	title_start_btn.pressed.connect(_on_title_start)
	vb.add_child(title_start_btn)

	title_continue_btn = _title_button(_ut("title.continue_btn", "⏩  继续游戏"), Color(0.18, 0.38, 0.60))
	title_continue_btn.pressed.connect(_on_title_continue)
	vb.add_child(title_continue_btn)

	# ★ 第六十四轮：制作人名单（从开始界面点进去，盖在标题面板上）
	title_credits_btn = _title_button(_ut("title.credits_btn", "制作人名单"), Color(0.24, 0.27, 0.34))
	title_credits_btn.pressed.connect(_show_credits)
	vb.add_child(title_credits_btn)

	title_quit_btn = _title_button(_ut("title.quit_btn", "✖  退出游戏"), Color(0.34, 0.24, 0.26))
	title_quit_btn.pressed.connect(_on_title_quit)
	vb.add_child(title_quit_btn)

	_build_credits()
	title_screen.hide()

# 制作人名单：一层压暗 + 一块居中的面板，正文一行一条。
func _build_credits() -> void:
	credits_layer = Control.new()
	credits_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	credits_layer.hide()
	title_screen.add_child(credits_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.035, 0.045, 0.90)
	credits_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.075, 0.082, 0.100)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.28, 0.30, 0.36)
	panel.add_theme_stylebox_override("panel", ps)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 28)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)

	var t := Label.new()
	t.text = _ut("title.credits_title", "制作人名单")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68))
	vb.add_child(t)

	vb.add_child(HSeparator.new())

	credits_body_label = Label.new()
	credits_body_label.text = _ut("title.credits_body", DEFAULT_CREDITS)
	credits_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credits_body_label.add_theme_font_size_override("font_size", 15)
	credits_body_label.add_theme_color_override("font_color", Color(0.84, 0.87, 0.92))
	credits_body_label.add_theme_constant_override("line_spacing", 8)
	credits_body_label.custom_minimum_size = Vector2(620, 0)
	vb.add_child(credits_body_label)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(back_row)
	credits_back_btn = _title_button(_ut("title.credits_back", "←  返回"), Color(0.30, 0.30, 0.36))
	credits_back_btn.custom_minimum_size = Vector2(220, 44)
	credits_back_btn.pressed.connect(_hide_credits)
	back_row.add_child(credits_back_btn)

func _show_credits() -> void:
	if credits_layer == null:
		return
	credits_layer.show()

func _hide_credits() -> void:
	if credits_layer != null:
		credits_layer.hide()

func _title_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = col.lightened(0.35)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sb)
	# 禁用态（没有存档时的「继续游戏」）要一眼看出点不动
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.14, 0.15, 0.18)
	dsb.set_corner_radius_all(9)
	dsb.set_border_width_all(1)
	dsb.border_color = Color(0.24, 0.26, 0.31)
	b.add_theme_stylebox_override("disabled", dsb)
	for c in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.96, 0.98, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.54))
	return b

# ---------------- 覆盖层 UI ----------------
func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.035, 0.045, 0.88)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 26)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)

	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 24)
	vb.add_child(overlay_title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	# 注意：RichTextLabel 没有 `font_size` 这个 theme item，必须用 `normal_font_size`
	overlay_body = RichTextLabel.new()
	overlay_body.bbcode_enabled = true
	overlay_body.fit_content = true
	overlay_body.scroll_active = false
	overlay_body.add_theme_font_size_override("normal_font_size", 14)
	overlay_body.custom_minimum_size = Vector2(0, 196)
	vb.add_child(overlay_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(row)

	overlay_btn = Button.new()
	overlay_btn.custom_minimum_size = Vector2(320, 48)
	overlay_btn.focus_mode = Control.FOCUS_NONE
	overlay_btn.add_theme_font_size_override("font_size", 15)
	overlay_btn.pressed.connect(_on_overlay_pressed)
	row.add_child(overlay_btn)

	overlay.hide()

# ★ 第八十一轮：结局文案「不写就不使用」——
#   · 标题 / 正文没写 → 那一块**整块收起来**（不留空白行、不留空面板）；
#   · 按钮标签没写 → 只留一个箭头（`→` 类动作用 ➔，重来类动作传 ↺）——
#     按钮是唯一的前进手段，绝不能变成一块点不动的空白。
func _show_overlay(title: String, body: String, button: String, color: Color,
		btn_arrow: String = "➔") -> void:
	overlay_title.text = title
	overlay_title.add_theme_color_override("font_color", color)
	overlay_title.visible = not title.strip_edges().is_empty()
	overlay_body.text = body
	overlay_body.visible = not body.strip_edges().is_empty()
	overlay_btn.text = button if not button.strip_edges().is_empty() else btn_arrow
	overlay.show()

func _hide_overlay() -> void:
	if overlay != null:
		overlay.hide()

# ---------------- 状态同步 ----------------
# 把换装结果写入全局状态，供盘问环节判定使用
func _sync_wardrobe_to_gamedata() -> void:
	var m: WardrobeModel = wardrobe.model

	# 先清掉上一轮残留的判定结果（怀疑度也在这一步复位）
	GameData.reset_level_state()

	GameData.acceptance = m.acceptance
	GameData.level_index = m.level_index
	GameData.outfit_exposure = m.total_exposure()
	GameData.outfit_exposure_cap = m.exposure_cap()
	GameData.contrast_total = m.total_contrast()
	GameData.contrast_required = m.contrast_requirement()
	GameData.contrast_sufficient = m.is_contrast_sufficient()
	GameData.matching_slots_count = m.matching_slots().size()
	GameData.uncovered_defects = m.exposed_defects()
	GameData.defects_covered = GameData.uncovered_defects.is_empty()

	# ★ 换装判定：阶段一不下结论，但结果得带过去 —— 门一开就要用。
	#   放在 reset_level_state() 之后（那一步会把 outfit_passed 复位成 true）。
	wardrobe.sync_outfit_verdict()

	# 手机浮层的操作本身已实时写入 GameData（dossier_* / revealed_slots），这里再兜一次
	wardrobe.intel.sync_to_gamedata()

	# 反差值越高，越能转移审讯官注意力（上限 0.9）
	# 分母 90 对应槽位扩到 18 个之后的反差值量级
	GameData.visual_distraction_power = clampf(m.total_contrast() / 90.0, 0.0, 0.9)
	GameData.is_defect_covered = GameData.defects_covered

# ============================================================
#  开场介绍浮窗（每局 / 每轮开场弹一次，可随时重新打开）
#
#  用户口径：「开场会弹出一个浮动窗口介绍本局背景（可用编辑器更改）
#            关闭后可点击按钮再次打开」
# ============================================================
func _build_intro() -> void:
	intro_layer = Control.new()
	intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.055, 0.90)
	intro_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.075, 0.085, 0.105)
	ps.set_corner_radius_all(14)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.32, 0.52, 0.74)
	panel.add_theme_stylebox_override("panel", ps)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 28)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	m.add_child(vb)

	var t := Label.new()
	t.name = "IntroTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 25)
	t.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))
	vb.add_child(t)

	vb.add_child(HSeparator.new())

	intro_body = Label.new()
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.add_theme_font_size_override("font_size", 14)
	intro_body.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	intro_body.custom_minimum_size = Vector2(0, 300)
	vb.add_child(intro_body)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	vb.add_child(btns)

	var ok := _intro_button(_ut("common.intro_ok_btn", "知道了  ➔"), Color(0.22, 0.50, 0.38))
	ok.pressed.connect(_close_intro)
	btns.add_child(ok)

	intro_layer.hide()

func _intro_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = col.lightened(0.35)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.96, 0.98, 1.0))
	return b

# 只在准备室可见时弹 —— 否则会把开始界面 / 结果覆盖层盖住
func _ensure_intro_shown() -> void:
	if wardrobe == null or not wardrobe.visible:
		return
	_show_intro()

func _show_intro() -> void:
	if intro_layer == null:
		return
	var title := intro_layer.get_node_or_null("IntroTitle")
	if title == null:
		title = intro_layer.find_child("IntroTitle", true, false)
	if title != null:
		(title as Label).text = "%s ｜ 第 %d 轮 · %s" % [
			RunData.background_name(), RunData.level_number(), RunData.level_name()]
	intro_body.text = DossierData.intro_text()
	intro_layer.show()
	_intro_shown_this_run = true

func _close_intro() -> void:
	if intro_layer != null:
		intro_layer.hide()

func _hide_intro() -> void:
	if intro_layer != null:
		intro_layer.hide()

# ============================================================
#  玩法说明（教练式标注）—— 两个阶段共用
#
#  用户口径：「每个阶段要有玩法说明功能 点击后
#            用文字箭头方框等说明每处的作用」
#  阶段一：「说明换装区域，说明接受度是什么 手机有什么用 消息 备忘录四个界面内容是什么」
#  阶段二：说明盘问界面上每一处的作用
#
#  坐标全部用**相对比例**（0~1），所以窗口缩放 / 布局微调都不影响标注的落点。
# ============================================================
func _show_stage_help() -> void:
	if help_overlay == null:
		return
	if interrogation.visible:
		help_overlay.open(_ut("help.interrogation_title", "阶段二 · 高压盘问"),
			_ut("help.interrogation_sub", "按编号看每一处是干什么的"),
			_interrogation_marks())
	elif wardrobe.intel != null and wardrobe.intel.is_phone_open():
		# 手机已经拿在手里 —— 那就讲手机里这四个界面各是干什么的
		help_overlay.open(_ut("help.phone_title", "阶段一 · 手机"),
			_ut("help.phone_sub", "手机里四个界面各是干什么的"),
			_phone_marks())
	else:
		help_overlay.open(_ut("help.wardrobe_title", "阶段一 · 准备室"),
			_ut("help.wardrobe_sub", "按编号看每一处是干什么的"),
			_wardrobe_marks())

# 标注的**文字**现在全在 data/story.json 的 ui.help.*_marks 数组里（编辑器可改）。
# 这里只负责「第几段文字配哪个控件」—— 数量对不上就退回出厂那套。
func _marks_texts(path: String, n: int) -> Array:
	var texts: Array = ScenarioData.ui_arr_d(path)
	if texts.size() != n:
		texts = ScenarioData.ui_arr(path, [])
	return texts

func _wardrobe_marks() -> Array:
	# 手机没打开时的准备室：讲清「卡片墙 / 数值量表 / 换装预览 / 手机」四处。
	# ★ 用户口径（第十七轮）：「判定栏」整个撤掉，这里也少一处标注。
	# 标注框全部用**运行时控件矩形**，正好套在那个控件外面。
	var item_list: Control = wardrobe.item_cols.get_parent()   # 卡片墙的滚动区
	var scale_row: Control = wardrobe.stat_blocks["expose"]["wrap"]
	var ctls := [item_list, scale_row, wardrobe.preview_stage,
		wardrobe.intel.phone_btn]
	var texts := _marks_texts("help.wardrobe_marks", ctls.size())
	var out: Array = []
	for i in ctls.size():
		out.append({"ctrl": ctls[i], "n": i + 1,
			"t": str(texts[i]) if i < texts.size() else ""})
	return out

func _phone_marks() -> Array:
	# 手机已经拿在手里：逐个讲四个界面。标注框套在手机底部的四个 App 按钮上。
	var out: Array = []
	var p: PhoneDesk = wardrobe.intel.phone
	if p == null or p.app_bar == null:
		return _wardrobe_marks()
	var texts := _marks_texts("help.phone_marks", p.app_bar.get_child_count())
	for i in texts.size():
		if i >= p.app_bar.get_child_count():
			break
		out.append({"ctrl": p.app_bar.get_child(i), "n": i + 1, "t": str(texts[i])})
	return out if not out.is_empty() else _wardrobe_marks()

func _interrogation_marks() -> Array:
	# 盘问界面：标注框同样走运行时控件矩形，哪一块在哪就是哪一块。
	# ★ 手机不在这里再讲一遍（用户口径：「第二阶段的玩法说明中不需要再次说明手机」）——
	#   阶段一已经把四个界面逐个讲过，这里只留盘问界面自己的东西。
	var ctls := [interrogation.suspicion_bar, interrogation.dialogue_label,
		interrogation.feedback_label, interrogation.opts_box]
	var texts := _marks_texts("help.interrogation_marks", ctls.size() + 1)
	var out: Array = []
	for i in ctls.size():
		out.append({"ctrl": ctls[i], "n": i + 1,
			"t": str(texts[i]) if i < texts.size() else ""})
	out.append({"r": Rect2(0.02, 0.84, 0.96, 0.14), "n": ctls.size() + 1,
		"t": str(texts[ctls.size()]) if texts.size() > ctls.size() else ""})
	return out
