extends Node
## v1.1 ads: the one place the game asks for ads. Rules live in AdRules
## (scripts/core/ad_rules.gd). On a phone with the AdMob and Billing plugins
## installed it uses scripts/ads/mobile_backend.gd; everywhere else (desktop,
## editor, tests) a fake backend that completes instantly.

signal no_ads_changed
signal purchase_done(ok: bool)

var backend: Object
var wins_since_ad := 0
var _last_ad_ms := -1

const FakeBackend := preload("res://scripts/ads/fake_backend.gd")
const MobileBackend := preload("res://scripts/ads/mobile_backend.gd")


func _ready() -> void:
	backend = MobileBackend.new() if MobileBackend.available() else FakeBackend.new()
	backend.start(self)


func no_ads() -> bool:
	return bool(Save.get_setting("no_ads"))


func set_no_ads(value: bool) -> void:
	if value == no_ads():
		return
	Save.set_setting("no_ads", value)
	if value:
		hide_banner()
		if backend.has_method("drop_ads"):
			backend.drop_ads()
	no_ads_changed.emit()


func completed_levels() -> int:
	var n := 0
	for rec in Save.levels.values():
		if int(rec.get("stars", 0)) > 0:
			n += 1
	return n


func seconds_since_last_ad() -> float:
	return INF if _last_ad_ms < 0 else (Time.get_ticks_msec() - _last_ad_ms) / 1000.0


## Called on every win.
func on_win() -> void:
	wins_since_ad += 1


func interstitial_due() -> bool:
	return AdRules.interstitial_due(wins_since_ad, seconds_since_last_ad(), completed_levels(), no_ads())


## Called when the player leaves the result screen (Next / Levels / Replay):
## shows a full-screen ad if one is due, then continues.
func maybe_interstitial(then: Callable) -> void:
	if not interstitial_due():
		then.call()
		return
	wins_since_ad = 0
	_last_ad_ms = Time.get_ticks_msec()
	hide_banner()
	backend.show_interstitial(then)


## Hints: "Show first line" / "Show solution" are unlocked by a rewarded ad
## (free after "Remove ads"). on_reward runs when the hint may be shown.
func show_rewarded(on_reward: Callable, on_skipped: Callable = func(): pass) -> void:
	if no_ads():
		on_reward.call()
		return
	backend.show_rewarded(on_reward, on_skipped)


func show_banner() -> void:
	if not no_ads():
		backend.show_banner()


func hide_banner() -> void:
	backend.hide_banner()


## True when "Remove ads" can really be bought here (billing available).
func can_buy() -> bool:
	return AdIds.REMOVE_ADS_ENABLED and backend.can_buy()


func buy_no_ads() -> void:
	backend.buy_no_ads(self)


func restore_purchases() -> void:
	backend.restore(self)


func purchase_finished(ok: bool) -> void:
	purchase_done.emit(ok)


func privacy_options_required() -> bool:
	return backend.privacy_options_required()


func show_privacy_options() -> void:
	backend.show_privacy_options()
