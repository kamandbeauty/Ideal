# Permissions, privacy and data

JavidAI is local-first. Nothing leaves the phone unless you switch on a cloud
provider **and** type an API key in Settings → هوش مصنوعی.

## What the app asks for

| Permission | Why | What it does **not** give |
| --- | --- | --- |
| `RECORD_AUDIO` (میکروفون) | Speech-to-text while you hold/tap the mic button. Recording starts only on a tap and stops when listening stops. | No background recording. No audio is ever uploaded by the app; Android's own recogniser handles it under its own policy. |
| `POST_NOTIFICATIONS` (اعلان‌ها) | Show reminders and the daily briefing as system notifications. | Nothing is read. Declining only means reminders appear inside the app instead. |
| Notification access (`BIND_NOTIFICATION_LISTENER_SERVICE`) | Read the notification shade so WhatsApp/Telegram/SMS messages can be listed and summarised. Granting happens in Android Settings, never inside the app. | **Not** chat history, not message content older than the grant, not media, not other apps' storage. Android has no API for those, and the app does not try to find one. |
| `SCHEDULE_EXACT_ALARM` | Fire a reminder at the exact minute the user asked for. | No access to other alarms. If exact alarms are unavailable the app degrades to inexact scheduling and says so. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ask the user (via a system dialog) to exempt JavidAI from battery optimisation so reminders are not delayed. | The user can refuse; the app keeps working with less reliable timing. |

### Notification access is not chat history

The listener only sees `Notification` objects posted **after** access is granted,
and only the fields Android exposes: package, app label, sender/title, text,
timestamp. The Messages screen says this in Persian, and the privacy screen
repeats it. The app cannot read deleted messages, media, or anything the sending
app did not put in the shade.

### SMS and Play policy

The app does **not** request `READ_SMS`. SMS content is only what the messaging
app posts to the notification shade, which is the same data the user already
sees on their lock screen. No SMS permission is declared in the manifest, so the
restricted-permission Play policy for SMS/call log does not apply.

## Data storage

| Data | Where | Retention |
| --- | --- | --- |
| Notes | SQLite `notes` | until deleted |
| Jobs + run history | SQLite `jobs`, `job_runs` | history trimmed per job (`limit 20` in the UI) |
| Captured notifications | SQLite `notifications` | auto-purged after the retention window (default 30 days, configurable in Settings) |
| Assistant activity | SQLite `assistant_messages` | until cleared in Settings → حریم خصوصی |
| App settings | SharedPreferences | until reset |
| AI API key | Android Keystore via `flutter_secure_storage` | until removed in Settings; never written to SQLite or logs |

Every table is created by `AppDatabase` on a normal `getDatabasesPath()` file, so
data survives restarts and normal app updates (migrations are additive).

## What the user can do

From **تنظیمات → حریم خصوصی و داده‌ها**:

- see exactly what is stored, table by table, in Persian;
- read the explanation for every permission before granting it;
- export notes/jobs to the clipboard (no file permission needed);
- delete all notifications, or all assistant activity, with a confirmation;
- remove the stored API key.

From **تنظیمات → هوش مصنوعی**:

- choose the local (offline) engine, which sends nothing anywhere;
- optionally enable a cloud provider and paste a key. Until then the cloud path
  is disabled and no message or notification text is ever transmitted;
- keep notification content out of cloud requests, independently of the
  provider choice.

## Threat model / guarantees

- **No hard-coded secrets.** The repository contains no keys; `SecureStore` is
  the only reader/writer.
- **No arbitrary execution.** The agent can only call tools registered in
  `ToolRegistry`; there is no shell, no `dart:io` process, no eval, no generic
  HTTP tool.
- **Confirmation before side effects.** Any tool above `readOnly` requires the
  confirmation sheet, which shows a preview of exactly what will be written.
- **No silent uploads.** Providers default to local; enabling cloud requires an
  explicit toggle plus a key, and notification content can be excluded
  separately.
- **No fake data.** The briefing summarises only rows that exist in the database.
