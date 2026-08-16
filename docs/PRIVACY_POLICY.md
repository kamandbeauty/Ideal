# Ruby Run Privacy Policy

**Effective date:** 16 August 2026  
**App:** Ruby Run / روبی ران (`com.javidsstudio.rubyrun`)  
**Developer:** Javids Studio

> **Publication TODO:** Before release, the developer must add a real contact address and publish this exact policy at an HTTPS URL, then set `privacy_policy_url` in `data/release_config.json`. No placeholder URL is presented as real.

## Base build covered by this policy

Ruby Run is an offline-first endless runner. The base version in this repository does not create accounts, does not contain an advertising or analytics SDK, does not send gameplay information to a server, and requests no Android permissions. The game does not request names, email addresses, phone numbers, contacts, messages, precise or approximate location, photos, files, camera, or microphone access.

## Information stored on the device

The app stores coins, best score, unlocked and selected skins, daily-reward timestamps, settings, and aggregate gameplay counters locally in the app's private storage. This information is used only to provide gameplay and settings. It is not transmitted by the base build.

The player can erase this information through **Settings → Reset Local Data → Delete Local Data**. Uninstalling the app normally removes its private local data as well (subject to the device/platform backup configuration).

## Daily reward and device time

The game reads the device clock to determine daily-reward availability and detect obvious clock rollback. The timestamp remains in local app storage and is not used to determine location or transmitted.

## Advertising and analytics

The current base build contains neither an advertising SDK nor an analytics SDK. Its optional integration interfaces are disabled. If either service is added in a future release, this policy, the in-app consent behavior where legally required, the Google Play Data Safety declaration, and the third-party SDK inventory must be updated **before** distribution. Gameplay will remain available when an optional service is unavailable.

## Children and inappropriate content

Ruby Run does not knowingly collect personal information from anyone, including children. Store target-audience and Families declarations must be reviewed against the final artwork, advertising configuration, and SDKs before release; this repository does not claim Families approval.

## Security

Local data is held in Android app-private storage. No method of storage is guaranteed absolutely secure. Because the base build transmits no user data, transport encryption is not applicable.

## Changes and contact

Material changes will be reflected in this document and its effective date. Before publication, Javids Studio must provide a monitored privacy contact here and on the hosted policy page.
