import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/presentation/pages/confirmed_orders_page.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
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

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  // Saving waits for the local order to reach disk, which happens in real
  // time outside the fake test clock.
  Future<void> settleSave(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(LocalProductProvider.flushPendingPersistence);
    await tester.pumpAndSettle();
  }

  // Search and status use the shared FilterPanel.
  Finder searchField() => find.descendant(
      of: find.byType(FilterPanel), matching: find.byType(TextField));

  Future<void> pickStatus(
      WidgetTester tester, String current, String next) async {
    await tester.tap(find.text(current));
    await tester.pumpAndSettle();
    await tester.tap(find.text(next).last);
    await tester.pumpAndSettle();
  }

  // Edit JSON, print and remove live in each card's "more" menu.
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
    await pickStatus(tester, 'All (4)', 'Rejected (1)');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    // A hidden order is never synced by surprise.
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Sync shown (1)'), findsOneWidget);
    await pickStatus(tester, 'Rejected (1)', 'All (4)');
    await tester.enterText(searchField(), 'customer 3');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    await tester.enterText(searchField(), 'nothing');
    await tester.pumpAndSettle();
    expect(find.text('No orders match this view.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-order-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Sync all (4)'), findsOneWidget);

    // The header Filters button hides the panel; the filters still apply.
    await pickStatus(tester, 'All (4)', 'Rejected (1)');
    await tester.tap(find.byKey(ConfirmedOrdersPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.byType(FilterPanel), findsNothing);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    await tester.tap(find.byKey(ConfirmedOrdersPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected orders are removed together after one confirmation',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    // qa-1 was sent before (needs review); qa-4 was never sent.
    await tester.tap(find.byKey(const ValueKey('select-order-qa-1')));
    await tester.tap(find.byKey(const ValueKey('select-order-qa-4')));
    await tester.pumpAndSettle();
    expect(find.text('Remove selected (2)'), findsOneWidget);

    // Cancel changes nothing.
    await tester.tap(find.byKey(const ValueKey('remove-selected-orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancel-remove-orders')));
    await tester.pumpAndSettle();
    expect(environment.sync.recordFor('qa-1')!.isDismissed, isFalse);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-selected-orders')));
    await tester.pumpAndSettle();
    expect(find.text('Remove 2 orders from the list?'), findsOneWidget);
    expect(find.textContaining('1 order was sent before'), findsOneWidget);
    expect(find.textContaining('1 order was never sent'), findsOneWidget);
    // Removing needs the operator to confirm they checked Sales.
    expect(enabled(tester, 'confirm-remove-orders'), isFalse);
    await tester.tap(find.byKey(const ValueKey('confirm-remove-checked')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-remove-orders')));
    await settleSave(tester);

    // Sent before: kept for audit, never sent again. Never sent: deleted.
    final dismissed = environment.sync.recordFor('qa-1')!;
    expect(dismissed.isDismissed, isTrue);
    expect(dismissed.attempts.length, 1);
    expect(environment.sync.recordFor('qa-4'), isNull);
    expect(environment.products.findConfirmedOrderById('qa-4'), isNull);
    expect(environment.products.findConfirmedOrderById('qa-1'), isNotNull);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
    expect(find.byKey(const ValueKey('attention-order-qa-4')), findsNothing);
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a receipt conflict says the order was most likely synced',
      (tester) async {
    final record =
        LocalSaleSyncRecord.fromJson(environment.store.rows['qa-1']!);
    await environment.store.write(record.copyWith(attempts: [
      const LocalSaleSyncAttempt(
          number: 1,
          startedAt: '2026-10-14T04:24:00Z',
          endpoint: 'https://qa.invalid/order',
          requestBody: '{}',
          finishedAt: '2026-10-14T04:25:00Z',
          httpStatus: 409,
          responseBody: '{"success":false,"code":"receipt_identity_conflict",'
              '"message":"The receipt number or client sale ID is already '
              'in use."}',
          outcome: 'needs_review'),
    ]).toJson());
    await mount(tester, const Size(1200, 900));
    expect(find.textContaining('The server already has this receipt'),
        findsOneWidget);
    // Other needs-review orders keep the general advice.
    expect(
        find.text(
            'Check Sales and compare the total price. If it is there, remove it; otherwise sync it.'),
        findsOneWidget);
  });

  testWidgets('Log sits beside Sync for orders that have a sync record',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    final log = find.byKey(const ValueKey('sync-log-qa-1'));
    expect(log, findsOneWidget);
    expect(find.descendant(of: log, matching: find.text('Log (1)')),
        findsOneWidget);
    // A legacy order has no sync record, so it has no log.
    expect(find.byKey(const ValueKey('sync-log-qa-4')), findsNothing);
    await tester.tap(log);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phones show search and filters in a collapsible tile',
      (tester) async {
    await mount(tester, const Size(390, 844));
    expect(find.text('Search and filters'), findsOneWidget);
    expect(searchField(), findsNothing);
    await tester.tap(find.text('Search and filters'));
    await tester.pumpAndSettle();
    await tester.enterText(searchField(), 'customer 2');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsNothing);
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

  Future<void> editSaleDetails(WidgetTester tester, String id) async {
    final edit = find.byKey(ValueKey('edit-sale-details-$id'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
  }

  testWidgets('sale details are read-only until Edit, then saved together',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('receipt-value-qa-1')),
            matching: find.text('2-11-261009-0001')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-number-qa-1')), findsNothing);

    await editSaleDetails(tester, 'qa-1');
    final field = find.byKey(const ValueKey('receipt-number-qa-1'));
    expect(
        tester.widget<TextField>(field).controller!.text, '2-11-261009-0001');
    expect(enabled(tester, 'save-sale-details-qa-1'), isFalse);
    // An unsaved edit cannot be synced by surprise.
    expect(enabled(tester, 'sync-order-qa-1'), isFalse);
    await tester.enterText(field, '2-11-261009-0042');
    await tester.pump();
    expect(enabled(tester, 'save-sale-details-qa-1'), isTrue);
    await tester.tap(find.byKey(const ValueKey('save-sale-details-qa-1')));
    await settleSave(tester);
    expect(environment.sync.recordFor('qa-1')!.payload['receipt_number'],
        '2-11-261009-0042');
    expect(environment.sync.recordFor('qa-1')!.payload['issued_at'],
        '2026-10-09T09:15:00');
    expect(environment.sync.recordFor('qa-1')!.attempts.length, 1);
    expect(environment.requests, isEmpty);
    // Reprints and details use the corrected number; the time is unchanged.
    final local = environment.products.findConfirmedOrderById('qa-1')!;
    expect(local.orderNumber, '2-11-261009-0042');
    expect(local.createdAt, '2026-10-09T09:15:00');
    expect(local.total, 18.75);
    expect(field, findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('receipt-value-qa-1')),
            matching: find.text('2-11-261009-0042')),
        findsOneWidget);
    expect(enabled(tester, 'sync-order-qa-1'), isTrue);

    // An empty number is refused in place; Cancel restores the saved one.
    await editSaleDetails(tester, 'qa-1');
    await tester.enterText(field, '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-sale-details-qa-1')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a receipt number.'), findsOneWidget);
    expect(environment.sync.recordFor('qa-1')!.payload['receipt_number'],
        '2-11-261009-0042');
    await tester.tap(find.byKey(const ValueKey('cancel-sale-details-qa-1')));
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('receipt-value-qa-1')),
            matching: find.text('2-11-261009-0042')),
        findsOneWidget);

    await tester.enterText(searchField(), '0042');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attention-order-qa-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('attention-order-qa-2')), findsNothing);
    await tester.enterText(searchField(), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sync-order-qa-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-bulk-sync')));
    await tester.pumpAndSettle();
    expect(environment.requests.single['receipt_number'], '2-11-261009-0042');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a legacy order creates its request', (tester) async {
    await mount(tester, const Size(1200, 900));
    expect(environment.sync.recordFor('qa-4'), isNull);
    await editSaleDetails(tester, 'qa-4');
    await tester.enterText(
        find.byKey(const ValueKey('receipt-number-qa-4')), '2-11-261009-0099');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleSave(tester);
    final record = environment.sync.recordFor('qa-4')!;
    expect(record.surface, LocalSaleSurface.legacy);
    expect(record.payload['receipt_number'], '2-11-261009-0099');
    expect(record.payload['items'], isA<List>());
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale date is picked in edit mode and saved as a UTC instant',
      (tester) async {
    // Pin "now" so the picker range does not depend on the test clock.
    DateHelper.setServerTime(DateTime(2026, 10, 13, 12));
    addTearDown(() => DateHelper.setServerTime(DateTime.now()));
    await mount(tester, const Size(1200, 900));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('sale-time-value-qa-1')),
            matching: find.text('09-10-2026 · 09:15 AM')),
        findsOneWidget);
    await editSaleDetails(tester, 'qa-1');
    final date = find.byKey(const ValueKey('sale-date-qa-1'));
    expect(find.descendant(of: date, matching: find.text('09-10-2026')),
        findsOneWidget);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog), matching: find.text('8')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: date, matching: find.text('08-10-2026')),
        findsOneWidget);
    // Nothing is stored until Save.
    expect(environment.sync.recordFor('qa-1')!.payload['issued_at'],
        '2026-10-09T09:15:00');
    await tester.tap(find.byKey(const ValueKey('save-sale-details-qa-1')));
    await settleSave(tester);
    // 09:15 business time on the 8th; QA has no timezone set, so the
    // IST fallback applies.
    expect(environment.sync.recordFor('qa-1')!.payload['issued_at'],
        startsWith('2026-10-08T03:45:00'));
    expect(
        environment.sync.recordFor('qa-1')!.payload['receipt_number'], isNull);
    final local = environment.products.findConfirmedOrderById('qa-1')!;
    expect(local.createdAt, startsWith('2026-10-08T03:45:00'));
    expect(local.orderNumber, '2-11-261009-0001');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('sale-time-value-qa-1')),
            matching: find.text('08-10-2026 · 09:15 AM')),
        findsOneWidget);
    expect(environment.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queued order waiting behind another send says so',
      (tester) async {
    await mount(tester, const Size(1200, 900));
    const ready = 'Saved on this device and ready to sync.';
    const waiting = 'Waiting for earlier orders to finish sending…';
    // Loading turns leftover queued sales into needs-review, so queue two
    // again: qa-1 sends first (slow fake server) and qa-3 waits behind it.
    await environment.sync.authorizeRetryAfterVerification('qa-1');
    await environment.sync.authorizeRetryAfterVerification('qa-3');
    await tester.pump();
    expect(find.text(ready), findsNWidgets(2));
    final first = environment.sync.submitOnce(
        localOrderId: 'qa-1', accessToken: 'qa-token', tenantKey: 'orders-qa');
    final second = environment.sync.submitOnce(
        localOrderId: 'qa-3', accessToken: 'qa-token', tenantKey: 'orders-qa');
    await tester.pump();
    expect(find.text(waiting), findsOneWidget);
    expect(enabled(tester, 'sync-order-qa-3'), isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await first;
    await second;
    await tester.pumpAndSettle();
    expect(find.text(waiting), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
