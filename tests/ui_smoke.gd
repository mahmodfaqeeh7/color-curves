extends SceneTree
## End-to-end UI check: open level 1, draw its rail with injected pointer
## events (the same path a finger takes), press Launch and expect a win.
## godot --headless --path . --script res://tests/ui_smoke.gd

## Mirrors GameScreen.Mode (autoload-dependent classes can't be referenced
## statically from a --script entry point).
const MODE_PLANNING := 0
const MODE_RUNNING := 1
const MODE_WON := 3

var main: Control
var frames := 0
var phase := 0
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames > 5:
		main.open_game(0)
		phase = 1
	elif phase == 1 and frames > 10:
		var g = main.current
		var board = g.board
		var sfx = root.get_node("Sfx")
		_expect(sfx._music_track == "play", "the play music runs in a level (track '%s')" % sfx._music_track)
		_expect(Engine.max_fps == 60, "levels run at 60 fps (max_fps %d)" % Engine.max_fps)
		_expect(not board.hint_paths.is_empty(), "level 1 shows the first-draw guide")
		var sol = LevelData.read_json(LevelData.solution_path(g.level.levelId))
		var pts: PackedVector2Array = PlanState.strokes_from_data(sol.strokes)[0]
		var to_screen := func(p: Vector2) -> Vector2:
			return root.get_final_transform() * board.get_global_transform_with_canvas() * (board.view_offset + p * board.view_scale)
		_press(to_screen.call(pts[0]), true)
		for i in range(1, pts.size()):
			var m := InputEventMouseMotion.new()
			m.position = to_screen.call(pts[i])
			m.global_position = m.position
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(m)
		_press(to_screen.call(pts[pts.size() - 1]), false)
		_expect(g.plan.used_strokes() == 1, "drag created one committed rail (board %s scale %.2f toast '%s')" % [board.size, board.view_scale, g.toast.text])
		# A tap must not create or consume a stroke.
		_press(to_screen.call(Vector2(500, 120)), true)
		_press(to_screen.call(Vector2(500, 120)), false)
		_expect(g.plan.used_strokes() == 1, "tap consumed nothing")
		g.btn_launch.pressed.emit()
		_expect(g.mode == MODE_RUNNING, "launch enters running state")
		g.btn_launch.pressed.emit()
		_expect(g.mode == MODE_PLANNING and g.plan.used_strokes() == 1, "stop & edit keeps rails")
		g.btn_launch.pressed.emit()
		phase = 2
	elif phase == 2 and frames > 900:
		var g = main.current
		_expect(g.mode == MODE_WON, "drawn solution wins in the real UI (mode=%d)" % g.mode)
		_expect(g.board.hint_paths.is_empty(), "the guide disappears after the first line")
		main.show_title()
		_expect(root.get_node("Sfx")._music_track == "menu" and Engine.max_fps == 30, "menus play menu music at 30 fps (max_fps %d)" % Engine.max_fps)
		# Chapter 2 level 1: ink runs dry, and a pinch zooms without drawing.
		main.open_game(20)
		phase = 3
	elif phase == 3 and frames > 910:
		var g = main.current
		_expect(g.overlay_layer.get_child_count() > 0, "chapter 2 level 1 shows the New! ink card")
		var zig := PackedVector2Array()
		for k in 7:
			zig.append(Vector2(150 if k % 2 == 0 else 900, 40 + k * 3))
		var long_raw := StrokeTools.subdivide(zig, 4.0)
		g.board.stroke_finished.emit(long_raw)
		var used: float = g.plan.used_ink()
		_expect(g.plan.used_strokes() == 1, "a too-long line is kept, not rejected")
		_expect(absf(used - g.plan.max_ink) < 1.0, "it stops exactly when the ink runs out (%.1f of %.1f)" % [used, g.plan.max_ink])
		_expect(g.toast.text != "", "an alert explains the pen ran dry")
		var b = g.board
		var c: Vector2 = b.size * 0.5
		_touch(0, c - Vector2(40, 0), true)
		_touch(1, c + Vector2(40, 0), true)
		_drag(1, c + Vector2(140, 0))
		_touch(1, c + Vector2(140, 0), false)
		_touch(0, c - Vector2(40, 0), false)
		_expect(b.zoom > 1.5, "two fingers zoom the board (zoom %.2f)" % b.zoom)
		_expect(g.plan.used_strokes() == 1, "pinching draws nothing")
		print("UI smoke: %s" % ("PASS" if failures == 0 else "FAIL"))
		root.get_node("Save").reset_progress()
		quit(1 if failures > 0 else 0)
	return false


## Touch events go straight to the board (local coordinates), like a finger.
func _touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = down
	e.position = pos
	main.current.board._gui_input(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	main.current.board._gui_input(e)


func _press(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
