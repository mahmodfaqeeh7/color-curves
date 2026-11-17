extends SceneTree
## v1.1 ads flow with the fake backend (desktop): full-screen ad timing,
## rewarded hints and "Remove ads". The real AdMob backend runs on phones.
## godot --headless --path . --script res://tests/ads_flow.gd

var failures := 0
var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var ads = root.get_node("Ads")
	var save = root.get_node("Save")
	var fake = ads.backend
	_expect(fake.get_script().resource_path.ends_with("fake_backend.gd"), "desktop uses the fake backend")
	save.reset_progress()
	save.set_setting("no_ads", false)
	ads.wins_since_ad = 0
	ads._last_ad_ms = -1
	# New player: no full-screen ads before 8 completed levels.
	for i in 5:
		ads.on_win()
	var went := [0]
	ads.maybe_interstitial(func(): went[0] += 1)
	_expect(went[0] == 1 and fake.shown.interstitial == 0, "no full-screen ad for a new player, game continues")
	# 8 levels completed, 5 wins: one ad, then the counter starts again.
	for i in 8:
		save.levels["t%d" % i] = {"revision": 1, "rulesVersion": 1, "stars": 1, "best": {}}
	ads.maybe_interstitial(func(): went[0] += 1)
	_expect(fake.shown.interstitial == 1 and went[0] == 2, "after 8 levels and 5 wins a full-screen ad shows, then continues")
	for i in 5:
		ads.on_win()
	ads.maybe_interstitial(func(): went[0] += 1)
	_expect(fake.shown.interstitial == 1 and went[0] == 3, "5 more quick wins: no second ad within 3 minutes")
	# Rewarded hint.
	var hint := [false]
	ads.show_rewarded(func(): hint[0] = true)
	_expect(hint[0] and fake.shown.rewarded == 1, "a rewarded ad unlocks the hint")
	# Banner on the result screen.
	ads.show_banner()
	_expect(fake.banner_visible, "result screen shows a banner")
	_expect(not ads.can_buy(), "Remove ads is parked: no button")
	# Remove ads logic (kept for later): simulate the purchase directly.
	ads.set_no_ads(true)
	_expect(ads.no_ads() and not fake.banner_visible, "Remove ads hides the banner at once")
	hint[0] = false
	ads.show_rewarded(func(): hint[0] = true)
	_expect(hint[0] and fake.shown.rewarded == 1, "after Remove ads hints are free, with no ad")
	ads._last_ad_ms = -1
	for i in 10:
		ads.on_win()
	_expect(not ads.interstitial_due(), "after Remove ads no full-screen ads")
	ads.show_banner()
	_expect(not fake.banner_visible, "after Remove ads no banner")
	save.set_setting("no_ads", false)
	save.reset_progress()
	print("Ads flow: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)
	return false


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
