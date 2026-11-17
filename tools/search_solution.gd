extends SceneTree
## Dev tool: hill-climbs stroke control points (Catmull-Rom, same as
## build_levels.py) until the level is won robustly. Prints the best control
## points to paste back into build_levels.py.
## godot --headless --path . --script res://tools/search_solution.gd -- --only=c1_07 --ctrl='[[[105,95],[300,200]]]' --iters=200 --sigma=20 --seed=1

const OFFSETS := [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
	Vector2(2, 2), Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2)]

var level: Dictionary


static func curve(ctrl: Array) -> PackedVector2Array:
	var pts: Array = []
	for p in ctrl:
		pts.append(Vector2(p[0], p[1]))
	var out := PackedVector2Array()
	if pts.size() == 2:
		var k: int = max(2, int(pts[0].distance_to(pts[1]) / 8))
		for i in k + 1:
			out.append(pts[0].lerp(pts[1], float(i) / k))
		return out
	var ext: Array = [pts[0]] + pts + [pts[pts.size() - 1]]
	for i in range(1, ext.size() - 2):
		var p0: Vector2 = ext[i - 1]
		var p1: Vector2 = ext[i]
		var p2: Vector2 = ext[i + 1]
		var p3: Vector2 = ext[i + 2]
		var seg: int = max(3, int(p1.distance_to(p2) / 8))
		for j in seg:
			var t := float(j) / seg
			out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
	out.append(pts[pts.size() - 1])
	return out


func build(ctrl: Array) -> Array:
	var rails: Array = []
	for s in ctrl:
		rails.append(curve(s))
	return rails


func valid(rails: Array) -> bool:
	var plan := PlanState.new(level)
	for r in rails:
		if StrokeTools.validate(r, level) != "" or plan.check_add(r) != "":
			return false
		plan.add(r)
	return true


func score(rails: Array) -> float:
	var sim := ColorSim.new(level, rails)
	var best_d := {}
	for c in sim.collectors:
		best_d[c.id] = 1000.0
	while sim.state == ColorSim.State.RUNNING and sim.tick <= sim.duration_ticks:
		sim.step()
		if sim.tick % 3 == 0:
			for b in sim.balls:
				if b.alive:
					for c in sim.collectors:
						if b.color == c.target:
							best_d[c.id] = min(best_d[c.id], b.pos.distance_to(c.center))
	var r := sim.result()
	if r.won:
		var robust := 0
		for off in OFFSETS:
			var moved: Array = []
			for s in rails:
				var m := PackedVector2Array()
				for p in s:
					m.append(p + off)
				moved.append(m)
			if valid(moved) and ColorSim.new(level, moved).run_to_end().won:
				robust += 1
		# Prefer robust, then no losses, then shorter rails (ink budgets use S).
		var ink := 0.0
		for rr in rails:
			ink += StrokeTools.path_length(rr)
		return 1000.0 + robust * 100.0 - r.lost * 5.0 - ink * 0.02
	var sc: float = r.captured * 60.0
	for k in best_d:
		sc -= best_d[k] * 0.5
	return sc


func _init() -> void:
	var only := ""
	var ctrl: Array = []
	var iters := 150
	var sigma := 15.0
	var sd := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
		if a.begins_with("--ctrl="): ctrl = JSON.parse_string(a.substr(7))
		if a.begins_with("--iters="): iters = int(a.substr(8))
		if a.begins_with("--sigma="): sigma = float(a.substr(8))
		if a.begins_with("--seed="): sd = int(a.substr(7))
	for path in LevelData.level_paths():
		var lv := LevelData.load_level(path)
		if lv.levelId == only:
			level = lv
	seed(sd)
	var best := ctrl
	var best_s := score(build(ctrl)) if valid(build(ctrl)) else -1e9
	print("start ", best_s)
	for it in iters:
		if best_s >= 1000.0 + OFFSETS.size() * 100.0 - 25.0 and it > iters / 2:
			break
		var sg := sigma * (1.0 - 0.7 * float(it) / iters)
		var cand: Array = []
		for s in best:
			var ns: Array = []
			for p in s:
				ns.append([roundf(p[0] + randfn(0, sg)), roundf(p[1] + randfn(0, sg))])
			cand.append(ns)
		var rails := build(cand)
		if not valid(rails):
			continue
		var sc := score(rails)
		if sc > best_s:
			best_s = sc
			best = cand
			print("it %d score %.1f %s" % [it, sc, JSON.stringify(best)])
	print("BEST %.1f %s" % [best_s, JSON.stringify(best)])
	quit()
