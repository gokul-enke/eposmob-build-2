import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/screens/print/print.dart';

import '../../sharing/sales_page_services.dart';
import '../detail/detail_command_helpers.dart';

Future<void> printMobileOrder(
    BuildContext context,
    ListOrderModelData order,
    SalesPageServices services,
    Function(ListOrderModelData) onSharePDF,
    Function(ListOrderModelData) onShareWhatsApp) async {
  try {
    String ordersId = order.orderNumber.toString();
    String? accessToken = services.auth.token;

    final OrderDetailsresponse = await services.sales
        .listOrderDetails(context, ordersId, accessToken ?? "");
    if (!context.mounted) return;
    if (!context.mounted) return;

    if (OrderDetailsresponse["status"] == "success") {
      OrderDetailsModel orderDetails =
          OrderDetailsModel.fromJson(OrderDetailsresponse);

      String? formattedTotal =
          orderDetails.data?.cart?.priceSummary?.netPayable?.toString() ??
              orderDetails.data?.cart?.priceSummary?.netTotal.toString();
      String? savedTotal =
          orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

      String storeName = orderDetails.data!.cart!.storeName ?? "";
      String orderDate = orderDetails.data!.orderDate ?? "";

      String? customerName = orderDetails.data?.customerDetails?.name;
      String? customerPhone = orderDetails.data?.customerDetails?.phone;
      String? customerEmail = orderDetails.data?.customerDetails?.email;
      String? customerAddress =
          orderDetails.data?.getCustomerAddressForDisplay();
      String? customerAlternatePhone =
          orderDetails.data?.customerDetails?.alternatePhone;
      String? customerType = orderDetails.data?.customerDetails?.customerType;
      String? paymentMethod = orderDetails.data?.paymentDetails?.paymentMethod;

      String? orderComment;
      if (orderDetails.data?.orderProps != null) {
        try {
          final commentProp = orderDetails.data!.orderProps!.firstWhere(
            (prop) => prop.propsCode == "COMMENT",
            orElse: () => OrderDetailsModelDataOrderProp(),
          );
          orderComment = commentProp.propsValue;
        } catch (e) {
          debugPrint("Error extracting order comment: $e");
        }
      }

      double paidAmount = 0.0;
      if (orderDetails.data?.payments != null) {
        orderDetails.data!.payments!.forEach((key, value) {
          paidAmount += double.tryParse(value.toString()) ?? 0.0;
        });
      }

      double? customerCurrentBalance;
      if (orderDetails.data?.orderProps != null) {
        try {
          final balanceProp = orderDetails.data!.orderProps!.firstWhere(
            (prop) => prop.propsCode == "BALANCE",
            orElse: () => OrderDetailsModelDataOrderProp(),
          );
          if (balanceProp.propsValue != null) {
            customerCurrentBalance =
                double.tryParse(balanceProp.propsValue.toString());
          }
        } catch (e) {
          debugPrint("Error extracting balance: $e");
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: orderDetails.data?.cart?.cartItems ?? [],
            formattedTotal: formattedTotal!,
            savedTotal: savedTotal!,
            discountAmount:
                orderDetails.data?.priceSummary?.discount?.toString() ?? "0.00",
            orderDate: DateHelper.formatInputToDisplay(orderDate),
            orderNumber: orderDetails.data!.customerReceiptNumber ?? ordersId,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            customerAlternatePhone: customerAlternatePhone,
            customerType: customerType,
            customerVatNumber: orderDetails.data?.kycInfo?.vatNumber,
            customerCrNumber: orderDetails.data?.kycInfo?.crNumber,
            paymentMethod: paymentMethod,
            paymentBreakdown: orderDetails.data?.payments,
            orderComment: orderComment,
            orderReturns: orderDetails.data?.orderReturns,
            paidAmount: paidAmount > 0 ? paidAmount : null,
            customerCurrentBalance: customerCurrentBalance,
            netExcTax:
                orderDetails.data?.cart?.priceSummary?.netExcTax?.toString(),
            isDefaultCustomer:
                isDetailDefaultCustomerPhone(customerPhone, services),
            documentConfigType: orderDetails.data?.orderReturns != null &&
                    (orderDetails.data?.orderReturns?.returnItems?.isNotEmpty ??
                        false)
                ? 'Sales and Return Bill'
                : 'Bill',
            apiTotalTax: orderDetails.data?.priceSummary?.totalTax?.toDouble(),
          ),
        ),
      );
    }
  } catch (error) {
    debugPrint(error.toString());
  }
}
