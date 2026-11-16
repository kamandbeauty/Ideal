# CI log (run 43965400070)

```
Flutter 3.47.9 • channel stable • https://github.com/flutter/flutter.git
Framework • revision c197ca5199 (3 weeks ago) • 2026-10-29 10:10:20 -0400
Engine • hash 9e025265bef30b838c0c1b68cad19decf97048f2 (revision 89c39edfdf) (20 days ago) • 2026-10-27 19:51:20.000Z
Tools • Dart 3.13.7 • DevTools 2.60.0
Resolving dependencies...
Downloading packages...
+ args 2.7.0
+ async 2.13.1
+ boolean_selector 2.1.2
+ characters 1.4.1
+ clock 1.1.3
+ code_assets 2.2.0
+ collection 1.19.1
+ crypto 3.0.8
+ fake_async 1.3.3
+ ffi 2.2.0
+ file 7.0.1
+ fixnum 1.1.1
+ flutter 0.0.0 from sdk flutter
+ flutter_lints 5.0.0 (6.0.0 available)
+ flutter_localizations 0.0.0 from sdk flutter
+ flutter_riverpod 2.6.1 (3.5.0 available)
+ flutter_secure_storage 9.2.4 (11.2.0 available)
+ flutter_secure_storage_linux 1.2.3 (3.0.3 available)
+ flutter_secure_storage_macos 3.1.3 (4.0.0 available)
+ flutter_secure_storage_platform_interface 1.1.2 (2.1.1 available)
+ flutter_secure_storage_web 1.2.1 (2.1.1 available)
+ flutter_secure_storage_windows 3.1.2 (4.2.2 available)
+ flutter_test 0.0.0 from sdk flutter
+ flutter_tts 4.2.5
+ flutter_web_plugins 0.0.0 from sdk flutter
+ glob 2.2.0
+ hooks 2.2.0
+ http 1.6.0
+ http_parser 4.1.2
+ intl 0.20.3
+ jni 1.1.2
+ jni_flutter 1.0.4+1
+ jni_util 1.0.0
+ js 0.6.7 (0.7.2 available)
+ json_annotation 4.12.0
+ leak_tracker 11.0.2
+ leak_tracker_flutter_testing 3.0.10
+ leak_tracker_testing 3.0.2
+ lints 5.1.1 (6.1.0 available)
+ logging 1.3.0
+ matcher 0.12.20
+ material_color_utilities 0.13.0 (0.13.1 available)
+ meta 1.19.0
+ mocktail 1.0.5
+ native_toolchain_c 0.19.6
+ objective_c 9.6.4
+ package_config 3.0.0
+ path 1.9.1
+ path_provider 2.1.6
+ path_provider_android 2.3.1
+ path_provider_foundation 2.6.0
+ path_provider_linux 2.2.2
+ path_provider_platform_interface 2.1.3
+ path_provider_windows 2.3.0
+ permission_handler 12.0.3 (13.0.2 available)
+ permission_handler_android 13.0.1 (14.1.1 available)
+ permission_handler_apple 9.6.5
+ permission_handler_html 0.1.4+1
+ permission_handler_platform_interface 4.4.1
+ permission_handler_windows 0.2.4
+ platform 3.2.0
+ plugin_platform_interface 2.1.8
+ process 5.0.6
+ pub_semver 2.2.1
+ record_use 1.1.1
+ riverpod 2.6.1 (3.5.0 available)
+ shared_preferences 2.5.6
+ shared_preferences_android 2.5.5
+ shared_preferences_foundation 2.6.2
+ shared_preferences_linux 2.4.1
+ shared_preferences_platform_interface 2.4.2
+ shared_preferences_web 2.4.3
+ shared_preferences_windows 2.4.1
+ sky_engine 0.0.0 from sdk flutter
+ source_span 1.10.2
+ speech_to_text 7.5.0
+ speech_to_text_platform_interface 2.5.0
+ speech_to_text_windows 1.0.1
+ sqflite 2.4.6
+ sqflite_android 2.4.6
+ sqflite_common 2.5.17
+ sqflite_common_ffi 2.4.7
+ sqflite_darwin 2.4.6
+ sqflite_platform_interface 2.4.4
+ sqlite3 3.9.1
+ stack_trace 1.12.2
+ state_notifier 1.0.0
+ stream_channel 2.1.4
+ string_scanner 1.4.1
+ synchronized 3.6.1+1
+ term_glyph 1.2.2
+ test_api 0.7.12 (0.7.15 available)
+ typed_data 1.4.0
+ url_launcher 6.3.3
+ url_launcher_android 6.3.33
+ url_launcher_ios 6.4.2
+ url_launcher_linux 3.2.3
+ url_launcher_macos 3.2.6
+ url_launcher_platform_interface 2.3.2
+ url_launcher_web 2.4.3
+ url_launcher_windows 3.1.6
+ uuid 4.6.0
+ vector_math 2.4.4
+ vm_service 15.4.0
+ web 1.1.2
+ win32 5.15.0 (6.4.0 available)
+ xdg_directories 1.1.0
+ yaml 3.1.4
Changed 108 dependencies!
16 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing Ideal...                                              

   info • Use the null-aware operator '?.' rather than an explicit 'null' comparison. Try using '?.' • lib/data/models/job_run.dart:26:7 • prefer_null_aware_operators
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/agent/agent_core.dart:92:16 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:239:9 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:240:18 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:242:20 • prefer_const_constructors
warning • Unused import: '../../core/providers/repository_providers.dart'. Try removing the import directive • lib/features/notes/notes_screen.dart:4:8 • unused_import
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:116:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:121:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:126:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:131:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:136:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:14:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:26:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:39:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:52:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:97:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:123:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:128:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:28:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:62:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:79:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:135:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:147:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:152:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:161:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:166:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/models_test.dart:50:17 • prefer_const_constructors
warning • Unused import: 'package:javid_ai/services/voice/native_speech_recognizer.dart'. Try removing the import directive • test/widget/app_smoke_test.dart:10:8 • unused_import
warning • Unused import: 'package:javid_ai/services/voice/native_tts_engine.dart'. Try removing the import directive • test/widget/app_smoke_test.dart:11:8 • unused_import
  error • The argument type 'SilentRecognizer' can't be assigned to the parameter type 'NativeSpeechRecognizer'.  • test/widget/app_smoke_test.dart:96:52 • argument_type_not_assignable
  error • The argument type 'SilentTts' can't be assigned to the parameter type 'NativeTtsEngine'.  • test/widget/app_smoke_test.dart:97:45 • argument_type_not_assignable

31 issues found. (ran in 9.2s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart
test/widget/app_smoke_test.dart:96:52: Error: The argument type 'SilentRecognizer' can't be assigned to the parameter type 'NativeSpeechRecognizer'.
 - 'SilentRecognizer' is from 'test/widget/app_smoke_test.dart'.
 - 'NativeSpeechRecognizer' is from 'package:javid_ai/services/voice/native_speech_recognizer.dart' ('lib/services/voice/native_speech_recognizer.dart').
        speechRecognizerProvider.overrideWithValue(SilentRecognizer()),
                                                   ^
test/widget/app_smoke_test.dart:97:45: Error: The argument type 'SilentTts' can't be assigned to the parameter type 'NativeTtsEngine'.
 - 'SilentTts' is from 'test/widget/app_smoke_test.dart'.
 - 'NativeTtsEngine' is from 'package:javid_ai/services/voice/native_tts_engine.dart' ('lib/services/voice/native_tts_engine.dart').
        ttsEngineProvider.overrideWithValue(SilentTts()),
                                            ^
00:00 +0 -1: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: test/widget/app_smoke_test.dart:96:52: Error: The argument type 'SilentRecognizer' can't be assigned to the parameter type 'NativeSpeechRecognizer'.
   - 'SilentRecognizer' is from 'test/widget/app_smoke_test.dart'.
   - 'NativeSpeechRecognizer' is from 'package:javid_ai/services/voice/native_speech_recognizer.dart' ('lib/services/voice/native_speech_recognizer.dart').
          speechRecognizerProvider.overrideWithValue(SilentRecognizer()),
                                                     ^
  test/widget/app_smoke_test.dart:97:45: Error: The argument type 'SilentTts' can't be assigned to the parameter type 'NativeTtsEngine'.
   - 'SilentTts' is from 'test/widget/app_smoke_test.dart'.
   - 'NativeTtsEngine' is from 'package:javid_ai/services/voice/native_tts_engine.dart' ('lib/services/voice/native_tts_engine.dart').
          ttsEngineProvider.overrideWithValue(SilentTts()),
                                              ^
  .
  Error: The Dart compiler exited unexpectedly.
  package:flutter_tools/src/base/common.dart 34:3  throwToolExit
  package:flutter_tools/src/compile.dart 1024:11   DefaultResidentCompiler._compile.<fn>
  dart:async/zone_root.dart 48:47                  _rootRunUnary
  dart:async/zone.dart 816:35                      _CustomZone.runUnary
  dart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback
  dart:async/future_impl.dart 977:13               Future._propagateToListeners
  dart:async/future_impl.dart 862:9                Future._propagateToListeners
  dart:async/future_impl.dart 720:5                Future._completeWithValue
  dart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>
  dart:async/zone_root.dart 35:13                  _rootRun
  dart:async/zone.dart 810:35                      _CustomZone.run
  dart:async/zone.dart 702:7                       _CustomZone.runGuarded
  dart:async/zone.dart 743:23                      _CustomZone.bindCallbackGuarded.<fn>
  dart:async/schedule_microtask.dart 40:35         _microtaskLoop
  dart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop
  dart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback
  dart:isolate-patch/isolate_patch.dart 193:5      _RawReceivePort._handleMessage
  
00:00 +0 -1: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: converts a valid native entry
00:00 +1 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +2 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +3 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +4 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +5 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +6 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +7 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +8 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +9 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:00 +10 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +11 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:00 +12 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: filters by category
00:00 +13 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: falls back to general for unknown categories
00:00 +14 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: updates content and bumps updatedAt
00:00 +15 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: pins notes to the top of the list
00:00 +16 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: deletes a note
00:00 +17 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: latest returns the most recently updated note
00:00 +18 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data survives closing and reopening the database file
00:00 +18 -2: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data survives closing and reopening the database file [E]
  Expected: 'ماندگار'
    Actual: <null>
     Which: not an <Instance of 'String'>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/note_service_test.dart 100:5              main.<fn>
  
00:00 +18 -2: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (tearDownAll)
00:00 +18 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (setUpAll)
00:00 +18 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: stores and lists notifications newest first
00:00 +19 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key
00:00 +20 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced
00:00 +21 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows
00:00 +22 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows
00:00 +23 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time
00:00 +24 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything
00:00 +25 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: source labels map packages to Persian names
00:00 +26 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: package classification matches the Kotlin implementation
00:00 +27 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (tearDownAll)
00:00 +27 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note round-trips through a map
00:00 +28 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note displayTitle falls back to the body
00:00 +29 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note preview flattens newlines
00:00 +30 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note category labels are Persian
00:00 +31 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job round-trips through a map
00:01 +32 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job isRecurring and isActive reflect the schedule
00:01 +33 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job copyWith can clear nullable fields
00:01 +34 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: JobRun round-trips and computes duration
00:01 +35 -2: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: AssistantMessage round-trips meta
00:01 +36 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a greeting
00:01 +37 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a help request
00:01 +38 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command
00:01 +38 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command [E]
  Expected: IntentType:<IntentType.createNote>
    Actual: IntentType:<IntentType.createJob>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 27:7              main.<fn>.<fn>
  
00:01 +38 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from «یادداشت جدید بساز»
00:01 +39 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes extracts quoted note bodies
00:01 +40 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes infers the work category
00:01 +41 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes asks for the body when the command has none
00:01 +42 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes lists notes
00:01 +43 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes deletes the latest note with confirmation
00:01 +44 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour
00:01 +45 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action
00:01 +46 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation one-off reminder for tomorrow at 09:00
00:01 +47 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «نه و نیم» clock expressions
00:01 +48 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours
00:01 +48 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours [E]
  Expected: <10>
    Actual: <null>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 100:7             main.<fn>.<fn>
  
00:01 +48 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00
00:01 +49 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum
00:01 +49 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum [E]
  Null check operator used on a null value
  test/unit/intent_parser_test.dart 113:64  main.<fn>.<fn>
  
00:01 +49 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation weekly schedule on Saturday
00:01 +50 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation a past clock time rolls over to tomorrow
00:01 +51 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing recognises a spoken briefing request
00:01 +52 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing message summary without a schedule is not a job
00:01 +53 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input falls back to unknown
00:01 +54 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input empty input is unknown
00:01 +55 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (setUpAll)
00:01 +55 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: starts in the idle state
00:01 +56 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: listening captures partial transcripts
00:01 +57 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: processing a final transcript produces and speaks a reply
00:02 +58 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +59 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +60 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +61 -5: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: rejects intervals under the WorkManager minimum
00:02 +62 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +63 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +64 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +65 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +66 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +67 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +68 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +69 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +70 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: recognition errors surface a Persian message and return to idle
00:02 +71 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:02 +72 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: missing Persian TTS voice is reported, text answer still works
00:02 +73 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: typed input is recorded in the activity log
00:02 +74 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: stopAll returns to idle and stops audio
00:02 +75 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: mute prevents speech output
00:02 +76 -5: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (tearDownAll)
00:02 +76 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts the start of Nowruz 1403
00:02 +77 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts a day in Aban 1405
00:02 +78 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian handles the last day of Esfand in a leap year
00:02 +79 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali round-trips 500 consecutive days
00:02 +80 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali Nowruz 1404 is 2025-03-21
00:02 +81 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths first six months have 31 days
00:02 +82 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths months seven to eleven have 30 days
00:02 +83 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths Esfand has 29 days in a common year and 30 in a leap year
00:03 +84 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (setUpAll)
00:03 +84 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: writes and reads a string
00:03 +85 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: overwriting replaces the previous value
00:03 +86 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: booleans round-trip with a fallback for missing keys
00:03 +87 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key
00:03 +88 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:03 +89 -5: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (tearDownAll)
00:03 +89 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: shortDate formats a Jalali date with Persian digits
00:03 +90 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: longDate uses Persian month names
00:03 +91 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: weekdayDate knows Persian weekday names
00:03 +92 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: clock pads hours and minutes
00:03 +93 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: relative describes recent times
00:03 +94 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: scheduleLabel distinguishes today and tomorrow
00:03 +95 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: greeting follows the hour of day
00:03 +96 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: addDays keeps the wall-clock time across month boundaries
00:03 +97 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles units and teens
00:04 +98 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles tens and compounds
00:04 +99 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles hundreds and thousands
00:04 +100 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.fromWord parses digits and words
00:04 +101 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses a plain hour
00:04 +102 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses «و نیم» and «و ربع»
00:04 +103 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock applies Persian meridiems
00:04 +104 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock rejects nonsense instead of guessing
00:04 +105 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun one-off returns its anchor only when in the future
00:04 +106 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily fires today when the time is still ahead
00:04 +107 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily rolls to tomorrow when the time has passed
00:04 +108 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly finds the next matching weekday
00:04 +109 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly returns today when it is the right day and still ahead
00:04 +110 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval advances from the anchor in fixed steps
00:04 +111 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval returns the anchor when it is still in the future
00:04 +112 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun invalid schedules return null instead of throwing
00:04 +113 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip daily schedule survives serialisation
00:04 +114 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip one-off anchor survives serialisation
00:04 +115 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip malformed JSON yields an invalid schedule rather than crashing
00:04 +116 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels daily label uses 24h times
00:04 +117 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels weekly label names the weekday
00:04 +118 -5: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels interval label prefers hours for whole hours
00:04 +119 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_weekday_test.dart: Persian weekday names line up with DateTime.weekday
00:04 +120 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_weekday_test.dart: month names are in calendar order
00:04 +121 -5: /home/runner/work/Ideal/Ideal/test/unit/jalali_weekday_test.dart: JalaliDate equality and comparison
00:04 +122 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits converts ASCII digits
00:04 +123 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits keeps letters and punctuation
00:04 +124 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits accepts non-string input
00:04 +125 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Persian digits
00:04 +126 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Arabic-Indic digits
00:04 +127 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput unifies Arabic yeh and kaf
00:04 +128 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput removes diacritics and tatweel
00:04 +129 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput converts digits and collapses whitespace
00:04 +130 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput replaces zero-width non-joiners with spaces
00:05 +131 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (setUpAll)
00:05 +131 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent note creation asks for confirmation and only saves on execute
00:05 +132 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent lists notes as a bullet list
00:05 +133 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent reading the latest note returns its body
00:05 +134 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent empty note commands ask for text instead of creating junk
00:05 +135 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:05 +136 -5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:05 +137 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +138 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +139 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +140 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +141 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +142 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +143 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +144 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +145 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +146 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:05 +146 -6: loading /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart
00:05 +146 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation [E]
  Expected: DateTime:<2026-11-16 20:00:00.000>
    Actual: DateTime:<2026-11-17 08:00:00.000>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 104:7                main.<fn>.<fn>
  
00:05 +146 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow
00:05 +147 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent lists active jobs
00:05 +148 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation
00:05 +149 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent briefing uses injected notifications and never invents data
00:05 +150 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent greeting mentions the time of day
00:05 +151 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent help lists real capabilities
00:05 +152 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:05 +153 -6: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (tearDownAll)
00:05 +153 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing says so honestly when nothing happened
00:05 +154 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing counts messages per source with Persian digits
00:05 +155 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing highlights the next job and urgent items
00:05 +156 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing ignores notifications from previous days
00:05 +157 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing never invents content when asked for details
00:05 +158 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: urge detector matches Persian and English keywords
00:05 +159 -6: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: summarize builds a compact one-liner
00:05 +160 -6: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
  /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours
  /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum
  /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command
  ... and 2 more
Running Gradle task 'assembleDebug'...                          
Loading package information...                                                  
Loading local repository...                                                     
[                                       ] 3% Loading local repository...        
[                                       ] 3% Fetch remote repository...         
[=                                      ] 3% Fetch remote repository...         
[=                                      ] 4% Fetch remote repository...         
[=                                      ] 5% Fetch remote repository...         
[==                                     ] 5% Fetch remote repository...         
[==                                     ] 6% Fetch remote repository...         
[==                                     ] 7% Fetch remote repository...         
[==                                     ] 7% Computing updates...               
[===                                    ] 8% Computing updates...               
[===                                    ] 10% Computing updates...              
[===                                    ] 10% Installing NDK (Side by side) 28.2
[===                                    ] 10% Downloading android-ndk-r28c-linux
[====                                   ] 10% Downloading android-ndk-r28c-linux
[====                                   ] 11% Downloading android-ndk-r28c-linux
[====                                   ] 12% Downloading android-ndk-r28c-linux
[=====                                  ] 13% Downloading android-ndk-r28c-linux
[=====                                  ] 14% Downloading android-ndk-r28c-linux
[=====                                  ] 15% Downloading android-ndk-r28c-linux
[======                                 ] 15% Downloading android-ndk-r28c-linux
[======                                 ] 16% Downloading android-ndk-r28c-linux
[======                                 ] 17% Downloading android-ndk-r28c-linux
[=======                                ] 18% Downloading android-ndk-r28c-linux
[=======                                ] 19% Downloading android-ndk-r28c-linux
[=======                                ] 20% Downloading android-ndk-r28c-linux
[========                               ] 20% Downloading android-ndk-r28c-linux
[========                               ] 21% Downloading android-ndk-r28c-linux
[========                               ] 22% Downloading android-ndk-r28c-linux
[=========                              ] 23% Downloading android-ndk-r28c-linux
[=========                              ] 24% Downloading android-ndk-r28c-linux
[=========                              ] 25% Downloading android-ndk-r28c-linux
[==========                             ] 25% Downloading android-ndk-r28c-linux
[==========                             ] 26% Downloading android-ndk-r28c-linux
[==========                             ] 27% Downloading android-ndk-r28c-linux
[===========                            ] 28% Downloading android-ndk-r28c-linux
[===========                            ] 29% Downloading android-ndk-r28c-linux
[===========                            ] 30% Downloading android-ndk-r28c-linux
[============                           ] 30% Downloading android-ndk-r28c-linux
[============                           ] 31% Downloading android-ndk-r28c-linux
[============                           ] 32% Downloading android-ndk-r28c-linux
[============                           ] 33% Downloading android-ndk-r28c-linux
[============                           ] 33% Unzipping...                      
[============                           ] 33% Unzipping... android-ndk-r28c/    
[============                           ] 33% Unzipping... android-ndk-r28c/READ
[=============                          ] 33% Unzipping... android-ndk-r28c/READ
[=============                          ] 33% Unzipping... android-ndk-r28c/meta
[=============                          ] 33% Unzipping... android-ndk-r28c/shad
[=============                          ] 33% Unzipping... android-ndk-r28c/ndk-
[=============                          ] 33% Unzipping... android-ndk-r28c/wrap
[=============                          ] 33% Unzipping... android-ndk-r28c/ndk-
[=============                          ] 33% Unzipping... android-ndk-r28c/tool
[=============                          ] 34% Unzipping... android-ndk-r28c/tool
[=============                          ] 35% Unzipping... android-ndk-r28c/tool
[==============                         ] 35% Unzipping... android-ndk-r28c/tool
[==============                         ] 36% Unzipping... android-ndk-r28c/tool
[==============                         ] 37% Unzipping... android-ndk-r28c/tool
[===============                        ] 38% Unzipping... android-ndk-r28c/tool
[===============                        ] 39% Unzipping... android-ndk-r28c/tool
[===============                        ] 40% Unzipping... android-ndk-r28c/tool
[================                       ] 40% Unzipping... android-ndk-r28c/tool
[================                       ] 41% Unzipping... android-ndk-r28c/tool
[================                       ] 42% Unzipping... android-ndk-r28c/tool
[=================                      ] 43% Unzipping... android-ndk-r28c/tool
[=================                      ] 44% Unzipping... android-ndk-r28c/tool
[=================                      ] 45% Unzipping... android-ndk-r28c/tool
[==================                     ] 45% Unzipping... android-ndk-r28c/tool
[==================                     ] 46% Unzipping... android-ndk-r28c/tool
[==================                     ] 47% Unzipping... android-ndk-r28c/tool
[===================                    ] 48% Unzipping... android-ndk-r28c/tool
[===================                    ] 49% Unzipping... android-ndk-r28c/tool
[===================                    ] 50% Unzipping... android-ndk-r28c/tool
[====================                   ] 50% Unzipping... android-ndk-r28c/tool
[====================                   ] 51% Unzipping... android-ndk-r28c/tool
[====================                   ] 52% Unzipping... android-ndk-r28c/tool
[=====================                  ] 53% Unzipping... android-ndk-r28c/tool
[=====================                  ] 54% Unzipping... android-ndk-r28c/tool
[=====================                  ] 54% Unzipping... android-ndk-r28c/buil
[=====================                  ] 54% Unzipping... android-ndk-r28c/sour
[=====================                  ] 54% Unzipping... android-ndk-r28c/NOTI
[=====================                  ] 54% Unzipping... android-ndk-r28c/ndk-
[=====================                  ] 54% Unzipping... android-ndk-r28c/NOTI
[=====================                  ] 54% Unzipping... android-ndk-r28c/pyth
[=====================                  ] 54% Unzipping... android-ndk-r28c/preb
[=====================                  ] 54% Unzipping... android-ndk-r28c/ndk-
[=====================                  ] 54% Unzipping... android-ndk-r28c/sour
[=====================                  ] 54% Unzipping... android-ndk-r28c/simp
[=====================                  ] 55% Unzipping... android-ndk-r28c/simp
[=====================                  ] 55% Unzipping... android-ndk-r28c/CHAN
[=======================================] 100% Unzipping... android-ndk-r28c/CHA

WARNING: Your Android app project: app located at: /home/runner/work/Ideal/Ideal/android/app/build.gradle.kts
applies the Kotlin Gradle Plugin, which will cause build failures in future versions of Flutter.
Please migrate your app to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_tts
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.

Please check the changelogs of these plugins and upgrade to a version that supports Built-in Kotlin.
If no such version exists, report the issue to the plugin. If necessary, here is a guide on filing
an issue against a plugin: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors

If you are a plugin author, please migrate your plugin to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
Checking the license for package CMake 3.22.1 in /usr/local/lib/android/sdk/licenses
License for package CMake 3.22.1 accepted.
Preparing "Install CMake 3.22.1 v.3.22.1".
"Install CMake 3.22.1 v.3.22.1" ready.
Installing CMake 3.22.1 in /usr/local/lib/android/sdk/cmake/3.22.1
"Install CMake 3.22.1 v.3.22.1" complete.
"Install CMake 3.22.1 v.3.22.1" finished.
Running Gradle task 'assembleDebug'...                            275.0s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```
