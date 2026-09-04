import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/services/print_service.dart';
import 'package:provider/provider.dart';
import 'dart:convert'; // Added for json.decode

class ConfirmedOrderDetailModal extends StatelessWidget {
  final SavedOrder order;

  const ConfirmedOrderDetailModal({Key? key, required this.order})
      : super(key: key);

  /// Helper method to check if a phone number matches the default customer phone from app settings
  bool _isDefaultCustomerPhone(BuildContext context, String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  // Calculate total MRP from all order items
  double _calculateTotalMRP() {
    double totalMRP = 0.0;
    for (var item in order.items) {
      final mrp = item.mrp ?? item.product.mrp ?? 0.0;
      totalMRP += mrp * item.quantity;
    }
    return totalMRP;
  }

  // Calculate "You Saved" amount (Total MRP - Net Total)
  double _calculateYouSaved() {
    double totalMRP = _calculateTotalMRP();
    double netTotal = 0.0;
    for (var item in order.items) {
      final price = item.price ?? item.product.price?.price ?? 0.0;
      netTotal += price * item.quantity;
    }
    double youSaved = totalMRP - netTotal;
    return youSaved > 0 ? youSaved : 0.0;
  }

  double _calculateDiscountAmount() {
    final subtotal = order.items.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          ((item.price ?? item.product.price?.price ?? 0.0) * item.quantity),
    );

    final flatDiscount = order.flatDiscount ?? 0.0;
    final percentageValue = order.percentageDiscount ?? 0.0;
    final percentageDiscount = subtotal * percentageValue / 100;
    final totalDiscount = flatDiscount + percentageDiscount;

    if (totalDiscount > subtotal) {
      return subtotal;
    }

    return totalDiscount;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: 700,
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button (Fixed at top)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "kitchen.order_details".tr,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Order Information Card
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "confirmed_orders.order_info".tr,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                    "sales.order_number_hint".tr, "#${order.orderNumber}"),
                                const SizedBox(height: 8),
                                _buildInfoRow("confirmed_orders.customer_phone".tr,
                                    order.customerPhone ?? "confirmed_orders.na".tr),
                                const SizedBox(height: 8),
                                if (order.customerName != null &&
                                    order.customerName!.isNotEmpty) ...[
                                  _buildInfoRow(
                                      "sales.customer_name_hint".tr, order.customerName!),
                                  const SizedBox(height: 8),
                                ],
                                _buildInfoRow(
                                    "sales.date_col".tr, _formatDateTime(order.createdAt)),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                    "confirmed_orders.time".tr, _formatTime(order.createdAt)),
                                const SizedBox(height: 8),
                                _buildInfoRow("confirmed_orders.total_amount".tr,
                                    "$currency${order.total.toStringAsFixed(2)}"),
                                const SizedBox(height: 8),
                                _buildInfoRow("confirmed_orders.total_mrp".tr,
                                    "$currency${_calculateTotalMRP().toStringAsFixed(2)}"),
                                const SizedBox(height: 8),
                                _buildInfoRow("confirmed_orders.you_saved".tr,
                                    "$currency${_calculateYouSaved().toStringAsFixed(2)}",
                                    valueStyle: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    )),
                                // Display additional order details
                                if (order.deliveryMethod != null &&
                                    order.deliveryMethod!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                      "confirmed_orders.delivery_method".tr, order.deliveryMethod!),
                                ],
                                if (order.transactionId != null &&
                                    order.transactionId!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                      "confirmed_orders.transaction_id".tr, order.transactionId!),
                                ],
                                if (order.balanceAmount != null &&
                                    order.balanceAmount != "0.0" &&
                                    order.balanceAmount!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow("confirmed_orders.balance_amount".tr,
                                      "$currency${order.balanceAmount}",
                                      valueStyle: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ],
                                if (order.carNumber != null &&
                                    order.carNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow("confirmed_orders.car_number".tr, order.carNumber!,
                                      valueStyle: const TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ],
                                if (order.status != null &&
                                    order.status!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow("confirmed_orders.order_status".tr,
                                      UiCodeLabels.status(order.status),
                                      valueStyle: TextStyle(
                                        color: order.status!.toLowerCase() ==
                                                'confirmed'
                                            ? Colors.green
                                            : order.status!.toLowerCase() ==
                                                    'saved'
                                                ? Colors.orange
                                                : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                                // Display Discount Information
                                if ((order.flatDiscount != null &&
                                        order.flatDiscount! > 0) ||
                                    (order.percentageDiscount != null &&
                                        order.percentageDiscount! > 0)) ...[
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                   Text(
                                    "confirmed_orders.applied_discounts".tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (order.flatDiscount != null &&
                                      order.flatDiscount! > 0)
                                    _buildInfoRow("confirmed_orders.flat_discount".tr,
                                        "$currency${order.flatDiscount!.toStringAsFixed(2)}",
                                        valueStyle: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  if (order.percentageDiscount != null &&
                                      order.percentageDiscount! > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildInfoRow("confirmed_orders.percentage_discount".tr,
                                        "${order.percentageDiscount!.toStringAsFixed(1)}%",
                                        valueStyle: const TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                  if (order.couponId != null &&
                                      order.couponId!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    _buildInfoRow(
                                        "confirmed_orders.coupon_code".tr, order.couponId!,
                                        valueStyle: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ],
                                // Display Payment Method(s)
                                if (order.paymentMethod != null) ...[
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  ConfirmedOrderDetailModal
                                      ._buildPaymentMethodInfo(
                                          order.paymentMethod!,
                                          currency,
                                          context),
                                ],
                                if (order.deliveryDate != null &&
                                    order.deliveryDate!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                      "confirmed_orders.delivery_date".tr,
                                      DateHelper.formatToISODateOnlyFromISO(
                                          order.deliveryDate!)),
                                ],
                                if (order.deliveryTime != null &&
                                    order.deliveryTime!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                      "confirmed_orders.delivery_time".tr, order.deliveryTime!),
                                ],
                                if (order.comment != null &&
                                    order.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow("confirmed_orders.comment".tr, order.comment!),
                                ],
                                if (order.toCustomerCredit == true) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    "confirmed_orders.credit_applied".tr,
                                    "confirmed_orders.yes".tr,
                                    valueStyle: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Order Items Section
                        Text(
                          "confirmed_orders.order_items".tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Table with order items (now scrolls with everything else)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: DataTable(
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              dataTextStyle: const TextStyle(
                                color: Colors.black,
                              ),
                              horizontalMargin: 16,
                              columnSpacing: 24,
                              columns: [
                                DataColumn(label: Text('confirmed_orders.product'.tr)),
                                DataColumn(label: Text('billing.table_qty'.tr), numeric: true),
                                DataColumn(
                                    label: Text('billing.unit_price'.tr), numeric: true),
                                DataColumn(label: Text('billing.table_total'.tr), numeric: true),
                              ],
                              rows: order.items.map((item) {
                                double unitPrice = item.price ??
                                    item.product.price?.price ??
                                    0.0;
                                double totalPrice = unitPrice * item.quantity;

                                return DataRow(cells: [
                                  DataCell(Text(
                                    item.product.productName ??
                                        'Unknown Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  )),
                                  DataCell(Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(color: Colors.black),
                                  )),
                                  DataCell(Text(
                                    "$currency${unitPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(color: Colors.black),
                                  )),
                                  DataCell(Text(
                                    "$currency${totalPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Action Buttons (Fixed at bottom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomRoundButton(
                      fct: () => _printOrder(context),
                      title: "confirmed_orders.print_order".tr,
                      fontSize: FontSize.s12,
                      height: MediaQuery.of(context).size.height * .05,
                      width: 120,
                      boxColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                    ),
                    Row(
                      children: [
                        CustomRoundButton(
                          fct: () => _showDeleteConfirmationDialog(context),
                          title: "confirmed_orders.delete".tr,
                          fontSize: FontSize.s12,
                          height: MediaQuery.of(context).size.height * .05,
                          width: 80,
                          boxColor: ColorManager.kButtonRed,
                          borderColor: ColorManager.kButtonRed,
                          textColor: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        CustomRoundButton(
                          fct: () => Navigator.of(context).pop(),
                          title: "confirmed_orders.close".tr,
                          fontSize: FontSize.s12,
                          height: MediaQuery.of(context).size.height * .05,
                          width: 80,
                          boxColor: Colors.grey[300],
                          textColor: Colors.black,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildInfoRow(String label, String value,
      {TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            "$label:",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  static String _formatDateTime(String isoDateString) {
    return DateHelper.formatToISODateOnlyFromISO(isoDateString);
  }

  static String _formatTime(String isoDateString) {
    return DateHelper.formatToISODateFromIST(isoDateString);
  }

  void _printOrder(BuildContext context) async {
    try {
      await const PrintService().printSavedOrder(context, order);
      return;
/*
      // Convert SavedOrder items to the format expected by PrintPage
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;
      double totalTax = 0.0;

      for (var item in order.items) {
        // Calculate individual item values
        double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        double itemTotalPrice = itemPrice * item.quantity;
        double itemTax = (item.taxAmount ?? 0.0) * item.quantity;

        // Add to totals for "You Saved" calculation
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

      // 🔧 FIX: Calculate "You Saved" using Option 3 approach
      double youSaved = totalMRP - netTotal;
      youSaved = youSaved > 0 ? youSaved : 0.0; // Ensure non-negative
      double netExcTax = netTotal - totalTax;

      debugPrint("🖨️ OFFLINE ORDER MODAL PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - Total Tax: $totalTax");
      debugPrint("  - Net Exc Tax: $netExcTax");
      debugPrint("  - You Saved: $youSaved");

      // Get active store name
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final storeName = storeSession.activeStore?.storeName ?? "Store";

      final double discountAmount = _calculateDiscountAmount();

      // Get paid amount
      double? paidAmount = (double.tryParse(order.paidAmount ?? "0") ?? 0.0) > 0
          ? (double.tryParse(order.paidAmount ?? "0") ?? 0.0)
          : null;

      final double finalTotal = order.total;

      // Parse multi-payment JSON into human-readable names and breakdown
      final parsedPayment =
          PaymentHelper.parseLocalMultiPayment(context, order.paymentMethod);
      final String? displayPaymentMethod =
          parsedPayment?.paymentMethodDisplay ?? order.paymentMethod;
      final Map<String, dynamic>? paymentBreakdown =
          parsedPayment?.paymentBreakdown;

      // Try auto-print with default printer first
      debugPrint(
          "🖨️ Attempting auto-print for confirmed order #${order.orderNumber}");
      final autoPrintSuccess = await PrintPage.autoPrint(
        context,
        storeName: storeName,
        cartItems: cartItems,
        formattedTotal: finalTotal.toString(),
        savedTotal: youSaved.toString(), // 🔧 FIX: Use calculated "You Saved"
        discountAmount: discountAmount.toString(),
        orderDate: order.createdAt,
        orderNumber: order.orderNumber,
        isFromLocalStorage: true,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        paymentMethod: displayPaymentMethod,
        paymentBreakdown: paymentBreakdown,
        customerAlternatePhone: order.alternatePhone,
        customerVatNumber: order.customerVatNumber,
        customerCrNumber: order.customerCrNumber,
        customerType: order.customerType,
        orderComment: order.comment,
        deliveryMethod: order.deliveryMethod,
        paidAmount: paidAmount,
        isDefaultCustomer:
            _isDefaultCustomerPhone(context, order.customerPhone),
        netExcTax: netExcTax.toString(),
        documentConfigType: 'Bill',
      );

      // Only show print page if auto-print failed
      if (!autoPrintSuccess) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrintPage(
              storeName: storeName,
              cartItems: cartItems,
              formattedTotal: finalTotal.toString(),
              savedTotal:
                  youSaved.toString(), // 🔧 FIX: Use calculated "You Saved"
              discountAmount: discountAmount.toString(),
              orderDate: order.createdAt,
              orderNumber: order.orderNumber,
              isFromLocalStorage: true,
              customerName: order.customerName,
              customerPhone: order.customerPhone,
              paymentMethod: displayPaymentMethod,
              paymentBreakdown: paymentBreakdown,
              customerAlternatePhone: order.alternatePhone,
              customerVatNumber: order.customerVatNumber,
              customerCrNumber: order.customerCrNumber,
              customerType: order.customerType,
              orderComment: order.comment,
              deliveryMethod: order.deliveryMethod,
              paidAmount: paidAmount,
              isDefaultCustomer:
                  _isDefaultCustomerPhone(context, order.customerPhone),
              netExcTax: netExcTax.toString(),
              documentConfigType: 'Bill',
            ),
          ),
        );
      }
*/
    } catch (error) {
      debugPrint("Error printing order: ${error.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("confirmed_orders.failed_print".tr),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    DeleteConfirmationDialog.show(
      context: context,
      title: "confirmed_orders.delete_title".tr,
      itemName: order.orderNumber,
      message:
          "confirmed_orders.delete_message".tr,
      warningIcon: Icons.receipt_long_outlined,
      warningIconColor: ColorManager.kButtonRed,
      deleteButtonText: "confirmed_orders.delete".tr,
      onDelete: () {
        // Delete the confirmed order from local storage
        final provider =
            Provider.of<LocalProductProvider>(context, listen: false);
        provider.deleteConfirmedOrder(order.id);

        // Close the modal first
        Navigator.of(context).pop();

        // Show success message
        showScaffold(
          context: context,
          message: "confirmed_orders.delete_success".tr,
        );
      },
    );
  }

  /// Helper function to convert payment method ID or value to display name
  /// Uses BillingProvider to map numeric IDs to human-readable names.
  static String _getPaymentMethodDisplayName(
      String methodIdOrName, BuildContext? context) {
    // If it's a numeric ID, try to convert using BillingProvider
    if (RegExp(r'^\d+$').hasMatch(methodIdOrName) && context != null) {
      try {
        final billing = Provider.of<BillingProvider>(context, listen: false);
        if (methodIdOrName == billing.cashPaymentMethodId) return 'CASH';
        if (methodIdOrName == billing.cardPaymentMethodId) return 'CARD';
        if (methodIdOrName == billing.upiPaymentMethodId) return 'UPI';
        if (methodIdOrName == billing.codPaymentMethodId) return 'COD';
      } catch (_) {}
      // Fallback if BillingProvider lookup failed
      return 'confirmed_orders.payment_hash'.tr.replaceAll('@id', methodIdOrName);
    }
    // It's already a name (CASH, CARD, UPI, DEBIT, etc.)
    return methodIdOrName;
  }

  static Widget _buildPaymentMethodInfo(
      String paymentMethodJsonOrString, String currency, BuildContext context) {
    try {
      if (paymentMethodJsonOrString.startsWith('{') &&
          paymentMethodJsonOrString.endsWith('}')) {
        final Map<String, dynamic> multiPaymentData =
            json.decode(paymentMethodJsonOrString);
        if (multiPaymentData['isMultiPayment'] == true) {
          final Map<String, dynamic> amounts =
              Map<String, dynamic>.from(multiPaymentData['amounts'] ?? {});

          List<Widget> methodWidgets = [];
          double totalPaid = 0.0;

          amounts.forEach((method, amount) {
            double amountValue = double.tryParse(amount.toString()) ?? 0.0;
            if (amountValue > 0) {
              // Convert method ID/name to display name
              String displayName =
                  _getPaymentMethodDisplayName(method, context);
              // DEBIT is a customer-credit allocation, not money collected.
              // Show it in the list, but don't include it in Total Paid.
              final isDebitCredit = displayName.toUpperCase() == 'DEBIT';
              if (!isDebitCredit) {
                totalPaid += amountValue;
              }
              methodWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                  child: _buildInfoRow(
                    'confirmed_orders.payment_display'.tr.replaceAll('@name', displayName),
                    "$currency${amountValue.toStringAsFixed(2)}",
                    valueStyle: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "billing.payment_methods".tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...methodWidgets,
              const SizedBox(height: 8),
              _buildInfoRow(
                  "billing.total_paid".tr, "$currency${totalPaid.toStringAsFixed(2)}",
                  valueStyle: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  )),
            ],
          );
        }
      }
    } catch (e) {
      debugPrint("Error parsing payment method JSON: $e");
    }
    // Fallback for single payment method or parsing error
    // Convert ID to display name if needed
    String displayName =
        _getPaymentMethodDisplayName(paymentMethodJsonOrString, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "confirmed_orders.payment_method".tr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow("confirmed_orders.method".tr, displayName,
            valueStyle: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
