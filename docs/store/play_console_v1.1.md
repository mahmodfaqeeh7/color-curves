# Play Console answers for v1.1 (ads)

## App content → Ads
- Does your app contain ads? **Yes**

## App content → Privacy policy
- URL: `https://<your-site>/privacy.html` (the updated page with the Ads section)

## Store settings → Store listing contact details
- Website: `https://<your-site>/` (must be the site that serves `/app-ads.txt`)

## App content → Data safety
Answers for an app whose only data collection is Google AdMob (no accounts, no
own servers). Re-check against Google's "AdMob data disclosure" page when filling.

1. Does your app collect or share any of the required user data types? **Yes**
2. Is all of the user data collected by your app encrypted in transit? **Yes**
3. Do you provide a way for users to request that their data is deleted? **No**
   (Rawan Studio stores no user data; ad data is handled by Google.)

Data types (mark each as **Collected** and **Shared**, processed **ephemerally: No**,
collection **required**; purposes: **Advertising or marketing, Analytics, Fraud
prevention, security, and compliance**):
- **Location → Approximate location** (from IP address)
- **App activity → Other app activity / App interactions** (ad interactions)
- **App info and performance → Crash logs, Diagnostics**
- **Device or other IDs → Device or other IDs** (advertising ID)

## App content → Advertising ID
- Does your app use advertising ID? **Yes** → purpose: **Advertising or marketing**

## Target audience
- Unchanged: 13 and over (ads are not designed for children).
