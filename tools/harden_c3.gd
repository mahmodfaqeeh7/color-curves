extends SceneTree
## v1.2 Chapter 3 rework: makes each level harder without breaking its
## proven solution. For every c3 level it adds
##   1. a rock "cup" around each goal, open only where the solution's balls
##      enter (a narrow entry), and
##   2. up to three poison pools right next to the winning path.
## Every addition is kept only if the stored solution still wins robustly
## (>= 6 of 9 small shifts). Output: tools/c3_extras.json, applied by
## build_levels.py.
##
## Run on the BASE levels:
##   BUILD_NO_EXTRAS=1 python3 tools/build_levels.py
##   godot --headless --path . --script res://tools/harden_c3.gd
##   python3 tools/build_levels.py

const OFFSETS := [
	Vector2(0, 0), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
	Vector2(2, 2), Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2),
]
const OUT := "res://tools/c3_extras.json"
const SEGS := 12


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var out := {}
	for path in LevelData.level_paths():
		var level := LevelData.load_level(path)
		var id: String = level.levelId
		if not id.begins_with("c3_") or (only != "" and id != only):
			continue
		var extras := harden(level)
		out[id] = extras
		var kinds := {}
		for e in extras:
			kinds[e.type] = int(kinds.get(e.type, 0)) + 1
		print("%s %s" % [id, str(kinds)])
	var keys := out.keys()
	keys.sort()
	var lines: Array = []
	for k in keys:
		lines.append('"%s": %s' % [k, JSON.stringify(out[k])])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lines) + "\n}\n")
	quit()


static func shifted(rails: Array, d: Vector2) -> Array:
	var out: Array = []
	for r in rails:
		var pr := PackedVector2Array()
		for p in r:
			pr.append(p + d)
		out.append(pr)
	return out


## Wins out of 9 shifted solutions (invalid drawings count as losses); -1 if
## the unshifted solution itself fails.
static func robustness(level: Dictionary, rails: Array) -> int:
	var wins := 0
	for i in OFFSETS.size():
		var moved := shifted(rails, OFFSETS[i])
		var ok := true
		for s in moved:
			if StrokeTools.validate(s, level) != "":
				ok = false
		if ok and ColorSim.new(level, moved).run_to_end().won:
			wins += 1
		elif i == 0:
			return -1
	return wins


static func with_extras(level: Dictionary, extras: Array) -> Dictionary:
	var lv := level.duplicate(true)
	lv["rulesVersion"] = 3
	lv.obstacles.append_array(extras)
	return lv


func harden(level: Dictionary) -> Array:
	var rails: Array = load("res://tools/verify_levels.gd").load_solution(level)
	var base := robustness(level, rails)
	if base < 5:
		return []
	var need := maxi(6, base - 1) if base >= 6 else base
	# Where balls travel and from where they enter each goal, over all shifts.
	var trace := PackedVector2Array()
	var entries := {}
	for c in level.collectors:
		entries[c.id] = []
	for d in OFFSETS:
		var sim := ColorSim.new(level, shifted(rails, d))
		var guard := 0
		while sim.state == ColorSim.State.RUNNING and guard < 3600:
			sim.step()
			guard += 1
			for e in sim.events:
				if e.type == "capture":
					for c in level.collectors:
						if c.id == e.collector:
							entries[c.id].append((e.pos - LevelData.v2(c.center)).angle())
			if guard % 2 == 0:
				for b in sim.balls:
					if b.alive:
						trace.append(b.pos)
	var extras: Array = []
	# 1. Goal cups, narrowest opening that still works.
	for c in level.collectors:
		for gap_deg in [50.0, 70.0, 95.0, 125.0]:
			var cup := _cup(c, entries[c.id], deg_to_rad(gap_deg))
			if cup.is_empty():
				continue
			var trial := extras + cup
			if robustness(with_extras(level, trial), rails) >= need:
				extras = trial
				break
	# 2. Poison pools beside the path.
	var cands: Array = []
	var bs := LevelData.board_size(level)
	var rail_pts := PackedVector2Array()
	for r in rails:
		rail_pts.append_array(r)
	var y := 45.0
	while y < bs.y - 30.0:
		var x := 60.0
		while x < bs.x - 50.0:
			var p := Vector2(x, y)
			var dt := _min_dist(p, trace)
			if dt >= 46.0 and dt <= 84.0 and _min_dist(p, rail_pts) >= 40.0 and _clear(level, extras, p):
				cands.append([dt, p])
			x += 28.0
		y += 28.0
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var placed: Array = []
	for cd in cands:
		if placed.size() >= 3:
			break
		var p: Vector2 = cd[1]
		var far := true
		for q in placed:
			if p.distance_to(q) < 170.0:
				far = false
		if not far:
			continue
		var pool := {"id": "PX%d" % placed.size(), "type": "poison", "shape": "rect",
			"center": [p.x, p.y], "size": [62, 20], "rotation": 0}
		var trial := extras + [pool]
		if robustness(with_extras(level, trial), rails) >= need:
			extras = trial
			placed.append(p)
	return extras


static func _min_dist(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for q in pts:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


## Far enough from launchers, goals and every existing piece.
func _clear(level: Dictionary, extras: Array, p: Vector2) -> bool:
	for l in level.launchers:
		if p.distance_to(LevelData.v2(l.pos)) < 110.0:
			return false
	for c in level.collectors:
		if p.distance_to(LevelData.v2(c.center)) < float(c.innerRadius) + 75.0:
			return false
	for o in level.obstacles + extras:
		var poly := LevelData.polygon_of(o)
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			if p.distance_to(q) < 46.0:
				return false
	return true


## Rock ring around a goal, split into runs of segments; segments within
## `gap` of any entry direction are left open.
func _cup(c: Dictionary, entry_angles: Array, gap: float) -> Array:
	if entry_angles.is_empty():
		return []
	var center := LevelData.v2(c.center)
	var r0 := float(c.innerRadius) + 9.0
	var r1 := r0 + 12.0
	var keep: Array = []
	for i in SEGS:
		var mid := TAU * (i + 0.5) / SEGS
		var open := false
		for a in entry_angles:
			if absf(angle_difference(mid, a)) < gap:
				open = true
				break
		keep.append(not open)
	if not true in keep:
		return []
	# Merge neighbouring kept segments into arc-shaped rocks.
	var out: Array = []
	var start := 0
	if not false in keep:
		return []   # never close a goal completely
	while keep[start]:
		start += 1   # begin just after an opening
	var i := 0
	var n := 0
	while i < SEGS:
		var idx := (start + i) % SEGS
		if not keep[idx]:
			i += 1
			continue
		var run := 0
		while run + i < SEGS and keep[(start + i + run) % SEGS]:
			run += 1
		var a0 := TAU * float((start + i) % SEGS) / SEGS
		var a1 := a0 + TAU * run / SEGS
		var pts: Array = []
		var steps := mini(run * 2, 14)
		for k in steps + 1:
			var a := lerpf(a0, a1, float(k) / steps)
			pts.append([snappedf(center.x + cos(a) * r1, 0.1), snappedf(center.y + sin(a) * r1, 0.1)])
		for k in steps + 1:
			var a := lerpf(a1, a0, float(k) / steps)
			pts.append([snappedf(center.x + cos(a) * r0, 0.1), snappedf(center.y + sin(a) * r0, 0.1)])
		if pts.size() <= 32:
			out.append({"id": "CUP_%s_%d" % [c.id, n], "type": "rock", "shape": "poly", "points": pts})
			n += 1
		i += run
	return out
