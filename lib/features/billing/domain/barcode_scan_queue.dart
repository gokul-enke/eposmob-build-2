import 'dart:async';
import 'dart:collection';

/// A FIFO queue that serialises barcode processing so rapid scanner bursts
/// never drop events.
///
/// Usage:
/// ```dart
/// final queue = BarcodeScanQueue(processBarcode);
/// queue.enqueue(barcode); // call from stream listener
/// ```
///
/// Design invariants:
/// - Empty / whitespace-only barcodes are silently ignored.
/// - Barcodes are processed one at a time, in enqueue order.
/// - The processor is `await`-ed for each item before the next starts.
/// - A processor that throws does NOT block later items; the error is swallowed
///   (printed in debug mode) and the queue continues.
/// - No Flutter / BuildContext dependency — pass the processor as a closure.
///
/// Mirror of [EmbeddedBarcode]: pure Dart, no Flutter imports, hermetically
/// testable.
class BarcodeScanQueue {
  BarcodeScanQueue(this._processor);

  final Future<void> Function(String barcode) _processor;

  final Queue<String> _queue = Queue<String>();
  bool _draining = false;

  // Completer that resolves when the queue becomes idle (empty + not draining).
  // Used by tests to await completion without polling.
  Completer<void>? _idleCompleter;

  /// Enqueues [barcode] for processing.
  ///
  /// Empty / whitespace-only strings are ignored.
  /// If the queue is currently idle, starts the drain loop immediately.
  void enqueue(String barcode) {
    if (barcode.trim().isEmpty) return;
    _queue.addLast(barcode);
    _ensureDraining();
  }

  /// Returns a [Future] that completes when the queue is idle (no items
  /// pending and no item currently being processed).
  ///
  /// If the queue is already idle, the returned future completes immediately.
  /// Useful in tests to await full processing of a batch.
  Future<void> get idle {
    if (!_draining && _queue.isEmpty) return Future.value();
    _idleCompleter ??= Completer<void>();
    return _idleCompleter!.future;
  }

  void _ensureDraining() {
    if (_draining) return;
    _draining = true;
    _drain();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final barcode = _queue.removeFirst();
      try {
        await _processor(barcode);
      } catch (e, st) {
        // Log the error but keep draining — one bad scan must not block others.
        // ignore: avoid_print
        print('[BarcodeScanQueue] processor error for "$barcode": $e\n$st');
      }
    }
    _draining = false;
    // Notify any waiters that the queue is now idle.
    final completer = _idleCompleter;
    _idleCompleter = null;
    completer?.complete();
  }
}
