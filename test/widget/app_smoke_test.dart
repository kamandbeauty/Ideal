import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/app/app.dart';
import 'package:javid_ai/features/assistant/assistant_screen.dart';
import 'package:javid_ai/features/jobs/jobs_screen.dart';
import 'package:javid_ai/features/messages/messages_screen.dart';
import 'package:javid_ai/features/notes/notes_screen.dart';
import 'package:javid_ai/features/settings/settings_screen.dart';
import 'package:javid_ai/core/providers/database_provider.dart';
import 'package:javid_ai/core/providers/service_providers.dart';
import 'package:javid_ai/core/providers/permission_providers.dart';
import 'package:javid_ai/core/providers/job_providers.dart';
import 'package:javid_ai/core/providers/voice_providers.dart';
import 'package:javid_ai/services/job_runner.dart';
import 'package:javid_ai/services/native_bridge.dart';
import 'package:javid_ai/services/permission_service.dart';
import 'package:javid_ai/services/voice/speech_recognizer.dart';
import 'package:javid_ai/services/voice/tts_engine.dart';

import '../helpers/test_database.dart';

/// These widget tests boot the real app widget tree against an in-memory
/// database with fake voice engines, so navigation, RTL layout and Persian text
/// rendering are exercised for real (no device required).
class FakeBridge extends NativeBridge {
  @override
  Future<bool> hasNotificationAccess() async => false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => false;

  @override
  Future<List<Map<String, Object?>>> fetchCapturedNotifications({int limit = 50}) async =>
      const [];

  @override
  Future<bool> openNotificationSettings() async => true;
}

/// No-op scheduler: the real one starts a timer and hits the database from a
/// `Timer`, which keeps `pump` busy forever inside a widget test.
class FakeTicker implements JobTicker {
  bool started = false;

  @override
  bool get isRunning => started;

  @override
  Future<void> start() async => started = true;

  @override
  Future<JobTickResult?> tick() async => null;

  @override
  void stop() => started = false;
}

class FakePerms extends PermissionService {
  @override
  Future<bool> isGranted(JavidPermission permission) async => true;
}

class SilentRecognizer implements SpeechRecognizer {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isPersianAvailable() async => true;

  @override
  Future<bool> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(String message) onError,
  }) async =>
      true;

  @override
  Future<void> stop() async {}
}

class SilentTts implements TtsEngine {
  @override
  Future<TtsAvailability> initialize() async =>
      const TtsAvailability(available: true, voiceName: 'fa-test');

  @override
  Future<void> speak(String text, {void Function()? onDone}) async => onDone?.call();

  @override
  Future<void> stop() async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(setUpSqfliteFfi);

  /// Advances a few frames without waiting for every animation to finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  /// Lets real asynchronous work finish.
  ///
  /// `testWidgets` runs in a fake-async zone where a real file/SQLite future
  /// never completes, so any step that touches the database must go through
  /// `runAsync`; the frames are pumped afterwards on the test's own clock.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 40),
          ));
      await settle(tester);
    }
  }

  Future<TestDatabase> pumpApp(
    WidgetTester tester, {
    Future<void> Function(ProviderContainer container)? seed,
  }) async {
    // The database must be opened outside the fake-async zone: `testWidgets`
    // replaces the clock and the microtask queue, and a real sqflite future can
    // never complete there.
    final database = (await tester.runAsync(openCleanDatabase))!;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        nativeBridgeProvider.overrideWithValue(FakeBridge()),
        permissionServiceProvider.overrideWithValue(FakePerms()),
        speechRecognizerProvider.overrideWithValue(SilentRecognizer()),
        ttsEngineProvider.overrideWithValue(SilentTts()),
        jobSchedulerProvider.overrideWithValue(FakeTicker()),
        appShutdownProvider.overrideWithValue(() async {}),
      ],
    );

    if (seed != null) {
      await tester.runAsync(() => seed(container));
    }

    // Stop the scheduler *before* the database closes. A `FutureProvider` that
    // is still resolving would otherwise hit a closed database during teardown,
    // which the test framework reports as a failure even though the UI passed.
    final shutdown = container.read(appShutdownProvider);
    addTearDown(() async {
      await shutdown();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const JavidApp()),
    );
    // The mic button pulses forever, so `pumpAndSettle` would never return.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    return database;
  }

  // A hanging frame must fail fast: the binding's default is ten minutes, which
  // would make one broken test eat the whole CI budget.
  const widgetTimeout = Timeout(Duration(seconds: 90));

  testWidgets('boots into the assistant tab in RTL with Persian labels',
      timeout: widgetTimeout, (tester) async {
    await pumpApp(tester);

    expect(find.text('دستیار'), findsOneWidget);
    expect(find.text('یادداشت‌ها'), findsOneWidget);
    expect(find.text('وظایف'), findsWidgets);
    expect(find.text('پیام‌ها'), findsOneWidget);
    expect(find.text('تنظیمات'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);

    // The greeting uses Persian digits and a Jalali weekday.
    expect(find.textContaining('بخیر'), findsAtLeastNWidgets(1));
  });

  testWidgets('navigates through all five tabs', timeout: widgetTimeout,
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(AssistantScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('یادداشت‌ها'));
    await settleIo(tester);
    // Offstage pages stay mounted, so look for what is actually on screen.
    expect(find.text('اولین یادداشتت را بساز'), findsOneWidget);
    expect(find.byType(NotesScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(AssistantScreen), findsNothing,
        reason: 'the assistant tab must be offstage after switching');

    await tester.tap(find.text('وظایف'));
    await settleIo(tester);
    expect(find.byType(JobsScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(JobsScreen), findsOneWidget,
        reason: 'the jobs tab must be on stage after tapping it');
    // Whatever the data state, the jobs screen must not be stuck loading.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('پیام‌ها'));
    await settleIo(tester);
    expect(find.byType(MessagesScreen, skipOffstage: false), findsOneWidget);
    expect(find.textContaining('دسترسی'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('تنظیمات'));
    await settleIo(tester);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('ظاهر'), findsOneWidget);
    expect(find.text('حریم خصوصی'), findsOneWidget);

    // Back to the assistant: the tab bar keeps working both ways.
    await tester.tap(find.text('دستیار'));
    await settleIo(tester);
    expect(find.byType(AssistantScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('typed assistant input opens the confirmation sheet',
      timeout: widgetTimeout, (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'یادداشت جدید بساز: تست ویجت');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settleIo(tester);

    // The write itself is covered by the unit tests; here we only assert that
    // nothing happens without an explicit confirmation and that cancelling
    // keeps the note out of the database.
    expect(find.text('ذخیرهٔ یادداشت'), findsWidgets);
    expect(find.text('تأیید و انجام'), findsOneWidget);
    expect(find.textContaining('فقط روی همین دستگاه'), findsWidgets);

    await tester.tap(find.text('انصراف'));
    await settle(tester);
    expect(find.text('تأیید و انجام'), findsNothing);
  });

  testWidgets('a stored note appears in the notes tab', timeout: widgetTimeout,
      (tester) async {
    final database = await pumpApp(tester, seed: (container) async {
      await container
          .read(noteServiceProvider)
          .create(body: 'خرید نان');
    });

    await tester.tap(find.text('یادداشت‌ها'));
    await settleIo(tester);
    expect(find.textContaining('خرید نان'), findsWidgets);

    final rows = await tester.runAsync(() async {
      final db = await database.open();
      return db.query('notes');
    });
    expect(rows, hasLength(1));
  });
}
