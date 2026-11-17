# CI log (run 44090430887)

```
�════════════════════════════════════════════════════════
00:03 +0 -3: typed assistant input produces a confirmation sheet [E]
  Test failed. See exception logs above.
  The test description was: typed assistant input produces a confirmation sheet
  
00:03 +0 -3: notes created through the agent appear in the notes tab
00:03 +0 -3: typed assistant input produces a confirmation sheet
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test (but after the test had completed):
Bad state: Tried to use AssistantController after `dispose` was called.

Consider checking `mounted`.

When the exception was thrown, this was the stack:
#0      StateNotifier._debugIsMounted.<anonymous closure> (package:state_notifier/state_notifier.dart:175:9)
#1      StateNotifier._debugIsMounted (package:state_notifier/state_notifier.dart:182:6)
#2      StateNotifier.state (package:state_notifier/state_notifier.dart:197:12)
#3      AssistantController._handleUtterance (package:javid_ai/features/assistant/assistant_controller.dart:136:15)
<asynchronous suspension>
#4      AssistantController.submitText (package:javid_ai/features/assistant/assistant_controller.dart:104:5)
<asynchronous suspension>
#5      _AssistantScreenState._submitTyped (package:javid_ai/features/assistant/assistant_screen.dart:63:5)
<asynchronous suspension>
════════════════════════════════════════════════════════════════════════════════════════════════════
00:03 +0 -3: typed assistant input produces a confirmation sheet [E]
  Test failed. See exception logs above.
  The test description was: typed assistant input produces a confirmation sheet
  
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following SqfliteFfiException was thrown running a test (but after the test had completed):
DatabaseException(ffi error: Bad state: This database has already been closed) sql 'INSERT OR
REPLACE INTO notes (id, title, body, category, created_at, updated_at, is_pinned, source) VALUES (?,
?, ?, ?, ?, ?, ?, ?)' args [01a1e9a4-625b-76cb-a66e-c415ca2c1228, تست ویجت, تست ویجت, general,
1794921226843, 1794921226843, 0, voice]

When the exception was thrown, this was the stack:
#0      responseToResultOrThrow (package:sqflite_common_ffi/src/method_call.dart:126:9)
#1      SqfliteIsolate.handle (package:sqflite_common_ffi/src/isolate_io.dart:85:12)
<asynchronous suspension>
#2      _isolateHandle (package:sqflite_common_ffi/src/database_factory_ffi_io.dart:115:10)
<asynchronous suspension>
#3      ffiMethodCallhandleInIsolate (package:sqflite_common_ffi/src/database_factory_ffi_io.dart:67:18)
<asynchronous suspension>
#4      _SqfliteDatabaseFactoryImpl.invokeMethod (package:sqflite_common/src/mixin/factory.dart:22:8)
<asynchronous suspension>
#5      SqfliteDatabaseMixin.txnRawInsert.<anonymous closure> (package:sqflite_common/src/database_mixin.dart:666:14)
<asynchronous suspension>
#6      BasicLock.synchronized (package:synchronized/src/basic_lock.dart:41:16)
<asynchronous suspension>
#7      SqfliteDatabaseMixin.txnSynchronized (package:sqflite_common/src/database_mixin.dart:592:14)
<asynchronous suspension>
#8      NoteService.create (package:javid_ai/services/note_service.dart:36:5)
<asynchronous suspension>
#9      AgentCore.handle.<anonymous closure> (package:javid_ai/features/agent/agent_core.dart:127:28)
<asynchronous suspension>
#10     AssistantController._runTool (package:javid_ai/features/assistant/assistant_controller.dart:166:20)
<asynchronous suspension>
════════════════════════════════════════════════════════════════════════════════════════════════════
  Test failed. See exception logs above.
  The test description was: typed assistant input produces a confirmation sheet
  
00:04 +0 -3: notes created through the agent appear in the notes tab
══╡ EXCEPTION CAUGHT BY WIDGETS ╞═══════════════════════════════════════════════════════════════════
The following message was thrown:
Warning: This application's locale, fa_IR, is not supported by all of its localization delegates.

• A CupertinoLocalizations delegate that supports the fa_IR locale was not found.

If the application is built using GlobalMaterialLocalizations.delegate, consider using
GlobalMaterialLocalizations.delegates (plural) instead, as that will automatically declare the
appropriate Cupertino localizations.

The declared supported locales for this app are: fa_IR

See https://flutter.dev/to/internationalization/ for more information about configuring an app's
locale, supportedLocales, and localizationsDelegates parameters.
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following StateError was thrown running a test:
Bad state: Tried to use AssistantController after `dispose` was called.

Consider checking `mounted`.

When the exception was thrown, this was the stack:
#0      StateNotifier._debugIsMounted.<anonymous closure> (package:state_notifier/state_notifier.dart:175:9)
#1      StateNotifier._debugIsMounted (package:state_notifier/state_notifier.dart:182:6)
#2      StateNotifier.state (package:state_notifier/state_notifier.dart:197:12)
#3      AssistantController._runTool (package:javid_ai/features/assistant/assistant_controller.dart:162:13)
#4      AssistantController._toConfirmation.<anonymous closure> (package:javid_ai/features/assistant/assistant_controller.dart:150:19)
#5      _ConfirmSheet.build.<anonymous closure> (package:javid_ai/features/assistant/confirm_action_sheet.dart:94:45)
#6      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1224:21)
#7      GestureRecognizer.invokeCallback (package:flutter/src/gestures/recognizer.dart:362:24)
#8      TapGestureRecognizer.handleTapUp (package:flutter/src/gestures/tap.dart:758:11)
#9      BaseTapGestureRecognizer._checkUp (package:flutter/src/gestures/tap.dart:383:5)
#10     BaseTapGestureRecognizer.acceptGesture (package:flutter/src/gestures/tap.dart:353:7)
#11     GestureArenaManager.sweep (package:flutter/src/gestures/arena.dart:173:27)
#12     GestureBinding.handleEvent (package:flutter/src/gestures/binding.dart:542:20)
#13     GestureBinding.dispatchEvent (package:flutter/src/gestures/binding.dart:508:22)
#14     RendererBinding.dispatchEvent (package:flutter/src/rendering/binding.dart:473:11)
#15     GestureBinding._handlePointerEventImmediately (package:flutter/src/gestures/binding.dart:447:7)
#16     GestureBinding.handlePointerEvent (package:flutter/src/gestures/binding.dart:404:5)
#17     TestWidgetsFlutterBinding.handlePointerEventForSource.<anonymous closure> (package:flutter_test/src/binding.dart:1571:42)
#18     TestWidgetsFlutterBinding.withPointerEventSource (package:flutter_test/src/binding.dart:1581:11)
#19     TestWidgetsFlutterBinding.handlePointerEventForSource (package:flutter_test/src/binding.dart:1571:5)
#20     WidgetTester.sendEventToBinding.<anonymous closure> (package:flutter_test/src/widget_tester.dart:869:15)
#23     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#24     WidgetTester.sendEventToBinding (package:flutter_test/src/widget_tester.dart:868:27)
#25     TestGesture.up.<anonymous closure> (package:flutter_test/src/test_pointer.dart:587:26)
#28     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#29     TestGesture.up (package:flutter_test/src/test_pointer.dart:580:27)
#30     WidgetController.tapAt.<anonymous closure> (package:flutter_test/src/controller.dart:1155:21)
<asynchronous suspension>
#31     TestAsyncUtils.guard.<anonymous closure> (package:flutter_test/src/test_async_utils.dart:130:27)
<asynchronous suspension>
#32     main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:223:5)
<asynchronous suspension>
#33     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#34     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The test description was:
  notes created through the agent appear in the notes tab
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:04 +0 -4: notes created through the agent appear in the notes tab [E]
  Test failed. See exception logs above.
  The test description was: notes created through the agent appear in the notes tab
  
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test (but after the test had completed):
Expected: an object with length of <1>
  Actual: []
   Which: has length of <0>

When the exception was thrown, this was the stack:
#0      fail (package:matcher/src/expect/expect.dart:187:31)
#1      _expect (package:matcher/src/expect/expect.dart:182:3)
#2      expect (package:matcher/src/expect/expect.dart:65:3)
#3      expect (package:flutter_test/src/widget_tester.dart:473:18)
#4      main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:231:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)
════════════════════════════════════════════════════════════════════════════════════════════════════
  Test failed. See exception logs above.
  The test description was: notes created through the agent appear in the notes tab
  
00:04 +0 -4: (tearDownAll)
00:04 +0 -4: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: navigates through all five tabs
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: notes created through the agent appear in the notes tab
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: typed assistant input produces a confirmation sheet
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
Running Gradle task 'assembleDebug'...                            290.1s
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

> Task :jni:generateDebugAssets UP-TO-DATE
> Task :flutter_secure_storage:generateDebugAssets UP-TO-DATE
> Task :flutter_secure_storage:preBuild UP-TO-DATE
> Task :jni:preBuild UP-TO-DATE
> Task :flutter_secure_storage:preDebugBuild UP-TO-DATE
> Task :jni:preDebugBuild UP-TO-DATE
> Task :app:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :flutter_secure_storage:mergeDebugAssets UP-TO-DATE
> Task :jni_flutter:generateDebugAssets UP-TO-DATE
> Task :jni_flutter:preBuild UP-TO-DATE
> Task :jni_flutter:preDebugBuild UP-TO-DATE
> Task :flutter_tts:generateDebugAssets UP-TO-DATE
> Task :jni:mergeDebugAssets UP-TO-DATE
> Task :flutter_tts:preBuild UP-TO-DATE
> Task :flutter_tts:preDebugBuild UP-TO-DATE
> Task :jni_flutter:mergeDebugAssets UP-TO-DATE
> Task :shared_preferences_android:generateDebugAssets UP-TO-DATE
> Task :shared_preferences_android:preBuild UP-TO-DATE
> Task :permission_handler_android:generateDebugAssets UP-TO-DATE
> Task :permission_handler_android:preBuild UP-TO-DATE
> Task :shared_preferences_android:preDebugBuild UP-TO-DATE
> Task :flutter_tts:mergeDebugAssets UP-TO-DATE
> Task :permission_handler_android:preDebugBuild UP-TO-DATE
> Task :shared_preferences_android:mergeDebugAssets UP-TO-DATE
> Task :speech_to_text:generateDebugAssets UP-TO-DATE
> Task :speech_to_text:preBuild UP-TO-DATE
> Task :speech_to_text:preDebugBuild UP-TO-DATE
> Task :sqflite_android:generateDebugAssets UP-TO-DATE
> Task :sqflite_android:preBuild UP-TO-DATE
> Task :sqflite_android:preDebugBuild UP-TO-DATE
> Task :permission_handler_android:mergeDebugAssets UP-TO-DATE
> Task :url_launcher_android:generateDebugAssets UP-TO-DATE
> Task :url_launcher_android:preBuild UP-TO-DATE
> Task :url_launcher_android:preDebugBuild UP-TO-DATE
> Task :speech_to_text:mergeDebugAssets UP-TO-DATE
> Task :url_launcher_android:mergeDebugAssets UP-TO-DATE
> Task :flutter_secure_storage:processDebugNavigationResources UP-TO-DATE
> Task :sqflite_android:mergeDebugAssets UP-TO-DATE
> Task :flutter_tts:processDebugNavigationResources UP-TO-DATE
> Task :jni_flutter:processDebugNavigationResources UP-TO-DATE
> Task :shared_preferences_android:processDebugNavigationResources UP-TO-DATE
> Task :permission_handler_android:processDebugNavigationResources UP-TO-DATE
> Task :app:cleanMergeDebugAssets
> Task :jni:processDebugNavigationResources UP-TO-DATE
> Task :sqflite_android:processDebugNavigationResources UP-TO-DATE
> Task :flutter_secure_storage:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :url_launcher_android:processDebugNavigationResources UP-TO-DATE
> Task :flutter_tts:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :flutter_secure_storage:generateDebugBuildConfig UP-TO-DATE
> Task :speech_to_text:processDebugNavigationResources UP-TO-DATE
> Task :jni:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni:generateDebugResources UP-TO-DATE
> Task :flutter_secure_storage:generateDebugResources UP-TO-DATE
> Task :flutter_tts:generateDebugResources UP-TO-DATE
> Task :flutter_secure_storage:packageDebugResources UP-TO-DATE
> Task :jni:packageDebugResources UP-TO-DATE
> Task :flutter_tts:packageDebugResources UP-TO-DATE
> Task :flutter_secure_storage:parseDebugLocalResources UP-TO-DATE
> Task :jni:parseDebugLocalResources UP-TO-DATE
> Task :flutter_tts:parseDebugLocalResources UP-TO-DATE
> Task :flutter_secure_storage:generateDebugRFile UP-TO-DATE
> Task :jni:generateDebugRFile UP-TO-DATE
> Task :flutter_tts:generateDebugRFile UP-TO-DATE
> Task :jni:compileDebugKotlin NO-SOURCE
> Task :jni:javaPreCompileDebug UP-TO-DATE
> Task :flutter_secure_storage:compileDebugKotlin NO-SOURCE
> Task :flutter_secure_storage:javaPreCompileDebug UP-TO-DATE
> Task :flutter_secure_storage:compileDebugJavaWithJavac UP-TO-DATE
> Task :flutter_secure_storage:bundleLibCompileToJarDebug UP-TO-DATE
> Task :jni_flutter:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni:compileDebugJavaWithJavac UP-TO-DATE
> Task :jni:bundleLibCompileToJarDebug UP-TO-DATE
> Task :permission_handler_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :jni_flutter:generateDebugResources UP-TO-DATE
> Task :permission_handler_android:generateDebugResources UP-TO-DATE
> Task :jni_flutter:packageDebugResources UP-TO-DATE
> Task :permission_handler_android:packageDebugResources UP-TO-DATE
> Task :jni_flutter:parseDebugLocalResources UP-TO-DATE
> Task :permission_handler_android:parseDebugLocalResources UP-TO-DATE
> Task :flutter_tts:compileDebugKotlin UP-TO-DATE
> Task :jni_flutter:generateDebugRFile UP-TO-DATE
> Task :flutter_tts:javaPreCompileDebug UP-TO-DATE
> Task :flutter_tts:compileDebugJavaWithJavac NO-SOURCE
> Task :flutter_tts:bundleLibCompileToJarDebug UP-TO-DATE
> Task :shared_preferences_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :shared_preferences_android:generateDebugResources UP-TO-DATE
> Task :shared_preferences_android:packageDebugResources UP-TO-DATE
> Task :permission_handler_android:generateDebugRFile UP-TO-DATE
> Task :jni_flutter:compileDebugKotlin NO-SOURCE
> Task :shared_preferences_android:parseDebugLocalResources UP-TO-DATE
> Task :permission_handler_android:compileDebugKotlin NO-SOURCE
> Task :jni_flutter:javaPreCompileDebug UP-TO-DATE
> Task :permission_handler_android:javaPreCompileDebug UP-TO-DATE
> Task :permission_handler_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :permission_handler_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :jni_flutter:compileDebugJavaWithJavac UP-TO-DATE
> Task :speech_to_text:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :speech_to_text:generateDebugResources UP-TO-DATE
> Task :jni_flutter:bundleLibCompileToJarDebug UP-TO-DATE
> Task :sqflite_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :sqflite_android:generateDebugResources UP-TO-DATE
> Task :speech_to_text:packageDebugResources UP-TO-DATE
> Task :speech_to_text:parseDebugLocalResources UP-TO-DATE
> Task :speech_to_text:generateDebugRFile UP-TO-DATE
> Task :sqflite_android:packageDebugResources UP-TO-DATE
> Task :sqflite_android:parseDebugLocalResources UP-TO-DATE
> Task :shared_preferences_android:generateDebugRFile UP-TO-DATE
> Task :sqflite_android:generateDebugRFile UP-TO-DATE
> Task :sqflite_android:compileDebugKotlin NO-SOURCE
> Task :speech_to_text:compileDebugKotlin UP-TO-DATE
> Task :speech_to_text:javaPreCompileDebug UP-TO-DATE
> Task :sqflite_android:javaPreCompileDebug UP-TO-DATE
> Task :speech_to_text:compileDebugJavaWithJavac NO-SOURCE
> Task :speech_to_text:bundleLibCompileToJarDebug UP-TO-DATE
> Task :url_launcher_android:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :url_launcher_android:generateDebugBuildConfig UP-TO-DATE
> Task :url_launcher_android:generateDebugResources UP-TO-DATE
> Task :url_launcher_android:packageDebugResources UP-TO-DATE
> Task :url_launcher_android:parseDebugLocalResources UP-TO-DATE
> Task :url_launcher_android:generateDebugRFile UP-TO-DATE
> Task :sqflite_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :sqflite_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :flutter_secure_storage:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_tts:writeDebugAarMetadata UP-TO-DATE
> Task :jni:writeDebugAarMetadata UP-TO-DATE
> Task :jni_flutter:writeDebugAarMetadata UP-TO-DATE
> Task :shared_preferences_android:compileDebugKotlin UP-TO-DATE
> Task :shared_preferences_android:javaPreCompileDebug UP-TO-DATE
> Task :shared_preferences_android:compileDebugJavaWithJavac NO-SOURCE
> Task :shared_preferences_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :shared_preferences_android:writeDebugAarMetadata UP-TO-DATE
> Task :url_launcher_android:compileDebugKotlin UP-TO-DATE
> Task :url_launcher_android:javaPreCompileDebug UP-TO-DATE
> Task :url_launcher_android:compileDebugJavaWithJavac UP-TO-DATE
> Task :url_launcher_android:bundleLibCompileToJarDebug UP-TO-DATE
> Task :sqflite_android:writeDebugAarMetadata UP-TO-DATE
> Task :url_launcher_android:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_secure_storage:extractDeepLinksDebug UP-TO-DATE
> Task :flutter_secure_storage:processDebugManifest UP-TO-DATE
> Task :flutter_tts:extractDeepLinksDebug UP-TO-DATE
> Task :flutter_tts:processDebugManifest UP-TO-DATE
> Task :jni:extractDeepLinksDebug UP-TO-DATE
> Task :jni:processDebugManifest UP-TO-DATE
> Task :jni_flutter:extractDeepLinksDebug UP-TO-DATE
> Task :jni_flutter:processDebugManifest UP-TO-DATE
> Task :shared_preferences_android:extractDeepLinksDebug UP-TO-DATE
> Task :shared_preferences_android:processDebugManifest UP-TO-DATE
> Task :sqflite_android:extractDeepLinksDebug UP-TO-DATE
> Task :sqflite_android:processDebugManifest UP-TO-DATE
> Task :url_launcher_android:extractDeepLinksDebug UP-TO-DATE
> Task :url_launcher_android:processDebugManifest UP-TO-DATE
> Task :speech_to_text:writeDebugAarMetadata UP-TO-DATE
> Task :permission_handler_android:writeDebugAarMetadata UP-TO-DATE
> Task :flutter_secure_storage:mapDebugSourceSetPaths UP-TO-DATE
> Task :flutter_secure_storage:compileDebugLibraryResources UP-TO-DATE
> Task :permission_handler_android:extractDeepLinksDebug UP-TO-DATE
> Task :speech_to_text:extractDeepLinksDebug UP-TO-DATE
> Task :flutter_tts:mapDebugSourceSetPaths UP-TO-DATE
> Task :permission_handler_android:processDebugManifest UP-TO-DATE
> Task :jni:mapDebugSourceSetPaths UP-TO-DATE
> Task :flutter_tts:compileDebugLibraryResources UP-TO-DATE
> Task :jni:compileDebugLibraryResources UP-TO-DATE
> Task :jni_flutter:mapDebugSourceSetPaths UP-TO-DATE
> Task :jni_flutter:compileDebugLibraryResources UP-TO-DATE
> Task :shared_preferences_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :shared_preferences_android:compileDebugLibraryResources UP-TO-DATE
> Task :sqflite_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :permission_handler_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :sqflite_android:compileDebugLibraryResources UP-TO-DATE
> Task :permission_handler_android:compileDebugLibraryResources UP-TO-DATE
> Task :flutter_secure_storage:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :url_launcher_android:mapDebugSourceSetPaths UP-TO-DATE
> Task :url_launcher_android:compileDebugLibraryResources UP-TO-DATE
> Task :flutter_tts:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :flutter_tts:processDebugJavaRes UP-TO-DATE
> Task :jni:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :flutter_secure_storage:processDebugJavaRes NO-SOURCE
> Task :jni_flutter:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :jni_flutter:processDebugJavaRes NO-SOURCE
> Task :permission_handler_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :jni:processDebugJavaRes NO-SOURCE
> Task :shared_preferences_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :permission_handler_android:processDebugJavaRes NO-SOURCE
> Task :sqflite_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :shared_preferences_android:processDebugJavaRes UP-TO-DATE
> Task :url_launcher_android:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :url_launcher_android:processDebugJavaRes UP-TO-DATE
> Task :flutter_secure_storage:preDebugUnitTestBuild UP-TO-DATE
> Task :sqflite_android:processDebugJavaRes NO-SOURCE
> Task :flutter_tts:preDebugUnitTestBuild UP-TO-DATE
> Task :speech_to_text:processDebugManifest UP-TO-DATE
> Task :speech_to_text:mapDebugSourceSetPaths UP-TO-DATE
> Task :speech_to_text:compileDebugLibraryResources UP-TO-DATE
> Task :speech_to_text:bundleLibRuntimeToJarDebug UP-TO-DATE
> Task :speech_to_text:processDebugJavaRes UP-TO-DATE
> Task :jni:preDebugUnitTestBuild UP-TO-DATE
> Task :jni:generateDebugUnitTestStubRFile
> Task :flutter_secure_storage:javaPreCompileDebugUnitTest FROM-CACHE
> Task :flutter_secure_storage:generateDebugUnitTestStubRFile
> Task :flutter_tts:generateDebugUnitTestStubRFile
> Task :jni:compileDebugUnitTestKotlin NO-SOURCE
> Task :flutter_tts:javaPreCompileDebugUnitTest FROM-CACHE
> Task :flutter_secure_storage:compileDebugUnitTestKotlin NO-SOURCE
> Task :flutter_tts:compileDebugUnitTestKotlin NO-SOURCE
> Task :flutter_secure_storage:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :jni:javaPreCompileDebugUnitTest FROM-CACHE
> Task :flutter_secure_storage:processDebugUnitTestJavaRes NO-SOURCE
> Task :flutter_tts:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :jni:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :flutter_tts:processDebugUnitTestJavaRes NO-SOURCE
> Task :jni:processDebugUnitTestJavaRes NO-SOURCE
> Task :flutter_secure_storage:testDebugUnitTest NO-SOURCE
> Task :jni_flutter:preDebugUnitTestBuild UP-TO-DATE
> Task :jni:testDebugUnitTest NO-SOURCE
> Task :flutter_tts:testDebugUnitTest NO-SOURCE
> Task :permission_handler_android:preDebugUnitTestBuild UP-TO-DATE
> Task :shared_preferences_android:preDebugUnitTestBuild UP-TO-DATE
> Task :permission_handler_android:generateDebugUnitTestStubRFile
> Task :jni_flutter:javaPreCompileDebugUnitTest FROM-CACHE
> Task :permission_handler_android:compileDebugUnitTestKotlin NO-SOURCE
> Task :permission_handler_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :permission_handler_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :permission_handler_android:processDebugUnitTestJavaRes NO-SOURCE
> Task :permission_handler_android:testDebugUnitTest NO-SOURCE
> Task :speech_to_text:preDebugUnitTestBuild UP-TO-DATE
> Task :jni_flutter:generateDebugUnitTestStubRFile
> Task :jni_flutter:compileDebugUnitTestKotlin NO-SOURCE
> Task :jni_flutter:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :jni_flutter:processDebugUnitTestJavaRes NO-SOURCE
> Task :jni_flutter:testDebugUnitTest NO-SOURCE
> Task :speech_to_text:javaPreCompileDebugUnitTest FROM-CACHE
> Task :sqflite_android:preDebugUnitTestBuild UP-TO-DATE
> Task :speech_to_text:generateDebugUnitTestStubRFile
> Task :speech_to_text:compileDebugUnitTestKotlin NO-SOURCE
> Task :speech_to_text:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :speech_to_text:processDebugUnitTestJavaRes NO-SOURCE
> Task :speech_to_text:testDebugUnitTest NO-SOURCE
> Task :url_launcher_android:preDebugUnitTestBuild UP-TO-DATE
> Task :sqflite_android:generateDebugUnitTestStubRFile
> Task :sqflite_android:compileDebugUnitTestKotlin NO-SOURCE
> Task :sqflite_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :sqflite_android:compileDebugUnitTestJavaWithJavac
> Task :sqflite_android:processDebugUnitTestJavaRes NO-SOURCE
> Task :url_launcher_android:checkDebugUnitTestAarMetadata
> Task :url_launcher_android:mapDebugUnitTestSourceSetPaths
> Task :url_launcher_android:generateDebugUnitTestResources FROM-CACHE
> Task :url_launcher_android:mergeDebugUnitTestResources
> Task :shared_preferences_android:checkDebugUnitTestAarMetadata
> Task :shared_preferences_android:mapDebugUnitTestSourceSetPaths
> Task :shared_preferences_android:generateDebugUnitTestResources FROM-CACHE
> Task :url_launcher_android:processDebugUnitTestManifest
> Task :url_launcher_android:processDebugUnitTestResources
> Task :shared_preferences_android:mergeDebugUnitTestResources
> Task :sqflite_android:testDebugUnitTest
> Task :url_launcher_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :url_launcher_android:generateDebugUnitTestAssets UP-TO-DATE
> Task :shared_preferences_android:processDebugUnitTestManifest
> Task :url_launcher_android:mergeDebugUnitTestAssets
> Task :url_launcher_android:packageDebugUnitTestForUnitTest
> Task :url_launcher_android:generateDebugUnitTestConfig
> Task :shared_preferences_android:javaPreCompileDebugUnitTest FROM-CACHE
> Task :shared_preferences_android:generateDebugUnitTestAssets UP-TO-DATE
> Task :shared_preferences_android:mergeDebugUnitTestAssets
> Task :shared_preferences_android:processDebugUnitTestResources
> Task :url_launcher_android:compileDebugUnitTestKotlin
> Task :url_launcher_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :url_launcher_android:processDebugUnitTestJavaRes
> Task :shared_preferences_android:packageDebugUnitTestForUnitTest
> Task :shared_preferences_android:generateDebugUnitTestConfig
> Task :shared_preferences_android:compileDebugUnitTestKotlin
> Task :shared_preferences_android:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :shared_preferences_android:processDebugUnitTestJavaRes
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :shared_preferences_android:testDebugUnitTest

LegacySharedPreferencesTest > executesOnBackgroundThreadSeriallyInFifoOrder STANDARD_ERROR
    WARNING: A Java agent has been loaded dynamically (/home/runner/.gradle/caches/modules-2/files-2.1/net.bytebuddy/byte-buddy-agent/1.18.2/62f38a6faf7f069d661b79a07d566f504b0b20c4/byte-buddy-agent-1.18.2.jar)
    WARNING: If a serviceability tool is in use, please run with -XX:+EnableDynamicAgentLoading to hide this warning
    WARNING: If a serviceability tool is not in use, please run with -Djdk.instrument.traceUsage for more information
    WARNING: Dynamic loading of agents will be disallowed by default in a future release

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

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

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
> Task :app:bundleDebugClassesToCompileJar
> Task :app:bundleDebugClassesToRuntimeJar

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

> Task :app:preDebugUnitTestBuild
> Task :app:javaPreCompileDebugUnitTest FROM-CACHE
> Task :app:processDebugJavaRes UP-TO-DATE

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[30] STANDARD_ERROR
    Mockito is currently self-attaching to enable the inline-mock-maker. This will no longer work in future releases of the JDK. Please add Mockito as an agent to your build as described in Mockito's documentation: https://javadoc.io/doc/org.mockito/mockito-core/latest/org.mockito/org/mockito/Mockito.html#0.3
    WARNING: A Java agent has been loaded dynamically (/tmp/byteBuddyAgent644051859512703304.jar)
    WARNING: If a serviceability tool is in use, please run with -XX:+EnableDynamicAgentLoading to hide this warning
    WARNING: If a serviceability tool is not in use, please run with -Djdk.instrument.traceUsage for more information
    WARNING: Dynamic loading of agents will be disallowed by default in a future release

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :shared_preferences_android:testDebugUnitTest

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

> Task :app:compileDebugUnitTestKotlin
> Task :app:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :app:processDebugUnitTestJavaRes

> Task :url_launcher_android:testDebugUnitTest

UrlLauncherTest > launch_setsRequireNonBrowserWhenRequested[30] PASSED

OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended

> Task :app:testDebugUnitTest

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

BUILD SUCCESSFUL in 1m 21s
219 actionable tasks: 41 executed, 12 from cache, 166 up-to-date
```
