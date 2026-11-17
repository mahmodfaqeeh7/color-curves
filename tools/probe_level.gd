extends SceneTree
## Dev tool: quick status of levels while designing.
## godot --headless --path . --script res://tools/probe_level.gd -- --ids=c4_01,c4_02
const OFFSETS := [Vector2(0, 0), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
	Vector2(2, 2), Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2)]

func _init() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
	for path in LevelData.level_paths():
		var level := LevelData.load_level(path)
		var id: String = level.levelId
		if not ids.is_empty() and not id in ids and not id.substr(0, 2) in ids:
			continue
		var errs := LevelData.validate(level)
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(level)
		var bad := ""
		for r in rails:
			var why := StrokeTools.validate(r, level)
			if why != "":
				bad = why
		var sim := ColorSim.new(level, rails)
		var reasons := {}
		while sim.state == ColorSim.State.RUNNING and sim.tick <= sim.duration_ticks:
			sim.step()
			for e in sim.events:
				if e.type == "lost":
					reasons[e.reason] = int(reasons.get(e.reason, 0)) + 1
		var res := sim.result()
		var robust := 0
		if res.won:
			for off in OFFSETS:
				var moved: Array = []
				var ok := true
				for s in rails:
					var m := PackedVector2Array()
					for p in s:
						m.append(p + off)
					if StrokeTools.validate(m, level) != "":
						ok = false
					moved.append(m)
				if ok and ColorSim.new(level, moved).run_to_end().won:
					robust += 1
		var empty := ColorSim.new(level, []).run_to_end()
		print("%s %s caps=%s lost=%s robust=%d/9 t=%.1fs empty=%s%s%s" % [id, "WON " if res.won else "fail", str(res.collectors.map(func(c): return c.count)), str(reasons), robust, res.ticks / 60.0,
			"WINS!" if empty.won else "ok", (" INVALID_STROKE:" + bad) if bad != "" else "", (" ERR:" + str(errs)) if not errs.is_empty() else ""])
	quit()
