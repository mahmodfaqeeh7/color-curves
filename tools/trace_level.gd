extends SceneTree
## Dev tool: dumps level geometry + ball trajectories for render_trace.py.
## godot --headless --path . --script res://tools/trace_level.gd -- --only=c1_01 [--empty] --out=/path.json

func _init() -> void:
	var only := ""
	var out := "user://trace.json"
	var empty := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
		if a.begins_with("--out="): out = a.substr(6)
		if a == "--empty": empty = true
	for path in LevelData.level_paths():
		var level := LevelData.load_level(path)
		if level.levelId != only:
			continue
		var rails: Array = [] if empty else load("res://tools/verify_levels.gd").load_solution(level)
		var sim := ColorSim.new(level, rails)
		var paths := {}
		while sim.state != ColorSim.State.FAILED and sim.tick < sim.duration_ticks and not (sim.state == ColorSim.State.WON and sim.tick > sim.win_tick + 30):
			sim.step()
			for b in sim.balls:
				if b.alive:
					if not paths.has(b.id): paths[b.id] = []
					paths[b.id].append([b.pos.x, b.pos.y, b.color])
		var polys := []
		for o in level.obstacles:
			var pts := []
			for p in LevelData.polygon_of(o): pts.append([p.x, p.y])
			polys.append({"type": o.type, "color": o.get("color", ""), "points": pts})
		var rl := []
		for r in rails:
			var pts := []
			for p in r: pts.append([p.x, p.y])
			rl.append(pts)
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"level": level, "polys": polys, "rails": rl, "paths": paths.values(), "result": sim.result()}))
		print(sim.result())
	quit()
