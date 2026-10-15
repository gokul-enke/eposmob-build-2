import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import '../domain/invoice_list_query.dart';

/// Compatibility boundary for shared provider state. Receipt loading, row
/// actions and other consumers retain the existing public provider methods.
class InvoiceListRepository {
  InvoiceListRepository(this.provider);
  final InvoiceProvider provider;
  Future<dynamic> load(String token, {String? zatcaStatus, int? page}) =>
      provider.listAllInvoices(
          accessToken: token, zatcaStatus: zatcaStatus, page: page);
  void apply(InvoiceListQuery query) => provider.applyFilters(
      name: query.name,
      invoiceNumber: query.invoiceNumber,
      phone: query.phone,
      fromDate: query.fromDate,
      toDate: query.toDate,
      status: query.status,
      zatcaStatus: query.zatcaStatus);
  void reset({bool reload = true, bool notify = true}) =>
      provider.resetFilters(reload: reload, notify: notify);
  void goToPage(int page) => provider.goToPage(page);
  String? consumePendingZatcaStatus() =>
      provider.consumePendingZatcaStatusFilter();
  Future<List<Invoice>> export(String token, InvoiceListQuery query,
          {required bool showZatca, void Function(int, int)? onProgress}) =>
      provider.fetchInvoicesForExport(
          accessToken: token,
          name: query.name,
          invoiceNumber: query.invoiceNumber,
          phone: query.phone,
          fromDate: query.fromDate,
          toDate: query.toDate,
          status: query.status,
          zatcaStatus: showZatca ? query.zatcaStatus : null,
          onProgress: onProgress);
}
