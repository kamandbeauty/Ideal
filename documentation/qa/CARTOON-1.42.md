# v1.42.0 — reference-style cartoon graphics QA

## Built source

- Runtime source: `548c2849edc9bb7d6e19cc14daec0fdfb1560350`.
- Rendered previews: bot commit `ce37437` (only JPEG captures differ).
- Android version: **1.42.0 / code 16**, `com.roadsideempire.tycoon`, ARM64.

## Verified automation

- [Project check 43833454368](https://github.com/kamandbeauty/Ideal/actions/runs/43833454368): **passed** import, all **13 test suites**, physical traffic, rendered walkthrough and main-scene startup.
- [Android build 43833454597](https://github.com/kamandbeauty/Ideal/actions/runs/43833454597): **passed** gameplay checks, export, package/version/ABI inspection, signature verification and publication.
- Physical stress: **360 simulated seconds**, 34 spawned, 31 serviced, **27 completed highway-to-highway visits**, all eight facilities visited. No detected penetrations or double-booked bays; exit progress continued throughout.
- Rendered daylight samples: road **`#889DAB`**, lawn **`#D7F15C`**. The grey/lime checks reject the earlier overexposed cyan/yellow appearance.
- **17 previews reviewed**: menus; early and expanded hub; Persian/English; facility sheet; close-up; managers; cases; map; expeditions; event; night; settings; one-way circulation; full hub; tall phone.
- Portrait captures: 540×960 previews of 720×1280 rendering; tall-device capture: 540×1200 preview of 720×1600 rendering.
- Navigation touch rectangles stay on-screen and do not overlap. Width-preserving orthographic projection keeps the gas office in frame on the tall device.
- Full local GDScript lint, parser checks, SVG/XML parsing, neutral-map checks and `git diff --check` passed.

Physics routes, reservations, vehicle collider dimensions, economy logic and save-state fields are unchanged from the validated v1.41 implementation. The new building shells also pass visual-bounds-vs-solid checks at multiple renovation stages.

## Deliverable

[RoadsideEmpire.apk](https://github.com/kamandbeauty/Ideal/releases/download/roadside-empire-apk/RoadsideEmpire.apk), **32,853,264 bytes**.

SHA-256:

```text
4dbb1db69e285f4f08e047014a04c07df87d2e7eaf60006b4c1523476a73c548
```

Public signing-certificate SHA-256:

```text
8792e1d235073b26ec97bd6cae558ded1efa32373ca4eeb39afa1aaf3ff29a46
```

The build reuses the signing cache established for v1.41. Compatibility with the older v1.40 signing key is unverified. Do not uninstall an existing game merely to resolve a package/signature conflict: uninstalling can delete saved progress.

This is automated engine/package QA and visual screenshot review, **not a physical Android-device performance test**. Phone GPU performance and an in-place upgrade still need confirmation on the user's device.
