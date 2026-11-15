# LAST WALL — AdMob integration

## Current integration state

- Godot AdMob plugin: v7.0, pinned to the release archive and SHA-256 in the Android workflow.
- Supported engine: Godot 4.7; the game currently uses Godot 4.7.2.
- Native integration: Android v2 plugin, packaged with Gradle.
- Formats wired in code: rewarded video and interstitial.
- Consent: UMP consent information is refreshed on launch; ads are requested only after consent is obtained or not required.
- Banner ads are intentionally not enabled in the combat HUD.
- The checked-in configuration uses Google's official test App ID and test ad-unit IDs. It cannot generate publisher revenue.

## First Android build

The CI workflow downloads the pinned plugin release, verifies its SHA-256, imports the project, installs the Godot Android build template and exports ARM64 APKs.

The Android export presets request only the network permissions needed by the SDK:
- INTERNET
- ACCESS_NETWORK_STATE

Google Play's advertising ID permission may be merged by the Google SDK. No location, contacts, microphone, camera or storage permission is requested by this integration.

## Before production monetization

1. The publisher must be the real, eligible owner/operator of the app and comply with the applicable Google publisher policies and local law.
2. Create the LAST WALL app in the publisher's own AdMob account.
3. Configure the app's real App ID and separate rewarded/interstitial ad-unit IDs.
4. Publish a developer website in the Google Play listing and verify the app-ads.txt file.
5. Configure a Google-certified CMP / AdMob Privacy & Messaging for EEA, UK and Switzerland.
6. Complete AdMob app verification and app readiness review.
7. Only then switch the runtime node to production IDs and set the export configuration to real mode.

Do not replace test IDs with production IDs in development or CI smoke tests. Never click your own live ads. A missing SDK, unavailable consent form, failed request or no-fill response must never block gameplay.

## Gameplay policy

- Rewarded video is opt-in. The game must grant its reward only from Ads.reward_earned, which is emitted by the SDK's reward callback.
- Interstitials are only attempted after a completed match, never during combat, pause, loading, a wave or a result transition.
- Interstitial frequency is capped at one per three minutes.
- The current game economy has no ad reward sink yet. Connect Ads.reward_earned to a clearly described, optional reward (for example, a post-match supply crate) before exposing a rewarded-ad button in the UI.
