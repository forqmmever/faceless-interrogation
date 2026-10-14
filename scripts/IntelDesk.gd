class_name IntelDesk
extends Control

# ============================================================
#  准备室里的「手机」—— 一个可开合的浮层
#
#  这里以前是「情报台」：一个占满右栏的面板，里面还有两个页签
#  （🎭 审问者 / 📱 手机），加上标题、说明段、性情卡、对策卡。
#  字太密，而且右栏一占，换装的地方就窄了。
#
#  现在整块留给换装，手机改成**浮层**：
#    · 标题栏一个「📱 手机」按钮 → 点开浮层；点遮罩或「✕ 收起」关掉。
#    · 审问者的性情只活在手机备忘录第一条里（含「该怎么答」那一行），
#      所以「翻开过备忘录」就等于「记下了他的脾性」——
#      盘问里 B 类题选项上的 ⚠ 从此以它为准（见 PhoneDesk._switch_app）。
#
#  数据层一行没动：identity_assign / revealed 依旧在开局自动填好，
#  依旧实时写进 GameData，Interrogation 与 Wardrobe 的判定逻辑不用改。
#
#  为什么那两套状态是「开局即自动填好」：
#    早期的「身份情报」「外貌情报」两栏各自要玩家手动点 12 次 / 18 次，
#    是纯粹的体力活，玩家读的是同一批信息，只是多按了几十下。
#    现在改成：归类按卡的 owner 自动填好（B 卡 = 可照答，A 卡 = 禁区），
#    原貌开局即全部可见 —— 换装时直接照着相反方向改就行。
#    信息一条没少，少的是那几十次点击。
# ============================================================

signal changed

var identity_assign: Dictionary = {}   # card_id -> "kept" | "sealed"（开局即按 owner 自动填好）
var revealed: Dictionary = {}          # slot -> true（开局即全满）

var phone: PhoneDesk
var phone_btn: Button                  # 造好之后由 Wardrobe 摆进左下角
var phone_help_btn: Button             # 手机浮层里的「玩法说明」入口（讲四个界面）
var phone_layer: Control
var phone_center: CenterContainer

func _ready() -> void:
	_fill_identity()
	_fill_revealed()
	_build_ui()
	rebuild()
	sync_to_gamedata()
	# ⚠ 这一层是被 add_child 进来的，那一帧父节点还没把新子节点的尺寸算下来，
	#   于是它的 size 会停在 (0,0) —— 浮层跟着一起塌成 0×0，手机就跑到左上角去了。
	#   下一帧补一次对齐；之后父窗口再变，靠 resized 信号跟着走。
	_sync_full_rect.call_deferred()
	resized.connect(_sync_full_rect)

func _sync_full_rect() -> void:
	if not is_inside_tree():
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if phone_layer != null:
		phone_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ---------------- 两套状态：开局即自动填好 ----------------
func _fill_identity() -> void:
	identity_assign.clear()
	for card in DossierData.cards():
		identity_assign[str(card["id"])] = "kept" if str(card["owner"]) == "B" else "sealed"

func _fill_revealed() -> void:
	revealed.clear()
	for slot in OutfitData.active_slots():
		revealed[slot] = true

# ---------------- UI ----------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 这一层只是个「浮层宿主」—— 自己完全不挡鼠标，换装界面照样能点。
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	phone_btn = Button.new()
	phone_btn.text = ScenarioData.ui_t_d("wardrobe.phone_btn")
	phone_btn.focus_mode = Control.FOCUS_NONE
	# 放在左下角、字号拉大、亮蓝描边 —— 它是准备室里唯一的「去看情报」入口，
	# 藏在角落里也得一眼看得见。
	phone_btn.custom_minimum_size = Vector2(140, 46)
	phone_btn.add_theme_font_size_override("font_size", 15)
	phone_btn.tooltip_text = ScenarioData.ui_t_d("wardrobe.phone_tip")
	phone_btn.pressed.connect(toggle_phone)
	_style_phone_btn()

	_build_phone_layer()

# 按钮的视觉：亮蓝底 + 描边，四个状态都套同一套 ——
# 免得鼠标一悬停就掉回 Godot 默认那个灰扑扑的样子。
func _style_phone_btn() -> void:
	if phone_btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.36, 0.58)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.44, 0.74, 1.0)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		phone_btn.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		phone_btn.add_theme_color_override(c, Color(0.95, 0.98, 1.0))

func _build_phone_layer() -> void:
	phone_layer = Control.new()
	phone_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	phone_layer.visible = false
	add_child(phone_layer)

	# 遮罩：点一下就收起手机
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.025, 0.035, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	phone_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_layer.add_child(center)
	phone_center = center

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	center.add_child(vb)

	# ★ 手机拿在手里的时候，顶栏那个「玩法说明」按钮被遮罩挡住了 ——
	#   所以浮层里另给一个入口：点了会逐个讲手机里这四个界面。
	#   （Main._show_stage_help 会先看手机开着没有，再决定讲哪一套。）
	phone_help_btn = Button.new()
	phone_help_btn.text = ScenarioData.ui_t_d("wardrobe.phone_help_btn")
	phone_help_btn.focus_mode = Control.FOCUS_NONE
	phone_help_btn.custom_minimum_size = Vector2(0, 34)
	phone_help_btn.add_theme_font_size_override("font_size", 13)
	phone_help_btn.tooltip_text = ScenarioData.ui_t_d("wardrobe.phone_help_tip")
	vb.add_child(phone_help_btn)

	phone = PhoneDesk.new()
	phone.changed.connect(_on_phone_changed)
	phone.slot_revealed.connect(_on_phone_slot_revealed)
	vb.add_child(phone)
	# ⚠ 高度必须写在 add_child 之后 —— PhoneDesk._build_shell() 会把
	#   custom_minimum_size 覆写成 (PHONE_W, 0)，那是给「有父容器撑高」的场合用的。
	#   浮层里没人替它撑，就得自己给一个（视口高 620，留出上下的边）。
	phone.custom_minimum_size = Vector2(PhoneDesk.PHONE_W, 500)

	var close := Button.new()
	close.text = ScenarioData.ui_t_d("wardrobe.phone_close_btn")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 32)
	close.add_theme_font_size_override("font_size", 12)
	close.pressed.connect(close_phone)
	vb.add_child(close)

func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		close_phone()

# ---------------- 开合 ----------------
func is_phone_open() -> bool:
	return phone_layer != null and phone_layer.visible

func toggle_phone() -> void:
	if is_phone_open():
		close_phone()
	else:
		open_phone()

func open_phone() -> void:
	if phone_layer == null:
		return
	# 浮层建出来的时候它还挂在「父节点尺寸 0×0」上，之后一直是 hidden，
	# 尺寸就停在那一刻了 —— 显示前再对齐一次，免得手机跑到左上角去。
	_sync_full_rect()
	if phone_center != null:
		phone_center.queue_sort()
	phone_layer.show()
	if phone != null:
		phone.rebuild()
	_update_phone_btn()

func close_phone() -> void:
	if phone_layer == null:
		return
	phone_layer.hide()
	_update_phone_btn()

# 按钮上的字：只报「开 / 收」两个状态。
# ★ 「0/1」「🔒3」这类计数与「还有几条没解锁」的字样一律去掉 ——
#   那些数字是给玩家添焦虑的，不是他要做的决定。
func _update_phone_btn() -> void:
	if phone_btn == null:
		return
	phone_btn.text = "📱 收起手机" if is_phone_open() else "📱 手机"

# ---------------- 审问者的情报（性情）----------------
#  按钮没了 —— 入口改成「翻开手机备忘录」。这里留一个纯状态方法，
#  测试与外部脚本仍然可以显式记下 / 忘掉。
func _read_intel() -> void:
	GameData.interrogator_intel_read = true
	rebuild()
	changed.emit()

func _forget_intel() -> void:
	GameData.interrogator_intel_read = false
	rebuild()
	changed.emit()

# ---------------- 操作 ----------------
# 归类 / 还原这两个动作已经没有 UI 了（见文件头说明），但方法留着：
# 测试与截图脚本还在用它们构造状态（例如故意把 A 卡收进伪装档案来验「说漏嘴」），
# 删掉会连带一堆无关的编译错误。现在它们只是「改状态 + 刷新」，没有对应按钮。
func _assign(card_id: String, state: String) -> void:
	if state == "":
		identity_assign.erase(card_id)
	else:
		identity_assign[card_id] = state
	rebuild()
	sync_to_gamedata()
	changed.emit()

func _reveal(clue_id: String) -> void:
	var clue := DossierData.get_clue(clue_id)
	if clue.is_empty():
		return
	revealed[str(clue["slot"])] = true
	rebuild()
	sync_to_gamedata()
	changed.emit()

# 手机里读了短信 / 擦了照片 —— 手机的进度也是情报进度
func _on_phone_changed() -> void:
	rebuild()
	sync_to_gamedata()
	changed.emit()

# 照片擦清楚了：等于白捡一处原貌还原
func _on_phone_slot_revealed(slot: String) -> void:
	revealed[slot] = true
	rebuild()
	sync_to_gamedata()
	changed.emit()

# ---------------- 统计 ----------------
func identity_done_count() -> int:
	var n := 0
	for k in identity_assign:
		if str(identity_assign[k]) != "":
			n += 1
	return n

func clues_done_count() -> int:
	return revealed.size()

func unassigned_count() -> int:
	return DossierData.card_count() - identity_done_count()

func identity_mistakes() -> int:
	var n := 0
	for card in DossierData.cards():
		var st: String = str(identity_assign.get(card["id"], ""))
		if st == "":
			continue          # 还没归类 ≠ 归错，交给 unassigned_count() 去管
		var correct: bool = (st == "kept" and card["owner"] == "B") \
			or (st == "sealed" and card["owner"] == "A")
		if not correct:
			n += 1
	return n

func is_identity_complete() -> bool:
	return unassigned_count() == 0

# 整局重来：清空全部整理进度（换背景 / 换原貌之后必须调用）
func reset() -> void:
	_fill_identity()
	_fill_revealed()
	close_phone()
	rebuild()
	if phone != null:
		phone.rebuild()
	sync_to_gamedata()
	changed.emit()

# ---------------- 同步 ----------------
func sync_to_gamedata() -> void:
	var kept := []
	var sealed := []
	for card in DossierData.cards():
		var st: String = str(identity_assign.get(card["id"], ""))
		if st == "kept":
			kept.append(card["id"])
		elif st == "sealed":
			sealed.append(card["id"])

	GameData.dossier_kept = kept
	GameData.dossier_sealed = sealed
	GameData.dossier_mistakes = identity_mistakes()
	GameData.dossier_total = DossierData.card_count()

	var slots := []
	for slot in OutfitData.active_slots():
		if revealed.has(slot):
			slots.append(slot)
	GameData.revealed_slots = slots
	GameData.clues_total = DossierData.clue_count()

# ---------------- 重建 ----------------
# 页签没了，这里只剩两件事：手机内容跟着本局进度刷新，按钮上的数字跟着刷新
func rebuild() -> void:
	if phone != null:
		phone.rebuild()
	_update_phone_btn()
