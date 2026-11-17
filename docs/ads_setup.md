# Ads and "Remove ads": setup (v1.1)

**Status (10 Nov 2026):** the AdMob plugin (Poing Studios v5.2.0) is installed in
`addons/admob/` and enabled. Its Android libraries were built from source for Godot
4.7.2 (core + ads only, no mediation). The App ID and the 3 ad unit ids are set; test
mode (`AdIds.USE_TEST_ADS`) is ON. "Remove ads" is parked (`AdIds.REMOVE_ADS_ENABLED
:= false`), so the Billing plugin and step 3's product are not needed yet.
For the release build: set `USE_TEST_ADS := false`, re-export, upload.

All game code is done and tested (rules, rewarded hints, result banner,
full-screen ads, Remove ads, consent). What is left needs the Godot editor and
your Google accounts, so it is done on your Mac.

## 1. Install the two plugins (Godot editor, once)

1. **AdMob** by Poing Studios: AssetLib tab → search "AdMob" → Download →
   Install. Enable it in Project → Project Settings → Plugins. Then
   Project → Tools → AdMob Manager → Android → **Download & Install**.
2. **GodotGooglePlayBilling**: download the latest release from
   github.com/godot-sdk-integrations/godot-google-play-billing, copy it to
   `addons/GodotGooglePlayBilling/`, enable it in Plugins.
3. The Android export already uses the Gradle build (required by both).
4. Add `addons/admob/*/sample/*` to the export exclude filter if the plugin has
   sample folders.

The game finds both plugins automatically (`scripts/ads/mobile_backend.gd`).
Without them it uses a fake backend, so desktop play and tests keep working.

## 2. AdMob account

1. admob.google.com → Apps → Add app → Android → "Color Curves"
   (link it to the Play listing).
2. Copy the **App ID** (`ca-app-pub-…~…`) into the AdMob plugin settings
   (AdMob Manager / project settings of the plugin).
3. Create 3 ad units: **Banner**, **Interstitial**, **Rewarded**.
4. Put the 3 ad unit ids in `scripts/ads/ad_ids.gd` → `REAL.android`.
5. Keep `USE_TEST_ADS := true` while testing on your phone. Set it to `false`
   only for the release build. Never tap real ads on your own phone.

## 3. Google Play Console

1. Monetize → Products → In-app products → Create: id **`remove_ads`**,
   one-time, a price (e.g. 1.99 USD), name "Remove ads" / "إزالة الإعلانات".
2. App content → **Ads: Yes, my app contains ads**.
3. App content → **Data safety**: add the data Google AdMob collects
   (see "Data safety" below), and that purchases are processed by Google Play.
4. Publish the v1.1 privacy policy (`docs/store/privacy_policy_v1.1.md`) on the
   website before the update goes live.
5. AdMob → Privacy & messaging → create a **GDPR** consent message (needed for
   the consent form to appear in the EU/UK).

## 4. Data safety (based on Google's AdMob disclosure; re-check it there)

Collected and shared, for advertising, analytics and fraud prevention:
- Device or other IDs (advertising ID)
- Approximate location (from IP address)
- App interactions with ads, app info and performance (diagnostics)

Data is encrypted in transit. No account, so no deletion request flow is needed
for your own data (Rawan Studio stores none).

## 5. Test on the phone (with test ads)

- Win 8 different levels, then 5 more wins: a full-screen ad shows when leaving
  the result screen; another one only after 3 minutes and 5 more wins.
- Result screen: banner at the bottom.
- Hint → "Show first line": a video, then the line appears.
- Settings → Remove ads → Google Play test purchase (add your Gmail as a
  license tester in Play Console). Ads disappear; hints become free.
- Reinstall → Settings → Restore purchases: ads stay off.

## Where the code is

| File | What |
|---|---|
| `scripts/core/ad_rules.gd` | When a full-screen ad may show (tested) |
| `scripts/autoload/ads.gd` | The one place the game asks for ads |
| `scripts/ads/mobile_backend.gd` | AdMob + Google Play Billing |
| `scripts/ads/fake_backend.gd` | Desktop / tests |
| `scripts/ads/ad_ids.gd` | Ad unit ids, test switch, product id |
| `tests/ads_flow.gd` | Ads flow test |

## app-ads.txt (AdMob asks for it)

`docs/site/app-ads.txt` contains the line AdMob needs for publisher
pub-4106639606201110. Upload it to the root of the website (for example
`https://your-site/app-ads.txt`) and put that website in the Play listing's
"Website" field. AdMob checks it within a day or so; ads can still show before.
