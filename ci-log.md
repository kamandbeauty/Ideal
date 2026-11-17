# CI log (run 44068726190)

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

  error • Undefined name 'speakRepliesProvider'. Try correcting the name to one that is defined, or defining the name • lib/core/providers/voice_providers.dart:34:29 • undefined_identifier
  error • Undefined name 'jobsRevisionProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/jobs/job_editor_screen.dart:99:16 • undefined_identifier
  error • Undefined name 'secureStoreProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/settings/ai_settings_screen.dart:39:32 • undefined_identifier
  error • Undefined name 'secureStoreProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/settings/ai_settings_screen.dart:57:22 • undefined_identifier
  error • Undefined name 'secureStoreProvider'. Try correcting the name to one that is defined, or defining the name • lib/features/settings/ai_settings_screen.dart:72:20 • undefined_identifier

5 issues found. (ran in 9.8s)
00:00 +0: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart
lib/core/providers/voice_providers.dart:34:29: Error: Undefined name 'speakRepliesProvider'.
    speakReplies: ref.watch(speakRepliesProvider),
                            ^^^^^^^^^^^^^^^^^^^^
lib/features/jobs/job_editor_screen.dart:99:16: Error: The getter 'jobsRevisionProvider' isn't defined for the type '_JobEditorScreenState'.
 - '_JobEditorScreenState' is from 'package:javid_ai/features/jobs/job_editor_screen.dart' ('lib/features/jobs/job_editor_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'jobsRevisionProvider'.
      ref.read(jobsRevisionProvider.notifier).state++;
               ^^^^^^^^^^^^^^^^^^^^
lib/features/settings/ai_settings_screen.dart:39:32: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
 - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
    final key = await ref.read(secureStoreProvider).readApiKey();
                               ^^^^^^^^^^^^^^^^^^^
lib/features/settings/ai_settings_screen.dart:57:22: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
 - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
      await ref.read(secureStoreProvider).writeApiKey(_apiKey.text.trim());
                     ^^^^^^^^^^^^^^^^^^^
lib/features/settings/ai_settings_screen.dart:72:20: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
 - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
    await ref.read(secureStoreProvider).deleteApiKey();
                   ^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart [E]
  Failed to load "/home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart":
  Compilation failed for testPath=/home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: lib/core/providers/voice_providers.dart:34:29: Error: Undefined name 'speakRepliesProvider'.
      speakReplies: ref.watch(speakRepliesProvider),
                              ^^^^^^^^^^^^^^^^^^^^
  lib/features/jobs/job_editor_screen.dart:99:16: Error: The getter 'jobsRevisionProvider' isn't defined for the type '_JobEditorScreenState'.
   - '_JobEditorScreenState' is from 'package:javid_ai/features/jobs/job_editor_screen.dart' ('lib/features/jobs/job_editor_screen.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'jobsRevisionProvider'.
        ref.read(jobsRevisionProvider.notifier).state++;
                 ^^^^^^^^^^^^^^^^^^^^
  lib/features/settings/ai_settings_screen.dart:39:32: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
   - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
      final key = await ref.read(secureStoreProvider).readApiKey();
                                 ^^^^^^^^^^^^^^^^^^^
  lib/features/settings/ai_settings_screen.dart:57:22: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
   - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
        await ref.read(secureStoreProvider).writeApiKey(_apiKey.text.trim());
                       ^^^^^^^^^^^^^^^^^^^
  lib/features/settings/ai_settings_screen.dart:72:20: Error: The getter 'secureStoreProvider' isn't defined for the type '_AiSettingsScreenState'.
   - '_AiSettingsScreenState' is from 'package:javid_ai/features/settings/ai_settings_screen.dart' ('lib/features/settings/ai_settings_screen.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'secureStoreProvider'.
      await ref.read(secureStoreProvider).deleteApiKey();
                     ^^^^^^^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: loading /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart
```
