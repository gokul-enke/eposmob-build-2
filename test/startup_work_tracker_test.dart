import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/services/startup_work_tracker.dart';

void main() {
  test('UI timeout does not allow closing storage before source settles',
      () async {
    final tracker = StartupWorkTracker();
    final source = Completer<void>();
    await expectLater(
        tracker
            .run(() => source.future)
            .timeout(const Duration(milliseconds: 1)),
        throwsA(isA<TimeoutException>()));
    var drained = false;
    final shutdown = tracker.stopAndDrain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    expect(() => tracker.run(() async {}), throwsStateError);
    source.complete();
    await shutdown;
    expect(drained, isTrue);
  });

  test('nested box work remains tracked after its parent deadline fails',
      () async {
    final tracker = StartupWorkTracker();
    final box = Completer<void>();
    await expectLater(tracker.run(() async {
      await tracker
          .run(() => box.future)
          .timeout(const Duration(milliseconds: 1));
    }), throwsA(isA<TimeoutException>()));
    var drained = false;
    final shutdown = tracker.stopAndDrain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    box.completeError(StateError('storage unavailable'));
    await shutdown;
    expect(drained, isTrue);
  });
}
