import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/startup_gate.dart';

void main() {
  testWidgets('paints while initialization waits, then mounts application once',
      (tester) async {
    final ready = Completer<Widget>();
    var calls = 0;
    await tester.pumpWidget(StartupGate(
        initialize: (stage) {
          calls++;
          stage('Opening your saved data…');
          return ready.future;
        },
        onClose: () {}));
    await tester.pump();
    expect(find.text('Opening your saved data…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Still getting ready…'), findsOneWidget);
    expect(calls, 1);
    ready.complete(const MaterialApp(home: Text('Ready')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets(
      'deadline failure stays visible after underlying initialization completes',
      (tester) async {
    final ready = Completer<Widget>();
    var closed = false;
    await tester.pumpWidget(StartupGate(
        initialize: (_) => ready.future.timeout(const Duration(seconds: 2)),
        onClose: () => closed = true));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-error')), findsOneWidget);
    ready.complete(const Text('Late app'));
    await tester.pumpAndSettle();
    expect(find.text('Late app'), findsNothing);
    await tester.tap(find.text('Close CloudPOS'));
    expect(closed, isTrue);
  });
}
