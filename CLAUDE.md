# Color Curves

Game name: **Color Curves** (Arabic: منحنيات الألوان). Rawan Studio is the company; keep the
"A game by Rawan Studio" footer and never put "Rawan" in the game's name.

Landscape-only mobile puzzle game: draw rails so coloured balls reach matching goals.
This is the **production project** (released as v1.0.0, app ID `com.rawanstudio.colorcurves`).
New work happens here as updates. Older copies (`/home/user/rawan_color_curves`, the visual lab)
are archives only. Every Play upload needs a higher `version/code` in `export_presets.cfg`.

## Facts

- Godot **4.7.2-stable** (upgraded from 4.3 in v0.6), GDScript, GL Compatibility renderer.
  Note: since 4.4, `str(2.0)` gives `"2.0"`; numbers read from JSON are floats, so convert with
  `int()` or format strings before showing or comparing them.
- Android: Gradle build, App Bundle (.aab) for Play, target SDK 36 / min SDK 24 (template
  defaults), arm64 only. `android/build` is the generated Gradle template (do not edit by hand).
- 100 levels in 5 chapters: Chapter 1 (640x360, rules v1), Chapter 2 (960x540, rules v2, ink),
  Chapter 3 (reworked in v1.2: rules v3), Chapter 4 Volcano and Chapter 5 Space (rules v3).
- Custom deterministic simulation in `scripts/core/color_sim.gd` (60 Hz fixed step, capsule
  collisions, sub-steps). **Never** use Godot physics for gameplay. Chapter 1 behaviour is locked
  by `tests/fingerprint_c1.txt`.
- Languages: English and Arabic. UI strings in `scripts/autoload/i18n.gd`; level text Arabic in
  `tools/strings_ar.py` (every level string needs an Arabic entry; a test enforces it).

## Levels are generated, not hand-edited

- Edit `tools/build_levels.py`, then run `python3 tools/build_levels.py`. Never edit
  `levels/*.json` by hand.
- Solutions: control points in `tools/solution_ctrl.json` (this file overrides the default
  solution written in `build_levels.py`). Tune with
  `GODOT=<godot> python3 tools/tune_solution.py <levelId> [iters] [sigma] [seeds]`.
- Ink budget formula: `ceil10(S x slack + 40)`, slack intro 1.6 / easy 1.45 / medium 1.3 /
  hard 1.2 / expert 1.12. Do not hand-set `maxInkLength`.
- Every level must pass `tools/verify_levels.gd`: solution wins, empty board does not win,
  robust in at least 5 of 9 small shifts.

## Commands (run from this folder; GODOT = path to the Godot 4.7.2 binary)

```bash
$GODOT --headless --path . --script res://tests/run_tests.gd
```

```bash
$GODOT --headless --path . --script res://tests/ui_smoke.gd
```

```bash
$GODOT --headless --path . --script res://tests/ui_layout.gd
```

```bash
$GODOT --headless --path . --script res://tests/ads_flow.gd
```

```bash
$GODOT --headless --path . --script res://tools/verify_levels.gd -- --only=c3_01
```

```bash
$GODOT --headless --path . --export-release Android /path/to/ColorCurves.aab
```

## Systems added in v0.5

- Saves (`scripts/autoload/save.gd`): atomic write (tmp, then rename) with a `.bak` backup,
  versioned migration (`migrate()`), batched writes flushed on pause/close.
- Onboarding: `scripts/core/piece_info.gd` (data) + `scripts/ui/piece_demo.gd` (live demo)
  show a "New!" card the first time each piece appears; level 1 shows a traced first line.
- Hints: text, then "Show first line", then "Show solution", drawn from `levels/solutions/`
  (these ship in the app now).
- Music: `python3 tools/make_music.py` regenerates `assets/audio/music_*.ogg`; Music/SFX
  sliders; music ducks under the win sound.
- Battery: menus 30 fps, game 60 fps (`main.gd` `fps_for`). Android builds are arm64 only.
- Store texts: `docs/store/` (privacy policy, listing). `docs/` has a `.gdignore`.

## Changes in v1.1

- Goal capture: a ball counts once its **centre** is inside the circle (was: whole ball inside).
  `tests/fingerprint_c1.txt` was regenerated on purpose for this.
- Map star (third star): `star` in each level, placed by
  `$GODOT --headless --path . --script res://tools/place_stars.gd` -> `tools/stars.json`, copied
  into levels by `build_levels.py`. `verify_levels.gd` checks the stored solution collects it and
  an empty board does not. Stars = win + target ink/strokes + map star (losing balls costs nothing).
- Chapter themes: `scripts/core/chapter_theme.gd` + backgrounds from `python3 tools/make_backgrounds.py`.
- Ads (`Ads` autoload): rules in `scripts/core/ad_rules.gd`, AdMob/Billing in `scripts/ads/`.
  AdMob plugin (Poing v5.2.0) is in `addons/admob` (Android libs built from source); App ID in
  project.godot `[admob]`, ad unit ids in `scripts/ads/ad_ids.gd` (test mode ON until release).
  "Remove ads" parked (`AdIds.REMOVE_ADS_ENABLED`). See `docs/ads_setup.md`.
  New `class_name` scripts need `$GODOT --headless --path . --import` before headless tests.
- (Released together with v1.2 as version 1.2.0, see below.)
- Layout: board + side buttons are centred as one group; side margins are symmetric:
  16 px (`main.gd` SIDE_MARGIN; the safe area/notch is still respected). The screen slide-in is an
  offset from that margin (`_slide`). Result-screen banner is at the TOP (never covers buttons).
  Level list scrolls by swiping (`Widgets.DragScroll`). Test: `tests/ui_layout.gd`.

## Changes in v1.2 (shipped together with v1.1 as version 1.2.0, version code 2)

- New pieces (rules version 3, `scripts/core/color_sim.gd`): poison, lava (kills balls; lines within
  24 px burn away 1.5 s into a run), fan, conveyor, glass (breaks after N hits), timed door, portal
  pair, black hole, magnet (pulls its own colour), mixer (red+yellow=orange, red+blue=purple,
  blue+yellow=green; `GameColors.mix`), orange/purple goals. Drawn in `board_view.gd` (end of file),
  "New!" cards in `piece_info.gd`. Lines may be drawn through fan/lava/poison areas.
- Hearts (`scripts/core/heart_rules.gd`, `Save.hearts`): Chapters 2-5, 3 per level, one per failed
  launch, stop is free before a ball is lost; at 0: rewarded ad keeps lines, or start over.
  Test: `tests/ui_hearts.gd`.
- Chapter 3 rework is automatic: `tools/harden_c3.gd` adds a rock cup round each goal and poison
  pools beside the solution path -> `tools/c3_extras.json` (applied by `build_levels.py`; revision 2).
  Save version 3 migrates Chapter 3 stars. To regenerate: `BUILD_NO_EXTRAS=1 python3
  tools/build_levels.py`, run `harden_c3.gd`, rebuild, re-place stars.
- Chapters 4-5 are defined in `tools/levels_v12.py` (inline English + Arabic text). Design loop:
  `GODOT=... tools/v12.sh try|st|tune|pic` (see the header of that script).
- After any level change: `place_stars.gd`, `build_levels.py`, then `verify_levels.gd` (all 100 pass).

## Rules

- Keep exports small: `tools/*`, `tests/*`, `build/*` and `addons/godot_mcp/*` are excluded in `export_presets.cfg`.
- Dev flags for screenshots/videos: `-- --level=N --solution --run --lang=ar --shot=path.png`.
- The `addons/godot_mcp` editor plugin is for development only; it is disabled by default.

## Next versions

v1.1 + v1.2 are complete (`docs/next_version_plan.md`, `docs/v1_2_build_plan.md`). Parked for later:
"Remove ads" purchase, iPhone release. For a release build set `AdIds.USE_TEST_ADS := false`.
