import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';

class CustomerPurchaseHistoryModal extends StatefulWidget {
  final GetProduct product;
  final List<CustomerPurchaseItem> purchaseHistory;
  final String customerName;

  const CustomerPurchaseHistoryModal({
    Key? key,
    required this.product,
    required this.purchaseHistory,
    required this.customerName,
  }) : super(key: key);

  @override
  State<CustomerPurchaseHistoryModal> createState() =>
      _CustomerPurchaseHistoryModalState();
}

class _CustomerPurchaseHistoryModalState
    extends State<CustomerPurchaseHistoryModal> {
  int? _focusedRowActionIndex;
  bool _closeFocused = false;
  bool _useCurrentFocused = false;
  bool _cancelFocused = false;

  @override
  Widget build(BuildContext context) {
    debugPrint("🏪 CustomerPurchaseHistoryModal: Building modal");
    debugPrint("  - Product: ${widget.product.productName}");
    debugPrint("  - Customer: ${widget.customerName}");
    debugPrint("  - History count: ${widget.purchaseHistory.length}");

    for (int i = 0; i < widget.purchaseHistory.length; i++) {
      final item = widget.purchaseHistory[i];
      debugPrint(
          "  - Record $i: Price=${item.price}, Qty=${item.quantity}, Date=${item.date}");
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Customer Purchase History',
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s16,
                            0.21,
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customer: ${widget.customerName}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.21,
                            ColorManager.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Product: ${widget.product.productName}',
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s14,
                            0.21,
                            ColorManager.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: Focus(
                      onFocusChange: (v) => setState(() => _closeFocused = v),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _closeFocused
                                ? Colors.orange
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            debugPrint("🏪 User clicked close (X) button");
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Purchase history list
              Text(
                'Last ${widget.purchaseHistory.length} Purchase${widget.purchaseHistory.length != 1 ? 's' : ''}:',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s16,
                  0.19,
                  ColorManager.textColor,
                ),
              ),

              const SizedBox(height: 12),

              // Table header
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Order #',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.15,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.15,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.15,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Price',
                        textAlign: TextAlign.center,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.15,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Action',
                        textAlign: TextAlign.center,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.15,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Purchase history items
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.purchaseHistory.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.purchaseHistory[index];
                    final isEven = index % 2 == 0;

                    return FocusTraversalOrder(
                      order: NumericFocusOrder(20 + (index * 2).toDouble()),
                      child: Focus(
                        canRequestFocus: true,
                        skipTraversal: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          color: isEven ? Colors.grey.shade50 : Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item.orderNumber ?? 'N/A',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.15,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  DateHelper.formatISODate(item.date),
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s12,
                                    0.15,
                                    Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  item.quantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s12,
                                    0.15,
                                    ColorManager.kPrimaryColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  AmountHelper.formatAmount(item.price),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s12,
                                    0.15,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: FocusTraversalOrder(
                                    order: NumericFocusOrder(
                                        21 + (index * 2).toDouble()),
                                    child: Focus(
                                      onFocusChange: (v) {
                                        if (v) {
                                          setState(() =>
                                              _focusedRowActionIndex = index);
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                _focusedRowActionIndex == index
                                                    ? Colors.orange
                                                    : Colors.transparent,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            debugPrint(
                                                "🏪 User selected historical purchase:");
                                            debugPrint(
                                                "  - Price: ${item.price} (string) → ${item.priceValue} (double) - WILL BE USED");
                                            debugPrint(
                                                "  - Quantity: ${item.quantity} (string) → NOT USED (quantity will remain 1)");
                                            debugPrint(
                                                "  - Order: ${item.orderNumber}");
                                            debugPrint(
                                                "  - Returning to ProductCartHelper...");

                                            Navigator.of(context).pop({
                                              'price': item.priceValue,
                                              'orderNumber': item.orderNumber,
                                              'useCurrentPrice': false,
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ColorManager.kPrimaryColor,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            minimumSize: const Size(60, 28),
                                          ),
                                          child: Text(
                                            'Use This',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s10,
                                              0.12,
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FocusTraversalOrder(
                        order: NumericFocusOrder(
                            1000 + widget.purchaseHistory.length.toDouble()),
                        child: Focus(
                          onFocusChange: (v) =>
                              setState(() => _useCurrentFocused = v),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _useCurrentFocused
                                    ? Colors.orange
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton(
                              onPressed: () {
                                debugPrint(
                                    "🏪 User clicked 'Use Current Price' button");
                                Navigator.of(context).pop({
                                  'useCurrentPrice': true,
                                });
                              },
                              child: Text(
                                'Use Current Price',
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s14,
                                  0.18,
                                  ColorManager.kPrimaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FocusTraversalOrder(
                        order: NumericFocusOrder(
                            1001 + widget.purchaseHistory.length.toDouble()),
                        child: Focus(
                          onFocusChange: (v) =>
                              setState(() => _cancelFocused = v),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _cancelFocused
                                    ? Colors.orange
                                    : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                debugPrint("🏪 User clicked 'Cancel' button");
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: Text(
                                'Cancel',
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s14,
                                  0.18,
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
