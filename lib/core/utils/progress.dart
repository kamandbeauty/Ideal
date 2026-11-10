/// The progress contract shared by long-running work (imports, exports) and
/// the UI that renders it. Kept in `core` so services can report progress
/// without depending on widgets.
library;

/// Reports progress of a long-running task.
///
/// [fraction] is 0..1 when known, or `null` while the amount of work is not
/// measurable yet (indeterminate). [detail] is an optional one-line status
/// (current file name, phase label, …).
typedef HeroReport = void Function(double? fraction, {String? detail});

/// Cooperative cancellation for hero progress tasks. Tasks should call
/// [check] at their natural boundaries (between files, between frames).
class HeroToken {
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() => _cancelled = true;

  /// Throws [HeroCancelled] once [cancel] has been called.
  void check() {
    if (_cancelled) throw const HeroCancelled();
  }
}

/// Thrown by a task that was cancelled through its [HeroToken].
class HeroCancelled implements Exception {
  const HeroCancelled();

  @override
  String toString() => 'HeroCancelled';
}
