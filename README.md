<div dir="rtl">

# JavidAI — دستیار هوشمند اندروید

دستیار صوتی فارسی که **آفلاین** کار می‌کند: یادداشت برمی‌دارد، برایتان یادآوری می‌سازد،
اعلان‌های واتساپ/تلگرام/پیامک را می‌خواند و هر روز صبح یک خلاصهٔ صوتی از روزتان می‌دهد.
همهٔ داده‌ها روی خود گوشی می‌مانند؛ هیچ کلید API در کد نیست و هیچ پیامی بدون اجازهٔ
شما جایی فرستاده نمی‌شود.

</div>

> **Status:** Milestones 1–6 of the build spec are implemented in source. CI runs
> `flutter analyze`, unit tests, widget tests, the debug APK build and the Kotlin
> unit tests on every push (see the badge section below for the current state).
> Real-device verification items that cannot be reproduced on a headless CI
> runner are listed in [docs/SETUP.md](docs/SETUP.md#what-still-needs-a-real-device).

## Features

| Area | What works |
| --- | --- |
| **Voice assistant** | Mic button with idle / listening / processing / speaking states, live Persian transcript, spoken reply, stop / cancel / repeat. Persian TTS via the device engine; `fa-IR` STT via Android's `SpeechRecognizer`. Both behind swappable interfaces (`SpeechRecognizer`, `TtsEngine`). |
| **Notes** | Create, edit, delete (with confirmation), full-text search, categories, timestamps, dictation into the editor, and Persian commands such as «این متن را ذخیره کن» or «یادداشت جدید بساز: …». |
| **Jobs** | One-time, daily, weekly and interval schedules; enable/disable; run history; retry with backoff; exact alarms with a WorkManager-style fallback on Android. Minimum interval is 15 minutes, mirroring Android's periodic-work floor. |
| **Notification reader** | Kotlin `NotificationListenerService` → SQLite. Per-app toggles, sender/app/time/content, dedupe by `package\|sender\|text`, retention window, delete, mark-read. Notification access ≠ chat history, and the UI says so. |
| **Daily briefing** | Summarises captured notifications, groups them by app, highlights urgent/missed items and today's jobs, and speaks a Persian summary. It only repeats what was actually captured — it never invents content. |
| **Agent** | `AgentCore` + `IntentParser` + `ToolRegistry` with three risk tiers (`readOnly`, `localReversible`, `externalSensitive`). Destructive actions require an explicit confirmation sheet with an action preview. There is no shell and no code execution tool. |
| **Privacy** | Local SQLite, API keys in the Android Keystore, data export to clipboard, delete-all actions, permission explanations, and cloud AI is off until you enable it. |

## Repository layout

```
lib/
  app/            MaterialApp, RTL shell, five-tab navigation
  core/           providers (Riverpod), theme, Persian date/number utilities
  data/           SQLite schema + migrations, models, repositories
  features/       agent, assistant, dashboard, jobs, messages, notes, settings
  l10n/           Persian MaterialLocalizations
  services/       job/note/briefing services, notification ingestion, native bridge
  ui/widgets/     glass cards, mic button, status chips, dictation field
android/app/src/main/kotlin/ai/javid/app/
  MainActivity.kt, JavidNativeChannel.kt
  notifications/  NotificationListenerService, source classification, store
  reminders/      exact-alarm scheduler, receiver, notifications
test/
  unit/           parser, schedules, services, repositories, models, state machine
  widget/         RTL navigation smoke tests + confirmation flow
  helpers/        in-memory SQLite + provider overrides
docs/             architecture, setup, permissions & privacy
```

## Quick start

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug      # -> build/app/outputs/flutter-apk/app-debug.apk
```

Requirements: Flutter 3.47.x (Dart 3.13), JDK 21, Android SDK 36, minSdk 29.
The full walkthrough — including signing, the Gradle unit tests and the CI
workflow — is in [docs/SETUP.md](docs/SETUP.md).

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layers, agent pipeline, data model
- [docs/SETUP.md](docs/SETUP.md) — toolchain, build, run, test, CI, device checks
- [docs/PERMISSIONS.md](docs/PERMISSIONS.md) — every permission, what it grants, what it does **not** grant
- [docs/API.md](docs/API.md) — how to plug in an AI provider without leaking data

## Honest limitations

- **STT in Persian** depends on the device: Android's recogniser needs a `fa-IR`
  language pack (Settings → Google → On-device speech recognition). If it is
  missing, the app says so instead of transcribing English silently.
- **TTS in Persian** depends on the installed engine. The app checks
  `isLanguageAvailable('fa-IR')` and shows an actionable message.
- **Background reliability**: exact alarms + battery-optimisation exemption give
  the best chance of on-time reminders. Android may still delay tasks; the job
  history shows every skipped or failed run rather than pretending otherwise.
- **Notification content**: only notifications posted *after* the user grants
  access are visible. There is no access to chat history, and no attempt to
  bypass Android security.

<div dir="rtl">

## مجوز و حریم خصوصی

هیچ داده‌ای به‌صورت پیش‌فرض از گوشی خارج نمی‌شود. کلید سرویس هوش مصنوعی (اختیاری)
در Keystore ذخیره می‌شود و تنها زمانی استفاده می‌شود که خودتان سرویس ابری را روشن
کنید. جزئیات در [docs/PERMISSIONS.md](docs/PERMISSIONS.md).

</div>
