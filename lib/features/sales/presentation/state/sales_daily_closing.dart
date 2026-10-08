import 'package:flutter/foundation.dart';

import '../../data/sales_repository.dart';
import '../../domain/models/daily_sales_close.dart';
import '../../domain/models/day_close_pending_status.dart';

mixin SalesDailyClosing on ChangeNotifier {
  SalesRepository get repository;
  List<DailySalesCloseData> dailySalesCloseList = [];
  Pagination? dailySalesClosePagination;
  DailySalesCloseData? _selectedDailySalesCloseData;
  DailySalesCloseData? get selectedDailySalesCloseData =>
      _selectedDailySalesCloseData;

  void setSelectedDailySalesCloseData(DailySalesCloseData? data) {
    _selectedDailySalesCloseData = data;
    notifyListeners();
  }

  int _returnIndex = 78; // Default to user list
  int get returnIndex => _returnIndex;
  void setReturnIndex(int index) {
    _returnIndex = index;
    notifyListeners();
  }

  int _closingGeneration = 0;
  Future<void> fetchDailySalesClose({
    required String accessToken,
    String? startDate,
    String? endDate,
    int page = 1,
    int? userId,
    required int storeId,
  }) async {
    final generation = ++_closingGeneration;
    try {
      final result = await repository.closing.fetchDailySalesClose(
          accessToken: accessToken,
          startDate: startDate,
          endDate: endDate,
          page: page,
          userId: userId,
          storeId: storeId);
      if (generation != _closingGeneration) return;
      dailySalesCloseList = result?.data ?? [];
      if (result != null) dailySalesClosePagination = result.pagination;
      notifyListeners();
    } catch (_) {
      if (generation != _closingGeneration) rethrow;
      dailySalesCloseList = [];
      notifyListeners();
      rethrow;
    }
  }

  Future<DailySalesCloseData?> fetchDailySalesCloseDetail({
    required String accessToken,
    required int id,
  }) =>
      repository.closing
          .fetchDailySalesCloseDetail(accessToken: accessToken, id: id);
  Future<DailySalesCloseSummary?> fetchDailySalesCloseSummary({
    required String accessToken,
    required int storeId,
    String? businessDate,
  }) =>
      repository.closing.fetchDailySalesCloseSummary(
          accessToken: accessToken,
          storeId: storeId,
          businessDate: businessDate);
  Future<Map<String, dynamic>> createDailySalesClose({
    required String accessToken,
    required int storeId,
    String? shiftName,
    String? businessDate,
    String? openingDate,
    String? openingTime,
    String? closingDate,
    String? closingTime,
    num? cashRefunds,
    num? cashExpenses,
    num? cashDropAmount,
    num? openingCashInHand,
    List<dynamic>? openingCashBreakdown,
    num? closingCashInHand,
    List<dynamic>? closingCashBreakdown,
    String? notes,
    int? openingTransactionId,
    int? closingTransactionId,
  }) =>
      repository.closing.createDailySalesClose(
          accessToken: accessToken,
          storeId: storeId,
          shiftName: shiftName,
          businessDate: businessDate,
          openingDate: openingDate,
          openingTime: openingTime,
          closingDate: closingDate,
          closingTime: closingTime,
          cashRefunds: cashRefunds,
          cashExpenses: cashExpenses,
          cashDropAmount: cashDropAmount,
          openingCashInHand: openingCashInHand,
          openingCashBreakdown: openingCashBreakdown,
          closingCashInHand: closingCashInHand,
          closingCashBreakdown: closingCashBreakdown,
          notes: notes,
          openingTransactionId: openingTransactionId,
          closingTransactionId: closingTransactionId);
  Future<bool> openShiftApi({
    required String accessToken,
    required int storeId,
    required String shiftName,
    required String businessDate,
    required String openingDate,
    required String openingTime,
    required double openingCashInHand,
    required List<Map<String, dynamic>> openingCashBreakdown,
    String notes = '',
  }) =>
      repository.closing.openShiftApi(
          accessToken: accessToken,
          storeId: storeId,
          shiftName: shiftName,
          businessDate: businessDate,
          openingDate: openingDate,
          openingTime: openingTime,
          openingCashInHand: openingCashInHand,
          openingCashBreakdown: openingCashBreakdown,
          notes: notes);
  Future<DayClosePendingStatus?> fetchDayClosePendingStatus({
    required String accessToken,
    required int storeId,
    required int userId,
  }) =>
      repository.closing.fetchDayClosePendingStatus(
          accessToken: accessToken, storeId: storeId, userId: userId);
}
