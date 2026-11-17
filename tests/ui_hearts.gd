extends SceneTree
## v1.2 hearts in the real game screen: failed launches cost hearts, a free
## stop does not, and at zero the out-of-hearts panel offers both ways back.
## godot --headless --path . --script res://tests/ui_hearts.gd

const MODE_PLANNING := 0
const MODE_RUNNING := 1

var main: Control
var frames := 0
var failures := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		root.get_node("Save").reset_progress()
		main.open_game(0)
	elif frames == 8:
		_expect(main.current.hearts_row == null, "chapter 1 shows no hearts")
		main.open_game(20)   # chapter 2, level 1
	elif frames == 12:
		var save = root.get_node("Save")
		var g = main.current
		g._close_overlays()
		_expect(g.hearts_row != null and save.hearts_left(g.level) == 3, "chapter 2 starts with 3 hearts")
		# Stop before any ball is lost: free.
		g._start_run()
		g._back_to_planning()
		_expect(save.hearts_left(g.level) == 3, "stopping at once is free")
		# Stop after a ball was lost: costs one heart, once.
		g._start_run()
		g.sim.lost_count = 1
		g._back_to_planning()
		g._back_to_planning()
		_expect(save.hearts_left(g.level) == 2, "stopping after a lost ball costs one heart (left %d)" % save.hearts_left(g.level))
		# Two failed launches: out of hearts.
		for i in 2:
			g._start_run()
			g._on_fail()
			g._back_to_planning()
		_expect(save.hearts_left(g.level) == 0, "two failed launches leave 0 hearts")
		g._start_run()
		_expect(g.mode == MODE_PLANNING and g.overlay_layer.get_child_count() > 0, "launching with 0 hearts opens the out-of-hearts panel")
		# Watch the ad (fake backend completes at once): hearts back, lines kept.
		g.plan.strokes.append(PackedVector2Array([Vector2(100, 100), Vector2(300, 140)]))
		g._close_overlays()
		root.get_node("Ads").show_rewarded(func(): g._refill_hearts())
		_expect(save.hearts_left(g.level) == 3 and g.plan.strokes.size() == 1, "the video gives 3 hearts and keeps the lines")
		# A win refills.
		save.set_hearts(g.level, 1)
		g._refill_hearts()
		_expect(save.hearts_left(g.level) == 3, "refill restores 3 hearts")
		save.reset_progress()
		print("UI hearts: %s" % ("PASS" if failures == 0 else "FAIL"))
		quit(1 if failures > 0 else 0)
	return false


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
