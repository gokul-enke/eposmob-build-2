import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/services/customer_ledger_snapshot.dart';
import '../domain/customer_ledger_query.dart';

class CustomerLedgerRepository {
  CustomerLedgerRepository(this.provider);
  final InvoiceProvider provider;
  Future<dynamic> request(
          String token, CustomerLedgerQuery f, int page, int count) =>
      provider.listCustomerTransactions(
          accessToken: token,
          customerId: f.customerId,
          dateFrom: f.date,
          dateTo: f.date,
          type: f.type == 'All' ? null : f.type.toLowerCase(),
          page: page,
          perPage: count,
          updateState: false);
  Future<CustomerLedgerPage> page(
          String token, CustomerLedgerQuery f, int page) async =>
      CustomerLedgerPage.parse(await request(token, f, page, 20), page);
  Future<List<ListTransaction>> snapshot(String token, CustomerLedgerQuery f,
          {void Function(int, int)? onProgress}) =>
      fetchCustomerLedgerSnapshot((p) => request(token, f, p, 1000),
          onProgress: onProgress);
}
