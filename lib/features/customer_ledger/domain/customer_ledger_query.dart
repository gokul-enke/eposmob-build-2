import 'package:pos_machine/models/list_transaction.dart';

typedef CustomerLedgerQuery = ({
  String amount,
  String name,
  String reference,
  String type,
  String? customerId,
  String? date
});
typedef CustomerLedgerServerQuery = ({
  String type,
  String? customerId,
  String? date
});

CustomerLedgerServerQuery ledgerServerQuery(CustomerLedgerQuery f) =>
    (type: f.type, customerId: f.customerId, date: f.date);
bool needsLocalLedgerMatching(CustomerLedgerQuery f) =>
    f.amount.isNotEmpty ||
    f.reference.isNotEmpty ||
    (f.name.isNotEmpty && f.customerId == null);
List<ListTransaction> matchCustomerLedger(
        List<ListTransaction> rows, CustomerLedgerQuery f) =>
    rows
        .where((r) =>
            (r.amount ?? '').contains(f.amount) &&
            (r.referenceId ?? '')
                .toLowerCase()
                .contains(f.reference.toLowerCase()) &&
            (f.customerId != null ||
                (r.customerName ?? '')
                    .toLowerCase()
                    .contains(f.name.toLowerCase())))
        .toList();
