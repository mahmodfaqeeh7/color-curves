class_name HeartRules
extends RefCounted
## v1.2 hearts (pure logic, unit-tested). Rules agreed with the owner:
## - Chapter 1 has no hearts; Chapters 2 and later give 3 hearts per level.
## - One failed launch costs one heart (per launch, never per ball).
## - Stopping a run is free unless a ball was already lost.
## - At 0 hearts: watch an ad (3 hearts back, lines kept) or start over
##   (3 hearts back, lines cleared). Winning refills.

const MAX := 3


static func uses_hearts(level: Dictionary) -> bool:
	return ChapterTheme.chapter_of(level) >= 2


## Does ending this run now cost a heart? `failed`: the run ended without
## filling every circle. Otherwise the player stopped it: free only if no
## ball was lost yet.
static func run_costs_heart(failed: bool, balls_lost: int) -> bool:
	return failed or balls_lost > 0
