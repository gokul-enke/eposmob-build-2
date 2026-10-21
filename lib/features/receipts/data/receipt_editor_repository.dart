import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

/// Uses the same provider contracts as the legacy receipt editor.
/// Invoice lookup remains a request-local snapshot, independent of list filters.
class ReceiptEditorRepository {
  const ReceiptEditorRepository({
    required this.invoices,
    required this.customers,
    required this.masterData,
  });

  final InvoiceProvider invoices;
  final CustomerProvider customers;
  final MasterDataProvider masterData;

  Future<List<CustomerListModelData>> loadCustomers(String accessToken) async {
    await customers.fetchCustomers(accessToken: accessToken, listAll: true);
    return customers.allCustomers ?? [];
  }

  Future<List<Invoice>> loadInvoices(String accessToken) =>
      invoices.fetchAllInvoicesSnapshot(accessToken: accessToken);

  Future<List<MasterDataValue>?> loadPaymentMethods() =>
      masterData.fetchPaymentMethods();

  Future<dynamic> createReceipt({
    required String customerId,
    required String receiptStatus,
    required List<Map<String, dynamic>> receiptItems,
    required String accessToken,
    String? paymentReference,
  }) =>
      invoices.addReceipt(
        customerId: customerId,
        receiptStatus: receiptStatus,
        receiptItems: receiptItems,
        accessToken: accessToken,
        paymentReference: paymentReference,
      );
}
