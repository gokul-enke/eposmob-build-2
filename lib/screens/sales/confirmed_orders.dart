import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/sales/widgets/confirmed_order_detail_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';

class ConfirmedOrdersScreen extends StatefulWidget {
  const ConfirmedOrdersScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmedOrdersScreen> createState() => _ConfirmedOrdersScreenState();
}

class _ConfirmedOrdersScreenState extends State<ConfirmedOrdersScreen> {
  bool isSyncing = false;
  int currentSyncIndex = 0;
  int totalOrdersToSync = 0;
  // Function to update dialog state from outside
  void Function(void Function())? _dialogSetState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BuildBoxShadowContainer(
        circleRadius: 7,
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Consumer<LocalProductProvider>(
                builder: (context, provider, child) {
                  final confirmedOrders = provider.confirmedOrders;

                  if (confirmedOrders.isEmpty) {
                    return const Center(
                      child: Text('No confirmed orders found'),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: confirmedOrders.length,
                          itemBuilder: (context, index) {
                            final order = confirmedOrders[index];
                            String formattedDate =
                                _formatDateTime(order.createdAt);
                            String formattedTime = _formatTime(order.createdAt);

                            return GestureDetector(
                              onTap: () {
                                _showOrderDetailsModal(context, order);
                              },
                              child: BuildBoxShadowContainer(
                                circleRadius: 8,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Order #${order.orderNumber}',
                                              style: buildCustomStyle(
                                                FontWeightManager.bold,
                                                FontSize.s14,
                                                0.21,
                                                ColorManager.kPrimaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.print,
                                                    size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _printOrder(order),
                                                color:
                                                    ColorManager.kPrimaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed: () =>
                                                    _showDeleteConfirmationDialog(
                                                        context, order),
                                                color: ColorManager.kButtonRed,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedTime,
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Display Delivery Date (optional)
                                      if (order.deliveryDate != null &&
                                          order.deliveryDate!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Delivery Date: ${DateHelper.formatToISODateOnlyFromISO(order.deliveryDate!)}',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.21,
                                            Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      // Display Delivery Time (optional)
                                      if (order.deliveryTime != null &&
                                          order.deliveryTime!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Delivery Time: ${order.deliveryTime!}',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.21,
                                            Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      // Show discount info if any discounts applied
                                      if ((order.flatDiscount != null &&
                                              order.flatDiscount! > 0) ||
                                          (order.percentageDiscount != null &&
                                              order.percentageDiscount! > 0) ||
                                          (order.couponId != null &&
                                              order.couponId!.isNotEmpty)) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.local_offer,
                                                size: 12, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Discount Applied',
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s10,
                                                0.21,
                                                Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Items: ${order.items.length}',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.21,
                                              Colors.grey,
                                            ),
                                          ),
                                          Consumer<AppSettingsProvider>(
                                            builder: (context,
                                                appSettingsProvider, child) {
                                              final currency =
                                                  appSettingsProvider
                                                          .appSettings
                                                          ?.currency ??
                                                      'INR';
                                              return Text(
                                                '$currency${order.total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: ColorManager
                                                      .kPrimaryColor,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String isoDateString) {
    return DateHelper.formatToISODateOnlyFromISO(isoDateString);
  }

  String _formatTime(String isoDateString) {
    return DateHelper.formatToISODateFromIST(isoDateString);
  }

  void _printOrder(SavedOrder order) {
    try {
      // Convert SavedOrder items to the format expected by PrintPage
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;

      for (var item in order.items) {
        // Calculate individual item values
        double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        double itemTotalPrice = itemPrice * item.quantity;

        // Add to totals for "You Saved" calculation
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

      // 🔧 FIX: Calculate "You Saved" using Option 3 approach
      double youSaved = totalMRP - netTotal;
      youSaved = youSaved > 0 ? youSaved : 0.0; // Ensure non-negative

      debugPrint("🖨️ OFFLINE ORDER PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - You Saved: $youSaved");

      // Use the stored total from order (already rounded when saved)
      double finalTotal = order.total;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: "SOUQ POINT",
            cartItems: cartItems,
            formattedTotal: finalTotal.toString(), // Use order's total
            savedTotal: youSaved.toString(),
            discountAmount: ((order.flatDiscount ?? 0.0) +
                    ((order.percentageDiscount ?? 0.0) > 0
                        ? (order.total *
                            (order.percentageDiscount ?? 0.0) /
                            100)
                        : 0.0))
                .toString(),
            orderDate: order.createdAt,
            orderNumber: order.orderNumber,
            isFromLocalStorage: true,
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error printing order: ${error.toString()}");
      showScaffoldError(
          context: context,
          message: "Failed to print order. Please try again.");
    }
  }

  void _showOrderDetailsModal(BuildContext context, SavedOrder order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmedOrderDetailModal(order: order);
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, SavedOrder order) {
    DeleteConfirmationDialog.show(
      context: context,
      title: "Delete Confirmed Order",
      itemName: order.orderNumber,
      message:
          "This confirmed order will be permanently removed from your local storage. This action cannot be undone.",
      warningIcon: Icons.receipt_long_outlined,
      warningIconColor: ColorManager.kButtonRed,
      deleteButtonText: "Delete",
      onDelete: () {
        // Delete the confirmed order from local storage
        final provider =
            Provider.of<LocalProductProvider>(context, listen: false);
        provider.deleteConfirmedOrder(order.id);

        // Show success message
        showScaffold(
          context: context,
          message: "Confirmed order deleted successfully",
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Confirmed Orders",
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomRoundButton(
                title: "Sync with Database",
                fct: () {
                  final provider =
                      Provider.of<LocalProductProvider>(context, listen: false);
                  if (provider.confirmedOrders.isEmpty) {
                    showScaffoldError(
                        context: context,
                        message: "No confirmed orders to sync");
                    return;
                  }
                  _syncConfirmedOrders(context);
                },
                fontSize: 12,
                height: 45,
                width: 200,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Syncs all confirmed orders with the database
  void _syncConfirmedOrders(BuildContext context) async {
    final provider = Provider.of<LocalProductProvider>(context, listen: false);

    // Create a copy of the orders list to avoid modification during iteration
    final List<SavedOrder> confirmedOrders =
        List.from(provider.confirmedOrders);

    debugPrint("Starting to sync ${confirmedOrders.length} orders");

    setState(() {
      isSyncing = true;
      currentSyncIndex = 0;
      totalOrdersToSync = confirmedOrders.length;
    });

    // Show a styled dialog that matches add_product_modal.dart
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Store the setState function to update dialog from outside
            _dialogSetState = setStateDialog;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width / 3,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Syncing Orders",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        // No close button since we don't want the user to cancel
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Uploading ${confirmedOrders.length} confirmed orders to the server. Please wait...",
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                ColorManager.kPrimaryColor),
                          ),
                          const SizedBox(height: 20),
                          // Display the correct count (current order being processed)
                          Text(
                            currentSyncIndex < totalOrdersToSync
                                ? 'Saving ${currentSyncIndex + 1} out of $totalOrdersToSync'
                                : 'Completed $currentSyncIndex out of $totalOrdersToSync',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: totalOrdersToSync > 0
                                ? currentSyncIndex / totalOrdersToSync
                                : 0,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                ColorManager.kPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Get auth token
    final authProvider = Provider.of<AuthModel>(context, listen: false);
    String? accessToken = authProvider.token;

    if (accessToken == null) {
      Navigator.of(context).pop(); // Close dialog
      showScaffoldError(
          context: context,
          message: "Authentication token not found. Please login again.");
      setState(() {
        isSyncing = false;
      });
      return;
    }

    int successCount = 0;
    int failureCount = 0;

    // Process each order one by one with proper async handling
    for (int i = 0; i < confirmedOrders.length; i++) {
      // Don't increment currentSyncIndex until after the API call completes
      if (_dialogSetState != null) {
        _dialogSetState!(() {
          // Update the display in the dialog but don't change currentSyncIndex yet
        });
      }

      final order = confirmedOrders[i];

      debugPrint(
          "Processing order ${i + 1}/${confirmedOrders.length}: ${order.orderNumber}");

      // Debug: Log the order data being synced
      debugPrint("💾 SYNC ORDER DATA:");
      debugPrint("  - Order Number: ${order.orderNumber}");
      debugPrint("  - Customer ID: ${order.customerId}");
      debugPrint("  - Customer Phone: ${order.customerPhone}");
      debugPrint("  - Payment Method: ${order.paymentMethod}");
      debugPrint("  - Paid Amount: ${order.paidAmount}");
      debugPrint("  - Balance Amount: ${order.balanceAmount}");
      debugPrint("  - Transaction ID: ${order.transactionId}");
      debugPrint("  - Coupon ID: ${order.couponId}");
      debugPrint("  - Delivery Method ID: ${order.deliveryMethodId}");
      debugPrint("  - Car Number: ${order.carNumber}");
      debugPrint("  - Status: ${order.status}");
      debugPrint("  - Total: ${order.total}");
      debugPrint("  - Flat Discount: ${order.flatDiscount}");
      debugPrint("  - Percentage Discount: ${order.percentageDiscount}");
      debugPrint("  - Coupon ID: ${order.couponId}");

      // Prepare items for API
      List<Map<String, dynamic>> items = [];
      for (var item in order.items) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
          'mrp': item.mrp, // 🔧 FIX: Include custom MRP in API call
        });
      }

      bool orderProcessed = false;

      try {
        // Handle multi-payment if stored as JSON
        String? paymentMethod = order.paymentMethod;
        String? paidAmount = order.paidAmount;
        List<String>? paymentMethods;
        List<Map<String, dynamic>>? paidMethods;

        if (paymentMethod != null && paymentMethod.startsWith('{')) {
          try {
            Map<String, dynamic> multiPaymentData = json.decode(paymentMethod);
            if (multiPaymentData['isMultiPayment'] == true) {
              // Extract multi-payment data
              paymentMethods =
                  List<String>.from(multiPaymentData['methods'] ?? []);
              Map<String, dynamic> amounts =
                  Map<String, dynamic>.from(multiPaymentData['amounts'] ?? {});

              paidMethods = [];
              if (amounts['CASH'] != null && amounts['CASH'] != "0") {
                paidMethods.add({
                  "method": "CASH",
                  "amount": double.tryParse(amounts['CASH']) ?? 0,
                });
              }
              if (amounts['CARD'] != null && amounts['CARD'] != "0") {
                paidMethods.add({
                  "method": "CARD",
                  "amount": double.tryParse(amounts['CARD']) ?? 0,
                });
              }
              if (amounts['UPI'] != null && amounts['UPI'] != "0") {
                paidMethods.add({
                  "method": "UPI",
                  "amount": double.tryParse(amounts['UPI']) ?? 0,
                });
              }

              // For multi-payment, set single payment fields to null
              paymentMethod = null;
              paidAmount = null;
            }
          } catch (e) {
            debugPrint("Error parsing multi-payment data during sync: $e");
            // Fallback to single payment
            paymentMethod = order.paymentMethod ?? "CASH";
            paidAmount = order.paidAmount ?? order.total.toString();
          }
        } else {
          // Single payment method
          paymentMethod = order.paymentMethod ?? "CASH";
          paidAmount = order.paidAmount ?? order.total.toString();
        }

        // Call API to add order and WAIT for completion
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final response = await cartProvider.addToOrderAPI(
          items: items,
          cartIds: 0, // Default cart ID as we're syncing saved orders
          accessToken: accessToken,
          // Use stored data from local order, with fallbacks if needed
          transactionId: order.transactionId ?? order.orderNumber,
          totalPrice: order.total.toString(),
          customerId: order.customerId,
          customerPhone: order.customerPhone ?? "",
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          paymentMethods: paymentMethods,
          paidMethods: paidMethods,
          balanceAmount: order.balanceAmount ?? "0.0",
          couponId: order.couponId,
          comment: order.comment,
          deliveryMethodId: order.deliveryMethodId ??
              "1", // Use stored delivery method or default
          carNumber: order.carNumber,
          status: order.status ?? "confirmed",
          // Include discount data from saved order
          flatDiscount: order.flatDiscount,
          percentageDiscount: order.percentageDiscount,
          discountAmount: (order.flatDiscount ?? 0.0) +
              ((order.percentageDiscount ?? 0.0) > 0
                  ? (order.total * (order.percentageDiscount ?? 0.0) / 100)
                  : 0.0),
          toCustomerCredit: order.toCustomerCredit,
        );

        // AFTER the API call completes, update the index
        setState(() {
          currentSyncIndex = i + 1; // Increment to next index AFTER processing
        });

        if (_dialogSetState != null) {
          _dialogSetState!(() {});
        }

        if (response != null && response["order_id"] != null) {
          // Order synced successfully, now delete it from local storage
          provider.deleteConfirmedOrder(order.id);
          successCount++;
          orderProcessed = true;
          debugPrint("Successfully synced order ${order.orderNumber}");
        } else {
          debugPrint("API error syncing order ${order.orderNumber}");
          failureCount++;
        }
      } catch (e) {
        // AFTER the API call fails, update the index
        setState(() {
          currentSyncIndex = i + 1; // Increment to next index even after error
        });

        if (_dialogSetState != null) {
          _dialogSetState!(() {});
        }

        debugPrint("Exception syncing order ${order.orderNumber}: $e");
        failureCount++;
      }

      // Log progress for debugging
      debugPrint(
          "Processed order ${i + 1}/${confirmedOrders.length}: ${orderProcessed ? 'SUCCESS' : 'FAILED'}");

      // Small delay to avoid overwhelming the API but AFTER the current order is processed
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Show remaining orders count in the logs (should be zero if all were processed)
    debugPrint(
        "After processing, remaining confirmed orders: ${provider.confirmedOrders.length}");

    // Wait a moment to show the completed status
    await Future.delayed(const Duration(seconds: 1));

    // Only now close the dialog
    if (mounted) {
      Navigator.of(context).pop();

      showScaffold(
          context: context,
          message:
              "Synced $successCount orders successfully${failureCount > 0 ? ", $failureCount failed" : ""}");
    }

    setState(() {
      isSyncing = false;
      _dialogSetState = null;
    });
  }
}
