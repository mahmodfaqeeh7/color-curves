extends RefCounted
## Real ads and purchases on the phone, through two Godot plugins that are
## installed in the editor (see docs/ads_setup.md):
##   - "AdMob" by Poing Studios: banner, full-screen (interstitial), rewarded,
##     and Google's consent form (UMP) for players in the EU/UK.
##   - "GodotGooglePlayBilling": the one-time "Remove ads" purchase.
## Their classes are looked up by name at run time, so the game still runs
## (with the fake backend) when the plugins are not installed.

const CONSENT_REQUIRED := 2           ## ConsentInformation.ConsentStatus.REQUIRED
const PRIVACY_OPTIONS_REQUIRED := 2   ## ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
const BILLING_OK := 0
const BILLING_INAPP := 0
const PURCHASED := 1
const RETRY_S := 30.0

var _ads: Node
var _cls := {}
var _interstitial = null
var _rewarded = null
var _banner = null
var _loaders := {}          ## keeps loaders alive until their callback fires
var _billing: Node = null
var _started := false


static func find_class(name: String) -> Script:
	for d in ProjectSettings.get_global_class_list():
		if str(d["class"]) == name:
			return load(str(d["path"]))
	return null


static func available() -> bool:
	return OS.get_name() in ["Android", "iOS"] and find_class("MobileAds") != null


func start(ads: Node) -> void:
	_ads = ads
	for n in ["MobileAds", "UserMessagingPlatform", "ConsentRequestParameters", "AdRequest",
			"InterstitialAdLoader", "InterstitialAdLoadCallback", "RewardedAdLoader",
			"RewardedAdLoadCallback", "OnUserEarnedRewardListener", "AdView", "AdSize", "AdPosition",
			"OnInitializationCompleteListener"]:
		_cls[n] = find_class(n)
	_start_billing()
	_request_consent()


# ------------------------------------------------------------------ consent

## Google's consent form first (shown only where the law needs it), then ads.
func _request_consent() -> void:
	var ump = _cls.UserMessagingPlatform
	if ump == null or _cls.ConsentRequestParameters == null:
		_init_ads()
		return
	ump.consent_information.update(_cls.ConsentRequestParameters.new(),
		func(): _after_consent_info(),
		func(_err): _init_ads())


func _after_consent_info() -> void:
	var ump = _cls.UserMessagingPlatform
	var info = ump.consent_information
	if info.get_is_consent_form_available() and int(info.get_consent_status()) == CONSENT_REQUIRED:
		ump.load_consent_form(
			func(form): form.show(func(_err): _init_ads()),
			func(_err): _init_ads())
	else:
		_init_ads()


func privacy_options_required() -> bool:
	var ump = _cls.get("UserMessagingPlatform")
	return ump != null and int(ump.consent_information.get_privacy_options_requirement_status()) == PRIVACY_OPTIONS_REQUIRED


func show_privacy_options() -> void:
	var ump = _cls.get("UserMessagingPlatform")
	if ump != null:
		ump.show_privacy_options_form(func(_err): pass)


func _init_ads() -> void:
	if _started:
		return
	_started = true
	# Load the first ads only once the SDK reports it is ready.
	var listener = _cls.OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status): _on_sdk_ready()
	_cls.MobileAds.initialize(listener)


func _on_sdk_ready() -> void:
	if not _ads.no_ads():
		_load_interstitial()
	_load_rewarded()


# ------------------------------------------------------------------ loading

func _retry(what: Callable) -> void:
	_ads.get_tree().create_timer(RETRY_S).timeout.connect(what)


func _load_interstitial() -> void:
	if _ads.no_ads() or _cls.InterstitialAdLoader == null:
		return
	var cb = _cls.InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad): _interstitial = ad
	cb.on_ad_failed_to_load = func(_err): _retry(_load_interstitial)
	var loader = _cls.InterstitialAdLoader.new()
	_loaders["interstitial"] = loader
	loader.load(AdIds.unit("interstitial"), _cls.AdRequest.new(), cb)


func _load_rewarded() -> void:
	if _cls.RewardedAdLoader == null:
		return
	var cb = _cls.RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad): _rewarded = ad
	cb.on_ad_failed_to_load = func(_err): _retry(_load_rewarded)
	var loader = _cls.RewardedAdLoader.new()
	_loaders["rewarded"] = loader
	loader.load(AdIds.unit("rewarded"), _cls.AdRequest.new(), cb)


# ------------------------------------------------------------------ showing

func show_interstitial(done: Callable) -> void:
	if _interstitial == null:
		done.call()   # nothing ready: never make the player wait
		_load_interstitial()
		return
	var ad = _interstitial
	_interstitial = null
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
		ad.destroy()
		done.call()
		_load_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
		ad.destroy()
		done.call()
		_load_interstitial()
	ad.show()


## The reward is given after the ad closes. If no ad is ready, or it fails to
## show, the player still gets the reward (agreed rule: never block hints).
func show_rewarded(on_reward: Callable, done: Callable) -> void:
	if _rewarded == null:
		on_reward.call()
		_load_rewarded()
		return
	var ad = _rewarded
	_rewarded = null
	var earned := [false]
	var listener = _cls.OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item): earned[0] = true
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
		ad.destroy()
		_load_rewarded()
		if earned[0]:
			on_reward.call()
		else:
			done.call()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
		ad.destroy()
		_load_rewarded()
		on_reward.call()
	ad.show(listener)


func show_banner() -> void:
	if _cls.AdView == null:
		return
	if _banner == null:
		var size = _cls.AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(_cls.AdSize.FULL_WIDTH)
		_banner = _cls.AdView.new(AdIds.unit("banner"), size, _cls.AdPosition.TOP)   # top: never covers the result buttons
		_banner.load_ad(_cls.AdRequest.new())
	else:
		_banner.show()


func hide_banner() -> void:
	if _banner != null:
		_banner.hide()


func drop_ads() -> void:
	## After "Remove ads": free the banner and the waiting full-screen ad.
	if _banner != null:
		_banner.destroy()
		_banner = null
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null


# ------------------------------------------------------------------ "Remove ads"

func _start_billing() -> void:
	var bc := find_class("BillingClient")
	if not AdIds.REMOVE_ADS_ENABLED or bc == null or OS.get_name() != "Android":
		return
	_billing = bc.new()
	_ads.add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.query_purchases_response.connect(_on_owned_purchases)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.start_connection()


func _on_billing_connected() -> void:
	# Product details must be queried before a purchase can start.
	_billing.query_product_details(PackedStringArray([AdIds.REMOVE_ADS_PRODUCT]), BILLING_INAPP)
	_billing.query_purchases(BILLING_INAPP)


## What Google Play says the player owns: the source of truth (it also
## restores "Remove ads" on a new phone, and removes it after a refund).
func _on_owned_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -99)) != BILLING_OK:
		return
	_ads.set_no_ads(_handle(r.get("purchases", [])))


func _on_purchase_updated(r: Dictionary) -> void:
	if int(r.get("response_code", -99)) != BILLING_OK:
		_ads.purchase_finished(false)
		return
	var owned := _handle(r.get("purchases", []))
	if owned:
		_ads.set_no_ads(true)
	_ads.purchase_finished(owned)


func _handle(purchases: Array) -> bool:
	var owned := false
	for p in purchases:
		if AdIds.REMOVE_ADS_PRODUCT in p.get("product_ids", []) and int(p.get("purchase_state", 0)) == PURCHASED:
			owned = true
			if not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(str(p.get("purchase_token", "")))
	return owned


func can_buy() -> bool:
	return _billing != null


func buy_no_ads(ads: Node) -> void:
	if _billing == null or not _billing.is_ready():
		ads.purchase_finished(false)
		return
	var res: Dictionary = _billing.purchase(AdIds.REMOVE_ADS_PRODUCT)
	if int(res.get("response_code", -1)) != BILLING_OK:
		ads.purchase_finished(false)


func restore(_a: Node) -> void:
	if _billing != null and _billing.is_ready():
		_billing.query_purchases(BILLING_INAPP)
