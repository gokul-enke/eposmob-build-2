/// Balance filter for party lists (customers, suppliers).
///
/// Display text lives with each feature (it has its own translation keys).
enum BalanceFilter {
  all('All'),
  positive('Positive (+ve)'),
  negative('Negative (-ve)'),
  zero('Zero (0)');

  const BalanceFilter(this.legacyValue);

  /// The string the old UI and provider APIs used for this filter.
  final String legacyValue;

  /// Parses an old string value. Unknown, empty and `null` mean [all].
  static BalanceFilter fromLegacy(String? value) {
    for (final filter in values) {
      if (filter.legacyValue == value) return filter;
    }
    return all;
  }

  /// Whether a party with [balance] passes this filter. A missing balance
  /// only passes [all].
  bool matches(num? balance) {
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
