class_name Widgets
extends RefCounted
## Small custom-drawn controls.


## Row of three stars.
class StarRow extends Control:
	var count := 0
	var star_size := 18.0

	func _init(n: int = 0, sz: float = 18.0) -> void:
		count = n
		star_size = sz
		custom_minimum_size = Vector2(sz * 2.4 * 3, sz * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step := size.x / 3.0
		for i in 3:
			UiKit.draw_star(self, Vector2(step * (i + 0.5), size.y * 0.5), star_size, i < count)


## One drawn star (fonts on web/mobile have no ★ glyph, so icons are drawn).
class StarIcon extends Control:
	var filled := true
	var r := 10.0

	func _init(is_filled: bool = true, radius: float = 10.0) -> void:
		filled = is_filled
		r = radius
		custom_minimum_size = Vector2(radius * 2.4, radius * 2.4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		UiKit.draw_star(self, size * 0.5, r, filled)


## Ink left as a small bar (lavender, turns red when low).
class InkBar extends Control:
	var frac := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(110, 7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fraction(f: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(GameColors.IVORY, 0.12))
		var col := GameColors.ACCENT if frac > 0.2 else GameColors.HEX.red
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)


## Collector progress: color symbol, five fill segments and "3/5".
class CollectorChip extends Control:
	var color_id := "blue"
	var count := 0
	var required := 5

	func _init() -> void:
		custom_minimum_size = Vector2(150, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(c: String, n: int, req: int) -> void:
		color_id = c
		count = n
		required = req
		queue_redraw()

	func _draw() -> void:
		draw_style_box(UiKit.box(GameColors.PANEL, 12), Rect2(Vector2.ZERO, size))
		var col := GameColors.of(color_id)
		var c := Vector2(22, size.y * 0.5)
		draw_circle(c, 13, col)
		GameColors.draw_symbol(self, color_id, c, 13, GameColors.BG)
		var x := 44.0
		for i in required:
			var r := Rect2(x + i * 13, size.y * 0.5 - 8, 10, 16)
			if i < count:
				draw_rect(r, col)
			else:
				draw_rect(r, Color(col, 0.22))
		var font := get_theme_default_font()
		draw_string(font, Vector2(x + required * 13 + 6, size.y * 0.5 + 8), "%d/%d" % [count, required],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GameColors.IVORY)


## Rawan Studio's heart-shaped ghost, holding a colour droplet.
class Ghost extends Control:
	var t := 0.0
	var happy := false
	var droplet := "blue"

	func _init(sz: float = 120.0) -> void:
		custom_minimum_size = Vector2(sz, sz * 1.1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		if int(t * 1.5) % 3 == 0:
			droplet = GameColors.IDS[int(t * 0.5) % 3]
		queue_redraw()

	func _draw() -> void:
		var reduced: bool = Save.get_setting("reduced_motion")
		var s: float = min(size.x, size.y / 1.1) / 100.0
		var bob := 0.0 if reduced else sin(t * (5.0 if happy else 2.2)) * (6.0 if happy else 3.0)
		var o := Vector2(size.x * 0.5, size.y * 0.5 + bob)
		var body := GameColors.ACCENT.lightened(0.25)
		# Heart-shaped head: two lobes over a ghost body with a wavy hem.
		var w := 36.0 * s
		draw_circle(o + Vector2(-18 * s, -16 * s), 18.6 * s, body)
		draw_circle(o + Vector2(18 * s, -16 * s), 18.6 * s, body)
		var pts := PackedVector2Array([o + Vector2(-w, -16 * s), o + Vector2(0, -12 * s), o + Vector2(w, -16 * s)])
		pts.append(o + Vector2(w, 30 * s))
		for i in 7:
			var x := w - (2.0 * w) * (i + 1) / 7.0
			var y := 38.0 * s if i % 2 == 0 else 30.0 * s
			if not reduced:
				y += sin(t * 6.0 + i) * 2.0 * s
			pts.append(o + Vector2(x, y))
		draw_colored_polygon(pts, body)
		var eye_y := -2.0 * s
		var blink := not reduced and fmod(t, 3.2) < 0.12
		for ex in [-13.0, 13.0]:
			var e := o + Vector2(ex * s, eye_y)
			if happy:
				draw_arc(e, 6 * s, PI * 1.1, PI * 1.9, 10, GameColors.BG, 3.0 * s, true)
			elif blink:
				draw_line(e - Vector2(5 * s, 0), e + Vector2(5 * s, 0), GameColors.BG, 3 * s)
			else:
				draw_circle(e, 5.5 * s, GameColors.BG)
				draw_circle(e + Vector2(-1.6, -1.8) * s, 1.8 * s, Color.WHITE)
		draw_circle(o + Vector2(-24 * s, 10 * s), 5 * s, Color(GameColors.HEX.red, 0.5))
		draw_circle(o + Vector2(24 * s, 10 * s), 5 * s, Color(GameColors.HEX.red, 0.5))
		draw_arc(o + Vector2(0, 8 * s), 6 * s, 0.2, PI - 0.2, 12, GameColors.BG, 2.5 * s, true)
		# droplet
		var dc := o + Vector2(44 * s, 6 * s)
		var dcol := GameColors.of(droplet)
		var drop := PackedVector2Array([dc + Vector2(0, -16 * s)])
		for i in 13:
			var a := -0.35 + (PI + 0.7) * i / 12.0
			drop.append(dc + Vector2(cos(a), sin(a)) * 9.0 * s)
		draw_colored_polygon(drop, dcol)
		GameColors.draw_symbol(self, droplet, dc, 8 * s, GameColors.BG)


## Rawan Studio heart-ghost artwork from the brand kit (assets/brand/mascot_*.png).
## The outer Control is what containers lay out; the inner image floats inside
## it, so the bob never disturbs layout. Pops in with an eased overshoot.
## Reduced motion: no float, no pop, just a short fade.
class Mascot extends Control:
	var t := 0.0
	var bob := 4.0
	var speed := 2.0
	var img: TextureRect

	func _init(pose: String = "welcome", height: float = 140.0) -> void:
		var tex: Texture2D = load("res://assets/brand/mascot_%s.png" % pose)
		var aspect := 1.0
		if tex != null:
			aspect = float(tex.get_width()) / max(1, tex.get_height())
		custom_minimum_size = Vector2(height * aspect, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		img = TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(img)

	func _ready() -> void:
		img.pivot_offset = size * 0.5
		resized.connect(func(): img.pivot_offset = size * 0.5)
		if Save.get_setting("reduced_motion"):
			img.modulate.a = 0.0
			create_tween().tween_property(img, "modulate:a", 1.0, 0.22)
		else:
			img.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(img, "scale", Vector2.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		t += delta
		if Save.get_setting("reduced_motion"):
			img.position.y = 0.0
			return
		img.position.y = sin(t * speed) * bob


## Title illustration: an ivory drawn rail; blue balls roll along it, touch a
## red pentagon (turning red, as in the game rules) and fill a red ring, which
## pops on every catch. Purely decorative; reduced motion shows a still frame.
class HeroRibbon extends Control:
	var t := 0.0
	var _count := 0
	var _pop := 9.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if Save.get_setting("reduced_motion"):
			return
		var before := int(t / 0.9)
		t += delta
		if int(t / 0.9) != before:
			_count = (_count + 1) % 6
			_pop = 0.0
		_pop += delta
		queue_redraw()

	func _pt(k: float) -> Vector2:
		# Cubic Bezier across the panel, in 0..1 local space.
		var p0 := Vector2(0.03, 0.80)
		var p1 := Vector2(0.30, 1.02)
		var p2 := Vector2(0.48, 0.62)
		var p3 := Vector2(0.74, 0.78)
		var u := 1.0 - k
		var q := u * u * u * p0 + 3 * u * u * k * p1 + 3 * u * k * k * p2 + k * k * k * p3
		return q * size

	func _draw() -> void:
		var sc: float = min(size.x, size.y) / 360.0
		var pts := PackedVector2Array()
		for i in 61:
			pts.append(_pt(i / 60.0))
		draw_polyline(pts, Color(GameColors.IVORY, 0.9), 9.0 * sc, true)
		draw_circle(pts[0], 4.5 * sc, Color(GameColors.IVORY, 0.9))
		# red painter pentagon just below the middle of the curve
		var pc := _pt(0.5) + Vector2(0, -40) * sc
		var pent := PackedVector2Array()
		for i in 5:
			var a := -PI / 2.0 + TAU * i / 5.0
			pent.append(pc + Vector2(cos(a), sin(a)) * 20.0 * sc)
		draw_colored_polygon(pent, GameColors.HEX.red)
		GameColors.draw_symbol(self, "red", pc, 14.0 * sc, GameColors.BG)
		# red collector ring at the end of the rail
		var rc := _pt(1.0) + Vector2(44, 10) * sc
		var k: float = clamp(_pop / 0.35, 0.0, 1.0)
		var pop := 0.0 if Save.get_setting("reduced_motion") else sin(k * PI) * (1.0 - k) * 1.6
		var rr := 30.0 * sc * (1.0 + 0.15 * pop)
		draw_circle(rc, rr, Color(GameColors.HEX.red, 0.12))
		for i in 5:
			var a0 := -PI / 2.0 + TAU * i / 5.0 + 0.08
			var a1 := -PI / 2.0 + TAU * (i + 1) / 5.0 - 0.08
			var filled := i < _count
			draw_arc(rc, rr + 4.0 * sc, a0, a1, 12, GameColors.HEX.red if filled else GameColors.HEX.red.darkened(0.62), 6.0 * sc, true)
		GameColors.draw_symbol(self, "red", rc, 14.0 * sc, GameColors.HEX.red)
		# balls travelling along the rail
		for j in 3:
			var kk := fmod(t * 0.38 + j / 3.0, 1.0)
			var col_id := "blue" if kk < 0.5 else "red"
			var bp := _pt(kk) + Vector2(0, -12) * sc
			draw_circle(bp, 9.0 * sc, GameColors.of(col_id))
			GameColors.draw_symbol(self, col_id, bp, 8.5 * sc, Color(GameColors.BG, 0.85))


## Animated heart-ghost made from the brand kit's single image (no layers):
## a grid mesh over the art is bent each frame (body breathing, arm wave,
## tails swaying) and blinks are drawn over the eyes. The silhouette, face and
## palette stay those of the master art; only gentle motion is added.
## Reduced motion: still image (with the usual short fade-in).
class MascotRig extends Control:
	const COLS := 18
	const ROWS := 16
	## Per-pose rig data in texture pixels (measured on the art).
	const RIGS := {
		"guide": {
			"eyes": [Rect2(213, 182, 49, 61), Rect2(373, 162, 46, 58)],
			"wave": {"pivot": Vector2(472, 300), "x0": 440.0, "x1": 495.0, "y0": 175.0, "y1": 215.0, "y2": 300.0, "y3": 335.0, "amp": 0.16, "speed": 5.0},
			"pen": {"pivot": Vector2(118, 330), "x0": 105.0, "x1": 150.0, "y0": 140.0, "y1": 180.0, "y2": 385.0, "y3": 405.0, "amp": 0.05, "speed": 3.4},
			"tail_y": 400.0, "base": Vector2(300, 525), "breath": 0.03, "speed": 2.2,
		},
		"victory": {
			"eyes": [],
			"tail_y": 300.0, "base": Vector2(210, 400), "breath": 0.06, "speed": 5.0,
		},
	}

	var tex: Texture2D
	var rig: Dictionary
	var poly: Polygon2D
	var lids: Control
	var rest := PackedVector2Array()
	var t := 0.0
	var _blink_t := 9.0
	var _next_blink := 1.6
	var _fit_scale := 1.0
	var _fit_off := Vector2.ZERO
	var _lid_colors: Array = []

	func _init(pose: String = "guide", height: float = 280.0) -> void:
		tex = load("res://assets/brand/mascot_%s.png" % pose)
		rig = RIGS.get(pose, RIGS.victory)
		var aspect := float(tex.get_width()) / maxf(1.0, tex.get_height())
		custom_minimum_size = Vector2(height * aspect, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		poly = Polygon2D.new()
		poly.texture = tex
		var W := float(tex.get_width())
		var H := float(tex.get_height())
		var uv := PackedVector2Array()
		for j in ROWS + 1:
			for i in COLS + 1:
				uv.append(Vector2(W * i / COLS, H * j / ROWS))
		rest = uv
		poly.uv = uv
		poly.polygon = uv
		var tris: Array = []
		for j in ROWS:
			for i in COLS:
				var a := j * (COLS + 1) + i
				var b := a + 1
				var c := a + COLS + 1
				var d := c + 1
				tris.append(PackedInt32Array([a, b, d]))
				tris.append(PackedInt32Array([a, d, c]))
		poly.polygons = tris
		add_child(poly)
		lids = Control.new()
		lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lids.set_anchors_preset(Control.PRESET_FULL_RECT)
		lids.draw.connect(_draw_lids)
		add_child(lids)
		# Lid colour = the art's own skin colour just around each eye.
		var img := tex.get_image()
		for e: Rect2 in rig.get("eyes", []):
			var acc := Color(0, 0, 0, 0)
			var samples := [Vector2(e.get_center().x, e.position.y - 6), Vector2(e.position.x - 6, e.get_center().y),
				Vector2(e.end.x + 6, e.get_center().y), Vector2(e.get_center().x, e.end.y + 5)]
			for q: Vector2 in samples:
				acc += img.get_pixelv(Vector2i(q))
			_lid_colors.append(Color(acc.r / 4.0, acc.g / 4.0, acc.b / 4.0, 1.0))

	func _ready() -> void:
		resized.connect(_fit)
		_fit()
		if Save.get_setting("reduced_motion"):
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, 0.22)
		else:
			pivot_offset = size * 0.5
			scale = Vector2(0.6, 0.6)
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _fit() -> void:
		var W := float(tex.get_width())
		var H := float(tex.get_height())
		_fit_scale = min(size.x / W, size.y / H)
		_fit_off = (size - Vector2(W, H) * _fit_scale) * 0.5
		poly.position = _fit_off
		poly.scale = Vector2(_fit_scale, _fit_scale)
		pivot_offset = size * 0.5

	static func _sm(a: float, b: float, x: float) -> float:
		return smoothstep(a, b, x) if a < b else 1.0 - smoothstep(b, a, x)

	func _limb(p: Vector2, l: Dictionary, right_side: bool) -> Vector2:
		var wx := smoothstep(l.x0, l.x1, p.x) if right_side else 1.0 - smoothstep(l.x0, l.x1, p.x)
		var wy := smoothstep(l.y0, l.y1, p.y) * (1.0 - smoothstep(l.y2, l.y3, p.y))
		var w := wx * wy
		if w <= 0.0:
			return p
		var ang: float = sin(t * l.speed) * l.amp * w
		return l.pivot + (p - l.pivot).rotated(ang)

	## Deformation of one point of the art (texture pixels -> texture pixels).
	func deform(p: Vector2) -> Vector2:
		var q := p
		if rig.has("wave"):
			q = _limb(q, rig.wave, true)
		if rig.has("pen"):
			q = _limb(q, rig.pen, false)
		var tail := smoothstep(rig.tail_y, rig.tail_y + 100.0, p.y)
		q.x += sin(t * 3.2 + p.x * 0.02) * 6.0 * tail
		var s: float = sin(t * rig.speed)
		var base: Vector2 = rig.base
		q.x = base.x + (q.x - base.x) * (1.0 - rig.breath * 0.8 * s)
		q.y = base.y + (q.y - base.y) * (1.0 + rig.breath * s)
		return q

	func _process(delta: float) -> void:
		if Save.get_setting("reduced_motion"):
			return
		t += delta
		var pts := PackedVector2Array()
		pts.resize(rest.size())
		for k in rest.size():
			pts[k] = deform(rest[k])
		poly.polygon = pts
		_blink_t += delta
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_t = 0.0
			_next_blink = randf_range(2.4, 4.2)
		lids.queue_redraw()

	## Blink: a lid in the art's skin colour closes over each eye (~140 ms),
	## leaving a soft curved line, like the kit's "happy" expression.
	func _draw_lids() -> void:
		if _blink_t > 0.14 or rig.eyes.is_empty():
			return
		var k := sin(_blink_t / 0.14 * PI)
		for idx in rig.eyes.size():
			var e: Rect2 = rig.eyes[idx]
			var c := deform(e.get_center())
			var rx := e.size.x * 0.64
			var ry := e.size.y * 0.64
			var pts := PackedVector2Array()
			for i in 28:
				var a := TAU * i / 28.0
				# Lid grows from the top edge of the eye downward.
				var y := c.y - ry + (sin(a) * 0.5 + 0.5) * ry * 2.0 * k
				pts.append(_fit_off + Vector2(c.x + cos(a) * rx, y) * _fit_scale)
			lids.draw_colored_polygon(pts, _lid_colors[idx])
			if k > 0.75:
				lids.draw_arc(_fit_off + (c + Vector2(0, -2)) * _fit_scale, e.size.x * 0.4 * _fit_scale, 0.35, PI - 0.35, 12,
					Color(0.2, 0.14, 0.22), 5.0 * _fit_scale, true)


## Game title for the main page: "Color" letters in the four ball colors and
## "Curves" in ivory (Arabic: "منحنيات" ivory, "الألوان" one color per letter
## group is avoided so letters still join). Underneath, a small drawn rail with
## painted segments and a ball that rolls along it and takes each color.
class GameTitle extends VBoxContainer:
	const LETTER_COLORS := ["red", "yellow", "green", "blue", "red"]

	func _init(size_px := 64) -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 0)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.add_theme_font_size_override("normal_font_size", size_px)
		rt.add_theme_constant_override("outline_size", 0)
		rt.text = "[center]" + markup() + "[/center]"
		add_child(rt)
		var rail := TitleRail.new()
		rail.custom_minimum_size = Vector2(size_px * 6.2, size_px * 0.42)
		rail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(rail)

	static func markup() -> String:
		var ivory := GameColors.IVORY.to_html(false)
		if I18n.lang == "ar":
			# Arabic letters must stay joined, so color whole words.
			return "[color=#%s]منحنيات[/color] [color=#%s]الألوان[/color]" % [ivory, GameColors.HEX.yellow.to_html(false)]
		var word := "Color"
		var out := ""
		for i in word.length():
			out += "[color=#%s]%s[/color]" % [GameColors.HEX[LETTER_COLORS[i]].to_html(false), word[i]]
		return out + " [color=#%s]Curves[/color]" % ivory


class TitleRail extends Control:
	var _t := 0.0
	const SEGMENTS := [[0.18, 0.28, "red"], [0.40, 0.50, "yellow"], [0.62, 0.72, "green"], [0.84, 0.94, "blue"]]

	func _process(delta: float) -> void:
		if not Save.get_setting("reduced_motion"):
			_t = fmod(_t + delta * 0.16, 1.0)
			queue_redraw()

	func _pt(u: float) -> Vector2:
		var w := size.x
		var h := size.y
		var x := 0.04 + 0.92 * u
		if I18n.is_rtl():
			x = 1.0 - x   # the ball rolls in the reading direction
		return Vector2(w * x, h * 0.55 + sin(u * TAU * 1.5) * h * 0.22)

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 61:
			pts.append(_pt(i / 60.0))
		draw_polyline(pts, Color(GameColors.IVORY, 0.55), 3.0, true)
		var col := GameColors.IVORY
		for s in SEGMENTS:
			var seg := PackedVector2Array()
			for i in 9:
				seg.append(_pt(lerpf(s[0], s[1], i / 8.0)))
			draw_polyline(seg, GameColors.of(s[2]), 5.0, true)
			if _t >= s[0]:
				col = GameColors.of(s[2])
		var u := _t if not Save.get_setting("reduced_motion") else 0.98
		var b := _pt(u) - Vector2(0, 8)
		draw_texture_rect(Art.soft_texture(), Rect2(b - Vector2(14, 14), Vector2(28, 28)), false, Color(col, 0.5))
		draw_texture_rect(Art.ball_texture(), Rect2(b - Vector2(7, 7), Vector2(14, 14)), false, col)


## Vertical list that scrolls when you swipe anywhere on it (finger or mouse),
## with a little momentum. Children keep their own taps; after a swipe,
## `dragged` stays true until the next press so a button released at the end
## of a swipe can ignore it.
class DragScroll extends ScrollContainer:
	const DRAG_START := 14.0     ## px of movement before a press becomes a swipe
	const FRICTION := 5.0        ## momentum decay per second
	const MAX_FLING := 3000.0    ## px per second
	var dragged := false
	var _down := false
	var _start := Vector2.ZERO
	var _last_y := 0.0
	var _scroll_at_start := 0.0
	var _velocity := 0.0
	var _last_t := 0

	func _init() -> void:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		set_process(false)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return   # hidden, or on a screen that is fading out
		var pressed_ev := event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		var motion_ev := event is InputEventMouseMotion
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			return   # touches also arrive as emulated mouse events
		if not pressed_ev and not motion_ev:
			return
		var local := (make_input_local(event) as InputEventMouse).position
		if pressed_ev:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				if Rect2(Vector2.ZERO, size).has_point(local):
					_down = true
					dragged = false
					_start = local
					_last_y = local.y
					_scroll_at_start = scroll_vertical
					_velocity = 0.0
					_last_t = Time.get_ticks_msec()
					set_process(false)
			elif _down:
				_down = false
				if dragged and absf(_velocity) > 60.0:
					set_process(true)
		elif _down:
			var dy := local.y - _start.y
			if not dragged and absf(dy) > DRAG_START:
				dragged = true
			if dragged:
				scroll_vertical = int(_scroll_at_start - dy)
				var now := Time.get_ticks_msec()
				var dt := maxf((now - _last_t) / 1000.0, 0.001)
				_velocity = clampf(lerpf(_velocity, (_last_y - local.y) / dt, 0.4), -MAX_FLING, MAX_FLING)
				_last_y = local.y
				_last_t = now

	## Stop any fling (used when the list is scrolled from code).
	func stop() -> void:
		_velocity = 0.0
		set_process(false)

	func _process(delta: float) -> void:
		scroll_vertical = int(scroll_vertical + _velocity * delta)
		_velocity *= maxf(0.0, 1.0 - FRICTION * delta)
		if absf(_velocity) < 20.0:
			set_process(false)


## v1.1 title screen backdrop: one long drawn line across the screen with
## colour pads on it; four balls keep rolling along it and take each pad's
## colour as they pass, like the game itself. Drawn in code, 30 fps menus.
class TitleWave extends Control:
	const PADS := [[0.14, 0.2, "red"], [0.36, 0.42, "yellow"], [0.58, 0.64, "green"], [0.80, 0.86, "blue"]]
	const BALLS := 4
	const SPEED := 0.055   ## curve lengths per second
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if Save.get_setting("reduced_motion"):
			return
		_t += delta
		queue_redraw()

	func _pt(u: float) -> Vector2:
		var x := -0.05 + 1.1 * u
		if I18n.is_rtl():
			x = 1.0 - x   # balls roll in the reading direction
		var y := 0.875 + sin(u * TAU * 1.25 + 0.6) * 0.035 + sin(u * TAU * 2.7) * 0.01
		return Vector2(size.x * x, size.y * y)

	func _color_at(u: float) -> Color:
		var col := GameColors.IVORY
		for p in PADS:
			if u >= p[0]:
				col = GameColors.of(p[2])
		return col

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 121:
			pts.append(_pt(i / 120.0))
		draw_polyline(Art._offset(pts, Vector2(2, 4)), Color(0, 0, 0, 0.25), 9.0, true)
		draw_polyline(pts, Color(GameColors.IVORY, 0.85), 7.0, true)
		draw_polyline(Art._offset(pts, Vector2(0, -1.5)), Color(1, 1, 1, 0.35), 1.5, true)
		for p in PADS:
			var seg := PackedVector2Array()
			for i in 13:
				seg.append(_pt(lerpf(p[0], p[1], i / 12.0)))
			draw_polyline(seg, GameColors.of(p[2]), 9.0, true)
		var still := bool(Save.get_setting("reduced_motion"))
		for k in BALLS:
			var u := fposmod((0.95 if still else _t * SPEED) + float(k) / BALLS, 1.0)
			# Short fading trail behind each ball.
			for j in range(6, 0, -1):
				var uj := u - j * 0.008
				if uj < 0.0:
					continue
				var tp := _pt(uj) - Vector2(0, 11)
				draw_circle(tp, 9.0 * (1.0 - j / 8.0), Color(_color_at(uj), 0.10 * (7 - j) / 6.0))
			var b := _pt(u) - Vector2(0, 11)
			var col := _color_at(u)
			draw_texture_rect(Art.soft_texture(), Rect2(b - Vector2(26, 26), Vector2(52, 52)), false, Color(col, 0.45))
			draw_texture_rect(Art.ball_texture(), Rect2(b - Vector2(11, 11), Vector2(22, 22)), false, col)


## Small "watch an ad" mark for buttons: a rounded tag with a play triangle
## (drawn, so it needs no font glyph).
class AdBadge extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(24, 18)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameColors.HEX.yellow
		sb.set_corner_radius_all(5)
		draw_style_box(sb, r)
		var c := r.get_center() + Vector2(1, 0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -5), c + Vector2(5, 0), c + Vector2(-4, 5)]), GameColors.BG)


## v1.2: row of hearts (drawn). A lost heart pops and empties.
class HeartRow extends Control:
	var count := 3
	var _pop := -1.0

	func _init(n: int = 3) -> void:
		count = n
		custom_minimum_size = Vector2(26.0 * HeartRules.MAX + 4.0, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_count(n: int, lost: bool) -> void:
		count = n
		if lost and not Save.get_setting("reduced_motion"):
			_pop = 0.0
			set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		_pop += delta
		if _pop > 0.4:
			_pop = -1.0
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		for i in HeartRules.MAX:
			var c := Vector2(15.0 + 26.0 * i, size.y * 0.5)
			var full := i < count
			var s := 9.0
			if i == count and _pop >= 0.0:
				s *= 1.0 + 0.5 * sin(_pop / 0.4 * PI)
			_heart(c, s, GameColors.HEX.red if full else Color(GameColors.IVORY, 0.16))

	func _heart(c: Vector2, s: float, col: Color) -> void:
		draw_circle(c + Vector2(-s * 0.5, -s * 0.3), s * 0.55, col)
		draw_circle(c + Vector2(s * 0.5, -s * 0.3), s * 0.55, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, -s * 0.05), c + Vector2(s * 1.02, -s * 0.05), c + Vector2(0, s * 1.05)]), col)
