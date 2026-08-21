import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart'; // Added import
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page.dart';
import 'package:pos_machine/features/billing/presentation/widgets/pos_security_key_dialog.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

/// A widget to display saved orders in a grid layout with new order button at top
class HorizontalSavedOrdersView extends StatefulWidget {
  final Function(String) onOrderSelected;
  final Future<void> Function()? onNewOrderPressed;
  final bool isBusy;
  final bool autofocus;
  final int focusRequestId;

  const HorizontalSavedOrdersView({
    Key? key,
    required this.onOrderSelected,
    this.onNewOrderPressed,
    this.isBusy = false,
    this.autofocus = false,
    this.focusRequestId = 0,
  }) : super(key: key);

  @override
  State<HorizontalSavedOrdersView> createState() =>
      _HorizontalSavedOrdersViewState();
}

class _HorizontalSavedOrdersViewState extends State<HorizontalSavedOrdersView> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _ordersGridFocusNode = FocusNode();
  int _focusedOrderIndex = 0;

  @override
  void initState() {
    super.initState();
    _ordersGridFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestGridFocusIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant HorizontalSavedOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus && widget.focusRequestId != oldWidget.focusRequestId) {
      _requestGridFocusIfNeeded();
    }
  }

  void _requestGridFocusIfNeeded() {
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ordersGridFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ordersGridFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleOrdersGridKey(
      KeyEvent event, List<SavedOrder> savedOrders) {
    if (event is! KeyDownEvent || savedOrders.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final index = _focusedOrderIndex.clamp(0, savedOrders.length - 1).toInt();
      if (!widget.isBusy) {
        widget.onOrderSelected(savedOrders[index].id);
      }
      return KeyEventResult.handled;
    }

    int? delta;
    if (key == LogicalKeyboardKey.arrowRight) {
      delta = 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      delta = -1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      delta = 2;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      delta = -2;
    }

    if (delta == null) {
      return KeyEventResult.ignored;
    }

    setState(() {
      _focusedOrderIndex = (_focusedOrderIndex + delta!)
          .clamp(0, savedOrders.length - 1)
          .toInt();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        return Container(
          // Remove fixed height and let it expand naturally
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildNewOrderButton(context, provider),
              const SizedBox(height: 12),
              Expanded(
                child: provider.savedOrders.isEmpty
                    ? _buildEmptyState()
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                          },
                        ),
                        child: Focus(
                          focusNode: _ordersGridFocusNode,
                          autofocus: widget.autofocus,
                          onKeyEvent: (node, event) =>
                              _handleOrdersGridKey(event, provider.savedOrders),
                          child: GridView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 250, // Maximum card width
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.45, // Width/height ratio
                            ),
                            itemCount: provider.savedOrders.length,
                            itemBuilder: (context, index) {
                              final order = provider.savedOrders[index];
                              final focusedIndex = _focusedOrderIndex
                                  .clamp(0, provider.savedOrders.length - 1)
                                  .toInt();
                              return _buildSavedOrderCard(
                                context,
                                provider,
                                order,
                                isKeyboardFocused:
                                    _ordersGridFocusNode.hasFocus &&
                                        index == focusedIndex,
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewOrderButton(
      BuildContext context, LocalProductProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: BuildBoxShadowContainer(
        circleRadius: 8,
        color: Colors.white,
        child: InkWell(
          onTap: () async {
            if (widget.isBusy) {
              return;
            }

            if (widget.onNewOrderPressed != null) {
              await widget.onNewOrderPressed!();
              return;
            }

            debugPrint("===== NEW ORDER (+) BUTTON PRESSED =====");
            debugPrint("🔄 Current state:");
            debugPrint("  - Current order ID: ${provider.currentOrder?.id}");
            debugPrint(
                "  - Current order number: ${provider.currentOrder?.orderNumber}");
            debugPrint("  - Cart items count: ${provider.cartItems.length}");

            // If currently editing an order and cart has items, update it
            if (provider.currentOrder != null &&
                provider.cartItems.isNotEmpty) {
              debugPrint(
                  "📝 Currently editing order ${provider.currentOrder!.orderNumber} with items in cart");

              // Get current values from billing page to preserve customer info
              final billingPageState =
                  context.findAncestorStateOfType<BillingPageState>();
              if (billingPageState != null) {
                debugPrint("💾 Updating current order before creating new one");
                debugPrint(
                    "  - Will save with all current customer and payment info");
                debugPrint(
                    "  - Current order ID: ${provider.currentOrder!.id}");
                debugPrint(
                    "  - Current order phone before save: ${provider.currentOrder!.customerPhone}");
                // Call the billing page's save method to properly save with current customer info
                await billingPageState.saveCurrentOrder();
                debugPrint(
                    "  - Current order phone after save: ${provider.currentOrder?.customerPhone}");
              } else {
                // Fallback - update with null values (not ideal but better than losing the order)
                debugPrint(
                    "⚠️ Could not find billing page state, updating with minimal info");
                provider.updateSavedOrder(
                  provider.currentOrder!.id,
                  context: context,
                );
              }
            }

            // If cart has items, save as new order
            else if (provider.cartItems.isNotEmpty) {
              // Get current values from billing page to preserve customer info
              final billingPageState =
                  context.findAncestorStateOfType<BillingPageState>();
              if (billingPageState != null) {
                debugPrint("💾 Saving new order with current customer info");
                // Call the billing page's save method to properly save with current customer info
                await billingPageState.saveCurrentOrder();
              } else {
                // Fallback - save without customer info (not ideal)
                debugPrint(
                    "⚠️ Could not find billing page state, saving without customer info");
                try {
                  provider.saveCurrentCartAsOrder();
                  showScaffold(
                    context: context,
                    message: "Order Saved Successfully",
                  );
                } catch (e) {
                  debugPrint("Error saving order: $e");
                }
              }
            }

            // Clear cart and reset current order
            debugPrint("🧹 Clearing cart and resetting for new order");
            provider.clearCart();

            // **FIX: Trigger the billing page to reset to default sales executive**
            // Find the billing page state and call the reset methods
            final billingPageState =
                context.findAncestorStateOfType<BillingPageState>();
            if (billingPageState != null) {
              debugPrint("✅ Found BillingPageState, calling reset method");
              debugPrint("  - This will reset to default sales executive");
              debugPrint("  - This will clear all form fields");

              // Call the public method to reset to default sales executive
              billingPageState.resetToDefaultSalesExecutive();

              showScaffold(
                context: context,
                message: "New Order - Reset to default sales executive",
              );
            } else {
              debugPrint("⚠️ BillingPageState not found, manual rebuild");
              (context as Element).markNeedsBuild();
            }

            debugPrint("===== NEW ORDER (+) BUTTON COMPLETE =====");
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle,
                  size: 24,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'common.create_new_order'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedOrderCard(
      BuildContext context, LocalProductProvider provider, SavedOrder order,
      {bool isKeyboardFocused = false}) {
    String time = DateHelper.formatToISOTimeOnlyFromISO(order.createdAt);
    bool isSelected = provider.currentOrder?.id == order.id;

    debugPrint(
        "SavedOrder ${order.orderNumber} raw createdAt: ${order.createdAt}");
    debugPrint("SavedOrder ${order.orderNumber} formatted time: $time");

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 200, // Minimum card width
        maxWidth: 250, // Maximum card width
      ),
      child: BuildBoxShadowContainer(
        circleRadius: 8,
        color: isSelected ? Colors.white : Colors.white,
        border: isKeyboardFocused
            ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
            : isSelected
                ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
                : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        child: InkWell(
          onTap: widget.isBusy ? null : () => widget.onOrderSelected(order.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected
                              ? ColorManager.kPrimaryColor
                              : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Amount and items count row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Consumer<AppSettingsProvider>(
                        builder: (context, settings, _) {
                          final currency =
                              settings.appSettings?.currency ?? 'INR';
                          return Text(
                            "$currency ${order.total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                            maxLines: 1,
                          );
                        },
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(
                        "${order.items.length} ${'common.items'.tr}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () async {
                        await const PrintService()
                            .printSavedOrder(context, order);
                      },
                      icon: const Icon(Icons.print, size: 20),
                      color: Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      key: ValueKey('delete_saved_order_${order.id}'),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context, provider, order);
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: ColorManager.kButtonRed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'common.no_saved_orders'.tr,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'common.create_first_order'.tr,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, LocalProductProvider provider, SavedOrder order) {
    return _confirmAndDeleteSavedOrder(
      context,
      provider,
      order,
    );
  }

  Future<void> _confirmAndDeleteSavedOrder(
    BuildContext context,
    LocalProductProvider provider,
    SavedOrder order,
  ) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      title: "Delete Order",
      itemName: order.orderNumber,
      message: "This order will be permanently removed from your saved orders.",
      warningIcon: Icons.receipt_long_outlined,
      onDelete: () {},
    );

    if (confirmed != true || !mounted || !context.mounted) return;
    if (!await PosSecurityKeyDialog.verify(
      context,
      action: 'delete this saved order',
    )) {
      return;
    }
    if (!mounted || !context.mounted) return;

    provider.deleteSavedOrder(order.id);
    showScaffold(
      context: context,
      message: "Order deleted successfully",
    );
  }
}
