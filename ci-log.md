# CI log (run 43961741608)

```
Ideal/Ideal/test/unit/note_service_test.dart: pins notes to the top of the list
00:00 +6 -2: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: deletes a note
00:00 +6 -3: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: deletes a note [E]
  Expected: <0>
    Actual: <11>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/note_service_test.dart 83:5               main.<fn>
  
00:00 +6 -3: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: latest returns the most recently updated note
00:00 +6 -4: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: latest returns the most recently updated note [E]
  Expected: '01a1e64a-9fe0-7351-a7be-f93afb76f1f9'
    Actual: '01a1e64a-9fba-73df-8069-5cd7c4ba8582'
     Which: is different.
            Expected: ... 1a1e64a-9fe0-7351-a7 ...
              Actual: ... 1a1e64a-9fba-73df-80 ...
                                    ^
             Differ at offset 11
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/note_service_test.dart 92:5               main.<fn>
  
00:00 +6 -4: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data survives closing and reopening the database file
00:00 +7 -4: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (tearDownAll)
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
00:00 +7 -4: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (setUpAll)
00:00 +7 -4: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: stores and lists notifications newest first
00:00 +8 -4: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key
00:00 +8 -5: loading /home/runner/work/Ideal/Ideal/test/unit/models_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/models_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/models_test.dart: lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  .
00:00 +8 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key [E]
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
  
00:00 +8 -6: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced
00:00 +8 -7: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced [E]
  Expected: empty
    Actual: [
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification',
              Instance of 'CapturedNotification'
            ]
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 63:5    main.<fn>
  
00:00 +8 -7: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows
00:00 +8 -8: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows [E]
  Expected: <1>
    Actual: <4>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 70:5    main.<fn>
  
00:00 +8 -8: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows
00:00 +8 -9: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows [E]
  Expected: <1>
    Actual: <3>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 77:5    main.<fn>
  
00:00 +8 -9: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time
00:00 +8 -10: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time [E]
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
  
00:00 +8 -10: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything
00:00 +8 -11: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything [E]
  Expected: <1>
    Actual: <0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/notification_repository_test.dart 98:5    main.<fn>
  
00:00 +8 -11: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: source labels map packages to Persian names
00:00 +9 -11: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: package classification matches the Kotlin implementation
00:00 +10 -11: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (tearDownAll)
lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
Try adding a backslash (\) to escape the '$'.
    if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                    ^
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
  JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                              ^^^^
00:01 +10 -12: loading /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
  Try adding a backslash (\) to escape the '$'.
      if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                      ^
  lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
    JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                                ^^^^
  .
lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
Try adding a backslash (\) to escape the '$'.
    if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                    ^
lib/features/agent/agent_core.dart:40:16: Error: Type 'ToolResult' not found.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
test/unit/assistant_controller_test.dart:117:34: Error: The argument type 'ProviderContainer' can't be assigned to the parameter type 'Ref<Object?>'.
 - 'ProviderContainer' is from 'package:riverpod/src/framework.dart' ('../../../.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/framework.dart').
 - 'Ref' is from 'package:riverpod/src/framework.dart' ('../../../.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/framework.dart').
 - 'Object' is from 'dart:core'.
    activity = AssistantActivity(container);
                                 ^
lib/features/agent/agent_core.dart:40:16: Error: 'ToolResult' isn't a type.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
lib/features/agent/agent_core.dart:180:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('یادداشت حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:262:30: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
                             ^^^^^^^^^^
lib/features/agent/agent_core.dart:276:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('وظیفه حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:131:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/agent/agent_core.dart:214:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/assistant/assistant_controller.dart:250:38: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
 - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
    final messages = await _ref.read(assistantRepositoryProvider).recent(limit: 20);
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/assistant/assistant_controller.dart:260:21: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
 - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
    await _ref.read(assistantRepositoryProvider).insert(
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
  JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                              ^^^^
00:02 +10 -13: loading /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
  Try adding a backslash (\) to escape the '$'.
      if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                      ^
  lib/features/agent/agent_core.dart:40:16: Error: Type 'ToolResult' not found.
    final Future<ToolResult<Object?>> Function() execute;
                 ^^^^^^^^^^
  test/unit/assistant_controller_test.dart:117:34: Error: The argument type 'ProviderContainer' can't be assigned to the parameter type 'Ref<Object?>'.
   - 'ProviderContainer' is from 'package:riverpod/src/framework.dart' ('../../../.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/framework.dart').
   - 'Ref' is from 'package:riverpod/src/framework.dart' ('../../../.pub-cache/hosted/pub.dev/riverpod-2.6.1/lib/src/framework.dart').
   - 'Object' is from 'dart:core'.
      activity = AssistantActivity(container);
                                   ^
  lib/features/agent/agent_core.dart:40:16: Error: 'ToolResult' isn't a type.
    final Future<ToolResult<Object?>> Function() execute;
                 ^^^^^^^^^^
  lib/features/agent/agent_core.dart:180:28: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('یادداشت حذف شد.');
                             ^^^^^^^^^^
  lib/features/agent/agent_core.dart:262:30: Error: Not a constant expression.
                  return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
                               ^^^^^^^^^^
  lib/features/agent/agent_core.dart:276:28: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('وظیفه حذف شد.');
                             ^^^^^^^^^^
  lib/features/agent/agent_core.dart:131:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
   - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
                return ToolResult<Object?>.ok(
                       ^^^^^^^^^^
  lib/features/agent/agent_core.dart:214:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
   - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
                return ToolResult<Object?>.ok(
                       ^^^^^^^^^^
  lib/features/assistant/assistant_controller.dart:250:38: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
   - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
      final messages = await _ref.read(assistantRepositoryProvider).recent(limit: 20);
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  lib/features/assistant/assistant_controller.dart:260:21: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
   - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
      await _ref.read(assistantRepositoryProvider).insert(
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
    JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                                ^^^^
  .
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
00:03 +10 -14: loading /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  .
00:05 +10 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts the start of Nowruz 1403
00:05 +11 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts a day in Aban 1405
00:05 +12 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian handles the last day of Esfand in a leap year
00:05 +13 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali round-trips 500 consecutive days
00:05 +14 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali Nowruz 1404 is 2025-03-21
00:05 +15 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths first six months have 31 days
00:05 +16 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths months seven to eleven have 30 days
00:05 +17 -14: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths Esfand has 29 days in a common year and 30 in a leap year
00:05 +18 -14: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (setUpAll)
00:05 +18 -14: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: writes and reads a string
00:05 +19 -14: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: overwriting replaces the previous value
00:05 +20 -14: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: booleans round-trip with a fallback for missing keys
00:05 +21 -14: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key
00:05 +21 -15: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key [E]
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
  
00:05 +21 -15: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:05 +22 -15: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (tearDownAll)
00:05 +22 -15: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: shortDate formats a Jalali date with Persian digits
00:05 +23 -15: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: longDate uses Persian month names
00:05 +24 -15: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: weekdayDate knows Persian weekday names
00:05 +25 -15: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: clock pads hours and minutes
00:05 +26 -15: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: relative describes recent times
00:05 +26 -16: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: relative describes recent times [E]
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
  
00:05 +26 -16: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: scheduleLabel distinguishes today and tomorrow
00:05 +27 -16: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: greeting follows the hour of day
00:05 +28 -16: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: addDays keeps the wall-clock time across month boundaries
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
00:05 +29 -17: loading /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  .
00:05 +29 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles units and teens
00:05 +30 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles tens and compounds
00:06 +31 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles hundreds and thousands
00:06 +32 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.fromWord parses digits and words
00:06 +33 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses a plain hour
00:06 +34 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses «و نیم» and «و ربع»
00:06 +35 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock applies Persian meridiems
00:06 +36 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock rejects nonsense instead of guessing
lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
Try adding a backslash (\) to escape the '$'.
    if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                    ^
lib/features/agent/agent_core.dart:40:16: Error: Type 'ToolResult' not found.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
lib/features/agent/agent_core.dart:40:16: Error: 'ToolResult' isn't a type.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
lib/features/agent/agent_core.dart:180:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('یادداشت حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:262:30: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
                             ^^^^^^^^^^
lib/features/agent/agent_core.dart:276:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('وظیفه حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:131:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/agent/agent_core.dart:214:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
  JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                              ^^^^
00:07 +37 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits converts ASCII digits
00:07 +38 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits keeps letters and punctuation
00:07 +39 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits accepts non-string input
00:07 +40 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Persian digits
00:07 +41 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Arabic-Indic digits
00:07 +42 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput unifies Arabic yeh and kaf
00:07 +43 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput removes diacritics and tatweel
00:07 +44 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput converts digits and collapses whitespace
00:07 +45 -17: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput replaces zero-width non-joiners with spaces
00:07 +46 -18: loading /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
  Try adding a backslash (\) to escape the '$'.
      if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                      ^
  lib/features/agent/agent_core.dart:40:16: Error: Type 'ToolResult' not found.
    final Future<ToolResult<Object?>> Function() execute;
                 ^^^^^^^^^^
  lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  lib/features/agent/agent_core.dart:40:16: Error: 'ToolResult' isn't a type.
    final Future<ToolResult<Object?>> Function() execute;
                 ^^^^^^^^^^
  lib/features/agent/agent_core.dart:180:28: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('یادداشت حذف شد.');
                             ^^^^^^^^^^
  lib/features/agent/agent_core.dart:262:30: Error: Not a constant expression.
                  return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
                               ^^^^^^^^^^
  lib/features/agent/agent_core.dart:276:28: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('وظیفه حذف شد.');
                             ^^^^^^^^^^
  lib/features/agent/agent_core.dart:131:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
   - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
                return ToolResult<Object?>.ok(
                       ^^^^^^^^^^
  lib/features/agent/agent_core.dart:214:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
   - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
                return ToolResult<Object?>.ok(
                       ^^^^^^^^^^
  lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
    JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                                ^^^^
  .
lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
Try adding a backslash (\) to escape the '$'.
    if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                    ^
00:08 +46 -19: loading /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
  Try adding a backslash (\) to escape the '$'.
      if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                      ^
  .
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
00:08 +46 -20: loading /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
   - '_Enum' is from 'dart:core'.
   - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
          kind: schedule?.kind ?? kind,
                               ^
  .
00:08 +46 -20: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: loading /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart
  /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: loading /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart
  /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: loading /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart
  /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: loading /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart
  ... and 16 more
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

Error: Couldn't resolve the package 'permission_handler' in 'package:permission_handler/permission_handler.dart'.
Error: Couldn't resolve the package 'flutter_tts' in 'package:flutter_tts/flutter_tts.dart'.
lib/services/permission_service.dart:1:8: Error: Not found: 'package:permission_handler/permission_handler.dart'
import 'package:permission_handler/permission_handler.dart';
       ^
lib/services/voice/native_tts_engine.dart:1:8: Error: Not found: 'package:flutter_tts/flutter_tts.dart'
import 'package:flutter_tts/flutter_tts.dart';
       ^
lib/core/utils/persian_date_parse.dart:102:53: Error: A '$' has special meaning inside a string, and must be followed by an identifier or an expression in curly braces ({}).
Try adding a backslash (\) to escape the '$'.
    if (RegExp('(^|\\s)${RegExp.escape(entry.key)}($|\\s)').hasMatch(text)) {
                                                    ^
lib/l10n/persian_material_localizations.dart:112:43: Error: Type 'AlwaysUse24HourFormat' not found.
  String formatHour(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = false}) {
                                          ^^^^^^^^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:121:48: Error: Type 'AlwaysUse24HourFormat' not found.
  String formatTimeOfDay(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = true}) {
                                               ^^^^^^^^^^^^^^^^^^^^^
lib/services/permission_service.dart:54:3: Error: Type 'Permission' not found.
  Permission? _map(JavidPermission permission) => switch (permission) {
  ^^^^^^^^^^
lib/services/voice/native_tts_engine.dart:13:9: Error: Type 'FlutterTts' not found.
  final FlutterTts _tts;
        ^^^^^^^^^^
lib/services/voice/native_tts_engine.dart:11:20: Error: Type 'FlutterTts' not found.
  NativeTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
                   ^^^^^^^^^^
lib/features/agent/agent_core.dart:40:16: Error: Type 'ToolResult' not found.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
lib/features/dashboard/dashboard_screen.dart:33:22: Error: Undefined name 'notificationRepositoryProvider'.
    return ref.watch(notificationRepositoryProvider).since(startOfDay);
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/core/providers/voice_providers.dart:25:48: Error: 'AssistantState' isn't a type.
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
                                               ^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:134:14: Error: The return type of the method 'PersianMaterialLocalizations.narrowWeekdays' is 'String', which does not match the return type, 'List<String>', of the overridden method, 'DefaultMaterialLocalizations.narrowWeekdays'.
 - 'List' is from 'dart:core'.
Change to a subtype of 'List<String>'.
  String get narrowWeekdays => 'ش،ی،د،س،چ،پ،ج';
             ^
/opt/hostedtoolcache/flutter/stable-3.47.9-x64/flutter/packages/flutter/lib/src/material/material_localizations.dart:938:20: Context: This is the overridden method ('narrowWeekdays').
  List<String> get narrowWeekdays => _narrowWeekdays;
                   ^
lib/l10n/persian_material_localizations.dart:112:43: Error: 'AlwaysUse24HourFormat' isn't a type.
  String formatHour(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = false}) {
                                          ^^^^^^^^^^^^^^^^^^^^^
lib/l10n/persian_material_localizations.dart:121:48: Error: 'AlwaysUse24HourFormat' isn't a type.
  String formatTimeOfDay(TimeOfDay timeOfDay, {AlwaysUse24HourFormat alwaysUse24HourFormat = true}) {
                                               ^^^^^^^^^^^^^^^^^^^^^
lib/features/jobs/jobs_screen.dart:26:10: Error: 'JobValidationException' isn't a type.
    } on JobValidationException catch (error) {
         ^^^^^^^^^^^^^^^^^^^^^^
lib/features/messages/messages_screen.dart:38:38: Error: The getter 'notificationRepositoryProvider' isn't defined for the type 'MessagesScreen'.
 - 'MessagesScreen' is from 'package:javid_ai/features/messages/messages_screen.dart' ('lib/features/messages/messages_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'notificationRepositoryProvider'.
                      await ref.read(notificationRepositoryProvider).markAllRead();
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/messages/messages_screen.dart:101:29: Error: The getter 'notificationRepositoryProvider' isn't defined for the type 'MessagesScreen'.
 - 'MessagesScreen' is from 'package:javid_ai/features/messages/messages_screen.dart' ('lib/features/messages/messages_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'notificationRepositoryProvider'.
                      .read(notificationRepositoryProvider)
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/notes/notes_screen.dart:254:12: Error: The method 'SurfaceCard' isn't defined for the type '_NoteTile'.
 - '_NoteTile' is from 'package:javid_ai/features/notes/notes_screen.dart' ('lib/features/notes/notes_screen.dart').
Try correcting the name to the name of an existing method, or defining a method named 'SurfaceCard'.
    return SurfaceCard(
           ^^^^^^^^^^^
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
lib/services/permission_service.dart:52:34: Error: The method 'openAppSettings' isn't defined for the type 'PermissionService'.
 - 'PermissionService' is from 'package:javid_ai/services/permission_service.dart' ('lib/services/permission_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'openAppSettings'.
  Future<bool> openSettings() => openAppSettings();
                                 ^^^^^^^^^^^^^^^
lib/services/permission_service.dart:55:39: Error: The getter 'Permission' isn't defined for the type 'PermissionService'.
 - 'PermissionService' is from 'package:javid_ai/services/permission_service.dart' ('lib/services/permission_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'Permission'.
        JavidPermission.microphone => Permission.microphone,
                                      ^^^^^^^^^^
lib/services/permission_service.dart:56:42: Error: The getter 'Permission' isn't defined for the type 'PermissionService'.
 - 'PermissionService' is from 'package:javid_ai/services/permission_service.dart' ('lib/services/permission_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'Permission'.
        JavidPermission.notifications => Permission.notification,
                                         ^^^^^^^^^^
lib/data/models/job.dart:82:30: Error: The argument type '_Enum' can't be assigned to the parameter type 'JobKind'.
 - '_Enum' is from 'dart:core'.
 - 'JobKind' is from 'package:javid_ai/data/models/job.dart' ('lib/data/models/job.dart').
        kind: schedule?.kind ?? kind,
                             ^
lib/features/jobs/job_editor_screen.dart:99:16: Error: The getter 'jobsRevisionProvider' isn't defined for the type '_JobEditorScreenState'.
 - '_JobEditorScreenState' is from 'package:javid_ai/features/jobs/job_editor_screen.dart' ('lib/features/jobs/job_editor_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'jobsRevisionProvider'.
      ref.read(jobsRevisionProvider.notifier).state++;
               ^^^^^^^^^^^^^^^^^^^^
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
lib/features/assistant/assistant_controller.dart:250:38: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
 - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
    final messages = await _ref.read(assistantRepositoryProvider).recent(limit: 20);
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/features/assistant/assistant_controller.dart:260:21: Error: The getter 'assistantRepositoryProvider' isn't defined for the type 'AssistantActivity'.
 - 'AssistantActivity' is from 'package:javid_ai/features/assistant/assistant_controller.dart' ('lib/features/assistant/assistant_controller.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'assistantRepositoryProvider'.
    await _ref.read(assistantRepositoryProvider).insert(
                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/services/voice/native_tts_engine.dart:11:20: Error: 'FlutterTts' isn't a type.
  NativeTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
                   ^^^^^^^^^^
lib/services/voice/native_tts_engine.dart:11:54: Error: Method not found: 'FlutterTts'.
  NativeTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
                                                     ^^^^^^^^^^
lib/services/voice/native_tts_engine.dart:13:9: Error: 'FlutterTts' isn't a type.
  final FlutterTts _tts;
        ^^^^^^^^^^
lib/features/agent/agent_core.dart:40:16: Error: 'ToolResult' isn't a type.
  final Future<ToolResult<Object?>> Function() execute;
               ^^^^^^^^^^
lib/features/agent/agent_core.dart:180:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('یادداشت حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:262:30: Error: Not a constant expression.
                return const ToolResult<Object?>.ok('وظیفه غیرفعال شد.');
                             ^^^^^^^^^^
lib/features/agent/agent_core.dart:276:28: Error: Not a constant expression.
              return const ToolResult<Object?>.ok('وظیفه حذف شد.');
                           ^^^^^^^^^^
lib/features/agent/agent_core.dart:131:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/agent/agent_core.dart:214:22: Error: The getter 'ToolResult' isn't defined for the type 'AgentCore'.
 - 'AgentCore' is from 'package:javid_ai/features/agent/agent_core.dart' ('lib/features/agent/agent_core.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ToolResult'.
              return ToolResult<Object?>.ok(
                     ^^^^^^^^^^
lib/features/agent/intent.dart:67:47: Error: Member not found: 'kind'.
  JobSchedule toSchedule() => ScheduleRequest.kind == JobScheduleKind.once
                                              ^^^^
Unhandled exception:
FileSystemException(uri=org-dartlang-untranslatable-uri:package%3Apermission_handler%2Fpermission_handler.d
art; message=StandardFileSystem only supports file:* and data:* URIs)
#0      StandardFileSystem.entityForUri (package:front_end/src/api_prototype/standard_file_system.dart:42)
#1      asFileUri (package:vm/kernel_front_end.dart:1059)
#2      writeDepfile (package:vm/kernel_front_end.dart:1220)
<asynchronous suspension>
#3      FrontendCompiler.compile (package:frontend_server/frontend_server.dart:932)
<asynchronous suspension>
#4      starter (package:frontend_server/starter.dart:108)
<asynchronous suspension>
#5      main (file:///b/s/w/ir/x/w/sdk/pkg/frontend_server/bin/frontend_server_starter.dart:13)
<asynchronous suspension>

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

BUILD FAILED in 2m 15s
Running Gradle task 'assembleDebug'...                            136.1s
Gradle task assembleDebug failed with exit code 1
```
