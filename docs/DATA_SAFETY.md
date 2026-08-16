# Google Play Data Safety — Base Build

Last reviewed: 2026-08-16. This document describes the repository's **actual base configuration**, not a future ad-supported build.

## Declaration summary

| Question | Base-build answer |
|---|---|
| Does the app collect user data? | No |
| Does the app share user data with third parties? | No |
| Is all data encrypted in transit? | Not applicable; no data is transmitted |
| Can users request deletion? | No account/server data exists; local data has an in-app reset |
| Account creation | None |

## Local-only data

Coins, scores, skins, settings, daily reward timestamps, run count, and collected-coin count are stored in `user://ruby_run_save.json` (Android app-private storage). Local-only processing is not declared as collection under the Data Safety definition when it never leaves the device. Reset Local Data erases it.

## SDK inventory

| Component | Data collected/shared | Network | Purpose |
|---|---|---|---|
| Godot Engine 4.7.1 official runtime/export templates | None by app configuration | None | Game engine |
| Ad SDK | **Not included** | None | Interface disabled |
| Analytics SDK | **Not included** | None | Interface disabled |

There are no third-party binary plugins in the base build. The Android export has `INTERNET=false` and `ACCESS_NETWORK_STATE=false`. Android may merge platform-required manifest declarations from official export templates; inspect the final manifest before upload.

## Required review when adding a service

Before enabling ads, analytics, crash reporting, cloud saves, or another SDK, document: exact SDK and version; collected and shared data; purpose; retention; encryption; deletion/control; required permissions; consent requirements; data-processing terms; Google Play SDK Index/policy status; and whether identifiers or diagnostics are used. Then update this file, the hosted privacy policy, consent flow, store declarations, and final-manifest audit. Do not copy this base declaration to a build whose behavior differs.
