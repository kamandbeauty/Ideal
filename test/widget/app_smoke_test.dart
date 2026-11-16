import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/app/app.dart';
import 'package:javid_ai/core/providers/database_provider.dart';
import 'package:javid_ai/core/providers/permission_providers.dart';
import 'package:javid_ai/core/providers/voice_providers.dart';
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

  Future<TestDatabase> pumpApp(WidgetTester tester) async {
    final database = await openCleanDatabase();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        nativeBridgeProvider.overrideWithValue(FakeBridge()),
        permissionServiceProvider.overrideWithValue(FakePerms()),
        speechRecognizerProvider.overrideWithValue(SilentRecognizer()),
        ttsEngineProvider.overrideWithValue(SilentTts()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const JavidApp()),
    );
    await tester.pumpAndSettle();
    return database;
  }

  testWidgets('boots into the assistant tab in RTL with Persian labels',
      (tester) async {
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
    expect(find.textContaining('بخیر'), findsWidgets);
  });

  testWidgets('navigates through all five tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('یادداشت‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('اولین یادداشتت را بساز'), findsOneWidget);

    await tester.tap(find.text('وظایف'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز وظیفه‌ای نداری'), findsOneWidget);

    await tester.tap(find.text('پیام‌ها'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تاریخچهٔ کامل چت'), findsOneWidget);

    await tester.tap(find.text('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.text('ظاهر'), findsOneWidget);
    expect(find.text('هوش مصنوعی'), findsWidgets);
    expect(find.text('حریم خصوصی'), findsOneWidget);
  });

  testWidgets('typed assistant input produces a confirmation sheet',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'یادداشت جدید بساز: تست ویجت');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('ذخیرهٔ یادداشت'), findsWidgets);
    expect(find.text('تأیید و انجام'), findsOneWidget);

    await tester.tap(find.text('تأیید و انجام'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ذخیره شد'), findsWidgets);
  });

  testWidgets('notes created through the agent appear in the notes tab',
      (tester) async {
    final database = await pumpApp(tester);
    // Wait for bootstrap writes to settle.
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, 'یادداشت جدید بساز: خرید نان');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأیید و انجام'));
    await tester.pumpAndSettle();

    final rows = await (await database.open()).query('notes');
    expect(rows, hasLength(1));
    expect(rows.single['body'], contains('خرید نان'));

    await tester.tap(find.text('یادداشت‌ها'));
    await tester.pumpAndSettle();
    expect(find.textContaining('خرید نان'), findsWidgets);
  });
}
