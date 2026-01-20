import 'package:flutter/material.dart';

class AppSettings {
  final bool barcodeSales;
  final String customerCarePhone;
  final String customerCareEmail;
  final String printTitle;
  final bool showCustomerLastBuyedPriceList;
  final bool askDeliveryDate;
  final bool priceRoundOff;
  final bool discountAndCoupon;
  final bool autoAssignDefaultCustomer;
  final String autoAssignDefaultCustomerPhone;
  final String currency;
  final bool zatcaPhase1Enabled;
  final bool zatcaPhase2Enabled;
  final bool showTaxPos;
  final bool showMrpPos;
  final bool showTaxRatePos;
  final bool showConfirmOrderButton;
  final bool enableKOTPrint;
  final String defaultDeliveryMethod;
  final String defaultPaymentMethod;

  AppSettings({
    required this.barcodeSales,
    required this.customerCarePhone,
    required this.customerCareEmail,
    required this.printTitle,
    required this.showCustomerLastBuyedPriceList,
    required this.askDeliveryDate,
    required this.priceRoundOff,
    required this.discountAndCoupon,
    required this.autoAssignDefaultCustomer,
    required this.autoAssignDefaultCustomerPhone,
    required this.currency,
    required this.zatcaPhase1Enabled,
    required this.zatcaPhase2Enabled,
    required this.showTaxPos,
    required this.showMrpPos,
    required this.showTaxRatePos,
    required this.showConfirmOrderButton,
    required this.enableKOTPrint,
    required this.defaultDeliveryMethod,
    required this.defaultPaymentMethod,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    var data = json['data'] as List;
    Map<String, dynamic> settingsMap = {};

    // Debug logging for parsing
    debugPrint('🎫 APP SETTINGS PARSING DEBUG:');
    debugPrint('  - Raw data length: ${data.length}');

    for (var setting in data) {
      // Handle both "true" and "1" as valid true values for status
      bool isStatusTrue =
          setting['status'] == "true" || setting['status'] == "1";

      // Debug logging for DISCOUNT_AND_COUPON specifically
      if (setting['code'] == 'DISCOUNT_AND_COUPON') {
        debugPrint('  - Found DISCOUNT_AND_COUPON:');
        debugPrint(
            '    - Raw status: "${setting['status']}" (type: ${setting['status'].runtimeType})');
        debugPrint(
            '    - Raw value: "${setting['value']}" (type: ${setting['value'].runtimeType})');
        debugPrint('    - Parsed status: $isStatusTrue');
      }

      settingsMap[setting['code']] = {
        'status': isStatusTrue,
        'value': setting['value'] ?? ""
      };
    }

    // Debug logging for final parsed settings
    debugPrint('  - Final parsed settings:');
    debugPrint(
        '    - BARCODE_SALES: ${settingsMap['BARCODE_SALES']?['status']}');
    debugPrint(
        '    - DISCOUNT_AND_COUPON: ${settingsMap['DISCOUNT_AND_COUPON']?['status']}');
    debugPrint(
        '    - PRICE_ROUND_OFF: ${settingsMap['PRICE_ROUND_OFF']?['status']}');
    debugPrint('    - CURRENCY: ${settingsMap['CURRENCY']?['value']}');

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
      askDeliveryDate: settingsMap['ASK_DELIVERY_DATE']?['status'] ?? false,
      priceRoundOff: settingsMap['PRICE_ROUND_OFF']?['status'] ?? false,
      discountAndCoupon: settingsMap['DISCOUNT_AND_COUPON']?['status'] ?? false,
      autoAssignDefaultCustomer:
          settingsMap['AUTO_ASSIGN_DEFAULT_CUSTOMER']?['status'] ?? false,
      autoAssignDefaultCustomerPhone:
          settingsMap['AUTO_ASSIGN_DEFAULT_CUSTOMER']?['value'] ?? "",
      currency: settingsMap['CURRENCY']?['value'] ?? "",
      zatcaPhase1Enabled: settingsMap['ZATCA_PHASE_1']?['status'] ?? false,
      zatcaPhase2Enabled: settingsMap['ZATCA_PHASE_2']?['status'] ?? false,
      showTaxPos: settingsMap['SHOW_TAX_POS']?['status'] ?? false,
      showMrpPos: settingsMap['SHOW_MRP_POS']?['status'] ?? false,
      showTaxRatePos: settingsMap['SHOW_TAXRATE_POS']?['status'] ?? false,
      showConfirmOrderButton:
          settingsMap['SHOW_CONFIRM_ORDER_BUTTON']?['status'] ?? true,
      enableKOTPrint: settingsMap['ENABLE_KOT_PRINT']?['status'] ?? false,
      defaultDeliveryMethod:
          settingsMap['DEFAULT_DELIVERY_METHOD']?['value'] ?? "",
      defaultPaymentMethod:
          settingsMap['DEFAULT_PAYMENT_METHOD']?['value'] ?? "",
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
        {
          "name": "Ask Delivery Date",
          "code": "ASK_DELIVERY_DATE",
          "value": "",
          "status": askDeliveryDate.toString(),
        },
        {
          "name": "Price Round Off",
          "code": "PRICE_ROUND_OFF",
          "value": "",
          "status": priceRoundOff.toString(),
        },
        {
          "name": "Discount and Coupon",
          "code": "DISCOUNT_AND_COUPON",
          "value": "",
          "status": discountAndCoupon.toString(),
        },
        {
          "name": "Auto Assign Default Customer",
          "code": "AUTO_ASSIGN_DEFAULT_CUSTOMER",
          "value": "",
          "status": autoAssignDefaultCustomer.toString(),
        },
        {
          "name": "Currency",
          "code": "CURRENCY",
          "value": currency,
          "status": currency.toString(),
        },
        {
          "name": "Zatca Phase 1",
          "code": "ZATCA_PHASE_1",
          "value": zatcaPhase1Enabled.toString(),
          "status": zatcaPhase1Enabled.toString(),
        },
        {
          "name": "Zatca Phase 2",
          "code": "ZATCA_PHASE_2",
          "value": zatcaPhase2Enabled.toString(),
          "status": zatcaPhase2Enabled.toString(),
        },
        {
          "name": "Show Tax POS",
          "code": "SHOW_TAX_POS",
          "value": "",
          "status": showTaxPos.toString(),
        },
        {
          "name": "Show MRP POS",
          "code": "SHOW_MRP_POS",
          "value": "",
          "status": showMrpPos.toString(),
        },
        {
          "name": "Show Tax Rate POS",
          "code": "SHOW_TAXRATE_POS",
          "value": "",
          "status": showTaxRatePos.toString(),
        },
        {
          "name": "Show Confirm Order Button",
          "code": "SHOW_CONFIRM_ORDER_BUTTON",
          "value": "",
          "status": showConfirmOrderButton.toString(),
        },
        {
          "name": "Enable KOT Print",
          "code": "ENABLE_KOT_PRINT",
          "value": "",
          "status": enableKOTPrint.toString(),
        },
        {
          "name": "Default Delivery Method",
          "code": "DEFAULT_DELIVERY_METHOD",
          "value": defaultDeliveryMethod.toString(),
          "status": defaultDeliveryMethod.toString(),
        },
        {
          "name": "Default Payment Method",
          "code": "DEFAULT_PAYMENT_METHOD",
          "value": defaultPaymentMethod.toString(),
          "status": defaultPaymentMethod.toString(),
        },
      ],
    };
  }
}
