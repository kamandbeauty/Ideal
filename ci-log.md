# CI log (run 43963999751)

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

warning • Unused import: '../features/dashboard/dashboard_screen.dart'. Try removing the import directive • lib/app/router.dart:7:8 • unused_import
warning • Unused import: 'data/models/app_notification.dart'. Try removing the import directive • lib/bootstrap.dart:10:8 • unused_import
  error • Undefined name 'assistantRepositoryProvider'. Try correcting the name to one that is defined, or defining the name • lib/core/providers/voice_providers.dart:21:40 • undefined_identifier
warning • Dead code. Try removing the code, or fixing the code before it so that it can be reached • lib/data/models/job.dart:82:20 • dead_code
   info • Unnecessary 'this.' qualifier. Try removing 'this.' • lib/data/models/job.dart:82:23 • unnecessary_this
warning • The left operand can't be null, so the right operand is never executed. Try removing the operator and the right operand • lib/data/models/job.dart:82:23 • dead_null_aware_expression
   info • Use the null-aware operator '?.' rather than an explicit 'null' comparison. Try using '?.' • lib/data/models/job_run.dart:26:7 • prefer_null_aware_operators
warning • Unused import: 'package:sqflite/sqflite.dart'. Try removing the import directive • lib/data/repositories/job_repository.dart:1:8 • unused_import
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/agent/agent_core.dart:92:16 • prefer_const_constructors
warning • Unused import: '../../core/providers/service_providers.dart'. Try removing the import directive • lib/features/assistant/assistant_controller.dart:6:8 • unused_import
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:239:9 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:240:18 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/assistant/assistant_screen.dart:242:20 • prefer_const_constructors
warning • Unused import: '../../core/providers/repository_providers.dart'. Try removing the import directive • lib/features/notes/notes_screen.dart:4:8 • unused_import
  error • The method 'SurfaceCard' isn't defined for the type '_NoteTile'. Try correcting the name to the name of an existing method, or defining a method named 'SurfaceCard' • lib/features/notes/notes_screen.dart:254:12 • undefined_method
  error • Undefined name 'settingsRepositoryProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/settings/ai_settings_screen.dart:36:31 • undefined_identifier
  error • Undefined name 'settingsRepositoryProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/settings/ai_settings_screen.dart:53:50 • undefined_identifier
warning • Unused import: '../../services/native_bridge.dart'. Try removing the import directive • lib/features/settings/privacy_screen.dart:11:8 • unused_import
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:117:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:122:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:127:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:132:11 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • lib/features/settings/privacy_screen.dart:137:11 • prefer_const_constructors
warning • Unused import: '../../services/native_bridge.dart'. Try removing the import directive • lib/features/settings/settings_screen.dart:10:8 • unused_import
warning • The getter doesn't override an inherited getter. Try updating this class to match the superclass, or removing the override annotation • lib/l10n/persian_material_localizations.dart:20:14 • override_on_non_overriding_member
warning • The getter doesn't override an inherited getter. Try updating this class to match the superclass, or removing the override annotation • lib/l10n/persian_material_localizations.dart:59:14 • override_on_non_overriding_member
warning • The getter doesn't override an inherited getter. Try updating this class to match the superclass, or removing the override annotation • lib/l10n/persian_material_localizations.dart:68:14 • override_on_non_overriding_member
warning • The declaration '_openDatabase' isn't referenced. Try removing the declaration of '_openDatabase' • test/helpers/test_database.dart:13:20 • unused_element
warning • The method doesn't override an inherited method. Try updating this class to match the superclass, or removing the override annotation • test/helpers/test_database.dart:13:20 • override_on_non_overriding_member
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
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:124:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:136:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:141:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:150:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:155:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/models_test.dart:50:17 • prefer_const_constructors

45 issues found. (ran in 7.7s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (setUpAll)
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +1: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: converts a valid native entry
00:00 +2: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:00 +3: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:00 +4: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:00 +5: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:00 +6: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: falls back to capture time for invalid timestamps
00:00 +7: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +8: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +9: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +10: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +11: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:00 +12: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: filters by category
00:00 +13: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: falls back to general for unknown categories
00:00 +14: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: updates content and bumps updatedAt
00:00 +15: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: pins notes to the top of the list
00:00 +16: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: deletes a note
00:00 +17: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: latest returns the most recently updated note
00:00 +18: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data survives closing and reopening the database file
00:00 +19: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (tearDownAll)
00:00 +19: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (setUpAll)
00:00 +19: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: stores and lists notifications newest first
00:01 +20: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key
00:01 +21: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced
00:01 +22: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows
00:01 +23: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows
00:01 +24: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time
00:01 +25: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything
00:01 +26: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: source labels map packages to Persian names
00:01 +27: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: package classification matches the Kotlin implementation
00:01 +28: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (tearDownAll)
00:01 +28: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note round-trips through a map
00:01 +29: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note displayTitle falls back to the body
00:01 +30: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note preview flattens newlines
00:01 +31: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note category labels are Persian
00:01 +32: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job round-trips through a map
00:01 +33: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job isRecurring and isActive reflect the schedule
00:01 +34: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job copyWith can clear nullable fields
00:01 +35: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: JobRun round-trips and computes duration
00:01 +36: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: AssistantMessage round-trips meta
00:01 +37: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a greeting
00:01 +38: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a help request
00:01 +39: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command
00:01 +39 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command [E]
  Expected: 'جلسهٔ فردا ساعت ده'
    Actual: ': جلسه فردا ساعت ده'
     Which: is different.
            Expected: جلسهٔ فردا ...
              Actual: : جلسه فرد ...
                      ^
             Differ at offset 0
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 28:7              main.<fn>.<fn>
  
00:01 +39 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from «یادداشت جدید بساز»
00:01 +40 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes extracts quoted note bodies
00:01 +41 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes infers the work category
00:01 +42 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes asks for the body when the command has none
00:01 +43 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes lists notes
00:01 +44 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes deletes the latest note with confirmation
00:01 +45 -1: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour
00:01 +45 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour [E]
  Expected: IntentType:<IntentType.createJob>
    Actual: IntentType:<IntentType.dailyBriefing>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 67:7              main.<fn>.<fn>
  
00:01 +45 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action
00:01 +45 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action [E]
  Expected: IntentType:<IntentType.createJob>
    Actual: IntentType:<IntentType.dailyBriefing>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 77:7              main.<fn>.<fn>
  
00:01 +45 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation one-off reminder for tomorrow at 09:00
00:01 +46 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «نه و نیم» clock expressions
00:01 +47 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours
00:01 +47 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours [E]
  Expected: <10>
    Actual: <null>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 100:7             main.<fn>.<fn>
  
00:01 +47 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00
00:01 +47 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00 [E]
  Expected: <20>
    Actual: <8>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 108:7             main.<fn>.<fn>
  
00:01 +47 -5: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum
00:01 +47 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum [E]
  Null check operator used on a null value
  test/unit/intent_parser_test.dart 113:64  main.<fn>.<fn>
  
00:01 +47 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation weekly schedule on Saturday
00:01 +48 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation a past clock time rolls over to tomorrow
00:01 +49 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing recognises a spoken briefing request
00:01 +50 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing message summary without a schedule is not a job
00:01 +51 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input falls back to unknown
00:01 +52 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input empty input is unknown
00:02 +53 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (setUpAll)
00:02 +53 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: starts in the idle state
00:02 +54 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: listening captures partial transcripts
00:02 +55 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: processing a final transcript produces and speaks a reply
00:02 +56 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +57 -6: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +57 -7: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: rejects one-off jobs in the past
00:02 +58 -7: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: rejects intervals under the WorkManager minimum
00:02 +58 -7: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval [E]
  Expected: <1>
    Actual: <0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/assistant_controller_test.dart 169:5      main.<fn>
  
00:02 +59 -7: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +59 -7: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: disabling clears the next run and enabling recomputes it
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 4, readOnly: false, singleInstance: true}}} during open, closing...
00:02 +59 -8: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +59 -8: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: disabling clears the next run and enabling recomputes it [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 4, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:02 +60 -8: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +61 -8: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +61 -9: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +61 -9: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: due jobs only include active jobs whose time has come [E]
  زمان اجرای این وظیفه در گذشته است.
  package:javid_ai/services/job_service.dart 54:7  JobService.create
  test/unit/job_service_test.dart 106:31           main.<fn>
  
00:02 +62 -9: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: deleting a job also deletes its run history
00:02 +62 -9: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: recognition errors surface a Persian message and return to idle
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 6, readOnly: false, singleInstance: true}}} during open, closing...
00:02 +62 -10: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: deleting a job also deletes its run history
00:02 +62 -10: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: recognition errors surface a Persian message and return to idle [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 6, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:02 +63 -10: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:02 +63 -10: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: nextScheduled returns the soonest active job
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 9, readOnly: false, singleInstance: true}}} during open, closing...
00:02 +63 -11: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:02 +63 -11: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: nextScheduled returns the soonest active job [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 9, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:02 +63 -11: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: list ordering is stable and deterministic
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 10, readOnly: false, singleInstance: true}}} during open, closing...
00:02 +63 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:02 +63 -12: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: list ordering is stable and deterministic [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 10, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:02 +63 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:02 +64 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: missing Persian TTS voice is reported, text answer still works
00:03 +65 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: typed input is recorded in the activity log
00:03 +66 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: stopAll returns to idle and stops audio
00:03 +67 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: mute prevents speech output
00:03 +68 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (tearDownAll)
00:03 +68 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts the start of Nowruz 1403
00:03 +69 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts a day in Aban 1405
00:03 +70 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian handles the last day of Esfand in a leap year
00:03 +71 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali round-trips 500 consecutive days
00:03 +72 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali Nowruz 1404 is 2025-03-21
00:03 +73 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths first six months have 31 days
00:03 +74 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths months seven to eleven have 30 days
00:03 +75 -12: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths Esfand has 29 days in a common year and 30 in a leap year
00:03 +76 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (setUpAll)
00:03 +76 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: writes and reads a string
00:04 +77 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: overwriting replaces the previous value
00:04 +78 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: booleans round-trip with a fallback for missing keys
00:04 +79 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key
00:04 +80 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +81 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +82 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +83 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +84 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +85 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +86 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: scheduleLabel distinguishes today and tomorrow
00:04 +87 -12: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (tearDownAll)
00:04 +87 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: greeting follows the hour of day
00:04 +88 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: addDays keeps the wall-clock time across month boundaries
00:04 +89 -12: loading /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart
00:04 +89 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles units and teens
00:04 +90 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles tens and compounds
00:04 +91 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles hundreds and thousands
00:04 +92 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.fromWord parses digits and words
00:04 +93 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses a plain hour
00:04 +94 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses «و نیم» and «و ربع»
00:04 +95 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock applies Persian meridiems
00:04 +96 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock rejects nonsense instead of guessing
00:05 +97 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun one-off returns its anchor only when in the future
00:05 +98 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily fires today when the time is still ahead
00:05 +99 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily rolls to tomorrow when the time has passed
00:05 +100 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly finds the next matching weekday
00:05 +101 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly returns today when it is the right day and still ahead
00:05 +102 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval advances from the anchor in fixed steps
00:05 +103 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval returns the anchor when it is still in the future
00:05 +104 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun invalid schedules return null instead of throwing
00:05 +105 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip daily schedule survives serialisation
00:05 +106 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip one-off anchor survives serialisation
00:05 +107 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip malformed JSON yields an invalid schedule rather than crashing
00:05 +108 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels daily label uses 24h times
00:05 +109 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels weekly label names the weekday
00:05 +110 -12: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels interval label prefers hours for whole hours
00:05 +111 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits converts ASCII digits
00:05 +112 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits keeps letters and punctuation
00:05 +113 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits accepts non-string input
00:05 +114 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Persian digits
00:05 +115 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Arabic-Indic digits
00:05 +116 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput unifies Arabic yeh and kaf
00:05 +117 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput removes diacritics and tatweel
00:05 +118 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput converts digits and collapses whitespace
00:05 +119 -12: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput replaces zero-width non-joiners with spaces
00:05 +120 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (setUpAll)
00:05 +120 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent note creation asks for confirmation and only saves on execute
00:05 +121 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent lists notes as a bullet list
00:05 +122 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent reading the latest note returns its body
00:05 +123 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent empty note commands ask for text instead of creating junk
00:05 +124 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent deleting a note needs confirmation and reports no data without it
00:05 +125 -12: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:06 +125 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 96:7                 main.<fn>.<fn>
  
00:06 +125 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow
00:06 +126 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent lists active jobs
00:06 +127 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation
00:06 +128 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent briefing uses injected notifications and never invents data
00:06 +129 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent greeting mentions the time of day
00:06 +130 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:06 +131 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:06 +132 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:06 +133 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:06 +134 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:06 +135 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:06 +136 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: a past Jalali day/month rolls to next year
00:06 +137 -13: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (tearDownAll)
00:06 +137 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: Persian ordinals are understood
00:06 +138 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: weekday names find the next occurrence
00:06 +139 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «سه روز دیگر» offsets by days
00:06 +140 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: explicit dotted Jalali dates are accepted
00:06 +141 -13: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: returns null when no date expression exists
00:06 +142 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing says so honestly when nothing happened
00:06 +143 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing counts messages per source with Persian digits
00:06 +144 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing highlights the next job and urgent items
00:06 +145 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing ignores notifications from previous days
00:06 +146 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing never invents content when asked for details
00:06 +147 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: urge detector matches Persian and English keywords
00:06 +148 -13: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: summarize builds a compact one-liner
00:06 +149 -13: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
  /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
  /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: recognition errors surface a Persian message and return to idle
  /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action
  ... and 9 more
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
lib/core/providers/voice_providers.dart:21:40: Error: Undefined name 'assistantRepositoryProvider'.
  (ref) => AssistantActivity(ref.watch(assistantRepositoryProvider)),
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/notes/notes_screen.dart:254:12: Error: The method 'SurfaceCard' isn't defined for the type '_NoteTile'.
 - '_NoteTile' is from 'package:javid_ai/features/notes/notes_screen.dart' ('lib/features/notes/notes_screen.dart').
Try correcting the name to the name of an existing method, or defining a method named 'SurfaceCard'.
    return SurfaceCard(
           ^^^^^^^^^^^
lib/features/settings/ai_settings_screen.dart:36:31: Error: The getter 'settingsRepositoryProvider' isn't defined for the type '_AiSettingsScreenState'.
 - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'settingsRepositoryProvider'.
    final settings = ref.read(settingsRepositoryProvider);
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/settings/ai_settings_screen.dart:53:50: Error: The getter 'settingsRepositoryProvider' isn't defined for the type '_AiSettingsScreenState'.
 - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'settingsRepositoryProvider'.
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
                                                 ^^^^^^^^^^^^^^^^^^^^^^^^^^
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildDebug'.
> Process 'command '/opt/hostedtoolcache/flutter/stable-3.47.9-x64/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights from a Build Scan (powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 2m 47s
Running Gradle task 'assembleDebug'...                            169.5s
Gradle task assembleDebug failed with exit code 1
```
