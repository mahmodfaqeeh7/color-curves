extends RefCounted
## Stand-in ad backend for desktop, the editor and tests: every ad "shows"
## instantly and completes, so the game flow can be played and tested.

var shown := {"banner": 0, "interstitial": 0, "rewarded": 0}
var banner_visible := false
var purchases := 0


func start(_ads: Node) -> void:
	pass


func show_interstitial(done: Callable) -> void:
	shown.interstitial += 1
	done.call()


func show_rewarded(on_reward: Callable, _done: Callable) -> void:
	shown.rewarded += 1
	on_reward.call()


func show_banner() -> void:
	shown.banner += 1
	banner_visible = true


func hide_banner() -> void:
	banner_visible = false


## Only on desktop / in tests: a phone without the billing plugin must never
## get "Remove ads" for free.
func can_buy() -> bool:
	return not OS.has_feature("mobile")


func buy_no_ads(ads: Node) -> void:
	if not can_buy():
		ads.purchase_finished(false)
		return
	purchases += 1
	ads.set_no_ads(true)


func restore(_ads: Node) -> void:
	pass


func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> void:
	pass
