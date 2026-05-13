import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/payment_helper.dart';

class PrintService {
  const PrintService();

  double _calculateSavedOrderDiscountAmount(SavedOrder savedOrder) {
    final subtotal = savedOrder.items.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          ((item.price ?? item.product.price?.price ?? 0.0) * item.quantity),
    );

    final flatDiscount = savedOrder.flatDiscount ?? 0.0;
    final percentageValue = savedOrder.percentageDiscount ?? 0.0;
    final percentageDiscount = subtotal * percentageValue / 100;
    final totalDiscount = flatDiscount + percentageDiscount;

    if (totalDiscount > subtotal) {
      return subtotal;
    }

    return totalDiscount;
  }

  /// Helper method to check if a phone number matches the default customer phone from app settings
  bool _isDefaultCustomerPhone(BuildContext context, String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  /// Fetch order details by order id and navigate to PrintPage
  Future<void> printOrderById(BuildContext context, String ordersId) async {
    try {
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null) {
        return; // Not authenticated
      }

      final orderDetailsResponse = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken);

      final orderDetails = OrderDetailsModel.fromJson(orderDetailsResponse);
      final cart = orderDetails.data?.cart;
      if (orderDetails.data == null || cart?.cartItems == null) {
        return;
      }

      final formattedTotal = orderDetails
              .data?.cart?.priceSummary?.netPayable
              ?.toString() ??
          orderDetails.data?.cart?.priceSummary?.netTotal.toString() ??
          '0.00';
      final savedTotal = orderDetails.data?.cart?.priceSummary?.savedTotal
              .toString() ??
          '0.00';

      final storeName = cart?.storeName ?? '';
      final orderDate = orderDetails.data?.orderDate ?? '';

      final customerName = orderDetails.data?.customerDetails?.name;
      final customerPhone = orderDetails.data?.customerDetails?.phone;
      final customerEmail = orderDetails.data?.customerDetails?.email;
      final customerAddress =
          orderDetails.data?.customerDetails?.address?.join(', ');
      final customerAlternatePhone =
          orderDetails.data?.customerDetails?.alternatePhone;
      final customerVatNumber = orderDetails.data?.kycInfo?.vatNumber;
      final customerCrNumber = orderDetails.data?.kycInfo?.crNumber;

      final paymentMethod =
          orderDetails.data?.paymentDetails?.paymentMethod ?? 'N/A';
      final Map<String, dynamic>? paymentBreakdown =
          orderDetails.data?.payments;

      double? paidAmount;
      if (paymentBreakdown != null) {
        final totalPaid = paymentBreakdown.values.fold<double>(
          0.0,
          (sum, val) =>
              sum + (val is num ? val.toDouble() : double.tryParse(val.toString()) ?? 0.0),
        );
        if (totalPaid > 0) paidAmount = totalPaid;
      }

      String? orderComment;
      if (orderDetails.data?.orderProps != null) {
        try {
          final commentProp = orderDetails.data!.orderProps!.firstWhere(
            (prop) => prop.propsCode == "COMMENT",
            orElse: () => OrderDetailsModelDataOrderProp(),
          );
          orderComment = commentProp.propsValue;
        } catch (_) {}
      }

      final deliveryMethod = orderDetails.data?.deliveryMethodName;
      final netExcTax =
          orderDetails.data?.cart?.priceSummary?.netExcTax?.toString();

      if (!context.mounted) return;

      // Try auto-print with default printer first
      final autoPrintSuccess = await PrintPage.autoPrint(
        context,
        storeName: storeName,
        cartItems: cart!.cartItems!,
        formattedTotal: formattedTotal,
        savedTotal: savedTotal,
        discountAmount:
            orderDetails.data!.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: DateHelper.formatInputToDisplay(orderDate),
        orderNumber: orderDetails.data!.orderNumber ?? '',
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        customerAlternatePhone: customerAlternatePhone,
        customerVatNumber: customerVatNumber,
        customerCrNumber: customerCrNumber,
        paymentMethod: paymentMethod,
        paymentBreakdown: paymentBreakdown,
        orderComment: orderComment,
        deliveryMethod: deliveryMethod,
        paidAmount: paidAmount,
        isDefaultCustomer: _isDefaultCustomerPhone(context, customerPhone),
        netExcTax: netExcTax,
      );

      // Only show print page if auto-print failed
      if (!autoPrintSuccess && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrintPage(
              storeName: storeName,
              cartItems: cart.cartItems!,
              formattedTotal: formattedTotal,
              savedTotal: savedTotal,
              discountAmount:
                  orderDetails.data!.priceSummary?.discount?.toString() ?? '0.00',
              orderDate: DateHelper.formatInputToDisplay(orderDate),
              orderNumber: orderDetails.data!.orderNumber ?? '',
              customerName: customerName,
              customerPhone: customerPhone,
              customerEmail: customerEmail,
              customerAddress: customerAddress,
              customerAlternatePhone: customerAlternatePhone,
              customerVatNumber: customerVatNumber,
              customerCrNumber: customerCrNumber,
              paymentMethod: paymentMethod,
              paymentBreakdown: paymentBreakdown,
              orderComment: orderComment,
              deliveryMethod: deliveryMethod,
              paidAmount: paidAmount,
              isDefaultCustomer: _isDefaultCustomerPhone(context, customerPhone),
              netExcTax: netExcTax,
            ),
          ),
        );
      }
    } catch (_) {
      // Swallow errors; original code logged and continued
    }
  }

  /// Print a locally saved order (offline/confirmed in local storage)
  Future<bool> printSavedOrder(
      BuildContext context, SavedOrder savedOrder) async {
    try {
      {
        final cartItems = <Map<String, dynamic>>[];
        double totalMRP = 0.0;
        double netTotal = 0.0;
        double totalTax = 0.0;

        for (var item in savedOrder.items) {
          final double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
          final double itemPrice =
              item.price ?? item.product.price?.price ?? 0.0;
          final double itemTotalPrice = itemPrice * item.quantity;
          final double itemTax = (item.taxAmount ?? 0.0) * item.quantity;

          totalMRP += itemMrp * item.quantity;
          netTotal += itemTotalPrice;
          totalTax += itemTax;

          cartItems.add({
            'productName': item.product.productName ?? 'Unknown',
            'mrp': itemMrp.toString(),
            'quantity': item.quantity.toString(),
            'unitPrice': itemPrice.toString(),
            'totalPrice': itemTotalPrice.toString(),
            'tax_amount': itemTax.toString(),
          });
        }

        double youSaved = totalMRP - netTotal;
        if (youSaved < 0) youSaved = 0.0;
        final double netExcTax = netTotal - totalTax;
        final double discountAmount =
            _calculateSavedOrderDiscountAmount(savedOrder);

        debugPrint("LOCAL PRINT CALCULATION:");
        debugPrint("  - Total MRP: $totalMRP");
        debugPrint("  - Net Total: $netTotal");
        debugPrint("  - Total Tax: $totalTax");
        debugPrint("  - Net Exc Tax: $netExcTax");
        debugPrint("  - You Saved: $youSaved");
        if (cartItems.isNotEmpty) {
          debugPrint("  - Sample item: ${json.encode(cartItems.first)}");
        }

        if (!context.mounted) return false;

        final storeSession =
            Provider.of<StoreSessionProvider>(context, listen: false);
        final storeName = storeSession.activeStore?.storeName ?? "Store";
        final parsedPayment = PaymentHelper.parseLocalMultiPayment(
            context, savedOrder.paymentMethod);
        final String? displayPaymentMethod =
            parsedPayment?.paymentMethodDisplay ?? savedOrder.paymentMethod;
        final Map<String, dynamic>? paymentBreakdown =
            parsedPayment?.paymentBreakdown;
        final double? paidAmount =
            (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0) > 0
                ? (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0)
                : null;

        final autoPrintSuccess = await PrintPage.autoPrint(
          context,
          storeName: storeName,
          cartItems: cartItems,
          formattedTotal: savedOrder.total.toString(),
          savedTotal: youSaved.toString(),
          discountAmount: discountAmount.toString(),
          orderDate: savedOrder.createdAt,
          orderNumber: savedOrder.orderNumber,
          isFromLocalStorage: true,
          customerName: savedOrder.customerName,
          customerPhone: savedOrder.customerPhone,
          customerAddress: savedOrder.address,
          paymentMethod: displayPaymentMethod,
          paymentBreakdown: paymentBreakdown,
          customerAlternatePhone: savedOrder.alternatePhone,
          customerVatNumber: savedOrder.customerVatNumber,
          customerCrNumber: savedOrder.customerCrNumber,
          orderComment: savedOrder.comment,
          deliveryMethod: savedOrder.deliveryMethod,
          paidAmount: paidAmount,
          isDefaultCustomer:
              _isDefaultCustomerPhone(context, savedOrder.customerPhone),
          netExcTax: netExcTax.toString(),
        );

        if (!autoPrintSuccess && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrintPage(
                storeName: storeName,
                cartItems: cartItems,
                formattedTotal: savedOrder.total.toString(),
                savedTotal: youSaved.toString(),
                discountAmount: discountAmount.toString(),
                orderDate: savedOrder.createdAt,
                orderNumber: savedOrder.orderNumber,
                isFromLocalStorage: true,
                customerName: savedOrder.customerName,
                customerPhone: savedOrder.customerPhone,
                customerAddress: savedOrder.address,
                paymentMethod: displayPaymentMethod,
                paymentBreakdown: paymentBreakdown,
                customerAlternatePhone: savedOrder.alternatePhone,
                customerVatNumber: savedOrder.customerVatNumber,
                customerCrNumber: savedOrder.customerCrNumber,
                orderComment: savedOrder.comment,
                deliveryMethod: savedOrder.deliveryMethod,
                paidAmount: paidAmount,
                isDefaultCustomer:
                    _isDefaultCustomerPhone(context, savedOrder.customerPhone),
                netExcTax: netExcTax.toString(),
              ),
            ),
          );
        }

        return autoPrintSuccess;
      }

/*
      // Build items payload for PrintPage
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;

      for (var item in savedOrder.items) {
        final double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        final double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        final double itemTotalPrice = itemPrice * item.quantity;

        totalMRP += itemMrp * item.quantity;
        netTotal += itemTotalPrice;

        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': itemMrp.toString(),
          'quantity': item.quantity.toString(),
          'unitPrice': itemPrice.toString(),
          'totalPrice': itemTotalPrice.toString(),
        });
      }

      double youSaved = totalMRP - netTotal;
      if (youSaved < 0) youSaved = 0.0;

      // Debug
      debugPrint("🖨️ LOCAL PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - You Saved: $youSaved");
      if (cartItems.isNotEmpty) {
        debugPrint("  - Sample item: ${json.encode(cartItems.first)}");
      }

      if (!context.mounted) return false;

      // Get active store name
      final storeSession = Provider.of<StoreSessionProvider>(context, listen: false);
      final storeName = storeSession.activeStore?.storeName ?? "Store";
        final parsedPayment =
          PaymentHelper.parseLocalMultiPayment(context, savedOrder.paymentMethod);
        final String? displayPaymentMethod =
          parsedPayment?.paymentMethodDisplay ?? savedOrder.paymentMethod;
        final Map<String, dynamic>? paymentBreakdown =
          parsedPayment?.paymentBreakdown;
        final double? paidAmount =
          (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0) > 0
            ? (double.tryParse(savedOrder.paidAmount ?? "0") ?? 0.0)
            : null;

      // Try auto-print with default printer first
      final autoPrintSuccess = await PrintPage.autoPrint(
        context,
        storeName: storeName,
        cartItems: cartItems,
        formattedTotal: savedOrder.total.toString(),
        savedTotal: youSaved.toString(),
        discountAmount: (savedOrder.flatDiscount != null ||
                savedOrder.percentageDiscount != null)
            ? ((savedOrder.flatDiscount ?? 0.0) +
                    ((savedOrder.percentageDiscount ?? 0.0) > 0
                        ? (savedOrder.total *
                            (savedOrder.percentageDiscount ?? 0.0) /
                            100)
                        : 0.0))
                .toString()
            : "0.00",
        orderDate: savedOrder.createdAt,
        orderNumber: savedOrder.orderNumber,
        isFromLocalStorage: true,
        customerName: savedOrder.customerName,
        customerPhone: savedOrder.customerPhone,
        customerAddress: savedOrder.address,
        paymentMethod: displayPaymentMethod,
        paymentBreakdown: paymentBreakdown,
        customerAlternatePhone: savedOrder.alternatePhone,
        orderComment: savedOrder.comment,
        deliveryMethod: savedOrder.deliveryMethod,
        paidAmount: paidAmount,
        isDefaultCustomer: _isDefaultCustomerPhone(context, savedOrder.customerPhone),
      );

      // Only show print page if auto-print failed
      if (!autoPrintSuccess && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrintPage(
              storeName: storeName,
              cartItems: cartItems,
              formattedTotal: savedOrder.total.toString(),
              savedTotal: youSaved.toString(),
              discountAmount: (savedOrder.flatDiscount != null ||
                      savedOrder.percentageDiscount != null)
                  ? ((savedOrder.flatDiscount ?? 0.0) +
                          ((savedOrder.percentageDiscount ?? 0.0) > 0
                              ? (savedOrder.total *
                                  (savedOrder.percentageDiscount ?? 0.0) /
                                  100)
                              : 0.0))
                      .toString()
                  : "0.00",
              orderDate: savedOrder.createdAt,
              orderNumber: savedOrder.orderNumber,
              isFromLocalStorage: true,
              customerName: savedOrder.customerName,
              customerPhone: savedOrder.customerPhone,
              customerAddress: savedOrder.address,
              paymentMethod: displayPaymentMethod,
              paymentBreakdown: paymentBreakdown,
              customerAlternatePhone: savedOrder.alternatePhone,
              orderComment: savedOrder.comment,
              deliveryMethod: savedOrder.deliveryMethod,
              paidAmount: paidAmount,
              isDefaultCustomer: _isDefaultCustomerPhone(context, savedOrder.customerPhone),
            ),
          ),
        );
      }
      return autoPrintSuccess;
*/
    } catch (error) {
      debugPrint("Error printing saved order: ${error.toString()}");
      return false;
    }
  }
}
