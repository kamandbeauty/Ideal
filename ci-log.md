# CI log (run 44907983032)

```
----- analyze -----
Analyzing Ideal...                                              
No issues found! (ran in 6.7s)
----- test/build -----
Flutter 3.47.9 • channel stable • https://github.com/flutter/flutter.git
Framework • revision c197ca5199 (3 weeks ago) • 2026-10-29 10:10:20 -0400
Engine • hash 9e025265bef30b838c0c1b68cad19decf97048f2 (revision 89c39edfdf) (24 days ago) • 2026-10-27 19:51:20.000Z
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
+ jni 1.2.1
+ jni_flutter 1.1.0
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
+ url_launcher_android 6.3.35
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
No issues found! (ran in 6.7s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «امروز» resolves to the current day
00:00 +1: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «فردا» resolves to the next day
00:00 +2: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «پس‌فردا» resolves two days ahead
00:00 +3: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: day + month names resolve in the Jalali calendar
00:00 +4: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: a past Jalali day/month rolls to next year
00:00 +5: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: Persian ordinals are understood
00:00 +6: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: weekday names find the next occurrence
00:00 +7: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: «سه روز دیگر» offsets by days
00:00 +8: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: explicit dotted Jalali dates are accepted
00:00 +9: /home/runner/work/Ideal/Ideal/test/unit/persian_date_parse_test.dart: returns null when no date expression exists
00:00 +10: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles units and teens
00:00 +11: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles tens and compounds
00:00 +12: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.toWords handles hundreds and thousands
00:00 +13: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianNumbers.fromWord parses digits and words
00:00 +14: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses a plain hour
00:00 +15: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock parses «و نیم» and «و ربع»
00:00 +16: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock applies Persian meridiems
00:00 +17: /home/runner/work/Ideal/Ideal/test/unit/persian_time_test.dart: PersianTime.parseClock rejects nonsense instead of guessing
00:00 +18: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits converts ASCII digits
00:00 +19: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits keeps letters and punctuation
00:00 +20: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toPersianDigits accepts non-string input
00:00 +21: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Persian digits
00:00 +22: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: toAsciiDigits converts Arabic-Indic digits
00:00 +23: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput unifies Arabic yeh and kaf
00:00 +24: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput removes diacritics and tatweel
00:00 +25: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput converts digits and collapses whitespace
00:00 +26: /home/runner/work/Ideal/Ideal/test/unit/persian_digits_test.dart: normalizePersianInput replaces zero-width non-joiners with spaces
00:00 +27: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a greeting
00:01 +28: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: greetings and help recognises a help request
00:01 +29: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command
00:01 +30: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from «یادداشت جدید بساز»
00:01 +31: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes extracts quoted note bodies
00:01 +32: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes infers the work category
00:01 +33: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes asks for the body when the command has none
00:01 +34: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes lists notes
00:01 +35: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes deletes the latest note with confirmation
00:01 +36: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily reminder with a Persian word hour
00:01 +37: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation daily news summary keeps the briefing action
00:01 +38: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation one-off reminder for tomorrow at 09:00
00:01 +39: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «نه و نیم» clock expressions
00:01 +40: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours
00:01 +41: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation «۸ شب» becomes 20:00
00:01 +42: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation interval schedules respect the 15 minute minimum
00:01 +43: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation weekly schedule on Saturday
00:01 +44: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation a past clock time rolls over to tomorrow
00:01 +45: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing recognises a spoken briefing request
00:01 +46: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing message summary without a schedule is not a job
00:01 +47: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input falls back to unknown
00:01 +48: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: unrecognised input empty input is unknown
00:01 +49: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (setUpAll)
00:01 +49: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: creates a note and derives a title from the body
00:01 +50: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: keeps an explicit title
00:01 +51: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: truncates very long derived titles
00:01 +52: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: searches title and body
00:01 +53: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: filters by category
00:01 +54: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: falls back to general for unknown categories
00:01 +55: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: updates content and bumps updatedAt
00:01 +56: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: pins notes to the top of the list
00:01 +57: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: deletes a note
00:01 +58: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: latest returns the most recently updated note
00:01 +59: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data is readable after the database is closed and reopened
00:01 +60: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (tearDownAll)
00:02 +60: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: (setUpAll)
00:02 +60: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: a due reminder runs, posts a notification and records history
00:02 +61: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: nothing happens when no job is due
00:02 +62: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: a recurring job advances to its next slot after running
00:02 +63: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: the briefing summarises captured notifications instead of inventing
00:02 +64: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: a failing job is recorded as failed and does not throw
00:02 +65: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: the scheduler ticks, then stops cleanly
00:02 +66: /home/runner/work/Ideal/Ideal/test/unit/job_runner_test.dart: (tearDownAll)
00:02 +66: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: (setUpAll)
00:02 +66: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: creates a recurring job with the next run
00:02 +67: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: rejects one-off jobs in the past
00:02 +68: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: rejects intervals under the WorkManager minimum
00:02 +69: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: disabling clears the next run and enabling recomputes it
00:02 +70: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: records a successful run, advances the schedule and stores history
00:02 +71: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: a failed one-off job keeps its time so it can be retried
00:02 +72: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: due jobs only include active jobs whose time has come
00:02 +73: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: deleting a job also deletes its run history
00:02 +74: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: nextScheduled returns the soonest active job
00:02 +75: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: list ordering is stable and deterministic
00:02 +76: /home/runner/work/Ideal/Ideal/test/unit/job_service_test.dart: (tearDownAll)
00:02 +76: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: shortDate formats a Jalali date with Persian digits
00:02 +77: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: longDate uses Persian month names
00:02 +78: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: weekdayDate knows Persian weekday names
00:02 +79: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: clock pads hours and minutes
00:02 +80: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: relative describes recent times
00:02 +81: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: scheduleLabel distinguishes today and tomorrow
00:02 +82: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: greeting follows the hour of day
00:02 +83: /home/runner/work/Ideal/Ideal/test/unit/persian_date_test.dart: addDays keeps the wall-clock time across month boundaries
00:02 +84: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun one-off returns its anchor only when in the future
00:02 +85: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily fires today when the time is still ahead
00:02 +86: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun daily rolls to tomorrow when the time has passed
00:02 +87: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly finds the next matching weekday
00:02 +88: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun weekly returns today when it is the right day and still ahead
00:02 +89: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval advances from the anchor in fixed steps
00:02 +90: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun interval returns the anchor when it is still in the future
00:02 +91: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule.nextRun invalid schedules return null instead of throwing
00:02 +92: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip daily schedule survives serialisation
00:02 +93: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip one-off anchor survives serialisation
00:02 +94: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: JobSchedule JSON round-trip malformed JSON yields an invalid schedule rather than crashing
00:02 +95: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels daily label uses 24h times
00:02 +96: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels weekly label names the weekday
00:02 +97: /home/runner/work/Ideal/Ideal/test/unit/job_schedule_test.dart: labels interval label prefers hours for whole hours
00:03 +98: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing says so honestly when nothing happened
00:03 +99: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing counts messages per source with Persian digits
00:03 +100: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing highlights the next job and urgent items
00:03 +101: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing ignores notifications from previous days
00:03 +102: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: briefing never invents content when asked for details
00:03 +103: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: urge detector matches Persian and English keywords
00:03 +104: /home/runner/work/Ideal/Ideal/test/unit/briefing_service_test.dart: summarize builds a compact one-liner
00:03 +105: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: converts a valid native entry
00:03 +106: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: skips entries from disabled sources
00:03 +107: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: keeps unknown packages only when "other" is enabled
00:03 +108: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: drops empty and malformed rows
00:03 +109: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: falls back to capture time for invalid timestamps
00:03 +110: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: builds a dedupe key when the native one is missing
00:03 +111: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: flags urgent messages without inventing content
00:03 +112: /home/runner/work/Ideal/Ideal/test/unit/notification_ingestor_test.dart: import() writes through and reports new rows only
00:03 +113: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note round-trips through a map
00:03 +114: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note displayTitle falls back to the body
00:03 +115: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note preview flattens newlines
00:03 +116: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Note category labels are Persian
00:03 +117: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job round-trips through a map
00:03 +118: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job isRecurring and isActive reflect the schedule
00:03 +119: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: Job copyWith can clear nullable fields
00:03 +120: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: JobRun round-trips and computes duration
00:03 +121: /home/runner/work/Ideal/Ideal/test/unit/models_test.dart: AssistantMessage round-trips meta
00:03 +122: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (setUpAll)
00:03 +122: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: stores and lists notifications newest first
00:03 +123: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deduplicates by dedupe key
00:03 +124: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: group summaries are never surfaced
00:03 +125: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: unread counts only unread, non-summary rows
00:03 +126: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: markRead and markAllRead update rows
00:03 +127: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: since filters by post time
00:03 +128: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: deleteBefore removes old rows and deleteAll clears everything
00:03 +129: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: source labels map packages to Persian names
00:03 +130: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: package classification matches the Kotlin implementation
00:03 +131: /home/runner/work/Ideal/Ideal/test/unit/notification_repository_test.dart: (tearDownAll)
00:04 +131: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (setUpAll)
00:04 +131: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent note creation asks for confirmation and only saves on execute
00:04 +132: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent lists notes as a bullet list
00:04 +133: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent reading the latest note returns its body
00:04 +134: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent empty note commands ask for text instead of creating junk
00:04 +135: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: notes through the agent deleting a note needs confirmation and reports no data without it
00:04 +136: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation
00:04 +137: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a one-off reminder for tomorrow
00:04 +138: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent lists active jobs
00:04 +139: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent pausing a job requires confirmation
00:04 +140: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent briefing uses injected notifications and never invents data
00:04 +141: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent greeting mentions the time of day
00:04 +142: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent help lists real capabilities
00:04 +143: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: briefing through the agent unknown input gets a helpful fallback with examples
00:04 +144: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: (tearDownAll)
00:05 +144: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: (setUpAll)
00:05 +144: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: starts in the idle state
00:05 +145: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: listening captures partial transcripts
00:05 +146: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: processing a final transcript produces and speaks a reply
00:05 +147: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:05 +148: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:05 +149: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:05 +150: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: confirmation-gated intents do not execute before approval
00:05 +151: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: cancel on the confirmation sheet keeps data untouched
00:05 +152: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: recognition errors surface a Persian message and return to idle
00:05 +153: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: repeat replays the last assistant reply
00:05 +154: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: missing Persian TTS voice is reported, text answer still works
00:05 +155: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: typed input is recorded in the activity log
00:05 +156: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: stopAll returns to idle and stops audio
00:05 +157: /home/runner/work/Ideal/Ideal/test/unit/assistant_controller_test.dart: mute prevents speech output
00:05 +158: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: writes and reads a string
00:05 +159: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: overwriting replaces the previous value
00:05 +160: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: booleans round-trip with a fallback for missing keys
00:05 +161: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: readAll returns every stored key
00:05 +162: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: delete removes a key
00:05 +163: /home/runner/work/Ideal/Ideal/test/unit/settings_repository_test.dart: (tearDownAll)
00:06 +163: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts the start of Nowruz 1403
00:06 +164: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian converts a day in Aban 1405
00:06 +165: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: jalaliFromGregorian handles the last day of Esfand in a leap year
00:06 +166: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali round-trips 500 consecutive days
00:06 +167: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: gregorianFromJalali Nowruz 1404 is 2025-03-21
00:06 +168: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths first six months have 31 days
00:06 +169: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths months seven to eleven have 30 days
00:06 +170: /home/runner/work/Ideal/Ideal/test/unit/jalali_test.dart: month lengths Esfand has 29 days in a common year and 30 in a leap year
00:06 +171: All tests passed!
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart
00:00 +0: (setUpAll)
00:00 +0: boots into the assistant tab in RTL with Persian labels
00:01 +1: navigates through all five tabs
00:02 +2: typed assistant input opens the confirmation sheet
00:03 +3: a stored note appears in the notes tab
00:03 +4: (tearDownAll)
00:03 +4: All tests passed!
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
Running Gradle task 'assembleDebug'...                            220.9s
✓ Built build/app/outputs/flutter-apk/app-debug.apk

Welcome to Gradle 9.3.1!

Here are the highlights of this release:
 - Test reporting improvements
 - Error and warning improvements
 - Build authoring improvements

For more details see https://docs.gradle.org/9.3.1/release-notes.html

> Task :gradle:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :gradle:compileKotlin UP-TO-DATE
> Task :gradle:compileJava NO-SOURCE
> Task :gradle:compileGroovy NO-SOURCE
> Task :gradle:pluginDescriptors UP-TO-DATE
> Task :gradle:processResources UP-TO-DATE
> Task :gradle:classes UP-TO-DATE
> Task :gradle:jar UP-TO-DATE

> Configure project :app
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
WARNING: The option setting 'android.newDsl=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':app' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :flutter_secure_storage
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':flutter_secure_storage' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :flutter_tts
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':flutter_tts' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :jni
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':jni' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :jni_flutter
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':jni_flutter' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :permission_handler_android
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':permission_handler_android' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :shared_preferences_android
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':shared_preferences_android' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :speech_to_text
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':speech_to_text' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :sqflite_android
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':sqflite_android' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Configure project :url_launcher_android
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':url_launcher_android' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.

WARNING: Your Android app project: app located at: /home/runner/work/Ideal/Ideal/android/app/build.gradle.kts
applies the Kotlin Gradle Plugin, which will cause build failures in future versions of Flutter.
Please migrate your app to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_tts
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.

Please check the changelogs of these plugins and upgrade to a version that supports Built-in Kotlin.
If no such version exists, report the issue to the plugin. If necessary, here is a guide on filing
an issue against a plugin: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors

If you are a plugin author, please migrate your plugin to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors

> Task :flutter_tts:generateDebugAssets UP-TO-DATE
> Task :flutter_tts:preBuild UP-TO-DATE
> Task :flutter_tts:preDebugBuild UP-TO-DATE
> Task :jni:generateDebugAssets UP-TO-DATE
> Task :flutter_secure_storage:generateDebugAssets UP-TO-DATE
> Task :jni:preBuild UP-TO-DATE
> Task :jni:preDebugBuild UP-TO-DATE
> Task :flutter_secure_storage:preBuild UP-TO-DATE
> Task :flutter_secure_storage:preDebugBuild UP-TO-DATE
> Task :jni:mergeDebugAssets UP-TO-DATE
> Task :jni_flutter:generateDebugAssets UP-TO-DATE
> Task :jni_flutter:preBuild UP-TO-DATE
> Task :jni_flutter:preDebugBuild UP-TO-DATE
> Task :flutter_tts:mergeDebugAssets UP-TO-DATE
> Task :permission_handler_android:generateDebugAssets UP-TO-DATE
> Task :permission_handler_android:preBuild UP-TO-DATE
> Task :permission_handler_android:preDebugBuild UP-TO-DATE
> Task :app:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni_flutter:mergeDebugAssets UP-TO-DATE
> Task :shared_preferences_android:generateDebugAssets UP-TO-DATE
> Task :shared_preferences_android:preBuild UP-TO-DATE
> Task :shared_preferences_android:preDebugBuild UP-TO-DATE
> Task :flutter_secure_storage:mergeDebugAssets UP-TO-DATE
> Task :permission_handler_android:mergeDebugAssets UP-TO-DATE
> Task :speech_to_text:generateDebugAssets UP-TO-DATE
> Task :speech_to_text:preBuild UP-TO-DATE
> Task :speech_to_text:preDebugBuild UP-TO-DATE
> Task :sqflite_android:generateDebugAssets UP-TO-DATE
> Task :sqflite_android:preBuild UP-TO-DATE
> Task :sqflite_android:preDebugBuild UP-TO-DATE
> Task :shared_preferences_android:mergeDebugAssets UP-TO-DATE
> Task :speech_to_text:mergeDebugAssets UP-TO-DATE
> Task :url_launcher_android:generateDebugAssets UP-TO-DATE
> Task :url_launcher_android:preBuild UP-TO-DATE
> Task :url_launcher_android:preDebugBuild UP-TO-DATE
> Task :sqflite_android:mergeDebugAssets UP-TO-DATE
> Task :flutter_secure_storage:processDebugNavigationResources UP-TO-DATE
> Task :flutter_tts:processDebugNavigationResources UP-TO-DATE
> Task :url_launcher_android:mergeDebugAssets UP-TO-DATE
> Task :jni:processDebugNavigationResources UP-TO-DATE
> Task :jni_flutter:processDebugNavigationResources UP-TO-DATE
> Task :speech_to_text:processDebugNavigationResources UP-TO-DATE
> Task :permission_handler_android:processDebugNavigationResources UP-TO-DATE
> Task :sqflite_android:processDebugNavigationResources UP-TO-DATE
> Task :url_launcher_android:processDebugNavigationResources UP-TO-DATE
> Task :flutter_secure_storage:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :flutter_tts:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :flutter_tts:generateDebugResources UP-TO-DATE
> Task :shared_preferences_android:processDebugNavigationResources UP-TO-DATE
> Task :jni:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :flutter_secure_storage:generateDebugBuildConfig UP-TO-DATE
> Task :jni:generateDebugResources UP-TO-DATE
> Task :flutter_tts:packageDebugResources UP-TO-DATE
> Task :jni:packageDebugResources UP-TO-DATE
> Task :app:cleanMergeDebugAssets
> Task :flutter_secure_storage:generateDebugResources UP-TO-DATE
> Task :flutter_tts:parseDebugLocalResources UP-TO-DATE
> Task :jni:parseDebugLocalResources UP-TO-DATE
> Task :flutter_secure_storage:packageDebugResources UP-TO-DATE
> Task :jni:generateDebugRFile UP-TO-DATE
> Task :flutter_tts:generateDebugRFile UP-TO-DATE
> Task :flutter_secure_storage:parseDebugLocalResources UP-TO-DATE
> Task :jni:compileDebugKotlin NO-SOURCE
> Task :flutter_secure_storage:generateDebugRFile UP-TO-DATE
> Task :jni:javaPreCompileDebug UP-TO-DATE
> Task :flutter_secure_storage:compileDebugKotlin NO-SOURCE
> Task :flutter_secure_storage:javaPreCompileDebug UP-TO-DATE
> Task :flutter_secure_storage:compileDebugJavaWithJavac UP-TO-DATE
> Task :jni:compileDebugJavaWithJavac UP-TO-DATE
> Task :jni:bundleLibCompileToJarDebug UP-TO-DATE
> Task :jni_flutter:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni_flutter:generateDebugResources UP-TO-DATE
> Task :flutter_secure_storage:bundleLibCompileToJarDebug UP-TO-DATE
> Task :permission_handler_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :permission_handler_android:generateDebugResources UP-TO-DATE
> Task :jni_flutter:packageDebugResources UP-TO-DATE
> Task :flutter_tts:compileDebugKotlin UP-TO-DATE
> Task :permission_handler_android:packageDebugResources UP-TO-DATE
> Task :jni_flutter:parseDebugLocalResources UP-TO-DATE
> Task :flutter_tts:javaPreCompileDebug UP-TO-DATE
> Task :flutter_tts:compileDebugJavaWithJavac NO-SOURCE
> Task :flutter_tts:bundleLibCompileToJarDebug UP-TO-DATE
> Task :shared_preferences_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :shared_preferences_android:generateDebugResources UP-TO-DATE
> Task :shared_preferences_android:packageDebugResources UP-TO-DATE
> Task :permission_handler_android:parseDebugLocalResources UP-TO-DATE
> Task :jni_flutter:generateDebugRFile UP-TO-DATE
> Task :shared_preferences_android:parseDebugLocalResources UP-TO-DATE
> Task :permission_handler_android:generateDebugRFile UP-TO-DATE
> Task :permission_handler_android:compileDebugKotlin NO-SOURCE
> Task :permission_handler_android:javaPreCompileDebug UP-TO-DATE
> Task :shared_preferences_android:generateDebugRFile UP-TO-DATE
> Task :jni_flutter:compileDebugKotlin NO-SOURCE
> Task :jni_flutter:javaPreCompileDebug UP-TO-DATE
> Task :permission_handler_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :permission_handler_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :speech_to_text:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni_flutter:compileDebugJavaWithJavac UP-TO-DATE
> Task :speech_to_text:generateDebugResources UP-TO-DATE
> Task :jni_flutter:bundleLibCompileToJarDebug UP-TO-DATE
> Task :sqflite_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :sqflite_android:generateDebugResources UP-TO-DATE
> Task :speech_to_text:packageDebugResources UP-TO-DATE
> Task :speech_to_text:parseDebugLocalResources UP-TO-DATE
> Task :sqflite_android:packageDebugResources UP-TO-DATE
> Task :sqflite_android:parseDebugLocalResources UP-TO-DATE
> Task :sqflite_android:generateDebugRFile UP-TO-DATE
> Task :speech_to_text:generateDebugRFile UP-TO-DATE
> Task :sqflite_android:compileDebugKotlin NO-SOURCE
> Task :sqflite_android:javaPreCompileDebug UP-TO-DATE
> Task :shared_preferences_android:compileDebugKotlin UP-TO-DATE
> Task :shared_preferences_android:javaPreCompileDebug UP-TO-DATE
> Task :shared_preferences_android:compileDebugJavaWithJavac NO-SOURCE
> Task :shared_preferences_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :url_launcher_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :sqflite_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :sqflite_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :flutter_secure_storage:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_tts:writeDebugAarMetadata UP-TO-DATE
> Task :jni:writeDebugAarMetadata UP-TO-DATE
> Task :jni_flutter:writeDebugAarMetadata UP-TO-DATE
> Task :permission_handler_android:writeDebugAarMetadata UP-TO-DATE
> Task :shared_preferences_android:writeDebugAarMetadata UP-TO-DATE
> Task :sqflite_android:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_secure_storage:extractDeepLinksDebug UP-TO-DATE
> Task :url_launcher_android:generateDebugBuildConfig UP-TO-DATE
> Task :url_launcher_android:generateDebugResources UP-TO-DATE
> Task :url_launcher_android:packageDebugResources UP-TO-DATE
> Task :url_launcher_android:parseDebugLocalResources UP-TO-DATE
> Task :flutter_secure_storage:processDebugManifest UP-TO-DATE
> Task :flutter_tts:extractDeepLinksDebug UP-TO-DATE
> Task :url_launcher_android:generateDebugRFile UP-TO-DATE
> Task :speech_to_text:compileDebugKotlin UP-TO-DATE
> Task :speech_to_text:javaPreCompileDebug UP-TO-DATE
> Task :speech_to_text:compileDebugJavaWithJavac NO-SOURCE
> Task :speech_to_text:bundleLibCompileToJarDebug UP-TO-DATE
> Task :speech_to_text:writeDebugAarMetadata UP-TO-DATE
> Task :jni:extractDeepLinksDebug UP-TO-DATE
> Task :flutter_tts:processDebugManifest UP-TO-DATE
> Task :jni_flutter:extractDeepLinksDebug UP-TO-DATE
> Task :jni:processDebugManifest UP-TO-DATE
> Task :jni_flutter:processDebugManifest UP-TO-DATE
> Task :url_launcher_android:compileDebugKotlin UP-TO-DATE
> Task :permission_handler_android:extractDeepLinksDebug UP-TO-DATE
> Task :shared_preferences_android:extractDeepLinksDebug UP-TO-DATE
> Task :url_launcher_android:javaPreCompileDebug UP-TO-DATE
> Task :shared_preferences_android:processDebugManifest UP-TO-DATE
> Task :speech_to_text:extractDeepLinksDebug UP-TO-DATE
> Task :speech_to_text:processDebugManifest UP-TO-DATE
> Task :sqflite_android:extractDeepLinksDebug UP-TO-DATE
> Task :permission_handler_android:processDebugManifest UP-TO-DATE
> Task :sqflite_android:processDebugManifest UP-TO-DATE
> Task :flutter_secure_storage:mapDebugSourceSetPaths UP-TO-DATE
> Task :url_launcher_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :flutter_tts:mapDebugSourceSetPaths UP-TO-DATE
> Task :url_launcher_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :flutter_secure_storage:compileDebugLibraryResources UP-TO-DATE
> Task :url_launcher_android:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_tts:compileDebugLibraryResources UP-TO-DATE
> Task :url_launcher_android:extractDeepLinksDebug UP-TO-DATE
> Task :jni_flutter:mapDebugSourceSetPaths UP-TO-DATE
> Task :jni_flutter:compileDebugLibraryResources UP-TO-DATE
> Task :permission_handler_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :permission_handler_android:compileDebugLibraryResources UP-TO-DATE
> Task :shared_preferences_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :jni:mapDebugSourceSetPaths UP-TO-DATE
> Task :jni:compileDebugLibraryResources UP-TO-DATE
> Task :shared_preferences_android:compileDebugLibraryResources UP-TO-DATE
> Task :speech_to_text:mapDebugSourceSetPaths UP-TO-DATE
> Task :sqflite_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :url_launcher_android:processDebugManifest UP-TO-DATE
> Task :speech_to_text:compileDebugLibraryResources UP-TO-DATE
> Task :sqflite_android:compileDebugLibraryResources UP-TO-DATE
> Task :flutter_secure_storage:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :url_launcher_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :flutter_tts:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :flutter_secure_storage:processDebugJavaRes NO-SOURCE
> Task :url_launcher_android:compileDebugLibraryResources UP-TO-DATE
> Task :jni:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :jni_flutter:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :flutter_tts:processDebugJavaRes UP-TO-DATE
> Task :jni:processDebugJavaRes NO-SOURCE
> Task :jni_flutter:processDebugJavaRes NO-SOURCE
> Task :shared_preferences_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :speech_to_text:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :permission_handler_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :permission_handler_android:processDebugJavaRes NO-SOURCE
> Task :shared_preferences_android:processDebugJavaRes UP-TO-DATE
> Task :sqflite_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :url_launcher_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :sqflite_android:processDebugJavaRes NO-SOURCE
> Task :flutter_secure_storage:preDebugUnitTestBuild UP-TO-DATE
> Task :url_launcher_android:processDebugJavaRes UP-TO-DATE
> Task :flutter_tts:preDebugUnitTestBuild UP-TO-DATE
> Task :speech_to_text:processDebugJavaRes UP-TO-DATE
> Task :jni:preDebugUnitTestBuild UP-TO-DATE
> Task :flutter_tts:generateDebugUnitTestStubRFile
> Task :jni:generateDebugUnitTestStubRFile
> Task :flutter_secure_storage:generateDebugUnitTestStubRFile
> Task :flutter_tts:compileDebugUnitTestKotlin NO-SOURCE
> Task :jni:compileDebugUnitTestKotlin NO-SOURCE
> Task :flutter_secure_storage:javaPreCompileDebugUnitTest FROM-CACHE
> Task :jni:javaPreCompileDebugUnitTest FROM-CACHE
> Task :flutter_tts:javaPreCompileDebugUnitTest FROM-CACHE
> Task :jni:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :flutter_tts:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :flutter_secure_storage:compileDebugUnitTestKotlin NO-SOURCE
> Task :flutter_secure_storage:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :jni:processDebugUnitTestJavaRes NO-SOURCE
> Task :flutter_secure_storage:processDebugUnitTestJavaRes NO-SOURCE
> Task :jni:testDebugUnitTest NO-SOURCE
> Task :jni_flutter:preDebugUnitTestBuild UP-TO-DATE
> Task :flutter_secure_storage:testDebugUnitTest NO-SOURCE
> Task :permission_handler_android:preDebugUnitTestBuild UP-TO-DATE
> Task :flutter_tts:processDebugUnitTestJavaRes NO-SOURCE
> Task :flutter_tts:testDebugUnitTest NO-SOURCE
> Task :jni_flutter:javaPreCompileDebugUnitTest FROM-CACHE
> Task :permission_handler_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :shared_preferences_android:preDebugUnitTestBuild UP-TO-DATE
> Task :permission_handler_android:generateDebugUnitTestStubRFile
> Task :jni_flutter:generateDebugUnitTestStubRFile
> Task :jni_flutter:compileDebugUnitTestKotlin NO-SOURCE
> Task :jni_flutter:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :jni_flutter:processDebugUnitTestJavaRes NO-SOURCE
> Task :permission_handler_android:compileDebugUnitTestKotlin NO-SOURCE
> Task :jni_flutter:testDebugUnitTest NO-SOURCE
> Task :speech_to_text:preDebugUnitTestBuild UP-TO-DATE
> Task :permission_handler_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :permission_handler_android:processDebugUnitTestJavaRes NO-SOURCE
> Task :permission_handler_android:testDebugUnitTest NO-SOURCE
> Task :sqflite_android:preDebugUnitTestBuild UP-TO-DATE
> Task :sqflite_android:generateDebugUnitTestStubRFile
> Task :speech_to_text:javaPreCompileDebugUnitTest FROM-CACHE
> Task :sqflite_android:compileDebugUnitTestKotlin NO-SOURCE
> Task :sqflite_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :speech_to_text:generateDebugUnitTestStubRFile
> Task :speech_to_text:compileDebugUnitTestKotlin NO-SOURCE
> Task :speech_to_text:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :speech_to_text:processDebugUnitTestJavaRes NO-SOURCE
> Task :speech_to_text:testDebugUnitTest NO-SOURCE
> Task :url_launcher_android:preDebugUnitTestBuild UP-TO-DATE
> Task :sqflite_android:compileDebugUnitTestJavaWithJavac
> Task :sqflite_android:processDebugUnitTestJavaRes NO-SOURCE
> Task :url_launcher_android:checkDebugUnitTestAarMetadata
> Task :url_launcher_android:mapDebugUnitTestSourceSetPaths
> Task :url_launcher_android:generateDebugUnitTestResources FROM-CACHE
> Task :shared_preferences_android:checkDebugUnitTestAarMetadata
> Task :shared_preferences_android:mapDebugUnitTestSourceSetPaths
> Task :shared_preferences_android:generateDebugUnitTestResources FROM-CACHE
> Task :url_launcher_android:mergeDebugUnitTestResources
> Task :url_launcher_android:processDebugUnitTestManifest
> Task :url_launcher_android:processDebugUnitTestResources
> Task :shared_preferences_android:mergeDebugUnitTestResources
> Task :shared_preferences_android:processDebugUnitTestManifest
> Task :sqflite_android:testDebugUnitTest
> Task :shared_preferences_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :shared_preferences_android:generateDebugUnitTestAssets UP-TO-DATE
> Task :shared_preferences_android:processDebugUnitTestResources
> Task :shared_preferences_android:mergeDebugUnitTestAssets
> Task :url_launcher_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :url_launcher_android:generateDebugUnitTestAssets UP-TO-DATE
> Task :url_launcher_android:mergeDebugUnitTestAssets
> Task :url_launcher_android:packageDebugUnitTestForUnitTest
> Task :url_launcher_android:generateDebugUnitTestConfig
> Task :shared_preferences_android:packageDebugUnitTestForUnitTest
> Task :shared_preferences_android:generateDebugUnitTestConfig
> Task :url_launcher_android:compileDebugUnitTestKotlin
> Task :url_launcher_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :url_launcher_android:processDebugUnitTestJavaRes
> Task :shared_preferences_android:compileDebugUnitTestKotlin
> Task :shared_preferences_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :shared_preferences_android:processDebugUnitTestJavaRes

> Task :shared_preferences_android:testDebugUnitTest

LegacySharedPreferencesTest > executesOnBackgroundThreadSeriallyInFifoOrder STANDARD_ERROR
    WARNING: A Java agent has been loaded dynamically (/home/runner/.gradle/caches/modules-2/files-2.1/net.bytebuddy/byte-buddy-agent/1.18.2/62f38a6faf7f069d661b79a07d566f504b0b20c4/byte-buddy-agent-1.18.2.jar)
    WARNING: If a serviceability tool is in use, please run with -XX:+EnableDynamicAgentLoading to hide this warning
    WARNING: If a serviceability tool is not in use, please run with -Djdk.instrument.traceUsage for more information
    WARNING: Dynamic loading of agents will be disallowed by default in a future release

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :shared_preferences_android:testDebugUnitTest

LegacySharedPreferencesTest > executesOnBackgroundThreadSeriallyInFifoOrder PASSED

LegacySharedPreferencesTest > getAll PASSED

LegacySharedPreferencesTest > setInt PASSED

LegacySharedPreferencesTest > onAttachedToEngine_doesNotEagerlyInitializePreferences PASSED

LegacySharedPreferencesTest > setDouble PASSED

LegacySharedPreferencesTest > setEncodedStringListSetsAndGetsString PASSED

LegacySharedPreferencesTest > allowList PASSED

LegacySharedPreferencesTest > clearWithNoAllowList PASSED

LegacySharedPreferencesTest > setString PASSED

LegacySharedPreferencesTest > clearWithAllowList PASSED

LegacySharedPreferencesTest > clearAll PASSED

LegacySharedPreferencesTest > testRemove PASSED

LegacySharedPreferencesTest > setBool PASSED

> Task :app:compileFlutterBuildDebug
> Task :app:generateDebugAssets UP-TO-DATE
> Task :app:validateCompileSdkVersion
> Task :app:preBuild
> Task :app:preDebugBuild
> Task :app:mergeDebugAssets
> Task :app:copyFlutterAssetsDebug
> Task :app:generateDebugResources UP-TO-DATE
> Task :app:packageDebugResources UP-TO-DATE
> Task :app:processDebugNavigationResources UP-TO-DATE
> Task :app:parseDebugLocalResources UP-TO-DATE
> Task :app:generateDebugRFile UP-TO-DATE
> Task :app:compileDebugKotlin UP-TO-DATE
> Task :app:javaPreCompileDebug UP-TO-DATE
> Task :app:compileDebugJavaWithJavac UP-TO-DATE
> Task :app:checkDebugAarMetadata UP-TO-DATE
> Task :app:mapDebugSourceSetPaths UP-TO-DATE
> Task :app:compileDebugNavigationResources UP-TO-DATE
> Task :app:mergeDebugResources UP-TO-DATE
> Task :app:createDebugCompatibleScreenManifests UP-TO-DATE
> Task :app:extractDeepLinksDebug UP-TO-DATE
> Task :app:processDebugMainManifest UP-TO-DATE
> Task :app:outputDebugAppLinkSettings UP-TO-DATE
> Task :app:processDebugManifest UP-TO-DATE
> Task :app:processDebugManifestForPackage UP-TO-DATE
> Task :app:processDebugResources UP-TO-DATE
> Task :app:bundleDebugClassesToRuntimeJar
> Task :app:preDebugUnitTestBuild
> Task :app:bundleDebugClassesToCompileJar
> Task :app:javaPreCompileDebugUnitTest FROM-CACHE
> Task :app:processDebugJavaRes UP-TO-DATE
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
> Task :app:compileDebugUnitTestKotlin
> Task :app:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :app:processDebugUnitTestJavaRes

> Task :shared_preferences_android:testDebugUnitTest

SharedPreferencesTest > testSharedPreferencesWithMultipleFiles PASSED

SharedPreferencesTest > testSetAndGetStringListWithSharedPreferencesRedirectsForPlatformEncoded PASSED

SharedPreferencesTest > testSetAndGetStringWithDataStore PASSED

SharedPreferencesTest > testSharedPreferencesDefaultFile PASSED

SharedPreferencesTest > testClearWithDataStore PASSED

SharedPreferencesTest > testGetKeysWithSharedPreferences PASSED

SharedPreferencesTest > testSetAndGetIntWithSharedPreferences PASSED

SharedPreferencesTest > testSetAndGetDoubleWithSharedPreferences PASSED

SharedPreferencesTest > testExecutesOnBackgroundThreadSeriallyInFifoOrder PASSED

SharedPreferencesTest > testGetAllWithSharedPreferences PASSED

SharedPreferencesTest > testGetAllWithAllowListWithDataStore PASSED

SharedPreferencesTest > testSetAndGetStringListWithDataStoreReportsRawString PASSED

SharedPreferencesTest > testClearWithAllowListWithSharedPreferences PASSED

SharedPreferencesTest > testSetAndGetBoolWithSharedPreferences PASSED

SharedPreferencesTest > testSetAndGetStringListWithSharedPreferencesReportsRawString PASSED

SharedPreferencesTest > testSetAndGetBoolWithDataStore PASSED

SharedPreferencesTest > testGetAllWithAllowListWithSharedPreferences PASSED

SharedPreferencesTest > testGetKeysWithDataStore PASSED

SharedPreferencesTest > testSetAndGetStringWithSharedPreferences PASSED

SharedPreferencesTest > testSetAndGetDoubleWithDataStore PASSED

SharedPreferencesTest > testSetAndGetIntWithDataStore PASSED

SharedPreferencesTest > testSetAndGetStringListWithSharedPreferences PASSED

SharedPreferencesTest > testClearWithSharedPreferences PASSED

SharedPreferencesTest > testClearWithAllowListWithDataStore PASSED

SharedPreferencesTest > testSetAndGetStringListWithDataStore PASSED

SharedPreferencesTest > testGetAllWithDataStore PASSED

SharedPreferencesTest > testUnexpectedClassDecodeThrows PASSED

SharedPreferencesTest > testSetAndGetStringListWithDataStoreRedirectsForPlatformEncoded PASSED

> Task :app:testDebugUnitTest

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[30] STANDARD_ERROR
    Mockito is currently self-attaching to enable the inline-mock-maker. This will no longer work in future releases of the JDK. Please add Mockito as an agent to your build as described in Mockito's documentation: https://javadoc.io/doc/org.mockito/mockito-core/latest/org.mockito/org/mockito/Mockito.html#0.3
    WARNING: A Java agent has been loaded dynamically (/tmp/byteBuddyAgent17374032995884732976.jar)
    WARNING: If a serviceability tool is in use, please run with -XX:+EnableDynamicAgentLoading to hide this warning
    WARNING: If a serviceability tool is not in use, please run with -Djdk.instrument.traceUsage for more information
    WARNING: Dynamic loading of agents will be disallowed by default in a future release

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[30] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[31] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[32] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[33] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[34] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[35] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[36] PASSED

UrlLauncherTest > openWebView_fallsBackToWebViewIfCustomTabFails PASSED

UrlLauncherTest > openWebView_throwsForNoCurrentActivity PASSED

UrlLauncherTest > openWebView_opensUrlInCustomTabsWithShowTitle PASSED

UrlLauncherTest > openWebView_opensUrlInCustomTabsWithoutShowTitle PASSED

UrlLauncherTest > openUrlInApp_opensUrlInWebViewIfNecessary PASSED

UrlLauncherTest > openWebView_opensUrlInCustomTabs PASSED

UrlLauncherTest > canLaunch_returnsFalseForEmulatorFallbackComponent PASSED

UrlLauncherTest > openWebView_handlesEnableJavaScript PASSED

UrlLauncherTest > canLaunch_createsIntentWithPassedUrl PASSED

UrlLauncherTest > launch_returnsTrue PASSED

UrlLauncherTest > openWebView_handlesEnableDomStorage PASSED

UrlLauncherTest > openWebView_handlesEnableShowTitle PASSED

UrlLauncherTest > canLaunch_returnsFalse PASSED

UrlLauncherTest > launch_throwsForNoCurrentActivity PASSED

UrlLauncherTest > openWebView_returnsFalse PASSED

UrlLauncherTest > closeWebView_closes PASSED

UrlLauncherTest > canLaunch_returnsTrue PASSED

UrlLauncherTest > openWebView_handlesHeaders PASSED

UrlLauncherTest > openWebView_opensUrlInCustomTabsWithCORSAllowedHeader PASSED

UrlLauncherTest > launch_returnsFalse PASSED

UrlLauncherTest > openWebView_opensUrlInWebViewIfRequested PASSED

UrlLauncherTest > launch_createsIntentWithPassedUrl PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested PASSED

WebViewActivityTest > extractHeaders_returnsEmptyMapWhenHeadersBundleNull PASSED

[Incubating] Problems report is available at: file:///home/runner/work/Ideal/Ideal/build/reports/problems/problems-report.html

Deprecated Gradle features were used in this build, making it incompatible with Gradle 10.

You can use '--warning-mode all' to show the individual deprecation warnings and determine if they come from your own scripts or plugins.

For more on this, please refer to https://docs.gradle.org/9.3.1/userguide/command_line_interface.html#sec:command_line_warnings in the Gradle documentation.

BUILD SUCCESSFUL in 1m 5s
219 actionable tasks: 41 executed, 12 from cache, 166 up-to-date
```
