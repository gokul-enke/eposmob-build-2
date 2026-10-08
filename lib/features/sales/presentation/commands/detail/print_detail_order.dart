import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_order_detail_controller.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/services/print_service.dart';

import 'detail_command_helpers.dart';

Future<void> printDetailOrder(BuildContext context,
    SalesOrderDetailController controller, SalesPageServices services) async {
  final orderDetailsModelData = controller.data;
  final customerDetails = controller.customer;

  final cartItems = controller.items;

  final orderNumber = controller.orderNumber;
  final tokenNumber = controller.tokenNumber;

  if (orderDetailsModelData?.cart == null ||
      cartItems == null ||
      cartItems.isEmpty) {
    AppToast.error(context, 'sales_order_details.msg_no_print_data'.tr);
    return;
  }

  String? formattedTotal =
      orderDetailsModelData?.cart?.priceSummary?.netPayable?.toString() ??
          orderDetailsModelData?.cart?.priceSummary?.netTotal?.toString() ??
          "0.00";
  String? savedTotal =
      orderDetailsModelData?.cart?.priceSummary?.savedTotal?.toString() ??
          "0.00";
  String? discountAmount =
      orderDetailsModelData?.cart?.priceSummary?.discount?.toString() ?? "0.00";
  String storeName = orderDetailsModelData?.cart?.storeName ??
      'sales_order_details.label_store'.tr;
  String orderDate = orderDetailsModelData?.orderDate ?? "";

  String? customerName = customerDetails?.name;
  String? customerPhone = customerDetails?.phone;
  String? customerEmail = customerDetails?.email;
  String? customerAddress =
      orderDetailsModelData?.getCustomerAddressForDisplay();
  String? customerAlternatePhone = customerDetails?.alternatePhone;
  String? customerType = customerDetails?.customerType;
  String? paymentMethod = orderDetailsModelData?.paymentDetails?.paymentMethod;
  String? customerVatNumber = orderDetailsModelData?.kycInfo?.vatNumber;
  String? customerCrNumber = orderDetailsModelData?.kycInfo?.crNumber;
  String? deliveryMethod = orderDetailsModelData?.deliveryMethodName;

  String? orderComment;
  if (orderDetailsModelData?.orderProps != null) {
    try {
      final commentProp = orderDetailsModelData!.orderProps!.firstWhere(
        (prop) => prop.propsCode == "COMMENT",
        orElse: () => OrderDetailsModelDataOrderProp(),
      );
      orderComment = commentProp.propsValue;
    } catch (e) {
      debugPrint("Error extracting order comment: $e");
    }
  }

  // Paid amount excluding DEBIT / CREDIT / BALANCE ledger keys,
  // exactly as PrintService computes it.
  final double? paidAmount =
      PrintService.paidAmountFromPayments(orderDetailsModelData?.payments);

  // Customer ledger balance, as PrintService uses. The stale
  // order_props.BALANCE is deliberately not used.
  final double? customerCurrentBalance = customerDetails?.customerBalance;
  final String? deliveryPhone =
      orderDetailsModelData?.getDeliveryPhoneForDisplay();

  // Try auto-print with default printer first

  final _hasReturns =
      orderDetailsModelData?.orderReturns?.returnItems?.isNotEmpty ?? false;
  final autoPrintSuccess = await PrintPage.autoPrint(
    context,
    storeName: storeName,
    cartItems: cartItems,
    formattedTotal: formattedTotal,
    savedTotal: savedTotal,
    discountAmount: discountAmount,
    orderDate: orderDate,
    orderNumber: orderNumber,
    tokenNumber: tokenNumber,
    customerName: customerName,
    customerPhone: customerPhone,
    customerEmail: customerEmail,
    customerAddress: customerAddress,
    customerAlternatePhone: customerAlternatePhone,
    paymentMethod: paymentMethod,
    paymentBreakdown: orderDetailsModelData?.payments,
    customerVatNumber: customerVatNumber,
    customerCrNumber: customerCrNumber,
    customerType: customerType,
    orderComment: orderComment,
    deliveryMethod: deliveryMethod,
    deliveryPhone: deliveryPhone,
    orderReturns: orderDetailsModelData?.orderReturns,
    paidAmount: paidAmount,
    customerCurrentBalance: customerCurrentBalance,
    isDefaultCustomer: isDetailDefaultCustomerPhone(customerPhone, services),
    netExcTax: orderDetailsModelData?.cart?.priceSummary?.netExcTax?.toString(),
    documentConfigType: _hasReturns ? 'Sales and Return Bill' : 'Bill',
    apiTotalTax: orderDetailsModelData?.priceSummary?.totalTax?.toDouble(),
  );

  // Only show print page if auto-print failed
  if (!autoPrintSuccess && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPage(
          storeName: storeName,
          cartItems: cartItems,
          formattedTotal: formattedTotal,
          savedTotal: savedTotal,
          discountAmount: discountAmount,
          orderDate: orderDate,
          orderNumber: orderNumber,
          tokenNumber: tokenNumber,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          customerAddress: customerAddress,
          customerAlternatePhone: customerAlternatePhone,
          paymentMethod: paymentMethod,
          paymentBreakdown: orderDetailsModelData?.payments,
          customerVatNumber: customerVatNumber,
          customerCrNumber: customerCrNumber,
          customerType: customerType,
          orderComment: orderComment,
          deliveryMethod: deliveryMethod,
          deliveryPhone: deliveryPhone,
          orderReturns: orderDetailsModelData?.orderReturns,
          paidAmount: paidAmount,
          customerCurrentBalance: customerCurrentBalance,
          isDefaultCustomer:
              isDetailDefaultCustomerPhone(customerPhone, services),
          netExcTax:
              orderDetailsModelData?.cart?.priceSummary?.netExcTax?.toString(),
          documentConfigType: _hasReturns ? 'Sales and Return Bill' : 'Bill',
          apiTotalTax:
              orderDetailsModelData?.priceSummary?.totalTax?.toDouble(),
        ),
      ),
    );
  }
}
