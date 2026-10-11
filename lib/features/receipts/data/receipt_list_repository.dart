import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import '../domain/receipt_list_query.dart';

/// Retains the shared provider cache, pagination and latest-request guards.
class ReceiptListRepository {
  ReceiptListRepository(this.provider);
  final InvoiceProvider provider;
  Future<void> load(String token) => provider.loadAllReceipts(token);
  void apply(ReceiptListQuery q) => provider.applyReceiptFilters(
      name: q.name.trim(),
      receiptNumber: q.receiptNumber,
      paymentReference: q.paymentReference,
      receiptStatus: q.status,
      phone: q.phone,
      email: q.email,
      paymentMethod: q.paymentMethod,
      dateFrom: q.fromDate.isEmpty ? null : q.fromDate,
      dateTo: q.toDate.isEmpty ? null : q.toDate,
      page: 1);
  void reset() => provider.resetReceiptFilters();
  void goToPage(int page) => provider.goToReceiptPage(page);
  Future<List<Receipt>> export(String token, ReceiptListQuery q,
          {void Function(int, int)? onProgress}) =>
      provider.fetchReceiptsForExport(
          accessToken: token,
          name: q.name,
          receiptNumber: q.receiptNumber,
          paymentReference: q.paymentReference,
          phone: q.phone,
          email: q.email,
          status: q.status,
          paymentMethod: q.paymentMethod,
          fromDate: q.fromDate,
          toDate: q.toDate,
          onProgress: onProgress);
}
