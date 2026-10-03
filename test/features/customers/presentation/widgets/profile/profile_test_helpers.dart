import 'package:pos_machine/features/customers/domain/models/customer_list.dart';

export '../../../../../test_support/app_settings_fakes.dart';

CustomerListModelData testCustomer({
  String? name = 'Asha Menon',
  String? customerType = 'B2B',
  List<CustomerTransaction>? transactions,
  List<Kyc>? kyc,
}) {
  return CustomerListModelData(
    id: 42,
    name: name,
    email: 'asha@example.com',
    phone: '9876543210',
    gender: 'female',
    balance: -125.5,
    paymentType: 'to_pay',
    customerType: customerType,
    loyaltyPoints: 320,
    minRedeemablePoints: 100,
    pricePerPoint: 0.25,
    cardNumber: 'LC-0042',
    membershipName: 'Gold',
    validFrom: '2026-01-01',
    createdAt: DateTime(2025, 3, 9),
    storeName: 'Main Store',
    companyId: 7,
    transactions: transactions,
    kyc: kyc,
  );
}
