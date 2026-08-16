# Data Safety — current base build

Reviewed: 2026-08-16

| Item | Actual base-build behavior |
|---|---|
| User data collected | No |
| User data shared | No |
| Accounts | None |
| Network gameplay dependency | None |
| Local deletion | Settings → Reset Local Data → Confirm |

Local coins, progress, upgrades, skins, daily timestamps, and preferences never leave app-private storage. Local-only processing is not declared as collection when it is not transmitted.

## SDK inventory

- Unity 6.3 LTS runtime and URP
- Unity Input System
- Unity Cinemachine
- No advertising SDK
- No analytics SDK
- No social/login SDK

Before adding any SDK, review its exact version, Google Play SDK Index status, permissions, collected/shared data, purposes, encryption, retention, deletion controls, consent requirements, and child-directed treatment. Then update the final manifest, this document, and the hosted privacy policy. Never reuse this declaration for a behaviorally different build.
