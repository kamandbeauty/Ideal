# Setup, build and test

## Toolchain

| Tool | Version used by CI |
| --- | --- |
| Flutter | 3.47.9 (stable) |
| Dart | 3.13.7 |
| JDK | Temurin 21 |
| Gradle | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin | 2.4.0 |
| compileSdk / targetSdk | 36 |
| minSdk | 29 (Android 10) |

The device the app is tuned for is a POCO X5 Pro 5G (Snapdragon 778G, MIUI/HyperOS),
but nothing is device-specific.

## Local build

```bash
git clone <this repo> && cd Ideal
flutter --version                 # must report 3.47.x
flutter pub get
flutter analyze                   # must print "No issues found!"
flutter test                      # unit + widget tests
flutter build apk --debug         # build/app/outputs/flutter-apk/app-debug.apk
```

`flutter build apk` generates the Gradle wrapper on first run. To run the Kotlin
unit tests (notification text parsing), do it **after** a build:

```bash
cd android && ./gradlew testDebugUnitTest
# report: android/app/build/reports/tests/testDebugUnitTest/index.html
```

## Signing a release build

```bash
keytool -genkey -v -keystore ~/javidai-release.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias javidai
```

Create `android/key.properties` (git-ignored):

```properties
storePassword=…
keyPassword=…
keyAlias=javidai
storeFile=/absolute/path/to/javidai-release.jks
```

Then `flutter build apk --release` / `flutter build appbundle --release`.

## Continuous integration

`.github/workflows/ci.yml` runs on every push:

1. `flutter pub get`
2. `flutter analyze` — blocking, `pipefail` so a failure really fails
3. `flutter test test/unit` — blocking
4. `flutter test test/widget` — blocking (boots the real widget tree on an
   in-memory database; no device needed)
5. `flutter build apk --debug` — proves the Android side compiles
6. `./gradlew testDebugUnitTest` — Kotlin unit tests
7. Publishes the analyzer output plus the tail of the console log to `ci-log.md`
   on the same branch

Artifacts: the workflow uploads **`javidai-debug-apk`**
(`build/app/outputs/flutter-apk/app-debug.apk`, 14-day retention) so it can be
sideloaded without a local toolchain. Download it from the run summary page or:

```bash
gh run download --name javidai-debug-apk --dir /tmp/javidai
adb install -r /tmp/javidai/app-debug.apk
```

## What still needs a real device

These cannot be verified on a headless runner and must be checked by hand once:

| Check | How |
| --- | --- |
| Persian rendering + RTL | Launch the app: every label must be right-aligned; no clipped glyphs. |
| Font | The Vazirmatn files are bundled in `assets/fonts`; text must not fall back to Roboto. |
| Mic permission | First mic tap → system dialog → deny shows the Persian explanation, allow starts listening. |
| STT (fa-IR) | Speak «یادداشت جدید بساز خرید نان» and confirm the transcript is Persian, not transliterated. |
| TTS (fa-IR) | The reply must be spoken in Persian; if the engine lacks `fa-IR` the app shows the message instead of silence. |
| DB persistence | Create a note, force-stop, relaunch, note is still there. |
| Job scheduling | Create a job one minute out, lock the phone; the reminder must fire and appear in history. |
| Notification access | Grant access, receive a WhatsApp message; it appears under پیام‌ها with app + sender + time. |
| Restart behaviour | Kill the app, receive notifications, reopen: `bootstrap()` imports what the listener captured. |
| Battery optimisation | Toggle the exemption from Settings → پایداری در پس‌زمینه; the system dialog (or the battery-optimisation list on ROMs without it) must appear and the state must persist. |
| Exact alarms | On Android 12+, Settings shows whether exact alarms are allowed. If not, the job is still scheduled inexactly and the reminder still fires, only later. |
