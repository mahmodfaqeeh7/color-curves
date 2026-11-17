extends SceneTree
## Layout check: in every language and screen shape, the game board and its
## side buttons sit centred as one group (equal space left and right), and
## the level select grid is centred.
## godot --headless --path . --script res://tests/ui_layout.gd

const SIZES := [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1440, 1080)]
const LANGS := ["en", "ar"]
const LEVELS := [0, 24, 45, 62, 79, 82]

var main: Control
var frames := 0
var step := 0
var cases: Array = []
var failures := 0
var _wait_until := 0
var _pos_i := 0
var _pos_opened := false
const POS_CASES := [
	{"screen": "levels", "lang": "en", "size": Vector2i(2532, 1170)},   # iPhone 13
	{"screen": "levels", "lang": "ar", "size": Vector2i(2532, 1170)},
	{"screen": "title", "lang": "en", "size": Vector2i(2400, 1080)},
	{"screen": "settings", "lang": "ar", "size": Vector2i(1920, 1080)},
	{"screen": "45", "lang": "en", "size": Vector2i(2532, 1170)},
	{"screen": "80", "lang": "ar", "size": Vector2i(1440, 1080)},
]


func _initialize() -> void:
	for lang in LANGS:
		for sz in SIZES:
			for lv in LEVELS:
				cases.append({"lang": lang, "size": sz, "level": lv})
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	# Each case: set up on one frame, measure two frames later.
	var i := step / 3
	var phase := step % 3
	step += 1
	if i >= cases.size():
		var k := step - cases.size() * 3
		if k == 1:
			root.get_node("I18n").lang = "en"
			root.size = Vector2i(1920, 1080)
			main.show_levels()
		elif k == 4:
			_swipe_test()
		elif k == 6:
			_expect(main.current_name == "levels", "a swipe never opens a level (screen '%s')" % main.current_name)
			main._level_scroll.stop()
			main._level_scroll.scroll_vertical = 0   # cards move on the next frame
		elif k == 8:
			var card: Control = main._level_scroll.get_child(0).get_child(0)   # level 1 is always open
			var p := card.get_global_rect().get_center()
			_mouse(p, true)
			_mouse(p, false)
		elif k == 10:
			_expect(main.current_name == "game", "a short tap opens a level (screen '%s')" % main.current_name)
			_wait_until = Time.get_ticks_msec() + 700   # let the slide-in finish
		elif k > 10 and Time.get_ticks_msec() >= _wait_until and _pos_i < POS_CASES.size():
			# Each screen, after its slide-in animation: equal space left and right.
			var pc: Dictionary = POS_CASES[_pos_i]
			if not _pos_opened:
				root.get_node("I18n").lang = pc.lang
				root.size = pc.size
				match pc.screen:
					"levels": main.show_levels()
					"title": main.show_title()
					"settings": main.show_settings()
					_: main.open_game(int(pc.screen))
				_pos_opened = true
				_wait_until = Time.get_ticks_msec() + 700
			else:
				_check_screen_position(pc)
				_pos_opened = false
				_pos_i += 1
		elif _pos_i >= POS_CASES.size():
			print("UI layout: %s (%d cases + swipe + %d screen positions)" % ["PASS" if failures == 0 else "FAIL", cases.size(), POS_CASES.size()])
			quit(1 if failures > 0 else 0)
		return false
	var c: Dictionary = cases[i]
	if phase == 0:
		root.get_node("I18n").lang = c.lang
		root.size = c.size
		main.open_game(c.level)
	elif phase == 2:
		_check_game(c)
	return false


func _check_game(c: Dictionary) -> void:
	var g = main.current
	var row: Control = g._row
	var left: float = g.board_holder.get_global_rect().position.x
	var right: float = left
	for ch in row.get_children():
		var r: Rect2 = (ch as Control).get_global_rect()
		left = minf(left, r.position.x)
		right = maxf(right, r.end.x)
	var rr: Rect2 = row.get_global_rect()
	var top_bar: Control = g.btn_back.get_parent()
	var last: Control = top_bar.get_child(top_bar.get_child_count() - 1)
	var vw: float = main.get_viewport_rect().size.x
	var bar_w: float = absf(last.get_global_rect().end.x - g.btn_back.get_global_rect().position.x) if root.get_node("I18n").lang == "en" else absf(g.btn_back.get_global_rect().end.x - last.get_global_rect().position.x)
	var room: float = vw - 2.0 * main.safe.get_theme_constant("margin_left") + 2.0
	_expect(bar_w <= room, "%s %s level %d: the top bar fits between the margins (%.0f of %.0f)" % [c.lang, c.size, c.level + 1, bar_w, room])
	_expect(rr.size.x <= vw - 2.0 * main.safe.get_theme_constant("margin_left") + 2.0, "%s %s level %d: the play area is not wider than the screen (%.0f of %.0f)" % [c.lang, c.size, c.level + 1, rr.size.x, vw])
	var ml: int = main.safe.get_theme_constant("margin_left")
	var mr: int = main.safe.get_theme_constant("margin_right")
	_expect(ml >= 16 and ml == mr, "%s %s: equal side margins (left %d, right %d)" % [c.lang, c.size, ml, mr])
	var gap_l := left - rr.position.x
	var gap_r := rr.end.x - right
	_expect(absf(gap_l - gap_r) <= 2.0, "%s %s level %d: board group centred (left gap %.0f, right gap %.0f)" % [c.lang, c.size, c.level + 1, gap_l, gap_r])
	# The board itself must fill its holder (no hidden empty band).
	var b = g.board
	var bw: float = LevelData.board_size(g.level).x * b.view_scale
	var bh: float = LevelData.board_size(g.level).y * b.view_scale
	var fills := absf(bw - b.size.x) <= 2.0 or absf(bh - b.size.y) <= 2.0
	_expect(fills, "%s %s level %d: board fills its area (board %.0fx%.0f in %s)" % [c.lang, c.size, c.level + 1, bw, bh, b.size])


## Swipe up on a level card: the list must scroll and no level may open.
func _swipe_test() -> void:
	var sc: ScrollContainer = main._level_scroll
	_expect(sc.get_v_scroll_bar().max_value > sc.size.y, "chapter 1 list is long enough to scroll")
	var card: Control = sc.get_child(0).get_child(5)
	var p := card.get_global_rect().get_center()
	_mouse(p, true)
	for j in 10:
		_motion(p - Vector2(0, 20 * (j + 1)))
	_mouse(p - Vector2(0, 200), false)
	_expect(sc.scroll_vertical > 100, "swiping on the cards scrolls the list (scroll %d)" % sc.scroll_vertical)


func _mouse(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = root.get_final_transform() * pos
	e.global_position = e.position
	root.push_input(e)


func _motion(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = root.get_final_transform() * pos
	m.global_position = m.position
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(m)


## Where the screen really is (not only the margin setting): equal space left
## and right once the slide-in animation is over.
func _check_screen_position(c: Dictionary) -> void:
	c = c.duplicate()
	c["level"] = int(c.screen) if str(c.screen).is_valid_int() else -1
	var scr: Control = main.current
	var vw: float = main.get_viewport_rect().size.x
	var r := scr.get_global_rect()
	var gl := r.position.x
	var gr := vw - r.end.x
	_expect(absf(gl - gr) <= 2.0, "%s %s level %d: screen centred on the display (left %.0f, right %.0f)" % [c.lang, c.size, c.level + 1, gl, gr])


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
