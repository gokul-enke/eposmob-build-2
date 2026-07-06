import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/billing/domain/receipt_customer_balance.dart';
import 'package:pos_machine/helpers/payment_helper.dart';

enum PrintMode { salesOnly, returnOnly, combined }

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

  /// Shows print options when the order has sales returns; otherwise prints combined.
  Future<bool> printOrderByIdWithOptions(
    BuildContext context,
    String ordersId, {
    bool useCheckoutBalanceFields = false,
    double? checkoutOldBalance,
    double? checkoutTotalPaid,
    bool checkoutIsDefaultCustomer = false,
  }) async {
    try {
      final orderDetails = await _fetchOrderDetails(context, ordersId);
      if (orderDetails == null || !context.mounted) {
        return false;
      }

      final orderReturns = orderDetails.data?.orderReturns;
      if (!_hasOrderReturns(orderReturns)) {
        return _executeOrderPrint(
          context,
          orderDetails,
          PrintMode.combined,
          useCheckoutBalanceFields: useCheckoutBalanceFields,
          checkoutOldBalance: checkoutOldBalance,
          checkoutTotalPaid: checkoutTotalPaid,
          checkoutIsDefaultCustomer: checkoutIsDefaultCustomer,
        );
      }

      final mode = await _showPrintModeSheet(context);
      if (mode == null || !context.mounted) {
        return false;
      }

      return _executeOrderPrint(
        context,
        orderDetails,
        mode,
        useCheckoutBalanceFields: useCheckoutBalanceFields,
        checkoutOldBalance: checkoutOldBalance,
        checkoutTotalPaid: checkoutTotalPaid,
        checkoutIsDefaultCustomer: checkoutIsDefaultCustomer,
      );
    } catch (_) {
      return false;
    }
  }

  /// Fetch order details by order id and navigate to PrintPage.
  ///
  /// When [checkoutOldBalance] and [checkoutTotalPaid] are supplied (mobile /
  /// checkout flows), receipt balance fields mirror desktop
  /// `_createOrderAndPrint`. Otherwise [customerCurrentBalance] falls back to
  /// the API `BALANCE` order prop when present.
  Future<bool> printOrderById(
    BuildContext context,
    String ordersId, {
    bool useCheckoutBalanceFields = false,
    double? checkoutOldBalance,
    double? checkoutTotalPaid,
    bool checkoutIsDefaultCustomer = false,
  }) async {
    try {
      final orderDetails = await _fetchOrderDetails(context, ordersId);
      if (orderDetails == null || !context.mounted) {
        return false;
      }

      return _executeOrderPrint(
        context,
        orderDetails,
        PrintMode.combined,
        useCheckoutBalanceFields: useCheckoutBalanceFields,
        checkoutOldBalance: checkoutOldBalance,
        checkoutTotalPaid: checkoutTotalPaid,
        checkoutIsDefaultCustomer: checkoutIsDefaultCustomer,
      );
    } catch (_) {
      return false;
    }
  }

  Future<OrderDetailsModel?> _fetchOrderDetails(
    BuildContext context,
    String ordersId,
  ) async {
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      return null;
    }

    final orderDetailsResponse =
        await SalesProvider().listOrderDetails(context, ordersId, accessToken);
    final orderDetails = OrderDetailsModel.fromJson(orderDetailsResponse);
    final cart = orderDetails.data?.cart;
    if (orderDetails.data == null || cart?.cartItems == null) {
      return null;
    }

    return orderDetails;
  }

  bool _hasOrderReturns(OrderReturns? orderReturns) {
    return orderReturns?.returnItems != null &&
        orderReturns!.returnItems!.isNotEmpty;
  }

  Future<PrintMode?> _showPrintModeSheet(BuildContext context) {
    return showModalBottomSheet<PrintMode>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Print Option',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Print Sales'),
                  subtitle: const Text('Receipt with returned quantities removed'),
                  onTap: () => Navigator.pop(sheetContext, PrintMode.salesOnly),
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_return),
                  title: const Text('Print Return'),
                  subtitle: const Text('Return receipt only'),
                  onTap: () => Navigator.pop(sheetContext, PrintMode.returnOnly),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt),
                  title: const Text('Print Combined'),
                  subtitle: const Text('Full bill with sales and returns'),
                  onTap: () => Navigator.pop(sheetContext, PrintMode.combined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<OrderDetailsModelDataCartItem> _adjustCartItemsForSalesOnly(
    List<OrderDetailsModelDataCartItem> cartItems,
    List<OrderReturnItem> returnItems,
  ) {
    final returnQtyByProduct = <String, int>{};
    for (final returnItem in returnItems) {
      final productName = returnItem.productName?.trim().toLowerCase() ?? '';
      if (productName.isEmpty) continue;
      returnQtyByProduct[productName] =
          (returnQtyByProduct[productName] ?? 0) + (returnItem.quantity ?? 0);
    }

    final remainingReturns = Map<String, int>.from(returnQtyByProduct);
    final adjustedItems = <OrderDetailsModelDataCartItem>[];

    for (final item in cartItems) {
      final productName = item.productName?.trim().toLowerCase() ?? '';
      final originalQty = item.quantity?.toDouble() ?? 0;
      if (originalQty <= 0) continue;

      final returnedQty = remainingReturns[productName] ?? 0;
      final deductQty = returnedQty.clamp(0, originalQty.toInt());
      if (deductQty > 0) {
        remainingReturns[productName] = returnedQty - deductQty;
      }

      final newQty = originalQty - deductQty;
      if (newQty <= 0) continue;

      final unitPrice = double.tryParse(item.unitPrice ?? '0') ?? 0;
      final originalTax = double.tryParse(item.taxAmount ?? '0') ?? 0;
      final taxPerUnit = originalQty > 0 ? originalTax / originalQty : 0;

      adjustedItems.add(
        item.copyWith(
          quantity: newQty,
          totalPrice: (unitPrice * newQty).toStringAsFixed(2),
          taxAmount: (taxPerUnit * newQty).toStringAsFixed(2),
        ),
      );
    }

    return adjustedItems;
  }

  String _calculateSavedTotalFromCartItems(
    List<OrderDetailsModelDataCartItem> cartItems,
  ) {
    double totalMrp = 0;
    double netTotal = 0;

    for (final item in cartItems) {
      final qty = item.quantity?.toDouble() ?? 0;
      final mrp = double.tryParse(item.mrp ?? '0') ?? 0;
      final totalPrice = double.tryParse(item.totalPrice ?? '0') ?? 0;
      totalMrp += mrp * qty;
      netTotal += totalPrice;
    }

    final saved = totalMrp - netTotal;
    return (saved < 0 ? 0 : saved).toStringAsFixed(2);
  }

  String _calculateNetExcTaxFromCartItems(
    List<OrderDetailsModelDataCartItem> cartItems,
  ) {
    final netExcTax = cartItems.fold<double>(0, (sum, item) {
      final totalPrice = double.tryParse(item.totalPrice ?? '0') ?? 0;
      final taxAmount = double.tryParse(item.taxAmount ?? '0') ?? 0;
      return sum + (totalPrice - taxAmount);
    });

    return netExcTax.toStringAsFixed(2);
  }

  String _calculateTotalFromCartItems(
    List<OrderDetailsModelDataCartItem> cartItems,
  ) {
    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item.totalPrice ?? '0') ?? 0),
    );
    return total.toStringAsFixed(2);
  }

  double? _calculateTotalTaxFromCartItems(
    List<OrderDetailsModelDataCartItem> cartItems,
  ) {
    final totalTax = cartItems.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item.taxAmount ?? '0') ?? 0),
    );
    return totalTax > 0 ? totalTax : null;
  }

  Future<bool> _executeOrderPrint(
    BuildContext context,
    OrderDetailsModel orderDetails,
    PrintMode mode, {
    bool useCheckoutBalanceFields = false,
    double? checkoutOldBalance,
    double? checkoutTotalPaid,
    bool checkoutIsDefaultCustomer = false,
  }) async {
    final cart = orderDetails.data!.cart!;
    final orderReturns = orderDetails.data?.orderReturns;

    if (mode == PrintMode.returnOnly) {
      if (!_hasOrderReturns(orderReturns) || !context.mounted) {
        return false;
      }

      final customerBalance = () {
        if (orderDetails.data?.orderProps == null) return null;
        try {
          final balanceProp = orderDetails.data!.orderProps!.firstWhere(
            (prop) => prop.propsCode == 'BALANCE',
            orElse: () => OrderDetailsModelDataOrderProp(),
          );
          return balanceProp.propsValue?.toString();
        } catch (_) {
          return null;
        }
      }();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnBillPrintPage(
            returnItems: orderReturns!.returnItems!,
            returnTotalAmount: orderReturns.returnTotalAmount ?? '0.00',
            storeName: cart.storeName,
            orderDate: orderDetails.data?.orderDate ?? '',
            orderNumber: orderDetails.data?.orderNumber ?? '',
            customerName: orderDetails.data?.customerDetails?.name,
            customerPhone: orderDetails.data?.customerDetails?.phone,
            customerEmail: orderDetails.data?.customerDetails?.email,
            customerAddress: orderDetails.data?.getCustomerAddressForDisplay(),
            customerBalance: customerBalance,
          ),
        ),
      );
      return true;
    }

    final isSalesOnly = mode == PrintMode.salesOnly;
    final cartItems = isSalesOnly
        ? _adjustCartItemsForSalesOnly(
            cart.cartItems!,
            orderReturns!.returnItems!,
          )
        : cart.cartItems!;

    if (cartItems.isEmpty) {
      return false;
    }

    final formattedTotal = isSalesOnly
        ? _calculateTotalFromCartItems(cartItems)
        : orderDetails.data?.cart?.priceSummary?.netPayable?.toString() ??
            orderDetails.data?.cart?.priceSummary?.netTotal.toString() ??
            '0.00';
    final savedTotal = isSalesOnly
        ? _calculateSavedTotalFromCartItems(cartItems)
        : orderDetails.data?.cart?.priceSummary?.savedTotal.toString() ??
            '0.00';

    final storeName = cart.storeName ?? '';
    final orderDate = orderDetails.data?.orderDate ?? '';

    final customerName = orderDetails.data?.customerDetails?.name;
    final customerPhone = orderDetails.data?.customerDetails?.phone;
    final customerEmail = orderDetails.data?.customerDetails?.email;
    final customerAddress = orderDetails.data?.getCustomerAddressForDisplay();
    final customerAlternatePhone =
        orderDetails.data?.customerDetails?.alternatePhone;
    final customerVatNumber = orderDetails.data?.kycInfo?.vatNumber;
    final customerCrNumber = orderDetails.data?.kycInfo?.crNumber;
    final customerType = orderDetails.data?.customerDetails?.customerType;

    final paymentMethod =
        orderDetails.data?.paymentDetails?.paymentMethod ?? 'N/A';
    final Map<String, dynamic>? paymentBreakdown = orderDetails.data?.payments;

    double? paidAmount;
    if (paymentBreakdown != null) {
      final totalPaid = paymentBreakdown.values.fold<double>(
        0.0,
        (sum, val) =>
            sum +
            (val is num
                ? val.toDouble()
                : double.tryParse(val.toString()) ?? 0.0),
      );
      if (totalPaid > 0) paidAmount = totalPaid;
    }

    String? orderComment;
    double? customerOldBalance;
    double? customerCurrentBalance;
    if (orderDetails.data?.orderProps != null) {
      try {
        final commentProp = orderDetails.data!.orderProps!.firstWhere(
          (prop) => prop.propsCode == 'COMMENT',
          orElse: () => OrderDetailsModelDataOrderProp(),
        );
        orderComment = commentProp.propsValue;
      } catch (_) {}
    }

    if (useCheckoutBalanceFields && checkoutTotalPaid != null) {
      final receiptBalance = ReceiptCustomerBalance.compute(
        isDefaultCustomer: checkoutIsDefaultCustomer,
        customerBalance: checkoutOldBalance,
        cartTotal: double.tryParse(formattedTotal) ?? 0.0,
        totalPaid: checkoutTotalPaid,
      );
      customerOldBalance = receiptBalance.oldBalance;
      customerCurrentBalance = receiptBalance.currentBalance;
    } else if (orderDetails.data?.orderProps != null) {
      try {
        final balanceProp = orderDetails.data!.orderProps!.firstWhere(
          (prop) => prop.propsCode == 'BALANCE',
          orElse: () => OrderDetailsModelDataOrderProp(),
        );
        customerCurrentBalance =
            double.tryParse(balanceProp.propsValue?.toString() ?? '');
      } catch (_) {}
    }

    final deliveryMethod = orderDetails.data?.deliveryMethodName;
    final netExcTax = isSalesOnly
        ? _calculateNetExcTaxFromCartItems(cartItems)
        : orderDetails.data?.cart?.priceSummary?.netExcTax?.toString();
    final apiTotalTax = isSalesOnly
        ? _calculateTotalTaxFromCartItems(cartItems)
        : orderDetails.data?.priceSummary?.totalTax?.toDouble();
    final effectiveOrderReturns = isSalesOnly ? null : orderReturns;
    final documentConfigType = mode == PrintMode.combined &&
            _hasOrderReturns(orderReturns)
        ? 'Sales and Return Bill'
        : 'Bill';

    if (!context.mounted) return false;

    final isDefaultCustomer = useCheckoutBalanceFields
        ? (checkoutIsDefaultCustomer ||
            _isDefaultCustomerPhone(context, customerPhone))
        : _isDefaultCustomerPhone(context, customerPhone);

    final autoPrintSuccess = await PrintPage.autoPrint(
      context,
      storeName: storeName,
      cartItems: cartItems,
      formattedTotal: formattedTotal,
      savedTotal: savedTotal,
      discountAmount:
          orderDetails.data!.priceSummary?.discount?.toString() ?? '0.00',
      orderDate: orderDate,
      orderNumber: orderDetails.data!.orderNumber ?? '',
      tokenNumber: orderDetails.data?.tokenNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      customerAlternatePhone: customerAlternatePhone,
      customerVatNumber: customerVatNumber,
      customerCrNumber: customerCrNumber,
      customerType: customerType,
      paymentMethod: paymentMethod,
      paymentBreakdown: paymentBreakdown,
      orderComment: orderComment,
      deliveryMethod: deliveryMethod,
      orderReturns: effectiveOrderReturns,
      paidAmount: paidAmount,
      customerOldBalance: customerOldBalance,
      customerCurrentBalance: customerCurrentBalance,
      isDefaultCustomer: isDefaultCustomer,
      netExcTax: netExcTax,
      apiTotalTax: apiTotalTax,
      documentConfigType: documentConfigType,
    );

    if (!autoPrintSuccess && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: cartItems,
            formattedTotal: formattedTotal,
            savedTotal: savedTotal,
            discountAmount:
                orderDetails.data!.priceSummary?.discount?.toString() ??
                    '0.00',
            orderDate: orderDate,
            orderNumber: orderDetails.data!.orderNumber ?? '',
            tokenNumber: orderDetails.data?.tokenNumber,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            customerAlternatePhone: customerAlternatePhone,
            customerVatNumber: customerVatNumber,
            customerCrNumber: customerCrNumber,
            customerType: customerType,
            paymentMethod: paymentMethod,
            paymentBreakdown: paymentBreakdown,
            orderComment: orderComment,
            deliveryMethod: deliveryMethod,
            orderReturns: effectiveOrderReturns,
            paidAmount: paidAmount,
            customerOldBalance: customerOldBalance,
            customerCurrentBalance: customerCurrentBalance,
            isDefaultCustomer: isDefaultCustomer,
            netExcTax: netExcTax,
            apiTotalTax: apiTotalTax,
            documentConfigType: documentConfigType,
          ),
        ),
      );
    }

    return autoPrintSuccess;
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
            'product_unit': item.product.unit ?? '',
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
          customerType: savedOrder.customerType,
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
                customerType: savedOrder.customerType,
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
          'product_unit': item.product.unit ?? '',
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
