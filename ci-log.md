# CI log (run 43962797613)

```
ned_class
  error • Undefined class 'AlwaysUse24HourFormat'. Try changing the name to the name of an existing class, or creating a class with the name 'AlwaysUse24HourFormat' • lib/l10n/persian_material_localizations.dart:121:48 • undefined_class
  error • 'PersianMaterialLocalizations.narrowWeekdays' ('String Function()') isn't a valid override of 'DefaultMaterialLocalizations.narrowWeekdays' ('List<String> Function()') • lib/l10n/persian_material_localizations.dart:134:14 • invalid_override
   info • 'localeId' is deprecated and shouldn't be used. Use SpeechListenOptions.localeId instead. Try replacing the use of the deprecated member with the replacement • lib/services/voice/native_speech_recognizer.dart:61:9 • deprecated_member_use
warning • The declaration '_openDatabase' isn't referenced. Try removing the declaration of '_openDatabase' • test/helpers/test_database.dart:13:20 • unused_element
warning • The method doesn't override an inherited method. Try updating this class to match the superclass, or removing the override annotation • test/helpers/test_database.dart:13:20 • override_on_non_overriding_member
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:14:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:26:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:39:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:52:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:97:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:123:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_schedule_test.dart:128:24 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:32:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:66:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:83:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:128:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:140:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:145:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:154:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/job_service_test.dart:159:17 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance. Try adding the 'const' keyword to the constructor invocation • test/unit/models_test.dart:50:17 • prefer_const_constructors

49 issues found. (ran in 8.4s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (setUpAll)
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:00 +1: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: converts a valid native entry
00:00 +2: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: converts a valid native entry
00:00 +3: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +4: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +5: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:00 +6: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: drops empty and malformed rows
00:00 +7: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:00 +8: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:00 +9: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:00 +10: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
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
00:01 +20 -1: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key [E]
  Expected: an object with length of <1>
    Actual: [
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification'
            ]
     Which: has length of <3>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 58:5    main.<fn>
  
00:01 +20 -1: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced
00:01 +20 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced [E]
  Expected: empty
    Actual: [
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification'
            ]
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 63:5    main.<fn>
  
00:01 +20 -2: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows
00:01 +20 -3: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows [E]
  Expected: <1>
    Actual: <4>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 70:5    main.<fn>
  
00:01 +20 -3: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows
00:01 +20 -4: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows [E]
  Expected: <1>
    Actual: <3>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 77:5    main.<fn>
  
00:01 +20 -4: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time
00:01 +20 -5: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time [E]
  Expected: ['new']
    Actual: MappedListIterable<CapturedNotification, String>:[
              'b',
              'n1',
              '1',
              '2',
              'new',
              'a'
            ]
     Which: at location [0] is 'b' instead of 'new'
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 90:5    main.<fn>
  
00:01 +20 -5: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything
00:01 +20 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything [E]
  Expected: <1>
    Actual: <0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 98:5    main.<fn>
  
00:01 +20 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: source labels map packages to Persian names
00:01 +21 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: package classification matches the Kotlin implementation
00:01 +22 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (tearDownAll)
00:01 +22 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note round-trips through a map
00:01 +23 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note displayTitle falls back to the body
00:01 +24 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note preview flattens newlines
00:01 +25 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note category labels are Persian
00:01 +26 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job round-trips through a map
00:01 +27 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job isRecurring and isActive reflect the schedule
00:01 +28 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job copyWith can clear nullable fields
00:01 +29 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: JobRun round-trips and computes duration
00:01 +30 -6: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: AssistantMessage round-trips meta
00:01 +31 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a greeting
00:01 +32 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a help request
00:01 +33 -6: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command
00:01 +33 -7: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command [E]
  Expected: IntentType:<IntentType.createNote>
    Actual: IntentType:<IntentType.createJob>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 27:7              main.<fn>.<fn>
  
00:01 +33 -7: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from «یادداشت جدید بساز»
00:01 +34 -7: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes extracts quoted note bodies
00:01 +34 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes extracts quoted note bodies [E]
  Expected: 'شمارهٔ دفتر: 02112345'
    Actual: 'شماره دفتر: 02112345'
     Which: is different.
            Expected: شمارهٔ دفتر: 02 ...
              Actual: شماره دفتر: 021 ...
                           ^
             Differ at offset 5
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 40:7              main.<fn>.<fn>
  
00:01 +34 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes infers the work category
00:01 +35 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes asks for the body when the command has none
00:01 +36 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes lists notes
00:01 +37 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes deletes the latest note with confirmation
00:01 +38 -8: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour
00:01 +38 -9: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour [E]
  Expected: IntentType:<IntentType.createJob>
    Actual: IntentType:<IntentType.dailyBriefing>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 66:7              main.<fn>.<fn>
  
00:01 +38 -9: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action
00:02 +38 -10: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action [E]
  Expected: IntentType:<IntentType.createJob>
    Actual: IntentType:<IntentType.dailyBriefing>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 76:7              main.<fn>.<fn>
  
00:02 +38 -10: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation one-off reminder for tomorrow at 09:00
00:02 +39 -10: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «نه و نیم» clock expressions
00:02 +40 -10: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours
00:02 +40 -11: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours [E]
  Expected: <10>
    Actual: <null>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 99:7              main.<fn>.<fn>
  
00:02 +40 -11: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00
00:02 +40 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00 [E]
  Expected: <20>
    Actual: <8>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 107:7             main.<fn>.<fn>
  
00:02 +40 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum
00:02 +41 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation weekly schedule on Saturday
00:02 +42 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation a past clock time rolls over to tomorrow
00:02 +43 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing recognises a spoken briefing request
00:02 +44 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing message summary without a schedule is not a job
00:02 +45 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input falls back to unknown
00:02 +46 -12: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input empty input is unknown
00:02 +47 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (setUpAll)
00:02 +47 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: starts in the idle state
00:02 +48 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: listening captures partial transcripts
00:02 +49 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: processing a final transcript produces and speaks a reply
00:02 +50 -12: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:02 +50 -13: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval [E]
  Expected: <0>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/assistant_controller_test.dart 166:5      main.<fn>
  
00:02 +50 -13: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:02 +50 -14: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: creates a recurring job with the next run
00:02 +50 -14: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched [E]
  Expected: <0>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/assistant_controller_test.dart 181:5      main.<fn>
  
00:02 +51 -14: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: creates a recurring job with the next run
00:03 +52 -14: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:03 +53 -14: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:03 +54 -14: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:03 +55 -14: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: disabling clears the next run and enabling recomputes it
00:03 +55 -14: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: missing Persian TTS voice is reported, text answer still works
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 8, readOnly: false, singleInstance: true}}} during open, closing...
00:03 +55 -15: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: disabling clears the next run and enabling recomputes it
00:03 +56 -15: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: records a successful run, advances the schedule and stores history
00:03 +56 -15: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: missing Persian TTS voice is reported, text answer still works [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 8, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:03 +56 -15: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: typed input is recorded in the activity log
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 9, readOnly: false, singleInstance: true}}} during open, closing...
00:03 +56 -16: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: records a successful run, advances the schedule and stores history
00:03 +56 -16: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: typed input is recorded in the activity log [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 9, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:03 +56 -16: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: stopAll returns to idle and stops audio
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 10, readOnly: false, singleInstance: true}}} during open, closing...
00:03 +56 -17: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: records a successful run, advances the schedule and stores history
00:03 +56 -17: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: stopAll returns to idle and stops audio [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 10, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:03 +56 -17: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: mute prevents speech output
error DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
  Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 11, readOnly: false, singleInstance: true}}} during open, closing...
00:03 +56 -18: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: records a successful run, advances the schedule and stores history
00:03 +57 -18: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: a failed one-off job keeps its time so it can be retried
00:03 +57 -18: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: mute prevents speech output [E]
  DatabaseException(ffi sqlite_error 5: SqliteException(5): while selecting from statement, database is locked, database is locked (code 5)
    Causing statement: PRAGMA user_version) sql 'PRAGMA user_version' {details: {database: {path: /home/runner/work/Ideal/Ideal/.dart_tool/sqflite_common_ffi/databases/:memory:, id: 11, readOnly: false, singleInstance: true}}}
  package:sqflite_common_ffi/src/method_call.dart 126:9  responseToResultOrThrow
  package:sqflite_common_ffi/src/isolate_io.dart 85:12   SqfliteIsolate.handle
  
00:03 +57 -18: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: a failed one-off job keeps its time so it can be retried
00:03 +58 -18: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: due jobs only include active jobs whose time has come
00:03 +58 -19: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: due jobs only include active jobs whose time has come [E]
  زمان اجرای این وظیفه در گذشته است.
  package:javid_ai/services/job_service.dart 54:7  JobService.create
  test/unit/job_service_test.dart 110:31           main.<fn>
  
00:03 +58 -19: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: deleting a job also deletes its run history
00:03 +59 -19: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: nextScheduled returns the soonest active job
00:03 +60 -19: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: list ordering is stable and deterministic
00:03 +61 -19: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: (tearDownAll)
00:03 +61 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts the start of Nowruz 1403
00:03 +62 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts a day in Aban 1405
00:03 +63 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian handles the last day of Esfand in a leap year
00:03 +64 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali round-trips 500 consecutive days
00:03 +65 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali Nowruz 1404 is 2025-03-21
00:03 +66 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths first six months have 31 days
00:03 +67 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths months seven to eleven have 30 days
00:03 +68 -19: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths Esfand has 29 days in a common year and 30 in a leap year
00:03 +69 -19: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (setUpAll)
00:03 +69 -19: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: writes and reads a string
00:04 +70 -19: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: overwriting replaces the previous value
00:04 +71 -19: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: booleans round-trip with a fallback for missing keys
00:04 +72 -19: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key
00:04 +72 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key [E]
  Expected: {'a': '1', 'b': '2'}
    Actual: {
              'ai_model': 'llama-3',
              'theme_mode': 'light',
              'cloud_ai_enabled': 'false',
              'a': '1',
              'b': '2'
            }
     Which: has different length and has extra map key 'ai_model'
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/settings_repository_test.dart 42:5        main.<fn>
  
00:04 +72 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +73 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +74 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +75 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +76 -20: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +76 -21: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:04 +77 -21: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (tearDownAll)
00:04 +77 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: relative describes recent times [E]
  Expected: 'دیروز'
    Actual: '۱۶ ساعت پیش'
     Which: is different.
            Expected: دیروز
              Actual: ۱۶ ساعت پی ...
                      ^
             Differ at offset 0
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/persian_date_test.dart 32:5               main.<fn>
  
00:04 +77 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: scheduleLabel distinguishes today and tomorrow
00:04 +78 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: greeting follows the hour of day
00:04 +79 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: addDays keeps the wall-clock time across month boundaries
00:04 +80 -21: loading /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart
00:04 +80 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles units and teens
00:05 +81 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles tens and compounds
00:05 +82 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles hundreds and thousands
00:05 +83 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.fromWord parses digits and words
00:05 +84 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses a plain hour
00:05 +85 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses «و نیم» and «و ربع»
00:05 +86 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock applies Persian meridiems
00:05 +87 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock rejects nonsense instead of guessing
00:05 +88 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun one-off returns its anchor only when in the future
00:05 +89 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily fires today when the time is still ahead
00:05 +90 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily rolls to tomorrow when the time has passed
00:05 +91 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly finds the next matching weekday
00:05 +92 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly returns today when it is the right day and still ahead
00:05 +93 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval advances from the anchor in fixed steps
00:05 +94 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval returns the anchor when it is still in the future
00:05 +95 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun invalid schedules return null instead of throwing
00:05 +96 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip daily schedule survives serialisation
00:05 +97 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip one-off anchor survives serialisation
00:05 +98 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip malformed JSON yields an invalid schedule rather than crashing
00:05 +99 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels daily label uses 24h times
00:05 +100 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels weekly label names the weekday
00:05 +101 -21: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels interval label prefers hours for whole hours
00:05 +102 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits converts ASCII digits
00:05 +103 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits keeps letters and punctuation
00:05 +104 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits accepts non-string input
00:05 +105 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Persian digits
00:05 +106 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Arabic-Indic digits
00:05 +107 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput unifies Arabic yeh and kaf
00:05 +108 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput removes diacritics and tatweel
00:05 +109 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput converts digits and collapses whitespace
00:05 +110 -21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput replaces zero-width non-joiners with spaces
00:05 +111 -21: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (setUpAll)
00:05 +111 -21: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent note creation asks for confirmation and only saves on execute
00:05 +111 -22: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent note creation asks for confirmation and only saves on execute [E]
  Expected: <0>
    Actual: <1>
  must not write before confirmation
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 57:7                 main.<fn>.<fn>
  
00:05 +111 -22: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent lists notes as a bullet list
00:05 +111 -23: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent lists notes as a bullet list [E]
  Expected: contains '۲ یادداشت'
    Actual: '۳ یادداشت داری:\n'
              '• دومی\n'
              '• اولی\n'
              '• ماندگار'
     Which: does not contain '۲ یادداشت'
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 68:7                 main.<fn>.<fn>
  
00:05 +111 -23: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent reading the latest note returns its body
00:06 +112 -23: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent empty note commands ask for text instead of creating junk
00:06 +113 -23: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent deleting a note needs confirmation and reports no data without it
00:06 +113 -24: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent deleting a note needs confirmation and reports no data without it [E]
  Expected: <1>
    Actual: <5>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 88:7                 main.<fn>.<fn>
  
00:06 +113 -24: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:06 +113 -25: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 97:7                 main.<fn>.<fn>
  
00:06 +113 -25: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow
00:06 +113 -26: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow [E]
  Bad state: Too many elements
  dart:core                              _Array.single
  test/unit/agent_core_test.dart 111:43  main.<fn>.<fn>
  
00:06 +113 -26: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent lists active jobs
00:06 +114 -26: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation
00:06 +114 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation [E]
  Bad state: Too many elements
  dart:core                              _Array.single
  test/unit/agent_core_test.dart 130:24  main.<fn>.<fn>
  
00:06 +114 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent briefing uses injected notifications and never invents data
00:06 +115 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent greeting mentions the time of day
00:06 +116 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent help lists real capabilities
00:06 +117 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:06 +118 -27: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (tearDownAll)
00:06 +118 -27: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:06 +119 -27: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «فردا» resolves to the next day
00:06 +120 -27: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «پس‌فردا» resolves two days ahead
00:06 +120 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «پس‌فردا» resolves two days ahead [E]
  Expected: DateTime:<2026-11-18 00:00:00.000>
    Actual: DateTime:<2026-11-17 00:00:00.000>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/persian_date_parse_test.dart 18:5         main.<fn>
  
00:06 +120 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: day + month names resolve in the Jalali calendar
00:06 +121 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: a past Jalali day/month rolls to next year
00:06 +122 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: Persian ordinals are understood
00:06 +123 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: weekday names find the next occurrence
00:06 +124 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «سه روز دیگر» offsets by days
00:06 +125 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: explicit dotted Jalali dates are accepted
00:06 +126 -28: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: returns null when no date expression exists
00:06 +127 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing says so honestly when nothing happened
00:06 +128 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing counts messages per source with Persian digits
00:06 +129 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing highlights the next job and urgent items
00:06 +130 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing ignores notifications from previous days
00:06 +131 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing never invents content when asked for details
00:06 +132 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: urge detector matches Persian and English keywords
00:06 +133 -28: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: summarize builds a compact one-liner
00:06 +134 -28: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent deleting a note needs confirmation and reports no data without it
  ... and 24 more
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
lib/l10n/persian_material_localizations.dart:112:43: Error: Type 'AlwaysUse24HourFormat' not found.
  String formatHour(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = false}) {
                                          ^^^^^^^^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:121:48: Error: Type 'AlwaysUse24HourFormat' not found.
  String formatTimeOfDay(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = true}) {
                                               ^^^^^^^^^^^^^^^^^^^^^
lib/core/providers/voice_providers.dart:21:40: Error: Undefined name 'assistantRepositoryProvider'.
  (ref) => AssistantActivity(ref.watch(assistantRepositoryProvider)),
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:134:14: Error: The return type of the method 'PersianMaterialLocalizations.narrowWeekdays' is 'String', which does not match the return type, 'List<String>', of the overridden method, 'DefaultMaterialLocalizations.narrowWeekdays'.
 - 'List' is from 'dart:core'.
Change to a subtype of 'List<String>'.
  String get narrowWeekdays => 'ش،ی،د،س،چ،پ،ج';
             ^
/opt/hostedtoolcache/flutter/stable-3.47.9-x64/flutter/packages/flutter/lib/src/material/material_localizations.dart:938:20: Context: This is the overridden method ('narrowWeekdays').
  List<String> get narrowWeekdays => _narrowWeekdays;
                   ^
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
lib/l10n/persian_material_localizations.dart:112:43: Error: 'AlwaysUse24HourFormat' isn't a type.
  String formatHour(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = false}) {
                                          ^^^^^^^^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:121:48: Error: 'AlwaysUse24HourFormat' isn't a type.
  String formatTimeOfDay(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = true}) {
                                               ^^^^^^^^^^^^^^^^^^^^^
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

BUILD FAILED in 2m 53s
Running Gradle task 'assembleDebug'...                            174.2s
Gradle task assembleDebug failed with exit code 1
```
