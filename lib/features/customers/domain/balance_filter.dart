/// Customer balance filter on the customers list.
enum BalanceFilter {
  all('All', 'customers.all'),
  positive('Positive (+ve)', 'customers.positive'),
  negative('Negative (-ve)', 'customers.negative'),
  zero('Zero (0)', 'customers.zero');

  const BalanceFilter(this.legacyValue, this.translationKey);

  /// The string the old UI and provider API used for this filter.
  final String legacyValue;

  /// Translation key of the display label.
  final String translationKey;

  /// Parses an old string value. Unknown, empty and `null` mean [all].
  static BalanceFilter fromLegacy(String? value) {
    for (final filter in values) {
      if (filter.legacyValue == value) return filter;
    }
    return all;
  }

  /// Whether a customer with [balance] passes this filter. Customers without
  /// a balance only pass [all].
  bool matches(double? balance) {
    if (this == all) return true;
    if (balance == null) return false;
    return switch (this) {
      positive => balance > 0,
      negative => balance < 0,
      zero => balance == 0,
      all => true,
    };
  }
}
