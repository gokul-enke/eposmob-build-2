class GeneralSettings {
  final bool stockEnabled;

  GeneralSettings({required this.stockEnabled});

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    return GeneralSettings(
      stockEnabled: json['stock_enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_enabled': stockEnabled,
    };
  }
}
