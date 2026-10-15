class_name PhoneDesk
extends Control

# ============================================================
#  手机 —— 情报的第二个界面
#
#  为什么要有手机：
#    档案是「别人的东西」—— 通缉令、口供、账单，冷冰冰，是碎片。
#    手机是「你的东西」—— 短信、相册，热乎，是你自己生活的痕迹。
#    两者拼在一起，才拼得出「B 是谁」和「A 长什么样」。
#
#  四个 App：
#    💬 消息 —— 列表按来源分成三段，但**不写分组标题**（用户定的：
#                「与审问官」「与同行的人」这类说明文字全删）。
#                顺序从最危险的排到唯一帮你的：
#                  · 审问官本人 —— 事件短信：答题时掏手机掏太多次招来的，
#                                  发信人就是他本人。存在 GameData，跨关累积。
#                  · 同行的人 C —— C 发来的。他知道你是 A，不站你这边。
#                                  ★ **不给口径**（没有 reveals），只施压。
#                  · 朋友       —— 东家、家人、旧相识。
#                                  ★ 读完才知道「B 的官方说法」——
#                                    盘问时你要是跟短信里说的不一样，那就是前后矛盾。
#    📷 相册 —— 别人偷拍的 A。糊、有反光、有噪点。
#                反复「擦掉反光」把清晰度顶上去，够清楚了才认得出那处原貌。
#                有些底片本身就废了，怎么擦都看不清 —— 这就是信息不全。
#    📒 备忘录 —— 手记。**第一条就是他**：这一局来问你的那个人的脾性、喜好、
#                忌讳。往后两页是卡司速记和本轮要点。篇幅刻意很短 —— 够用就行。
#    📝 备注 —— 你已经掌握的说法清单（只记官方版本，不记你临场编的）。
#
#  ★ 界面上的每一个字都来自 ScenarioData.PHONE（data/story.json 的 phone 段）——
#    没有硬编码。想改提示语、改 App 名字、改三个分组的标题，
#    用 tools/phone_editor.html 改就行，不用碰这个文件。
# ============================================================

signal changed
signal slot_revealed(slot: String)

const SHADER_PATH := "res://shaders/photo_blur.gdshader"

# 消息列表里那条「审讯官本人」的对话，用一个不会被剧情短信撞上的 id
const INTR_THREAD := "__interrogator__"

const PHONE_W := 336
# ★ 照片卡片的尺寸是「手机宽度」的约束条件，不是随便定的：
#   手机内容区只有 PHONE_W - 机身边距(9×2) - 屏幕边距(8×2) = 302 宽，
#   相册是 2 列网格，每格还要扣掉卡片内边距 8×2 ——
#   2×(PHOTO_VW+16) + 列间距 7 ≤ 302  →  PHOTO_VW ≤ 131。
#   以前是 150：相册一展开就把整部手机撑宽了（其它 App 看着就「变小」）。
const PHOTO_VW := 124
const PHOTO_VH := 158

# 三个分组的强调色 —— 和准备室顶栏的卡司配色对齐：
#   审问官 = 红（他就在桌子对面）｜ C = 紫（同行人）｜ 朋友 = 蓝
const GROUP_COLORS := {
	"interrogator": Color(0.96, 0.52, 0.46),
	"companion": Color(0.80, 0.66, 0.96),
	"friends": Color(0.55, 0.78, 0.98),
}

var screen_box: VBoxContainer          # 屏幕内容容器（每次切换 App 重建）
var app_bar: HBoxContainer
var title_label: Label
var status_time: Label

var _app: String = "messages"
var _open_sms: String = ""
var _photo_shader: Shader

var _photo_subs: Array = []            # index -> SubViewport
var _photo_key: String = ""

func _ready() -> void:
	_photo_shader = load(SHADER_PATH) if ResourceLoader.exists(SHADER_PATH) else null
	_build_shell()
	rebuild()

# ============================================================
#  文案：全部从 ScenarioData.PHONE 读
# ============================================================
## 按 "messages.group_friends" 这样的路径取一条文案。
func _t(path: String, fallback: String = "") -> String:
	return ScenarioData.phone_text(path, fallback)

## 取一条带占位符的文案并格式化。
## 模板里的 % 数量对不上（编辑器改坏了）时退回 fallback ——
## 宁可用出厂文案，也别让整个手机在运行时抛错。
func _tf(path: String, args: Array, fallback: String) -> String:
	var tpl := _t(path, fallback)
	if _count_ph(tpl) != args.size():
		if _count_ph(fallback) != args.size():
			return tpl
		tpl = fallback
	return tpl % args

func _count_ph(s: String) -> int:
	var n := 0
	var i := 0
	while i < s.length():
		if s[i] == "%":
			if i + 1 < s.length() and s[i + 1] == "%":
				i += 2
				continue
			n += 1
		i += 1
	return n

# ============================================================
#  外壳
# ============================================================
func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(PHONE_W, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bezel := PanelContainer.new()
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.055, 0.058, 0.072)
	bs.set_corner_radius_all(24)
	bs.set_border_width_all(2)
	bs.border_color = Color(0.24, 0.25, 0.30)
	bezel.add_theme_stylebox_override("panel", bs)
	add_child(bezel)

	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 9)
	bezel.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	m.add_child(col)

	# ---- 状态栏 ----
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 6)
	col.add_child(status)

	status_time = Label.new()
	status_time.text = _t("shell.time", "21:40")
	status_time.add_theme_font_size_override("font_size", 11)
	status_time.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	status.add_child(status_time)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(sp)

	var sig := Label.new()
	sig.text = _t("shell.signal", "▮▮▯  4G  🔋78%")
	sig.add_theme_font_size_override("font_size", 10)
	sig.add_theme_color_override("font_color", Color(0.60, 0.64, 0.72))
	status.add_child(sig)

	# ---- 屏幕 ----
	var screen := PanelContainer.new()
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.085, 0.092, 0.115)
	ss.set_corner_radius_all(15)
	ss.set_border_width_all(1)
	ss.border_color = Color(0.18, 0.19, 0.24)
	screen.add_theme_stylebox_override("panel", ss)
	col.add_child(screen)

	var sm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		sm.add_theme_constant_override("margin_" + s, 8)
	screen.add_child(sm)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sm.add_child(sv)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
	sv.add_child(title_label)

	var sep := HSeparator.new()
	sv.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(scroll)

	# ★ 第三十一轮（用户口径「修复切换到相册界面大小会变」）：
	#   症状：手机外框一直是 336 宽不变，但**屏幕内容区的实际宽度会变** ——
	#     消息页 296 / 相册页 299（实测），切过去整块内容会横向跳 3px。
	#   根因：纵向滚动条一出现就占掉 3px 宽。谁需要滚动条取决于内容长度，
	#     于是「切 App」变成了「内容区变宽变窄」。
	#   修法：把纵向滚动条的宽度压到 0 —— 真机上的滚动条本来也是浮在内容上的、
	#     不占布局。滚轮 / 拖拽照常可用，只是不再挤压内容。
	var vbar := scroll.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(0, 0)
	vbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	vbar.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	vbar.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	vbar.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())

	screen_box = VBoxContainer.new()
	screen_box.add_theme_constant_override("separation", 7)
	screen_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(screen_box)

	# ---- 底部 App 栏 ----
	app_bar = HBoxContainer.new()
	app_bar.add_theme_constant_override("separation", 4)
	col.add_child(app_bar)

	_add_app_button("messages", _t("shell.app_messages", "💬 消息"))
	_add_app_button("photos", _t("shell.app_photos", "📷 相册"))
	_add_app_button("memo", _t("shell.app_memo", "📒 备忘录"))
	_add_app_button("notes", _t("shell.app_notes", "📝 备注"))

func _add_app_button(id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	# 四个 App 挤在 336px 里 —— 字号压到 10 才不至于把「备忘录」三个字截掉
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(_switch_app.bind(id))
	app_bar.add_child(b)
	b.set_meta("app_id", id)

func _switch_app(id: String) -> void:
	_app = id
	if id != "messages":
		_open_sms = ""
	# ★ 翻开备忘录 = 读到了审问者的性情。
	#   情报台删掉之后，这里是「记下他的脾性」的唯一入口 ——
	#   盘问里 B 类题选项上的 ⚠，从此以「你有没有翻开过备忘录」为准。
	if id == "memo" and not GameData.interrogator_intel_read:
		GameData.interrogator_intel_read = true
		changed.emit()
	rebuild()

func _style_app_buttons() -> void:
	for b in app_bar.get_children():
		var active: bool = str(b.get_meta("app_id")) == _app
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.17, 0.33, 0.52) if active else Color(0.12, 0.13, 0.17)
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.33, 0.58, 0.86) if active else Color(0.20, 0.22, 0.27)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var fg := Color(0.96, 0.98, 1) if active else Color(0.56, 0.60, 0.67)
		for c in ["font_color", "font_pressed_color", "font_hover_color",
				"font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, fg)

# ============================================================
#  重建
# ============================================================
func rebuild() -> void:
	_style_app_buttons()
	_clear(screen_box)

	match _app:
		"messages":
			if _open_sms == "":
				_build_thread_list()
			else:
				_build_thread_view()
		"photos":
			_build_album()
		"memo":
			_build_memo()
		"notes":
			_build_notes()

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _header(text: String, back: bool) -> void:
	title_label.text = text
	if back:
		# 标题左侧给一个返回按钮
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		screen_box.add_child(row)
		var b := Button.new()
		b.text = _t("messages.btn_back", "‹ 返回")
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_back_to_list)
		row.add_child(b)

func _back_to_list() -> void:
	_open_sms = ""
	rebuild()

# ============================================================
#  App 1 · 消息（三个分组）
#
#  分组顺序刻意是「审问官 → 同行的人 → 朋友」：
#  从最危险的那个开始，到唯一真正帮你的那个结束。
# ============================================================
func _build_thread_list() -> void:
	title_label.text = _t("messages.title", "消息")

	var friends: Array = DossierData.sms_threads()
	var read := _read_count(friends)
	var total := DossierData.sms_total()
	# ★ 第三十一轮（用户口径）：去掉「还有 N 条没到手 —— 往后每过一关…」那行小字。
	#   短信逐关解锁这件事，过一关自然就发现了；而那行字比正文还长，
	#   只会把消息列表挤得更难扫。（DossierData.sms_locked_count() 留着没删 ——
	#   它只在这里用过，但语义上是个正经查询，将来别处要用不必再写一遍。）
	_hint(_tf("messages.hint", [read, total],
		"（%d/%d 已读）读完短信，你才知道「B」该怎么说话。"),
		Color(0.55, 0.60, 0.68))

	# 列表顺序仍是「审问官 → 同行的人 → 朋友」：
	#  从最危险的那个开始，到唯一真正帮你的那个结束。
	# ★ 但**不再在每组上面写身份**（「与审问官」「与同行的人」那些字全删了）——
	#   每条短信自己的头像、联系人名和语气就够说明它来自谁了。

	# ---- 1 · 审问官本人 ----
	#  排在列表最上面：它不是「B 该怎么说话」，是「他已经注意到你了」。
	if not DossierData.interrogator_sms_list().is_empty():
		_intr_thread_row()

	# ---- 2 · 同行的人（C）----
	for t in DossierData.companion_sms_threads():
		_thread_row(t, "companion")

	# ---- 3 · 朋友 ----
	for t in friends:
		_thread_row(t, "friends")

func _read_count(arr: Array) -> int:
	var n := 0
	for t in arr:
		if GameData.sms_read.has(str((t as Dictionary).get("id", ""))):
			n += 1
	return n

## 一条普通短信线程（与 C / 与朋友共用）—— kind 只影响强调色。
func _thread_row(t: Dictionary, kind: String) -> void:
	var tid := str(t.get("id", ""))
	var msgs: Array = t.get("messages", [])
	var last: Dictionary = msgs[msgs.size() - 1] if msgs.size() > 0 else {}
	var is_read: bool = GameData.sms_read.has(tid)
	var accent: Color = GROUP_COLORS.get(kind, Color(0.55, 0.78, 0.98))

	var row := _card()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)

	var av := Label.new()
	av.text = str(t.get("avatar", "👤"))
	av.add_theme_font_size_override("font_size", 20)
	av.custom_minimum_size = Vector2(26, 0)
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(av)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var nm := Label.new()
	nm.text = str(t.get("contact", "?")) + ("" if is_read else "  ●")
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color",
		Color(0.92, 0.94, 0.98) if is_read else accent)
	vb.add_child(nm)

	var pv := Label.new()
	pv.text = str(last.get("text", ""))
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_theme_font_size_override("font_size", 10)
	pv.add_theme_color_override("font_color", Color(0.50, 0.54, 0.61))
	vb.add_child(pv)

	var b := Button.new()
	b.text = _t("messages.btn_read", "读")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 0)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(_open_thread.bind(tid))
	hb.add_child(b)

# 列表里那条「审讯官本人」的对话 —— 红框，一眼就能看出不对劲
func _intr_thread_row() -> void:
	var msgs: Array = DossierData.interrogator_sms_list()
	var row := _card()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)

	var av := Label.new()
	av.text = "🕶"
	av.add_theme_font_size_override("font_size", 20)
	av.custom_minimum_size = Vector2(26, 0)
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(av)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var nm := Label.new()
	nm.text = _tf("messages.interrogator_row",
		[DossierData.interrogator_name(), msgs.size()], "%s  ●  %d 条")
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", GROUP_COLORS["interrogator"])
	vb.add_child(nm)

	var pv := Label.new()
	pv.text = str(msgs[msgs.size() - 1]) if msgs.size() > 0 else ""
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_theme_font_size_override("font_size", 10)
	pv.add_theme_color_override("font_color", Color(0.72, 0.52, 0.50))
	vb.add_child(pv)

	var b := Button.new()
	b.text = _t("messages.btn_open", "看")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 0)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(_open_thread.bind(INTR_THREAD))
	hb.add_child(b)

func _open_thread(id: String) -> void:
	_open_sms = id
	if id == INTR_THREAD:
		rebuild()
		return

	# 先按「与朋友」找，找不到再按「与同行的人」找 ——
	# 两组共用同一套阅读/气泡渲染，只有「读完之后学到什么」不同。
	var t := DossierData.get_sms(id)
	var is_comp := false
	if t.is_empty():
		t = DossierData.get_companion_sms(id)
		is_comp = true
	if t.is_empty():
		rebuild()
		return

	var first_time: bool = not GameData.sms_read.has(id)
	if first_time:
		GameData.sms_read.append(id)
		# ★ 只有「与朋友」那一组揭示官方口径。
		#   C 的短信读了不涨知识 —— 他就是不给你口径。
		if not is_comp:
			for r in t.get("reveals", []):
				GameData.known_facts[str(r["fact"])] = str(r["value"])
	rebuild()
	if first_time:
		changed.emit()

func _build_thread_view() -> void:
	if _open_sms == INTR_THREAD:
		_build_interrogator_thread()
		return

	var t := DossierData.get_sms(_open_sms)
	var is_comp := false
	if t.is_empty():
		t = DossierData.get_companion_sms(_open_sms)
		is_comp = true
	if t.is_empty():
		_back_to_list()
		return

	_header(_tf("messages.thread_title", [str(t.get("contact", "?"))], "与 %s 的对话"), true)

	for msg in t.get("messages", []):
		var mine: bool = bool(msg.get("me", false))
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		screen_box.add_child(line)

		var sp_l := Control.new()
		sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sp_r := Control.new()
		sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.custom_minimum_size = Vector2(0, 0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.34, 0.24) if mine else Color(0.17, 0.18, 0.22)
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		bubble.add_theme_stylebox_override("panel", sb)

		var txt := Label.new()
		txt.text = str(msg.get("text", ""))
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_font_size_override("font_size", 11)
		txt.add_theme_color_override("font_color", Color(0.90, 0.93, 0.96))
		bubble.add_child(txt)

		if mine:
			line.add_child(sp_l)
			line.add_child(bubble)
			line.add_child(sp_r)
		else:
			line.add_child(sp_r)
			line.add_child(bubble)
			line.add_child(sp_l)

	# C 的短信到此为止 —— 没有「记进脑子」那一段，因为它本来就没给口径
	if is_comp:
		return

	# 读完提示
	var reveals: Array = t.get("reveals", [])
	if not reveals.is_empty():
		var note := ""
		for r in reveals:
			var fid := str(r["fact"])
			var f := DossierData.get_fact(fid)
			note += "· 「%s」→ %s\n" % [str(f.get("id", fid)), DossierData.fact_value_label(fid, str(r["value"]))]
		_hint(_t("messages.reveals_head", "你把这几条记进了脑子：\n") + note,
			Color(0.52, 0.80, 0.62))

# 审讯官本人的那条对话 —— 只有一条气泡列，全是「他发的」
func _build_interrogator_thread() -> void:
	_header(_tf("messages.thread_title", [DossierData.interrogator_name()], "与 %s 的对话"), true)

	for text in GameData.interrogator_sms:
		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.26, 0.13, 0.13)
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		bubble.add_theme_stylebox_override("panel", sb)

		var txt := Label.new()
		txt.text = str(text)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_font_size_override("font_size", 11)
		txt.add_theme_color_override("font_color", Color(0.96, 0.88, 0.86))
		bubble.add_child(txt)
		screen_box.add_child(bubble)

	_hint(_t("messages.interrogator_tail",
		"（每次你把手机掏出来看，这条线就会再长一句。）"), Color(0.62, 0.50, 0.48))

# ============================================================
#  App 2 · 相册
# ============================================================
func _build_album() -> void:
	title_label.text = _t("album.title", "相册")
	_ensure_photo_subs()

	var clear_n := 0
	for i in DossierData.photo_count():
		if clarity_of(i) >= ScenarioData.PHOTO_CLEAR_AT:
			clear_n += 1
	_hint(_tf("album.hint", [clear_n, DossierData.photo_count()],
		"（%d/%d 看清了）糊掉的部分擦不掉就永远看不清 —— 底片就那样。"),
		Color(0.55, 0.60, 0.68))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	screen_box.add_child(grid)

	for i in DossierData.photo_count():
		_make_photo_card(i, grid)

func _make_photo_card(i: int, grid: Node) -> void:
	var p := DossierData.get_photo(i)
	var slot := str(p.get("slot", ""))
	var clarity := clarity_of(i)
	var clear_enough: bool = clarity >= ScenarioData.PHOTO_CLEAR_AT
	var used := int(GameData.photo_wipes.get(i, 0))
	var maxw := int(p.get("max_wipes", 0))

	var vb := _card(grid)
	vb.add_theme_constant_override("separation", 4)

	var shot := Label.new()
	# ★ 第三十一轮：标题里带上「上半身 / 下半身」—— 明确告诉你这张记的是哪一半
	var half := str(p.get("half", ""))
	var shot_what := str(p.get("shot_slot", ""))
	if half != "":
		shot_what += " · " + half
	shot.text = _tf("album.shot", [shot_what], "偷拍 · %s")
	shot.add_theme_font_size_override("font_size", 10)
	shot.add_theme_color_override("font_color", Color(0.66, 0.70, 0.78))
	vb.add_child(shot)

	# ---- 照片本体 ----
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(PHOTO_VW, PHOTO_VH)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.20, 0.21, 0.24)
	fs.set_corner_radius_all(5)
	fs.set_border_width_all(1)
	fs.border_color = Color(0.30, 0.31, 0.36)
	frame.add_theme_stylebox_override("panel", fs)
	vb.add_child(frame)

	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if i < _photo_subs.size():
		tr.texture = (_photo_subs[i] as SubViewport).get_texture()
	if _photo_shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _photo_shader
		_apply_clarity(mat, clarity, i)
		tr.material = mat
	frame.add_child(tr)

	# ---- 清晰度 ----
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 9)
	bar.max_value = 100.0
	bar.value = clarity * 100.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.14)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fl := StyleBoxFlat.new()
	fl.bg_color = Color(0.36, 0.80, 0.55) if clear_enough else Color(0.88, 0.62, 0.24)
	fl.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fl)
	vb.add_child(bar)

	var note := Label.new()
	note.text = str(p.get("note", ""))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color(0.46, 0.50, 0.57))
	vb.add_child(note)

	if clear_enough:
		var it := OutfitData.get_item(RunData.true_item(slot))
		var got := Label.new()
		got.text = _tf("album.cleared",
			[OutfitData.SLOT_NAMES.get(slot, slot), it.get("name", "?")],
			"✓ 看清了 · %s →「%s」")
		got.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		got.add_theme_font_size_override("font_size", 10)
		got.add_theme_color_override("font_color", Color(0.48, 0.86, 0.64))
		vb.add_child(got)
	elif used >= maxw:
		var bad := Label.new()
		bad.text = _t("album.dead", "✗ 底片救不回来了")
		bad.add_theme_font_size_override("font_size", 10)
		bad.add_theme_color_override("font_color", Color(0.86, 0.46, 0.42))
		vb.add_child(bad)
	else:
		var b := Button.new()
		b.text = _tf("album.wipe", [maxw - used], "🧽 擦掉反光（还剩 %d 次）")
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_wipe.bind(i))
		vb.add_child(b)

func clarity_of(i: int) -> float:
	var p := DossierData.get_photo(i)
	if p.is_empty():
		return 0.0
	var used := int(GameData.photo_wipes.get(i, 0))
	return minf(1.0, float(p.get("start_clarity", 0.0))
		+ float(used) * ScenarioData.PHOTO_WIPE_STEP)

func _wipe(i: int) -> void:
	var p := DossierData.get_photo(i)
	if p.is_empty():
		return
	var used := int(GameData.photo_wipes.get(i, 0))
	if used >= int(p.get("max_wipes", 0)):
		return
	GameData.photo_wipes[i] = used + 1

	var c := clarity_of(i)
	if c >= ScenarioData.PHOTO_CLEAR_AT and not GameData.photos_revealed.has(i):
		GameData.photos_revealed.append(i)
		slot_revealed.emit(str(p.get("slot", "")))

	rebuild()
	changed.emit()

func _apply_clarity(mat: ShaderMaterial, c: float, i: int) -> void:
	mat.set_shader_parameter("blur", lerpf(9.0, 0.7, c))
	mat.set_shader_parameter("glare", lerpf(0.95, 0.04, c))
	mat.set_shader_parameter("wash", lerpf(0.50, 0.03, c))
	mat.set_shader_parameter("grain", lerpf(0.40, 0.06, c))
	mat.set_shader_parameter("glare_at",
		Vector2(0.20 + 0.30 * float(i % 3) * 0.5, 0.22 + 0.12 * float(i % 2)))

# ---- 照片的 SubViewport：把本局原貌的那一层渲染成一张「偷拍」 ----
func _ensure_photo_subs() -> void:
	var key := "%d-%d-%d" % [RunData.run_index, RunData.seed_value, RunData.photos.size()]
	if key == _photo_key and _photo_subs.size() == RunData.photos.size():
		return
	for s in _photo_subs:
		if is_instance_valid(s):
			s.queue_free()
	_photo_subs = []
	_photo_key = key
	for i in RunData.photos.size():
		_photo_subs.append(_make_photo_subviewport(i))

func _make_photo_subviewport(i: int) -> SubViewport:
	var p := RunData.photo_at(i)
	var slot := str(p.get("slot", ""))
	var focus := ScenarioData.photo_focus(slot)

	var sv := SubViewport.new()
	sv.size = Vector2i(PHOTO_VW, PHOTO_VH)
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	# 照片里是 DoL 的小人：基础层 + 这个部位的原貌层，一起按取景框裁进小视口。
	var scale := float(PHOTO_VW) / maxf(1.0, focus.size.x)
	var off := -focus.position * scale
	var full := DolDoll.frame_size() * scale

	var eq: Dictionary = {}
	var id := RunData.true_item(slot)
	if id != "":
		eq[slot] = id
	for L in DolDoll.plan(eq):
		var layer := TextureRect.new()
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.position = off
		layer.size = full
		layer.texture = DolDoll.tex(str(L["file"]))
		sv.add_child(layer)

	return sv

# ============================================================
#  App 3 · 备忘录（手记）
#
#  **第一条记的就是审问者**：这一局来问你的那个人是什么脾性、喜欢听什么、
#  最忌讳什么。篇幅刻意很短 —— 就是临出门前匆匆记下的几行字。
#  第二条是这一局的卡司速记。
#
#  ★ 第十三轮：**备忘录的内容整局不变**。
#    原来还有「【第三条】这一轮」（轮次名 / 本轮强制装备 / 反差要求）——
#    它每过一轮就变，掏出手机看到的字跟着跳，反而干扰「记着什么」这件事。
#    现在只留审问者与卡司两条 —— 一局之内一个字都不变，翻到第几次都一样。
# ============================================================
func _build_memo() -> void:
	title_label.text = _t("memo.title", "备忘录")
	_hint(_t("memo.hint",
		"手记。第一条是他 —— 这一局来问你的那个人。\n（盘问中途也能掏出来看，但别掏太多次。）"),
		Color(0.55, 0.60, 0.68))

	_build_memo_interrogator()
	_build_memo_cast()

# ---- 第一条 · 审问者本人 ----
func _build_memo_interrogator() -> void:
	var who := DossierData.interrogator_name()
	var t := DossierData.interrogator_trait()

	var card := _card()
	var head := Label.new()
	head.text = _tf("memo.head_interrogator", [who, DossierData.interrogator_gender()],
		"【第一条】%s（%s）")
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.96, 0.74, 0.46))
	card.add_child(head)

	var tn := Label.new()
	tn.text = _tf("memo.trait_line", [str(t.get("name", "")), str(t.get("tag", ""))],
		"性情 · %s（%s）")
	tn.add_theme_font_size_override("font_size", 11)
	tn.add_theme_color_override("font_color", Color(0.62, 0.78, 0.96))
	card.add_child(tn)

	var memo := Label.new()
	memo.text = DossierData.interrogator_memo()
	memo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memo.add_theme_font_size_override("font_size", 11)
	memo.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
	card.add_child(memo)

	var like := Label.new()
	like.text = _tf("memo.like_line", [DossierData.interrogator_like()], "喜好：%s")
	like.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	like.add_theme_font_size_override("font_size", 11)
	like.add_theme_color_override("font_color", Color(0.52, 0.84, 0.64))
	card.add_child(like)

	var hate := Label.new()
	hate.text = _tf("memo.hate_line", [DossierData.interrogator_hate()], "忌讳：%s")
	hate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hate.add_theme_font_size_override("font_size", 11)
	hate.add_theme_color_override("font_color", Color(0.94, 0.56, 0.50))
	card.add_child(hate)

	# 「该怎么答」—— 盲区题唯一的依据。
	# 盘问里他忽然问起一件档案里没有、短信里也没提的事时，
	# 你能用的就只有这一行。所以它不是装饰，是答案。
	var howto := Label.new()
	howto.text = _tf("memo.howto_line", [DossierData.interrogator_hint()], "该怎么答：%s")
	howto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	howto.add_theme_font_size_override("font_size", 11)
	howto.add_theme_color_override("font_color", Color(0.72, 0.80, 0.94))
	card.add_child(howto)

# ---- 第二条 · 本局卡司速记 ----
func _build_memo_cast() -> void:
	var c := DossierData.cast()

	var card := _card()
	var head := Label.new()
	head.text = _t("memo.head_cast", "【第二条】这一局的人")
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.96, 0.74, 0.46))
	card.add_child(head)

	var body := Label.new()
	body.text = _tf("memo.cast_body", [
		c["true_name"], c["player_gender"], c["true_role"],
		c["cover_role"],
		c["interrogator"], c["interrogator_gender"], c["trait"],
		c["companion"], c["companion_relation"], c["companion_gender"],
		c["true_name"]],
		("我（A 真身）：%s（%s）—— %s\n"
		+ "我装的（B 马甲）：%s\n"
		+ "问我的（审问者）：%s（%s·%s）—— 他认识 A\n"
		+ "同行者（C）：%s（%s·%s）—— 知道我是 A，不站我这边\n"
		+ "（「%s」这个名字，只有在被他认出来的时候才会被念出来。）"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
	card.add_child(body)

# ---- 第三条 · 本轮要点 ----
#  ★ 第十三轮删掉了这一条 —— 备忘录的内容现在整局不变。
#    留着函数体没意义，直接删干净（原来渲染的是轮次名 / 反差要求 / 强制装备）。

# ============================================================
#  App 4 · 备注（逐轮问答记录）
# ============================================================
#  用户口径：「备注界面第一轮为空 说明文字也不要
#            第二轮显示第一轮的问题和你的回答，第三轮记录前两次，以此类推」
#
#  所以这一页**不是**「官方口径 vs 我说过的话」的对照表，
#  而是一份**按轮次累积的问答记录**：
#     第 1 轮 → 空（连一句说明文字都不写）
#     第 2 轮 → 显示第 1 轮问过什么、你答了什么
#     第 3 轮 → 显示第 1、2 轮
#     …
#  当前轮的记录**当场不显示** —— 它要等下一轮才「归档」到这一页上。
# ============================================================
func _build_notes() -> void:
	title_label.text = _t("notes.title", "备注")

	var logs := _past_answers()
	if logs.is_empty():
		# 第一轮：整页空着。不写任何说明文字（用户明确要求）。
		return

	# 按轮次分组：最新的一轮排在最上面
	var by_level: Dictionary = {}
	for e in logs:
		var lv := int((e as Dictionary).get("level", 0))
		if not by_level.has(lv):
			by_level[lv] = []
		(by_level[lv] as Array).append(e)

	var keys: Array = by_level.keys()
	keys.sort()
	keys.reverse()

	for lv in keys:
		var head := Label.new()
		head.text = _tf("notes.head_round", [int(lv) + 1], "—— 第 %d 轮 ——")
		head.add_theme_font_size_override("font_size", 10)
		head.add_theme_color_override("font_color", Color(0.52, 0.58, 0.66))
		screen_box.add_child(head)

		for e in by_level[lv]:
			var ed: Dictionary = e
			var card := _card()

			var q := Label.new()
			q.text = _tf("notes.q_line", [str(ed.get("q", ""))], "他问：%s")
			q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			q.add_theme_font_size_override("font_size", 11)
			q.add_theme_color_override("font_color", Color(0.62, 0.74, 0.94))
			card.add_child(q)

			var a := Label.new()
			a.text = _tf("notes.a_line", [str(ed.get("answer", ""))], "我答：%s")
			a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			a.add_theme_font_size_override("font_size", 11)
			a.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
			card.add_child(a)

## 取出「当前轮之前」的问答记录（当前轮的要等下一轮才归档）。
func _past_answers() -> Array:
	var cur := RunData.level_index
	var out := []
	for e in GameData.answer_log:
		if int((e as Dictionary).get("level", -1)) < cur:
			out.append(e)
	return out

# ============================================================
#  小工具
# ============================================================
## 造一张卡片并「立刻挂到 parent 下」，返回卡片的**内容容器**。
## 调用方只管往返回值里塞子节点，不必再管外层 PanelContainer。
## parent 缺省为 screen_box；相册要挂到 GridContainer 时才显式传。
func _card(parent: Node = null) -> VBoxContainer:
	var host: Node = parent if parent != null else screen_box
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.19, 0.20, 0.25)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", sb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(body)
	host.add_child(panel)
	return body

func _hint(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	screen_box.add_child(l)
