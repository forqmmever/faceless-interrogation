class_name BodyPreview
extends Control

# ============================================================
#  表情 QTE 旁边的「换装下腹部」小图
#
#  用户口径（第六十三轮）：「第二阶段时，把换装的结果下腹部截图，
#  画出屁股的形状，最后在上面画一个张开五指的手，
#  并且随表情 QTE 一起出现和消失」。
#
#  这个 Control 只负责**画**（屁股轮廓 + 五指手）；底下的截图由
#  Interrogation 里的 SubViewport 铺好、TextureRect 显示，本节点叠在它上面。
#  颜色都带透明度，让下面的衣服 / 皮肤还能透出来。
# ============================================================

var butt_fill := Color(0.95, 0.58, 0.52, 0.16)
var butt_line := Color(0.96, 0.44, 0.41, 0.95)
var hand_fill := Color(0.97, 0.80, 0.70, 0.92)
var hand_line := Color(0.42, 0.24, 0.21, 0.96)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# 屁股轮廓在中间偏下；手盖在它上面，五指张开。
	var butt_center := Vector2(w * 0.5, h * 0.56)
	var butt_half := Vector2(w * 0.42, h * 0.36)
	_draw_butt(butt_center, butt_half)
	_draw_hand(Vector2(w * 0.5, h * 0.55), minf(w, h) / 232.0)

func _draw_butt(c: Vector2, half: Vector2) -> void:
	# 两瓣屁股的轮廓：左瓣外弧（上→下）+ 底部中点 + 右瓣外弧（下→上）+ 顶部凹口。
	var lc := c + Vector2(-half.x * 0.28, 0.0)
	var rc := c + Vector2(half.x * 0.28, 0.0)
	var rx := half.x * 0.55
	var ry := half.y * 0.92
	# 填充分成两瓣 + 底部一块（都是凸多边形，避免凹多边形三角化失败）。
	_fill_ellipse(lc, Vector2(rx, ry), butt_fill)
	_fill_ellipse(rc, Vector2(rx, ry), butt_fill)
	_fill_ellipse(c + Vector2(0.0, half.y * 0.20),
		Vector2(rx * 0.88, ry * 0.62), butt_fill)
	var pts := PackedVector2Array()
	for i in 24:
		var a := -PI * 0.5 + PI * float(i) / 23.0
		pts.append(lc + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(c + Vector2(0.0, half.y * 0.96))
	for i in 24:
		var a := PI * 0.5 + PI * float(i) / 23.0
		pts.append(rc + Vector2(cos(a) * rx, sin(a) * ry))
	# 顶部中间的凹口（两瓣之间的沟从这里开始）
	pts.append(c + Vector2(0.0, -half.y * 0.54))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, butt_line, 3.0, true)
	# 中间的沟：从凹口往下
	draw_line(c + Vector2(0.0, -half.y * 0.54), c + Vector2(0.0, half.y * 0.70),
		butt_line, 2.6, true)

func _fill_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)

func _draw_hand(c: Vector2, k: float) -> void:
	# k 以 232 宽的方框为基准；小屏 / 大屏按比例缩放。
	k = maxf(0.2, k)
	# 五指：拇指 / 食指 / 中指 / 无名指 / 小指（相对手掌中心，y 向下）。
	var fingers := [
		[Vector2(-24.0, 4.0), Vector2(-60.0, -14.0)],
		[Vector2(-11.0, -15.0), Vector2(-22.0, -64.0)],
		[Vector2(2.0, -19.0), Vector2(2.0, -76.0)],
		[Vector2(15.0, -16.0), Vector2(30.0, -63.0)],
		[Vector2(27.0, -7.0), Vector2(54.0, -42.0)],
	]
	# 先描一遍深色轮廓，再填肉色 —— 叠在截图上才看得清。
	for f in fingers:
		var a: Vector2 = c + (f[0] as Vector2) * k
		var b: Vector2 = c + (f[1] as Vector2) * k
		draw_line(a, b, hand_line, 17.0 * k, true)
		draw_circle(b, 8.5 * k, hand_line)
	draw_circle(c + Vector2(0.0, 10.0) * k, 34.0 * k, hand_line)
	for f in fingers:
		var a: Vector2 = c + (f[0] as Vector2) * k
		var b: Vector2 = c + (f[1] as Vector2) * k
		draw_line(a, b, hand_fill, 12.0 * k, true)
		draw_circle(b, 6.0 * k, hand_fill)
	draw_circle(c + Vector2(0.0, 10.0) * k, 31.0 * k, hand_fill)
	draw_arc(c + Vector2(0.0, 10.0) * k, 31.0 * k, 0.0, TAU, 40, hand_line, 2.0 * k, true)
	# 手腕：一条短横线，免得手像悬在半空
	draw_line(c + Vector2(-16.0, 34.0) * k, c + Vector2(16.0, 34.0) * k,
		hand_line, 2.0 * k, true)
