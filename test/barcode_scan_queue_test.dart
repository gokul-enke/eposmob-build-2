import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/barcode_scan_queue.dart';

void main() {
  group('BarcodeScanQueue', () {
    test('processes 10 barcodes in original order even when processor is slow',
        () async {
      final processed = <String>[];

      Future<void> slowProcessor(String barcode) async {
        // Simulate async work (e.g. await product lookup).
        await Future<void>.delayed(const Duration(milliseconds: 5));
        processed.add(barcode);
      }

      final queue = BarcodeScanQueue(slowProcessor);

      // Enqueue all 10 barcodes "simultaneously" (before any processing finishes).
      for (var i = 1; i <= 10; i++) {
        queue.enqueue('BARCODE_$i');
      }

      // Wait until the queue drains.
      await queue.idle;

      expect(processed.length, equals(10));
      expect(
        processed,
        equals(List.generate(10, (i) => 'BARCODE_${i + 1}')),
      );
    });

    test('a processor that throws on one barcode does not block later ones',
        () async {
      final processed = <String>[];

      Future<void> faultyProcessor(String barcode) async {
        if (barcode == 'BAD') {
          throw Exception('simulated processor failure');
        }
        processed.add(barcode);
      }

      final queue = BarcodeScanQueue(faultyProcessor);

      queue.enqueue('GOOD_1');
      queue.enqueue('BAD');
      queue.enqueue('GOOD_2');
      queue.enqueue('GOOD_3');

      await queue.idle;

      // The three good barcodes must have been processed; BAD is skipped.
      expect(processed, equals(['GOOD_1', 'GOOD_2', 'GOOD_3']));
    });

    test('empty and whitespace-only strings are ignored', () async {
      final processed = <String>[];

      final queue = BarcodeScanQueue((b) async => processed.add(b));

      queue.enqueue('');
      queue.enqueue('   ');
      queue.enqueue('\t');
      queue.enqueue('REAL_BARCODE');
      queue.enqueue('');

      await queue.idle;

      expect(processed, equals(['REAL_BARCODE']));
    });

    test('non-empty barcodes are never dropped', () async {
      final processed = <String>[];
      final barcodes = List.generate(20, (i) => 'BC_$i');

      // Processor with variable async delay to stress ordering.
      Future<void> processor(String barcode) async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        processed.add(barcode);
      }

      final queue = BarcodeScanQueue(processor);
      for (final b in barcodes) {
        queue.enqueue(b);
      }

      await queue.idle;

      expect(processed.length, equals(20));
      // All present, no duplicates, none dropped.
      expect(processed.toSet(), equals(barcodes.toSet()));
    });

    test('order is preserved when barcodes are enqueued during in-flight processing',
        () async {
      final processed = <String>[];
      final completer = Completer<void>();

      Future<void> blockingProcessor(String barcode) async {
        if (barcode == 'FIRST') {
          // Block until we signal, giving us time to enqueue more.
          await completer.future;
        }
        processed.add(barcode);
      }

      final queue = BarcodeScanQueue(blockingProcessor);

      // Enqueue 'FIRST' — this starts draining but blocks on the completer.
      queue.enqueue('FIRST');

      // Give the drain loop a chance to pick up FIRST and await the completer.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Enqueue more while FIRST is still in flight.
      queue.enqueue('SECOND');
      queue.enqueue('THIRD');

      // Unblock FIRST.
      completer.complete();

      await queue.idle;

      expect(processed, equals(['FIRST', 'SECOND', 'THIRD']));
    });

    test('idle future completes immediately when queue is already empty',
        () async {
      final queue = BarcodeScanQueue((_) async {});
      // Queue is empty and not draining, so idle should resolve right away.
      await queue.idle.timeout(const Duration(milliseconds: 50));
    });

    test('multiple sequential enqueue batches all complete correctly', () async {
      final processed = <String>[];

      final queue = BarcodeScanQueue((b) async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        processed.add(b);
      });

      // First batch
      queue.enqueue('A1');
      queue.enqueue('A2');
      await queue.idle;

      // Second batch after queue has gone idle
      queue.enqueue('B1');
      queue.enqueue('B2');
      await queue.idle;

      expect(processed, equals(['A1', 'A2', 'B1', 'B2']));
    });
  });
}
