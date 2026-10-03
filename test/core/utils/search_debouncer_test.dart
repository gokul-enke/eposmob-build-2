import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/utils/search_debouncer.dart';

// testWidgets runs on a fake clock, so the timers are driven by pump().
void main() {
  testWidgets('schedule runs once, after the last call settles',
      (tester) async {
    var runs = 0;
    final search = SearchDebouncer(() => runs++);

    search.schedule();
    await tester.pump(const Duration(milliseconds: 200));
    search.schedule();
    await tester.pump(const Duration(milliseconds: 299));
    expect(runs, 0);
    expect(search.isPending, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(runs, 1);
    expect(search.isPending, isFalse);
  });

  testWidgets('flush runs now and drops the pending run', (tester) async {
    var runs = 0;
    final search = SearchDebouncer(() => runs++);
    search.schedule();
    search.flush();
    await tester.pump(const Duration(seconds: 1));
    expect(runs, 1);
  });

  testWidgets('flushPending only runs when something was waiting',
      (tester) async {
    var runs = 0;
    final search = SearchDebouncer(() => runs++);
    search.flushPending();
    expect(runs, 0);
    search.schedule();
    search.flushPending();
    expect(runs, 1);
  });

  testWidgets('cancel and dispose drop the pending run', (tester) async {
    var runs = 0;
    final search = SearchDebouncer(() => runs++);
    search.schedule();
    search.cancel();
    search.schedule();
    search.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(runs, 0);
  });
}
