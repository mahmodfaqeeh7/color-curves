class_name GameScreen
extends Control
## One level: planning ⇄ running ⇄ paused / won / failed.
## Planning → Running via Launch. Running → Paused via Pause/background.
## Running/Paused/Failed → Planning via Stop & Edit or Retry (rails kept).
## Won → next level or Replay.

signal go_levels
signal go_level(index: int)

enum Mode { PLANNING, RUNNING, PAUSED, WON, FAILED }

var level_index := 0
var level: Dictionary
var plan: PlanState
var sim: ColorSim
var mode := Mode.PLANNING
var fast := false
var _celebrate_t := -1.0
var _hitstop := 0.0           ## real seconds of frozen stepping after the winning capture
var _fail_t := -1.0
var _win_info := {}
var _stroke_count_at_launch := 0
var _ink_at_launch := 0.0

var board: BoardView
var lbl_title: Label
var lbl_diff: Label
var lbl_strokes: Label
var lbl_ink: Label
var ink_box: Control
var ink_bar
var lbl_balls: Label
var chips_box: HBoxContainer
var chips: Array = []
var btn_back: Button
var btn_undo: Button
var btn_redo: Button
var btn_delete: Button
var btn_clear: Button
var btn_launch: Button
var btn_fast: Button
var toast: Label
var tip_label: Label
var overlay_layer: Control
var _toast_t := 0.0
var hearts_row   ## Widgets.HeartRow (null in Chapter 1)


## Onboarding ("New!" piece cards, first-draw guide) is off for automated
## screenshots and videos (set by main.gd when dev flags are present).
static var onboarding_enabled := true
var _guide_active := false
var _solution_cache = null


func setup(index: int, levels: Array) -> void:
	level_index = index
	level = levels[index]
	plan = PlanState.new(level)
	for s in Save.load_plan(level):
		if StrokeTools.validate(s, level) == "" and plan.check_add(s) == "":
			plan.strokes.append(s)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	board.set_level(level, plan)
	_set_mode(Mode.PLANNING)
	var tip := LevelData.text(level, "tip", I18n.lang)
	tip_label.text = tip
	tip_label.visible = tip != ""
	if onboarding_enabled:
		call_deferred("_start_onboarding")


# ------------------------------------------------------------------ onboarding & hints

## The stored, verified solution for this level (empty if missing).
func _solution_strokes() -> Array:
	if _solution_cache == null:
		var sol = LevelData.read_json(LevelData.solution_path(level.levelId))
		_solution_cache = PlanState.strokes_from_data(sol.get("strokes", [])) if typeof(sol) == TYPE_DICTIONARY else []
	return _solution_cache


func _start_onboarding() -> void:
	var queue: Array = PieceDemo.keys_in(level).filter(func(k): return not Save.has_seen("piece_" + k))
	if not queue.is_empty():
		_show_piece_card(queue)
	else:
		_maybe_first_draw_guide()


## "New!" card: a live demo of the piece, its name and one line on how it works.
func _show_piece_card(queue: Array) -> void:
	var k: String = queue[0]
	var box := _overlay(I18n.t("new_piece") + "  " + I18n.t("piece_" + k))
	var demo := PieceDemo.new(k, Vector2(440, 248))
	demo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(demo)
	var l := UiKit.label(I18n.t("piece_" + k + "_d"), 21)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	box.add_child(l)
	box.add_child(UiKit.button(I18n.t("close"), func():
		Save.mark_seen("piece_" + k)
		var rest := queue.slice(1)
		if rest.is_empty():
			_close_overlays()
			_maybe_first_draw_guide()
		else:
			_show_piece_card(rest), Vector2(220, 60), true))


## Very first level: show the first line of the solution as a traced guide
## until the player draws their first line.
func _maybe_first_draw_guide() -> void:
	if level_index != 0 or Save.has_seen("first_draw") or not plan.strokes.is_empty():
		return
	var sol := _solution_strokes()
	if sol.is_empty():
		return
	board.show_hint_paths([sol[0]])
	tip_label.text = I18n.t("guide_first")
	tip_label.visible = true
	_guide_active = true


# ------------------------------------------------------------------ layout

const SIDE_W := 158.0
const ROW_SEP := 12
var _row: HBoxContainer
var board_holder: Control


## Width of the board area = the board's aspect ratio at the row's height,
## capped by the space left next to the side buttons.
func _fit_board_holder() -> void:
	if _row == null or level.is_empty():
		return
	var bs := LevelData.board_size(level)
	# Measure the screen, not the row: the row can never be narrower than the
	# board holder it contains, so using its own width could only ever grow.
	var avail := size.x - SIDE_W - ROW_SEP
	var w := minf(avail, _row.size.y * bs.x / maxf(bs.y, 1.0))
	board_holder.custom_minimum_size.x = floorf(maxf(w, 0.0))


func _build() -> void:
	add_child(UiKit.chapter_backdrop(ChapterTheme.chapter_of(level), 0.35))

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.custom_minimum_size = Vector2(0, 52)
	root.add_child(top)
	btn_back = UiKit.button(I18n.t("back"), _on_back, Vector2(110, 52))
	top.add_child(btn_back)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", -4)
	top.add_child(tbox)
	lbl_title = UiKit.label("%s · %s" % [I18n.t("level_n") % int(level.number), LevelData.title(level, I18n.lang)], 24, GameColors.IVORY, HORIZONTAL_ALIGNMENT_LEFT)
	tbox.add_child(lbl_title)
	lbl_diff = UiKit.label(I18n.t("diff_" + str(level.difficulty)), 16, GameColors.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	tbox.add_child(lbl_diff)
	# The title takes the free space and shortens with "…" on narrow screens,
	# so the chips and the Hint button always fit (hearts added a chip in v1.2).
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tl in [lbl_title, lbl_diff]:
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_strokes = _chip(top)
	ink_box = PanelContainer.new()
	ink_box.add_theme_stylebox_override("panel", UiKit.box(GameColors.PANEL, 12, 8))
	var ink_row := VBoxContainer.new()
	ink_row.add_theme_constant_override("separation", 2)
	lbl_ink = UiKit.label("", 18)
	ink_row.add_child(lbl_ink)
	ink_bar = Widgets.InkBar.new()
	ink_row.add_child(ink_bar)
	ink_box.add_child(ink_row)
	top.add_child(ink_box)
	lbl_balls = _chip(top)
	if HeartRules.uses_hearts(level):
		var hp := PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UiKit.box(GameColors.PANEL, 12, 8))
		hearts_row = Widgets.HeartRow.new(Save.hearts_left(level))
		hp.add_child(hearts_row)
		top.add_child(hp)
	chips_box = HBoxContainer.new()
	top.add_child(chips_box)
	for c in level.collectors:
		var chip := Widgets.CollectorChip.new()
		chip.set_state(c.targetColor, 0, int(c.get("requiredCount", 5)))
		chips_box.add_child(chip)
		chips.append(chip)
	var hint_btn := UiKit.button(I18n.t("hint"), _show_hint, Vector2(90, 52))
	top.add_child(hint_btn)

	# Main row: board + side controls
	# The board and the side buttons are centred as one group: the board holder
	# is sized to the board's aspect ratio (see _fit_board_holder), so wide
	# screens and right-to-left layouts get equal space on both sides.
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", ROW_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	_row = row
	board_holder = Control.new()
	board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(board_holder)
	row.resized.connect(_fit_board_holder)
	resized.connect(_fit_board_holder)
	board = BoardView.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Board is physical space: never mirrored for right-to-left languages.
	board.layout_direction = Control.LAYOUT_DIRECTION_LTR
	board_holder.add_child(board)
	board.stroke_finished.connect(_on_stroke)
	board.tapped.connect(_on_tap)
	board.stroke_feedback.connect(func(r): _toast(I18n.t("reason_" + r)))

	tip_label = UiKit.label("", 18, Color(GameColors.IVORY, 0.75))
	tip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip_label.offset_top = -34
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_holder.add_child(tip_label)
	toast = UiKit.label("", 22, GameColors.IVORY)
	toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 10
	toast.offset_bottom = 54
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_holder.add_child(toast)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDE_W, 0)
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	btn_undo = UiKit.button(I18n.t("undo"), func(): _edit(func(): plan.undo()), Vector2(158, 62))
	btn_redo = UiKit.button(I18n.t("redo"), func(): _edit(func(): plan.redo()), Vector2(158, 62))
	btn_delete = UiKit.button(I18n.t("delete"), func(): _edit(func(): plan.delete_at(plan.selected)), Vector2(158, 62))
	btn_clear = UiKit.button(I18n.t("clear"), _on_clear, Vector2(158, 62))
	for b in [btn_undo, btn_redo, btn_delete, btn_clear]:
		side.add_child(b)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(sp2)
	btn_fast = UiKit.button("×1", _toggle_fast, Vector2(158, 52))
	side.add_child(btn_fast)
	btn_launch = UiKit.button(I18n.t("launch"), _on_launch, Vector2(158, 96), true)
	btn_launch.add_theme_font_size_override("font_size", 28)
	side.add_child(btn_launch)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)


func _chip(parent: Control) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(GameColors.PANEL, 12, 8))
	var l := UiKit.label("", 20)
	p.add_child(l)
	parent.add_child(p)
	return l


# ------------------------------------------------------------------ state

func _set_mode(m: Mode) -> void:
	mode = m
	var planning := m == Mode.PLANNING
	board.drawing_enabled = planning
	if not planning:
		board.cancel_stroke()
	btn_launch.text = I18n.t("launch") if planning else I18n.t("stop_edit")
	UiKit.accent_button(btn_launch, GameColors.ACCENT if planning else GameColors.SLATE)
	btn_back.text = I18n.t("back") if planning else I18n.t("pause")
	btn_fast.visible = not planning
	tip_label.visible = planning and tip_label.text != ""
	_refresh()


func _refresh() -> void:
	var planning := mode == Mode.PLANNING
	btn_undo.disabled = not planning or not plan.can_undo()
	btn_redo.disabled = not planning or not plan.can_redo()
	btn_delete.disabled = not planning or plan.selected < 0
	btn_clear.disabled = not planning or plan.strokes.is_empty()
	btn_launch.disabled = mode in [Mode.WON, Mode.FAILED, Mode.PAUSED]
	if plan.max_strokes <= 0:
		lbl_strokes.text = "%s %d" % [I18n.t("strokes"), plan.used_strokes()]
	else:
		lbl_strokes.text = "%s %d/%d" % [I18n.t("strokes"), plan.used_strokes(), plan.max_strokes]
	ink_box.visible = plan.max_ink > 0.0
	if plan.max_ink > 0.0:
		var left: float = maxf(0.0, plan.max_ink - plan.used_ink())
		lbl_ink.text = I18n.t("ink_m") % ("%.1f" % (left / 100.0))
		ink_bar.set_fraction(left / plan.max_ink)
	board.ink_left = (plan.max_ink - plan.used_ink()) if plan.max_ink > 0.0 else -1.0
	var balls := LevelData.total_supply(level)
	if sim != null:
		balls = sim.unlaunched_count() + sim.active_count()
	_set_balls(balls)
	for i in chips.size():
		var c = level.collectors[i]
		var n := 0
		if sim != null:
			n = sim.collectors[i].count
		chips[i].set_state(c.targetColor, n, int(c.get("requiredCount", 5)))


var _balls_shown := -1


## HUD number ticks toward its new value instead of jumping (reduced motion: jump).
func _set_balls(n: int) -> void:
	if _balls_shown < 0 or Save.get_setting("reduced_motion"):
		_balls_shown = n
		lbl_balls.text = "%s %d" % [I18n.t("balls"), n]
		return
	if n == _balls_shown:
		return
	var from := _balls_shown
	_balls_shown = n
	lbl_balls.create_tween().tween_method(func(v: float):
		lbl_balls.text = "%s %d" % [I18n.t("balls"), int(round(v))], float(from), float(n), 0.25)


func _edit(f: Callable) -> void:
	if mode != Mode.PLANNING:
		return
	f.call()
	Save.store_plan(level, plan.to_data())
	board.plan_changed()
	_refresh()


func _toast(text: String) -> void:
	if text == "":
		return
	toast.text = text
	_toast_t = 2.2


# ------------------------------------------------------------------ input

func _on_stroke(raw: PackedVector2Array) -> void:
	if mode != Mode.PLANNING:
		return
	var res := StrokeTools.process(raw, level)
	if not res.ok:
		if res.reason != StrokeTools.TOO_SHORT:
			board.flash_invalid(res.points)
			_toast(I18n.t("reason_" + res.reason))
			Sfx.play("invalid")
			Sfx.buzz(30)
		return
	var pts: PackedVector2Array = res.points
	var dry := false
	if plan.max_ink > 0.0:
		var left := plan.max_ink - plan.used_ink()
		var min_len := float(level.drawingRules.get("minStrokeLength", 12.0))
		if res.length > left + 0.001:
			# The pen runs dry: keep what the ink allows, show the rest as dry.
			var parts := StrokeTools.split_at_length(pts, left)
			if StrokeTools.path_length(parts[0]) < min_len:
				board.flash_invalid(pts)
				_toast(I18n.t("reason_no_ink"))
				Sfx.play("invalid")
				Sfx.buzz(40)
				return
			pts = parts[0]
			board.flash_dry(parts[1])
			dry = true
	var why := plan.check_add(pts)
	if why != "":
		board.flash_invalid(pts)
		_toast(I18n.t("reason_" + why))
		Sfx.play("invalid")
		return
	_edit(func(): plan.add(pts))
	board.on_stroke_committed(plan.strokes.size() - 1)
	if dry:
		_toast(I18n.t("ink_dry"))
		Sfx.play("invalid")
		Sfx.buzz(40)
	else:
		Sfx.play("draw")
	tip_label.visible = false
	if _guide_active:
		_guide_active = false
		Save.mark_seen("first_draw")
		board.show_hint_paths([])


func _on_tap(p: Vector2) -> void:
	if mode != Mode.PLANNING:
		return
	var best := -1
	var best_d := 14.0
	for i in plan.strokes.size():
		var d := StrokeTools.distance_to_rail(p, plan.strokes[i])
		if d < best_d:
			best_d = d
			best = i
	plan.selected = best if best != plan.selected else -1
	_refresh()


func _on_clear() -> void:
	if plan.strokes.is_empty():
		return
	_confirm(I18n.t("confirm_clear"), I18n.t("confirm_clear_body"), I18n.t("clear"), func(): _edit(func(): plan.clear()))


func _on_launch() -> void:
	if mode == Mode.PLANNING:
		_start_run()
	elif mode == Mode.RUNNING:
		_back_to_planning()


func _on_back() -> void:
	if mode == Mode.PLANNING:
		go_levels.emit()
	elif mode == Mode.RUNNING:
		_pause()


func handle_back_request() -> void:
	if overlay_layer.get_child_count() > 0:
		if mode == Mode.PAUSED:
			_resume()
		elif mode in [Mode.PLANNING]:
			_close_overlays()
		return
	_on_back()


func _toggle_fast() -> void:
	fast = not fast
	btn_fast.text = "×2" if fast else "×1"


# ------------------------------------------------------------------ running

func _start_run() -> void:
	if HeartRules.uses_hearts(level) and Save.hearts_left(level) <= 0:
		_show_no_hearts()
		return
	_close_overlays()
	_run_charged = false
	_stroke_count_at_launch = plan.used_strokes()
	_ink_at_launch = plan.used_ink()
	plan.selected = -1
	sim = ColorSim.new(level, plan.strokes.duplicate())
	board.start_sim(sim)
	Sfx.play("launch")
	_celebrate_t = -1.0
	_fail_t = -1.0
	_set_mode(Mode.RUNNING)


func _leave_result(then: Callable) -> void:
	Ads.hide_banner()
	Ads.maybe_interstitial(then)


func _exit_tree() -> void:
	Ads.hide_banner()


## v1.2 hearts ------------------------------------------------------------
var _run_charged := false   ## this run already cost its heart


func _lose_heart() -> void:
	if _run_charged or not HeartRules.uses_hearts(level):
		return
	_run_charged = true
	var left := Save.hearts_left(level) - 1
	Save.set_hearts(level, left)
	if hearts_row != null:
		hearts_row.set_count(maxi(0, left), true)
	Sfx.play("heart")
	Sfx.buzz(30)


## Leaving a run that is still going: free unless a ball was already lost.
func _charge_if_abandoned() -> void:
	if sim != null and mode in [Mode.RUNNING, Mode.PAUSED] and HeartRules.run_costs_heart(false, sim.lost_count):
		_lose_heart()


func _refill_hearts() -> void:
	Save.set_hearts(level, HeartRules.MAX)
	if hearts_row != null:
		hearts_row.set_count(HeartRules.MAX, false)


## Out of hearts: watch an ad and keep the lines, or start over without them.
func _show_no_hearts() -> void:
	_close_overlays()
	if sim != null:
		board.stop_sim()
		sim = null
		_set_mode(Mode.PLANNING)
	var box := _overlay(I18n.t("no_hearts"), "surprised", 90)
	var l := UiKit.label(I18n.t("no_hearts_body"), 20, Color(GameColors.IVORY, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button(I18n.t("start_over"), func():
		_close_overlays()
		_refill_hearts()
		_edit(func(): plan.clear())
		Save.store_plan(level, plan.to_data()), Vector2(220, 64)))
	var keep := UiKit.button(I18n.t("keep_lines"), func():
		_close_overlays()
		Ads.show_rewarded(func(): _refill_hearts(), func(): _show_no_hearts()), Vector2(260, 64), true)
	if not Ads.no_ads():
		var badge := Widgets.AdBadge.new()
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT if not I18n.is_rtl() else Control.PRESET_TOP_LEFT)
		badge.position += Vector2(-14 if not I18n.is_rtl() else -10, -8)
		keep.add_child(badge)
	row.add_child(keep)
	box.add_child(row)


func _back_to_planning() -> void:
	_charge_if_abandoned()
	Ads.hide_banner()
	_close_overlays()
	board.stop_sim()
	sim = null
	_set_mode(Mode.PLANNING)


func _retry() -> void:
	board.stop_sim()
	Sfx.play("retry")
	_start_run()


func _pause() -> void:
	if mode != Mode.RUNNING:
		return
	_set_mode(Mode.PAUSED)
	var box := _overlay(I18n.t("paused"), "sleeping")
	box.add_child(UiKit.button(I18n.t("resume"), _resume, Vector2(300, 64), true))
	box.add_child(UiKit.button(I18n.t("stop_edit"), _back_to_planning, Vector2(300, 64)))
	box.add_child(UiKit.button(I18n.t("levels"), func():
		_charge_if_abandoned()
		go_levels.emit(), Vector2(300, 64)))


func _resume() -> void:
	_close_overlays()
	_set_mode(Mode.RUNNING)


func _physics_process(delta: float) -> void:
	board.interpolate = false
	if sim == null or mode == Mode.PAUSED or mode == Mode.PLANNING:
		return
	if mode == Mode.FAILED and _fail_t >= 0.0:
		return
	if _hitstop > 0.0:
		# Hit-stop: the winning capture freezes the board for a beat. Only the
		# visual stepping pauses; results were already decided by the sim.
		_hitstop -= delta
		return
	board.interpolate = true
	var steps := 2 if fast else 1
	var hud_dirty := false
	for _i in steps:
		sim.step()
		board.after_tick()
		if not sim.events.is_empty():
			hud_dirty = _handle_events(sim.events) or hud_dirty
		if mode != Mode.RUNNING:
			break
	# Event-driven HUD: only refresh when a spawn/capture/loss/end happened.
	if hud_dirty:
		_refresh()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clamp(_toast_t / 0.4, 0.0, 1.0)
		if _toast_t <= 0.0:
			toast.text = ""
	if _celebrate_t >= 0.0:
		_celebrate_t += delta
		if _celebrate_t > 1.3:
			_celebrate_t = -1.0
			_show_win()
	if _fail_t >= 0.0:
		_fail_t += delta
		if _fail_t > 0.7:
			_fail_t = -1.0
			_show_fail()


## Feedback tiers (game-feel): bounce = small, recolor = medium,
## capture = large, win = huge. Returns true when the HUD needs a refresh.
const CAPTURE_PITCH := [1.0, 1.122, 1.26, 1.498, 1.682]   # rising pentatonic steps


func _handle_events(events: Array) -> bool:
	var hud := false
	for e in events:
		match e.type:
			"spawn":
				board.on_spawn(sim.balls[e.ball].launcher_id, e.pos)
				hud = true
			"paint":
				board.on_paint(e.ball, e.pos, e.to)
				Sfx.play("paint", 1.0, 40)
			"capture":
				board.on_capture(e.collector, e.pos, e.color, e.count)
				Sfx.play("capture", CAPTURE_PITCH[clampi(e.count, 1, 5) - 1])
				Sfx.buzz(15)
				_pop_chip(e.collector)
				hud = true
			"star":
				board.on_star(e.pos)
				Sfx.play("star")
				Sfx.buzz(20)
			"pass":
				board.add_effect("pass", e.pos)
				Sfx.play("wrong", 1.0, 80)
			"lost":
				board.add_effect("lost", e.pos, e.color)
				if e.reason in ["poison", "lava", "blackhole"]:
					Sfx.play("hazard", 1.0, 60)
				elif e.reason != "out":
					Sfx.play("lost")
				hud = true
			"portal":
				board.add_effect("paint", e.from, e.color)
				board.add_effect("paint", e.pos, e.color)
				Sfx.play("portal", 1.0, 60)
			"crack":
				board.add_effect("pass", e.pos)
				Sfx.play("crack", 1.0, 40)
			"shatter":
				board.add_effect("lost", e.pos, "")
				Sfx.play("shatter")
				Sfx.buzz(20)
			"door":
				Sfx.play("door", 1.1 if e.open else 0.85, 100)
			"split":
				board.add_effect("paint", e.pos, e.color)
				board.on_paint(e.ball, e.pos, e.color)
				Sfx.play("split")
				hud = true
			"split_full":
				board.add_effect("pass", e.pos)
			"switch":
				board.on_switch(e.switch)
				Sfx.play("switch")
				Sfx.buzz(25)
			"flip":
				board.add_effect("paint", e.pos, "")
				Sfx.play("flip", 1.15 if e.up else 0.9, 60)
			"boost":
				board.add_effect("bounce", e.pos)
				Sfx.play("boost", 1.0, 70)
			"unlock":
				board.on_unlock(e.collector, e.pos)
				Sfx.play("unlock")
			"bounce":
				if e.kind == "bumper":
					board.on_bumper_hit(e.pos)
					Sfx.play("bumper", 1.0, 50)
				board.on_bounce(e.ball, e.get("normal", Vector2.UP), e.speed)
				if e.speed > 120:
					board.add_effect("bounce", e.pos)
					Sfx.play("bounce", 0.8 + min(e.speed, 600.0) / 1200.0, 45)
			"win":
				_on_win()
				hud = true
			"fail":
				_on_fail()
				hud = true
	return hud


func _pop_chip(collector_id: String) -> void:
	for i in level.collectors.size():
		if level.collectors[i].id != collector_id:
			continue
		var chip: Control = chips[i]
		if Save.get_setting("reduced_motion"):
			return
		chip.pivot_offset = chip.size * 0.5
		chip.scale = Vector2(1.15, 1.15)
		chip.create_tween().tween_property(chip, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_win() -> void:
	Sfx.duck()
	Ads.on_win()
	var r := sim.result()
	var strokes := _stroke_count_at_launch
	var par := int(level.get("scoring", {}).get("parStrokes", 1))
	var par_ink := float(level.get("scoring", {}).get("parInk", 0.0))
	# v1.1 stars: one for winning, one for the target ink (or strokes), one for
	# collecting the map star. Losing balls no longer costs a star.
	var good := (_ink_at_launch <= par_ink + 0.5) if par_ink > 0.0 else (strokes <= par)
	var got_star := bool(r.get("star", false))
	var stars := 1 + (1 if good else 0) + (1 if got_star else 0)
	r["strokes"] = strokes
	r["ink_q"] = int(round(_ink_at_launch / LevelData.board_size(level).x / 0.01))
	var saved := Save.record_win(level, r, stars)
	if HeartRules.uses_hearts(level):
		_refill_hearts()   # a win gives all hearts back
	_win_info = {"stars": stars, "good": good, "got_star": got_star, "new_best": saved.new_best, "strokes": strokes, "par": par, "par_ink": par_ink}
	Save.store_plan(level, plan.to_data())
	Sfx.play("win")
	Sfx.buzz(40)
	board.on_win()
	_hitstop = 0.0 if Save.get_setting("reduced_motion") else 0.12
	_set_mode(Mode.WON)
	_celebrate_t = 0.0


func _on_fail() -> void:
	_lose_heart()
	Sfx.play("fail")
	_set_mode(Mode.FAILED)
	_fail_t = 0.0


func _fail_text() -> String:
	match sim.fail_reason:
		"timeout":
			return I18n.t("fail_timeout")
	if sim.collectors.size() == 1:
		var c: Dictionary = sim.collectors[0]
		if c.count == 0 and sim.unlaunched_count() == 0 and sim.active_count() == 0:
			return I18n.t("fail_no_balls")
		if c.count == 0:
			return I18n.t("fail_none") % I18n.t(c.target)
		return I18n.t("fail_short_one") % [c.count, I18n.t(c.target)]
	return I18n.t("fail_short_multi")


func _show_fail() -> void:
	if HeartRules.uses_hearts(level) and Save.hearts_left(level) <= 0:
		_show_no_hearts()
		return
	var box := _overlay(I18n.t("attempt_failed"), "encouraging")
	var why := UiKit.label(_fail_text(), 22, Color(GameColors.IVORY, 0.85))
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(460, 0)
	box.add_child(why)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button(I18n.t("edit_path"), _back_to_planning, Vector2(200, 64), true))
	row.add_child(UiKit.button(I18n.t("retry"), _retry, Vector2(200, 64)))
	box.add_child(row)


func _show_win() -> void:
	var box := _overlay(I18n.t("level_complete"), "victory", 130)
	var stars := Widgets.StarRow.new(int(_win_info.stars), 24)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stars)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	var s2 := bool(_win_info.get("good", false))
	var s3 := bool(_win_info.get("got_star", false))
	_criterion(info, I18n.t("star1"), true)
	if float(_win_info.get("par_ink", 0.0)) > 0.0:
		_criterion(info, I18n.t("star2_ink") % ("%.1f" % (float(_win_info.par_ink) / 100.0)), s2)
	else:
		_criterion(info, I18n.t("star2") % I18n.strokes_phrase(int(_win_info.par)), s2)
	_criterion(info, I18n.t("star3"), s3)
	box.add_child(info)
	if _win_info.new_best:
		box.add_child(UiKit.label(I18n.t("new_best"), 18, GameColors.HEX.yellow))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# v1.1 ads: a banner while the result shows; a full-screen ad (when one
	# is due, see AdRules) only after the player picks what to do next.
	row.add_child(UiKit.button(I18n.t("levels"), func(): _leave_result(func(): go_levels.emit()), Vector2(160, 62)))
	row.add_child(UiKit.button(I18n.t("replay"), func(): _leave_result(_back_to_planning), Vector2(160, 62)))
	row.add_child(UiKit.button(I18n.t("next"), func(): _leave_result(func(): go_level.emit(level_index + 1)), Vector2(160, 62), true))
	box.add_child(row)
	Ads.show_banner()


## One star condition: a drawn star (filled when earned) and its text.
func _criterion(parent: Control, text: String, met: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(Widgets.StarIcon.new(met, 8.0))
	row.add_child(UiKit.label(text, 17, Color(GameColors.IVORY, 0.85 if met else 0.45)))
	parent.add_child(row)


func _show_hint() -> void:
	if mode == Mode.RUNNING:
		return
	# Hint ladder: words first, then the first line of the verified solution
	# traced on the board, then the whole solution.
	var box := _overlay(I18n.t("hint"), "thinking")
	var l := UiKit.label(LevelData.text(level, "hint", I18n.lang), 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	box.add_child(l)
	var sol := _solution_strokes()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# v1.1: the two line hints are unlocked with a rewarded ad (once per visit
	# to the level; free after "Remove ads"). The word hint stays free.
	if not sol.is_empty():
		row.add_child(_ad_hint_button(I18n.t("hint_first"), "first", func(): _show_hint_paths(sol.slice(0, 1))))
	if sol.size() > 1:
		row.add_child(_ad_hint_button(I18n.t("hint_all"), "all", func(): _show_hint_paths(sol)))
	row.add_child(UiKit.button(I18n.t("close"), _close_overlays, Vector2(170, 60), true))
	box.add_child(row)


var _hints_unlocked := {}   ## "first"/"all" -> true for this visit to the level


func _ad_hint_button(text: String, key: String, reveal: Callable) -> Button:
	var free: bool = Ads.no_ads() or _hints_unlocked.has(key)
	var b := UiKit.button(text, func():
		if Ads.no_ads() or _hints_unlocked.has(key):
			reveal.call()
			return
		_close_overlays()
		Ads.show_rewarded(func():
			_hints_unlocked[key] = true
			if key == "all":
				_hints_unlocked["first"] = true
			reveal.call()), Vector2(230, 60))
	if not free:
		var badge := Widgets.AdBadge.new()
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT if not I18n.is_rtl() else Control.PRESET_TOP_LEFT)
		badge.position += Vector2(-14 if not I18n.is_rtl() else -10, -8)   # on the corner
		b.add_child(badge)
	return b


func _show_hint_paths(paths: Array) -> void:
	_close_overlays()
	board.show_hint_paths(paths)
	_toast(I18n.t("hint_trace"))


## Confirmation: question title, consequence line, and buttons named after the
## action ("Clear" / "Cancel"), never Yes/No.
func _confirm(text: String, body: String, action: String, yes: Callable) -> void:
	var box := _overlay(text, "surprised", 90)
	if body != "":
		box.add_child(UiKit.label(body, 19, Color(GameColors.IVORY, 0.75)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button(I18n.t("cancel"), _close_overlays, Vector2(170, 60)))
	row.add_child(UiKit.button(action, func():
		_close_overlays()
		yes.call(), Vector2(170, 60), true))
	box.add_child(row)


## Modal overlay with a dimmed background; returns its content VBox.
func _overlay(title: String, pose: String = "", pose_h: float = 110.0) -> VBoxContainer:
	_close_overlays()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	if pose == "victory":
		box.add_child(Widgets.MascotRig.new(pose, pose_h))
	elif pose != "":
		box.add_child(Widgets.Mascot.new(pose, pose_h))
	box.add_child(UiKit.label(title, 32))
	if not Save.get_setting("reduced_motion"):
		# Panel pops in (brand motion: up to 300 ms for celebrations).
		panel.pivot_offset = Vector2.ZERO
		panel.modulate.a = 0.0
		var tw := panel.create_tween().set_parallel()
		tw.tween_property(panel, "modulate:a", 1.0, 0.18)
		panel.scale = Vector2(0.92, 0.92)
		panel.resized.connect(func(): panel.pivot_offset = panel.size * 0.5, CONNECT_ONE_SHOT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return box


func _close_overlays() -> void:
	for c in overlay_layer.get_children():
		c.queue_free()
		overlay_layer.remove_child(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		board.cancel_stroke()
		if mode == Mode.RUNNING:
			_pause()
