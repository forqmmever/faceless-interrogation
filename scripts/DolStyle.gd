class_name DolStyle
extends RefCounted

# ============================================================
#  DoL 风格层（Degrees of Lewdity 的换装 / 数值表现语言）
#
#  用户口径：「参考 E:\DOWNLOAD\Degrees of Lewdity 下的换装系统的样式，
#            将本游戏的系统替换那样的；暴露值等数值的表现方式也参考相应的样式」
#
#  参照物的原样是这样的（摘自 DoL 0.5.12 的样式表与控件模板）：
#
#    · 衣物在商店 / 衣柜里是**卡片**（.clothing-item）：
#        inline-flex、宽 49%、1px 实线边框、cursor:pointer；
#        悬停时背景换成 var(--850)（更深/更亮一层）。
#        卡片内容＝缩略图 + 名称 + 三行数值 + 一枚斜着的价签。
#    · 数值的表示方式是 **7 颗小圆点**（.stats-ball：5×5、圆形、1px 描边）：
#        点亮的颗数＝量级，颜色＝档位。三行分别是
#        I.（integrity 耐久）、R.（reveal 暴露）、W.（warmth 保暖）。
#        每行前面挂一个 19×12 的小图标，或者退化成两个字母 "I." / "R." / "W."。
#    · 档位是从数值硬切出来的 7 档，颜色取自已命名的色阶：
#        暴露 R. 越低越好 → 绿、青、浅蓝、蓝、紫、粉、红
#        耐久 I. 越低越糟 → 红、粉、紫、蓝、浅蓝、青、绿
#        保暖 W. 是连续的 → 蓝 → 柠檬 → 红的插值
#        悬停另给一行精确读数，如 `Clothing exposure: 850`，数字自身也染色。
#    · 连续量还有一条**渐变刻度条**（.warmth-scale-div：10px 高、圆角、
#        背景是 linear-gradient(dodgerblue, lemonchiffon, red)），
#        上面压一个**箭头指针**（.warmth-indicator）指出当前值。
#
#  本文件把上面这套语言原样搬过来：
#    · 色板直接取 DoL 的主题变量值（--green #38b20a 等）。
#    · 三条 7 档色阶：暴露 / 反差 / 接受度需求。
#    · Pips —— 7 颗小圆点。
#    · Scale —— 渐变刻度条 + 指针 + 阈值刻线。
#    · card_style() —— 卡片的三态边框（普通 / 已装备 / 强制）。
#
#  为什么会「换一套表现方式」是值得的：
#    原来数值是 RichTextLabel 里一串「【暴露值】12 / 22」——
#    能读懂，但**没法比较**。7 颗点不一样：一两件衣服摆在一起，
#    哪件更扎眼是眼睛扫过去就知道的，不用先把数字念一遍再心算。
# ============================================================

# ---------------- 色板（= DoL 的主题变量原值）----------------
const RED := Color("ec3535")
const PINK := Color("e40081")
const PURPLE := Color("aa4bc8")
const BLUE := Color("4372ff")
const LBLUE := Color("559bc0")
const TEAL := Color("08c1c1")
const GREEN := Color("38b20a")
const ORANGE := Color("f28500")
const YELLOW := Color("ffd700")
const GREY := Color("8a8f99")
const SILVER := Color("c0c0c0")

# ---------------- 卡片的底色与描边（照 DoL 的 --900 / --850 / --300）----------
const CARD_BG := Color("14161b")
const CARD_BG_HOVER := Color("22242a")
const CARD_BG_DIM := Color("101216")
const CARD_BORDER := Color("3a3f46")
const CARD_BORDER_HOVER := Color("5a5f68")
const CARD_BORDER_DIM := Color("262a30")
const PANEL_BG := Color("0f1116")
const TRACK_BG := Color("2a2e35")
const DOT_RING := Color("4a5058")
const TAG_BG := Color("3f434a")
const TAG_TEXT := Color("14161b")

# ---------------- 三条色阶（各 7 档，对应 7 颗点）----------------
#  暴露值：越高越危险 → 绿 → 红（照 DoL 的 reveal 色阶）
const RAMP_EXPOSE: Array = [GREEN, TEAL, LBLUE, BLUE, PURPLE, PINK, RED]
#  反差值：越高越安全 → 把上一条翻过来用（红 → 绿）
const RAMP_CONTRAST: Array = [RED, PINK, PURPLE, BLUE, LBLUE, TEAL, GREEN]
#  接受度需求：越高越贵 → 灰 → 金（DoL 里金色是「贵重 / 买得起」的颜色）
const RAMP_DEMAND: Array = [
	Color("666b73"), Color("7c828a"), Color("8f8a72"),
	Color("a2915c"), Color("b8a057"), Color("d0b050"), YELLOW,
]

const PIP_COUNT := 7

# 把「值 / 上限」切成 0 ~ 7 档 —— DoL 的 getRevealInfo() 是硬切阈值，
# 这里用比例切：两边的语义一样（点亮几颗 = 量级，颜色 = 档位），
# 但不用为每条数值各写一张阈值表。
static func level_of(value: float, max_value: float, count: int = PIP_COUNT) -> int:
	if value <= 0.0 or max_value <= 0.0:
		return 0
	var ratio := clampf(value / max_value, 0.0, 1.0)
	return clampi(int(ceil(ratio * float(count))), 1, count)

static func ramp_color(ramp: Array, level: int) -> Color:
	if level <= 0 or ramp.is_empty():
		return Color(0, 0, 0, 0)
	return ramp[clampi(level - 1, 0, ramp.size() - 1)]

# 数值本身的染色（DoL 的 tooltip 里 `<i class="red normal">850</i>` 就是这个）
static func value_color(ramp: Array, value: float, max_value: float) -> Color:
	return ramp_color(ramp, level_of(value, max_value))

# ---------------- 卡片样式 ----------------
#  state: "normal" | "hover" | "equipped" | "forced" | "dim" | "locked"
#  DoL 的卡片是「1px 实线 + 悬停换底色」，三态靠边框颜色区分：
#    已装备 → 绿框；本关强制 → 橙框；还没解锁 → 灰到几乎看不见。
static func card_style(state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	match state:
		"hover":
			sb.bg_color = CARD_BG_HOVER
			sb.border_color = CARD_BORDER_HOVER
		"equipped":
			sb.bg_color = Color("12211a")
			sb.border_color = GREEN
		"forced":
			sb.bg_color = Color("2a1a10")
			sb.border_color = ORANGE
		"dim":
			sb.bg_color = CARD_BG
			sb.border_color = CARD_BORDER_DIM
		"locked":
			sb.bg_color = CARD_BG_DIM
			sb.border_color = CARD_BORDER_DIM
	return sb

static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = CARD_BORDER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb

# ============================================================
#  Pips —— 7 颗小圆点（DoL 的 .stats-ball）
#
#  点亮的颗数 = 量级，颜色 = 该档的色阶色；没点亮的只留一圈细描边。
#  尺寸照 DoL：点直径 5~6、间距 9（DoL 是 margin-right:-3px 把小点挤在一起，
#  那样点会互相咬住；这里留了 3px 间隙，扫一眼数得清）。
# ============================================================
class Pips extends Control:
	const DOT := 6.0
	const PITCH := 9.0

	var value: float = 0.0
	var max_value: float = 10.0
	var ramp: Array = []
	var note: String = ""              # 悬停提示（DoL 的 @tooltip）

	func _init(v: float = 0.0, mx: float = 10.0, rp: Array = [], tip: String = "") -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(PITCH * (DolStyle.PIP_COUNT - 1) + DOT, DOT + 2.0)
		setup(v, mx, rp, tip)

	func setup(v: float, mx: float, rp: Array, tip: String = "") -> void:
		value = v
		max_value = mx
		ramp = rp
		note = tip
		if tip != "":
			tooltip_text = tip
		queue_redraw()

	func _draw() -> void:
		var lvl := DolStyle.level_of(value, max_value, DolStyle.PIP_COUNT)
		var col := DolStyle.ramp_color(ramp, lvl)
		var cy := size.y * 0.5
		for i in DolStyle.PIP_COUNT:
			var c := Vector2(DOT * 0.5 + float(i) * PITCH, cy)
			if i < lvl:
				draw_circle(c, DOT * 0.5, col)
			else:
				draw_arc(c, DOT * 0.5, 0.0, TAU, 14, DolStyle.DOT_RING, 1.0, true)

# ============================================================
#  Scale —— 渐变刻度条 + 指针 + 阈值刻线（DoL 的 .warmth-scale-div / -indicator）
#
#  DoL 那条是固定的 蓝→柠檬→红 渐变，指针指出当前值；
#  这里渐变用各数值自己的色阶，另外多画一条**阈值刻线**：
#    暴露值 → 上限；反差值 → 本关要求。跨没跨过去，看刻线左右就知道。
# ============================================================
class Scale extends Control:
	const ARROW_H := 9.0
	const BAR_H := 10.0

	var value: float = 0.0
	var max_value: float = 10.0
	var warn_at: float = -1.0          # <0 表示不画阈值刻线
	var ramp: Array = []
	var _tex: GradientTexture2D

	func _init(v: float = 0.0, mx: float = 10.0, rp: Array = [], warn: float = -1.0,
			tip: String = "") -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(0, ARROW_H + 3.0 + BAR_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		setup(v, mx, rp, warn, tip)

	func setup(v: float, mx: float, rp: Array, warn: float = -1.0, tip: String = "") -> void:
		value = v
		max_value = maxf(0.001, mx)
		ramp = rp
		warn_at = warn
		if tip != "":
			tooltip_text = tip
		_rebuild()
		queue_redraw()

	func _rebuild() -> void:
		if ramp.is_empty():
			return
		var g := Gradient.new()
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		var n := ramp.size()
		for i in n:
			offs.append(float(i) / float(maxi(1, n - 1)))
			cols.append(ramp[i])
		g.offsets = offs
		g.colors = cols
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.width = maxi(2, int(size.x))
		_tex.height = int(BAR_H)
		_tex.fill_from = Vector2(0.0, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_rebuild()

	func _x_of(v: float) -> float:
		return clampf(v / max_value, 0.0, 1.0) * (size.x - 8.0) + 4.0

	func _draw() -> void:
		var track := Rect2(0.0, ARROW_H + 3.0, size.x, BAR_H)
		draw_rect(track, DolStyle.TRACK_BG, true)
		if _tex != null:
			_tex.width = maxi(2, int(size.x))
			draw_texture_rect(_tex, track, false)

		# 阈值刻线：暴露上限 / 反差要求
		if warn_at > 0.0:
			var wx := _x_of(warn_at)
			draw_line(Vector2(wx, track.position.y - 3.0),
				Vector2(wx, track.position.y + BAR_H + 3.0), DolStyle.ORANGE, 2.0)

		# 指针（DoL 的 warmth-indicator 就是一个小箭头压在条上）
		var px := _x_of(value)
		var col := DolStyle.value_color(ramp, value, max_value)
		draw_colored_polygon(PackedVector2Array([
			Vector2(px - 5.0, ARROW_H - 1.0),
			Vector2(px + 5.0, ARROW_H - 1.0),
			Vector2(px, ARROW_H + 2.0),
		]), col)
		draw_line(Vector2(px, ARROW_H + 2.0),
			Vector2(px, track.position.y + BAR_H), col, 2.0)
