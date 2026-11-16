import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable clock: tests freeze time, production uses the wall clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// A value that changes once per minute so date-sensitive widgets refresh
/// (greeting, "today" lists) without a per-frame timer.
final minuteTickerProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream<DateTime>.periodic(const Duration(seconds: 30), (_) => clock());
});
