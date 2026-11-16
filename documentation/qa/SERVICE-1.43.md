# v1.43.0 — live service feedback and Persian UI QA

## Build identities

- Android version: **1.43.0 / code 17**, debug-signed, ARM64.
- Final packaging source: `221d79bd4983b43d41530456ea5ee5de648939b1`.
- Engine-validated runtime source: `23b5164a3c109857026bac900843c22f4a648dd2`. The later packaging commits change only the APK workflow; scripts, assets, scenes, tests, tools, project and export-preset metadata are identical.
- Rendered previews: bot commit `f23defc`.
- Main app: `com.roadsideempire.tycoon`. Separate trial app: `com.roadsideempire.preview`, launcher label **Roadside Empire Preview**.

## Changes reviewed

- Actual service gates control the feedback: no foam, cable, rollers or service icon while arriving, waiting to depart, reversing or merging. Payment hides the feedback before departure.
- A fixed-size MultiMesh pool supplies facility-specific foam, charge pulses, repair glints and refresh/food/rest/cinema accents. Fuel/EV cables remain aligned with the world-space pump, without modifying a vehicle's pose. Wash rollers visibly rotate during service.
- Eight distinct service symbols also appear on small facade plaques. Indicators clear the canopy/gantry rather than disappearing under it.
- Low/medium/high budgets are **0 / 6 / 10 particles per customer**. Live quality changes resize only the pool. Effects have no physics, lights, Timer nodes, per-frame node spawning, random draws, income writes or save fields, and are freed with their owning car.
- Persian facility/manager levels, multipliers, customer prices, event seconds and bay numbers are localized. Existing painted numbers update on language change without moving their bays.
- Floating badges use cached styles, 44 px-high touch targets and translated-text bounds. Their projected geometry is explicitly LTR, while text retains bidi shaping; this fixes the RTL zero-width-holder mirroring caught by the rendered assertions.

## Verified automation

- [Project check 43961787180](https://github.com/kamandbeauty/Ideal/actions/runs/43961787180): **passed** import, **3,938 checks / 82 methods / 14 suites**, physical traffic, rendered walkthrough and main-scene startup.
- [Final APK build 43963455495](https://github.com/kamandbeauty/Ideal/actions/runs/43963455495): **passed** import/gameplay/traffic checks, both exports, main and Preview package/version/ABI/launcher-label inspection, signature equality checks, checksums and publication.
- [Previous explicit-signer build 43962880200](https://github.com/kamandbeauty/Ideal/actions/runs/43962880200): both APKs used the **same certificate as the final build**, independently confirming the selected cached identity across two jobs. APK file hashes differ between exports; byte-for-byte reproducibility is not claimed.
- Traffic stress: **360 simulated seconds**, **34 spawned / 31 serviced / 27 complete highway-to-highway visits**, all eight facilities. No detected vehicle/scenery penetrations or double-booked bays. The scenario observes all eight service effects, checks phase/visibility/activation/parking alignment every tick and changes low/medium/high budgets while customers are live.
- **21 rendered captures** pass portrait navigation bounds/non-overlap, badge bounds, Persian-label and live bay-language assertions. The service close-up waits for a real highway arrival and ServiceQueue progress, not a teleported/posed vehicle. High and low quality captures verify service continuity.
- Reviewed the capture overview and principal full-size day/night, Persian/English, station, managers, close-up and tall-phone views. Daylight samples remain road **`#889DAB`**, lawn **`#D7F15C`**. The tall 720×1600 composition still includes the gas office.
- Previews are 540×960 (720×1280 render), except the 540×1200 tall-phone preview (720×1600 render).
- Local GDScript lint/parser checks, SVG XML, workflow YAML, every APK workflow bash block, preview-metadata Python compilation and whitespace checks pass.

Vehicle routes, collision envelopes/layers, ownership/reservations, statistical economy and save-state fields have not changed. The traffic result remains the same as the previous graphics release.

## Signing correction and installation safety

Final public signing-certificate SHA-256 (both APKs):

```text
bb6840034c2fdbaafebcd65487cd4b572cec1bd96eec875a7b634a23ffc53b99
```

The earlier SDK-keystore cache did **not** by itself select Godot's exported signing identity. Godot was free to generate/use an editor-local debug key. This was discovered when checking the first v1.43 export against v1.42, before recommending a download. That initial v1.43 artifact has been superseded.

The workflow now explicitly supplies `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, user and the standard debug password, pins the **public certificate digest**, and verifies that **each exported APK certificate equals both the selected key and the pin**. Missing cache or mismatched identity fails the build; it never silently creates a replacement. Private key material is not committed or published. The cache is not a permanent key backup; a production release still needs securely backed-up signing material.

The actual v1.42 certificate was `8792e1d235073b26ec97bd6cae558ded1efa32373ca4eeb39afa1aaf3ff29a46`, so **an installed v1.42 main app cannot be replaced in place with this corrected main APK**. Compatibility with the user's older v1.40 installation is unverified. The historical [v1.42 QA record](CARTOON-1.42.md) has been corrected rather than retaining the earlier mistaken cache-reuse inference.

**For a non-destructive trial, use `RoadsideEmpire-Preview.apk`.** Its verified distinct package ID gives it separate app storage and a distinct launcher name. It does not replace the installed game and does **not** import its progress. Keep the old installation. Never uninstall a game just to resolve a signing conflict: doing so can delete saved progress.

## Published deliverables

The links are rolling release assets. Sizes and hashes below identify this verified build.

| APK | Package | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [RoadsideEmpire-Preview.apk](https://github.com/kamandbeauty/Ideal/releases/download/roadside-empire-apk/RoadsideEmpire-Preview.apk) | `com.roadsideempire.preview` | 32,887,471 | `a8dfa85bf12a1164468da45bf77bd9373063b5c89da80e8a48fb46a0a9c4af64` |
| [RoadsideEmpire.apk](https://github.com/kamandbeauty/Ideal/releases/download/roadside-empire-apk/RoadsideEmpire.apk) | `com.roadsideempire.tycoon` | 32,887,471 | `9b790b12d5bf9945cecaa229f60a0b5bc1e35f6312fee41645019d7c02e5c023` |

Both have matching `.apk.sha256` assets. GitHub's published asset digests were compared with the build's checksum annotations. Package metadata, signing certificate and version were checked in CI before either file was published.

## Limitations

This is automated engine/package QA and screenshot review, **not a physical Android-device installation/performance test**. New-device GPU frame time, memory, battery use and update installation within the newly pinned signing series remain unmeasured. The low preset's existing shadow/MSAA changes produce a darker Compatibility-rendered image; high/low captures establish effect continuity, not pixel-identical lighting or a performance benchmark. The default high preset retains the validated bright reference palette.
