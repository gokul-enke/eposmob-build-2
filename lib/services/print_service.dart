import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class PrintService {
  const PrintService();

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

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: storeName,
            cartItems: cart!.cartItems!,
            formattedTotal: formattedTotal,
            savedTotal: savedTotal,
            discountAmount:
                orderDetails.data!.priceSummary?.discount?.toString() ?? '0.00',
            orderDate: orderDate,
            orderNumber: orderDetails.data!.orderNumber ?? '',
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
          ),
        ),
      );
    } catch (_) {
      // Swallow errors; original code logged and continued
    }
  }

  /// Print a locally saved order (offline/confirmed in local storage)
  Future<void> printSavedOrder(BuildContext context, SavedOrder savedOrder) async {
    try {
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

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: "SOUQ POINT",
            cartItems: cartItems,
            formattedTotal: netTotal.toString(),
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
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error printing saved order: ${error.toString()}");
    }
  }
}
