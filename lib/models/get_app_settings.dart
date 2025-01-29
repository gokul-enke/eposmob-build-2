class AppSettings {
  final bool barcodeSales;

  AppSettings({
    required this.barcodeSales,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    var data = json['data'] as List;
    Map<String, dynamic> settingsMap = {};
    for (var setting in data) {
      settingsMap[setting['code']] = setting['status'] == "true";
    }

    return AppSettings(
      barcodeSales: settingsMap['BARCODE_SALES'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode_sales': barcodeSales,
    };
  }
}
