extends SceneTree
## Headless test suite for the rules in the spec (section 14).
## godot --headless --path . --script res://tests/run_tests.gd

var passed := 0
var failed := 0
var _current := ""


func _init() -> void:
	var tests := [
		"test_paint_once_per_contact_entry",
		"test_last_contact_color_wins",
		"test_wrong_color_passes_then_returns",
		"test_five_captures_win_once",
		"test_duplicate_capture_impossible",
		"test_capture_when_centre_inside_circle",
		"test_ad_rules",
		"test_heart_rules",
		"test_v3_poison",
		"test_v3_lava_kills_and_burns_lines",
		"test_v3_fan_pushes",
		"test_v3_conveyor_carries",
		"test_v3_glass_breaks",
		"test_v3_door_opens_and_closes",
		"test_v3_portal_teleports",
		"test_v3_black_hole_swallows",
		"test_v3_magnet_pulls_own_colour",
		"test_v3_mixer_mixes",
		"test_v3_validation",
		"test_map_star_collected_once",
		"test_map_star_does_not_change_physics",
		"test_full_collector_ignores_balls",
		"test_multi_collector_needs_all",
		"test_impossible_count_fails_early",
		"test_wrong_color_ball_not_counted_lost",
		"test_win_stops_spawning",
		"test_no_tunneling_through_thin_rail",
		"test_simultaneous_paint_tie_break",
		"test_retry_is_deterministic",
		"test_stroke_validation",
		"test_tiny_and_invalid_strokes_cost_nothing",
		"test_undo_redo_delete_clear_budget",
		"test_ink_budget",
		"test_ranking_order",
		"test_all_levels_verified",
		"test_gate_passes_only_its_color",
		"test_switch_wall_opens_for_its_color_and_stays_open",
		"test_splitter_doubles_once",
		"test_splitter_cap",
		"test_bumper_rebounds_harder_without_paint",
		"test_flip_pad_flips_gravity",
		"test_booster_accelerates",
		"test_gravity_zone_and_zero_g",
		"test_ordered_goals",
		"test_power_launcher_no_tunneling",
		"test_splitter_disables_early_fail",
		"test_stuck_waits_for_switch",
		"test_new_piece_validation",
		"test_drawing_rules_for_new_pieces",
		"test_chapter1_fingerprint_unchanged",
		"test_split_at_length",
		"test_rock_blocks_balls_and_drawing",
		"test_chapter2_ink_budgets_follow_formula",
		"test_chapter2_levels_use_new_board",
		"test_chapter3_hard_mixed_levels",
		"test_every_level_text_has_arabic",
		"test_save_atomic_write_keeps_backup",
		"test_save_recovers_from_damaged_file",
		"test_save_migrates_v1",
		"test_piece_cards_and_demos",
		"test_every_level_has_a_hint_solution",
	]
	for t in tests:
		_current = t
		call(t)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL [%s] %s" % [_current, msg])


# ------------------------------------------------------------------ helpers

func make_level(over: Dictionary = {}) -> Dictionary:
	var lv := {
		"schemaVersion": 1, "levelId": "test", "revision": 1, "rulesVersion": 1,
		"board": {"width": 640, "height": 360}, "gravity": [0, 0],
		"material": {"obstacle": {"restitution": 1.0, "friction": 0.0},
			"rail": {"restitution": 1.0, "friction": 0.0}},
		"runDurationLimit": 45, "ballLifetime": 20,
		"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6,
			"colors": ["blue"], "count": 5, "interval": 30.0}],
		"obstacles": [],
		"collectors": [{"id": "C1", "center": [560, 60], "innerRadius": 24, "targetColor": "red", "requiredCount": 5}],
		"drawingRules": {"maxStrokes": 3, "maxInkLength": null, "minStrokeLength": 12, "railWidth": 6, "forbiddenZones": []},
	}
	lv.merge(over, true)
	return lv


func rect(id: String, cx: float, cy: float, w: float, h: float, color := "") -> Dictionary:
	var o := {"id": id, "type": "painter" if color != "" else "neutral", "shape": "rect",
		"center": [cx, cy], "size": [w, h], "rotation": 0}
	if color != "":
		o["color"] = color
	return o


func line(a: Vector2, b: Vector2, n: int = 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		p.append(a.lerp(b, float(i) / n))
	return p


func run_collect(sim: ColorSim, ticks: int) -> Array:
	var all: Array = []
	for i in ticks:
		sim.step()
		all.append_array(sim.events.duplicate())
	return all


func count_type(events: Array, t: String) -> int:
	return events.filter(func(e): return e.type == t).size()


# ------------------------------------------------------------------ colour

func test_paint_once_per_contact_entry() -> void:
	# Ball starts resting on top of a long red slab and rolls along it.
	var lv := make_level({
		"gravity": [0, 420],
		"launchers": [{"id": "L1", "pos": [100, 193.5], "velocity": [120, 0], "ballRadius": 6,
			"colors": ["blue"], "count": 5, "interval": 30.0}],
		"obstacles": [rect("R", 300, 210, 500, 20, "red")],
	})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 120)
	check(count_type(ev, "paint") == 1, "continuous contact must paint exactly once (got %d)" % count_type(ev, "paint"))
	check(sim.balls[0].color == "red", "blue ball touching red becomes red")


func test_last_contact_color_wins() -> void:
	# Ball hits green wall, bounces back onto a neutral rail and stays green.
	var lv := make_level({
		"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6,
			"colors": ["red"], "count": 5, "interval": 30.0}],
		"obstacles": [rect("G", 400, 180, 20, 100, "green")],
	})
	var rail := line(Vector2(40, 140), Vector2(40, 220))
	var sim := ColorSim.new(lv, [rail])
	var ev := run_collect(sim, 150)
	var paints := ev.filter(func(e): return e.type == "paint")
	check(paints.size() >= 1 and paints[0].to == "green", "red ball turns green on the pentagon/wall")
	check(count_type(ev, "bounce") >= 2, "ball bounced off wall and rail")
	check(sim.balls[0].color == "green", "neutral rail keeps the ball green")


func test_wrong_color_passes_then_returns() -> void:
	# Blue ball crosses a red collector (no count), hits a red wall, returns red.
	var lv := make_level({
		"obstacles": [rect("R", 450, 180, 20, 120, "red")],
		"collectors": [{"id": "C1", "center": [250, 180], "innerRadius": 24, "targetColor": "red", "requiredCount": 5}],
		"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6,
			"colors": ["blue"], "count": 5, "interval": 30.0}],
	})
	var sim := ColorSim.new(lv, [])
	var ev: Array = []
	for i in 40:
		sim.step()
		ev.append_array(sim.events.duplicate())
	check(count_type(ev, "pass") == 1, "wrong colour passes once with feedback")
	check(sim.collectors[0].count == 0, "wrong colour adds zero")
	ev.append_array(run_collect(sim, 80))
	check(sim.collectors[0].count == 1, "correctly coloured re-entry adds one")


func _stream_level(count: int, required_colors: Array, launcher_color := "red") -> Dictionary:
	var cols: Array = []
	var x := 300.0
	for c in required_colors:
		cols.append({"id": "C_" + str(c), "center": [x, 180], "innerRadius": 24, "targetColor": c, "requiredCount": 5})
		x += 120.0
	return make_level({
		"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6,
			"colors": [launcher_color], "count": count, "interval": 0.2}],
		"collectors": cols,
	})


func test_five_captures_win_once() -> void:
	var sim := ColorSim.new(_stream_level(8, ["red"]), [])
	var ev := run_collect(sim, 600)
	check(sim.state == ColorSim.State.WON, "fifth matching capture wins")
	check(count_type(ev, "win") == 1, "win event fires exactly once")
	check(sim.collectors[0].count == 5, "count is exactly five")
	check(count_type(ev, "capture") == 5, "five capture events")


## v1.1 ads: every 5 wins, at least 3 minutes apart, only after 8 completed
## levels, never after "Remove ads".
func test_ad_rules() -> void:
	check(AdRules.interstitial_due(5, INF, 8, false), "5 wins, 8 levels done, no recent ad: due")
	check(not AdRules.interstitial_due(4, INF, 20, false), "4 wins: not yet")
	check(not AdRules.interstitial_due(5, INF, 7, false), "only 7 levels completed: no ads for new players")
	check(not AdRules.interstitial_due(5, 120.0, 20, false), "2 minutes since the last ad: too soon")
	check(AdRules.interstitial_due(6, 181.0, 20, false), "just over 3 minutes: due")
	check(not AdRules.interstitial_due(50, INF, 60, true), "never after Remove ads")


## v1.2 hearts: chapters 2+, one per failed launch, free stop before a loss.
func test_heart_rules() -> void:
	check(not HeartRules.uses_hearts({"chapter": 1}), "chapter 1 has no hearts")
	check(HeartRules.uses_hearts({"chapter": 2}) and HeartRules.uses_hearts({"chapter": 5}), "chapters 2 to 5 use hearts")
	check(HeartRules.run_costs_heart(true, 0), "a failed launch costs a heart")
	check(not HeartRules.run_costs_heart(false, 0), "stopping before any ball is lost is free")
	check(HeartRules.run_costs_heart(false, 1), "stopping after a ball is lost costs a heart")
	var lv := {"levelId": "t_hearts", "chapter": 2}
	var sv = load("res://scripts/autoload/save.gd").new()
	sv.path = "user://test_hearts.json"
	sv.set_hearts(lv, HeartRules.MAX)
	check(sv.hearts_left(lv) == 3 and not sv.hearts.has("t_hearts"), "full hearts are not stored")
	sv.set_hearts(lv, 1)
	check(sv.hearts_left(lv) == 1, "hearts are remembered per level")
	sv.flush()
	var sv2 = load("res://scripts/autoload/save.gd").new()
	sv2.path = "user://test_hearts.json"
	sv2.load_data()
	check(sv2.hearts_left(lv) == 1, "hearts survive closing the app")
	sv.set_hearts(lv, -4)
	check(sv.hearts_left(lv) == 0, "hearts never go below zero")
	sv.free()
	sv2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hearts.json"))


## v1.1 map star: a ball that passes through it collects it exactly once.
func test_map_star_collected_once() -> void:
	var lv := _stream_level(8, ["red"])
	lv["star"] = {"pos": [200, 180]}   # on the balls' straight path
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 600)
	check(count_type(ev, "star") == 1, "the star event fires once (got %d)" % count_type(ev, "star"))
	check(sim.result().star, "the result reports the star")
	var lv2 := _stream_level(8, ["red"])
	lv2["star"] = {"pos": [200, 60]}   # far above the path
	var sim2 := ColorSim.new(lv2, [])
	run_collect(sim2, 600)
	check(not sim2.result().star, "a star off the path is not collected")


func test_map_star_does_not_change_physics() -> void:
	var a := ColorSim.new(_stream_level(8, ["red"]), [])
	var lv := _stream_level(8, ["red"])
	lv["star"] = {"pos": [200, 180]}
	var b := ColorSim.new(lv, [])
	for i in 300:
		a.step()
		b.step()
	var same := a.balls.size() == b.balls.size()
	for i in mini(a.balls.size(), b.balls.size()):
		same = same and a.balls[i].pos == b.balls[i].pos
	check(same, "balls move exactly the same with or without a star")


## v1.1 hitbox: a ball counts once its centre is inside the circle, even if
## part of it still overlaps the edge; a ball whose centre is outside does not.
func test_capture_when_centre_inside_circle() -> void:
	var sim := ColorSim.new(_stream_level(8, ["red"]), [])
	sim.step()   # running
	var c: Dictionary = sim.collectors[0]
	var edge := ColorSim.Ball.new()
	edge.color = "red"
	edge.radius = 6.0
	edge.pos = c.center + Vector2(c.inner - 2.0, 0)   # centre inside, ball over the edge
	sim._check_collectors(edge)
	check(edge.captured, "a ball half over the edge is caught")
	var outside := ColorSim.Ball.new()
	outside.color = "red"
	outside.radius = 6.0
	outside.pos = c.center + Vector2(0, c.inner + 1.0)   # centre just outside
	sim._check_collectors(outside)
	check(not outside.captured, "a ball whose centre is outside is not caught")


func test_duplicate_capture_impossible() -> void:
	var sim := ColorSim.new(_stream_level(8, ["red"]), [])
	for i in 60:
		sim.step()
	var captured: Array = sim.balls.filter(func(b): return b.captured)
	check(captured.size() >= 1, "at least one capture happened")
	var before: int = sim.collectors[0].count
	sim._check_collectors(captured[0])
	sim._check_collectors(captured[0])
	check(sim.collectors[0].count == before, "repeated callback does not count again")


func test_full_collector_ignores_balls() -> void:
	# Red collector first in line fills; the next red balls must pass it and
	# must not double-score anywhere.
	var lv := _stream_level(12, ["red", "blue"])
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 600)
	check(sim.collectors[0].count == 5, "first collector caps at five")
	check(sim.collectors[1].count == 0, "red balls never count in the blue collector")
	var full_passes := ev.filter(func(e): return e.type == "pass" and e.full)
	check(full_passes.size() >= 1, "later balls pass through the full collector")
	check(sim.state != ColorSim.State.WON, "not won while blue collector is empty")


func test_multi_collector_needs_all() -> void:
	var lv := make_level({
		"launchers": [
			{"id": "L1", "pos": [100, 120], "velocity": [300, 0], "ballRadius": 6, "colors": ["red"], "count": 5, "interval": 0.2},
			{"id": "L2", "pos": [100, 240], "velocity": [300, 0], "ballRadius": 6, "colors": ["blue"], "count": 5, "interval": 0.2, "delay": 1.5},
		],
		"collectors": [
			{"id": "CR", "center": [300, 120], "innerRadius": 24, "targetColor": "red", "requiredCount": 5},
			{"id": "CB", "center": [300, 240], "innerRadius": 24, "targetColor": "blue", "requiredCount": 5},
		],
	})
	var sim := ColorSim.new(lv, [])
	for i in 100:
		sim.step()
	check(sim.collectors[0].count == 5 and sim.state == ColorSim.State.RUNNING, "one full collector is not a win")
	run_collect(sim, 400)
	check(sim.state == ColorSim.State.WON, "wins when every collector is full")


func test_impossible_count_fails_early() -> void:
	# 5 required, 5 supplied, the first ball flies off the board => D > A + U.
	var lv := make_level({
		"launchers": [{"id": "L1", "pos": [600, 180], "velocity": [300, 0], "ballRadius": 6,
			"colors": ["red"], "count": 5, "interval": 1.0}],
	})
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 30)
	check(sim.state == ColorSim.State.FAILED and sim.fail_reason == "not_enough", "fails as soon as D > A + U")


func test_wrong_color_ball_not_counted_lost() -> void:
	# Blue balls bounce inside a closed box; red collector. They are wrong
	# but still active, so the count check must not fail the attempt.
	var lv := make_level({
		"launchers": [{"id": "L1", "pos": [200, 180], "velocity": [150, 90], "ballRadius": 6,
			"colors": ["blue"], "count": 5, "interval": 0.1}],
		"obstacles": [rect("T", 320, 10, 640, 20), rect("B", 320, 350, 640, 20), rect("Lw", 10, 180, 20, 360), rect("Rw", 630, 180, 20, 360)],
	})
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 180)
	check(sim.state == ColorSim.State.RUNNING, "wrong-coloured active balls keep the attempt alive")


func test_win_stops_spawning() -> void:
	var sim := ColorSim.new(_stream_level(15, ["red"]), [])
	run_collect(sim, 400)
	var launched := sim.launched
	run_collect(sim, 400)
	check(sim.state == ColorSim.State.WON, "won")
	check(sim.launched == launched and launched < 15, "no spawning after the win")
	check(sim.result().captured == 5, "score frozen at the win")


# ------------------------------------------------------------------ physics

func test_no_tunneling_through_thin_rail() -> void:
	for speed in [300.0, 720.0, 5000.0]:
		var lv := make_level({
			"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [speed, 37], "ballRadius": 6,
				"colors": ["blue"], "count": 5, "interval": 30.0}],
		})
		var rail := line(Vector2(300, 60), Vector2(300, 300), 30)
		var sim := ColorSim.new(lv, [rail])
		var crossed := false
		for i in 120:
			sim.step()
			for b in sim.balls:
				if b.alive and b.pos.x > 300.0:
					crossed = true
		check(not crossed, "ball at speed %d must not pass a 6-unit rail" % speed)


func test_simultaneous_paint_tie_break() -> void:
	# Ball lands exactly on the seam between two painters: stable ID order.
	var results := {}
	for k in 3:
		var lv := make_level({
			"gravity": [0, 420],
			"launchers": [{"id": "L1", "pos": [150, 150], "velocity": [0, 0], "ballRadius": 6,
				"colors": ["blue"], "count": 5, "interval": 30.0}],
			"obstacles": [rect("a_red", 125, 220, 50, 40, "red"), rect("b_green", 175, 220, 50, 40, "green")],
		})
		var sim := ColorSim.new(lv, [])
		run_collect(sim, 60)
		results[sim.balls[0].color] = true
	check(results.size() == 1, "tie-break is stable across runs")
	check(results.has("green"), "later stable id applies last (b_green)")


func test_retry_is_deterministic() -> void:
	var level := LevelData.load_level("res://levels/c1_12.json")
	var rails: Array = load("res://tools/verify_levels.gd").load_solution(level)
	var a := ColorSim.new(level, rails).run_to_end()
	var sim_b := ColorSim.new(level, rails)
	check(sim_b.tick == 0 and sim_b.launched == 0 and sim_b.collectors[0].count == 0, "fresh attempt starts from zero")
	var b := sim_b.run_to_end()
	check(a.won and b.won, "solution wins")
	check(a.ticks == b.ticks and a.captured == b.captured and a.launched == b.launched, "identical result on retry")


# ------------------------------------------------------------------ drawing

func test_stroke_validation() -> void:
	var lv := make_level({
		"obstacles": [rect("N", 300, 180, 60, 60)],
		"drawingRules": {"maxStrokes": 3, "minStrokeLength": 12, "railWidth": 6,
			"forbiddenZones": [{"rect": [500, 250, 80, 60]}]},
	})
	check(StrokeTools.validate(line(Vector2(200, 180), Vector2(400, 180)), lv) == StrokeTools.OBSTACLE, "crossing an obstacle is rejected")
	check(StrokeTools.validate(line(Vector2(260, 147.5), Vector2(340, 147.5)), lv) == "", "tangent rail within tolerance is accepted")
	check(StrokeTools.validate(line(Vector2(260, 149.0), Vector2(340, 149.0)), lv) == StrokeTools.OBSTACLE, "thick rail penetrating a face is rejected")
	check(StrokeTools.validate(line(Vector2(290, 175), Vector2(310, 185)), lv) == StrokeTools.OBSTACLE, "rail inside a shape is rejected")
	check(StrokeTools.validate(line(Vector2(90, 200), Vector2(140, 200)), lv) == StrokeTools.PROTECTED, "launcher spawn zone is protected")
	check(StrokeTools.validate(line(Vector2(540, 40), Vector2(600, 90)), lv) == StrokeTools.PROTECTED, "collector zone is protected")
	check(StrokeTools.validate(line(Vector2(1, 300), Vector2(50, 300)), lv) == StrokeTools.OUTSIDE, "outside the board is rejected")
	check(StrokeTools.validate(line(Vector2(480, 280), Vector2(620, 280)), lv) == StrokeTools.NO_DRAW, "no-draw zone is rejected")
	var r := StrokeTools.process(line(Vector2(100, 300), Vector2(400, 300), 60), lv)
	check(r.ok, "a clean stroke is accepted")


func test_tiny_and_invalid_strokes_cost_nothing() -> void:
	var lv := make_level({"obstacles": [rect("N", 300, 180, 60, 60)]})
	var plan := PlanState.new(lv)
	var tiny := StrokeTools.process(PackedVector2Array([Vector2(200, 300), Vector2(205, 302)]), lv)
	check(not tiny.ok and tiny.reason == StrokeTools.TOO_SHORT, "tap is too short")
	var bad := StrokeTools.process(line(Vector2(200, 180), Vector2(400, 180)), lv)
	check(not bad.ok, "invalid stroke rejected whole")
	check(plan.used_strokes() == 0, "rejected strokes consume nothing")


func test_undo_redo_delete_clear_budget() -> void:
	var lv := make_level()
	var plan := PlanState.new(lv)
	var s1 := line(Vector2(200, 300), Vector2(300, 300))
	var s2 := line(Vector2(200, 250), Vector2(300, 250))
	var s3 := line(Vector2(200, 200), Vector2(300, 200))
	var s4 := line(Vector2(200, 150), Vector2(300, 150))
	check(plan.add(s1) and plan.add(s2) and plan.add(s3), "three strokes fit a cap of three")
	check(not plan.add(s4) and plan.check_add(s4) == "no_strokes", "fourth stroke refused")
	plan.undo()
	check(plan.used_strokes() == 2, "undo refunds")
	plan.redo()
	check(plan.used_strokes() == 3, "redo reconsumes")
	plan.delete_at(0)
	check(plan.used_strokes() == 2 and plan.strokes[0] == s2, "delete removes the chosen stroke")
	plan.undo()
	check(plan.used_strokes() == 3 and plan.strokes[0] == s1, "undo restores a deleted stroke in place")
	plan.clear()
	check(plan.used_strokes() == 0, "clear empties")
	plan.undo()
	check(plan.used_strokes() == 3, "undo restores a clear")
	plan.undo()
	plan.add(s4)
	check(not plan.can_redo(), "new stroke clears redo history")


func test_ink_budget() -> void:
	var lv := make_level({"drawingRules": {"maxStrokes": 3, "maxInkLength": 150, "minStrokeLength": 12, "railWidth": 6}})
	var plan := PlanState.new(lv)
	check(plan.add(line(Vector2(200, 300), Vector2(300, 300))), "100 ink fits")
	check(plan.check_add(line(Vector2(200, 250), Vector2(300, 250))) == "no_ink", "200 ink exceeds 150")
	check(is_equal_approx(plan.used_ink(), 100.0), "ink measured as rail length")
	plan.undo()
	check(plan.used_ink() == 0.0, "undo refunds ink")


func test_ranking_order() -> void:
	var save_script = load("res://scripts/autoload/save.gd")
	var a := {"strokes": 1, "ink": 50, "launched": 7, "ticks": 300}
	var b := {"strokes": 2, "ink": 10, "launched": 5, "ticks": 100}
	check(save_script.better(a, b), "fewer strokes ranks first")
	var c := {"strokes": 1, "ink": 40, "launched": 9, "ticks": 900}
	check(save_script.better(c, a), "then shorter rails")
	check(not save_script.better(a, a), "exact ties are not better")


# ------------------------------------------------------------------ content

func test_all_levels_verified() -> void:
	var paths := LevelData.level_paths()
	var c1 := paths.filter(func(p): return LevelData.load_level(p).get("chapter") is float and int(LevelData.load_level(p).chapter) == 1)
	check(c1.size() == 20, "chapter 1 has 20 levels")
	var verifier = load("res://tools/verify_levels.gd")
	for p in paths:
		var lv := LevelData.load_level(p)
		var r: Dictionary = verifier.verify(lv)
		check(r.ok, "level verified: " + r.line)


# ------------------------------------------------------------------ Phase 2 pieces

func lv2(over: Dictionary) -> Dictionary:
	var lv := make_level(over)
	lv["rulesVersion"] = 2
	return lv


func one(color: String, pos: Array, vel: Array) -> Array:
	return [{"id": "L1", "pos": pos, "velocity": vel, "ballRadius": 6, "colors": [color], "count": 5, "interval": 30.0}]


func piece(id: String, type: String, cx: float, cy: float, w: float, h: float, extra: Dictionary = {}) -> Dictionary:
	var o := {"id": id, "type": type, "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": 0}
	o.merge(extra, true)
	return o


func test_gate_passes_only_its_color() -> void:
	for c in ["blue", "red"]:
		var lv := lv2({"launchers": one(c, [100, 180], [300, 0]), "obstacles": [piece("G", "gate", 300, 180, 16, 200, {"color": "blue"})]})
		var sim := ColorSim.new(lv, [])
		run_collect(sim, 60)
		var b = sim.balls[0]
		if c == "blue":
			check(b.pos.x > 320.0 and b.color == "blue", "blue ball passes the blue gate")
		else:
			check(b.pos.x < 300.0 and b.color == "red", "red ball bounces off the blue gate (and keeps its colour)")


func test_switch_wall_opens_for_its_color_and_stays_open() -> void:
	var sw := piece("S", "switch", 300, 180, 16, 120, {"color": "red", "move": [0, -150], "speed": 300})
	var lv := lv2({"launchers": one("blue", [100, 180], [300, 0]), "obstacles": [sw]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 60)
	check(count_type(ev, "switch") == 0 and sim.switch_offset("S") == Vector2.ZERO, "a blue ball does not move a red switch")
	check(sim.balls[0].pos.x < 300.0, "the closed switch blocks the blue ball")
	lv = lv2({"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6, "colors": ["red", "blue"], "count": 12, "interval": 1.5}], "obstacles": [sw]})
	sim = ColorSim.new(lv, [])
	ev = run_collect(sim, 80)
	check(count_type(ev, "switch") == 1, "the red ball triggers the switch once")
	check(sim.switch_offset("S") == Vector2(0, -150), "the wall slides its full distance")
	run_collect(sim, 60)
	check(sim.balls[1].color == "blue" and sim.balls[1].pos.x > 320.0, "after opening, any colour passes")
	check(sim.switch_offset("S") == Vector2(0, -150), "the wall stays open")
	ev = run_collect(sim, 1)
	check(count_type(ev, "paint") == 0, "the switch never paints")


func test_splitter_doubles_once() -> void:
	var sp := {"id": "X", "type": "splitter", "shape": "regular", "center": [250, 180], "radius": 26, "sides": 3, "rotation": 90}
	var lv := lv2({"launchers": one("blue", [100, 180], [300, 0]), "obstacles": [sp]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 120)
	check(count_type(ev, "split") == 1, "one ball through one prism splits once")
	check(sim.balls.size() == 2, "two balls on the board")
	if sim.balls.size() == 2:
		var a = sim.balls[0]
		var b = sim.balls[1]
		check(a.color == "blue" and b.color == "blue", "copies keep the colour")
		check(b.copy_of == a.id, "the copy remembers its original")
		var ang: float = abs(rad_to_deg(a.vel.angle_to(b.vel)))
		check(abs(ang - 60.0) < 0.5, "copies leave 60 degrees apart (30 each side)")


func test_splitter_cap() -> void:
	var obs: Array = []
	for i in 6:
		# Big overlapping prisms, so the spreading copies keep hitting the next one.
		obs.append({"id": "X%d" % i, "type": "splitter", "shape": "regular", "center": [170 + i * 45, 180], "radius": 80, "sides": 3, "rotation": 90})
	var lv := lv2({"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [200, 0], "ballRadius": 6, "colors": ["blue"], "count": 5, "interval": 0.2}],
		"obstacles": obs, "board": {"width": 640, "height": 2000}})
	var sim := ColorSim.new(lv, [])
	var peak := 0
	for i in 300:
		sim.step()
		peak = maxi(peak, sim.active_count())
	check(peak <= ColorSim.MAX_BALLS, "never more than %d balls on the board (peak %d)" % [ColorSim.MAX_BALLS, peak])
	check(peak > 20, "multipliers really multiply (peak %d)" % peak)


func test_bumper_rebounds_harder_without_paint() -> void:
	var bu := {"id": "B", "type": "bumper", "shape": "regular", "center": [300, 180], "radius": 20, "sides": 16, "rotation": 0}
	var lv := lv2({"launchers": one("green", [100, 180], [150, 0]), "obstacles": [bu]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 120)
	var hits := ev.filter(func(e): return e.type == "bounce" and e.kind == "bumper")
	check(hits.size() >= 1, "the ball hits the bumper")
	check(sim.balls[0].vel.length() >= ColorSim.BUMPER_MIN_OUT - 1.0, "it leaves at least %d units/s" % ColorSim.BUMPER_MIN_OUT)
	check(sim.balls[0].color == "green" and count_type(ev, "paint") == 0, "bumpers never paint")


func test_flip_pad_flips_gravity() -> void:
	var lv := lv2({"gravity": [0, 420], "launchers": one("blue", [300, 100], [0, 0]),
		"obstacles": [piece("F", "flip", 300, 200, 80, 12)], "board": {"width": 640, "height": 360}})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 40)
	check(count_type(ev, "flip") >= 1, "the falling ball touches the flip pad")
	check(sim.balls[0].gsign == -1.0, "its gravity is flipped")
	run_collect(sim, 30)
	check(sim.balls[0].pos.y < 180.0 and sim.balls[0].vel.y < 0.0, "the ball now falls upward")


func test_booster_accelerates() -> void:
	var lv := lv2({"launchers": one("blue", [100, 180], [100, 0]),
		"obstacles": [piece("P", "booster", 250, 180, 80, 30, {"push": [900, 0]})]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 120)
	check(count_type(ev, "boost") == 1, "one boost event on entry")
	check(sim.balls[0].vel.x > 180.0, "the ball leaves the pad faster (%.0f)" % sim.balls[0].vel.x)


func test_gravity_zone_and_zero_g() -> void:
	var up := lv2({"gravity": [0, 420], "launchers": one("blue", [100, 300], [120, 0]),
		"obstacles": [{"id": "Z", "type": "zone", "shape": "rect", "center": [320, 180], "size": [640, 360], "rotation": 0, "gravity": [0, -420]}]})
	var sim := ColorSim.new(up, [])
	run_collect(sim, 30)
	check(sim.balls[0].vel.y < -50.0, "inside an 'up' zone the ball rises")
	var zero := lv2({"gravity": [0, 420], "launchers": one("blue", [100, 180], [200, 0]),
		"obstacles": [{"id": "Z", "type": "zone", "shape": "rect", "center": [320, 180], "size": [640, 360], "rotation": 0, "gravity": [0, 0], "drag": 1.5}]})
	sim = ColorSim.new(zero, [])
	run_collect(sim, 30)
	check(abs(sim.balls[0].pos.y - 180.0) < 0.01, "zero gravity: the ball flies straight")
	run_collect(sim, 240)
	check(sim.balls[0].vel.length() < 5.0, "drag lets the ball settle")


func test_ordered_goals() -> void:
	var lv := lv2({"launchers": [{"id": "L1", "pos": [100, 120], "velocity": [300, 0], "ballRadius": 6, "colors": ["red"], "count": 5, "interval": 0.2},
			{"id": "L2", "pos": [100, 240], "velocity": [300, 0], "ballRadius": 6, "colors": ["blue"], "count": 16, "interval": 0.2}],
		"collectors": [{"id": "CR", "center": [400, 120], "innerRadius": 24, "targetColor": "red", "requiredCount": 5},
			{"id": "CB", "center": [300, 240], "innerRadius": 24, "targetColor": "blue", "requiredCount": 5, "after": "CR"}]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 40)
	check(sim.collectors[1].count == 0 and sim.collector_locked("CB"), "the blue goal stays locked while red is not full")
	check(ev.any(func(e): return e.type == "pass" and e.locked), "blue balls pass through the locked goal")
	ev = run_collect(sim, 200)
	check(count_type(ev, "unlock") == 1, "the blue goal unlocks once red is full")
	check(sim.state == ColorSim.State.WON, "both goals fill in order")


func test_power_launcher_no_tunneling() -> void:
	var lv := lv2({"maxSpeed": 1200, "launchers": one("blue", [100, 180], [5000, 31])})
	var sim := ColorSim.new(lv, [line(Vector2(300, 60), Vector2(300, 300), 30)])
	check(sim.substeps == 6, "power levels take 6 sub-steps")
	var crossed := false
	var top := 0.0
	for i in 120:
		sim.step()
		for b in sim.balls:
			top = maxf(top, b.vel.length())
			if b.alive and b.pos.x > 300.0:
				crossed = true
	check(not crossed, "no tunneling at 1200 units/s")
	check(top <= 1200.5 and top > 900.0, "speed capped at 1200 (peak %.0f)" % top)


func test_splitter_disables_early_fail() -> void:
	var sp := {"id": "X", "type": "splitter", "shape": "regular", "center": [250, 180], "radius": 26, "sides": 3, "rotation": 90}
	var lv := lv2({"launchers": [{"id": "L1", "pos": [600, 180], "velocity": [300, 0], "ballRadius": 6, "colors": ["red"], "count": 3, "interval": 1.0}], "obstacles": [sp]})
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 30)
	check(sim.state == ColorSim.State.RUNNING, "with a multiplier, losing a ball does not end the run early")


func test_stuck_waits_for_switch() -> void:
	var lv := lv2({"gravity": [0, 420], "launchers": one("blue", [100, 300], [0, 0]),
		"obstacles": [piece("Floor", "neutral", 320, 320, 640, 20), piece("S", "switch", 500, 200, 16, 100, {"color": "red", "move": [0, -100]})]})
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 200)
	check(sim.balls[0].alive, "a resting ball is kept while a switch wall could still free it")


func test_new_piece_validation() -> void:
	var bad := make_level({"obstacles": [piece("G", "gate", 300, 180, 16, 100, {"color": "blue"})]})
	check(LevelData.validate(bad).any(func(e): return "rulesVersion 2" in e), "new pieces need rulesVersion 2")
	var sp := {"id": "X", "type": "splitter", "shape": "regular", "center": [250, 180], "radius": 26, "sides": 3, "rotation": 90}
	var lv := lv2({"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6, "colors": ["red"], "count": 3, "interval": 1.0}], "obstacles": [sp]})
	check(not LevelData.validate(lv).any(func(e): return "supply" in e), "3 balls x2 can fill a goal of 5")
	var lock := lv2({"collectors": [{"id": "C1", "center": [560, 60], "innerRadius": 24, "targetColor": "red", "requiredCount": 5, "after": "nope"}]})
	check(LevelData.validate(lock).any(func(e): return "unknown collector" in e), "a lock must name a real goal")


func test_drawing_rules_for_new_pieces() -> void:
	var lv := lv2({"obstacles": [
		piece("S", "switch", 300, 250, 16, 80, {"color": "red", "move": [0, -150]}),
		{"id": "Z", "type": "zone", "shape": "rect", "center": [150, 250], "size": [100, 100], "rotation": 0, "gravity": [0, -420]},
		{"id": "X", "type": "splitter", "shape": "regular", "center": [450, 250], "radius": 26, "sides": 3, "rotation": 90}]})
	check(StrokeTools.validate(line(Vector2(260, 140), Vector2(340, 140)), lv) == StrokeTools.OBSTACLE, "rails can't block a switch wall's path")
	check(StrokeTools.validate(line(Vector2(110, 250), Vector2(190, 250)), lv) == "", "rails may cross a gravity zone")
	check(StrokeTools.validate(line(Vector2(400, 250), Vector2(500, 250)), lv) == StrokeTools.OBSTACLE, "rails can't cross a multiplier")


func test_chapter1_fingerprint_unchanged() -> void:
	var f := FileAccess.open("res://tests/fingerprint_c1.txt", FileAccess.READ)
	var expected := {}
	while not f.eof_reached():
		var ln := f.get_line().strip_edges()
		if ln != "":
			expected[ln.split(" ")[0]] = ln
	for path in LevelData.level_paths():
		var lv := LevelData.load_level(path)
		if not expected.has(lv.levelId):
			continue
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(lv)
		var sim := ColorSim.new(lv, rails)
		var r := sim.run_to_end()
		var h := 0
		for b in sim.balls:
			h = hash([h, snappedf(b.pos.x, 0.001), snappedf(b.pos.y, 0.001), b.color, b.captured])
		var got := "%s won=%s ticks=%d launched=%d lost=%d captured=%d hash=%d" % [lv.levelId, r.won, r.ticks, r.launched, r.lost, r.captured, h]
		check(got == expected[lv.levelId], "chapter 1 level %s plays exactly as before" % lv.levelId)


# ------------------------------------------------------------------ v1.2 pieces (rules v3)

func _v3(over: Dictionary) -> Dictionary:
	var lv := make_level(over)
	lv["rulesVersion"] = 3
	# A goal no ball reaches, for any colour used here, so runs never end early as "impossible".
	if not over.has("collectors"):
		lv["collectors"] = [{"id": "C1", "center": [600, 30], "innerRadius": 20, "targetColor": "blue", "requiredCount": 1}]
	return lv


func _area(id: String, type: String, cx: float, cy: float, w: float, h: float, extra := {}) -> Dictionary:
	var o := {"id": id, "type": type, "shape": "rect", "center": [cx, cy], "size": [w, h], "rotation": 0}
	o.merge(extra)
	return o


func _lost_reasons(ev: Array) -> Array:
	return ev.filter(func(e): return e.type == "lost").map(func(e): return e.reason)


func test_v3_poison() -> void:
	var sim := ColorSim.new(_v3({"obstacles": [_area("P", "poison", 300, 180, 40, 80)]}), [])
	var ev := run_collect(sim, 90)
	check("poison" in _lost_reasons(ev), "a ball touching poison is lost (%s)" % str(_lost_reasons(ev)))


func test_v3_lava_kills_and_burns_lines() -> void:
	var sim := ColorSim.new(_v3({"obstacles": [_area("L", "lava", 300, 180, 40, 80)]}), [])
	var ev := run_collect(sim, 90)
	check("lava" in _lost_reasons(ev), "a ball touching lava is lost")
	var lv := _v3({"obstacles": [_area("L", "lava", 300, 260, 100, 40)]})
	var rail := line(Vector2(100, 260), Vector2(500, 260), 20)
	var s2 := ColorSim.new(lv, [rail])
	var burning := 0
	var safe := 0
	for si in s2.seg_burn.size():
		if s2.owners[s2.seg_owner[si]].kind == "rail":
			if s2.seg_burn[si] >= 0:
				burning += 1
			else:
				safe += 1
	check(burning >= 3 and safe >= 10, "only the part of a line inside lava burns (%d burning, %d safe)" % [burning, safe])


func test_v3_fan_pushes() -> void:
	var calm := ColorSim.new(_v3({}), [])
	var windy := ColorSim.new(_v3({"obstacles": [_area("F", "fan", 300, 180, 300, 300, {"push": [0, -600]})]}), [])
	for i in 50:
		calm.step()
		windy.step()
	check(windy.balls[0].pos.y < calm.balls[0].pos.y - 20.0, "a fan blows balls along its push (%.0f vs %.0f)" % [windy.balls[0].pos.y, calm.balls[0].pos.y])


func test_v3_conveyor_carries() -> void:
	var lv := _v3({"gravity": [0, 420],
		"launchers": [{"id": "L1", "pos": [300, 170], "velocity": [0, 0], "ballRadius": 6, "colors": ["blue"], "count": 1, "interval": 30.0}],
		"obstacles": [_area("B", "conveyor", 300, 200, 400, 20, {"speed": 200})]})
	lv.material.obstacle.restitution = 0.2
	var sim := ColorSim.new(lv, [])
	for i in 90:
		sim.step()
	var b = sim.balls[0]
	check(b.pos.x > 340.0 and b.vel.x > 100.0, "a conveyor carries a resting ball along (x %.0f, vx %.0f)" % [b.pos.x, b.vel.x])


func test_v3_glass_breaks() -> void:
	var lv := _v3({"launchers": [{"id": "L1", "pos": [100, 180], "velocity": [300, 0], "ballRadius": 6, "colors": ["blue"], "count": 4, "interval": 0.4}],
		"obstacles": [_area("G", "glass", 300, 180, 16, 200, {"hits": 2})]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 200)
	check(count_type(ev, "crack") >= 2 and count_type(ev, "shatter") == 1, "glass cracks and breaks after its hits (cracks %d, shatter %d)" % [count_type(ev, "crack"), count_type(ev, "shatter")])
	var passed := sim.balls.filter(func(b): return b.pos.x > 320.0).size()
	check(passed >= 1, "balls fly through once the glass is gone")


func test_v3_door_opens_and_closes() -> void:
	var lv := _v3({"obstacles": [_area("D", "door", 300, 180, 16, 200, {"period": 2.0, "open": 1.0, "phase": 0.0})]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 250)
	check(count_type(ev, "door") >= 3, "a timed door keeps opening and closing (%d changes)" % count_type(ev, "door"))
	var oi: int = sim.doors[0]
	check(ColorSim._door_open_at(sim.owners[oi], 10) and not ColorSim._door_open_at(sim.owners[oi], 70), "open for the first second, then closed")


func test_v3_portal_teleports() -> void:
	var lv := _v3({"obstacles": [{"id": "T", "type": "portal", "shape": "regular", "center": [200, 180], "radius": 18, "sides": 16, "rotation": 0, "to": [400, 60]}]})
	var sim := ColorSim.new(lv, [])
	var ev := run_collect(sim, 40)
	check(count_type(ev, "portal") == 1, "a ball goes through the portal once (%d)" % count_type(ev, "portal"))
	check(sim.balls[0].pos.y < 100.0 and sim.balls[0].vel.x > 250.0, "it comes out of the other end with the same speed")


func test_v3_black_hole_swallows() -> void:
	var lv := _v3({"obstacles": [{"id": "H", "type": "blackhole", "shape": "regular", "center": [300, 200], "radius": 14, "sides": 16, "rotation": 0, "reach": 140}]})
	var ev := run_collect(ColorSim.new(lv, []), 120)
	check("blackhole" in _lost_reasons(ev), "a black hole pulls a passing ball in and swallows it")


func test_v3_magnet_pulls_own_colour() -> void:
	var mag := {"id": "M", "type": "magnet", "shape": "regular", "center": [300, 110], "radius": 12, "sides": 16, "rotation": 0, "reach": 160, "color": "red"}
	var blue := ColorSim.new(_v3({"obstacles": [mag]}), [])
	var lv := _v3({"obstacles": [mag.duplicate()]})
	lv.launchers[0].colors = ["red"]
	var red := ColorSim.new(lv, [])
	for i in 50:
		blue.step()
		red.step()
	check(absf(blue.balls[0].pos.y - 180.0) < 1.0, "a magnet ignores other colours")
	check(red.balls[0].pos.y < 175.0, "a magnet pulls balls of its colour (y %.0f)" % red.balls[0].pos.y)


func test_v3_mixer_mixes() -> void:
	check(GameColors.mix("red", "yellow") == "orange" and GameColors.mix("blue", "red") == "purple" and GameColors.mix("yellow", "blue") == "green", "mix table")
	check(GameColors.mix("green", "red") == "red", "an unlisted pair takes the mixer colour")
	check(GameColors.mix("orange", "yellow") == "orange" and GameColors.mix("purple", "blue") == "purple", "a second touch on the same mixer keeps the mixed colour")
	var lv := _v3({"obstacles": [_area("X", "mixer", 300, 180, 16, 200, {"color": "yellow"})]})
	lv.launchers[0].colors = ["red"]
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 60)
	check(sim.balls[0].color == "orange", "a red ball touching a yellow mixer turns orange (%s)" % sim.balls[0].color)


func test_v3_validation() -> void:
	var lv := make_level({"obstacles": [_area("P", "poison", 300, 180, 40, 80)]})
	lv["rulesVersion"] = 2
	check(LevelData.validate(lv).any(func(e): return "rulesVersion 3" in e), "new pieces need rulesVersion 3")
	var ok := _v3({"obstacles": [_area("P", "poison", 300, 180, 40, 80)],
		"collectors": [{"id": "C1", "center": [560, 60], "innerRadius": 24, "targetColor": "blue", "requiredCount": 5}]})
	check(LevelData.validate(ok).is_empty(), "a rules-3 level with poison is valid (%s)" % str(LevelData.validate(ok)))


# ------------------------------------------------------------------ ink, rocks, chapter 2

func test_split_at_length() -> void:
	var parts := StrokeTools.split_at_length(line(Vector2(0, 0), Vector2(100, 0), 10), 40.0)
	check(is_equal_approx(StrokeTools.path_length(parts[0]), 40.0), "kept part is exactly the remaining ink")
	check(is_equal_approx(StrokeTools.path_length(parts[1]), 60.0), "the dry part is the rest")
	var all := StrokeTools.split_at_length(line(Vector2(0, 0), Vector2(100, 0), 10), 500.0)
	check(all[1].is_empty() and is_equal_approx(StrokeTools.path_length(all[0]), 100.0), "enough ink keeps the whole line")


func test_rock_blocks_balls_and_drawing() -> void:
	var rk := {"id": "K", "type": "rock", "shape": "poly", "points": [[300, 100], [360, 100], [360, 300], [300, 300]]}
	var lv := lv2({"launchers": one("blue", [100, 200], [300, 0]), "obstacles": [rk]})
	var sim := ColorSim.new(lv, [])
	run_collect(sim, 60)
	check(sim.balls[0].pos.x < 300.0, "a ball cannot pass through rock")
	check(StrokeTools.validate(line(Vector2(250, 200), Vector2(400, 200)), lv) == StrokeTools.OBSTACLE, "rails cannot cross rock")
	check(LevelData.validate(make_level({"obstacles": [rk]})).any(func(e): return "rulesVersion 2" in e), "rock needs rulesVersion 2")


func _c2_levels(chapter := "2") -> Array:
	var out: Array = []
	for p in LevelData.level_paths():
		var lv := LevelData.load_level(p)
		if str(lv.get("chapter", "")).replace(".0", "") == chapter:   # 4.4+ prints 2.0 as "2.0"
			out.append(lv)
	return out


func test_chapter2_ink_budgets_follow_formula() -> void:
	var slack := {"intro": 1.6, "easy": 1.45, "medium": 1.3, "hard": 1.2, "expert": 1.12}
	var levels := _c2_levels() + _c2_levels("3")
	check(levels.size() == 40, "chapters 2 and 3 have 40 levels (found %d)" % levels.size())
	for lv in levels:
		var rails: Array = load("res://tools/verify_levels.gd").load_solution(lv)
		var S := 0.0
		for r in rails:
			S += StrokeTools.path_length(r)
		var want := ceili((S * float(slack[lv.difficulty]) + 40.0) / 10.0 - 0.0001) * 10
		var got := int(lv.drawingRules.get("maxInkLength", 0))
		check(abs(got - want) <= 10, "%s ink %d follows the formula (%d)" % [lv.levelId, got, want])
		check(S <= got, "%s solution fits its ink" % lv.levelId)
		check(int(lv.drawingRules.maxStrokes) == 0, "%s uses ink instead of a stroke limit" % lv.levelId)


func test_chapter2_levels_use_new_board() -> void:
	for lv in _c2_levels():
		check(LevelData.board_size(lv) == Vector2(960, 540), "%s uses the 960 x 540 board" % lv.levelId)


## Chapter 3 is hard-only: every level is hard or expert, mixes at least two
## kinds of special piece, and uses the big board with an ink budget.
func test_chapter3_hard_mixed_levels() -> void:
	var levels := _c2_levels("3")
	check(levels.size() == 20, "chapter 3 has 20 levels (found %d)" % levels.size())
	for lv in levels:
		check(lv.difficulty in ["hard", "expert"], "%s is hard or expert" % lv.levelId)
		check(LevelData.board_size(lv) == Vector2(960, 540), "%s uses the 960 x 540 board" % lv.levelId)
		var kinds := {}
		for o in lv.obstacles:
			if o.get("type", "") in ["painter", "gate", "switch", "splitter", "bumper", "flip", "booster", "zone", "rock"]:
				kinds[o.type] = true
		for l in lv.launchers:
			if l.get("power", false):
				kinds["power"] = true
		if lv.get("gravity", [0, 630])[0] != 0:
			kinds["sideways"] = true
		for c in lv.collectors:
			if c.has("after"):
				kinds["order"] = true
		if lv.collectors.size() > 1:
			kinds["two goals"] = true
		check(kinds.size() >= 2, "%s mixes ideas (%s)" % [lv.levelId, ", ".join(kinds.keys())])


## Every level's title, tip and hint has real Arabic text (not the English copied).
func test_every_level_text_has_arabic() -> void:
	for p in LevelData.level_paths():
		var lv := LevelData.load_level(p)
		for key in ["title", "tip", "hint"]:
			var t: Dictionary = lv.get(key, {})
			if t.is_empty():
				continue
			var ar := str(t.get("ar", ""))
			check(ar != "" and ar != str(t.get("en", "")), "%s %s has Arabic text" % [lv.levelId, key])


# ------------------------------------------------------------------ crash-safe saves

const SaveScript := preload("res://scripts/autoload/save.gd")


func _wipe(p: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(p + suffix)


func test_save_atomic_write_keeps_backup() -> void:
	var p := "user://test_save_atomic.json"
	_wipe(p)
	check(SaveScript.write_atomic(p, JSON.stringify({"n": 1})), "first write succeeds")
	check(SaveScript.write_atomic(p, JSON.stringify({"n": 2})), "second write succeeds")
	check(int(LevelData.read_json(p).n) == 2, "main file holds the newest save")
	check(int(LevelData.read_json(p + ".bak").n) == 1, "backup holds the previous save")
	check(not FileAccess.file_exists(p + ".tmp"), "no temp file left behind")
	_wipe(p)


func test_save_recovers_from_damaged_file() -> void:
	var p := "user://test_save_damaged.json"
	_wipe(p)
	SaveScript.write_atomic(p, JSON.stringify({"version": 2, "levels": {"c1_01": {"stars": 3}}, "settings": {}}))
	SaveScript.write_atomic(p, JSON.stringify({"version": 2, "levels": {"c1_01": {"stars": 3}, "c1_02": {"stars": 1}}, "settings": {}}))
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"version\": 2, \"levels\": {\"c1_0")   # truncated mid-write
	f.close()
	var s = SaveScript.new()
	s.path = p
	s.load_data()
	check(s.loaded_from == "backup", "a damaged save loads the backup (got %s)" % s.loaded_from)
	check(s.levels.has("c1_01"), "progress from the backup is kept")
	s.free()
	var s2 = SaveScript.new()
	s2.path = "user://test_save_missing.json"
	_wipe(s2.path)
	s2.load_data()
	check(s2.loaded_from == "" and s2.levels.is_empty(), "no save at all starts fresh without errors")
	s2.free()
	_wipe(p)


func test_save_migrates_v1() -> void:
	var d := SaveScript.migrate({"version": 1, "settings": {"sound": false}, "levels": {}})
	check(int(d.version) == 3, "v1 saves upgrade to the newest version")
	var d3 := SaveScript.migrate({"version": 2, "settings": {}, "levels": {
		"c3_04": {"revision": 1, "rulesVersion": 2, "stars": 3, "best": {}},
		"c2_04": {"revision": 1, "rulesVersion": 2, "stars": 2, "best": {}}}})
	check(int(d3.levels.c3_04.revision) == 2 and int(d3.levels.c3_04.rulesVersion) == 3 and int(d3.levels.c3_04.stars) == 3, "chapter 3 stars survive the v1.2 rework")
	check(int(d3.levels.c2_04.revision) == 1, "other chapters are untouched")
	check(d.settings.sound == false, "a player who muted sound stays muted")
	check(d.settings.has("music_vol") and d.settings.has("sfx_vol"), "volume sliders are added")
	check(typeof(d.get("seen")) == TYPE_DICTIONARY, "onboarding flags are added")


# ------------------------------------------------------------------ onboarding & hints

func test_piece_cards_and_demos() -> void:
	# i18n.gd uses autoloads, so read its string table as text here.
	var src := FileAccess.get_file_as_string("res://scripts/autoload/i18n.gd")
	for k in PieceInfo.KEYS:
		for key in ["piece_" + k, "piece_" + k + "_d"]:
			var re := RegEx.create_from_string('"%s": \\{"en": "[^"]+", "ar": "[^"]+"\\}' % key)
			check(re.search(src) != null, "%s has English and Arabic text" % key)
		var lv := PieceInfo.level_for(k)
		var sim := ColorSim.new(lv, [])
		for i in 240:
			if sim.state != ColorSim.State.RUNNING:
				break
			sim.step()
		check(lv.launchers.is_empty() or sim.launched > 0, "demo %s launches balls" % k)
	var by_id := {}
	for p in LevelData.level_paths():
		var lv := LevelData.load_level(p)
		by_id[lv.levelId] = PieceInfo.keys_in(lv)
	check(by_id["c1_01"].is_empty(), "chapter 1 levels need no piece cards")
	check(by_id["c2_01"] == ["ink", "star", "hearts"], "Wide Open introduces ink and hearts (got %s)" % str(by_id["c2_01"]))
	check(not "hearts" in by_id["c1_20"], "chapter 1 never shows the hearts card")
	check(by_id["c1_02"] == ["star"], "level 2 introduces the map star (got %s)" % str(by_id["c1_02"]))
	check("gate" in by_id["c2_02"], "Blue Door introduces the color door")
	check("splitter" in by_id["c2_06"], "Split Paths introduces the prism")
	check("sideways" in by_id["c2_17"], "Sideways introduces sideways gravity")


func test_every_level_has_a_hint_solution() -> void:
	for p in LevelData.level_paths():
		var lv := LevelData.load_level(p)
		var sol = LevelData.read_json(LevelData.solution_path(lv.levelId))
		check(typeof(sol) == TYPE_DICTIONARY and not sol.get("strokes", []).is_empty(), "%s has a solution for the hint" % lv.levelId)
