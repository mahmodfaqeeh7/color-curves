class_name ColorSim
extends RefCounted
## Deterministic fixed-step simulation of one attempt.
##
## Pure logic: no nodes, no rendering, no engine physics. The same level and
## rails always produce the same tick-by-tick result on a given build, which is
## what replays, stored solutions and stars rely on.
##
## Balls are circles; every collider (obstacle edge or player rail) is a capsule
## segment. Sub-steps per 60 Hz tick plus a speed cap keep every movement below
## a third of the ball radius, so balls cannot tunnel through thin rails.
##
## Rules version 2 (Phase 2) adds, only for levels that contain them:
##   gate      solid for every colour except its own
##   switch    solid wall that slides along `move` once touched by its colour
##   bumper    rebounds harder than it was hit (never paints)
##   flip      solid pad that flips the touching ball's gravity
##   splitter  x2 sensor: one ball in, two of the same colour out (+-30 deg)
##   booster   sensor that accelerates balls along `push`
##   zone      sensor area with its own gravity (and optional drag)
##   collector.after  goal locked until another goal is full
##   level maxSpeed   power launchers: higher speed cap, 6 sub-steps
## Only painters change colour. Levels without these pieces run exactly the
## rules-1 code path (tools/fingerprint.gd proves it).

const RULES_VERSION := 3       ## highest rules version this engine runs (3 = v1.2 pieces)
const TICK_RATE := 60
const SUBSTEPS := 4
const MAX_SPEED := 720.0
const CONTACT_MARGIN := 1.0   ## hysteresis: contact persists within this gap
const REST_SPEED := 40.0      ## normal impact speed below which there is no bounce
const BOUNCE_EVENT_SPEED := 80.0
const STUCK_SPEED := 4.0
const STUCK_TICKS := 90       ## a ball resting this long on static geometry is lost
const WARN_SECONDS := 3.0
const CELL := 24.0
const MAX_BALLS := 40          ## safety cap for multipliers
const SPLIT_ANGLE := deg_to_rad(30.0)
const BUMPER_MIN_OUT := 260.0  ## a bumper always sends a ball away at least this fast
# v1.2 pieces
const LAVA_BURN_TICKS := 90      ## drawn lines near lava burn away 1.5 s into the run
const LAVA_HEAT := 24.0          ## lines this close to lava (or inside it) burn: no bridges over lava
const CONVEYOR_GRIP := 900.0     ## how fast a belt brings a touching ball to its speed (px/s^2)
const WELL_STRENGTH := 900.0     ## default pull of black holes and magnets (px/s^2 at the centre)

enum State { RUNNING, WON, FAILED }


class Ball:
	var id: int
	var pos: Vector2
	var prev_pos: Vector2       ## position at the start of the last tick (render interpolation)
	var vel: Vector2
	var color: String
	var radius: float
	var launcher_id: String
	var age := 0
	var alive := true
	var captured := false
	var lost := false
	var lost_reason := ""
	var contacts := {}          ## owner index -> true
	var in_collector := -1
	var still_ticks := 0
	var gsign := 1.0            ## flipped by flip pads
	var splits := {}            ## splitter index -> true (each splits a ball once)
	var in_boost := {}          ## booster index -> true (for the entry event)
	var copy_of := -1           ## id of the ball it was split from (-1 = launched)
	var portal_lock := -1       ## portal it just came out of (no instant ping-pong)


var level: Dictionary
var board_size: Vector2
var gravity: Vector2
var lifetime_ticks: int
var duration_ticks: int
var max_speed := MAX_SPEED
var substeps := SUBSTEPS
var level_drag := 0.0

var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var seg_r := PackedFloat32Array()
var seg_owner := PackedInt32Array()
## owners[i] = {id, kind, color, restitution, friction}
## kind: rail | neutral | painter | gate | switch | bumper | flip
var owners: Array = []
var polys: Array = []   ## {owner, points, rect, switch (index or -1)}
var grid: Array = []
var grid_w := 0
var grid_h := 0

## Switch walls (moving, kept out of the static grid).
## {owner, id, color, base: PackedVector2Array, move: Vector2, speed, offset: Vector2, triggered, done}
var switches: Array = []
## Sensors.
var splitters: Array = []  ## {id, points, rect}
var boosters: Array = []   ## {id, points, rect, push: Vector2}
var zones: Array = []      ## {id, points, rect, gravity: Vector2, drag}
# v1.2
var hazards: Array = []    ## poison / lava: {id, kind, points, rect}
var wells: Array = []      ## black holes and magnets: {id, kind, center, radius, strength, core, color}
var portals: Array = []    ## {id, a, b, r}
var doors: Array = []      ## owner indices of timed doors
var seg_burn := PackedInt32Array()   ## per segment: tick it burns away (-1 = never)

var balls: Array = []
var collectors: Array = []   ## {id, center, inner, target, required, count, after}
var schedule: Array = []     ## {tick, launcher, color, pos, vel, radius}
var next_spawn := 0
var tick := 0
var state := State.RUNNING
var events: Array = []
var fail_reason := ""
var launched := 0
var lost_count := 0
var captured_count := 0
var win_tick := -1
var lost_before_win := 0
var _pending: Array = []      ## balls created by splitters during a sub-step
## v1.1 map star: an optional pickup. Any ball touching it collects it (once);
## it never changes how balls move, so old replays stay identical.
const STAR_RADIUS := 14.0
var star_pos := Vector2.ZERO
var has_star := false
var star_collected := false
var star_tick := -1


func _init(p_level: Dictionary, rails: Array) -> void:
	level = p_level
	board_size = LevelData.board_size(level)
	gravity = LevelData.gravity(level)
	lifetime_ticks = int(round(float(level.get("ballLifetime", 20.0)) * TICK_RATE))
	duration_ticks = int(round(float(level.get("runDurationLimit", 45.0)) * TICK_RATE))
	max_speed = float(level.get("maxSpeed", MAX_SPEED))
	substeps = SUBSTEPS if max_speed <= MAX_SPEED else 6
	level_drag = float(level.get("drag", 0.0))
	_build_colliders(rails)
	_build_grid()
	_build_collectors()
	_build_schedule()
	if level.has("star"):
		has_star = true
		star_pos = LevelData.v2(level.star.pos)


# --------------------------------------------------------------------------
# Setup

func _add_owner(id: String, kind: String, color: String, mat: Dictionary) -> int:
	owners.append({
		"id": id, "kind": kind, "color": color,
		"restitution": float(mat.restitution), "friction": float(mat.friction),
	})
	return owners.size() - 1


func _add_seg(a: Vector2, b: Vector2, r: float, owner: int) -> void:
	seg_a.append(a)
	seg_b.append(b)
	seg_r.append(r)
	seg_owner.append(owner)
	seg_burn.append(-1)


static func _rect_of(pts: PackedVector2Array) -> Rect2:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	return rect


func _build_colliders(rails: Array) -> void:
	var omat := LevelData.material(level, "obstacle")
	for o in level.get("obstacles", []):
		var kind := str(o.get("type", "neutral"))
		var pts := LevelData.polygon_of(o)
		match kind:
			"splitter":
				splitters.append({"id": str(o.id), "points": pts, "rect": _rect_of(pts)})
				continue
			"booster":
				boosters.append({"id": str(o.id), "points": pts, "rect": _rect_of(pts), "push": LevelData.v2(o.push)})
				continue
			"zone":
				zones.append({"id": str(o.id), "points": pts, "rect": _rect_of(pts),
					"gravity": LevelData.v2(o.gravity), "drag": float(o.get("drag", 0.0))})
				continue
			"poison", "lava":
				hazards.append({"id": str(o.id), "kind": kind, "points": pts, "rect": _rect_of(pts)})
				continue
			"fan":
				boosters.append({"id": str(o.id), "points": pts, "rect": _rect_of(pts), "push": LevelData.v2(o.push), "fan": true})
				continue
			"blackhole", "magnet":
				wells.append({"id": str(o.id), "kind": kind, "center": LevelData.v2(o.center),
					"radius": float(o.get("reach", float(o.get("radius", 40.0)) * 3.0)),
					"strength": float(o.get("strength", WELL_STRENGTH)),
					"core": float(o.get("radius", 14.0)) if kind == "blackhole" else 0.0,
					"color": str(o.get("color", "")) if kind == "magnet" else ""})
				continue
			"portal":
				portals.append({"id": str(o.id), "a": LevelData.v2(o.center), "b": LevelData.v2(o.to),
					"r": float(o.get("radius", 18.0))})
				continue
		var color := str(o.get("color", "")) if kind in ["painter", "gate", "switch", "mixer"] else ""
		var mat := omat.duplicate()
		if kind == "bumper":
			mat = {"restitution": 1.25, "friction": 0.0}
		if o.has("material"):
			mat.merge(o.material, true)
		var oi := _add_owner(str(o.id), kind, color, mat)
		match kind:
			"conveyor":
				# Belt direction = the rectangle's long axis; positive speed moves along +x before rotation.
				owners[oi]["belt"] = Vector2.RIGHT.rotated(deg_to_rad(float(o.get("rotation", 0.0)))) * float(o.get("speed", 160.0))
			"glass":
				owners[oi]["hits"] = int(o.get("hits", 3))
				owners[oi]["broken"] = false
			"door":
				owners[oi]["period"] = maxi(2, int(round(float(o.get("period", 2.0)) * TICK_RATE)))
				owners[oi]["open_t"] = int(round(float(o.get("open", 1.0)) * TICK_RATE))
				owners[oi]["phase"] = int(round(float(o.get("phase", 0.0)) * TICK_RATE))
				owners[oi]["is_open"] = _door_open_at(owners[oi], 0)
				doors.append(oi)
		if kind == "switch":
			switches.append({"owner": oi, "id": str(o.id), "color": color, "base": pts,
				"move": LevelData.v2(o.move), "speed": float(o.get("speed", 240.0)),
				"offset": Vector2.ZERO, "triggered": false, "done": false})
			polys.append({"owner": oi, "points": pts, "rect": _rect_of(pts), "switch": switches.size() - 1})
			continue
		for i in pts.size():
			_add_seg(pts[i], pts[(i + 1) % pts.size()], 0.0, oi)
		polys.append({"owner": oi, "points": pts, "rect": _rect_of(pts), "switch": -1})
	var rmat := LevelData.material(level, "rail")
	var half := float(level.get("drawingRules", {}).get("railWidth", 6.0)) * 0.5
	for ri in rails.size():
		var pts: PackedVector2Array = rails[ri]
		var oi := _add_owner("rail_%d" % ri, "rail", "", rmat)
		if pts.size() == 1:
			_add_seg(pts[0], pts[0], half, oi)
		for i in range(pts.size() - 1):
			_add_seg(pts[i], pts[i + 1], half, oi)
			if _in_lava((pts[i] + pts[i + 1]) * 0.5):
				seg_burn[seg_burn.size() - 1] = LAVA_BURN_TICKS


func _in_lava(p: Vector2) -> bool:
	for h in hazards:
		if h.kind == "lava" and h.rect.grow(LAVA_HEAT).has_point(p) and near_poly(p, h.points, LAVA_HEAT):
			return true
	return false


## Inside the polygon, or within `gap` of its outline.
static func near_poly(p: Vector2, pts: PackedVector2Array, gap: float) -> bool:
	if Geometry2D.is_point_in_polygon(p, pts):
		return true
	for i in pts.size():
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])) <= gap:
			return true
	return false


static func _door_open_at(o: Dictionary, t: int) -> bool:
	return (t + int(o.phase)) % int(o.period) < int(o.open_t)


## Is this owner solid right now? (glass breaks, doors open and close)
func _solid(oi: int) -> bool:
	var o: Dictionary = owners[oi]
	match o.kind:
		"glass":
			return not o.broken
		"door":
			return not o.is_open
	return true


func _max_ball_radius() -> float:
	var r := 6.0
	for l in level.get("launchers", []):
		r = max(r, float(l.get("ballRadius", 6.0)))
	return r


func _build_grid() -> void:
	grid_w = int(ceil(board_size.x / CELL))
	grid_h = int(ceil(board_size.y / CELL))
	grid.resize(grid_w * grid_h)
	for i in grid.size():
		grid[i] = PackedInt32Array()
	var reach := _max_ball_radius() + CONTACT_MARGIN + 2.0
	for si in seg_a.size():
		var a := seg_a[si]
		var b := seg_b[si]
		var e := seg_r[si] + reach
		var x0 := clampi(int(floor((min(a.x, b.x) - e) / CELL)), 0, grid_w - 1)
		var x1 := clampi(int(floor((max(a.x, b.x) + e) / CELL)), 0, grid_w - 1)
		var y0 := clampi(int(floor((min(a.y, b.y) - e) / CELL)), 0, grid_h - 1)
		var y1 := clampi(int(floor((max(a.y, b.y) + e) / CELL)), 0, grid_h - 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var cc := Vector2((gx + 0.5) * CELL, (gy + 0.5) * CELL)
				var cp := Geometry2D.get_closest_point_to_segment(cc, a, b)
				if cc.distance_to(cp) <= e + CELL * 0.7072:
					var cell: PackedInt32Array = grid[gy * grid_w + gx]
					cell.append(si)
					grid[gy * grid_w + gx] = cell


func _build_collectors() -> void:
	for c in level.get("collectors", []):
		collectors.append({
			"id": str(c.id), "center": LevelData.v2(c.center),
			"inner": float(c.innerRadius), "target": str(c.targetColor),
			"required": int(c.get("requiredCount", 5)), "count": 0,
			"after": str(c.get("after", "")),
		})


func _build_schedule() -> void:
	var li := 0
	for l in level.get("launchers", []):
		var interval := int(round(float(l.get("interval", 0.55)) * TICK_RATE))
		var delay := int(round(float(l.get("delay", 0.0)) * TICK_RATE))
		var colors: Array = l.colors
		for k in int(l.count):
			schedule.append({
				"tick": delay + k * interval, "order": li, "launcher": str(l.id),
				"color": str(colors[k % colors.size()]),
				"pos": LevelData.v2(l.pos), "vel": LevelData.v2(l.velocity),
				"radius": float(l.get("ballRadius", 6.0)),
			})
		li += 1
	schedule.sort_custom(func(x, y):
		return x.tick < y.tick or (x.tick == y.tick and x.order < y.order))


# --------------------------------------------------------------------------
# Queries

func is_running() -> bool:
	return state == State.RUNNING


func remaining_slots() -> int:
	var d := 0
	for c in collectors:
		d += c.required - c.count
	return d


func active_count() -> int:
	var n := 0
	for b in balls:
		if b.alive:
			n += 1
	return n


func unlaunched_count() -> int:
	return schedule.size() - next_spawn


## Current offset of a switch wall by obstacle id (for drawing).
func switch_offset(id: String) -> Vector2:
	for s in switches:
		if s.id == id:
			return s.offset
	return Vector2.ZERO


func _collector_locked(c: Dictionary) -> bool:
	if c.after == "":
		return false
	for o in collectors:
		if o.id == c.after:
			return o.count < o.required
	return false


func collector_locked(id: String) -> bool:
	for c in collectors:
		if c.id == id:
			return _collector_locked(c)
	return false


# --------------------------------------------------------------------------
# Stepping

## Advance one fixed tick. After a win the world keeps moving for the
## celebration, but spawning, capture and scoring are frozen.
func step() -> void:
	events.clear()
	for b in balls:
		b.prev_pos = b.pos
	if state == State.FAILED:
		return
	if state == State.RUNNING:
		while next_spawn < schedule.size() and schedule[next_spawn].tick <= tick:
			_spawn(schedule[next_spawn])
			next_spawn += 1
	for oi in doors:
		var o: Dictionary = owners[oi]
		var now := _door_open_at(o, tick)
		if now != o.is_open:
			o.is_open = now
			events.append({"type": "door", "id": o.id, "open": now})
	var dt := 1.0 / TICK_RATE / substeps
	for _s in substeps:
		if not switches.is_empty():
			_move_switches(dt)
		for b in balls:
			if b.alive:
				_integrate(b, dt)
		if not _pending.is_empty():
			balls.append_array(_pending)
			_pending.clear()
	for b in balls:
		if not b.alive:
			continue
		b.age += 1
		var r: float = b.radius
		if b.pos.x < -r or b.pos.x > board_size.x + r or b.pos.y < -r or b.pos.y > board_size.y + r:
			_lose(b, "out")
		elif b.age >= lifetime_ticks:
			_lose(b, "expired")
		elif b.vel.length() < STUCK_SPEED:
			b.still_ticks += 1
			if b.still_ticks >= STUCK_TICKS and not _walls_may_still_move():
				_lose(b, "stuck")
		else:
			b.still_ticks = 0
	tick += 1
	if state == State.RUNNING:
		_check_failure()


## A resting ball is only "stuck" if no switch wall can still move and free it.
func _walls_may_still_move() -> bool:
	if not doors.is_empty():
		return true
	for s in switches:
		if not s.done:
			return true
	return false


func _move_switches(dt: float) -> void:
	for s in switches:
		if not s.triggered or s.done:
			continue
		var total: float = s.move.length()
		var travelled: float = s.offset.length() + s.speed * dt
		if travelled >= total:
			s.offset = s.move
			s.done = true
		else:
			s.offset = s.move.normalized() * travelled


func _spawn(s: Dictionary) -> void:
	var b := Ball.new()
	b.id = balls.size()
	b.pos = s.pos
	b.prev_pos = s.pos
	b.vel = s.vel
	b.color = s.color
	b.radius = s.radius
	b.launcher_id = s.launcher
	balls.append(b)
	launched += 1
	events.append({"type": "spawn", "ball": b.id, "color": b.color, "pos": b.pos})


func _lose(b: Ball, reason: String) -> void:
	b.alive = false
	b.lost = true
	b.lost_reason = reason
	if state == State.RUNNING:
		lost_count += 1
	events.append({"type": "lost", "ball": b.id, "reason": reason, "pos": b.pos, "color": b.color})


func _gravity_for(b: Ball) -> Vector2:
	var g := gravity
	for z in zones:
		if z.rect.has_point(b.pos) and Geometry2D.is_point_in_polygon(b.pos, z.points):
			g = z.gravity
	return g * b.gsign if b.gsign != 1.0 else g


func _drag_for(b: Ball) -> float:
	var d := level_drag
	for z in zones:
		if z.rect.has_point(b.pos) and Geometry2D.is_point_in_polygon(b.pos, z.points):
			d = z.drag
	return d


func _integrate(b: Ball, dt: float) -> void:
	if not wells.is_empty():
		_apply_wells(b, dt)
		if not b.alive:
			return
	if zones.is_empty() and b.gsign == 1.0:
		b.vel += gravity * dt
	else:
		b.vel += _gravity_for(b) * dt
	if not boosters.is_empty():
		_apply_boosters(b, dt)
	if level_drag > 0.0 or not zones.is_empty():
		var d := _drag_for(b)
		if d > 0.0:
			b.vel *= max(0.0, 1.0 - d * dt)
	var sp := b.vel.length()
	if sp > max_speed:
		b.vel *= max_speed / sp
	b.pos += b.vel * dt
	_collide(b, dt)
	if not hazards.is_empty() and _in_hazard(b):
		return
	if not portals.is_empty():
		_check_portals(b)
	if b.alive and not splitters.is_empty():
		_check_splitters(b)
	if b.alive and state == State.RUNNING:
		if has_star and not star_collected and b.pos.distance_to(star_pos) <= STAR_RADIUS + b.radius:
			star_collected = true
			star_tick = tick
			events.append({"type": "star", "ball": b.id, "pos": star_pos, "color": b.color})
		_check_collectors(b)


## Black holes pull every ball and swallow it at the core; magnets pull only
## balls of their colour. Pull grows toward the centre and is zero at the edge.
func _apply_wells(b: Ball, dt: float) -> void:
	for w in wells:
		if w.color != "" and w.color != b.color:
			continue
		var d: Vector2 = w.center - b.pos
		var dist := d.length()
		if dist >= w.radius or dist < 0.001:
			continue
		if w.core > 0.0 and dist <= w.core:
			_lose(b, "blackhole")
			return
		b.vel += d / dist * float(w.strength) * (1.0 - dist / float(w.radius)) * dt


## Poison and lava: a ball touching them is lost.
func _in_hazard(b: Ball) -> bool:
	for h in hazards:
		if h.rect.grow(b.radius).has_point(b.pos):
			var inside := Geometry2D.is_point_in_polygon(b.pos, h.points)
			if not inside:
				var pts: PackedVector2Array = h.points
				for i in pts.size():
					var cp := Geometry2D.get_closest_point_to_segment(b.pos, pts[i], pts[(i + 1) % pts.size()])
					if b.pos.distance_to(cp) < b.radius * 0.6:
						inside = true
						break
			if inside:
				_lose(b, str(h.kind))
				return true
	return false


## Portals work both ways and keep the ball's speed and direction.
func _check_portals(b: Ball) -> void:
	for i in portals.size():
		var p: Dictionary = portals[i]
		var da: float = b.pos.distance_to(p.a)
		var db: float = b.pos.distance_to(p.b)
		if b.portal_lock == i:
			if da > p.r + b.radius and db > p.r + b.radius:
				b.portal_lock = -1
			continue
		var from: Vector2
		var to: Vector2
		if da <= p.r:
			from = p.a
			to = p.b
		elif db <= p.r:
			from = p.b
			to = p.a
		else:
			continue
		var entry := b.pos
		b.pos = to + (b.pos - from)
		b.prev_pos = b.pos
		b.portal_lock = i
		events.append({"type": "portal", "ball": b.id, "from": entry, "pos": b.pos, "portal": p.id, "color": b.color})
		return


func _apply_boosters(b: Ball, dt: float) -> void:
	for i in boosters.size():
		var bo: Dictionary = boosters[i]
		var inside: bool = bo.rect.has_point(b.pos) and Geometry2D.is_point_in_polygon(b.pos, bo.points)
		if inside:
			b.vel += bo.push * dt
			if not b.in_boost.has(i):
				b.in_boost[i] = true
				if not bo.get("fan", false):
					events.append({"type": "boost", "ball": b.id, "pos": b.pos, "booster": bo.id})
		elif b.in_boost.has(i):
			b.in_boost.erase(i)


func _check_splitters(b: Ball) -> void:
	for i in splitters.size():
		if b.splits.has(i):
			continue
		var sp: Dictionary = splitters[i]
		if not (sp.rect.has_point(b.pos) and Geometry2D.is_point_in_polygon(b.pos, sp.points)):
			continue
		b.splits[i] = true
		if active_count() + _pending.size() >= MAX_BALLS:
			events.append({"type": "split_full", "ball": b.id, "pos": b.pos, "splitter": sp.id})
			continue
		var c := Ball.new()
		c.id = balls.size() + _pending.size()
		c.pos = b.pos
		c.prev_pos = b.prev_pos
		c.color = b.color
		c.radius = b.radius
		c.launcher_id = b.launcher_id
		c.gsign = b.gsign
		c.splits = b.splits.duplicate()
		c.copy_of = b.id
		c.age = b.age
		c.vel = b.vel.rotated(SPLIT_ANGLE)
		b.vel = b.vel.rotated(-SPLIT_ANGLE)
		_pending.append(c)
		events.append({"type": "split", "ball": b.id, "copy": c.id, "pos": b.pos, "splitter": sp.id, "color": b.color})


func _collide(b: Ball, dt: float) -> void:
	var touching := {}
	var depth := {}
	var gx := int(floor(b.pos.x / CELL))
	var gy := int(floor(b.pos.y / CELL))
	if gx >= 0 and gy >= 0 and gx < grid_w and gy < grid_h:
		var cell: PackedInt32Array = grid[gy * grid_w + gx]
		for si in cell:
			var oi := seg_owner[si]
			if owners[oi].kind == "gate" and owners[oi].color == b.color:
				continue  # a gate is open for its own colour
			if seg_burn[si] >= 0 and tick >= seg_burn[si]:
				continue  # this piece of line burned away in lava
			if not _solid(oi):
				continue
			_collide_seg(b, seg_a[si], seg_b[si], seg_r[si], oi, dt, touching, depth)
	for s in switches:
		var pts: PackedVector2Array = s.base
		var off: Vector2 = s.offset
		for i in pts.size():
			_collide_seg(b, pts[i] + off, pts[(i + 1) % pts.size()] + off, 0.0, s.owner, dt, touching, depth)
	# Safety net: a ball centre inside a solid polygon is pushed out of it.
	for p in polys:
		var oi: int = p.owner
		if owners[oi].kind == "gate" and owners[oi].color == b.color:
			continue
		if not _solid(oi):
			continue
		var off := Vector2.ZERO
		if p.switch >= 0:
			off = switches[p.switch].offset
		if not p.rect.has_point(b.pos - off):
			continue
		var pts: PackedVector2Array = p.points
		var local := b.pos - off
		if not Geometry2D.is_point_in_polygon(local, pts):
			continue
		var best := INF
		var best_cp := local
		for i in pts.size():
			var cp := Geometry2D.get_closest_point_to_segment(local, pts[i], pts[(i + 1) % pts.size()])
			var dd := local.distance_to(cp)
			if dd < best:
				best = dd
				best_cp = cp
		var n := (best_cp - local).normalized()
		if n == Vector2.ZERO:
			n = Vector2.UP
		b.pos = best_cp + off + n * b.radius
		touching[oi] = true
		depth[oi] = max(float(depth.get(oi, 0.0)), best + b.radius)
		_respond(b, n, owners[oi], dt)
	_apply_contacts(b, touching, depth)
	b.contacts = touching


func _collide_seg(b: Ball, a: Vector2, e: Vector2, seg_radius: float, oi: int, dt: float, touching: Dictionary, depth: Dictionary) -> void:
	var cp := Geometry2D.get_closest_point_to_segment(b.pos, a, e)
	var d := b.pos - cp
	var dist := d.length()
	var min_d: float = b.radius + seg_radius
	if dist >= min_d + CONTACT_MARGIN:
		return
	if not touching.has(oi):
		touching[oi] = true
		depth[oi] = 0.0
	if dist < min_d:
		var n: Vector2
		if dist > 0.0001:
			n = d / dist
		else:
			n = (e - a).orthogonal().normalized()
			if n == Vector2.ZERO or n.dot(b.vel) > 0.0:
				n = -n if n != Vector2.ZERO else Vector2.UP
		var pen := min_d - dist
		b.pos += n * pen
		depth[oi] = max(float(depth[oi]), pen)
		_respond(b, n, owners[oi], dt)


func _respond(b: Ball, n: Vector2, mat: Dictionary, dt: float) -> void:
	var vn := b.vel.dot(n)
	if vn >= 0.0:
		return
	var vt := b.vel - n * vn
	if mat.kind == "bumper":
		var out: float = max(-vn * float(mat.restitution), BUMPER_MIN_OUT)
		b.vel = vt + n * out
		events.append({"type": "bounce", "ball": b.id, "speed": out, "pos": b.pos, "kind": "bumper", "normal": n})
		return
	var e: float = mat.restitution if -vn > REST_SPEED else 0.0
	if mat.kind == "conveyor":
		# The belt carries the ball: its sliding speed moves toward the belt's speed.
		var tangent := n.orthogonal()
		var belt: float = (mat.belt as Vector2).dot(tangent)
		var along := vt.dot(tangent)
		vt = tangent * move_toward(along, belt, CONVEYOR_GRIP * dt)
	else:
		vt *= max(0.0, 1.0 - float(mat.friction) * dt)
	b.vel = vt - n * (vn * e)
	if -vn > BOUNCE_EVENT_SPEED:
		events.append({"type": "bounce", "ball": b.id, "speed": -vn, "pos": b.pos, "kind": mat.kind, "normal": n})


## Contact entries: painters overwrite colour (in chronological order, then
## by stable id, so the most recent contact decides); flip pads flip gravity;
## a switch wall starts moving when its own colour touches it.
func _apply_contacts(b: Ball, touching: Dictionary, depth: Dictionary) -> void:
	var entered: Array = []
	for oi in touching:
		if b.contacts.has(oi):
			continue
		var kind: String = owners[oi].kind
		if kind == "painter":
			entered.append(oi)
		elif kind == "mixer":
			var from := b.color
			b.color = GameColors.mix(b.color, owners[oi].color)
			events.append({"type": "paint", "ball": b.id, "from": from, "to": b.color,
				"pos": b.pos, "obstacle": owners[oi].id, "mixer": true})
		elif kind == "glass" and not owners[oi].broken:
			owners[oi].hits -= 1
			events.append({"type": "crack", "id": owners[oi].id, "pos": b.pos, "left": owners[oi].hits})
			if owners[oi].hits <= 0:
				owners[oi].broken = true
				events.append({"type": "shatter", "id": owners[oi].id, "pos": b.pos})
		elif kind == "flip":
			b.gsign = -b.gsign
			events.append({"type": "flip", "ball": b.id, "pos": b.pos, "up": b.gsign < 0.0})
		elif kind == "switch" and owners[oi].color == b.color:
			for s in switches:
				if s.owner == oi and not s.triggered:
					s.triggered = true
					events.append({"type": "switch", "ball": b.id, "pos": b.pos, "switch": s.id, "color": b.color})
	if entered.is_empty():
		return
	entered.sort_custom(func(x, y):
		if not is_equal_approx(depth[x], depth[y]):
			return depth[x] > depth[y]
		return str(owners[x].id) < str(owners[y].id))
	for oi in entered:
		var from := b.color
		b.color = owners[oi].color
		events.append({
			"type": "paint", "ball": b.id, "from": from, "to": b.color,
			"pos": b.pos, "obstacle": owners[oi].id,
		})


func _check_collectors(b: Ball) -> void:
	if not b.alive or b.captured or state != State.RUNNING:
		return  # a ball can only ever be captured once
	var inside := -1
	for ci in collectors.size():
		var c: Dictionary = collectors[ci]
		# v1.1: a ball counts once its centre is inside the circle (at least half
		# of it in the well). It used to need the whole ball inside, so balls
		# that visibly rolled over the circle's edge were not caught.
		if b.pos.distance_to(c.center) <= c.inner:
			inside = ci
			if c.count < c.required and b.color == c.target and not _collector_locked(c):
				c.count += 1
				captured_count += 1
				b.alive = false
				b.captured = true
				events.append({
					"type": "capture", "ball": b.id, "collector": c.id,
					"count": c.count, "pos": b.pos, "color": b.color,
				})
				if c.count == c.required:
					for o in collectors:
						if o.after == c.id:
							events.append({"type": "unlock", "collector": o.id, "pos": o.center})
				if remaining_slots() == 0:
					state = State.WON
					win_tick = tick
					lost_before_win = lost_count
					events.append({"type": "win"})
				return
	if inside != b.in_collector and inside >= 0:
		var c: Dictionary = collectors[inside]
		events.append({
			"type": "pass", "ball": b.id, "collector": c.id,
			"full": c.count >= c.required, "locked": _collector_locked(c), "pos": b.pos,
		})
	b.in_collector = inside


## Count-only necessary check (spec 4.5). It never declares failure just
## because an active ball currently has the wrong colour. With multipliers on
## the board the ball count can still grow, so only "nothing left" and the
## time limit end the attempt.
func _check_failure() -> void:
	var d := remaining_slots()
	var a := active_count()
	var u := unlaunched_count()
	if d > a + u and splitters.is_empty():
		_fail("not_enough" if (a + u) > 0 else "no_balls")
	elif a == 0 and u == 0 and d > 0:
		_fail("no_balls")
	elif tick >= duration_ticks:
		_fail("timeout")


func _fail(reason: String) -> void:
	state = State.FAILED
	fail_reason = reason
	events.append({"type": "fail", "reason": reason})


## Run to completion (used by tests and level verification).
func run_to_end(max_ticks: int = -1) -> Dictionary:
	var cap := duration_ticks + 1 if max_ticks < 0 else max_ticks
	while state == State.RUNNING and tick < cap:
		step()
	return result()


func result() -> Dictionary:
	var per: Array = []
	for c in collectors:
		per.append({"id": c.id, "target": c.target, "count": c.count, "required": c.required})
	return {
		"won": state == State.WON,
		"failed": state == State.FAILED,
		"reason": fail_reason,
		"ticks": win_tick if state == State.WON else tick,
		"launched": launched,
		"lost": lost_before_win if state == State.WON else lost_count,
		"captured": captured_count,
		"collectors": per,
		"star": star_collected,
		"rulesVersion": int(level.get("rulesVersion", 1)),
	}
