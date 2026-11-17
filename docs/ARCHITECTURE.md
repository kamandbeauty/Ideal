# Architecture

JavidAI is a single-activity Flutter app with a thin Kotlin layer for the two
things Flutter cannot do alone: reading system notifications and waking up at an
exact time. Everything else — parsing Persian, deciding what to do, storing data,
speaking — happens in Dart.

```
┌──────────────────────────── Flutter (Dart) ────────────────────────────┐
│ app/            JavidApp → MaterialApp(fa_IR, RTL) → AppShell (5 tabs) │
│ features/       screens + AssistantController (state machine)          │
│ features/agent/ IntentParser → AgentCore → ToolRegistry → services     │
│ services/       NoteService · JobService · BriefingService · Ingestor  │
│ data/           repositories → AppDatabase (sqflite, migrations)       │
│ core/           Riverpod providers, theme, Persian date/number utils   │
└───────────────────────────────┬────────────────────────────────────────┘
                                │ MethodChannel `ai.javid.app/native`
┌───────────────────────────────┴────────────────────────────────────────┐
│ Kotlin: MainActivity, JavidNativeChannel                                │
│   notifications/ NotificationListenerService → NotificationStore       │
│   reminders/     ReminderScheduler (AlarmManager) → receiver → notif   │
└────────────────────────────────────────────────────────────────────────┘
```

## Layers

**Presentation.** `lib/app/router.dart` holds the five destinations
(دستیار، یادداشت‌ها، وظایف، پیام‌ها، تنظیمات). Every screen is real; there is no
placeholder tab. `AppTheme` builds dark and light themes from a shared seed
(deep navy + violet) and applies Vazirmatn to the whole text theme. `JavidApp`
pins `Locale('fa','IR')`, uses `PersianMaterialLocalizations`, and wraps the tree
in `Directionality(TextDirection.rtl)` so layout is right-to-left even on a
device set to another language.

**State.** Riverpod everywhere. Providers are small and single-purpose:

- `databaseProvider` → one `AppDatabase` instance, opened once in `bootstrap()`.
- `*RepositoryProvider` → thin data access over that database.
- `noteServiceProvider`, `jobServiceProvider`, `briefingServiceProvider` → policy.
- `agentCoreProvider` → the parser + services bundle.

`AssistantController` is a `StateNotifier<AssistantState>`; the UI only reacts to
`AssistantState.status` (idle / listening / processing / speaking) and never
talks to the recogniser directly.

**Agent.** The pipeline is deliberately boring and inspectable:

```
text/voice → normalizePersianInput → IntentParser → AgentIntent
           → AgentCore.turn() → AgentTurn { reply, requiresConfirmation?, toolCall? }
           → (user confirms) → AgentToolCall.execute() → ToolResult → spoken reply
```

`IntentParser` is rule-based and deterministic: it handles notes, jobs, job
management, briefings, message summaries, greetings and help, plus Persian date
and clock expressions (Jalali dates, «فردا»، «پس‌فردا»، «شنبه»، «۸ شب»، «۹ و ربع»).
No model call is needed for any of the MVP flows, so the app works offline.

`ToolRegistry` is the only path to a side effect. Tools are registered with one
of three risk tiers:

| Tier | Examples | Confirmation |
| --- | --- | --- |
| `readOnly` | summarise notifications, read the latest note | never |
| `localReversible` | create a note, create a job | yes, with a preview |
| `externalSensitive` | send a message, share data, payments | yes + explicit warning |

The MVP registers only read-only and local-reversible tools; the
`externalSensitive` tier exists so a future messaging tool cannot be added
without a confirmation path. There is **no** shell, code-evaluation or generic
HTTP tool: model output can never become arbitrary code.

**Data.** `AppDatabase` owns an explicit, ordered migration list so upgrades
never drop user data. Tables: `notes`, `jobs`, `job_runs`, `notifications`,
`assistant_messages`, `settings`. Each model has `toMap`/`fromMap` and a
`copyWith`; repositories do the SQL and nothing else.

**Kotlin bridge.** `JavidNativeChannel` exposes:

| Method | Purpose |
| --- | --- |
| `hasNotificationAccess` | whether the listener is enabled |
| `openNotificationSettings` | deep-link to the system screen |
| `fetchCapturedNotifications` | drain what the listener stored while the app was dead |
| `showNotification` | post a local reminder notification |
| `scheduleReminder` / `cancelReminder` | exact alarms via `AlarmManager` |
| `isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimizations` | reliability controls |

Every Dart call degrades gracefully (`try/catch` → sensible default) so the app
still works on a device without notification access or with the bridge missing.

## Agent flow, end to end

1. The user speaks or types. Voice goes through `SpeechRecognizer` (Android
   `fa-IR`), which streams partials into the transcript field.
2. `AssistantController` sets `processing`, calls `AgentCore.turn()`.
3. `IntentParser` returns an `AgentIntent`, e.g. `createNote` with
   `{body, category}`.
4. `AgentCore` builds a human-readable reply and, for anything that writes, an
   `AgentToolCall` with a Persian preview (`title`, `preview`) and the closure
   that performs the write.
5. The UI shows `confirm_action_sheet.dart`: action title, preview, and
   «تأیید و انجام» / «انصراف».
6. On approval the tool runs, the result message is spoken and written to
   `assistant_messages`, and the relevant provider is invalidated so every tab
   refreshes.

## Failure behaviour

- Speech recognition errors become a Persian message and return the machine to
  `idle` (never a stuck spinner).
- A job that fails is retried with backoff (`JobService.maxRetries = 3`), then
  marked failed and surfaced in the run history.
- Notification ingestion skips empty payloads, unknown packages become
  `NotificationSource.other`, bad timestamps fall back to capture time, and
  duplicates collapse on `package|sender|text`.
- The brief states what it has: no notifications → it says there is nothing to
  summarise instead of inventing a summary.
