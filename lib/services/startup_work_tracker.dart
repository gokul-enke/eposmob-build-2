import 'dart:async';

/// Tracks actual work, not the deadline futures presented to the UI. A timed-out
/// Hive open may still own files, so shutdown must wait for its source future.
class StartupWorkTracker {
  final Set<Future<void>> _pending = {};
  bool _stopping = false;
  bool get stopping => _stopping;

  void checkRunning() {
    if (_stopping) throw StateError('CloudPOS is preparing to restart.');
  }

  Future<T> run<T>(Future<T> Function() action) {
    checkRunning();
    final source = Future<T>.sync(action);
    late final Future<void> settled;
    settled = source
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() => _pending.remove(settled));
    _pending.add(settled);
    return source;
  }

  Future<void> stopAndDrain() async {
    _stopping = true;
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}
