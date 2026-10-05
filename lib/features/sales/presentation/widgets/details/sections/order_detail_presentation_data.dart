import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/delivery_method_display.dart';
import 'package:pos_machine/models/order_details.dart';

class OrderDetailPresentationData {
  final OrderDetailsModelData? orderDetailsModelData;
  final OrderDetailsModelDataCustomerDetails? customerDetails;
  final List<OrderDetailsModelDataCartItem>? cartItem;
  final OrderDetailsModelDataPriceSummary? priceSummary;
  final Future<void> Function()? onFulfillmentUpdated;

  const OrderDetailPresentationData(
      {required this.orderDetailsModelData,
      required this.priceSummary,
      required this.cartItem,
      required this.customerDetails,
      this.onFulfillmentUpdated});
  String get deliveryMethodLabel => DeliveryMethodDisplay.labelForIdOrName(
        orderDetailsModelData?.deliveryMethodId,
        orderDetailsModelData?.deliveryMethodName,
      );

  double calculateTotalMRP() {
    if (cartItem == null || cartItem!.isEmpty) {
      return 0.0;
    }

    double totalMRP = 0.0;
    for (var item in cartItem!) {
      final mrp = double.tryParse(item.mrp ?? '0') ?? 0.0;
      final quantity = item.quantity ?? 0;
      totalMRP += mrp * quantity;
    }
    return totalMRP;
  }

  OrderDetailsModelDataPriceSummary? effectivePriceSummary() {
    return priceSummary ??
        orderDetailsModelData?.priceSummary ??
        orderDetailsModelData?.cart?.priceSummary;
  }

  String? getOrderPropValue(String code) {
    final prop = orderDetailsModelData?.orderProps?.firstWhere(
      (item) => item.propsCode?.toUpperCase() == code.toUpperCase(),
      orElse: () => OrderDetailsModelDataOrderProp(),
    );
    final value = prop?.propsValue;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  double balanceAmount(OrderDetailsModelDataPriceSummary? summary) {
    final propBalance = double.tryParse(getOrderPropValue('BALANCE') ?? '');
    if (propBalance != null) {
      return propBalance;
    }

    final totalPaid =
        calculateTotalPayments(orderDetailsModelData?.payments ?? {});
    final payable = (summary?.netPayable ?? summary?.netTotal ?? 0).toDouble();
    final balance = payable - totalPaid;
    return balance < 0 ? 0.0 : balance;
  }

  String formatAmount(num? value) {
    return (value ?? 0).toStringAsFixed(2);
  }

  String formatCustomerAddressList(List<dynamic>? addressList) {
    if (addressList == null || addressList.isEmpty) return '';

    try {
      // If the first item is a Map (parsed JSON)
      if (addressList[0] is Map) {
        final map = addressList[0];
        List<String> parts = [];

        if (map['address'] != null) parts.add(map['address'].toString());
        if (map['city'] != null) parts.add(map['city'].toString());

        // Handle state
        if (map['state_id'] != null) {
          // If we have state ID but no name, we might just show ID or skip
          // Ideally we'd look up the name, but for now let's skip if no name
        }

        // Handle pincode
        if (map['pincode_id'] != null) {
          // Same for pincode
        }

        return parts.join(', ');
      }

      // If it's a string representation of a map "{id: 6, ...}"
      String raw = addressList[0].toString();
      if (raw.startsWith('{')) {
        String address = "";
        String city = "";

        final addressMatch = RegExp(r'address:\s*([^,]+)').firstMatch(raw);
        if (addressMatch != null) address = addressMatch.group(1)?.trim() ?? "";

        final cityMatch = RegExp(r'city:\s*([^,]+)').firstMatch(raw);
        if (cityMatch != null) city = cityMatch.group(1)?.trim() ?? "";

        List<String> parts = [];
        if (address.isNotEmpty) parts.add(address);
        if (city.isNotEmpty) parts.add(city);

        if (parts.isNotEmpty) return parts.join(', ');
      }

      return addressList.join(', ');
    } catch (e) {
      return addressList.join(', ');
    }
  }

  String formatOrderPropertyValue(String label, String value, String currency) {
    // Format specific order properties
    switch (label.toUpperCase()) {
      case 'ORDER STATUS':
      case 'ORDER_STATUS':
        // Extract date from "confirmed - 2025-08-02 17:24:09" format
        if (value.contains(' - ')) {
          final parts = value.split(' - ');
          if (parts.length == 2) {
            final status = parts[0];
            final dateTime = parts[1];
            try {
              final date = DateTime.parse(dateTime);
              return '$status - ${DateHelper.formatTimeOnly(date.toString())}';
            } catch (e) {
              return value; // Return original if parsing fails
            }
          }
        }
        return value;
      case 'TOKEN NUMBER':
      case 'ORDER TOKEN NUMBER':
      case 'ORDER_TOKEN_NUMBER':
        return value;
      case 'BALANCE':
        // Format balance with proper currency
        final balance = double.tryParse(value) ?? 0.0;
        return '$currency ${balance.toStringAsFixed(2)}';
      case 'DELIVERY DATE':
        try {
          return DateHelper.formatISODate(value);
        } catch (e) {
          return value;
        }
      case 'CUSTOMER_PHONE':
      case 'CUSTOMER PHONE':
      case 'CUSTOMER_EMAIL':
      case 'CUSTOMER EMAIL':
        // Keep as is for contact info
        return value;
      default:
        return value;
    }
  }

  double calculateTotalPayments(Map<String, dynamic> payments) {
    return payments.values.fold(
        0.0, (sum, value) => sum + (double.tryParse(value.toString()) ?? 0.0));
  }

  String fmt(dynamic val) {
    if (val == null) return '0.00';
    if (val is num) return val.toStringAsFixed(2);
    if (val is String) {
      final parsed = double.tryParse(val);
      return parsed != null ? parsed.toStringAsFixed(2) : val;
    }
    return val.toString();
  }

  String unitText(OrderDetailsModelDataCartItem item) {
    final saleUnitName = item.saleUnitName?.trim();
    if (saleUnitName != null && saleUnitName.isNotEmpty) {
      return saleUnitName;
    }

    final productUnit = item.productUnit?.trim();
    if (productUnit != null && productUnit.isNotEmpty) {
      return productUnit;
    }

    return '-';
  }

  String fmtQty(dynamic val) {
    if (val == null) return '0';
    if (val is num) {
      return val == val.truncate() ? val.truncate().toString() : val.toString();
    }
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) {
        return parsed == parsed.truncate()
            ? parsed.truncate().toString()
            : parsed.toString();
      }
      return val;
    }
    return val.toString();
  }
}
