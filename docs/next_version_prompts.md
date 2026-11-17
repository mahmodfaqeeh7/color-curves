# Color Curves: prompts for v1.1 and v1.2

Copy one prompt into Claude Code (opened in this project folder). Each prompt
stands alone. The full plan and the reasons are in `docs/next_version_plan.md`.
Every prompt ends the same way: run the tests, check with screenshots, report
the real results.

Shared rules for every prompt:
- Read `CLAUDE.md` first.
- Never edit `levels/*.json` by hand; use `tools/build_levels.py`.
- Every UI string goes through `scripts/autoload/i18n.gd`, in English and Arabic.
- When done, run `tests/run_tests.gd`, `tests/ui_smoke.gd` and
  `tools/verify_levels.gd`, and take screenshots in English and Arabic.

---

## v1.1 "Polish and ads"

### 1. Center the game and fix the Arabic layout
> Center every screen of Color Curves (title, level select, game board, result
> and settings). In Arabic some parts sit too far left with empty space on the
> right. Fix the layout with containers and anchors (no hard-coded x positions)
> so it is centered and mirrored correctly in both languages. Check it with
> screenshots at 1920x1080 (16:9), 2400x1080 (20:9) and 1440x1080 (4:3) in
> English and Arabic. Add a test that fails if the board or the main panels are
> not centered.

### 2. Swipe to scroll the level list
> In the level select screen, scrolling only works by dragging the scroll bar.
> Make a swipe anywhere on the list scroll it (touch and mouse), with a little
> momentum. A short tap still opens a level; a swipe must never open one. Add a
> UI test that drags the list and checks that it scrolled and no level opened.

### 3. Goal circle hitbox
> Check the goal circle's hitbox in `scripts/core/color_sim.gd`: compare where
> the ring is drawn with where balls collide and where they count as captured.
> Fix any mismatch, so a ball that looks inside the circle counts, and the ring
> edge blocks balls only where it is drawn. Keep Chapter 1 behaviour unless the
> fix is needed there; if `tests/fingerprint_c1.txt` changes, explain why and
> re-verify every level. Add regression tests.

### 4. New title screen
> Design a new title screen for Color Curves: the colored game name, the mascot,
> a moving demo line with the four colored balls rolling on it, and big Play,
> Settings and language buttons (at least 48 dp). Keep the "A game by Rawan
> Studio" footer. Draw it with code (no big images), keep it at 30 fps, and
> make it work in Arabic (RTL). Show me screenshots before and after.

### 5. Better-looking game objects
> Redesign how the launcher, the goal circle, rails, paint pads and the other
> pieces are drawn, so they look more polished (soft shadows, highlights,
> gentle idle animation). Keep the color symbols on every ball and piece for
> color-blind players, keep the same sizes and hitboxes, and keep draw calls
> low. Show before and after screenshots of the same levels.

### 6. A theme for each chapter (Chapters 1 to 3)
> Give each chapter its own look: Chapter 1 Studio (calm plum), Chapter 2
> Garden (greens), Chapter 3 Lab (cool blues). Each theme has its own
> background, accent color and chapter title card, used in the level select and
> in the game. Backgrounds are drawn once and cached. Keep text contrast
> readable. Show screenshots of each chapter.

### 7. Collectible map star (replaces "lose no balls")
> Change the third star. Today: star 1 = win, star 2 = target ink (or strokes in
> Chapter 1), star 3 = lose no balls (`game_screen.gd` `_on_win`). New: delete
> the "lose no balls" rule. Add a collectible star piece to the simulation;
> when any ball passes through it, it is collected (sparkle and sound). Win +
> collected star = star 3. Place one star in every level with
> `tools/build_levels.py`, off the easy path, and prove with
> `tools/verify_levels.gd` that a stored solution wins and collects it. Players
> keep stars they already earned. Update the win screen texts in English and
> Arabic. Add unit tests.

### 8. Ads
> Add ads with the AdMob plugin for Godot 4 (Android). Use Google's test ad IDs
> until I give you my real AdMob IDs. Rules:
> - Rewarded ad to unlock "Show first line" and "Show solution" (the text hint
>   stays free).
> - A banner only on the level-complete screen.
> - A full-screen ad after every 5 wins, at least 3 to 4 minutes apart, only
>   after level 8, never during a level.
> - A one-time "Remove ads" purchase (Google Play Billing) that removes banners
>   and full-screen ads and unlocks hints without ads.
> - Google's consent screen (UMP) before any ad.
> Put all ad logic in one autoload (`Ads`) with a fake backend for desktop and
> tests. If an ad fails to load, the player still gets the reward. Update the
> privacy policy, the store listing ("Contains ads: Yes") and the Data safety
> answers in `docs/store/`. Add tests for the frequency rules.

### 9. Release v1.1
> Prepare the v1.1 release: raise `version/code` and set the version name to
> 1.1.0 in `export_presets.cfg`, run every test, build the signed AAB and a
> test APK, verify the signature and contents, and write release notes in
> English and Arabic (under 500 characters each).

---

## v1.2 "New challenges"

### 10. Hearts (from Chapter 2)
> Add the hearts system (full rules in `docs/next_version_plan.md`, item 6):
> - Chapter 1 has no hearts. Chapters 2 to 5 have 3 hearts per level, shown in
>   the top bar.
> - A failed launch costs 1 heart (one per launch, not per ball).
> - Drawing and editing are free. Stopping a run is free unless a ball was
>   already lost.
> - At 0 hearts: "Watch an ad" (3 hearts back, keep your lines; free for Remove
>   ads buyers) or "Start over" (3 hearts back, lines cleared).
> - Hearts are saved per level until a win or start over.
> - No relaxed mode. Hearts don't change stars.
> - A "New! Hearts" card on the first Chapter 2 level.
> Save hearts with the save migration system. Add unit tests for every rule and
> a UI test for the out-of-hearts panel.

### 11. Poison zones
> Add a poison zone piece to the simulation: a ball that touches it is lost
> (sinking effect and sound). Draw it in the game's style with a symbol, add a
> "New! Poison" demo card, unit tests, and use it in the reworked Chapter 3.

### 12. Rework Chapter 3
> Rework the 20 Chapter 3 levels to be harder and more unique; some look alike.
> Use poison zones and narrow entries to the goal. Keep the level IDs so
> players keep their stars. Every level needs a map star, a tuned solution, and
> must pass `tools/verify_levels.gd`. Show me a picture of every level.

### 13. Chapter 4: Volcano
> Add Chapter 4 "Volcano" (20 levels) with its own theme (dark reds, glowing
> lava). New pieces, each with simulation code, drawing, a "New!" card and unit
> tests:
> - Lava that burns away the part of a line it touches.
> - Fans that push balls sideways.
> - Conveyor belts.
> - Rails that crack after N balls.
> - Timed doors.
> Hearts and map stars apply. Every level must pass `tools/verify_levels.gd`.

### 14. Chapter 5: Space
> Add Chapter 5 "Space" (20 levels) with its own theme (deep blues, stars).
> New pieces, each with simulation code, drawing, a "New!" card and unit tests:
> - Portals.
> - Black holes that pull balls.
> - Magnets that pull one color.
> - Color mixing (red + yellow = orange goal).
> - No-draw zones.
> Hearts and map stars apply. Every level must pass `tools/verify_levels.gd`.

### 15. Release v1.2
> Prepare the v1.2 release (version name 1.2.0, higher version code), run every
> test, build and verify the AAB, update the store listing for the new chapters
> and write release notes in English and Arabic.
