class_name PieceDemo
extends Control
## A tiny live demo of one game piece for the "New!" card: a 400 x 225 board
## where balls meet the piece by themselves, looping every few seconds.
## Uses the real BoardView and ColorSim, so the demo always matches the game.

const KEYS := PieceInfo.KEYS
const LOOP_SECONDS := 4.5

var key := ""
var board: BoardView
var _level: Dictionary
var _sim: ColorSim
var _t := 0.0
var _live := true
var _end_t := 0.0


func _init(k: String, size_px := Vector2(400, 225)) -> void:
	key = k
	custom_minimum_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	board = BoardView.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.drawing_enabled = false
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_level = PieceInfo.level_for(key)
	_live = not _level.launchers.is_empty()
	var plan := PlanState.new(_level)
	for s in _level.get("_demo_rails", []):
		var pts := PackedVector2Array()
		for q in s:
			pts.append(Vector2(q[0], q[1]))
		plan.strokes.append(StrokeTools.smooth(pts, 3))
	board.set_level(_level, plan)
	_restart()


func _restart() -> void:
	_t = 0.0
	_end_t = 0.0
	if not _live:
		return
	board.stop_sim()
	board.ghost_paths.clear()
	_sim = ColorSim.new(_level, board.plan.strokes)
	board.start_sim(_sim)


func _physics_process(delta: float) -> void:
	if not _live or _sim == null:
		return
	_t += delta
	if _sim.state != ColorSim.State.RUNNING:
		_end_t += delta
		if _end_t > 0.8:   # a short beat after a demo ends, then loop
			_restart()
		return
	if _t > LOOP_SECONDS:
		_restart()
		return
	board.interpolate = true
	_sim.step()
	board.after_tick()
	for e in _sim.events:
		match e.type:
			"spawn":
				board.on_spawn(_sim.balls[e.ball].launcher_id, e.pos)
			"paint", "split":
				board.on_paint(e.ball, e.pos, e.get("to", e.get("color", "")))
			"switch":
				board.on_switch(e.switch)
			"bounce":
				if e.kind == "bumper":
					board.on_bumper_hit(e.pos)
				board.on_bounce(e.ball, e.get("normal", Vector2.UP), e.speed)
			"capture":
				board.on_capture(e.collector, e.pos, e.color, e.count)


static func keys_in(lv: Dictionary) -> Array:
	return PieceInfo.keys_in(lv)
