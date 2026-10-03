/// Display rules for customer data that don't depend on the UI.
abstract final class CustomerNames {
  /// Placeholder names the backend uses for walk-in / unnamed customers.
  static const _placeholders = {'no name', 'unnamed'};

  static bool isUnnamed(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty || _placeholders.contains(trimmed.toLowerCase());
  }

  /// The trimmed name, or `null` when the customer is unnamed.
  static String? realName(String? name) =>
      isUnnamed(name) ? null : name!.trim();
}

/// B2C (consumer) or B2B (business) customer.
enum CustomerType {
  b2c('B2C'),
  b2b('B2B');

  const CustomerType(this.apiValue);

  final String apiValue;

  /// Missing or unknown values are treated as B2C.
  static CustomerType parse(String? value) =>
      value?.trim().toUpperCase() == 'B2B' ? b2b : b2c;
}
