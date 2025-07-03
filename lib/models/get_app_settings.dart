class AppSettings {
  final bool barcodeSales;
  final String customerCarePhone;
  final String customerCareEmail;
  final String printTitle;
  final bool showCustomerLastBuyedPriceList;

  AppSettings({
    required this.barcodeSales,
    required this.customerCarePhone,
    required this.customerCareEmail,
    required this.printTitle,
    required this.showCustomerLastBuyedPriceList,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    var data = json['data'] as List;
    Map<String, dynamic> settingsMap = {};

    for (var setting in data) {
      // Only use the value of 'status' to determine boolean values
      settingsMap[setting['code']] = {
        'status': setting['status'] == "true",
        'value': setting['value'] ?? ""
      };
    }

    return AppSettings(
      barcodeSales: settingsMap['BARCODE_SALES']?['status'] ?? false,
      customerCarePhone:
          settingsMap['COMPANY_CUSTOMER_CARE_PHONE']?['value'] ?? "",
      customerCareEmail:
          settingsMap['COMPANY_CUSTOMER_CARE_EMAIL']?['value'] ?? "",
      printTitle: settingsMap['PRINT_TITLE']?['value'] ?? "",
      showCustomerLastBuyedPriceList:
          settingsMap['SHOW_CUSTOMER_LAST_BUYED_PRICE_LIST']?['status'] ??
              false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': [
        {
          'name': "Barcode Sales",
          'code': 'BARCODE_SALES',
          'value': barcodeSales.toString(), // Assuming this is also a string
          'status': barcodeSales.toString(),
        },
        {
          'name': "Company Customer Care Phone",
          'code': 'COMPANY_CUSTOMER_CARE_PHONE',
          'value': customerCarePhone,
          'status': customerCarePhone.isNotEmpty ? "true" : "false",
        },
        {
          'name': "Company Customer Care Email",
          'code': 'COMPANY_CUSTOMER_CARE_EMAIL',
          'value': customerCareEmail,
          'status': customerCareEmail.isNotEmpty ? "true" : "false",
        },
        {
          'name': "Print Title",
          'code': 'PRINT_TITLE',
          'value': printTitle,
          'status': printTitle.isNotEmpty ? "true" : "false",
        },
        {
          "name": "Show Customer Last Buyed Price List",
          "code": "SHOW_CUSTOMER_LAST_BUYED_PRICE_LIST",
          "value": "",
          "status": showCustomerLastBuyedPriceList.toString(),
        },
      ],
    };
  }
}
