/// Which category list bucket to load or read.
enum CategoryListScope {
  /// Billing sidebar, restaurant, kiosk, offline sync.
  sellable,

  /// Add stock / purchase flows.
  purchasable,

  /// Category management screens (full directory).
  all,
}
