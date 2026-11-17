extends SceneTree
## Prints each level's stored-solution rail length (board units).
func _init() -> void:
	for path in LevelData.level_paths():
		var lv := LevelData.load_level(path)
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(lv)
		var ink := 0.0
		for r in rails:
			ink += StrokeTools.path_length(r)
		print("%s|%s|%s|%d|%d" % [lv.levelId, LevelData.title(lv, "en"), str(lv.get("difficulty", "")), rails.size(), int(round(ink))])
	quit()
