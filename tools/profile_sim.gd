extends SceneTree
## Measures simulation cost per tick for every level's stored solution.
## godot --headless --path . --script res://tools/profile_sim.gd
func _init() -> void:
	var worst := 0.0
	var worst_id := ""
	for path in LevelData.level_paths():
		var lv := LevelData.load_level(path)
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(lv)
		var sim := ColorSim.new(lv, rails)
		var t0 := Time.get_ticks_usec()
		var peak := 0
		var ticks := 0
		while sim.state == ColorSim.State.RUNNING and ticks < 3000:
			var a := Time.get_ticks_usec()
			sim.step()
			peak = maxi(peak, Time.get_ticks_usec() - a)
			ticks += 1
		var avg := float(Time.get_ticks_usec() - t0) / maxi(1, ticks)
		print("%s avg %.3f ms/tick  peak %.3f ms  (%d ticks)" % [lv.levelId, avg / 1000.0, peak / 1000.0, ticks])
		if avg > worst:
			worst = avg
			worst_id = lv.levelId
	print("WORST avg %.3f ms/tick on %s (budget at 60 FPS: 16.67 ms/frame)" % [worst / 1000.0, worst_id])
	quit()
