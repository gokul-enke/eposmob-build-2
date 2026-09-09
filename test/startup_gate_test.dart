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

  testWidgets('restart launches once and does not rerun initialization',
      (tester) async {
    var initialized = 0;
    var restarted = 0;
    final restarting = Completer<void>();
    await tester.pumpWidget(StartupGate(
        initialize: (_) async {
          initialized++;
          throw StateError('storage failed');
        },
        onClose: () {},
        onRestart: () {
          restarted++;
          return restarting.future;
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('startup-restart')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('startup-restart')));
    expect(restarted, 1);
    expect(initialized, 1);
    restarting.complete();
    await tester.pumpAndSettle();
    expect(find.text('Restarting CloudPOS…'), findsOneWidget);
  });

  testWidgets('restart launch error leaves close and retry available',
      (tester) async {
    var closed = false;
    await tester.pumpWidget(StartupGate(
        initialize: (_) async => throw StateError('storage failed'),
        onClose: () => closed = true,
        onRestart: () async => throw StateError('launch denied')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('startup-restart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('startup-restart-error')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('startup-restart')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(find.text('Close CloudPOS'));
    await tester.tap(find.text('Close CloudPOS'));
    expect(closed, isTrue);
  });
}
