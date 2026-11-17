extends SceneTree
## Level verification: every level must (1) pass structural validation,
## (2) be won by its stored solution within all budgets, (3) NOT be won with an
## empty drawing, and (4) tolerate small offsets of the solution.
##
## godot --headless --path . --script res://tools/verify_levels.gd [-- --only=c1_03 --verbose]

const OFFSETS := [
	Vector2(0, 0), Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
	Vector2(2, 2), Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2),
]


func _init() -> void:
	var only := ""
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a == "--verbose":
			verbose = true
	var failures := 0
	for path in LevelData.level_paths():
		var level := LevelData.load_level(path)
		if only != "" and level.get("levelId") != only:
			continue
		var r := verify(level, verbose)
		if not r.ok:
			failures += 1
		print(r.line)
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


static func load_solution(level: Dictionary) -> Array:
	var sol = LevelData.read_json(LevelData.solution_path(level.levelId))
	if typeof(sol) != TYPE_DICTIONARY:
		return []
	return PlanState.strokes_from_data(sol.get("strokes", []))


static func verify(level: Dictionary, verbose := false) -> Dictionary:
	var id: String = level.get("levelId", "?")
	var problems: Array = LevelData.validate(level)
	var rails := load_solution(level)
	if rails.is_empty():
		problems.append("no solution")
	var plan := PlanState.new(level)
	for i in rails.size():
		var why := StrokeTools.validate(rails[i], level)
		if why != "":
			problems.append("solution stroke %d invalid: %s" % [i, why])
		elif plan.check_add(rails[i]) != "":
			problems.append("solution stroke %d over budget: %s" % [i, plan.check_add(rails[i])])
		else:
			plan.add(rails[i])
	var res := {}
	if problems.is_empty():
		res = ColorSim.new(level, rails).run_to_end()
		if not res.won:
			problems.append("solution does not win (%s, %s)" % [res.reason, str(res.collectors)])
	var empty := ColorSim.new(level, []).run_to_end()
	if empty.won:
		problems.append("level is won with no drawing")
	# v1.1 map star: the stored solution must win AND collect it; an empty
	# board must not reach it.
	var has_star := level.has("star")
	if not has_star:
		problems.append("no map star")
	elif not res.is_empty() and not res.star:
		problems.append("stored solution does not collect the star")
	if has_star and empty.star:
		problems.append("the star is collected with no drawing")
	var star_robust := 0
	var robust := 0
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
		if ok:
			var mr := ColorSim.new(level, moved).run_to_end()
			if mr.won:
				robust += 1
				if mr.star:
					star_robust += 1
	var line := "%s %-6s strokes=%d/%s par=%s robust=%d/%d" % [
		"OK  " if problems.is_empty() else "FAIL", id, rails.size(),
		str(level.get("drawingRules", {}).get("maxStrokes")),
		str(level.get("scoring", {}).get("parStrokes")), robust, OFFSETS.size()]
	line += " star=%d/%d" % [star_robust, OFFSETS.size()]
	if not res.is_empty():
		line += " t=%.1fs launched=%d lost=%d" % [res.ticks / 60.0, res.launched, res.lost]
	line += " empty=%s%s" % [empty.reason, str(empty.collectors.map(func(c): return c.count))]
	if not problems.is_empty():
		line += "\n      " + "\n      ".join(problems)
	return {"ok": problems.is_empty() and robust >= 5, "line": line}
