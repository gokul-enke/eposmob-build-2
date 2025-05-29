import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                          IconButton(
                                            icon:
                                                const Icon(Icons.print, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _printOrder(order),
                                            color: ColorManager.kPrimaryColor,
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
                                      const Spacer(),
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
                                          Text(
                                            '₹${order.total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: ColorManager.kPrimaryColor,
                                            ),
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
    final DateTime dateTime = DateTime.parse(isoDateString);
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    return formatter.format(dateTime);
  }

  String _formatTime(String isoDateString) {
    final DateTime dateTime = DateTime.parse(isoDateString);
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(dateTime);
  }

  void _printOrder(SavedOrder order) {
    try {
      // Convert SavedOrder items to the format expected by PrintPage
      List<Map<String, dynamic>> cartItems = [];

      for (var item in order.items) {
        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': (item.product.mrp?.toString() ?? '0.00'),
          'quantity': item.quantity.toString(),
          'unitPrice': (item.price?.toString() ??
              item.product.price?.price?.toString() ??
              '0.00'),
          'totalPrice': ((item.price ?? (item.product.price?.price ?? 0.0)) *
                  item.quantity)
              .toString(),
        });
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: "SOUQ POINT",
            cartItems: cartItems,
            formattedTotal: order.total.toString(),
            savedTotal: "0.00", // Adjust if you track discounts
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

      // Prepare items for API
      List<Map<String, dynamic>> items = [];
      for (var item in order.items) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price,
        });
      }

      bool orderProcessed = false;

      try {
        // Call API to add order and WAIT for completion
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final response = await cartProvider.addToOrderAPI(
          items: items,
          cartIds: 0, // Default cart ID as we're syncing saved orders
          accessToken: accessToken,
          transactionId: order.orderNumber,
          totalPrice: order.total.toString(),
          customerPhone: order.customerPhone ?? "",
          paymentMethod: "CASH", // Default payment method
          paidAmount: order.total.toString(),
          balanceAmount: "0.0",
          comment: order.comment,
          deliveryMethodId: "1", // Default delivery method
          status: "confirmed",
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
