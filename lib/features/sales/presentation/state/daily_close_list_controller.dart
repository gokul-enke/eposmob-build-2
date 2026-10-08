import 'package:flutter/widgets.dart';
import 'package:pos_machine/models/sales_executive.dart';

import '../../domain/models/day_close_pending_status.dart';

class DailyCloseListRequest {
  const DailyCloseListRequest(
      {required this.token,
      required this.storeId,
      required this.userId,
      required this.date,
      required this.page});
  final String token;
  final int storeId;
  final int? userId;
  final String? date;
  final int page;
}

class DailyCloseListController extends ChangeNotifier {
  DailyCloseListController(
      {required this.request, required this.fetch, this.fetchPending});
  final DailyCloseListRequest Function(int, String?, SalesExecutive?) request;
  final Future<void> Function(DailyCloseListRequest) fetch;
  final Future<DayClosePendingStatus?> Function(DailyCloseListRequest)?
      fetchPending;
  final dateController = TextEditingController();
  DateTime? selectedDate;
  Key calendarPickerKey = UniqueKey();
  SalesExecutive? selectedExecutive;
  bool loading = false;
  DayClosePendingStatus? pendingStatus;
  bool _disposed = false;
  int _generation = 0;
  void update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  Future<void> load({int page = 1}) async {
    if (_disposed) return;
    final generation = ++_generation;
    final query = request(
        page,
        dateController.text.isEmpty ? null : dateController.text,
        selectedExecutive);
    update(() => loading = true);
    try {
      await fetch(query);
      if (_disposed || generation != _generation) return;
      if (fetchPending != null) {
        final result = await fetchPending!(query);
        if (_disposed || generation != _generation) return;
        pendingStatus = result;
      }
    } catch (_) {
      // The provider retains the existing list failure policy.
    } finally {
      if (!_disposed && generation == _generation)
        update(() => loading = false);
    }
  }

  void reset() {
    update(() {
      selectedDate = null;
      dateController.clear();
      selectedExecutive = null;
      calendarPickerKey = UniqueKey();
    });
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    dateController.dispose();
    super.dispose();
  }
}
