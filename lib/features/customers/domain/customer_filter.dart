import 'balance_filter.dart';
import 'models/customer_list.dart';

/// The customers-list search criteria (immutable). Empty strings mean "no
/// filter".
class CustomerFilter {
  const CustomerFilter({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.balance = BalanceFilter.all,
  });

  static const none = CustomerFilter();

  final String name;
  final String email;
  final String phone;
  final BalanceFilter balance;

  bool get isEmpty =>
      name.isEmpty &&
      email.isEmpty &&
      phone.isEmpty &&
      balance == BalanceFilter.all;

  CustomerFilter copyWith({
    String? name,
    String? email,
    String? phone,
    BalanceFilter? balance,
  }) =>
      CustomerFilter(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        balance: balance ?? this.balance,
      );

  /// Name and email match case-insensitively; phone matches the main or the
  /// alternative number.
  bool matches(CustomerListModelData customer) {
    if (name.isNotEmpty &&
        !(customer.name?.toLowerCase().contains(name.toLowerCase()) ?? false)) {
      return false;
    }
    if (email.isNotEmpty &&
        !(customer.email?.toLowerCase().contains(email.toLowerCase()) ??
            false)) {
      return false;
    }
    if (phone.isNotEmpty &&
        !((customer.phone?.contains(phone) ?? false) ||
            (customer.altPhone?.contains(phone) ?? false))) {
      return false;
    }
    return balance.matches(customer.balance);
  }

  List<CustomerListModelData> apply(List<CustomerListModelData> customers) =>
      isEmpty ? List.of(customers) : customers.where(matches).toList();

  @override
  bool operator ==(Object other) =>
      other is CustomerFilter &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(name, email, phone, balance);
}
