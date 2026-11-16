# CI log (run 43967036290)

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

26 issues found. (ran in 9.5s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart
00:00 +0: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: (setUpAll)
00:00 +0: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: (setUpAll)
00:00 +0: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +6: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +7: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +8: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +9: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +10: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +10 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +10 -1: /home/runner/work/Ideal/Ideal/test/unit/note_service_test.dart: data is readable after the database is closed and reopened [E]
  Expected: 'ماندگار'
    Actual: <null>
     Which: not an <Instance of 'String'>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/note_service_test.dart 100:5              main.<fn>
  
00:00 +10 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +11 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +12 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +13 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +14 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +15 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +16 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +17 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:00 +18 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +19 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +20 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +21 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +22 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +23 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +24 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +25 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +26 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:01 +27 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +28 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +29 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +30 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +31 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +32 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +33 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +34 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +35 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +36 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +37 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +38 -1: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +38 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +38 -2: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: notes creates a note from an explicit save command [E]
  Expected: 'جلسهٔ فردا ساعت ده'
    Actual: 'جلسه فردا ساعت ده'
     Which: is different.
            Expected: جلسهٔ فردا ساع ...
              Actual: جلسه فردا ساعت ...
                          ^
             Differ at offset 4
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 28:7              main.<fn>.<fn>
  
00:02 +39 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +40 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +41 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +42 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +43 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +44 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +45 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +46 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +47 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +48 -2: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +48 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +48 -3: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: job creation handles «و ربع» quarter hours [E]
  Expected: <10>
    Actual: <null>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 100:7             main.<fn>.<fn>
  
00:02 +49 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +50 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +51 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +52 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +53 -3: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +53 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +53 -4: /home/runner/work/Ideal/Ideal/test/unit/intent_parser_test.dart: briefing message summary without a schedule is not a job [E]
  Expected: IntentType:<IntentType.dailyBriefing>
    Actual: IntentType:<IntentType.messageSummary>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/intent_parser_test.dart 141:7             main.<fn>.<fn>
  
00:02 +54 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:02 +55 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +56 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +57 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +58 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +59 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +60 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +61 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +62 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +63 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +64 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:03 +65 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +66 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +67 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +68 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +69 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +70 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +71 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +72 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +73 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +74 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +75 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:04 +76 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +77 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +78 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +79 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +80 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +81 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +82 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +83 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +84 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +85 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +86 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +87 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +88 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:05 +89 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +90 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +91 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +92 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +93 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +94 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +95 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +96 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +97 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +98 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +99 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +100 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +101 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +102 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +103 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +104 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:06 +105 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +106 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +107 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +108 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +109 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +110 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +111 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +112 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +113 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +114 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +115 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +116 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +117 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +118 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:07 +119 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +120 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +121 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +122 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +123 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +124 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +125 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +126 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +127 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +128 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +129 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +130 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:08 +131 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +132 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +133 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +134 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +135 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +136 -4: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +136 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +136 -5: /home/runner/work/Ideal/Ideal/test/unit/agent_core_test.dart: jobs through the agent creates a daily job after confirmation [E]
  Expected: DateTime:<2026-11-16 20:00:00.000>
    Actual: DateTime:<2026-11-17 08:00:00.000>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/unit/agent_core_test.dart 104:7                main.<fn>.<fn>
  
00:09 +137 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +138 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +139 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +140 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +141 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +142 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +143 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +144 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +145 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +146 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +147 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +148 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +149 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +150 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +151 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +152 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:09 +153 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +154 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +155 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +156 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +157 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +158 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +159 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
00:10 +160 -5: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
10:00 +160 -6: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels [E]
  TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.
  dart:isolate  _RawReceivePort._handleMessage
  
10:00 +160 -6: /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: navigates through all five tabs
```
