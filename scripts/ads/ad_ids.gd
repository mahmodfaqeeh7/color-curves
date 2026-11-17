class_name AdIds
extends RefCounted
## AdMob ad unit ids and the "Remove ads" product id.
## USE_TEST_ADS stays true until the real ids from the AdMob console are put
## below. Never publish with real ids while testing on your own phone: tapping
## your own real ads can get the AdMob account banned.

const USE_TEST_ADS := true

## Google's official test ids (safe to use any time).
const TEST := {
	"android": {
		"banner": "ca-app-pub-3940256099942544/9214589741",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
	},
	"ios": {
		"banner": "ca-app-pub-3940256099942544/2435281174",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
	},
}

## Real ids: fill in from AdMob (Apps > Color Curves > Ad units).
const REAL := {
	"android": {
		"banner": "ca-app-pub-4106639606201110/7921837486",
		"interstitial": "ca-app-pub-4106639606201110/9043347461",
		"rewarded": "ca-app-pub-4106639606201110/6006120581",
	},
	"ios": {"banner": "", "interstitial": "", "rewarded": ""},
}

## AdMob App ID (goes into the AdMob plugin's Android settings / manifest).
const APP_ID_ANDROID := "ca-app-pub-4106639606201110~9015427309"

## "Remove ads" is parked for a later version (owner's decision, Nov 2026):
## while false the button is hidden and no billing is started.
const REMOVE_ADS_ENABLED := false

## Google Play Console > Monetize > In-app products: a one-time product with this id.
const REMOVE_ADS_PRODUCT := "remove_ads"


static func unit(kind: String) -> String:
	var platform := "ios" if OS.get_name() == "iOS" else "android"
	var real: String = REAL[platform][kind]
	return TEST[platform][kind] if USE_TEST_ADS or real == "" else real
