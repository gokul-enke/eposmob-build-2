class GeneralSettings {
  final bool stockEnabled;

  /// When true, selling a variant that reports zero stock shows a
  /// confirm-oversell dialog before adding it to the cart. Defaults to false
  /// so businesses that don't track variant-level stock aren't nagged on
  /// every sale. Server key: `confirm_oversell_on_zero_stock`.
  final bool confirmOversellOnZeroStock;

  GeneralSettings({
    required this.stockEnabled,
    this.confirmOversellOnZeroStock = false,
  });

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    return GeneralSettings(
      stockEnabled: json['stock_enabled'] as bool,
      confirmOversellOnZeroStock:
          json['confirm_oversell_on_zero_stock'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_enabled': stockEnabled,
      'confirm_oversell_on_zero_stock': confirmOversellOnZeroStock,
    };
  }
}
