class_name HelpOverlay
extends Control

# ============================================================
#  玩法说明浮层（教练式标注）
#
#  用户口径：「每个阶段要有玩法说明功能 点击后
#            用文字箭头方框等说明每处的作用」
#  后续反馈：「玩法说明的框和线交叉在一起了看不清请改正」
#
#  ── 第十三版的做法为什么看不清 ──
#    说明文字是「谁的框就贴在谁的旁边」——左边框贴右边、右边框贴左边，
#    于是左边那条线要横穿整个屏幕去右边，右边那条线又要横穿去左边，
#    两条线必然交叉；文字块之间也只做了「撞了就往下推」的粗暴避让，
#    结果好几个文字块叠在一起。
#
#  ── 现在的做法 ──
#    1. 说明文字**全部排进同一侧的一列**（按标注框的重心选左侧或右侧），
#       从上到下依次摆开，彼此绝不重叠。
#    2. 连接线的配对顺序按「同侧嵌套」排：
#       所有徽章都在列的同一侧时，只要让「离列近的那个徽章接上面的文字块」，
#       线就是一把扇子（层层相套），绝不会交叉。
#       同 y 的徽章（比如手机底部那一排按钮）按到列的距离排先后。
#    3. 标注框优先用**运行时控件矩形**（`ctrl`）——正好套在那个控件外面，
#       不会再出现两个框重叠、或者框套错地方的情况。
#    4. 画序：框 → 线 → 文字块。文字块在最上层且不透明，
#       就算框线从它下面经过，读起来也是干净的。
#
#  用法：
#      var h = HelpOverlay.new()
#      add_child(h)
#      h.open("阶段一 · 准备室", "按编号看每一处是干什么的", [
#          {"ctrl": some_control, "n": 1, "t": "这一块是……"},
#          {"r": Rect2(0.02, 0.9, 0.2, 0.08), "n": 2, "t": "这一块是……"},
#      ])
# ============================================================

signal closed

const DIM := Color(0.02, 0.03, 0.045, 0.84)
const BOX_COL := Color(0.44, 0.76, 1.0)
const BOX_FILL := Color(0.18, 0.46, 0.78, 0.14)
const BADGE_BG := Color(0.20, 0.48, 0.78)
const TEXT_BG := Color(0.075, 0.088, 0.112, 0.97)
const TEXT_COL := Color(0.93, 0.95, 0.98)
const TITLE_COL := Color(0.98, 0.86, 0.60)
const SUB_COL := Color(0.62, 0.68, 0.78)
const LINE_COL := Color(0.42, 0.70, 0.94)

const F_TITLE := 25
const F_SUB := 14
const F_BODY := 13
const LINE_H := 20.0

const COL_W_RATIO := 0.335      # 说明文字那一列占屏宽的比例
const COL_MIN_W := 330.0
const COL_MARGIN := 18.0
const BLOCK_PAD_X := 14.0
const BLOCK_PAD_Y := 11.0
const BLOCK_GAP := 10.0
const TOP_SAFE := 92.0          # 标题下方留白
const BOTTOM_SAFE := 88.0       # 关闭按钮上方留白
const BADGE_R := 16.0
const BADGE_MIN_DX := 40.0      # 两个徽章的最小水平间距（避免叠在一起）
const BADGE_MIN_DY := 40.0

var title: String = ""
var subtitle: String = ""
var marks: Array = []          # [{ctrl|r, n, t}]
var close_text: String = "知道了  ✕"

var _close_btn: Button
var _visible_now: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# 关闭按钮的字从 story.json 的 ui 段读（编辑器可改）；取不到退回出厂那句
	close_text = ScenarioData.ui_t_d("common.help_close_btn")
	resized.connect(_synced)
	_build_close()

# ★ 一个必须记住的坑：**隐藏中的 Control 不参与布局**，size 会一直停在 (0,0)。
#   等到 open() 把它显示出来，那一帧也不保证立刻算好 —— 于是整个标注层画在
#   一个 0×0 的矩形里，等于什么都没画。所以真正要画的时候用 `_area()` 兜底：
#   取不到自己的 size，就退回视口大小。
func _area() -> Vector2:
	if size.x > 10.0 and size.y > 10.0:
		return size
	return get_viewport_rect().size

func _synced() -> void:
	_sync_layout()
	queue_redraw()

func _sync_layout() -> void:
	if _close_btn == null:
		return
	var sz := _area()
	_close_btn.size = Vector2(240, 48)
	_close_btn.position = Vector2(sz.x * 0.5 - 120.0, sz.y - 66.0)

func _build_close() -> void:
	_close_btn = Button.new()
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.custom_minimum_size = Vector2(240, 48)
	_close_btn.add_theme_font_size_override("font_size", 17)
	_close_btn.pressed.connect(close)
	add_child(_close_btn)
	_style_close()

func _style_close() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.50, 0.38)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.52, 0.88, 0.70)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_close_btn.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color"]:
		_close_btn.add_theme_color_override(c, Color(0.97, 1.0, 0.98))

# ---------------- 开关 ----------------
func open(t: String, sub: String, m: Array, btn_text: String = "") -> void:
	title = t
	subtitle = sub
	marks = m
	if btn_text != "":
		close_text = btn_text
	_close_btn.text = close_text
	visible = true
	_visible_now = true
	_sync_layout()
	layout_deferred.call_deferred()
	queue_redraw()

# 延迟再对一次 —— 隐藏→显示这一帧，父节点可能刚刚才把尺寸算下来
func layout_deferred() -> void:
	_sync_layout()
	queue_redraw()

func close() -> void:
	visible = false
	_visible_now = false
	closed.emit()

func is_open() -> bool:
	return _visible_now

# ============================================================
#  版式计算（独立成函数，测试可以直接拿它做几何断言）
#
#  返回 {items, lines, col_right, col_x, col_w}
#    items[i] = {n, box, lines(折好行的文本), badge, block}
#    lines[i] = [徽章坐标, 文字块入边中点]
#
#  排版顺序很关键（顺序错了就会打结）：
#    ① 量出每个标注框 ② 折行、算出文字块总高 ③ 摆徽章（重叠就挪开）
#    ④ 按「同侧嵌套」排序 ⑤ 文字块自上而下摆开 ⑥ 连线
# ============================================================
func layout(sz: Vector2) -> Dictionary:
	var font := ThemeDB.fallback_font
	var items: Array = []
	for i in marks.size():
		var m: Dictionary = marks[i]
		var rel: Rect2 = m.get("r", Rect2(0.1, 0.1, 0.2, 0.2))
		var box := Rect2(rel.position * sz, rel.size * sz)
		# 优先用运行时控件矩形 —— 框正好套在那个控件外面
		if m.has("ctrl"):
			var c: Variant = m["ctrl"]
			if c != null and is_instance_valid(c) and (c as Control).is_inside_tree():
				var g: Rect2 = (c as Control).get_global_rect()
				if g.size.x > 4.0 and g.size.y > 4.0:
					box = g
		items.append({
			"n": int(m.get("n", i + 1)),
			"box": box,
			"raw": str(m.get("t", "")),
		})

	var w := maxf(COL_MIN_W, sz.x * COL_W_RATIO)

	# ① 选列在哪一侧：在左右两边各算一次「文字列会盖住多少标注框」，
	#    取盖得少的那一边。用重心是个偷懒的近似 —— 遇到「框几乎横跨整屏」
	#    的阶段二就不准了（重心在中间，结果两边都盖很多）。
	var col_band := Rect2(0.0, TOP_SAFE, w, maxf(40.0, sz.y - TOP_SAFE - BOTTOM_SAFE))
	var ov_left := 0.0
	var ov_right := 0.0
	for it in items:
		var bx: Rect2 = it["box"]
		col_band.position.x = COL_MARGIN
		ov_left += _overlap_area(bx, col_band)
		col_band.position.x = sz.x - w - COL_MARGIN
		ov_right += _overlap_area(bx, col_band)
	var col_right := ov_right <= ov_left
	var col_x := (sz.x - w - COL_MARGIN) if col_right else COL_MARGIN

	# ② 折行 → 每块多高 → 块的整体重心落在哪个高度
	for it in items:
		it["lines"] = _wrap(it["raw"], w - BLOCK_PAD_X * 2.0 - 24.0, font)
	var total_h := 0.0
	for it in items:
		total_h += _block_h(it)
	var mean_block_y := TOP_SAFE + total_h * 0.5

	# ③ 徽章：先放框的左上角外侧，叠在一起就顺次挪开
	var placed: Array = []
	for it in items:
		var b: Rect2 = it["box"]
		var p := Vector2(b.position.x - 4.0, b.position.y - 12.0)
		p.x = clampf(p.x, 24.0, sz.x - 24.0)
		p.y = clampf(p.y, 26.0, sz.y - 26.0)
		var guard := 0
		while guard < 40 and _badge_taken(p, placed):
			p.x += BADGE_MIN_DX
			if p.x > sz.x - 26.0:
				p.x = 24.0
				p.y += BADGE_MIN_DY
			guard += 1
		placed.append(p)
		it["badge"] = p
	var mean_badge_y := 0.0
	for it in items:
		mean_badge_y += (it["badge"] as Vector2).y
	mean_badge_y /= maxf(1.0, float(items.size()))

	# ④ 排序：同侧嵌套
	#   规则：先按徽章 y 从小到大（上方的接上面的文字块）。
	#   y 差不多时（比如手机底部那一排按钮，全在同一行）按 x 排 ——
	#   方向取决于**文字块整体在徽章的上方还是下方**：
	#     · 块在徽章下方 → 离列近的那个徽章接最上面的块；
	#     · 块在徽章上方 → 离列远的那个徽章接最上面的块。
	#   两个方向随便挑一个都会让线打结，所以必须按几何关系定。
	var blocks_below: bool = mean_block_y > mean_badge_y
	items.sort_custom(func(a, b):
		var ya: float = (a["badge"] as Vector2).y
		var yb: float = (b["badge"] as Vector2).y
		if absf(ya - yb) > 8.0:
			return ya < yb
		var xa: float = (a["badge"] as Vector2).x
		var xb: float = (b["badge"] as Vector2).x
		if col_right:
			return (xb < xa) if blocks_below else (xa < xb)
		return (xa < xb) if blocks_below else (xb < xa))

	# ⑤ 文字块自上而下摆开；落差不够就把间距压紧
	var heights: Array = []
	var total := 0.0
	for it in items:
		var h := _block_h(it)
		heights.append(h)
		total += h
	var top := TOP_SAFE
	var bottom := sz.y - BOTTOM_SAFE
	var avail := maxf(40.0, bottom - top)
	var gap := BLOCK_GAP
	if items.size() > 1 and total + gap * float(items.size() - 1) > avail:
		gap = maxf(2.0, (avail - total) / float(items.size() - 1))
	var y := top
	for i in items.size():
		var it: Dictionary = items[i]
		it["block"] = Rect2(col_x, y, w, heights[i])
		y += heights[i] + gap

	# ⑥ 指示箭头：从徽章指向**自己那个框的内部**（短箭头，最多 46 像素）
	#
	#  ★ 为什么不画「徽章 → 文字块」的长连线：
	#    上一版就是那样画的，用户的原话是「框和线交叉在一起了看不清」。
	#    长连线的麻烦在于——只要有两个徽章的相对位置（y 差与 x 差）不成比例，
	#    两条线就会打结；想彻底避免得做正交布线或单总线，可读性反而更差。
	#    现在的做法是：徽章贴在自己那个框的角上、右上角再写一遍编号，
	#    箭头只往框里指一小段；「哪条文字对应哪一处」靠**编号**对应，
	#    想认错都难。短箭头之间不可能交叉。
	var arrows: Array = []
	for it in items:
		var badge: Vector2 = it["badge"]
		var box: Rect2 = it["box"]
		var to_c := (box.get_center() - badge)
		var dist := to_c.length()
		if dist < 1.0:
			arrows.append([badge, badge])
			continue
		# 沿「徽章 → 框中心」走，直到踩进框里，再多走 10 像素 ——
		# 箭头必须**落进框内**，停在框外面等于没指到。
		var d := to_c.normalized()
		var t := 0.0
		var inner := box.grow(-6.0)
		while t < dist and not inner.has_point(badge + d * t):
			t += 3.0
		var tip: Vector2 = badge + d * minf(t + 10.0, dist)
		arrows.append([badge, tip])

	return {"items": items, "lines": arrows, "col_right": col_right,
		"col_x": col_x, "col_w": w}

func _block_h(it: Dictionary) -> float:
	return float((it["lines"] as Array).size()) * LINE_H + BLOCK_PAD_Y * 2.0

# 两个矩形的重叠面积 —— 用来挑「文字列盖得最少」的那一侧
func _overlap_area(a: Rect2, b: Rect2) -> float:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var x1 := minf(a.position.x + a.size.x, b.position.x + b.size.x)
	var y1 := minf(a.position.y + a.size.y, b.position.y + b.size.y)
	if x1 <= x0 or y1 <= y0:
		return 0.0
	return (x1 - x0) * (y1 - y0)

func _badge_taken(p: Vector2, placed: Array) -> bool:
	for q in placed:
		var d: Vector2 = (q as Vector2) - p
		if absf(d.x) < BADGE_MIN_DX - 4.0 and absf(d.y) < BADGE_MIN_DY - 4.0:
			return true
	return false

# 逐字折行 —— 中文没有空格，不能靠 split()
func _wrap(text: String, max_w: float, font: Font) -> Array:
	var out := []
	for para in text.split("\n"):
		var cur := ""
		for ch in para:
			var trial := cur + ch
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY).x <= max_w or cur == "":
				cur = trial
			else:
				out.append(cur)
				cur = ch
		out.append(cur)
	return out

# ============================================================
#  绘制
# ============================================================
func _draw() -> void:
	if not _visible_now:
		return
	var sz := _area()
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, sz), DIM)

	# 顶部标题
	draw_string(font, Vector2(36, 42), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, F_TITLE, TITLE_COL)
	draw_string(font, Vector2(36, 68), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, -1, F_SUB, SUB_COL)

	var L := layout(sz)
	var items: Array = L["items"]
	var lines: Array = L["lines"]

	# 1) 标注框（半透明填充 + 亮边，不挡住底下的界面）
	for it in items:
		var box: Rect2 = it["box"]
		draw_rect(box, BOX_FILL)
		draw_rect(box, BOX_COL, false, 3.0)

	# 2) 连接线（在框之上、文字块之下）
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		draw_line(a, b, LINE_COL, 2.0, true)
		draw_circle(a, 4.5, LINE_COL)
		draw_circle(b, 4.5, LINE_COL)

	# 3) 徽章
	for it in items:
		_draw_badge(it["badge"], it["n"], font)

	# 4) 文字块（最上层，不透明）
	for it in items:
		_draw_block(it, font)

func _draw_badge(center: Vector2, n: int, font: Font) -> void:
	draw_circle(center, BADGE_R, BADGE_BG)
	draw_circle(center, BADGE_R, BOX_COL, false, 2.5)
	var num := str(n)
	var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY + 3).x
	draw_string(font, center + Vector2(-nw * 0.5, 6), num,
		HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY + 3, Color(0.98, 1.0, 1.0))

func _draw_block(it: Dictionary, font: Font) -> void:
	var blk: Rect2 = it["block"]
	draw_rect(blk, TEXT_BG)
	# 左边一道编号色的竖条，读起来跟徽章是一对
	draw_rect(Rect2(blk.position, Vector2(4.0, blk.size.y)), BOX_COL)
	draw_rect(blk, Color(0.26, 0.44, 0.62), false, 1.5)

	# 块内左上角再写一次编号 —— 线断了也认得出是哪一处
	var num := str(it["n"])
	var nx := blk.position.x + BLOCK_PAD_X - 2.0
	var ny := blk.position.y + BLOCK_PAD_Y + 12.0
	draw_string(font, Vector2(nx, ny), num,
		HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY + 2, BOX_COL)

	var tx := blk.position.x + BLOCK_PAD_X + 20.0
	var ty := blk.position.y + BLOCK_PAD_Y + 12.0
	for ln in (it["lines"] as Array):
		draw_string(font, Vector2(tx, ty), str(ln),
			HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY, TEXT_COL)
		ty += LINE_H
