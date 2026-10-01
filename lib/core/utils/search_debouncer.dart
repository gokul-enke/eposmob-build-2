import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs a search after typing pauses, with a way to run it now (Enter,
/// export) or drop the pending one (reset).
///
/// ```dart
/// final _search = SearchDebouncer(_applyFilters);
/// FilterPanel(onSearch: _search.schedule, onSubmit: _search.flush, ...);
/// // before exporting: _search.flush();
/// // in dispose(): _search.dispose();
/// ```
class SearchDebouncer {
  SearchDebouncer(this._action,
      {this.delay = const Duration(milliseconds: 300)});

  final VoidCallback _action;
  final Duration delay;
  Timer? _timer;

  /// Whether a search is waiting to run.
  bool get isPending => _timer?.isActive ?? false;

  /// Restarts the wait; the search runs [delay] after the last call.
  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, _action);
  }

  /// Runs the search now and drops the pending one.
  void flush() {
    _timer?.cancel();
    _timer = null;
    _action();
  }

  /// Runs the search now only if one was waiting (e.g. before an export
  /// that must see the latest input).
  void flushPending() {
    if (isPending) flush();
  }

  /// Drops the pending search without running it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
