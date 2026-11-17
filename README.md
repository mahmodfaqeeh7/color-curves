# Color Curves (v1.2.0)

Draw a path. Change the color. Fill the circle. · ارسم مسارًا. غيّر اللون. املأ الدائرة.

A landscape-only mobile physics puzzle game by **Rawan Studio**, built with Godot **4.7.2-stable**
(GDScript, GL Compatibility renderer). 100 levels in five chapters (Studio, Garden, Lab,
Volcano, Space), English and Arabic.
App ID: `com.rawanstudio.colorcurves`.

## Build it yourself

1. Install **Godot 4.7.2-stable** and its export templates (Editor → Manage Export Templates).
2. Open this folder in Godot. Run the checks:
   `godot --headless --path . --script res://tests/run_tests.gd` (expects "969 passed, 0 failed"; the other
   suites in `tests/` print PASS).
3. Android: in Editor Settings → Export → Android set the **Android SDK** path (platform 36,
   build-tools 36.1) and **Java SDK** (JDK 17 or 21). Then **Project → Install Android Build
   Template** (recreates `android/build`, left out of the source zip because it is 200 MB of
   generated files).
4. Project → Export → Android → set the release keystore to your **upload key**
   (`colorcurves-upload.jks`, alias `upload`), then export as **.aab** for Google Play.
   Raise `version/code` by 1 for every new upload.

Level tools (Python 3): `python3 tools/build_levels.py` regenerates the levels,
`python3 tools/make_music.py` regenerates the music. See `CLAUDE.md` for the full working rules.

Store texts and website: `docs/store/` (listing, privacy policy) and `docs/site/` (static site).

## History (development notes)

Built from `Rawan_Color_Curves_Game_Spec.md`:

| Area | Status |
|---|---|
| Core rules: drawing, overwrite-on-contact paint, 5-ball collectors, D > A + U failure, retries | Done |
| 20 campaign levels (spec §6 briefs), each with a stored, machine-verified solution | Done |
| Stars, local personal bests, sequential unlocks, saved drawings per level | Done |
| English + Arabic UI (RTL layout; the board is never mirrored) | Done |
| Color symbols (dot / triangle / plus / diamond), trails, last-attempt trace, reduced motion, sound, haptics | Done |
| Hints (first tier: text clue per level) | Done |
| Pause on background, Android back button, device safe areas | Done |
| Level editor, daily challenges, online leaderboards, sharing, monetization | **Not implemented** (later spec phases) |
| Rawan Studio brand: studio splash, kit mascots on every popup, title illustration, app icon, kit sounds, Nunito Sans + Tajawal fonts | Done (v0.2) |
| Android debug APK and installable Web build (landscape) | Built and checked in this environment |
| Tested on real phones | **Not yet**. Checked on desktop, headless and a mobile-sized headless browser. See "Next steps" |

## Running

1. Install Godot 4.3-stable and open `project.godot`. The first open imports the fonts.
2. Press Play. A mouse works like a finger.

Developer flags (after `--`): `--level=N`, `--solution` (loads the stored solution), `--run`, `--lang=ar`,
`--screen=levels|settings`, `--shot=out.png --shot-after=2`.

## Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd      # 82 rule checks + all levels verified
godot --headless --path . --script res://tests/ui_smoke.gd       # drags a rail via input events, launches, expects a win
godot --headless --path . --script res://tools/verify_levels.gd  # per-level report
```

`verify_levels` checks four things for each level:
- the level passes structural validation;
- its stored solution is valid and wins within the stroke and ink budgets;
- an empty drawing does not win;
- the solution still wins when shifted by up to 3 units in 8 directions (a robustness check against pixel-perfect solutions).

## Mobile export

`export_presets.cfg` contains Android and iOS presets. You need the Godot export templates, plus the Android SDK and a keystore (or Xcode for iOS).
The orientation is **sensor landscape** (`display/window/handheld/orientation=4`): the game is always landscape and flips 180° with the device.
JSON level files are included through `include_filter`.

## v0.2 review against the 8 installed skills

| Skill | What I checked | What changed |
|---|---|---|
| game-feel | Each event's feedback, and whether it matches the event's importance | Feedback is sized to each event: a bounce gets a faint ring, a recolor briefly pops the ball, a capture pops the circle and bursts particles, and a win throws confetti and shakes the board with a decaying "trauma" curve. The winning capture freezes the board for 0.12 s, and buttons pop when pressed. All of this is visual only and never changes the physics. Reduced motion turns off shake, squash and confetti. |
| physics-tuning | Fixed timestep, tunneling, render smoothness | The fixed 60 Hz timestep, the speed cap and the 4 sub-steps were already correct, and there is a tunneling test. Added **render interpolation**: balls are drawn between their previous and current physics positions, so motion stays smooth on 90/120 Hz phones. |
| game-ui-ux | Safe area, scaling, HUD wiring, text size | The safe-area code now clips the system safe area to the window, per the skill. The HUD now updates only when a game event changes it, instead of every physics tick. Small text was enlarged. Gamepad focus navigation was skipped because this is a touch game. |
| audio-design | Mix structure, headroom, repeated sounds | Sounds now play through SFX and UI channels with a limiter on Master at −1 dB, and muting works on the channels. The kit's sound cues peak at −16.5 dBFS and get +8 dB. Every cue gets a small random pitch and volume change, and the 5 captures rise through a pentatonic scale. |
| level-design | Difficulty curve, teach-then-test, impossible levels | Difficulty rises in a sawtooth: Intro 1–3 → Easy 4–8 → Medium 9–16 → Hard 17–20. Each new idea gets a tutorial tip before it is tested: the ink budget in level 15, two launchers in levels 16–17. The verifier proves every level is solvable and that none is won with an empty drawing. Added a **launch preview**: dots show each launcher's first arc, up to its first contact. |
| performance-optimization | Measured before changing anything | The simulation costs 0.22 ms per tick at worst (level 17). Draw calls were measured, the biggest cost found (a 144-dot background grid) and replaced with one batched call: planning dropped from 235 to 112 draw calls, a running level from 317 to 201. The launch preview costs at most 8 ms, once per edit. Frame times were measured with a software renderer, not on a phone GPU. |
| godot-export | Templates, presets, non-resource files | The level JSON files are included in every export. **Solutions and dev tools are excluded**, so verified answers don't ship in the app (spec §9.3). The `build/` folder has `.gdignore`. Added a Web/PWA preset, landscape only, plus the Android launcher and adaptive icons. |
| ux-writing-arabic | Every Arabic and English string | Buttons are verbs (أطلق، احذف، امسح، تابِع). Every error says what to do next, e.g. "ارسم حول الأشكال، لا عبرها". Confirm dialogs name the action instead of Yes/No (امسح / إلغاء). Count phrases use proper plurals (خطًا واحدًا، خطين، 3 خطوط). Encouragement follows the brand voice (أحسنت! / جرّب مرة ثانية). |

Also fixed during review: the ★, ✓ and ∞ symbols are missing from the bundled fonts, so they showed as empty boxes in the browser. They are now drawn as icons or replaced with text.

## Brand integration (Rawan Studio kit)

- Startup: the engine boot splash shows the studio logo on its plum colour, then a short splash adds "A little heart in every game" and fades to the title. A tap skips it.
- Title: the Color Curves guide mascot (holding the stylus), an animated illustration of the game rule (blue balls touch a red pentagon, turn red and fill a red ring), and a "A game by Rawan Studio" lockup.
- Each popup has a mascot pose: victory on a win, encouraging on a failed attempt, thinking for hints, sleeping on pause, surprised on confirm dialogs. Levels screen: happy.
- The app icon comes from `04_Color_Curves/icons`. Android launcher and adaptive icons and the web/PWA icons are generated from it.
- Sounds: the kit cues launch, recolor, capture, draw-confirm, retry and win. The tap and invalid sounds come from the studio's Puzzle Garden kit.
- Fonts: Nunito Sans 800 from the kit for Latin, Tajawal for Arabic (as the brand guide asks), and Noto Sans Arabic as a fallback. All three are OFL-licensed and their licence files are in `assets/fonts`.
- Gameplay shapes are still drawn from the real collision geometry. They use the kit sprites' palette and symbols, so what you see always matches what the physics does.

## Builds

```bash
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-debug "Android" build/android/RawanColorCurves-debug.apk
```

The included APK is a **debug test build** signed with the standard Android debug key, using APK Signature Scheme v2.
It installs on Android 7.0 or newer. Don't upload it to Google Play.
For the store you need your own release keystore, plus an AAB built with a full Android SDK (Gradle build): set `keystore/release` in the Android preset and export with `--export-release`.

The web build must be served over HTTP, not opened as a local file. Any static host works, including itch.io as HTML5.
It is an installable PWA locked to landscape: in the phone's browser, use "Add to Home Screen".

## Changes to the spec's rules

You allowed changes to drawing, physics and collision rules only. These are the changes:

- **Landscape board**: 640 × 360 units instead of portrait 360 × 640, scaled uniformly and letterboxed.
- **Custom deterministic physics** replaces Godot's RigidBody2D. Balls are circles and every collider is a capsule segment.
  The step is 60 Hz with 4 substeps, and speed is capped at 720 units/s, so each move is under 3 units against a ball radius of 6. That rules out tunneling (tested at up to 5000 units/s).
  On one build the same inputs give the same tick-for-tick result. This is the groundwork for verified rankings later. Cross-platform float determinism is still unproven (spec §7).
- **Stuck balls**: a ball that rests for 1.5 s is removed as "stuck", instead of waiting for its 20 s lifetime. This is safe only because every v1 obstacle is static.
  It must be revisited when moving obstacles arrive.
- **Simultaneous paint tie-break**: deeper penetration counts as the earlier contact. If depths are equal, contacts are applied in stable-ID order, so the highest ID applies last and wins.
- **Paint hysteresis**: a contact stays "entered" within 1 unit, so a rolling ball does not re-trigger paint every tick.
- **Stroke processing**: the stroke is smoothed with two light 1-2-1 passes, then simplified with RDP (ε = 0.6).
  If smoothing would push the line into an obstacle, the unsmoothed line is used. If that is also invalid, the whole stroke is rejected; it is never truncated.
  Tangency tolerance is 0.75 units.

## Layout

```
scripts/core/      pure rules: color_sim (physics + scoring), stroke_tools, plan_state, level_data, game_colors
scripts/ui/        main (screens), game_screen (state machine + HUD), board_view (render + input), widgets, ui_kit
scripts/autoload/  save (local JSON), i18n (EN/AR), sfx (synthesised sounds + haptics)
levels/            c1_01..c1_20.json, index.json; solutions/ = verification data (kept separate from play data)
tools/             build_levels.py (authoring source), solution_ctrl.json, verify/search/trace dev tools
tests/             run_tests.gd, ui_smoke.gd
```

To edit levels, change `tools/build_levels.py` and run `python3 tools/build_levels.py`.
To find or improve a solution, run `GODOT=... python3 tools/tune_solution.py c1_07`, then run `verify_levels`.
A level whose geometry changes needs a `revision` bump; old stars do not carry over.

## Performance

Use the `--perf` flag with any dev flags to print draw calls and frame times. `tools/profile_sim.gd` measures simulation cost per tick for every level.

## Next steps

- Install the APK on 2–3 real phones and check drawing feel, frame rate, audio level and the safe area on notched screens.
- Playtest difficulty. Several stored solutions were found by an automated search, so a human route may differ.
- Optional: hint tiers 2–3, a level editor with share codes, daily challenges.

## Visual Lab: Phases 1–3 (work in progress, not yet merged into the real game)

This lab copy holds the Phase 1 look and the merged Phase 2+3 work.

**Rules version 2 pieces** (only in levels that declare `rulesVersion: 2`; chapter 1 is unchanged, and `tests/fingerprint_c1.txt` proves it):

| Type | Behaviour |
|---|---|
| `gate` | Solid for every colour except its own |
| `switch` | A solid wall that slides along `move` once touched by its own colour, then stays open. It never paints. |
| `splitter` | ×2: one ball in, two out at ±30°. Each prism splits a ball once, with at most 40 balls on the board. |
| `bumper` | Rebounds a ball at 1.25× its speed, at least 260 units/s |
| `flip` | Flips the touching ball's gravity |
| `booster` | Accelerates balls along `push` while they are inside it |
| `zone` | An area with its own `gravity` (0 = zero gravity, with optional `drag`) |
| `rock` | Shaped-map ground: solid, can't be drawn on |
| collector `after` | The goal is locked until the named goal is full |
| level `maxSpeed` | Above 720, the engine takes 6 sub-steps per frame instead of 4 |

**Ink budgets (chapter 2).** `maxStrokes: 0` with `maxInkLength = ceil10(S × slack + 40)`. S is the length of the shortest solution the solver found. Slack is 1.6 (intro), 1.45 (easy), 1.3 (medium), 1.2 (hard) or 1.12 (expert). The second star uses `parInk = ceil10(S × 1.1)`. When ink runs out mid-line, the pen runs dry: the kept part stays, the dry part is shown dotted, and an alert explains it.

**Bigger board.** Chapter 2 uses 960 × 540. Two fingers pinch-zoom up to 3×, a "Fit" button resets the view, and the mouse wheel zooms on desktop.

**Tools.** `tools/build_levels.py` builds every chapter. `tools/tune_solution.py <id>` searches for a solution (4 jobs can run in parallel). `tools/fingerprint.gd` and `tools/ink_report.gd` support the regression test and the ink check.
