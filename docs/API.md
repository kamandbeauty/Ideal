# AI providers

The MVP is fully functional **offline**: intent parsing, notes, jobs, briefings
and responses are rule-based and local. A cloud model is an optional upgrade for
free-form conversation, not a requirement.

## Interfaces

```dart
abstract class SpeechRecognizer { /* fa-IR STT */ }
abstract class TtsEngine        { /* fa-IR TTS  */ }
```

Both are supplied through Riverpod (`speechRecognizerProvider`,
`ttsEngineProvider`) and implemented by `NativeSpeechRecognizer` (Android
`SpeechRecognizer`) and `NativeTtsEngine` (Android `TextToSpeech`). To add a
provider, implement the interface and override the provider — no screen changes.

## Adding a cloud AI provider

1. Add a client behind a small interface (do not call `http` from widgets):

```dart
abstract class AiProvider {
  Future<String> complete({
    required String systemPrompt,
    required List<AiMessage> messages,
    bool allowNotificationContent = false,
  });
}
```

2. Read the key only from `SecureStore`:

```dart
final key = await ref.read(secureStoreProvider).readApiKey();
if (key == null || key.isEmpty) {
  // Persian error: «کلید API ثبت نشده است.» — never fall back to a fake key.
}
```

3. Gate notification content on the setting, not on the provider:

```dart
final includeMessages = ref.read(settingsProvider).shareNotificationsWithCloud;
```

4. Keep tool execution local. A model may *propose* a tool call; `AgentCore`
   validates the tool name against `ToolRegistry`, checks the risk tier, builds
   the preview, and waits for user confirmation. Model output is never executed.

## Suggested providers (optional)

| Provider | STT fa-IR | TTS fa-IR | Notes |
| --- | --- | --- | --- |
| Android on-device | ✅ with `fa-IR` language pack | depends on engine | free, offline, default |
| Azure Speech | ✅ `fa-IR` | ✅ `fa-IR-DilaraNeural`, `fa-IR-FaridNeural` | needs a key; useful when a device has no Persian voice |

## Configuration checklist

- [ ] No key committed: `git grep -i "api_key"` shows only the storage key name.
- [ ] Cloud toggle defaults to off.
- [ ] Turning the toggle off returns to the offline parser immediately.
- [ ] The AI settings screen validates the key format client-side and never
      echoes it back in plain text.
