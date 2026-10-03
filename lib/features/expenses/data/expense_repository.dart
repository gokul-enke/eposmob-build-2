import '../domain/models/expense.dart';
import 'expense_api.dart';

/// Request boundary shared by expense pages and daily sales closing.
class ExpenseRepository {
  ExpenseRepository({ExpenseApi? api}) : api = api ?? ExpenseApi();
  final ExpenseApi api;
  Future<List<Expense>?> fetchGeneralPayments(
          {required String accessToken,
          String type = 'EXPENSE',
          bool Function()? isCurrent}) =>
      api.fetchGeneralPayments(
          accessToken: accessToken, type: type, isCurrent: isCurrent);
  Future<dynamic> fetchAccountOptions({required String accessToken}) =>
      api.fetchAccountOptions(accessToken: accessToken);
  Future<Map<String, dynamic>> createGeneralPayment(
          {required String accessToken,
          required Map<String, dynamic> payload}) =>
      api.createGeneralPayment(accessToken: accessToken, payload: payload);
  Future<Map<String, double>> getExpenseBreakdownForDate(
          {required String accessToken,
          required int storeId,
          required String businessDate}) =>
      api.getExpenseBreakdownForDate(
          accessToken: accessToken,
          storeId: storeId,
          businessDate: businessDate);
}
