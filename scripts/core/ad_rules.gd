class_name AdRules
extends RefCounted
## v1.1 ad rules agreed with the owner (pure logic, unit-tested):
## - full-screen ad after every 5 wins, at least 3 minutes apart,
## - only once the player has completed 8 levels,
## - never during a level (callers only ask on the result screen),
## - none at all after "Remove ads".

const WINS_PER_AD := 5
const MIN_GAP_S := 180.0
const FIRST_AFTER_COMPLETED := 8


static func interstitial_due(wins_since_ad: int, seconds_since_last: float, completed_levels: int, no_ads: bool) -> bool:
	return not no_ads \
		and completed_levels >= FIRST_AFTER_COMPLETED \
		and wins_since_ad >= WINS_PER_AD \
		and seconds_since_last >= MIN_GAP_S
