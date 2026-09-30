import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/order_details.dart';

/// Identifies the return record independently of the original sale reference.
/// Missing creation dates must not become the sale date or the current time.
class ReturnPrintIdentity {
  const ReturnPrintIdentity({required this.number, required this.date});

  final String number;
  final String date;

  factory ReturnPrintIdentity.fromSummary(OrderReturns returns) =>
      ReturnPrintIdentity(
        number: _number(returns.id),
        date: _date(returns.createdAt),
      );

  factory ReturnPrintIdentity.fromTransaction(SalesReturnOrder returns) =>
      ReturnPrintIdentity(
        number: _number(returns.id),
        date: returns.hasCreatedAt ? returns.createdAt.toIso8601String() : '',
      );

  static String _number(int? id) => id != null && id > 0 ? '$id' : '';

  static String _date(String? source) {
    final value = source?.trim() ?? '';
    return DateTime.tryParse(value) == null ? '' : value;
  }
}
