# v1.2 build plan (shipped together with v1.1 as one update)

Owner decision (10 Nov 2026): v1.1 and v1.2 go to Google Play together as
**version 1.2.0 (version code 2)**, with real ads switched on for the release
build. Full feature rules: `docs/next_version_plan.md` (items 5 and 6, and the
Chapter 4/5 sections). Prompts: `docs/next_version_prompts.md` (10–15).

Every level: built by `tools/build_levels.py`, map star placed by
`tools/place_stars.gd`, proven by `tools/verify_levels.gd` (solution wins and
collects the star, empty board neither wins nor collects it, robust >= 5/9).

## Phase 1: new pieces in the simulation (each: sim + drawing + New! card + EN/AR text + unit tests)
- [x] poison (area: ball touching it is lost)
- [x] lava (area: ball touching it is lost; drawn lines inside it burn away after a delay)
- [x] fan (area that pushes balls one way: wind)
- [x] conveyor (surface that carries balls along)
- [x] glass (platform that cracks after N ball hits)
- [x] timed door (wall that opens and closes on a rhythm)
- [x] portal pair (enter one, leave the other with the same velocity)
- [x] black hole (pulls balls toward its centre)
- [x] magnet (pulls only balls of its colour)
- [x] mixer (paints by mixing: red+yellow=orange, red+blue=purple, blue+yellow=green) + orange/purple goals
- [x] no-draw zone (exists as drawingRules.forbiddenZones: check drawing + card)

## Phase 2: hearts (Chapters 2–5)
- [x] 3 hearts per level, failed launch = 1 heart, stop after a loss = 1 heart
- [x] out of hearts: watch ad (keep lines) or start over (lines cleared)
- [x] saved per level until win/start over; New! card on first Chapter 2 level
- [x] unit + UI tests

## Phase 3: Chapter 3 rework (20 levels, same ids c3_01..c3_20)
## Phase 4: Chapter 4 Volcano (20 levels c4_01..c4_20) + theme
## Phase 5: Chapter 5 Space (20 levels c5_01..c5_20) + theme
## Phase 6: release 1.2.0: stars, full verify, tests, screenshots, real ads, signed AAB, notes EN/AR

**Status (10 Nov 2026): all phases done.** 100 levels pass `verify_levels.gd`; tests: 969 unit + 4 UI suites pass.
