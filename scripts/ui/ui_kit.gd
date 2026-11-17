class_name UiKit
extends RefCounted
## Theme and small widget helpers shared by every screen.

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	# Brand typography: Nunito Sans (Latin, from the studio kit) + Tajawal (Arabic),
	# with Noto Sans Arabic as a safety fallback for rare glyphs.
	var latin: FontFile = load("res://assets/fonts/NunitoSans-800.ttf")
	var arabic: FontFile = load("res://assets/fonts/Tajawal-ExtraBold.woff2")
	var arabic_fallback: FontFile = load("res://assets/fonts/NotoSansArabic-Bold.woff2")
	var font := FontVariation.new()
	font.base_font = latin
	latin.fallbacks = [arabic, arabic_fallback]
	t.default_font = font
	t.default_font_size = 24

	var ivory := GameColors.IVORY
	t.set_color("font_color", "Label", ivory)
	for b in ["Button", "CheckButton"]:
		t.set_color("font_color", b, ivory)
		t.set_color("font_hover_color", b, ivory)
		t.set_color("font_pressed_color", b, ivory)
		t.set_color("font_focus_color", b, ivory)
		t.set_color("font_disabled_color", b, Color(ivory, 0.35))
		t.set_color("font_hover_pressed_color", b, ivory)

	t.set_stylebox("normal", "Button", box(GameColors.PANEL_LIGHT))
	t.set_stylebox("hover", "Button", box(GameColors.PANEL_LIGHT.lightened(0.08)))
	t.set_stylebox("pressed", "Button", box(GameColors.PANEL_LIGHT.darkened(0.2)))
	t.set_stylebox("hover_pressed", "Button", box(GameColors.PANEL_LIGHT.darkened(0.2)))
	t.set_stylebox("disabled", "Button", box(Color(GameColors.PANEL_LIGHT, 0.45)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "CheckButton", box(GameColors.PANEL_LIGHT))
	t.set_stylebox("hover", "CheckButton", box(GameColors.PANEL_LIGHT.lightened(0.08)))
	t.set_stylebox("pressed", "CheckButton", box(GameColors.PANEL_LIGHT))
	t.set_stylebox("hover_pressed", "CheckButton", box(GameColors.PANEL_LIGHT.lightened(0.08)))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(GameColors.PANEL, 20, 24))
	_theme = t
	return t


static func box(col: Color, radius: int = 14, margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 4
	s.content_margin_right = margin + 4
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	return s


## v1.1 chapter look behind a whole screen: the chapter's screen colour with
## its background image on top (dimmed by `alpha`). It reaches past the
## safe-area margins so the colour fills the whole display.
static func chapter_backdrop(chapter: int, alpha: float) -> Control:
	var th := ChapterTheme.of_chapter(chapter)
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		c.set_offset(side, -200)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		c.set_offset(side, 200)
	var col := ColorRect.new()
	col.color = th.screen
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(col)
	var tex := ChapterTheme.background(chapter)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color(1, 1, 1, alpha)
		c.add_child(tr)
	return c


static func button(text: String, cb: Callable, min_size := Vector2(0, 60), accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		accent_button(b, GameColors.ACCENT)
	b.pressed.connect(func():
		Sfx.play("tap")
		cb.call())
	add_press_pop(b)
	return b


## Quick press feedback: shrink on press, spring back with overshoot on release
## (140 ms "quick feedback" from the brand motion guide). Skipped with reduced motion.
static func add_press_pop(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
			return
		if Save.get_setting("reduced_motion") or (b is BaseButton and b.disabled):
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		if e.pressed:
			tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.07).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


static func accent_button(b: Button, col: Color) -> void:
	b.add_theme_stylebox_override("normal", box(col))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.15)))
	b.add_theme_stylebox_override("hover_pressed", box(col.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", box(Color(col, 0.35)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, GameColors.BG)


static func label(text: String, size: int = 24, col: Color = GameColors.IVORY, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func draw_star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if filled:
		ci.draw_colored_polygon(pts, GameColors.HEX.yellow)
	else:
		ci.draw_colored_polygon(pts, Color(GameColors.IVORY, 0.12))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(GameColors.HEX.yellow, 0.9 if filled else 0.35), 2.0, true)
