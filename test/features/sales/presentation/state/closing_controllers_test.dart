import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/presentation/state/daily_close_list_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/open_shift_form_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/open_shift_form_ports.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';

class Auth extends Fake implements AuthModel {
  @override
  String? get token => 'token';
}

class Master extends Fake implements MasterDataProvider {}

class Store extends Fake implements StoreSessionProvider {}

class Sales extends Fake implements SalesProvider {
  int calls = 0;
  final completion = Completer<bool>();
  @override
  Future<bool> openShiftApi(
      {required String accessToken,
      required int storeId,
      required String shiftName,
      required String businessDate,
      required String openingDate,
      required String openingTime,
      required double openingCashInHand,
      required List<Map<String, dynamic>> openingCashBreakdown,
      String notes = ''}) {
    calls++;
    return completion.future;
  }
}

void main() {
  test(
      'closing query is captured per request and old completion cannot clear loading',
      () async {
    final requests = <DailyCloseListRequest>[];
    final results = <Completer<void>>[];
    var pendingCalls = 0;
    final controller = DailyCloseListController(
        request: (page, date, user) => DailyCloseListRequest(
            token: 't', storeId: 7, userId: user?.id, date: date, page: page),
        fetch: (q) {
          requests.add(q);
          final c = Completer<void>();
          results.add(c);
          return c.future;
        },
        fetchPending: (_) async {
          pendingCalls++;
          return null;
        });
    controller.dateController.text = '2026-10-01';
    final old = controller.load(page: 2);
    controller.dateController.text = '2026-10-05';
    final current = controller.load(page: 3);
    results.first.complete();
    await old;
    expect(controller.loading, true);
    expect(pendingCalls, 0);
    results.last.complete();
    await current;
    expect(controller.loading, false);
    expect(pendingCalls, 1);
    expect(requests.map((r) => r.date), ['2026-10-01', '2026-10-05']);
    final late = controller.load();
    controller.dispose();
    results.last.complete();
    await late;
    expect(pendingCalls, 1);
  });
  test('detail rejects old answers and ignores completion after disposal',
      () async {
    final answers = <Completer<dynamic>>[];
    final controller = SalesOrderDetailController(fetch: () {
      final c = Completer<dynamic>();
      answers.add(c);
      return c.future;
    });
    final old = controller.load();
    final current = controller.load();
    answers.last.complete({'status': 'failed', 'message': 'current'});
    await current;
    answers.first.complete({'status': 'failed', 'message': 'old'});
    await old;
    expect(controller.orderNumber, 'current');
    expect(controller.loading, false);
    final late = controller.load();
    controller.dispose();
    answers.last.complete({'status': 'failed', 'message': 'late'});
    await late;
    expect(controller.orderNumber, 'current');
  });
  test('Open Shift does not submit twice or close a disposed dialog', () async {
    final sales = Sales();
    var closed = 0;
    final controller = OpenShiftFormController(
        ports: OpenShiftFormPorts(
            master: Master(), auth: Auth(), store: Store(), sales: sales),
        onCompleted: () => closed++);
    controller.openingTimeController.text = '08:00:00';
    final first = controller.saveOpeningDraft();
    await controller.saveOpeningDraft();
    expect(sales.calls, 1);
    expect(controller.isLoading, true);
    controller.dispose();
    sales.completion.complete(true);
    await first;
    expect(closed, 0);
  });
}
