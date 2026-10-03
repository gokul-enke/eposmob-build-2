import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';
import 'package:pos_machine/providers/role_provider.dart';

export '../../../../../test_support/app_settings_fakes.dart'
    show FakeAppSettingsProvider, testAppSettings, useSurfaceSize;

/// [RoleProvider] that grants or denies every permission.
class FakeRoleProvider extends RoleProvider {
  FakeRoleProvider({this.allowed = true});

  final bool allowed;

  @override
  bool currentUserHasPermissionSync(String permission) => allowed;
}

SupplierTransaction testTransaction(
  int i, {
  String type = 'Credit',
  String? date,
  String? reference,
}) {
  return SupplierTransaction(
    id: i,
    date: date ?? '2026-02-${(i % 28 + 1).toString().padLeft(2, '0')}',
    paymentMethod: 'cash',
    type: type,
    transactionType: 'Invoice',
    amount: '${i * 10}.00',
    currency: 'INR',
    reference: reference ?? 'REF-$i',
    status: 'completed',
  );
}

SupplierPurchase testPurchase(int i, {String status = 'y'}) {
  return SupplierPurchase(
    id: i,
    purchaseNumber: 'PO-$i',
    status: status,
    amountTotal: '${i * 100}.00',
    taxTotal: '5.00',
    items: [
      PurchaseItem(
        id: i,
        productName: 'Widget $i',
        quantity: '2',
        unitPrice: '50.00',
        totalPrice: '100.00',
      ),
    ],
  );
}

Supplier testSupplier({
  int id = 7,
  String name = 'Acme Traders',
  String email = 'acme@example.com',
  String altPhone = '',
  double currentBalance = -250.5,
  String paymentType = 'to_pay',
  List<SupplierKyc> kyc = const [],
  List<SupplierTransaction> transactions = const [],
  List<SupplierPurchase> purchases = const [],
}) {
  return Supplier(
    id: id,
    name: name,
    email: email,
    phone: '9876543210',
    altPhone: altPhone,
    taxNumber: 'TAX-1',
    kyc: kyc,
    productCategories: 'Hardware',
    address: '12 Market Road',
    balance: currentBalance,
    paymentType: paymentType,
    companyId: 1,
    currentBalance: currentBalance,
    balanceStatus: 'Payable',
    userId: 1,
    transactions: transactions,
    purchases: purchases,
  );
}
