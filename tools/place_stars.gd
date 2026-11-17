extends SceneTree
## Places the v1.1 map star of every level and writes tools/stars.json, which
## tools/build_levels.py copies into the levels.
##
## The star goes where the stored solution's balls fly freely (so it is
## provably collectible), away from where an empty board sends the balls (so
## it needs a drawn line), away from launchers, goals and the solution's own
## rails, and preferably where most slightly-shifted solutions still pass.
##
## godot --headless --path . --script res://tools/place_stars.gd [-- --only=c1_03]

const OFFSETS := [
	Vector2(0, 0), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
	Vector2(2, 2), Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2),
]
const TOUCH := 20.0   ## star radius (14) + ball radius (6)
const OUT := "res://tools/stars.json"


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var stars := {}
	if FileAccess.file_exists(OUT):
		var old = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if typeof(old) == TYPE_DICTIONARY:
			stars = old
	for path in LevelData.level_paths():
		var level := LevelData.load_level(path)
		var id: String = level.levelId
		if only != "" and id != only:
			continue
		var r := place(level)
		if r.is_empty():
			print("NO SPOT  %s" % id)
			continue
		stars[id] = [int(round(r.pos.x)), int(round(r.pos.y))]
		print("STAR %s at %s  shifted-solutions %d/9  empty-board distance %.0f" % [id, stars[id], r.robust, r.empty_d])
	var keys := stars.keys()
	keys.sort()
	var lines: Array = []
	for k in keys:
		lines.append('"%s": %s' % [k, JSON.stringify(stars[k])])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
	quit()


## Ball positions of one run: every tick, every live ball.
## airborne_only keeps only balls touching nothing (free flight).
static func trace(level: Dictionary, rails: Array, airborne_only: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sim := ColorSim.new(level, rails)
	var guard := 0
	while sim.state == ColorSim.State.RUNNING and guard < 60 * 60:
		sim.step()
		guard += 1
		for b in sim.balls:
			if b.alive and not b.captured and (not airborne_only or b.contacts.is_empty()):
				pts.append(b.pos)
	return pts


static func min_dist(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for q in pts:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


## Distance from p to a polygon's outline (0 when p is inside it).
static func _poly_gap(p: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return best


static func _candidates(src: PackedVector2Array, bs: Vector2) -> PackedVector2Array:
	var cands := PackedVector2Array()
	for i in range(0, src.size(), 4):
		var p := src[i]
		if p.x < 30 or p.y < 30 or p.x > bs.x - 30 or p.y > bs.y - 30:
			continue
		if not cands.is_empty() and min_dist(p, cands) < 12.0:
			continue
		cands.append(p)
	return cands


static func shifted(rails: Array, d: Vector2) -> Array:
	var out: Array = []
	for r in rails:
		var pr := PackedVector2Array()
		for p in r:
			pr.append(p + d)
		out.append(pr)
	return out


static func place(level: Dictionary) -> Dictionary:
	var rails: Array = load("res://tools/verify_levels.gd").load_solution(level)
	if rails.is_empty():
		return {}
	var bs := LevelData.board_size(level)
	var flight := trace(level, rails, true)
	var empty := trace(level, [], false)
	var rail_pts := PackedVector2Array()
	for r in rails:
		rail_pts.append_array(r)
	var variants: Array = []
	for d in OFFSETS:
		variants.append(trace(level, shifted(rails, d), false))
	var rolling := trace(level, rails, false)
	# Pieces the star must not cover (zones are see-through areas, so they may).
	var solids: Array = []
	for o in level.get("obstacles", []):
		if str(o.get("type", "")) != "zone":
			solids.append(LevelData.polygon_of(o))
	var launchers: Array = []
	for l in level.get("launchers", []):
		launchers.append(LevelData.v2(l.pos))
	# Candidates: every 4th free-flight sample, thinned to one per 12 px; the
	# last tier also tries spots where balls roll along a line.
	var cands := _candidates(flight, bs)
	var cands_all := _candidates(rolling, bs)
	# Strict first, then gentler limits for levels whose free flight is short.
	# [empty-board gap, rail gap, shifted solutions needed, launcher gap, goal gap]
	for tier in [[80.0, 34.0, 6, 90.0, 50.0], [50.0, 34.0, 6, 90.0, 50.0], [30.0, 34.0, 6, 90.0, 50.0],
			[24.0, 24.0, 4, 90.0, 50.0], [24.0, 24.0, 4, 60.0, 22.0], [24.0, 18.0, 3, 60.0, 22.0],
			[24.0, 10.0, 4, 60.0, 22.0, true],
			# Balls that roll on a line or a slab all the way: the star sits on the rolling path.
			[24.0, 5.0, 4, 60.0, 22.0, true, 4.0]]:
		var need_empty: float = tier[0]
		var rail_gap: float = tier[1]
		var need_robust: int = tier[2]
		var launch_gap: float = tier[3]
		var goal_gap: float = tier[4]
		var best := {}
		for p in (cands_all if tier.size() > 5 else cands):
			var ok := true
			for lp in launchers:
				if p.distance_to(lp) < launch_gap:
					ok = false
			for c in level.get("collectors", []):
				if p.distance_to(LevelData.v2(c.center)) < float(c.innerRadius) + goal_gap:
					ok = false
			for poly in solids:
				if ok and _poly_gap(p, poly) < (float(tier[6]) if tier.size() > 6 else 22.0):
					ok = false
			if not ok or min_dist(p, rail_pts) < rail_gap:
				continue
			var ed := min_dist(p, empty) if not empty.is_empty() else 999.0
			if ed < need_empty:
				continue
			var robust := 0
			for v in variants:
				if min_dist(p, v) <= TOUCH - 2.0:
					robust += 1
			var score := robust * 1000.0 + minf(ed, 200.0)
			if best.is_empty() or score > best.score:
				best = {"pos": p, "robust": robust, "empty_d": ed, "score": score}
		if not best.is_empty() and best.robust >= need_robust:
			return best
	return {}
