# Color Curves: plan for the next versions

Requests from the owner (Nov 2026), with Claude's notes.
**Status:** v1.1 work started on 2026-11-10. v1.2 starts when the owner asks.
Ready-to-use prompts for every item: `docs/next_version_prompts.md`.

Plan: two versions (decided with the owner).
- **v1.1 "Polish and ads":** items 1, 2, 3, 4, 7, 8 and 9.
  - Centering and Arabic layout, swipe scrolling, goal hitbox.
  - New title screen.
  - Ads + "Remove ads".
  - Map star.
  - New object designs.
  - A theme for each chapter (Ch1 to Ch3).
- **v1.2 "New challenges":** items 5 and 6, plus Chapters 4 and 5.
  - Hearts and poison.
  - Chapter 3 rework.
  - Chapter 4 Volcano and Chapter 5 Space, with their new pieces and themes.

Every update needs a higher `version/code` in `export_presets.cfg`.

---

## 1. Center the game, fix the Arabic layout (bug, high priority)
- Levels and screens should be centered. In Arabic, some parts sit too far left
  with empty space on the right.
- Note: check every screen in both languages at 16:9, 20:9 and 4:3. Add a
  layout test that fails when a screen is not centered.

## 2. Swipe to scroll the level list (bug, high priority)
- Today you must drag the scroll bar. Swiping anywhere on the list should scroll it.
- Note: a swipe must scroll, and only a short tap opens a level.

## 3. New title screen + goal circle hitbox
- New design for the first screen.
- Fix the hitbox of the circle the balls fill.
- Note: confirm the exact problem first (do balls bounce off the ring edge, or
  does a ball that looks inside not count?). Then add a test so it never comes back.

## 4. Ads (decided with the owner)
- **Rewarded ad:** for "Show first line" and "Show solution". The text hint stays free.
- **No banner on the first screen.** The banner goes on the level-complete
  (result) screen.
- **Full-screen ad:**
  - After every 5 wins, at least 3 to 4 minutes apart.
  - Only after about level 8.
  - Never during a level.
- **"Remove ads":** a one-time purchase. **Parked for later** (owner, Nov 2026): code is ready,
  switched off with `AdIds.REMOVE_ADS_ENABLED`; needs the Billing plugin + Play product.
- **Also required:**
  - Google's consent screen (GDPR/UMP).
  - Updated privacy policy.
  - Data safety form.
  - "Contains ads: Yes".
  - The AdMob plugin for Godot 4.

## 5. Rework Chapter 3
- Make the levels harder and more unique (some look alike).
- Use more narrow entries to the goal.
- Notes:
  - Keep level IDs so players' stars stay.
  - Every level must still pass `tools/verify_levels.gd` (solvable, robust),
    so narrow goals stay fair.

## 6. Poison zones and hearts (v1.2, hearts from Chapter 2)

**Poison area:** a ball that touches it dies (sinks with a sound and a puff).

**Hearts: full rules**
1. **Where:**
   - **Chapter 1: no hearts.** It is the learning chapter, scored mostly by
     strokes. Ink already appears from level 14, and that stays as it is.
   - **Chapters 2, 3, 4 and 5 use hearts** (and ink).
   - Poison starts in Chapter 3 (the reworked one).
2. **How many:** 3 hearts per level, shown in the top bar.
3. **What costs a heart:**
   - One failed launch costs 1 heart. A launch fails when it ends without
     filling every circle.
   - It is one heart per launch, not per ball, so splitting prisms and many
     balls are never unfair.
4. **What is free:**
   - Drawing, undo, redo, delete and clear.
   - Stopping a run before any ball is lost.
   - Stopping after a ball is lost counts as a failed launch, so nobody can
     cancel a run just before it fails.
5. **Out of hearts:** a panel offers two choices.
   - **Watch an ad:** get 3 hearts back and keep your lines.
   - **Start over (free):** get 3 hearts back; your lines are cleared.

   The player is never locked out. The cost of running out is losing the
   drawing, not losing the level.
6. **Hearts remember:**
   - Hearts are saved per level until you win or start over.
   - Leaving the level and coming back does not refill them.
7. **Refill:** on a win, or with one of the two choices above.
8. **Stars:** hearts don't change stars (★1 win, ★2 ink, ★3 map star).
9. **"Remove ads" buyers:** the "keep your lines" refill is free, with no ad.
10. **Teaching:**
    - A "New! Hearts" card on the first Chapter 2 level (like the new-piece
      cards).
    - A short "New! Poison" demo on the first poison level in Chapter 3.
11. **No "Relaxed mode"** (decided with the owner): hearts can't be turned off.

**Tests:**
- Unit tests for every rule above.
- Hearts saved and loaded correctly after closing the app.
- Every Chapter 2 to 5 level is still proven solvable.

## 7. Better look for game objects
- Redesign the launcher, the goal circle and the other pieces.
- Note: keep the color symbols on every piece (for color-blind players) and keep
  shapes easy to read on small phones.

## 8. A look for each chapter
- Each chapter gets its own color theme, background and title art.
- Ideas:
  - Ch1 Studio (calm plum)
  - Ch2 Garden (greens)
  - Ch3 Lab (poison, cool blues)
  - Ch4 Volcano (v1.2)
  - Ch5 Space (v1.2)
- Note: backgrounds are drawn once and cached, for mobile speed.

## 9. Collectible star replaces the "lose no balls" star
- Today:
  - ★1 = win.
  - ★2 = use the target ink or less.
  - ★3 = lose no balls (`game_screen.gd` `_on_win`).
- New:
  - Delete the "lose no balls" rule: losing a ball no longer costs a star.
  - Each level gets a **star placed on the board**. When any ball rolls through
    it, the star is collected. Collected star + win = ★3.
- Notes:
  - The star is placed off the easy path, so the player has to bend a line to
    reach it. It's an optional challenge; the level can still be won without it.
  - Every level's star must be proven collectible: the stored solution (or a
    second "star solution") must win **and** collect it, checked by
    `tools/verify_levels.gd`.
  - Players keep the stars they already earned (never take stars away on update).
  - Effects: a sparkle and sound when collected; the star on the win screen fills in.
  - Update the win-screen star list text in English and Arabic.

---

## Chapters 4 and 5 (approved by the owner for v1.2)

**Chapter 4: Volcano**
- **Lava** (different from poison):
  - Lava burns away the part of your line it touches after a few seconds.
  - Lava rises slowly, so you must finish before it reaches the line.
- **Fans / wind:** push balls sideways.
- **Conveyor belts:** move balls along by themselves.
- **Breakable rails:** a line segment holds only N balls, then cracks.
- **Timed doors:** open and close on a rhythm.

**Chapter 5: Space**
- **Portals:** a ball enters one and comes out of the other.
- **Black holes / gravity wells:** pull balls toward them.
- **Color mixing:** red + yellow = orange goal. This fits the game's name well.
- **Magnets:** pull only balls of one color.
- **No-draw zones:** areas where you can't draw ink.

All new pieces must work in the deterministic simulation, have unit tests, and
each level must be proven solvable before release.
