class_name BoardView
extends Control
## Renders a level (in board units, uniformly scaled) and captures drawing input.
## Owns no scoring rules: it draws the PlanState / ColorSim it is given.
##
## Visual Lab (Phase 1) look: shaded shapes with gentle volume, shiny rolling
## balls, ink rails with a soft shadow, glowing goal rings and a dim painted
## chapter background. Every outline is still the exact collision geometry.
##
## Feedback tiers (game feel): bounce = small (squash along the impact),
## recolor = medium (pop + ring), capture = large (ring pop, segment sweep,
## burst), win = huge (confetti + decaying shake). Visual only; the simulation
## is never touched. Reduced motion removes shake, squash, spin and confetti.

signal stroke_finished(raw: PackedVector2Array)
signal tapped(board_pos: Vector2)
signal stroke_feedback(reason: String)

const TRAIL_LEN := 26
const PREVIEW_TICKS := 100
var _theme: Dictionary = ChapterTheme.of_chapter(1)

var level: Dictionary = {}
var plan: PlanState
var sim: ColorSim
var drawing_enabled := true
## True while the simulation is being stepped: balls are drawn between their
## previous and current tick positions (render interpolation).
var interpolate := false
## Ink left in board units (-1 = no ink limit). Set by the game screen.
var ink_left := -1.0
var _dry := PackedVector2Array()
var _dry_t := 0.0

var board_size := Vector2(640, 360)
var view_scale := 1.0
var view_offset := Vector2.ZERO

var _polys: Array = []          ## [{points, type, color, centroid}]
var _dots := PackedVector2Array()
var _bg: Texture2D
var _stroke := PackedVector2Array()
var _stroke_active := false
var _stroke_invalid := ""
var _trails := {}               ## ball id -> Array of [Vector2, color]
var ghost_paths: Array = []
var hint_paths: Array = []      ## solution strokes shown by the hint (PackedVector2Array each)
var hint_t := 0.0
var _effects: Array = []        ## {type, pos, color, t, dur, text}
var _particles: Array = []      ## {pos, vel, color, t, dur, size}
var _collector_pop := {}        ## collector id -> seconds since last capture
var _seg_sweep := {}            ## collector id -> {index, t}
var _ball_pop := {}             ## ball id -> seconds since last recolor
var _ball_spin := {}            ## ball id -> rolling angle (radians)
var _ball_squash := {}          ## ball id -> {t, angle, amount}
var _kick := {}                 ## launcher id -> seconds since last shot
var _ink_pulse := {}            ## stroke index -> seconds since commit
var _preview: Array = []
var _preview_dirty := true
var _trauma := 0.0
var _shake := Vector2.ZERO
var _time := 0.0
var _star_t := -1.0             ## seconds since the map star was collected (-1 = not yet)
var invalid_flash: PackedVector2Array
var _invalid_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_layout)
	_fit_btn = UiKit.button("Fit", reset_zoom, Vector2(70, 40))
	_fit_btn.position = Vector2(8, 8)
	_fit_btn.visible = false
	add_child(_fit_btn)


func set_level(lv: Dictionary, p: PlanState) -> void:
	level = lv
	plan = p
	sim = null
	_theme = ChapterTheme.of_level(lv)
	_bg = ChapterTheme.background(ChapterTheme.chapter_of(lv))
	board_size = LevelData.board_size(lv)
	_polys.clear()
	for o in lv.get("obstacles", []):
		var pts := LevelData.polygon_of(o)
		var c := Vector2.ZERO
		for q in pts:
			c += q
		c /= max(1, pts.size())
		_polys.append({"points": pts, "type": o.type, "color": str(o.get("color", "")), "centroid": c, "id": str(o.id), "o": o})
	_dots.clear()
	for x in range(20, int(board_size.x), 40):
		for y in range(20, int(board_size.y), 40):
			_dots.append(Vector2(x - 0.7, y))
			_dots.append(Vector2(x + 0.7, y))
	_trails.clear()
	ghost_paths.clear()
	_effects.clear()
	_particles.clear()
	_hatch_cache.clear()
	zoom = 1.0
	pan = Vector2.ZERO
	_preview_dirty = true
	_layout()
	queue_redraw()


## Pinch-zoom: 1 = whole board fits; up to MAX_ZOOM. `pan` moves the zoomed
## view (screen px). Drawing, tapping and physics are unaffected: input is
## mapped back to board units through the same transform.
const MAX_ZOOM := 3.0
var zoom := 1.0
var pan := Vector2.ZERO
var _touches := {}       ## finger index -> position (local)
var _pinch := false
var _pinch0 := {}
var _fit_btn: Button


func _base_scale() -> float:
	return min(size.x / board_size.x, size.y / board_size.y)


func _layout() -> void:
	if board_size.x <= 0:
		return
	var base := _base_scale()
	view_scale = base * zoom
	var centred := (size - board_size * base) * 0.5
	if zoom <= 1.0001:
		pan = Vector2.ZERO
	view_offset = centred + pan
	# Keep the zoomed board covering the view (no empty gaps when panning).
	if zoom > 1.0001:
		var w := board_size * view_scale
		view_offset.x = clampf(view_offset.x, minf(size.x - w.x, 0.0), maxf(0.0, size.x - w.x))
		view_offset.y = clampf(view_offset.y, minf(size.y - w.y, 0.0), maxf(0.0, size.y - w.y))
		pan = view_offset - centred
	if _fit_btn != null:
		_fit_btn.visible = zoom > 1.01
	queue_redraw()


func set_zoom(z: float, anchor: Vector2) -> void:
	var bp := to_board(anchor)
	zoom = clampf(z, 1.0, MAX_ZOOM)
	if zoom < 1.05:
		zoom = 1.0
	var base := _base_scale()
	var centred := (size - board_size * base) * 0.5
	pan = anchor - bp * base * zoom - centred
	_layout()


func reset_zoom() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_layout()


func _handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2 and not _pinch:
			_pinch = true
			cancel_stroke()
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			_pinch0 = {"d": maxf(a.distance_to(b), 1.0), "zoom": zoom, "mid": (a + b) * 0.5, "bp": to_board((a + b) * 0.5)}
		elif _touches.size() < 2 and _pinch:
			_pinch = false
		return _pinch or _touches.size() >= 2
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _pinch and _touches.size() >= 2:
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var mid := (a + b) * 0.5
			zoom = clampf(float(_pinch0.zoom) * a.distance_to(b) / float(_pinch0.d), 1.0, MAX_ZOOM)
			if zoom < 1.05:
				zoom = 1.0
			var base := _base_scale()
			var centred := (size - board_size * base) * 0.5
			pan = mid - _pinch0.bp * base * zoom - centred
			_layout()
			return true
	return false


func to_board(p: Vector2) -> Vector2:
	return (p - view_offset) / view_scale


func _reduced() -> bool:
	return bool(Save.get_setting("reduced_motion"))


func start_sim(s: ColorSim) -> void:
	sim = s
	_trails.clear()
	_effects.clear()
	_particles.clear()
	_collector_pop.clear()
	_seg_sweep.clear()
	_ball_pop.clear()
	_ball_spin.clear()
	_ball_squash.clear()
	_kick.clear()
	_star_t = -1.0
	queue_redraw()


func stop_sim() -> void:
	if sim != null and Save.get_setting("ghost"):
		ghost_paths = _trails.values().filter(func(t): return t.size() > 1)
	sim = null
	interpolate = false
	_trails.clear()
	_effects.clear()
	_particles.clear()
	_star_t = -1.0
	_trauma = 0.0
	_preview_dirty = true
	queue_redraw()


func plan_changed() -> void:
	_preview_dirty = true


## Called by the game when a stroke is accepted: a bright pulse runs along it.
func on_stroke_committed(index: int) -> void:
	_ink_pulse[index] = 0.0


func after_tick() -> void:
	if sim == null:
		return
	for b in sim.balls:
		if not b.alive:
			continue
		if not _trails.has(b.id):
			_trails[b.id] = []
		var tr: Array = _trails[b.id]
		if not tr.is_empty() and tr[tr.size() - 1][0].distance_to(b.pos) > 60.0:
			tr.clear()   # a portal jump: start a new trail at the exit
		if tr.is_empty() or tr[tr.size() - 1][0].distance_to(b.pos) > 2.5:
			tr.append([b.pos, b.color])
			if tr.size() > 900:
				tr.pop_front()
		# Rolling: spin by the distance travelled sideways (reads as rolling on rails).
		if not _reduced():
			_ball_spin[b.id] = float(_ball_spin.get(b.id, 0.0)) + (b.pos.x - b.prev_pos.x) / b.radius


# ------------------------------------------------------------------ feedback

func add_effect(type: String, pos: Vector2, color: String = "", text: String = "") -> void:
	var dur := 0.45
	match type:
		"capture":
			dur = 0.6
		"lost":
			dur = 0.5
		"pass":
			dur = 0.4
	if _reduced():
		dur *= 0.6
	_effects.append({"type": type, "pos": pos, "color": color, "t": 0.0, "dur": dur, "text": text})


func on_spawn(launcher_id: String, pos: Vector2) -> void:
	_kick[launcher_id] = 0.0
	if _reduced():
		return
	for i in 4:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(10.0, 26.0)
		_particles.append({"pos": pos, "vel": v, "color": "", "t": 0.0, "dur": 0.35, "size": randf_range(1.2, 2.0)})


func on_bounce(ball_id: int, normal: Vector2, speed: float) -> void:
	if _reduced() or speed < 90.0:
		return
	_ball_squash[ball_id] = {"t": 0.0, "angle": normal.angle(), "amount": clamp(speed / 900.0, 0.08, 0.3)}


func on_paint(ball_id: int, pos: Vector2, color: String) -> void:
	add_effect("paint", pos, color)
	if not _reduced():
		_ball_pop[ball_id] = 0.0


func on_capture(collector_id: String, pos: Vector2, color: String, count: int) -> void:
	add_effect("capture", pos, color, "%d/5" % count)
	_collector_pop[collector_id] = 0.0
	_seg_sweep[collector_id] = {"index": count - 1, "t": 0.0}
	_burst(pos, color, 6 if _reduced() else 12, 70.0)


func on_win() -> void:
	if _reduced():
		return
	add_trauma(0.45)
	for c in level.collectors:
		var center := LevelData.v2(c.center)
		for id in GameColors.IDS:
			_burst(center, id, 7, 150.0)


func add_trauma(amount: float) -> void:
	if _reduced():
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _burst(pos: Vector2, color: String, n: int, speed: float) -> void:
	for i in n:
		var a := TAU * (float(i) + randf() * 0.6) / n
		var v := Vector2.from_angle(a) * speed * randf_range(0.5, 1.0) + Vector2(0, -30)
		_particles.append({"pos": pos, "vel": v, "color": color, "t": 0.0,
			"dur": randf_range(0.45, 0.8), "size": randf_range(1.4, 2.6)})


func cancel_stroke() -> void:
	_stroke_active = false
	_stroke = PackedVector2Array()
	_stroke_invalid = ""
	queue_redraw()


## The part of a stroke the ink could not pay for, shown dotted for a moment.
func flash_dry(pts: PackedVector2Array) -> void:
	_dry = pts
	_dry_t = 1.4


func _dotted(pts: PackedVector2Array, col: Color, r: float) -> void:
	var acc := 0.0
	var next := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		while next <= acc + seg:
			draw_circle(a.lerp(b, (next - acc) / maxf(seg, 0.0001)), r, col)
			next += r * 3.2
		acc += seg


func flash_invalid(pts: PackedVector2Array) -> void:
	invalid_flash = pts
	_invalid_t = 0.7


func _process(delta: float) -> void:
	_time += delta
	hint_t += delta
	if _star_t >= 0.0:
		_star_t += delta
	if _invalid_t > 0.0:
		_invalid_t = max(0.0, _invalid_t - delta)
	if _dry_t > 0.0:
		_dry_t = max(0.0, _dry_t - delta)
	for e in _effects:
		e.t += delta
	_effects = _effects.filter(func(e): return e.t < e.dur)
	for p in _particles:
		p.t += delta
		p.vel *= 0.94
		p.vel.y += 160.0 * delta
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p): return p.t < p.dur)
	for d in [_collector_pop, _kick, _ink_pulse, _bump_t, _switch_t, _unlock_t]:
		for k in d.keys():
			d[k] += delta
	for k in _seg_sweep.keys():
		_seg_sweep[k].t += delta
	for k in _ball_pop.keys():
		_ball_pop[k] += delta
		if _ball_pop[k] > 0.25:
			_ball_pop.erase(k)
	for k in _ball_squash.keys():
		_ball_squash[k].t += delta
		if _ball_squash[k].t > 0.2:
			_ball_squash.erase(k)
	if _trauma > 0.0:
		_trauma = maxf(_trauma - 1.4 * delta, 0.0)
		var s := _trauma * _trauma
		_shake = Vector2(6.0 * s * sin(_time * 51.0), 4.0 * s * sin(_time * 69.0))
	else:
		_shake = Vector2.ZERO
	if _preview_dirty and sim == null and plan != null:
		_build_preview()
	queue_redraw()


func _build_preview() -> void:
	_preview_dirty = false
	_preview.clear()
	if level.is_empty() or not Save.get_setting("preview"):
		return
	var s := ColorSim.new(level, plan.strokes)
	var paths := {}
	var done := {}
	for i in PREVIEW_TICKS:
		s.step()
		for e in s.events:
			if e.type in ["bounce", "paint", "lost", "capture", "pass"]:
				done[e.ball] = true
		for b in s.balls:
			if done.has(b.id) or not b.alive:
				done[b.id] = true
				continue
			if not paths.has(b.launcher_id):
				paths[b.launcher_id] = {"color": b.color, "ball": b.id, "points": PackedVector2Array()}
			if paths[b.launcher_id].ball == b.id:
				paths[b.launcher_id].points.append(b.pos)
		if s.state != ColorSim.State.RUNNING:
			break
		var all_done: bool = paths.size() == level.launchers.size()
		for k in paths:
			if not done.has(paths[k].ball):
				all_done = false
		if all_done:
			break
	_preview = paths.values()


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if level.is_empty():
		return
	if _handle_touch(event):
		accept_event()
		return
	if _pinch:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		set_zoom(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not drawing_enabled:
				return
			_stroke_active = true
			_stroke = PackedVector2Array([to_board(event.position)])
			_stroke_invalid = ""
			accept_event()
		elif _stroke_active:
			_stroke_active = false
			var raw := _stroke
			_stroke = PackedVector2Array()
			if StrokeTools.path_length(raw) < float(level.drawingRules.get("minStrokeLength", 12.0)):
				tapped.emit(raw[0])
			else:
				stroke_finished.emit(raw)
			_stroke_invalid = ""
			accept_event()
	elif event is InputEventMouseMotion and _stroke_active:
		var p := to_board(event.position)
		var last := _stroke[_stroke.size() - 1]
		if last.distance_to(p) >= 1.5:
			_stroke.append(p)
			if _stroke_invalid == "" and StrokeTools.path_length(_stroke) >= 4.0:
				var r := StrokeTools.validate_segment(last, p, level)
				if r != "":
					_stroke_invalid = r
					stroke_feedback.emit(r)
		accept_event()


# ------------------------------------------------------------------ drawing

func _board_xform() -> void:
	draw_set_transform(view_offset + _shake * view_scale, 0.0, Vector2(view_scale, view_scale))


func _draw() -> void:
	if level.is_empty():
		return
	_board_xform()
	var br := Rect2(Vector2.ZERO, board_size)
	_draw_backdrop(br)
	_draw_zones()
	_draw_ghost()
	_draw_preview()
	# Layers: areas under everything, then solid pieces, then gates and prisms.
	for p in _polys:
		if p.type in ["zone", "booster"]:
			_draw_area(p)
		elif p.type in V3_AREAS:
			_draw_v3_area(p)
	for p in _polys:
		if p.type == "rock":
			_draw_obstacle(p)
	for p in _polys:
		if not p.type in ["zone", "booster", "gate", "splitter", "rock"] and not p.type in V3_AREAS:
			_draw_obstacle(p)
	for p in _polys:
		if p.type in ["gate", "splitter"]:
			_draw_obstacle(p)
	for c in level.collectors:
		_draw_collector(c)
	_draw_map_star()
	_draw_hint()
	_draw_rails()
	for l in level.launchers:
		_draw_launcher(l)
	_draw_trails()
	_draw_balls()
	_board_xform()
	_draw_particles()
	_draw_effects()
	draw_rect(br, Color(GameColors.IVORY, 0.16), false, 2.0 / view_scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_backdrop(br: Rect2) -> void:
	Art.gradient_rect(self, br, _theme.board_top, _theme.board_bottom)
	if _bg != null:
		# Chapter background, kept dim so it never competes with play.
		draw_texture_rect(_bg, br, false, Color(1, 1, 1, 0.8))
		Art.gradient_rect(self, br, Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.3))
	# Soft vignette: darker edges keep the eye on the middle of the board.
	var v := 36.0
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0, 0, 0, 0.28)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(br.end.x, 0), Vector2(br.end.x, v), Vector2(0, v)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, br.end.y - v), Vector2(br.end.x, br.end.y - v), br.end, Vector2(0, br.end.y)]), PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(v, 0), Vector2(v, br.end.y), Vector2(0, br.end.y)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(br.end.x - v, 0), Vector2(br.end.x, 0), br.end, Vector2(br.end.x - v, br.end.y)]), PackedColorArray([clear, dark, dark, clear]))
	if not _dots.is_empty():
		draw_multiline(_dots, Color(GameColors.IVORY, 0.05), 1.4)
	_draw_gravity_badge(br)


## When a level's gravity is not straight down, a small compass in the top
## corner shows which way balls fall.
func _draw_gravity_badge(br: Rect2) -> void:
	var g := LevelData.gravity(level)
	if g.length() > 1.0 and g.normalized().dot(Vector2.DOWN) > 0.99:
		return
	var c := Vector2(br.end.x - 26, 26)
	draw_circle(c, 16, Color(GameColors.BG, 0.85))
	draw_arc(c, 16, 0, TAU, 32, Color("#6fc3d6"), 1.6, true)
	if g.length() < 1.0:
		var font := get_theme_default_font()
		draw_string(font, c + Vector2(-12, 5), "0 g", HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color("#6fc3d6"))
		return
	var d := g.normalized()
	var bob := 0.0 if _reduced() else sin(_time * 3.0) * 1.5
	var tip := c + d * (10.0 + bob)
	draw_line(c - d * 8.0, tip - d * 3.0, Color("#6fc3d6"), 2.5, true)
	draw_colored_polygon(PackedVector2Array([tip + d * 2.0, tip - d * 5.0 + d.orthogonal() * 5.0, tip - d * 5.0 - d.orthogonal() * 5.0]), Color("#6fc3d6"))


func _draw_zones() -> void:
	var hatch := Color(GameColors.INVALID, 0.18)
	for r: Rect2 in LevelData.forbidden_rects(level):
		draw_rect(r, Color(GameColors.INVALID, 0.07))
		var lines := PackedVector2Array()
		var x := r.position.x - r.size.y
		while x < r.end.x:
			lines.append(Vector2(max(x, r.position.x), r.position.y + max(0.0, r.position.x - x)))
			lines.append(Vector2(min(x + r.size.y, r.end.x), r.position.y + min(r.size.y, r.end.x - x)))
			x += 10.0
		draw_multiline(lines, hatch, 1.0)
		draw_rect(r, Color(GameColors.INVALID, 0.35), false, 1.0)
	if _stroke_active:
		for z in LevelData.protected_circles(level):
			draw_arc(z.center, z.radius, 0, TAU, 48, Color(GameColors.IVORY, 0.12), 1.0, true)


func _draw_preview() -> void:
	if sim != null or _preview.is_empty():
		return
	for p in _preview:
		var pts: PackedVector2Array = p.points
		var col := GameColors.of(p.color)
		var n := pts.size()
		var i := 3
		# Dots drift gently forward so the arc reads as a direction.
		var drift := 0 if _reduced() else int(_time * 12.0) % 5
		i += drift
		while i < n:
			var f := 1.0 - float(i) / maxf(1.0, n)
			draw_circle(pts[i], 1.7, Color(col, 0.15 + 0.5 * f))
			i += 5


func _draw_obstacle(p: Dictionary) -> void:
	match p.type:
		"rock":
			_draw_rock(p.points)
			return
		"gate":
			_draw_gate(p)
			return
		"switch":
			_draw_switch(p)
			return
		"splitter":
			_draw_splitter(p)
			return
		"bumper":
			_draw_bumper(p)
			return
		"flip":
			_draw_flip(p)
			return
		"conveyor", "glass", "door", "mixer", "portal", "blackhole", "magnet":
			_draw_v3_piece(p)
			return
	_draw_solid(p)


func _draw_solid(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var painter: bool = p.type == "painter"
	var col := GameColors.of(p.color) if painter else GameColors.SLATE
	Art.shaded_polygon(self, pts, col)
	if painter:
		# A faint breathing inner glow marks painters as "active" surfaces,
		# kept inside the outline so it never suggests a bigger collider.
		var glow := 0.0 if _reduced() else 0.5 + 0.5 * sin(_time * 2.0 + p.centroid.x * 0.05)
		GameColors.draw_symbol(self, p.color, p.centroid + Vector2(0.6, 0.8), 11.0, Color(0, 0, 0, 0.25))
		GameColors.draw_symbol(self, p.color, p.centroid, 11.0, GameColors.BG.lerp(col.darkened(0.6), 0.3 * glow))


func _draw_collector(c: Dictionary) -> void:
	var center := LevelData.v2(c.center)
	var r := float(c.innerRadius)
	var col := GameColors.of(c.targetColor)
	var count := 0
	var full := false
	if sim != null:
		for sc in sim.collectors:
			if sc.id == c.id:
				count = sc.count
				full = sc.count >= sc.required
	var since: float = _collector_pop.get(c.id, 99.0)
	var pop := 0.0 if _reduced() or since > 0.4 else sin(since / 0.4 * PI) * (1.0 - since / 0.4) * 1.6
	var rr := r * (1.0 + 0.18 * pop)
	var breathe := 0.0 if _reduced() else 0.5 + 0.5 * sin(_time * 2.0 + center.x * 0.01)
	# v1.1 look: a soft halo in the goal's colour, then a bowl-like well.
	draw_texture_rect(Art.soft_texture(), Rect2(center - Vector2(rr, rr) * 1.9, Vector2(rr, rr) * 3.8), false,
		Color(col, (0.10 + 0.05 * breathe) if not full else 0.3))
	draw_circle(center, rr + 1.0, Color(0.04, 0.03, 0.07, 0.7))
	draw_texture_rect(Art.soft_texture(), Rect2(center - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false,
		Color(col, 0.2 if not full else 0.5))
	# A slowly turning dashed ring inside: the goal is "open" and waiting.
	if not full:
		var spin := 0.0 if _reduced() else _time * 0.5
		var dashes := 12
		for i in dashes:
			var d0 := spin + TAU * i / dashes
			draw_arc(center, rr * 0.72, d0, d0 + TAU / dashes * 0.45, 4, Color(col, 0.22), 1.5, true)
	var req := int(c.get("requiredCount", 5))
	var gap := 0.2
	for i in req:
		var a0 := -PI / 2.0 + TAU * i / req + gap * 0.5
		var a1 := -PI / 2.0 + TAU * (i + 1) / req - gap * 0.5
		draw_arc(center, rr + 4.5, a0, a1, 14, col.darkened(0.55), 6.0, true)
		var fill := 0.0
		if i < count:
			fill = 1.0
			var sw: Dictionary = _seg_sweep.get(c.id, {})
			if not sw.is_empty() and int(sw.index) == i and not _reduced():
				fill = Art.ease_out(float(sw.t) / 0.28)
		if fill > 0.0:
			var a_end := a0 + (a1 - a0) * fill
			draw_arc(center, rr + 4.5, a0, a_end, 14, col, 6.0, true)
			draw_circle(center + Vector2.from_angle(a0) * (rr + 4.5), 3.0, col)
			draw_circle(center + Vector2.from_angle(a_end) * (rr + 4.5), 3.0, col)
			# Thin bright highlight along the filled segment.
			draw_arc(center, rr + 5.5, a0, a_end, 14, Color(col.lightened(0.45), 0.6), 1.5, true)
	if full and not _reduced():
		var k := 0.5 + 0.5 * sin(_time * 3.0)
		draw_arc(center, rr + 9.0, 0, TAU, 40, Color(col, 0.18 + 0.12 * k), 2.0, true)
	var pulse := 0.0 if _reduced() or full else sin(_time * 3.0) * 0.06
	draw_circle(center, 13.0 * (1.0 + pulse + 0.25 * pop), Color(0.04, 0.03, 0.07, 0.45))
	GameColors.draw_symbol(self, c.targetColor, center, 12.0 * (1.0 + pulse + 0.25 * pop), col if not full else col.lightened(0.3))
	if c.has("after") and _is_locked(c):
		_draw_padlock(center + Vector2(0, -rr - 14))


func _draw_launcher(l: Dictionary) -> void:
	var pos := LevelData.v2(l.pos)
	var vel := LevelData.v2(l.velocity)
	var dir := vel.normalized() if vel.length() > 1.0 else Vector2.DOWN
	# Recoil: the barrel kicks back on every shot and springs forward.
	var k: float = _kick.get(l.id, 99.0)
	var recoil := 0.0 if _reduced() or k > 0.25 else sin(k / 0.25 * PI) * 3.0
	var base := pos - dir * recoil
	var power: bool = l.get("power", false)
	var colors: Array = l.colors
	var next_color: String = colors[0]
	var remaining := int(l.count)
	if sim != null:
		var launched := 0
		for b in sim.balls:
			if b.launcher_id == l.id and b.copy_of == -1:   # prism copies were never launched
				launched += 1
		remaining = int(l.count) - launched
		next_color = colors[launched % colors.size()]
	var next_col := GameColors.of(next_color)
	var body := GameColors.PANEL_LIGHT.lightened(0.22)
	if power:
		# Power launcher: heavier barrel with a glowing aura.
		draw_texture_rect(Art.soft_texture(), Rect2(pos - Vector2(28, 28), Vector2(56, 56)), false, Color(GameColors.ACCENT, 0.4))
	# v1.1 look: rounded barrel with a colour band showing the next ball.
	var blen := 24.0 if power else 18.0
	var bw := 13.0 if power else 10.0
	var tip := base + dir * blen
	draw_line(base + Vector2(1.5, 2.5), tip + Vector2(1.5, 2.5), Color(0, 0, 0, 0.25), bw, true)   # shadow
	draw_line(base, tip, body.darkened(0.15), bw, true)
	draw_circle(tip, bw * 0.5, body.darkened(0.15))
	var side := dir.orthogonal() * (bw * 0.22)
	draw_line(base - side, tip - side, Color(1, 1, 1, 0.16), bw * 0.25, true)   # highlight
	var band := base + dir * (blen - 3.0)
	draw_line(band - dir * 1.5, band + dir * 1.5, Color(next_col, 0.85 if remaining > 0 else 0.25), bw, false)
	# Pod: shadow, glossy body, ring.
	draw_circle(pos + Vector2(1.5, 2.5), 14.0, Color(0, 0, 0, 0.28))
	draw_circle(pos, 13.5, body.darkened(0.35))
	draw_circle(pos + Vector2(-0.8, -1.2), 11.5, body)
	draw_texture_rect(Art.soft_texture(), Rect2(pos + Vector2(-9, -10), Vector2(10, 9)), false, Color(1, 1, 1, 0.22))
	var ring := Color(GameColors.IVORY, 0.45)
	if sim == null and not _reduced():
		ring = ring.lerp(GameColors.ACCENT, 0.5 + 0.5 * sin(_time * 2.5))
	draw_arc(pos, 13.5, 0, TAU, 32, ring, 1.6, true)
	if remaining > 0:
		_draw_ball_at(pos, 6.0, next_color, 0.0, null)
	else:
		draw_circle(pos, 5.0, Color(0.05, 0.04, 0.08, 0.8))
	# Ball count in a small badge above the pod.
	var font := get_theme_default_font()
	var txt := str(remaining)
	var fs := 11
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bc := pos + Vector2(0, -23)
	var bwid := maxf(tw + 8.0, 15.0)
	draw_style_box(_badge_box(), Rect2(bc - Vector2(bwid * 0.5, 6.5), Vector2(bwid, 13)))
	draw_string(font, bc + Vector2(-tw * 0.5, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GameColors.IVORY, 0.92))


var _badge: StyleBoxFlat


func _badge_box() -> StyleBoxFlat:
	if _badge == null:
		_badge = StyleBoxFlat.new()
		_badge.bg_color = Color(0.05, 0.04, 0.08, 0.72)
		_badge.set_corner_radius_all(7)
		_badge.anti_aliasing = true
	return _badge


## Ink rail: soft shadow, ivory body, a thin highlight along the top.
func _rail_line(pts: PackedVector2Array, col: Color, w: float, shaded := true) -> void:
	if pts.size() >= 2:
		if shaded:
			draw_polyline(Art._offset(pts, Vector2(1.2, 2.2)), Color(0, 0, 0, 0.28), w, true)
		draw_polyline(pts, col, w, true)
		if shaded:
			draw_polyline(Art._offset(pts, Vector2(-0.4, -0.9)), Color(1, 1, 1, 0.45 * col.a), w * 0.32, true)
	for p in [pts[0], pts[pts.size() - 1]]:
		draw_circle(p, w * 0.5, col)


func _draw_rails() -> void:
	if plan == null:
		return
	var w := StrokeTools.half_width(level) * 2.0
	for i in plan.strokes.size():
		var pts: PackedVector2Array = plan.strokes[i]
		if i == plan.selected:
			_rail_line(pts, Color(GameColors.ACCENT, 0.55), w + 6.0, false)
		_rail_line(pts, GameColors.IVORY, w)
		_draw_ink_pulse(i, pts)
		_draw_lava_burn(pts, w)
	if _stroke_active and _stroke.size() >= 1:
		var col := Color(GameColors.INVALID, 0.9) if _stroke_invalid != "" else Color(GameColors.IVORY, 0.7)
		var live := _stroke
		var over := PackedVector2Array()
		if ink_left >= 0.0:
			var parts := StrokeTools.split_at_length(_stroke, ink_left)
			live = parts[0]
			over = parts[1]
		_rail_line(live, col, w, false)
		if over.size() >= 2:
			_dotted(over, Color(GameColors.INVALID, 0.75), w * 0.6)
		if ink_left >= 0.0:
			var left: float = maxf(0.0, ink_left - StrokeTools.path_length(_stroke))
			var font := get_theme_default_font()
			var at := _stroke[_stroke.size() - 1] + Vector2(10, -14)
			var txt := "%.1f m" % (left / 100.0)
			draw_string(font, at + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6))
			draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameColors.HEX.red if left <= 0.0 else GameColors.IVORY)
		# "Wet ink" tip under the finger.
		var tip := _stroke[_stroke.size() - 1]
		var k := 0.5 + 0.5 * sin(_time * 10.0)
		draw_circle(tip, w * (0.7 + 0.25 * k), Color(col, 0.35))
	if _dry_t > 0.0 and _dry.size() >= 2:
		_dotted(_dry, Color(GameColors.INVALID, _dry_t / 1.4 * 0.85), w * 0.6)
	if _invalid_t > 0.0 and invalid_flash.size() >= 1:
		_rail_line(invalid_flash, Color(GameColors.INVALID, _invalid_t / 0.7 * 0.9), w, false)


func _draw_ink_pulse(i: int, pts: PackedVector2Array) -> void:
	if not _ink_pulse.has(i) or pts.size() < 2:
		return
	var t: float = _ink_pulse[i]
	var dur := 0.4
	if t > dur or _reduced():
		_ink_pulse.erase(i)
		return
	var total := StrokeTools.path_length(pts)
	var target := total * Art.ease_out(t / dur)
	var acc := 0.0
	for j in range(1, pts.size()):
		var seg := pts[j - 1].distance_to(pts[j])
		if acc + seg >= target:
			var p := pts[j - 1].lerp(pts[j], (target - acc) / max(seg, 0.001))
			draw_texture_rect(Art.soft_texture(), Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(1, 1, 1, 0.9 * (1.0 - t / dur)))
			break
		acc += seg


## Hint guide: each solution stroke as marching ivory dashes, with a glowing
## "fingertip" that traces it from start to end (one stroke after another),
## so the player sees both where and in which direction to draw.
const HINT_DASH := 14.0
const HINT_SPEED := 260.0   ## board px per second for the fingertip

func _draw_hint() -> void:
	if hint_paths.is_empty() or sim != null:
		return
	var w := 3.0 / maxf(view_scale, 0.01) + 2.0
	var march := 0.0 if _reduced() else fmod(hint_t * 40.0, HINT_DASH * 2.0)
	var total := 0.0
	for pts in hint_paths:
		total += StrokeTools.path_length(pts)
	for pts in hint_paths:
		var acc := -march
		for j in range(1, pts.size()):
			var a: Vector2 = pts[j - 1]
			var b: Vector2 = pts[j]
			var seg := a.distance_to(b)
			var t0 := 0.0
			while t0 < seg:
				var phase := fposmod(acc + t0, HINT_DASH * 2.0)
				var on := phase < HINT_DASH
				var step := minf((HINT_DASH - phase) if on else (HINT_DASH * 2.0 - phase), seg - t0)
				if on:
					draw_line(a.lerp(b, t0 / seg), a.lerp(b, (t0 + step) / seg), Color(GameColors.IVORY, 0.75), w, true)
				t0 += maxf(step, 0.5)
			acc += seg
		# Start marker: a ring where the finger goes down.
		draw_arc(pts[0], 9.0, 0.0, TAU, 24, Color(GameColors.ACCENT, 0.9), 2.0, true)
	if _reduced() or total <= 0.0:
		return
	# Fingertip travelling along all strokes in order, then a short rest.
	var d := fmod(hint_t * HINT_SPEED, total + HINT_SPEED * 0.8)
	for pts in hint_paths:
		var L := StrokeTools.path_length(pts)
		if d <= L:
			var q := StrokeTools.point_at_length(pts, d)
			draw_texture_rect(Art.soft_texture(), Rect2(q - Vector2(16, 16), Vector2(32, 32)), false, Color(GameColors.ACCENT, 0.85))
			draw_circle(q, 5.0, GameColors.IVORY)
			break
		d -= L


func show_hint_paths(paths: Array) -> void:
	hint_paths = paths
	hint_t = 0.0
	queue_redraw()


func _draw_ghost() -> void:
	if sim != null or ghost_paths.is_empty() or not Save.get_setting("ghost"):
		return
	for tr in ghost_paths:
		var lines := PackedVector2Array()
		var cols := PackedColorArray()
		for i in range(1, tr.size(), 2):
			lines.append(tr[i - 1][0])
			lines.append(tr[i][0])
			cols.append(Color(GameColors.of(tr[i][1]), 0.22))
		if lines.size() >= 2:
			draw_multiline_colors(lines, cols, 1.0)


func _draw_trails() -> void:
	if sim == null or not Save.get_setting("trails"):
		return
	for id in _trails:
		if not sim.balls[id].alive:
			continue
		var tr: Array = _trails[id]
		var n := tr.size()
		var start := maxi(0, n - TRAIL_LEN)
		if n - start < 2:
			continue
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var core := PackedColorArray()
		for i in range(start, n):
			var f := float(i - start) / (n - start)
			pts.append(tr[i][0])
			# Each segment keeps the colour the ball had when it was drawn.
			cols.append(Color(GameColors.of(tr[i][1]), f * 0.4))
			core.append(Color(GameColors.of(tr[i][1]).lightened(0.3), f * f * 0.6))
		draw_polyline_colors(pts, cols, 5.0, true)
		draw_polyline_colors(pts, core, 1.6, true)


## One ball: soft shadow, shaded sphere (light fixed), a symbol that spins as
## it rolls, and an optional squash along the last impact direction.
func _draw_ball_at(pos: Vector2, r: float, color_id: String, spin: float, squash) -> void:
	var col := GameColors.of(color_id)
	var sx := 1.0
	var sy := 1.0
	var ang := 0.0
	if squash != null:
		var k: float = squash.t / 0.2
		var a: float = squash.amount * sin(k * PI) * (1.0 - k * 0.5)
		sx = 1.0 - a
		sy = 1.0 + a * 0.8
		ang = squash.angle
	var origin := view_offset + _shake * view_scale + pos * view_scale
	draw_set_transform(origin, 0.0, Vector2(view_scale, view_scale))
	# Soft halo in the ball's own colour so it pops on the dark board.
	draw_texture_rect(Art.soft_texture(), Rect2(Vector2(-r, -r) * 2.2, Vector2(r, r) * 4.4), false, Color(col, 0.28))
	draw_set_transform(origin + Vector2(1.0, 1.6) * view_scale, 0.0, Vector2(view_scale, view_scale))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.22))
	draw_set_transform(origin, ang, Vector2(view_scale * sx, view_scale * sy))
	draw_texture_rect(Art.ball_texture(), Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, col)
	draw_set_transform(origin, spin, Vector2(view_scale, view_scale))
	GameColors.draw_symbol(self, color_id, Vector2.ZERO, r * 0.9, Color(GameColors.BG, 0.85))
	_board_xform()


func _draw_balls() -> void:
	if sim == null:
		return
	var alpha := Engine.get_physics_interpolation_fraction() if interpolate else 1.0
	var warn_ticks := int((float(level.get("ballLifetime", 20.0)) - ColorSim.WARN_SECONDS) * ColorSim.TICK_RATE)
	for b in sim.balls:
		if not b.alive:
			continue
		var pos: Vector2 = b.prev_pos.lerp(b.pos, alpha)
		var r: float = b.radius
		if _ball_pop.has(b.id):
			var k: float = _ball_pop[b.id] / 0.22
			if k < 1.0:
				r *= 1.0 + 0.3 * sin(k * PI) * (1.0 - k) * 1.6
		var id: String = b.color
		_draw_ball_at(pos, r, id, float(_ball_spin.get(b.id, 0.0)), _ball_squash.get(b.id))
		if b.age > warn_ticks and int(_time * 8.0) % 2 == 0:
			draw_circle(pos, r, Color(GameColors.BG, 0.5))


## The level's collectible star: glowing and bobbing until a ball touches it,
## then it bursts and leaves a faint outline for the rest of the run.
func on_star(pos: Vector2) -> void:
	_star_t = 0.0
	if _reduced():
		return
	for i in 14:
		var v := Vector2.from_angle(TAU * i / 14.0 + randf() * 0.3) * randf_range(60.0, 130.0)
		_particles.append({"pos": pos, "vel": v, "color": "yellow", "t": 0.0, "dur": 0.6, "size": randf_range(1.6, 2.8)})


func _draw_map_star() -> void:
	if not level.has("star"):
		return
	var c := LevelData.v2(level.star.pos)
	var r := ColorSim.STAR_RADIUS
	var gold: Color = GameColors.HEX.yellow
	if _star_t >= 0.0:
		var k := clampf(_star_t / 0.45, 0.0, 1.0)
		if k < 1.0 and not _reduced():
			# Burst: grows and fades.
			draw_texture_rect(Art.soft_texture(), Rect2(c - Vector2(r, r) * 3.0, Vector2(r, r) * 6.0), false, Color(gold, 0.6 * (1.0 - k)))
			_star_shape(c, r * (1.0 + 0.8 * k), Color(gold, 1.0 - k), true)
		_star_shape(c, r * 0.8, Color(gold, 0.35), false)
		return
	var bob := 0.0 if _reduced() else sin(_time * 2.4) * 2.0
	var pulse := 0.0 if _reduced() else 0.5 + 0.5 * sin(_time * 3.2)
	var p := c + Vector2(0, bob)
	draw_texture_rect(Art.soft_texture(), Rect2(p - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(gold, 0.28 + 0.14 * pulse))
	_star_shape(p, r, gold, true)
	# A small highlight so it reads as a shiny pickup.
	draw_circle(p + Vector2(-r * 0.22, -r * 0.3), r * 0.14, Color(1, 1, 1, 0.7))


func _star_shape(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.47))
	if filled:
		draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.35) if filled else col, 2.0, true)


func _draw_particles() -> void:
	for p in _particles:
		var k: float = p.t / p.dur
		var col := GameColors.IVORY if p.color == "" else GameColors.of(p.color)
		draw_circle(p.pos, p.size * (1.0 - k * 0.5), Color(col, (1.0 - k) * (0.6 if p.color == "" else 1.0)))


func _draw_effects() -> void:
	var font := get_theme_default_font()
	for e in _effects:
		var k: float = e.t / e.dur
		var col := GameColors.of(e.color) if e.color != "" else GameColors.IVORY
		match e.type:
			"paint":
				draw_texture_rect(Art.soft_texture(), Rect2(e.pos - Vector2(16, 16), Vector2(32, 32)), false, Color(col, 0.55 * (1.0 - k)))
				draw_arc(e.pos, 6.0 + k * 14.0, 0, TAU, 24, Color(col, 1.0 - k), 2.5, true)
			"capture":
				draw_texture_rect(Art.soft_texture(), Rect2(e.pos - Vector2(26, 26), Vector2(52, 52)), false, Color(col, 0.6 * (1.0 - k)))
				draw_arc(e.pos, 16.0 * (1.0 - k) + 2.0, 0, TAU, 24, Color(col, 1.0 - k), 3.0, true)
				draw_string(font, e.pos + Vector2(-24, -16 - Art.ease_out(k) * 20), e.text, HORIZONTAL_ALIGNMENT_CENTER, 48, 14, Color(col, 1.0 - k))
			"lost":
				for i in 6:
					var d := Vector2.from_angle(TAU * i / 6.0) * (4.0 + k * 10.0)
					draw_circle(e.pos + d, 1.6 * (1.0 - k), Color(col, 1.0 - k))
			"pass":
				var s := 5.0
				draw_line(e.pos + Vector2(-s, -s), e.pos + Vector2(s, s), Color(GameColors.IVORY, 0.6 * (1.0 - k)), 1.5)
				draw_line(e.pos + Vector2(-s, s), e.pos + Vector2(s, -s), Color(GameColors.IVORY, 0.6 * (1.0 - k)), 1.5)
			"bounce":
				draw_arc(e.pos, 4.0 + k * 6.0, 0, TAU, 16, Color(GameColors.IVORY, 0.25 * (1.0 - k)), 1.0, true)


# ------------------------------------------------------------------ Phase 2 pieces

var _bump_t := {}     ## bumper id -> seconds since hit
var _switch_t := {}   ## switch id -> seconds since triggered
var _unlock_t := {}   ## collector id -> seconds since unlocked


func on_bumper_hit(pos: Vector2) -> void:
	var best := ""
	var bd := INF
	for p in _polys:
		if p.type == "bumper":
			var d: float = p.centroid.distance_to(pos)
			if d < bd:
				bd = d
				best = p.id
	if best != "":
		_bump_t[best] = 0.0


func on_switch(id: String) -> void:
	_switch_t[id] = 0.0


func on_unlock(id: String, pos: Vector2) -> void:
	_unlock_t[id] = 0.0
	_burst(pos, "", 10, 90.0)


func _since(d: Dictionary, k: String) -> float:
	return float(d.get(k, 99.0))


func _is_locked(c: Dictionary) -> bool:
	if str(c.get("after", "")) == "":
		return false
	if sim != null:
		return sim.collector_locked(str(c.id))
	return true


func _draw_padlock(at: Vector2) -> void:
	draw_circle(at, 9.0, Color(GameColors.BG, 0.9))
	draw_arc(at + Vector2(0, -2), 4.0, PI, TAU, 10, GameColors.IVORY, 1.8, true)
	draw_rect(Rect2(at + Vector2(-5, -1), Vector2(10, 7)), GameColors.IVORY)


func _dash_poly(pts: PackedVector2Array, col: Color, w: float, dash := 6.0) -> void:
	var lines := PackedVector2Array()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := maxi(1, int(a.distance_to(b) / dash))
		for j in n:
			if j % 2 == 0:
				lines.append(a.lerp(b, float(j) / n))
				lines.append(a.lerp(b, float(j + 1) / n))
	draw_multiline(lines, col, w)


## Hatch lines clipped to a polygon (sampled), every `step` units, along `dir`.
func _hatch(pts: PackedVector2Array, step: float, col: Color, w: float) -> void:
	var key := "h%s%s%d" % [pts[0], pts[pts.size() - 1], pts.size()]
	if _hatch_cache.has(key):
		var cached: PackedVector2Array = _hatch_cache[key]
		if not cached.is_empty():
			draw_multiline(cached, col, w)
		return
	var rect := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		rect = rect.expand(q)
	var lines := PackedVector2Array()
	var y := rect.position.y + step * 0.5
	while y < rect.end.y:
		var inside := false
		var start := Vector2.ZERO
		var x := rect.position.x
		while x <= rect.end.x + 1.0:
			var q := Vector2(x, y)
			var now := Geometry2D.is_point_in_polygon(q, pts)
			if now and not inside:
				start = q
			if not now and inside:
				lines.append(start + Vector2(1.5, 0))
				lines.append(q - Vector2(1.5, 0))
			inside = now
			x += 1.0
		if inside:
			lines.append(start)
			lines.append(Vector2(rect.end.x, y))
		y += step
	_hatch_cache[key] = lines
	if not lines.is_empty():
		draw_multiline(lines, col, w)


## Colour gate: see-through door with bars; only its own colour passes.
func _draw_gate(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var col := GameColors.of(p.color)
	draw_colored_polygon(pts, Color(col, 0.18))
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	draw_texture_rect(Art.soft_texture(), r.grow(10), false, Color(col, 0.22))
	_hatch(pts, 8.0, Color(col, 0.55), 1.4)
	var glow := 0.0 if _reduced() else 0.15 * sin(_time * 3.0)
	_dash_poly(pts, Color(col.lightened(0.25), 0.85 + glow), 1.8)
	var c: Vector2 = p.centroid
	draw_circle(c, 10.0, Color(GameColors.BG, 0.92))
	draw_arc(c, 10.0, 0, TAU, 28, col, 1.6, true)
	GameColors.draw_symbol(self, p.color, c, 10.0, col)


## Switch wall: slides along its arrow once touched by its own colour.
func _draw_switch(p: Dictionary) -> void:
	var o: Dictionary = p.o
	var col := GameColors.of(p.color)
	var mv := LevelData.v2(o.move)
	var off := Vector2.ZERO
	if sim != null:
		off = sim.switch_offset(p.id)
	var base: PackedVector2Array = p.points
	# Track: dashed line along the travel direction through the centre.
	var c0: Vector2 = p.centroid
	var track := PackedVector2Array()
	var n := int(mv.length() / 8.0)
	for j in n:
		if j % 2 == 0:
			track.append(c0 + mv * (float(j) / n))
			track.append(c0 + mv * (float(j + 1) / n))
	draw_multiline(track, Color(GameColors.IVORY, 0.22), 1.2)
	if off.length() > 0.5:
		_dash_poly(base, Color(col, 0.5), 1.4)
	var pts := PackedVector2Array()
	for q in base:
		pts.append(q + off)
	Art.shaded_polygon(self, pts, col)
	var c := c0 + off
	var d := mv.normalized()
	var k := _since(_switch_t, p.id)
	var nudge := 0.0 if _reduced() or k > 0.3 else sin(k / 0.3 * PI) * 3.0
	var tip := c + d * (18.0 + nudge)
	var tail := c - d * 4.0
	draw_line(tail, c + d * 10.0, GameColors.BG, 3.0, true)
	draw_colored_polygon(PackedVector2Array([tip, c + d * 8.0 + d.orthogonal() * 7.0, c + d * 8.0 - d.orthogonal() * 7.0]), GameColors.BG)
	GameColors.draw_symbol(self, p.color, c - d * 16.0, 8.0, GameColors.BG)


## x2 multiplier prism: dark glass, ivory outline, "x2", split arrows.
func _draw_splitter(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var c: Vector2 = p.centroid
	draw_colored_polygon(Art._offset(pts, Vector2(1.5, 2.5)), Color(0, 0, 0, 0.3))
	var cols := PackedColorArray()
	for i in pts.size():
		cols.append([Color("#3a3150"), Color("#16131f"), Color("#241e31")][i % 3])
	draw_polygon(pts, cols)
	var breathe := 0.0 if _reduced() else 0.1 * sin(_time * 2.4)
	draw_texture_rect(Art.soft_texture(), Rect2(c - Vector2(22, 22), Vector2(44, 44)), false, Color(GameColors.ACCENT, 0.3 + breathe))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, GameColors.IVORY, 2.0, true)
	var font := get_theme_default_font()
	draw_string(font, c + Vector2(-17, 5), "\u00d72", HORIZONTAL_ALIGNMENT_CENTER, 34, 13, GameColors.IVORY)
	var dir := (pts[0] - c).normalized()
	var tipp := pts[0]
	for sgn in [-1.0, 1.0]:
		var dd := dir.rotated(0.52 * sgn)
		var a := tipp + dir * 3.0
		var b := a + dd * 13.0
		draw_line(a, b, Color(GameColors.IVORY, 0.8), 1.5, true)
		draw_colored_polygon(PackedVector2Array([b + dd * 3.0, b - dd * 2.0 + dd.orthogonal() * 3.0, b - dd * 2.0 - dd.orthogonal() * 3.0]), Color(GameColors.IVORY, 0.8))


## Bumper: a springy ring that flashes when hit.
func _draw_bumper(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var c: Vector2 = p.centroid
	var r := 0.0
	for q in pts:
		r = maxf(r, c.distance_to(q))
	var k := _since(_bump_t, p.id)
	var pop := 0.0 if _reduced() or k > 0.25 else sin(k / 0.25 * PI) * (1.0 - k / 0.25) * 1.6
	var rr := r * (1.0 + 0.12 * pop)
	draw_circle(c + Vector2(1.5, 2.5), rr, Color(0, 0, 0, 0.25))
	draw_circle(c, rr, GameColors.IVORY.darkened(0.15))
	draw_circle(c + Vector2(-1, -1.5), rr * 0.78, GameColors.PANEL_LIGHT)
	draw_circle(c, rr * 0.45, GameColors.IVORY.lerp(GameColors.ACCENT, 0.4 + 0.6 * pop))
	draw_arc(c, rr, 0, TAU, 32, Color(GameColors.ACCENT, 0.6 + 0.4 * pop), 2.0, true)


## Flip pad: lavender pad with up/down arrows; flips a ball's gravity.
func _draw_flip(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	Art.shaded_polygon(self, pts, GameColors.ACCENT)
	var c: Vector2 = p.centroid
	var wob := 0.0 if _reduced() else sin(_time * 4.0) * 1.5
	for sgn in [-1.0, 1.0]:
		var t := c + Vector2(0, sgn * (5.0 + wob))
		draw_colored_polygon(PackedVector2Array([t + Vector2(0, sgn * 5.0), t + Vector2(-5, 0), t + Vector2(5, 0)]), GameColors.BG)
	draw_line(c + Vector2(-14, 0), c + Vector2(-8, 0), GameColors.BG, 2.0)
	draw_line(c + Vector2(8, 0), c + Vector2(14, 0), GameColors.BG, 2.0)


## Areas: gravity zones (tinted, flowing arrows; zero-g = floating motes) and
## booster pads (chevrons scrolling along the push direction).
func _draw_area(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var o: Dictionary = p.o
	var rect := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		rect = rect.expand(q)
	if p.type == "booster":
		var push := LevelData.v2(o.push)
		var d := push.normalized()
		draw_colored_polygon(pts, Color(GameColors.IVORY, 0.08))
		_dash_poly(pts, Color(GameColors.IVORY, 0.45), 1.2)
		var span: float = absf(rect.size.dot(d.abs()))
		var scroll := 0.0 if _reduced() else fmod(_time * 40.0, 12.0)
		var s := -span * 0.5 + scroll
		var c := rect.get_center()
		while s < span * 0.5:
			var at := c + d * s
			var w: float = absf(rect.size.dot(d.orthogonal().abs())) * 0.32
			if Geometry2D.is_point_in_polygon(at, pts):
				draw_polyline(PackedVector2Array([at - d * 4.0 + d.orthogonal() * w, at + d * 3.0, at - d * 4.0 - d.orthogonal() * w]), Color(GameColors.ACCENT, 0.85), 2.2, true)
			s += 12.0
		return
	var g := LevelData.v2(o.gravity)
	var tint := Color("#6fc3d6")
	draw_colored_polygon(pts, Color(tint, 0.07))
	_dash_poly(pts, Color(tint, 0.45), 1.2, 7.0)
	if g.length() < 1.0:
		# Zero gravity: slow floating motes.
		for i in 14:
			var u := fmod(i * 0.618 + (0.0 if _reduced() else _time * 0.03 * (1 + i % 3)), 1.0)
			var v := fmod(i * 0.377 + 0.13 * i, 1.0)
			var q := rect.position + Vector2(u * rect.size.x, v * rect.size.y)
			if Geometry2D.is_point_in_polygon(q, pts):
				draw_circle(q, 1.6, Color(tint, 0.5))
		var font := get_theme_default_font()
		draw_string(font, rect.position + Vector2(6, 14), "0 g", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tint, 0.8))
		return
	var d := g.normalized()
	var flow := 0.0 if _reduced() else fmod(_time * 30.0, 24.0)
	var x := rect.position.x + 12.0
	while x < rect.end.x - 6.0:
		var y := rect.position.y + 12.0
		while y < rect.end.y - 6.0:
			var at := Vector2(x, y) + d * (flow - 12.0)
			if Geometry2D.is_point_in_polygon(at, pts):
				var head := at + d * 6.0
				draw_line(at - d * 4.0, head, Color(tint, 0.5), 1.4, true)
				draw_colored_polygon(PackedVector2Array([head + d * 3.0, head - d * 1.0 + d.orthogonal() * 3.0, head - d * 1.0 - d.orthogonal() * 3.0]), Color(tint, 0.55))
			y += 24.0
		x += 24.0


## Rock area of a shaped map: solid dark ground with a soft glowing edge and a
## diagonal texture. No drawing and no passing inside it.
func _draw_rock(pts: PackedVector2Array) -> void:
	var cols := PackedColorArray()
	var miny := INF
	var maxy := -INF
	for p in pts:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	for p in pts:
		var t := (p.y - miny) / maxf(1.0, maxy - miny)
		cols.append(Color("#0d0b12").lerp(Color("#050408"), t))
	draw_polygon(pts, cols)
	_hatch_diag(pts, 14.0, Color(GameColors.ACCENT, 0.09), 1.2)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(GameColors.ACCENT, 0.18), 7.0, true)
	draw_polyline(outline, Color(GameColors.ACCENT, 0.6), 2.0, true)


var _hatch_cache := {}


func _hatch_diag(pts: PackedVector2Array, step: float, col: Color, w: float) -> void:
	var key := "d%s%s%d" % [pts[0], pts[pts.size() - 1], pts.size()]
	if _hatch_cache.has(key):
		var cached: PackedVector2Array = _hatch_cache[key]
		if not cached.is_empty():
			draw_multiline(cached, col, w)
		return
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	var lines := PackedVector2Array()
	var x0 := rect.position.x - rect.size.y
	while x0 < rect.end.x:
		var steps := 24
		for j in steps:
			var a := Vector2(x0 + rect.size.y * j / steps, rect.position.y + rect.size.y * j / steps)
			var b := Vector2(x0 + rect.size.y * (j + 1) / steps, rect.position.y + rect.size.y * (j + 1) / steps)
			if Geometry2D.is_point_in_polygon(a, pts) and Geometry2D.is_point_in_polygon(b, pts):
				lines.append(a)
				lines.append(b)
		x0 += step
	_hatch_cache[key] = lines
	if not lines.is_empty():
		draw_multiline(lines, col, w)



# ------------------------------------------------------------------ v1.2 pieces

const V3_AREAS := ["poison", "lava", "fan"]
const POISON := Color("#9BE564")
const LAVA := Color("#FF6A3D")
const PORTAL := Color("#8FB8FF")


## Live state of a piece during a run (glass hits, door open/closed).
func _owner_state(id: String) -> Dictionary:
	if sim == null:
		return {}
	for o in sim.owners:
		if o.id == id:
			return o
	return {}


func _bbox(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r


func _draw_v3_area(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var rect := _bbox(pts)
	var t := 0.0 if _reduced() else _time
	match p.type:
		"poison":
			draw_colored_polygon(pts, Color(POISON, 0.2))
			_dash_poly(pts, Color(POISON, 0.75), 1.6, 6.0)
			# Bubbles rising inside: the area is alive and dangerous.
			for i in 12:
				var u := fmod(i * 0.618, 1.0)
				var v := 1.0 - fmod(i * 0.29 + t * 0.12 * (1 + i % 3), 1.0)
				var at := rect.position + rect.size * Vector2(u, v)
				if Geometry2D.is_point_in_polygon(at, pts):
					draw_arc(at, 2.0 + (i % 3), 0, TAU, 10, Color(POISON, 0.6), 1.2, true)
			_draw_skull(p.centroid, 9.0, Color(POISON, 0.9))
		"lava":
			draw_colored_polygon(pts, Color(LAVA, 0.45))
			var glow := 0.5 + 0.5 * sin(t * 2.2 + p.centroid.x * 0.03)
			draw_texture_rect(Art.soft_texture(), rect.grow(10), false, Color("#FFB347", 0.18 + 0.12 * glow))
			# Slow molten waves.
			for k in 3:
				var line := PackedVector2Array()
				var y := rect.position.y + rect.size.y * (0.3 + 0.25 * k)
				var x := rect.position.x
				while x <= rect.end.x:
					var q := Vector2(x, y + sin(x * 0.06 + t * 1.5 + k) * 3.0)
					if Geometry2D.is_point_in_polygon(q, pts):
						line.append(q)
					elif line.size() >= 2:
						draw_polyline(line, Color("#FFD27A", 0.55), 1.6, true)
						line = PackedVector2Array()
					else:
						line = PackedVector2Array()
					x += 6.0
				if line.size() >= 2:
					draw_polyline(line, Color("#FFD27A", 0.55), 1.6, true)
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color("#FFB347", 0.9), 2.0, true)
		"fan":
			var push := LevelData.v2(p.o.push)
			var d := push.normalized()
			draw_colored_polygon(pts, Color("#CFE8FF", 0.06))
			_dash_poly(pts, Color("#CFE8FF", 0.4), 1.2, 9.0)
			# Wind streaks drifting with the push.
			for i in 10:
				var u := fmod(i * 0.618 + t * 0.35 * (1.0 + (i % 3) * 0.3), 1.0)
				var v := fmod(i * 0.377 + 0.1, 1.0)
				var c := rect.get_center()
				var span := rect.size
				var at := c + d * (u - 0.5) * absf(span.dot(d.abs())) + d.orthogonal() * (v - 0.5) * absf(span.dot(d.orthogonal().abs())) * 0.9
				if Geometry2D.is_point_in_polygon(at, pts):
					draw_line(at - d * 9.0, at + d * 9.0, Color("#E6F2FF", 0.5 * sin(u * PI)), 1.6, true)
			_draw_fan_icon(p.centroid, 11.0, d, t)


func _draw_v3_piece(p: Dictionary) -> void:
	var pts: PackedVector2Array = p.points
	var o: Dictionary = p.o
	var t := 0.0 if _reduced() else _time
	var st := _owner_state(str(o.id))
	match p.type:
		"conveyor":
			Art.shaded_polygon(self, pts, Color("#4A4458"))
			var rot := deg_to_rad(float(o.get("rotation", 0.0)))
			var d := Vector2.RIGHT.rotated(rot) * signf(float(o.get("speed", 160.0)))
			var sz := LevelData.v2(o.size)
			var c := LevelData.v2(o.center)
			var scroll := fmod(t * 30.0, 14.0)
			var x := -sz.x * 0.5 + scroll
			while x < sz.x * 0.5 - 4.0:
				var at := c + Vector2.RIGHT.rotated(rot) * x
				var n := Vector2.DOWN.rotated(rot) * sz.y * 0.28
				draw_polyline(PackedVector2Array([at - d * 3.0 - n, at + d * 3.0, at - d * 3.0 + n]), Color(GameColors.IVORY, 0.55), 1.8, true)
				x += 14.0
			for end in [-1.0, 1.0]:
				draw_circle(c + Vector2.RIGHT.rotated(rot) * end * (sz.x * 0.5 - sz.y * 0.5), sz.y * 0.32, Color("#2B2636"))
		"glass":
			var broken: bool = st.get("broken", false)
			if broken:
				return
			var left := int(st.get("hits", int(o.get("hits", 3))))
			var total := int(o.get("hits", 3))
			draw_colored_polygon(pts, Color("#BFEFFF", 0.28))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color("#E6FBFF", 0.85), 1.6, true)
			# Shine and cracks (one crack per hit taken).
			var r := _bbox(pts)
			draw_line(r.position + r.size * Vector2(0.2, 0.15), r.position + r.size * Vector2(0.45, 0.6), Color(1, 1, 1, 0.35), 1.4, true)
			for k in total - left:
				var a := r.get_center() + Vector2(sin(k * 2.3) * r.size.x * 0.2, cos(k * 1.7) * r.size.y * 0.2)
				draw_polyline(PackedVector2Array([a, a + Vector2(6, -7).rotated(k), a + Vector2(11, -3).rotated(k * 1.4), a + Vector2(16, -10).rotated(k)]), Color(1, 1, 1, 0.8), 1.2, true)
			var font := get_theme_default_font()
			draw_string(font, p.centroid + Vector2(-4, 4), str(left), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#0E2A33", 0.9))
		"door":
			var open: bool = st.get("is_open", ColorSim._door_open_at({"period": maxi(2, int(round(float(o.get("period", 2.0)) * 60))), "open_t": int(round(float(o.get("open", 1.0)) * 60)), "phase": int(round(float(o.get("phase", 0.0)) * 60))}, 0))
			var amber := Color("#FFB648")
			if open:
				_dash_poly(pts, Color(amber, 0.6), 1.4, 5.0)
			else:
				Art.shaded_polygon(self, pts, amber.darkened(0.25))
				var r := _bbox(pts)
				var stripes := PackedVector2Array()
				var y := r.position.y
				while y < r.end.y:
					stripes.append(Vector2(r.position.x + 2, y))
					stripes.append(Vector2(r.end.x - 2, y + minf(8.0, r.end.y - y)))
					y += 10.0
				draw_multiline(stripes, Color(0, 0, 0, 0.3), 2.0)
			# Timer ring: how long until the door changes.
			var period := float(o.get("period", 2.0))
			var phase := float(o.get("phase", 0.0))
			var now := (sim.tick / 60.0) if sim != null else 0.0
			var k := fmod(now + phase, period) / period
			draw_arc(p.centroid, 8.0, -PI / 2, -PI / 2 + TAU * k, 20, Color(GameColors.IVORY, 0.85), 2.0, true)
			draw_arc(p.centroid, 8.0, 0, TAU, 20, Color(GameColors.IVORY, 0.25), 1.0, true)
		"mixer":
			var col := GameColors.of(str(o.color))
			Art.shaded_polygon(self, pts, col)
			# Diagonal white stripes: a mixer blends, a plain painter replaces.
			var r := _bbox(pts)
			var lines := PackedVector2Array()
			var x := r.position.x - r.size.y
			while x < r.end.x:
				var a := Vector2(x, r.end.y)
				var b := Vector2(x + r.size.y, r.position.y)
				var seg := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), pts)
				for sgm in seg:
					if sgm.size() >= 2:
						lines.append(sgm[0])
						lines.append(sgm[sgm.size() - 1])
				x += 9.0
			draw_multiline(lines, Color(1, 1, 1, 0.35), 2.0)
			draw_circle(p.centroid, 9.0, Color(0.06, 0.05, 0.09, 0.55))
			GameColors.draw_symbol(self, str(o.color), p.centroid, 10.0, col)
		"portal":
			for end in [LevelData.v2(o.center), LevelData.v2(o.to)]:
				_draw_portal_ring(end, float(o.get("radius", 18.0)), t)
		"blackhole":
			var c := LevelData.v2(o.center)
			var core := float(o.get("radius", 14.0))
			var reach := float(o.get("reach", core * 3.0))
			draw_arc(c, reach, 0, TAU, 48, Color("#B18CFF", 0.12), 1.0, true)
			draw_texture_rect(Art.soft_texture(), Rect2(c - Vector2(core, core) * 3.0, Vector2(core, core) * 6.0), false, Color("#7B4DFF", 0.35))
			for k in 3:
				var a0 := t * (1.2 + k * 0.4) + k * 2.1
				draw_arc(c, core * (1.5 + k * 0.45), a0, a0 + 2.2, 18, Color("#D7C2FF", 0.5 - k * 0.12), 1.6, true)
			draw_circle(c, core, Color("#05030A"))
			draw_arc(c, core, 0, TAU, 32, Color("#B18CFF", 0.9), 1.6, true)
		"magnet":
			var c := LevelData.v2(o.center)
			var col := GameColors.of(str(o.color))
			var reach := float(o.get("reach", float(o.get("radius", 12.0)) * 3.0))
			var k := 0.0 if _reduced() else fmod(_time * 0.6, 1.0)
			draw_arc(c, reach * (1.0 - k * 0.6), 0, TAU, 48, Color(col, 0.25 * (1.0 - k)), 1.5, true)
			draw_arc(c, reach, 0, TAU, 48, Color(col, 0.12), 1.0, true)
			var rr := float(o.get("radius", 12.0))
			# Horseshoe magnet.
			draw_arc(c, rr, PI * 0.05, PI * 0.95, 16, col, rr * 0.55, true)
			for side in [-1.0, 1.0]:
				var tip := c + Vector2(side * rr, 0)
				draw_line(tip, tip + Vector2(0, -rr * 0.9), col, rr * 0.55, true)
				draw_line(tip + Vector2(0, -rr * 0.9), tip + Vector2(0, -rr * 1.3), GameColors.IVORY, rr * 0.55, true)
			GameColors.draw_symbol(self, str(o.color), c + Vector2(0, rr * 0.2), 7.0, GameColors.BG)


func _draw_portal_ring(c: Vector2, r: float, t: float) -> void:
	draw_texture_rect(Art.soft_texture(), Rect2(c - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, Color(PORTAL, 0.35))
	draw_circle(c, r, Color("#0B1530", 0.85))
	for k in 6:
		var a := t * 2.0 + TAU * k / 6.0
		draw_arc(c, r * 0.65, a, a + 0.6, 6, Color(PORTAL, 0.7), 1.6, true)
	draw_arc(c, r, 0, TAU, 32, PORTAL, 2.2, true)


func _draw_skull(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(0, -s * 0.15), s * 0.6, col)
	draw_rect(Rect2(c + Vector2(-s * 0.32, s * 0.25), Vector2(s * 0.64, s * 0.35)), col)
	for side in [-1.0, 1.0]:
		draw_circle(c + Vector2(side * s * 0.24, -s * 0.18), s * 0.15, GameColors.BG)


func _draw_fan_icon(c: Vector2, r: float, d: Vector2, t: float) -> void:
	draw_circle(c, r, Color(0.06, 0.05, 0.09, 0.45))
	var spin := t * 6.0
	for k in 3:
		var a := spin + TAU * k / 3.0
		var tip := c + Vector2.from_angle(a) * r * 0.8
		draw_colored_polygon(PackedVector2Array([c, tip + Vector2.from_angle(a + 1.6) * r * 0.35, tip]), Color("#E6F2FF", 0.85))
	draw_circle(c, r * 0.18, Color("#E6F2FF"))
	draw_line(c + d * (r + 3.0), c + d * (r + 11.0), Color("#E6F2FF", 0.85), 2.0, true)


## Lines drawn through lava glow during the first 1.5 s of a run, then burn away.
func _draw_lava_burn(pts: PackedVector2Array, w: float) -> void:
	var lavas: Array = _polys.filter(func(q): return q.type == "lava")
	if lavas.is_empty() or pts.size() < 2:
		return
	var burned := sim != null and sim.tick >= ColorSim.LAVA_BURN_TICKS
	var heat := 0.0 if sim == null else clampf(float(sim.tick) / ColorSim.LAVA_BURN_TICKS, 0.0, 1.0)
	for i in range(pts.size() - 1):
		var mid := (pts[i] + pts[i + 1]) * 0.5
		for q in lavas:
			if ColorSim.near_poly(mid, q.points, ColorSim.LAVA_HEAT):
				if burned:
					draw_line(pts[i], pts[i + 1], Color("#3A2A26"), w + 1.0, true)
				else:
					draw_line(pts[i], pts[i + 1], Color(LAVA, 0.35 + 0.6 * heat), w, true)
				break
