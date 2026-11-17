extends SceneTree
## Prints a per-level fingerprint (result + final ball positions) of every
## stored solution. Used to prove engine changes leave old levels identical.
## godot --headless --path . --script res://tools/fingerprint.gd
func _init() -> void:
	for path in LevelData.level_paths():
		var lv := LevelData.load_level(path)
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(lv)
		var sim := ColorSim.new(lv, rails)
		var r := sim.run_to_end()
		var h := 0
		for b in sim.balls:
			h = hash([h, snappedf(b.pos.x, 0.001), snappedf(b.pos.y, 0.001), b.color, b.captured])
		print("%s won=%s ticks=%d launched=%d lost=%d captured=%d hash=%d" % [lv.levelId, r.won, r.ticks, r.launched, r.lost, r.captured, h])
	quit()
