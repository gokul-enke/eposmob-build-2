import 'package:pos_machine/core/filters/balance_filter.dart';

import 'models/supplier.dart';

/// The suppliers-list search criteria (immutable). Empty strings mean "no
/// filter".
class SupplierFilter {
  const SupplierFilter({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.balance = BalanceFilter.all,
  });

  static const none = SupplierFilter();

  final String name;
  final String email;
  final String phone;
  final BalanceFilter balance;

  bool get isEmpty =>
      name.isEmpty &&
      email.isEmpty &&
      phone.isEmpty &&
      balance == BalanceFilter.all;

  SupplierFilter copyWith({
    String? name,
    String? email,
    String? phone,
    BalanceFilter? balance,
  }) =>
      SupplierFilter(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        balance: balance ?? this.balance,
      );

  /// Name, email and phone match case-insensitively as substrings.
  bool matches(Supplier supplier) {
    bool contains(String value, String query) =>
        query.isEmpty || value.toLowerCase().contains(query.toLowerCase());
    return contains(supplier.name, name) &&
        contains(supplier.email, email) &&
        contains(supplier.phone, phone) &&
        balance.matches(supplier.currentBalance);
  }

  List<Supplier> apply(List<Supplier> suppliers) =>
      isEmpty ? List.of(suppliers) : suppliers.where(matches).toList();

  @override
  bool operator ==(Object other) =>
      other is SupplierFilter &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(name, email, phone, balance);
}
