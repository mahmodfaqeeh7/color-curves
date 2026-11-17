extends Control
## Screen manager: title, level select, settings and the game itself.
## Applies the device safe area and handles the Android back button.

var levels: Array = []
var safe: MarginContainer
var current: Control
var current_name := ""


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	levels = LevelData.load_all()
	var bg := ColorRect.new()
	bg.color = GameColors.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	get_viewport().size_changed.connect(_apply_safe_area)
	I18n.language_changed.connect(func(): _apply_direction(); _reopen())
	_apply_safe_area()
	_apply_direction()
	_handle_cmdline()


## Developer flags (after "--"): --level=N, --solution, --run, --screen=levels|settings,
## --shot=path.png --shot-after=seconds. Used for automated screenshots.
func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var shot_after := 1.0
	var screen := "default"
	var lvl := -1
	for a in args:
		if a.begins_with("--level="):
			lvl = int(a.substr(8)) - 1
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--shot-after="):
			shot_after = float(a.substr(13))
		elif a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--chapter="):
			chapter_shown = a.substr(10)
		elif a.begins_with("--lang="):
			I18n.lang = a.substr(7)
			_apply_direction()
	if lvl >= 0 or "--tour" in args or shot != "":
		GameScreen.onboarding_enabled = "--onboarding" in args
	if "--tour" in args:
		_tour()
		return
	if "--demos" in args or "--demos3" in args:
		_demo_grid("--demos3" in args)
	elif lvl >= 0:
		open_game(lvl)
		var g := current as GameScreen
		if "--solution" in args:
			var sol = LevelData.read_json(LevelData.solution_path(g.level.levelId))
			g.plan.strokes = PlanState.strokes_from_data(sol.strokes)
			g._refresh()
		if "--hint-menu" in args:
			g.call_deferred("_show_hint")
		if "--hint" in args:
			g.call_deferred("_show_hint_paths", g._solution_strokes())
		if "--run" in args:
			g.call_deferred("_start_run")
		if "--draw" in args:
			_draw_and_run(g)
		if "--clean" in args:
			g.tip_label.visible = false   # text-free footage for ads
	elif screen == "levels":
		show_levels()
	elif screen == "settings":
		show_settings()
	elif screen == "splash":
		show_splash()
	elif screen == "title" and not args.is_empty():
		show_title()
	else:
		show_splash()
	if "--perf" in args:
		# Dev: sample frame metrics during a run (see README "Performance").
		await get_tree().create_timer(shot_after).timeout
		var dc := 0.0
		var pt := 0.0
		var ppt := 0.0
		for i in 60:
			await get_tree().process_frame
			dc = max(dc, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			pt = max(pt, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			ppt = max(ppt, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		print("PERF draw_calls_max=%d process_ms_max=%.2f physics_ms_max=%.2f objects=%d" % [dc, pt, ppt, Performance.get_monitor(Performance.OBJECT_COUNT)])
		get_tree().quit()
		return
	if shot != "":
		await get_tree().create_timer(shot_after).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _apply_direction() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if I18n.is_rtl() else Control.LAYOUT_DIRECTION_LTR


const SIDE_MARGIN := 16.0   ## owner: small equal space left and right (safe area/notch still respected)


func _apply_safe_area() -> void:
	# Only Android/iOS report a real safe area; on desktop it is the usable
	# screen rect, so the margins below stay at their minimums there.
	var win := Rect2(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	var to_ui := get_viewport_rect().size / win.size.max(Vector2.ONE)
	# v1.1: at least 60 px of space on the left and right of every screen
	# (owner's request: content was too close to the screen edges).
	var left := SIDE_MARGIN
	var right := SIDE_MARGIN
	var top := 12.0
	var bottom := 12.0
	if OS.has_feature("mobile"):
		var inner := Rect2(DisplayServer.get_display_safe_area()).intersection(win)
		if inner.has_area():
			left = maxf(left, (inner.position.x - win.position.x) * to_ui.x)
			top = maxf(top, (inner.position.y - win.position.y) * to_ui.y)
			right = maxf(right, (win.end.x - inner.end.x) * to_ui.x)
			bottom = maxf(bottom, (win.end.y - inner.end.y) * to_ui.y)
	# Keep the layout centred: a notch on one side gets the same margin on the
	# other side, so screens never look shifted left or right.
	var side := maxf(left, right)
	left = side
	right = side
	safe.add_theme_constant_override("margin_left", int(left))
	safe.add_theme_constant_override("margin_right", int(right))
	safe.add_theme_constant_override("margin_top", int(top))
	safe.add_theme_constant_override("margin_bottom", int(bottom))


## Screen change: the old screen fades out while the new one fades in and
## slides 24 px from the reading direction (220 ms, the brand's default
## transition). Reduced motion: a quick fade only.
## Battery: menus only animate gently, so they run at 30 fps; drawing and the
## simulation need full smoothness, so the game screen runs at 60.
const MENU_FPS := 30
const GAME_FPS := 60


static func fps_for(screen_name: String) -> int:
	return GAME_FPS if screen_name == "game" else MENU_FPS


func _swap(c: Control, name: String) -> void:
	var old := current
	current = c
	current_name = name
	Engine.max_fps = fps_for(name)
	if name in ["title", "levels", "settings"]:
		Sfx.music("menu")
	elif name == "game":
		Sfx.music("play")
	safe.add_child(c)
	if old != null:
		_ignore_input(old)   # a fading-out screen must not take taps
		var tw_out := old.create_tween()
		tw_out.tween_property(old, "modulate:a", 0.0, 0.14)
		tw_out.tween_callback(old.queue_free)
	if old == null:
		return  # first screen (the splash) appears instantly, matching the boot splash
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(0.06)
	if not Save.get_setting("reduced_motion"):
		var dx := -24.0 if I18n.is_rtl() else 24.0
		tw.tween_method(func(v: float): _slide(c, v), dx, 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.04)


static func _ignore_input(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_input(ch)


## The slide is an offset from where the safe-area container put the screen
## (its left margin). Setting position.x = 0 here used to throw the left margin
## away, so on phones every screen sat against the left edge.
func _slide(c: Control, v: float) -> void:
	if is_instance_valid(c):
		c.position.x = float(safe.get_theme_constant("margin_left")) + v
		if v == 0.0:
			safe.queue_sort()   # end of the slide: let the container place it exactly


func _reopen() -> void:
	match current_name:
		"settings":
			show_settings()
		"levels":
			show_levels()
		_:
			show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match current_name:
			"game":
				(current as GameScreen).handle_back_request()
			"levels", "settings":
				show_title()
			"splash":
				show_title()
			_:
				get_tree().quit()


# ------------------------------------------------------------------ splash

## Studio splash: continues seamlessly from the engine boot splash (same logo on
## the same plum), adds the studio tagline, then fades to the title. Tap skips.
const STUDIO_PLUM := Color(0.255, 0.192, 0.263)


func show_splash() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = STUDIO_PLUM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Cover the safe-area margins too, so the plum reaches the screen edges.
	bg.offset_left = -64
	bg.offset_top = -64
	bg.offset_right = 64
	bg.offset_bottom = 64
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/boot_splash.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(620, 248)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	var tag := UiKit.label(I18n.t("studio_tagline"), 26, Color(GameColors.IVORY, 0.85))
	tag.modulate.a = 0.0
	v.add_child(tag)
	root.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			show_title())
	_swap(root, "splash")
	var tw := root.create_tween()
	tw.tween_property(tag, "modulate:a", 1.0, 0.22).set_delay(0.25)
	tw.tween_interval(1.1)
	tw.tween_property(root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		if current == root:
			show_title())


# ------------------------------------------------------------------ title

func show_title() -> void:
	# v1.1 title: one centred column (mirrors cleanly in Arabic) over the
	# Studio background, with balls rolling along a drawn line behind it.
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(UiKit.chapter_backdrop(1, 0.7))
	var wave := Widgets.TitleWave.new()
	wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(wave)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_bottom = -150   # leave the rolling line and the footer free
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	screen.add_child(col)
	var guide := Widgets.MascotRig.new("guide", 150)
	guide.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(guide)
	col.add_child(Widgets.GameTitle.new(68))
	var tagline := UiKit.label(I18n.t("tagline"), 24, GameColors.ACCENT)
	col.add_child(tagline)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	col.add_child(sp)
	var play := UiKit.button(I18n.t("play"), show_levels, Vector2(340, 84), true)
	play.add_theme_font_size_override("font_size", 34)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(play)
	if not Save.get_setting("reduced_motion"):
		# A gentle "breathing" pulse invites the first tap.
		play.resized.connect(func(): play.pivot_offset = play.size * 0.5)
		var tw := play.create_tween().set_loops()
		tw.tween_property(play, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	row2.add_child(UiKit.button(I18n.t("settings"), show_settings, Vector2(164, 56)))
	row2.add_child(UiKit.button("English  |  العربية", func(): I18n.set_lang("ar" if I18n.lang == "en" else "en"), Vector2(200, 56)))
	col.add_child(row2)

	# Total stars, top corner (reading side).
	var total := 0
	for lv in levels:
		total += Save.stars(lv)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(Color(GameColors.PANEL, 0.85), 14, 10))
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	chip_row.add_child(Widgets.StarIcon.new(true, 11.0))
	chip_row.add_child(UiKit.label("%d / %d" % [total, levels.size() * 3], 22, GameColors.HEX.yellow))
	chip.add_child(chip_row)
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT if not I18n.is_rtl() else Control.PRESET_TOP_LEFT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN if not I18n.is_rtl() else Control.GROW_DIRECTION_END
	screen.add_child(chip)

	# Footer credit with the studio lockup.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 10)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -44
	foot.add_child(UiKit.label(I18n.t("a_game_by"), 17, Color(GameColors.IVORY, 0.7)))
	var lockup := TextureRect.new()
	lockup.texture = load("res://assets/brand/studio_lockup.png")
	lockup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lockup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lockup.custom_minimum_size = Vector2(170, 39)
	foot.add_child(lockup)
	screen.add_child(foot)
	_swap(screen, "title")


# ------------------------------------------------------------------ levels

var chapter_shown := ""


func _chapter_of(lv: Dictionary) -> String:
	return str(lv.get("chapter", 1)).replace(".0", "")


func _chapters() -> Array:
	var out: Array = []
	for lv in levels:
		var c := _chapter_of(lv)
		if not c in out:
			out.append(c)
	return out


## Tab text: "Chapter 2 · Garden".
func _chapter_title(c: String) -> String:
	if not c.is_valid_int():
		return _chapter_name(c)
	# Short form ("2 · Garden") so five chapter tabs fit on every screen.
	return "%d · %s" % [int(c), I18n.t("theme_" + str(ChapterTheme.of_chapter(int(c)).key))]


func _chapter_name(c: String) -> String:
	if c == "lab":
		return "Phase 2 Lab"
	return (I18n.t("chapter_n") % int(c)) if I18n.STRINGS.has("chapter_n") else "Chapter %s" % c


## A level is open if it is the first of its chapter, the previous level of
## the same chapter is completed, or it was completed before. Lab levels are
## always open (they are test levels for review).
func _unlocked(i: int) -> bool:
	var lv: Dictionary = levels[i]
	var c := _chapter_of(lv)
	if c == "lab" or Save.is_completed(lv):
		return true
	if i == 0 or _chapter_of(levels[i - 1]) != c:
		return true
	return Save.is_completed(levels[i - 1])


var _level_scroll: Widgets.DragScroll


func show_levels() -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var chapters_all := _chapters()
	var shown: String = chapter_shown if chapter_shown in chapters_all else str(chapters_all[0])
	var ch_num := int(shown) if str(shown).is_valid_int() else 1
	screen.add_child(UiKit.chapter_backdrop(ch_num, 0.6))
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(root)
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.button(I18n.t("back"), show_title, Vector2(130, 56)))
	top.add_child(Widgets.Mascot.new("happy", 56))
	var t := UiKit.label(I18n.t("levels"), 34, GameColors.IVORY, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var chapters0 := _chapters()
	if chapter_shown == "" or not chapter_shown in chapters0:
		chapter_shown = chapters0[0]
	var total := 0
	var in_chapter := 0
	for lv in levels:
		if _chapter_of(lv) == chapter_shown:
			total += Save.stars(lv)
			in_chapter += 1
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(GameColors.PANEL, 12, 10))
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	chip_row.add_child(Widgets.StarIcon.new(true, 11.0))
	chip_row.add_child(UiKit.label("%d / %d" % [total, in_chapter * 3], 24, GameColors.HEX.yellow))
	chip.add_child(chip_row)
	top.add_child(chip)
	root.add_child(top)
	var chapters := _chapters()
	if chapter_shown == "" or not chapter_shown in chapters:
		chapter_shown = chapters[0]
	if chapters.size() > 1:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 10)
		for c in chapters:
			var b := UiKit.button(_chapter_title(c), func():
				chapter_shown = c
				show_levels(), Vector2(176, 48))
			if c == chapter_shown and str(c).is_valid_int():
				UiKit.accent_button(b, ChapterTheme.of_chapter(int(c)).accent)
			tabs.add_child(b)
		root.add_child(tabs)
	var scroll := Widgets.DragScroll.new()   # swipe anywhere to scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_level_scroll = scroll
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for i in levels.size():
		if _chapter_of(levels[i]) == chapter_shown:
			grid.add_child(_level_card(i))
	_swap(screen, "levels")


func _level_card(i: int) -> Control:
	var lv: Dictionary = levels[i]
	var open := _unlocked(i)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(150, 150)
	b.disabled = not open
	# Difficulty tint along the card edge, so the curve of the campaign is visible.
	var tier := {"intro": GameColors.HEX.green, "easy": GameColors.HEX.blue, "medium": GameColors.HEX.yellow,
		"hard": GameColors.HEX.red, "expert": GameColors.ACCENT}
	var edge: Color = tier.get(str(lv.get("difficulty", "")), GameColors.SLATE)
	# Cards take the chapter's colour (v1.1 chapter themes).
	var base: Color = Color(ChapterTheme.of_level(lv).board_top.lightened(0.1), 0.94)
	var st := UiKit.box(base, 20)
	st.border_width_bottom = 5
	st.border_color = Color(edge, 0.9 if open else 0.25)
	b.add_theme_stylebox_override("normal", st)
	var sth := st.duplicate()
	sth.bg_color = base.lightened(0.08)
	b.add_theme_stylebox_override("hover", sth)
	var stp := st.duplicate()
	stp.bg_color = base.darkened(0.2)
	b.add_theme_stylebox_override("pressed", stp)
	var std := st.duplicate()
	std.bg_color = Color(base, 0.45)
	b.add_theme_stylebox_override("disabled", std)
	b.pressed.connect(func():
		if is_instance_valid(_level_scroll) and _level_scroll.dragged:
			return   # the end of a swipe, not a tap
		Sfx.play("tap")
		open_game(i))
	UiKit.add_press_pop(b)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var num := UiKit.label(str(int(lv.get("number", i + 1))), 32, GameColors.IVORY if open else Color(GameColors.IVORY, 0.3))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)
	var name := UiKit.label(LevelData.title(lv, I18n.lang), 17, Color(GameColors.IVORY, 0.8 if open else 0.3))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.clip_text = true
	v.add_child(name)
	var stars := Widgets.StarRow.new(Save.stars(lv), 11)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stars.modulate.a = 1.0 if open else 0.3
	v.add_child(stars)
	return b


func open_game(i: int) -> void:
	if i >= levels.size():
		show_levels()
		return
	i = clampi(i, 0, levels.size() - 1)
	var g := GameScreen.new()
	g.setup(i, levels)
	g.go_levels.connect(show_levels)
	g.go_level.connect(open_game)
	_swap(g, "game")


# ------------------------------------------------------------------ settings

func show_settings() -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(UiKit.chapter_backdrop(1, 0.5))
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(root)
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button(I18n.t("back"), show_title, Vector2(130, 56)))
	var t := UiKit.label(I18n.t("settings"), 34)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(130, 0)
	top.add_child(spacer)
	root.add_child(top)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for key in ["music_vol", "sfx_vol"]:
		grid.add_child(_slider_row(key))
	for key in ["sound", "haptics", "trails", "ghost", "preview", "reduced_motion"]:
		var c := CheckButton.new()
		c.text = I18n.t(key)
		c.focus_mode = Control.FOCUS_NONE
		c.custom_minimum_size = Vector2(380, 58)
		c.button_pressed = bool(Save.get_setting(key))
		c.toggled.connect(func(on):
			Save.set_setting(key, on)
			Sfx.play("tap"))
		grid.add_child(c)
	var lang := UiKit.button("%s: %s" % [I18n.t("language"), "English" if I18n.lang == "en" else "العربية"],
		func(): I18n.set_lang("ar" if I18n.lang == "en" else "en"), Vector2(380, 58))
	grid.add_child(lang)
	var reset := UiKit.button(I18n.t("reset_progress"), func(): _confirm_reset(), Vector2(380, 58))
	grid.add_child(reset)
	# v1.1: "Remove ads" (one-time purchase) and restoring it on a new phone.
	if Ads.no_ads():
		var done := UiKit.label(I18n.t("ads_removed"), 20, GameColors.HEX.green)
		done.custom_minimum_size = Vector2(380, 58)
		grid.add_child(done)
	elif Ads.can_buy():
		grid.add_child(UiKit.button(I18n.t("remove_ads"), func(): Ads.buy_no_ads(), Vector2(380, 58), true))
	if Ads.can_buy():
		grid.add_child(UiKit.button(I18n.t("restore_purchases"), func(): Ads.restore_purchases(), Vector2(380, 58)))
	if Ads.privacy_options_required():
		grid.add_child(UiKit.button(I18n.t("privacy_options"), func(): Ads.show_privacy_options(), Vector2(380, 58)))
	if not Ads.no_ads_changed.is_connected(_on_no_ads_changed):
		Ads.no_ads_changed.connect(_on_no_ads_changed)
	_swap(screen, "settings")


func _on_no_ads_changed() -> void:
	if current_name == "settings":
		show_settings()


## A volume slider styled like the toggle cards: label on the reading side,
## a thick track with an accent fill and a ball-shaped handle (48 dp+ target).
func _slider_row(key: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 58)
	card.add_theme_stylebox_override("panel", theme.get_stylebox("normal", "Button"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var lab := UiKit.label(I18n.t(key), 22, GameColors.IVORY, HORIZONTAL_ALIGNMENT_LEFT)
	lab.custom_minimum_size = Vector2(120, 0)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Save.get_setting(key))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_FILL
	sl.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = GameColors.BG
	track.set_corner_radius_all(5)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate()
	fill.bg_color = GameColors.ACCENT
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	sl.add_theme_icon_override("grabber", knob)
	sl.add_theme_icon_override("grabber_highlight", knob)
	sl.value_changed.connect(func(v):
		Save.set_setting(key, v)
		if key == "sfx_vol":
			Sfx.play("tap", 1.0, 120))
	row.add_child(sl)
	return card


static var _knob: ImageTexture
static func _knob_texture() -> ImageTexture:
	if _knob == null:
		var img := Art.ball_texture().get_image()
		img.resize(26, 26, Image.INTERPOLATE_BILINEAR)
		_knob = ImageTexture.create_from_image(img)
	return _knob


func _confirm_reset() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := PanelContainer.new()
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(Widgets.Mascot.new("surprised", 90))
	v.add_child(UiKit.label(I18n.t("confirm_reset"), 26))
	v.add_child(UiKit.label(I18n.t("confirm_reset_body"), 19, Color(GameColors.IVORY, 0.75)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiKit.button(I18n.t("cancel"), func(): dim.queue_free(), Vector2(170, 58)))
	row.add_child(UiKit.button(I18n.t("reset"), func():
		Save.reset_progress()
		dim.queue_free(), Vector2(170, 58), true))
	v.add_child(row)
	add_child(dim)


# ------------------------------------------------------------------ dev tour

## Dev only (Visual Lab): an automatic walk-through for preview videos.
## Splash -> title -> levels -> level 6: draws the stored solution with real
## pointer events, launches, and ends on the win screen.
func _tour() -> void:
	var wait := func(sec: float): await get_tree().create_timer(sec).timeout
	show_splash()
	await wait.call(4.2)
	show_levels()
	await wait.call(1.8)
	open_game(5)
	await wait.call(0.8)
	var g = current
	var sol = LevelData.read_json(LevelData.solution_path(g.level.levelId))
	for stroke in PlanState.strokes_from_data(sol.strokes):
		await _tour_drag(g.board, stroke)
		await wait.call(0.5)
	await wait.call(0.4)
	g.btn_launch.pressed.emit()


## Dev (trailer footage): draws the level's verified solution like a finger,
## then presses Launch.
func _draw_and_run(g) -> void:
	await get_tree().create_timer(0.7).timeout
	var sol = LevelData.read_json(LevelData.solution_path(g.level.levelId))
	for stroke in PlanState.strokes_from_data(sol.strokes):
		await _tour_drag(g.board, stroke)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.35).timeout
	g.btn_launch.pressed.emit()


func _tour_drag(board, stroke: PackedVector2Array) -> void:
	var vp := get_viewport()
	var xf: Transform2D = vp.get_final_transform() * board.get_global_transform_with_canvas()
	var to_win := func(p: Vector2) -> Vector2: return xf * (board.view_offset + p * board.view_scale)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = to_win.call(stroke[0])
	down.global_position = down.position
	vp.push_input(down)
	for i in range(1, stroke.size()):
		var m := InputEventMouseMotion.new()
		m.position = to_win.call(stroke[i])
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(m)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to_win.call(stroke[stroke.size() - 1])
	up.global_position = up.position
	vp.push_input(up)


## Dev screen: every "New!" piece demo at once (for review screenshots).
func _demo_grid(v3_only := false) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	var keys: Array = PieceDemo.KEYS
	if v3_only:
		keys = keys.slice(keys.find("poison"))
	for k in keys:
		var v := VBoxContainer.new()
		v.add_child(UiKit.label(k, 14))
		v.add_child(PieceDemo.new(k, Vector2(240, 135)))
		grid.add_child(v)
	_swap(grid, "demos")
