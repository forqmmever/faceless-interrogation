extends Control

# ============================================================
#  准备室（唯一的准备阶段）—— 换装界面
#
#  换装与情报整理在同一个界面里同时进行：
#    · 左：纸娃娃实时预览 + 原貌对照 + DoL 式量表（两条：暴露 / 反差）
#    · 右：换装槽位（OutfitData.active_slots()，当前 17 个 —— 外袍暂时下架），
#      每槽一组**卡片**（缩略图 + 名称 + 一行七点色阶：暴露值）
#    · 左下角：「手机」按钮 —— 点开浮层（短信 / 相册 / 备忘录 / 备注）
#
#  ★ 表现方式参照 Degrees of Lewdity 的换装系统（见 DolStyle.gd 的说明）：
#    · 衣物是**卡片**：1px 实线边框、悬停换底色。
#    · 数值是**7 颗小圆点**：点亮几颗＝量级，颜色＝档位。
#      行前一个字母 E.（暴露值），对应 DoL 的 I. / R. / W. 那套读数。
#      ★ 第三十一轮（用户口径）：C. 反差值那一行撤掉了 —— 反差值现在由整套搭配算，
#        不是单件衣服的固有属性，印在卡上会误导（详见文档里「反差值」一节）。
#    · 连续量另有一条**渐变刻度条 + 指针**，并多画一条**阈值刻线**：
#      暴露值 → 上限；反差值 → 本轮要求。跨没跨过去，看刻线左右就知道。
#
#  ★ 这一阶段**不替玩家下结论**。
#    这里只把数字摊开：反差值多少、要求多少、缺陷遮没遮、强制装备穿没穿。
#    至于这身打扮能不能骗过他 —— 门开的那一刻才知道
#    （判定在 Interrogation.start_interrogation 里做）。
# ============================================================

signal wardrobe_confirmed

# 小人素材来自 assets/dol_au/（由 tools/dol_prepare.py 从 AUfemale 图包烘焙而来，
# 见 DolDoll.ROOT），取图与分层都交给 DolDoll.gd。

const ICON_SIZE := 60                  # 卡片里的缩略图边长（= DoL 的 30×30 图标放 2 倍）
const CARD_H := 68                     # 卡片高度（缩略图 60 + 上下留白；文字区一行点阵 + 名称）
# 预览区的**上限盒子** —— 实际尺寸由 DolDoll.fit_size() 把 AU 取景框 68×203
# 等比塞进来算出（得 92×276），这里只是上限，不写死具体数字。
const STAGE_BOX := Vector2(123, 276)
const CARD_COLS := 3                   # 每个槽位下面几列卡片
const SLOT_BAR_W := 3

# 量表的**绝对量程** —— 故意不跟着阈值走。
#   ★ 这里有个坑：如果量程取成「阈值 × 1.35」，那阈值刻线的位置就恒等于
#     1/1.35 ≈ 74%，三条量表的刻线全落在同一个地方 —— 那条刻线等于没画。
#     所以量程按**这个数值本身的可能范围**定，刻线才会随轮次移动
#     （第 1 关的暴露上限在 40%，到第 4 关挪到 98%，一眼看得出预算在放宽）。
#   暴露 71 = 第 4 轮上限 70 再留 1；反差 270 = 「每槽位都取最暴露那件」的理论上限
#     （可凑出的暴露值总和上限 54 × 系数 5）—— 实测 150 种子 × 4 轮的真实求解器上限是
#     235，留出余量免得刻线顶到条尾。
#   ★ 第四十九轮重标过：起始接受度 10 → 14（上限 30/40/50/64 → 38/48/58/70），
#     反差口径改成全槽位求和（旧值 55 / 100 都装不下了）。
const SCALE_MAX := {"expose": 71.0, "contrast": 270.0}

var model: WardrobeModel
var intel: IntelDesk

var layer_rects: Dictionary = {}      # slot -> TextureRect
var slot_buttons: Dictionary = {}     # slot -> Array[Button]（卡片本身，语义与旧版一致）
var slot_labels: Dictionary = {}      # slot -> Label（分区标题）
var slot_notes: Dictionary = {}       # slot -> Label（标题右侧「当前：xxx」）
var card_refs: Dictionary = {}        # slot -> Array[Dictionary]（卡片里的点阵/标签引用）
var stat_blocks: Dictionary = {}      # key -> Dictionary（量表：pips / scale / 数值）
var stats_label: RichTextLabel        # 强制装备 / 缺陷 / 接受度（文字清单）
var continue_btn: Button
var auto_btn: Button
var peek_btn: Button
var peek_hint: Label
var run_label: Label
var help_btn: Button
var intro_btn: Button
var item_cols: VBoxContainer          # 槽位分区的容器（玩法说明要圈它）
var preview_stage: Control            # 纸娃娃预览的舞台（玩法说明要圈它）

var _peeking: bool = false            # 预览是否切换为「A 的原貌」
var _peek_sync: bool = false          # 防止 button_pressed 回写时递归
var _auto_msg: String = ""            # 「一键达标」测试按钮上一次的结果说明

func _ready() -> void:
	model = WardrobeModel.new(OutfitData, RunData.true_appearance(), RunData.levels())
	model.changed.connect(_refresh)
	_build_ui()
	intel.changed.connect(_refresh)
	_refresh()

# ---------------- 多轮制：开一局 / 进一关 ----------------
# 开新的一局：背景与原貌都换了，手机里的进度必须整个清空重来
func start_run() -> void:
	intel.reset()
	start_level()

# 进入本局当前这一轮：装备退回 A 的原貌，接受度与轮次同步过来
# 情报进度（已还原的外貌 / 已归类的身份）**跨关保留** —— 同一局里他还是那个人
func start_level() -> void:
	model.reset_for_level(RunData.acceptance, RunData.level_index, RunData.true_appearance(),
		RunData.forced_item_ids(), RunData.forced_groups_info())
	_peeking = false
	_auto_msg = ""
	if peek_btn != null:
		_peek_sync = true
		peek_btn.button_pressed = false
		_peek_sync = false
	# 手机要跟着刷新：这一轮的短信是新解锁的，手机里的列表得重算。
	intel.rebuild()
	_refresh()
	show()

# 把一组「slot -> item id」套回模型 —— 续玩时用来还原玩家上次的打扮。
# 只认合法、属于该槽位、且当前接受度穿得起的那些；其余一律跳过。
# ★ 第三十六轮：多件槽位（纹身）的值是 Array，逐件校验后一起还原。
func apply_outfit(outfit: Dictionary) -> void:
	if outfit.is_empty():
		return
	for slot in outfit.keys():
		var s := str(slot)
		# ★ 第二十七轮：下架的槽位不还原 —— 旧存档里可能还留着外袍 / 手套 / 头饰，
		#   还原回来就会让 equipped 多出几个「界面看不见、数值却算进去」的槽位。
		if not OutfitData.slot_enabled(s):
			continue
		var raw: Variant = outfit[slot]
		var ids := []
		for x in (raw as Array if typeof(raw) == TYPE_ARRAY else [raw]):
			var id := str(x)
			if id == "":
				continue
			var it := OutfitData.get_item(id)
			if it.is_empty() or str(it.get("slot", "")) != s:
				continue
			if not model.can_equip(it):
				continue
			ids.append(id)
		if ids.is_empty():
			continue
		model.set_ids(s, ids)
	# ★ 第二十七轮：还原完之后过一遍互斥归一化 —— 存档里的搭配本来就该是自洽的
	#   （装备时就会自动清空同组其它槽位），这里只是兜底：
	#   万一存档来自旧版本、或者被手工改过，也不会出现「成装 + 长裤」这种半截搭配。
	model._normalize_exclusive()
	model.changed.emit()
	_refresh()

func _slot_revealed(slot: String) -> bool:
	return GameData.revealed_slots.has(slot)

# ---------------- UI 构建 ----------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.075, 0.082, 0.098)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 9)
	margin.add_child(root_box)

	# ---- 标题 ----
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	root_box.add_child(title_row)

	var title := Label.new()
	title.text = ScenarioData.ui_t_d("wardrobe.title")
	title.add_theme_font_size_override("font_size", 21)
	title_row.add_child(title)

	run_label = Label.new()
	run_label.add_theme_font_size_override("font_size", 13)
	run_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.40))
	run_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(run_label)

	# 「本局背景」—— 开场那个浮动窗口关掉之后，靠它再打开
	intro_btn = Button.new()
	intro_btn.text = ScenarioData.ui_t_d("wardrobe.intro_btn")
	intro_btn.focus_mode = Control.FOCUS_NONE
	intro_btn.custom_minimum_size = Vector2(104, 32)
	intro_btn.add_theme_font_size_override("font_size", 13)
	intro_btn.tooltip_text = ScenarioData.ui_t_d("wardrobe.intro_tip")
	title_row.add_child(intro_btn)

	# 「玩法说明」—— 教练式标注，把每一处是干什么的画出来
	help_btn = Button.new()
	help_btn.text = ScenarioData.ui_t_d("wardrobe.help_btn")
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.custom_minimum_size = Vector2(104, 32)
	help_btn.add_theme_font_size_override("font_size", 13)
	help_btn.tooltip_text = ScenarioData.ui_t_d("common.help_tip")
	title_row.add_child(help_btn)

	# ---- 主体：左预览 + 右卡片墙 ----
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 10)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(main_row)

	_build_preview(main_row)
	_build_item_list(main_row)

	# ---- 底部 ----
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root_box.add_child(bottom)

	# ★ 用户口径（第十七轮）：「判定栏的文字及对应说明」整个撤掉。
	#   那一栏原本是把「还差多少反差 / 哪处缺陷露着 / 超没超上限 / 强制装备穿齐没有」
	#   摊在底部。现在这些要么已经写在左侧文字清单里，要么进门那一刻才见分晓 ——
	#   底部只留一排按钮，用一条伸缩空隙把按钮顶到右下角（手机按钮在最左）。
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_spacer)

	# ---- 测试按钮：一键满足本轮全部服装要求 ----
	auto_btn = Button.new()
	auto_btn.text = "一键达标"
	auto_btn.custom_minimum_size = Vector2(96, 44)
	auto_btn.add_theme_font_size_override("font_size", 12)
	auto_btn.tooltip_text = ("测试用捷径（不是玩法的一部分）：自动穿好本轮强制装备、"
		+ "遮住全部身体缺陷、把反差值拉到本轮要求以上，并保证暴露值不超上限。\n"
		+ "求解是精确的 —— 约束下能达到的最大反差。")
	auto_btn.pressed.connect(_on_auto_complete)
	bottom.add_child(auto_btn)

	continue_btn = Button.new()
	continue_btn.text = "进入盘问环节  >"
	continue_btn.custom_minimum_size = Vector2(176, 44)
	continue_btn.pressed.connect(_on_continue)
	bottom.add_child(continue_btn)

	# 手机浮层最后建 —— 它要盖在所有东西之上；
	# 按钮则插进底部那一行的**最左**（也就是屏幕左下角）。
	_build_phone_overlay(bottom)

# ---------------- 左侧：纸娃娃预览 + DoL 量表 ----------------
func _build_preview(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(238, 0)
	panel.add_theme_stylebox_override("panel", DolStyle.panel_style())
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	box.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 6)
	col.add_child(head_row)

	var lab := Label.new()
	lab.text = "换装预览"
	lab.add_theme_font_size_override("font_size", 13)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(lab)

	peek_btn = Button.new()
	peek_btn.text = "原貌"
	peek_btn.toggle_mode = true
	peek_btn.focus_mode = Control.FOCUS_NONE
	peek_btn.custom_minimum_size = Vector2(58, 22)
	peek_btn.add_theme_font_size_override("font_size", 11)
	peek_btn.tooltip_text = "切换显示：已还原的那部分「A」"
	peek_btn.toggled.connect(_on_peek_toggled)
	head_row.add_child(peek_btn)

	# 预览舞台：尺寸跟着当前图包的取景框走（DolDoll.frame_size 等比塞进 STAGE_BOX）。
	# 具体铺哪几层由 _refresh_preview() 交给 DolDoll 动态生成 ——
	# 一件衣物可能占好几层（发型就跨了三层：脑后的、侧面的、刘海）。
	var stage := Control.new()
	stage.custom_minimum_size = _stage_size()
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.clip_contents = true
	col.add_child(stage)
	preview_stage = stage

	peek_hint = Label.new()
	peek_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	peek_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peek_hint.add_theme_font_size_override("font_size", 10)
	col.add_child(peek_hint)

	# ---- DoL 式量表 ----
	#  两条：暴露值（到上限）/ 反差值（到要求）。
	#  点阵读「量级」、刻度条读「离阈值还有多远」、指针读「当前值」。
	#  ★ 用户口径（第十七轮）：「未改部位」那条整个撤掉 —— 它和反差值说的是
	#    同一件事（改得越多反差越高），留着只会让人多算一遍。
	col.add_child(HSeparator.new())
	_add_stat_block(col, "expose", "暴露值", DolStyle.RAMP_EXPOSE, "over_bad",
		"暴露值：这身打扮有多扎眼。跨过橙色刻线（本关上限）就会被一眼记住。")
	_add_stat_block(col, "contrast", "反差值", DolStyle.RAMP_CONTRAST, "under_bad",
		"反差值：你和「他记忆里的样子」差了多少。到橙色刻线（本轮要求）才算够。")

	col.add_child(HSeparator.new())

	# 文字清单：强制装备 / 缺陷 / 接受度（这些是「有或没有」，不适合做刻度）
	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	stats_label.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(stats_label)

# 一块量表 = 标题 + 点阵 + 「当前 / 阈值」 + 刻度条
func _add_stat_block(parent: VBoxContainer, key: String, title: String,
		ramp: Array, dir: String, tip: String) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	wrap.tooltip_text = tip
	parent.add_child(wrap)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(head)

	var t := Label.new()
	t.text = title
	t.custom_minimum_size = Vector2(56, 0)
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", DolStyle.SILVER)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)

	var pips := DolStyle.Pips.new(0.0, 1.0, ramp, tip)
	head.add_child(pips)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)

	var vl := Label.new()
	vl.text = "0 / 0"
	vl.add_theme_font_size_override("font_size", 11)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(vl)

	var sc := DolStyle.Scale.new(0.0, 1.0, ramp, -1.0, tip)
	wrap.add_child(sc)

	stat_blocks[key] = {"pips": pips, "scale": sc, "value": vl, "dir": dir, "ramp": ramp,
		"wrap": wrap}

# ---------------- 右侧：槽位分区 + 卡片网格 ----------------
func _build_item_list(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", DolStyle.panel_style())
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	item_cols = VBoxContainer.new()
	item_cols.add_theme_constant_override("separation", 10)
	item_cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_cols)

	for slot in OutfitData.active_slots():
		_add_slot_section(slot, item_cols)

# 一个槽位 = 一行分区标题 + 一张卡片网格
func _add_slot_section(slot: String, parent: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)

	# ---- 分区标题（对应 DoL 的 .wardrobeSubSection）----
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	section.add_child(head)

	var bar := ColorRect.new()
	bar.color = Color(0.35, 0.39, 0.45)
	bar.custom_minimum_size = Vector2(SLOT_BAR_W, 15)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bar)

	var lab := Label.new()
	lab.text = OutfitData.SLOT_NAMES.get(slot, slot)
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(lab)
	slot_labels[slot] = lab
	lab.set_meta("bar", bar)

	var note := Label.new()
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(note)
	slot_notes[slot] = note

	# ---- 卡片网格 ----
	var grid := GridContainer.new()
	grid.columns = CARD_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)

	var items := OutfitData.get_items_for_slot(slot)
	var btns := []
	var refs := []
	for it in items:
		var pair := _make_card(it)
		grid.add_child(pair["btn"])
		btns.append(pair["btn"])
		refs.append(pair)
	slot_buttons[slot] = btns
	card_refs[slot] = refs

	# 补几张空位卡片（DoL 的 .clothing-item-spacer）—— 最后一行不成整列时不至于豁口
	var rest: int = (CARD_COLS - items.size() % CARD_COLS) % CARD_COLS
	for i in rest:
		var spacer := PanelContainer.new()
		spacer.custom_minimum_size = Vector2(0, CARD_H)
		var sb := DolStyle.card_style("locked")
		sb.draw_center = false
		spacer.add_theme_stylebox_override("panel", sb)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(spacer)

# 一张衣物卡片（对应 DoL 的 .clothing-item）：
#   左侧缩略图（由 Button 自己的 icon 画，未解锁时是「?」）
#   右侧：名称 + E. 一行七点色阶
func _make_card(it: Dictionary) -> Dictionary:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 30×30 像素图标放 2 倍不糊
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_constant_override("icon_max_width", ICON_SIZE)
	b.add_theme_constant_override("h_separation", 6)
	b.pressed.connect(_on_item_pressed.bind(it))
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, DolStyle.card_style("normal"))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = ICON_SIZE + 14.0
	box.offset_right = -8.0
	box.offset_top = 4.0
	box.offset_bottom = -4.0
	box.add_theme_constant_override("separation", 0)
	# 点阵从三行减到一行之后，文字块比卡片矮了一截 —— 垂直居中，
	# 好让名称 + 点阵跟左侧缩略图（按钮自己居中画的）对齐。
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(box)

	var name_lab := Label.new()
	name_lab.clip_text = true
	name_lab.add_theme_font_size_override("font_size", 11)
	name_lab.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_lab)

	# ★ 第三十一轮（用户口径）：卡上**只留一行** E. 暴露值 —— 「C. 反差值」整行去掉。
	#   反差值不再是「单件衣服的固有属性」（第二十九轮起它由整套搭配算出来），
	#   印在卡上反而误导：玩家会以为挑几件高反差的零件就能凑够本轮要求。
	#   本轮还差多少，看左侧那条量表。
	var e := _add_pip_line(box, "E.", DolStyle.RAMP_EXPOSE, OutfitData.stat_max_of("exposure"))

	return {"btn": b, "name": name_lab, "e": e,
		"icon": null, "slot": str(it.get("slot", ""))}

func _add_pip_line(parent: VBoxContainer, letter: String, ramp: Array, mx: int) -> DolStyle.Pips:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var t := Label.new()
	t.text = letter
	t.custom_minimum_size = Vector2(14, 0)
	t.add_theme_font_size_override("font_size", 9)
	t.add_theme_color_override("font_color", DolStyle.GREY)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(t)

	var pips := DolStyle.Pips.new(0.0, float(maxi(1, mx)), ramp)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pips)
	return pips

# ---------------- 手机（浮层）----------------
#  整块地方留给换装，手机改成点按钮才出来的浮层。
#  卡司（A / B / C / 审讯官是谁）没丢 —— 它就写在手机备忘录里。
func _build_phone_overlay(host_row: HBoxContainer) -> void:
	intel = IntelDesk.new()
	add_child(intel)
	host_row.add_child(intel.phone_btn)
	host_row.move_child(intel.phone_btn, 0)

# ---------------- 交互 ----------------
func _on_peek_toggled(on: bool) -> void:
	_peeking = on
	# 外部（如自动化脚本）直接改 _peeking 时，把按钮视觉同步过来
	if not _peek_sync and peek_btn.button_pressed != on:
		_peek_sync = true
		peek_btn.button_pressed = on
		_peek_sync = false
	_refresh_preview()

func _on_item_pressed(item: Dictionary) -> void:
	# 玩家自己动了手 → 上一次「一键达标」的结果说明就作废了
	_auto_msg = ""
	# ★ 第三十六轮：多件槽位（纹身）走 toggle —— 已装备的再点一次是「脱下来」；
	#   单件槽位的语义没变（点已装备的那件仍是空操作）。
	if model.toggle(item):
		_refresh()

# ---- 测试按钮：一键满足本轮全部服装要求 ----
func _on_auto_complete() -> void:
	var rep: Dictionary = model.auto_complete_outfit()
	_auto_msg = _auto_report_text(rep)
	_refresh()

func _auto_report_text(rep: Dictionary) -> String:
	if bool(rep.get("ok", false)):
		return ("[color=#6fd39a]测试按钮：已满足本轮全部服装要求"
			+ "（反差 %d / %d ｜ 暴露 %d / %d）[/color]") % [
			int(rep.get("contrast", 0)), int(rep.get("contrast_req", 0)),
			int(rep.get("exposure", 0)), int(rep.get("exposure_cap", 0))]
	# 没能全部满足：把还差在哪一条条列出来，别只丢一句「失败」
	var why := []
	for d in rep.get("uncovered", []):
		why.append("缺陷「%s」遮不住" % str((d as Dictionary).get("name", "")))
	for it in rep.get("missing_forced", []):
		why.append("强制装备「%s」穿不上" % str((it as Dictionary).get("name", "")))
	if int(rep.get("contrast", 0)) < int(rep.get("contrast_req", 0)):
		why.append("反差 %d 达不到本轮要求的 %d" % [
			int(rep.get("contrast", 0)), int(rep.get("contrast_req", 0))])
	if int(rep.get("exposure", 0)) > int(rep.get("exposure_cap", 0)):
		why.append("暴露 %d 超出上限 %d" % [
			int(rep.get("exposure", 0)), int(rep.get("exposure_cap", 0))])
	return "[color=#f0a83c]测试按钮：尽力了，这一轮仍差 %d 处 —— %s[/color]" % [
		why.size(), "；".join(why)]

func _on_continue() -> void:
	wardrobe_confirmed.emit()

# ---------------- 刷新 ----------------
func _refresh() -> void:
	_update_run_label()
	_refresh_preview()
	_refresh_buttons()
	_update_stats()

func _update_run_label() -> void:
	if run_label == null:
		return
	run_label.text = "第 %d 局 ｜ %s ｜ 第 %d / %d 轮 ｜ %s" % [
		RunData.run_index, RunData.background_name(),
		RunData.level_number(), RunData.level_count(),
		model.level_name()]

	# 本局固定卡司：一局之内 A / B / C / 审讯官都不会换人。
	# 命名口径（用户定的）：A = 真身（你本人），B = 马甲（你在扮的那个人），C = 同行人。
	var c := RunData.cast()
	run_label.tooltip_text = ("本局卡司（一局之内不会变）\n"
		+ "  A 真身：%s —— 你本人，%s\n"
		+ "    「%s」这个名字只在一种时候会被念出来：他认出你的时候。\n"
		+ "  B 马甲：%s —— 你现在扮的人（%s）\n"
		+ "  审讯官：%s（%s·%s）—— 他认识 A，但他没见过 B\n"
		+ "  C 同行人：%s（%s·%s）—— 他知道你是 A，也知道你在装 B，可他不站你这边\n"
		+ "    %s\n"
		+ "\n场所：%s\n"
		+ "（手机备忘录里也记着这一份）") % [
		c["true_role"], c["player_gender"],
		c["true_name"],
		c["cover_role"], c["player_gender"],
		c["interrogator"], c["interrogator_gender"], c["trait"],
		c["companion"], c["companion_relation"], c["companion_gender"],
		c["companion_desc"],
		c["venue"]]

func _refresh_preview() -> void:
	# 铺哪一身：正常看「当前伪装」，按原貌切换时只显示已还原的那部分 A
	var eq: Dictionary = {}
	if _peeking:
		for slot in OutfitData.active_slots():
			if _slot_revealed(slot):
				var id := RunData.true_item(slot)
				if id != "":
					eq[slot] = id
	else:
		eq = model.equipped.duplicate(true)   # 深拷贝：多件槽位的值是 Array
	# DolDoll 会按 z 序把基础层 + 这一身的每一层铺好，并把每个槽位的首个
	# TextureRect 记回来（layer_rects 的语义与旧版一致：可用来判断有没有贴图）
	layer_rects = DolDoll.stack_into(preview_stage, eq, _stage_size())


# 预览区实际尺寸：把 AU 取景框 68×203 等比塞进 STAGE_BOX，得 92×276。
func _stage_size() -> Vector2:
	return DolDoll.fit_size(STAGE_BOX)

	var m_cnt := model.matching_slots().size()
	# ★ 第三十九轮：分母必须与 `matching_slots()` 同口径。
	#   那个函数现在走 `auto_slots()`（不含「妙妙工具」那一栏）——
	#   分母要是还用 active_slots()，就会印出「13 / 14 处仍一致」这种自相矛盾的数字。
	var slot_total := OutfitData.auto_slots().size()
	if _peeking:
		peek_hint.text = "「A」的原貌 —— 审讯官记忆里的你
还有 %d 处没改" % m_cnt
		peek_hint.add_theme_color_override("font_color", Color(0.90, 0.62, 0.36))
	else:
		peek_hint.text = "当前伪装 · 与原貌 %d / %d 处仍一致" % [m_cnt, slot_total]
		peek_hint.add_theme_color_override("font_color", Color(0.58, 0.62, 0.68))

func _tip_for(it: Dictionary, locked: bool, affordable: bool) -> String:
	# 还没解锁的装扮：卡片上是个问号，提示也别把名字漏出来 ——
	# 问号的意思就是「这件你还没到手」，只说还差多少接受度。
	if locked:
		return "？ 未解锁的装扮\n需要接受度 %d（当前 %d）" % [
			int(it.get("acceptance_req", 0)), model.acceptance]
	# DoL 的悬停会另给一行精确读数（数字自身染色），这里照办
	# ★ 第三十一轮（用户口径）：悬停里**不再报反差值** —— 只留暴露值与接受度门槛。
	var tip := "%s\n暴露值 %d ｜ 需接受度 %d" % [
		it["name"], it["exposure"], it["acceptance_req"]]
	var slot: String = it["slot"]
	# ★ 第三十九轮：妙妙工具（只能手动装备的一栏）。
	#   它没有原貌、不进任何数值统计，所以上面那行「暴露值 / 接受度」对它意义不大，
	#   但照旧印出来（都是 0，玩家一眼就知道它不占预算）。这里补两行：
	#   · 物品自己的**介绍**（ITEMS 里的 `desc` 字段，用户口径「介绍为喵什么错都没有」）
	#   · 这一栏的机制说明 —— 免得玩家以为它是个普通饰品
	if OutfitData.is_manual_slot(slot):
		var d := str(it.get("desc", ""))
		if d != "":
			tip += "\n" + d
		tip += "\n（妙妙工具 —— 只能手动装备，不参与原貌与反差值计算）"
		return tip
	# ★ 第二十二轮（第三十六轮扩到纹身）：受门控的件 —— 只有「看得见」时才算数值。
	#   不写出来的话，读数跟量表对不上，玩家会以为出 bug 了。
	if OutfitData.is_gated_item(it) and not model.item_counts(slot, str(it["id"])):
		tip += "\n外衣盖得严实 —— 这一件不计入暴露值"
		tip += "\n（透出来才算：透明外衣 / 镂空开档 / 直接外穿）"
	# ★ 第三十六轮：多件槽位（纹身）—— 说清上限与「再点一次脱下来」。
	if OutfitData.is_multi_slot(slot):
		var n: int = model.solid_ids(slot).size()
		tip += "\n最多同时装备 %d 件（当前 %d 件）" % [OutfitData.max_equip(slot), n]
		if model.ids_at(slot).has(str(it["id"])):
			tip += "\n再点一次即脱下"
		elif n >= OutfitData.max_equip(slot):
			tip += "\n已满 —— 再装一件会顶掉最早那件"
	# ★ 刻意**不**在悬停里提示「这件与原貌一致 / 不同」——
	#   那等于把答案直接写在卡片上，搭配的乐趣全没了。玩家得自己去情报台比对。
	# ★ 第二十七轮：互斥槽位（成装 / 上装 / 下装）要说清「穿上它会顶掉谁」——
	#   不然玩家点了一下发现另一栏被清空了，会当成 bug。
	var peers: Array = OutfitData.exclusive_peers(slot)
	if not peers.is_empty() and not OutfitData.is_bare(it):
		var names := []
		for p in peers:
			var ps := str(p)
			names.append(str(OutfitData.SLOT_NAMES.get(ps, ps)))
		tip += "\n与%s互斥：穿上这件会自动脱下同类" % " / ".join(names)
	if not _slot_revealed(slot):
		tip += "\n该部位原貌未知 —— 你无法判断这一件"
	if not affordable:
		tip += "\n装上后会超出暴露值上限"
	return tip

# 卡片的视觉状态：普通 / 已装备 / 强制 / 未解锁，另外把暴露值点阵刷新
func _card_state(it: Dictionary, is_equipped: bool, locked: bool, affordable: bool) -> String:
	if is_equipped:
		return "forced" if model.is_forced_id(str(it["id"])) else "equipped"
	if locked:
		return "locked"
	if not affordable:
		return "dim"
	return "normal"

func _refresh_buttons() -> void:
	var matching := model.matching_slots()
	for slot in OutfitData.active_slots():
		var lab: Label = slot_labels.get(slot)
		var bar: ColorRect = lab.get_meta("bar") if lab != null else null
		if lab != null:
			var base := str(OutfitData.SLOT_NAMES.get(slot, slot))
			# ★ 第三十九轮：妙妙工具（只能手动装备的一栏）**没有原貌可比** ——
			#   所以既不给它「? 原貌未知」（它不是「还没查到」，是压根不参与），
			#   也不给「仍与 A 一致 / 已偏离原貌」（那两个说法对它都没有意义）。
			if OutfitData.is_manual_slot(slot):
				lab.text = base
				lab.add_theme_color_override("font_color", Color(0.74, 0.68, 0.94))
				lab.tooltip_text = "妙妙工具 —— 只能手动装备，不参与原貌与反差值计算"
				if bar != null:
					bar.color = Color(0.60, 0.54, 0.82)
			elif not _slot_revealed(slot):
				lab.text = base + " ?"
				lab.add_theme_color_override("font_color", Color(0.50, 0.53, 0.58))
				lab.tooltip_text = "原貌未知 —— 你还没查到他在这个部位的样子"
				if bar != null:
					bar.color = Color(0.30, 0.33, 0.38)
			elif matching.has(slot):
				lab.text = base
				lab.add_theme_color_override("font_color", Color(0.93, 0.60, 0.36))
				lab.tooltip_text = "仍与 A 的原貌一致 —— 审讯官一眼就会认出"
				if bar != null:
					bar.color = Color(0.95, 0.60, 0.30)
			else:
				lab.text = base
				lab.add_theme_color_override("font_color", Color(0.50, 0.86, 0.66))
				lab.tooltip_text = "已偏离原貌"
				if bar != null:
					bar.color = DolStyle.GREEN

		# 分区标题右侧：当前穿的是什么（多件槽位把名字串起来）
		var note: Label = slot_notes.get(slot)
		if note != null:
			var names := []
			for it in model.items_at(slot):
				names.append(str((it as Dictionary).get("name", "")))
			note.text = "当前：%s" % "、".join(names) if not names.is_empty() else ""

	for slot in OutfitData.active_slots():
		var items := OutfitData.get_items_for_slot(slot)
		var cur_ids: Array = model.ids_at(slot)
		var refs: Array = card_refs[slot]

		for i in items.size():
			var it: Dictionary = items[i]
			var pair: Dictionary = refs[i]
			var b: Button = pair["btn"]
			var is_equipped: bool = cur_ids.has(str(it["id"]))
			var locked := not model.can_equip(it)
			# ★ 判断「装上后会不会超上限」必须按门控后的真实值来算 ——
			#   换上蕾丝内衣本身不加暴露值，但换上半透上衣会连带把内衣一起点亮。
			#   用单槽位增量（精确、含连带效应），比整套重算便宜几十倍。
			var affordable := model.exposure_after(slot, str(it["id"])) <= model.exposure_cap()
			var usable := not locked and affordable
			var state := _card_state(it, is_equipped, locked, affordable)

			b.disabled = (not usable) and (not is_equipped)
			b.modulate = Color(1, 1, 1, 1) if (is_equipped or usable) else Color(0.62, 0.63, 0.68, 0.85)

			# ★ 还没解锁的装扮**不显示图标，只显示问号** ——
			#   接受度不够就意味着这件还没到手，提前把样子亮出来等于剧透，
			#   也让人分不清「买不起」和「不适合」。悬停仍然能看到还差多少接受度。
			var name_lab: Label = pair["name"]
			if locked and not is_equipped:
				b.icon = null
				b.text = "?"
				b.add_theme_font_size_override("font_size", 20)
				b.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
				name_lab.text = "未解锁的装扮"
				name_lab.add_theme_color_override("font_color", Color(0.50, 0.53, 0.58))
			else:
				b.icon = DolDoll.icon(str(it["id"]))
				b.text = ""
				b.remove_theme_color_override("font_color")
				name_lab.text = str(it["name"])
				name_lab.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))

			# ★ 第三十一轮：卡上只剩一行 E. 暴露值（反差值那行已按用户口径去掉）。
			(pair["e"] as DolStyle.Pips).setup(float(it.get("exposure", 0)),
				float(OutfitData.stat_max_of("exposure")), DolStyle.RAMP_EXPOSE)

			# ★ 第二十二轮（第三十六轮扩到纹身）：受门控的件，外衣不够露时把点阵压暗 ——
			#   卡片上照旧印着它自己的数值，但一眼就能看出「目前不算数」。
			#   ★ 逐件判定：多件槽位里可能一件露着、一件被盖住。
			var gate_alpha := 1.0 if model.item_counts(slot, str(it["id"])) else 0.32
			(pair["e"] as DolStyle.Pips).modulate = Color(1, 1, 1, gate_alpha)

			# 边框：强制装备（橙）优先于「已装备」（绿）
			for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
				b.add_theme_stylebox_override(st, _card_style_for(state, st))

			var tip := _tip_for(it, locked, affordable)
			if model.is_forced_id(str(it["id"])):
				tip = "本轮强制装备 —— 不穿会当场被识破\n" + tip
			if is_equipped:
				tip += "\n已装备"
			b.tooltip_text = tip

func _card_style_for(state: String, slot_name: String) -> StyleBoxFlat:
	var st := DolStyle.card_style(state)
	if slot_name in ["hover", "focus", "hover_pressed"]:
		if state == "normal":
			st = DolStyle.card_style("hover")
		elif state == "equipped":
			st.bg_color = Color("17301f")
			st.border_color = DolStyle.GREEN.lightened(0.18)
		elif state == "forced":
			st.bg_color = Color("38220f")
			st.border_color = DolStyle.ORANGE.lightened(0.15)
	return st

func _update_stats() -> void:
	var exp_t := model.total_exposure()
	var exp_c := model.exposure_cap()
	var con_t := model.total_contrast()
	var con_r := model.contrast_requirement()

	# ---- DoL 量表：两条（暴露值 / 反差值）----
	_refresh_stat_block("expose", float(exp_t), float(exp_c), exp_t > exp_c)
	_refresh_stat_block("contrast", float(con_t), float(con_r), con_t < con_r)

	# ---- 文字清单（这些是「有或没有」，不适合做刻度）----
	#  ★ 用户口径（第十七轮）：这里不再重复轮次名 —— 顶部标题栏「第 1 / 4 关 ｜
	#    第一轮 · 外栅栏哨位」已经写了；悬停里那句「审讯官依据线索推导出的形象」
	#    也一并撤掉，只留场所一行。
	var lines := []
	lines.append("[color=#8fb8f0]接受度 [b]%d[/b][/color]" % model.acceptance)
	if ProfileData.bonus() > 0:
		lines.append("[color=#6f7684]跨局保留 [b]+%d[/b]（失败也不会丢）[/color]" % ProfileData.bonus())

	# 本轮强制装备（0 ~ 2 件高暴露衣物，没穿 = 当场识破）
	var forced := model.forced_items_info()
	if forced.is_empty():
		lines.append("[color=#c8ccd4]【强制装备】[/color][color=#7a8290]本轮没有硬性要求[/color]")
	else:
		var miss_ids := []
		for m in model.missing_forced():
			miss_ids.append(str(m.get("id", "")))
		lines.append("[color=#c8ccd4]【强制装备】[/color][color=%s][b]%d[/b] / %d 已穿[/color]"
			% ["#f2595b" if miss_ids.size() > 0 else "#4dd98f",
				forced.size() - miss_ids.size(), forced.size()])
		for it in forced:
			var worn: bool = not miss_ids.has(str(it.get("id", "")))
			lines.append("[color=%s]  %s%s（暴露 %d）[/color]" % [
				"#4dd98f" if worn else "#f2595b",
				"已穿 " if worn else "未穿 ",
				str(it.get("name", "")), int(it.get("exposure", 0))])

	# 缺陷遮挡
	var uncovered := model.exposed_defects()
	if uncovered.is_empty():
		lines.append("[color=#c8ccd4]【缺陷遮挡】[/color][color=#4dd98f]全部遮住了[/color]")
	else:
		lines.append("[color=#c8ccd4]【缺陷遮挡】[/color][color=#f2595b]%d 处露着[/color]" % uncovered.size())
		for d in uncovered:
			lines.append("[color=#f2595b]  %s[/color]" % d["name"])

	# 「一键达标」测试按钮的结果 —— 只在刚点过、且玩家没再自己动手时显示。
	# ★ 判定栏撤掉之后，这句测试反馈改挂到左侧文字清单的末尾（它本来就只是测试用）。
	if _auto_msg != "":
		lines.append(_auto_msg)

	stats_label.text = "\n".join(lines)
	stats_label.tooltip_text = RunData.venue()

	sync_outfit_verdict()

# 量表刷新：
#   · 点阵按**阈值**切档 —— 到上限/要求正好满 7 颗，一眼看出够没够
#   · 刻度条的量程按数值本身的可能范围定，刻线才会随轮次移动
#   · 数值标签在「不该越界却越了」时变红
func _refresh_stat_block(key: String, value: float, warn: float, bad: bool) -> void:
	var b: Dictionary = stat_blocks.get(key)
	if b.is_empty():
		return
	var ramp: Array = b["ramp"]
	var tip: String = ""
	match key:
		"expose":
			tip = "暴露值 %d / 上限 %d\n这身打扮有多扎眼。跨过橙色刻线就会被一眼记住。" % [value, warn]
		"contrast":
			tip = "反差值 %d / 要求 %d\n你和「他记忆里的样子」差了多少。到橙色刻线才算够。" % [value, warn]

	var pip_max: float = warn
	var scale_max: float = float(SCALE_MAX.get(key, maxf(warn, 1.0)))

	(b["pips"] as DolStyle.Pips).setup(value, maxf(1.0, pip_max), ramp, tip)
	(b["scale"] as DolStyle.Scale).setup(value, scale_max, ramp, warn, tip)
	var vl: Label = b["value"]
	vl.text = "%d / %d" % [int(value), int(warn)]
	vl.add_theme_color_override("font_color",
		DolStyle.RED if bad else DolStyle.ramp_color(ramp, DolStyle.level_of(value, maxf(1.0, pip_max))))

# 把「这身打扮算出来什么」写进 GameData —— 阶段一不下结论，只把结果交出去。
func sync_outfit_verdict() -> void:
	var ev := model.evaluate()
	var reasons: Array = ev["reasons"]
	GameData.outfit_passed = (str(ev["verdict"]) == "pass")
	GameData.outfit_fail_reasons = reasons.duplicate()

	# 顺带把其余几个值也同步过去 —— 阶段二开场要用
	GameData.outfit_exposure = model.total_exposure()
	GameData.outfit_exposure_cap = model.exposure_cap()
	GameData.contrast_total = model.total_contrast()
	GameData.contrast_required = model.contrast_requirement()
	GameData.contrast_sufficient = model.is_contrast_sufficient()
	GameData.matching_slots_count = model.matching_slots().size()
	GameData.defects_covered = model.exposed_defects().is_empty()
	GameData.uncovered_defects = model.exposed_defects()
	GameData.acceptance = model.acceptance
	# ★ 第三十九轮：把「这一轮实际携带的妙妙工具」交给 GameData —— 阶段二要用它。
	#   妙妙工具（OutfitData.MANUAL_SLOTS）是**手动装备**的一栏，不进任何数值统计，
	#   所以这里只把它的实体件 id 报出去（空件「（不携带）」不算）。
	#   遍历 MANUAL_SLOTS 而不是写死 "tool" —— 以后这一栏加槽位不用改这里。
	var tools: Array = []
	for ms in OutfitData.MANUAL_SLOTS:
		for tid in model.solid_ids(str(ms)):
			tools.append(str(tid))
	GameData.carried_tools = tools
	# ★ 不锁按钮：赌不赌由你决定。
	continue_btn.disabled = false
