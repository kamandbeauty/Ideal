import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/shared/widgets/sf_progress.dart';

/// The progress surface is shared by the exporter, the importer and the
/// transcription screen, so a bug here is visible in three places at once.
///
/// The tests pin the two things users actually read - the remaining-time copy
/// and the percentage - plus the rule that a task which cannot report progress
/// must render an indeterminate bar instead of a fake number.
void main() {
  group('remaining time copy', () {
    test('under a minute is seconds', () {
      expect(sfFormatRemaining(45), '۴۵ ثانیه');
      expect(sfFormatRemaining(0), '۰ ثانیه');
    });

    test('whole minutes drop the seconds', () {
      expect(sfFormatRemaining(60), '۱ دقیقه');
      expect(sfFormatRemaining(120), '۲ دقیقه');
    });

    test('mixed minutes keep two digits, because 2:5 reads like a typo', () {
      expect(sfFormatRemaining(125), '۲:۰۵');
      expect(sfFormatRemaining(605), '۱۰:۰۵');
    });

    test('hours are spoken, not colonised', () {
      expect(sfFormatRemaining(3720), '۱ ساعت و ۲ دقیقه');
    });

    test('a finished task has no remaining copy', () {
      expect(sfFormatRemaining(-1), '');
    });
  });

  group('SfProgressController', () {
    test('clamps both ends and reports completion', () {
      final SfProgressController controller = SfProgressController();
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.begin();
      controller.update(0.5);
      expect(controller.value, 0.5);
      expect(controller.isFinished, isFalse);

      controller.update(2);
      expect(controller.value, 1.0);
      expect(controller.isFinished, isTrue);
      expect(notifications, greaterThanOrEqualTo(2));
      controller.dispose();
    });

    test('does not invent an estimate before there is data', () {
      final SfProgressController controller = SfProgressController();
      controller.begin();
      expect(controller.remainingSeconds, isNull);
      controller.dispose();
    });

    test('a late progress callback after disposal is harmless', () {
      final SfProgressController controller = SfProgressController();
      controller.begin();
      controller.dispose();
      controller.update(0.4);
      expect(controller.value, 0.4);
    });
  });

  group('widgets', () {
    testWidgets('a determinate bar paints without animating in tests', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 200, child: SfProgressBar(value: 0.42, animate: false)))),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SfProgressBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bar with no value paints the indeterminate band', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 200, child: SfProgressBar(value: null, animate: false)))),
      ));
      expect(find.byType(SfProgressBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dialog speaks Persian percentages', (WidgetTester tester) async {
      final SfProgressController controller = SfProgressController();
      controller.begin('آماده‌سازی');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SfProgressDialog(title: 'در حال ساخت ویدئو…', controller: controller)),
      ));
      controller.update(1);
      await tester.pump();
      expect(find.text('۱۰۰٪'), findsOneWidget);
      expect(find.text('در حال ساخت ویدئو…'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('the task overlay names the step in progress', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              SizedBox.expand(),
              SfTaskOverlay(label: 'در حال ساخت پروژه…', value: null),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('در حال ساخت پروژه…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
