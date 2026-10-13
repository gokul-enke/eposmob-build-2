import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/presentation/pages/confirmed_orders_page.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import '../../../tool/qa_confirmed_orders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OrdersQaEnvironment environment;

  setUp(() async {
    environment = OrdersQaEnvironment()
      ..delay = const Duration(milliseconds: 100);
    await environment.initialize();
  });
  tearDown(() => environment.dispose());

  Future<void> mount(WidgetTester tester, Size size,
      {double textScale = 1}) async {
    environment.sync.dispose();
    environment.resetSync();
    await environment.sync.hydrate();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(environment.wrap(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      home: const ConfirmedOrdersPage(),
    )));
    await tester.pumpAndSettle();
  }

  // Edit JSON, log, print and remove live in each card's "more" menu.
  Future<void> openActions(WidgetTester tester, String id) async {
    final menu = find.byKey(ValueKey('order-actions-$id'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }

  testWidgets('individual selection, select all, indeterminate and clear work',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-order-qa-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('select-all-orders')))
            .value,
        isNull);
    await tester.tap(find.byKey(const ValueKey('select-all-orders')));
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-order-selection')));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'bulk sync continues after rejection and unknown outcome, including legacy',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    await tester.tap(find.byKey(const ValueKey('sync-all-orders')));
    await tester.pumpAndSettle();
    expect(environment.requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey('confirm-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests.length, 4);
    expect(
        environment.sync.recordFor('qa-1')!.state, LocalSaleSyncState.synced);
    expect(
        environment.sync.recordFor('qa-2')!.state, LocalSaleSyncState.rejected);
    expect(environment.sync.recordFor('qa-3')!.state,
        LocalSaleSyncState.needsReview);
    expect(
        environment.sync.recordFor('qa-4')!.state, LocalSaleSyncState.synced);
    expect(find.textContaining('2 synced · 1 rejected · 1 need review'),
        findsOneWidget);
    expect(find.text('Sync all (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'JSON validation, formatting and save feed the next individual sync',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    await openActions(tester, 'qa-1');
    await tester.tap(find.byKey(const ValueKey('edit-request-qa-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sale-request-json')), '{"order_id": }');
    await tester.tap(find.byKey(const ValueKey('save-request-json')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid JSON on line 1'), findsOneWidget);
    expect(environment.sync.recordFor('qa-1')!.payload['order_id'], 80);
    await tester.enterText(
        find.byKey(const ValueKey('sale-request-json')), '[1,2]');
    await tester.tap(find.byKey(const ValueKey('save-request-json')));
    await tester.pumpAndSettle();
    expect(find.textContaining('non-empty JSON object'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sale-request-json')),
        '{"order_id":81,"shipped_id":99,"issued_at":"2026-10-08T10:00:00Z"}');
    await tester.tap(find.byKey(const ValueKey('format-request-json')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('sale-request-json')))
            .controller!
            .text,
        contains('\n'));
    await tester.tap(find.byKey(const ValueKey('save-request-json')));
    await tester.pumpAndSettle();
    expect(environment.sync.recordFor('qa-1')!.payload['shipped_id'], 99);
    expect(environment.sync.recordFor('qa-1')!.attempts.length, 1);
    expect(environment.requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey('sync-order-qa-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests.single['shipped_id'], 99);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'edited legacy order stays deletable and still asks for verification',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    await openActions(tester, 'qa-4');
    await tester.tap(find.byKey(const ValueKey('edit-request-qa-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-request-json')));
    await tester.pumpAndSettle();
    final record = environment.sync.recordFor('qa-4')!;
    expect(record.surface, LocalSaleSurface.legacy);
    expect(record.isUnsentLegacy, isTrue);
    // Let the "Request saved" toast clear; it covers the bottom card row.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await openActions(tester, 'qa-4');
    final remove = find.byKey(const ValueKey('remove-order-qa-4'));
    expect(remove, findsOneWidget);
    expect(find.descendant(of: remove, matching: find.text('Delete')),
        findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-order-qa-4')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('bulk-sync-verify-notice')), findsOneWidget);
    expect(find.text('Verified — Sync'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single rejected order dialog shows the rejection reason',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    expect(find.text('Retry sync'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sync-order-qa-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bulk-sync-rejected-notice')),
        findsOneWidget);
    expect(find.textContaining('Invalid shipped ID'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('cancel-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests, isEmpty);
  });

  testWidgets('status filters and search narrow cards, selection and sync',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    await tester.tap(find.byKey(const ValueKey('select-order-qa-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-rejected')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    // A hidden order is never synced by surprise.
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Sync shown (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-all')));
    await tester.enterText(
        find.byKey(const ValueKey('search-attention-orders')), 'customer 3');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('search-attention-orders')), 'nothing');
    await tester.pumpAndSettle();
    expect(find.text('No orders match this view.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-order-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Sync all (4)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch clears selection and the result banner can be dismissed',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    await tester.tap(find.byKey(const ValueKey('select-order-qa-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-selected-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-bulk-sync')));
    await tester.pumpAndSettle();
    expect(
        environment.sync.recordFor('qa-2')!.state, LocalSaleSyncState.rejected);
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('bulk-sync-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dismiss-bulk-sync-result')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bulk-sync-result')), findsNothing);
  });

  for (final width in [320.0, 360.0, 768.0, 1920.0]) {
    testWidgets('page and JSON editor fit width $width with larger text',
        (tester) async {
      await mount(tester, Size(width, 800), textScale: 1.3);
      expect(find.text('Sync attention'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await openActions(tester, 'qa-1');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('edit-request-qa-1')));
      await tester.pumpAndSettle();
      expect(find.text('Edit request JSON'), findsOneWidget);
      expect(find.byKey(const ValueKey('save-request-json')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('request-editor-close')));
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
      'small phone editor keeps save and errors visible above the keyboard',
      (tester) async {
    await mount(tester, const Size(320, 568));
    await openActions(tester, 'qa-1');
    await tester.tap(find.byKey(const ValueKey('edit-request-qa-1')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sale-request-json')), '{');
    await tester.tap(find.byKey(const ValueKey('save-request-json')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invalid JSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final saveRect =
        tester.getRect(find.byKey(const ValueKey('save-request-json')));
    expect(saveRect.bottom, lessThanOrEqualTo(288));
  });

  testWidgets('receipt number edits on the card feed search and the next sync',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    final field = find.byKey(const ValueKey('receipt-number-qa-1'));
    expect(
        tester.widget<TextField>(field).controller!.text, '2-11-261009-0001');
    await tester.enterText(field, '2-11-261009-0042');
    await tester.pump();
    expect(find.byKey(const ValueKey('save-receipt-qa-1')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(environment.sync.recordFor('qa-1')!.payload['receipt_number'],
        '2-11-261009-0042');
    expect(environment.sync.recordFor('qa-1')!.attempts.length, 1);
    expect(environment.requests, isEmpty);

    // An empty number is refused and the saved one comes back.
    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(field).controller!.text, '2-11-261009-0042');
    expect(environment.sync.recordFor('qa-1')!.payload['receipt_number'],
        '2-11-261009-0042');

    await tester.enterText(
        find.byKey(const ValueKey('search-attention-orders')), '0042');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('search-attention-orders')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sync-order-qa-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests.single['receipt_number'], '2-11-261009-0042');
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt number edit on a legacy order creates its request',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    expect(environment.sync.recordFor('qa-4'), isNull);
    final field = find.byKey(const ValueKey('receipt-number-qa-4'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '2-11-261009-0099');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final record = environment.sync.recordFor('qa-4')!;
    expect(record.surface, LocalSaleSurface.legacy);
    expect(record.payload['receipt_number'], '2-11-261009-0099');
    expect(record.payload['items'], isA<List>());
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale date is picked on the card and saved as a UTC instant',
      (tester) async {
    // Pin "now" so the picker range does not depend on the test clock.
    DateHelper.setServerTime(DateTime(2026, 10, 13, 12));
    addTearDown(() => DateHelper.setServerTime(DateTime.now()));
    await mount(tester, const Size(1200, 900));
    final date = find.byKey(const ValueKey('sale-date-qa-1'));
    expect(find.descendant(of: date, matching: find.text('09-10-2026')),
        findsOneWidget);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog), matching: find.text('8')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 09:15 business time on the 8th; QA has no timezone set, so the
    // IST fallback applies.
    expect(environment.sync.recordFor('qa-1')!.payload['issued_at'],
        startsWith('2026-10-08T03:45:00'));
    expect(find.descendant(of: date, matching: find.text('08-10-2026')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('sale-time-qa-1')),
            matching: find.text('09:15 AM')),
        findsOneWidget);
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
