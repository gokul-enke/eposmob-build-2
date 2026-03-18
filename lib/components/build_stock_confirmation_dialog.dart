import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// A confirmation dialog for stock submission with payment summary
class StockConfirmationDialog extends StatefulWidget {
  final String title;
  final int itemCount;
  final double totalAmount;
  final DynamicPaymentData? paymentData;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String confirmButtonText;
  final String cancelButtonText;
  final bool showPaymentWarning;
  final double? totalDueOverride;
  final List<Map<String, dynamic>>? stockItems;
  final double? supplierOldBalance;

  const StockConfirmationDialog({
    Key? key,
    this.title = "Confirm Stock Submission",
    required this.itemCount,
    required this.totalAmount,
    this.paymentData,
    required this.onConfirm,
    this.onCancel,
    this.confirmButtonText = "Confirm",
    this.cancelButtonText = "Cancel",
    this.showPaymentWarning = false,
    this.totalDueOverride,
    this.stockItems,
    this.supplierOldBalance,
  }) : super(key: key);

  /// Show confirmation dialog when submitting without payment
  static Future<bool?> showNoPaymentConfirmation({
    required BuildContext context,
    required int itemCount,
    required double totalAmount,
    required double totalDueAmount,
    required VoidCallback onConfirm,
    List<Map<String, dynamic>>? stockItems,
    double? supplierOldBalance,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StockConfirmationDialog(
          title: "Submit Without Payment?",
          itemCount: itemCount,
          totalAmount: totalAmount,
          paymentData: null,
          onConfirm: onConfirm,
          showPaymentWarning: true,
          confirmButtonText: "Yes, Submit",
          cancelButtonText: "Add Payment",
          totalDueOverride: totalDueAmount,
          stockItems: stockItems,
          supplierOldBalance: supplierOldBalance,
        );
      },
    );
  }

  /// Show payment summary confirmation dialog
  static Future<bool?> showPaymentSummary({
    required BuildContext context,
    required int itemCount,
    required double totalAmount,
    required DynamicPaymentData paymentData,
    double? totalDueAmount,
    required VoidCallback onConfirm,
    List<Map<String, dynamic>>? stockItems,
    double? supplierOldBalance,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StockConfirmationDialog(
          title: "Payment Summary",
          itemCount: itemCount,
          totalAmount: totalAmount,
          paymentData: paymentData,
          onConfirm: onConfirm,
          showPaymentWarning: false,
          confirmButtonText: "Confirm & Submit",
          cancelButtonText: "Cancel",
          totalDueOverride: totalDueAmount,
          stockItems: stockItems,
          supplierOldBalance: supplierOldBalance,
        );
      },
    );
  }

  @override
  State<StockConfirmationDialog> createState() =>
      _StockConfirmationDialogState();
}

class _StockConfirmationDialogState extends State<StockConfirmationDialog> {
  bool _isItemsExpanded = false;
  static const int _maxVisibleItems = 10;

  // Color palette for payment methods
  final List<Color> _methodColors = [
    ColorManager.kButtonGreen,
    ColorManager.kButtonBlue,
    ColorManager.kPrimaryColor,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  // Icon palette for payment methods
  final Map<String, IconData> _methodIcons = {
    'CASH': Icons.money,
    'COD': Icons.money,
    'CARD': Icons.credit_card,
    'UPI': Icons.qr_code,
    'ONLINE': Icons.language,
    'CHEQUE': Icons.receipt_long,
  };

  String _getMethodName(MasterDataValue method) {
    return method.description.isNotEmpty ? method.description : method.value;
  }

  IconData _getMethodIcon(MasterDataValue method) {
    final value = method.value.toUpperCase();
    return _methodIcons[value] ?? Icons.payment;
  }

  Color _getMethodColor(MasterDataValue method, int index) {
    return _methodColors[index % _methodColors.length];
  }

  // Calculate totals from stock items
  int _getTotalQuantity() {
    if (widget.stockItems == null) return 0;
    int total = 0;
    for (var item in widget.stockItems!) {
      total += int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  Map<String, double> _getPurchaseTaxBreakdown() {
    if (widget.stockItems == null || widget.stockItems!.isEmpty) {
      return {
        'includedTax': 0.0,
        'additionalTax': 0.0,
      };
    }

    double includedTax = 0.0;
    double additionalTax = 0.0;

    for (final item in widget.stockItems!) {
      final qty = _toDouble(item['quantity']);
      final taxPerUnit = _toDouble(item['taxAmountPurchase']);
      final itemTax = taxPerUnit * qty;
      final bool taxInclude = item['taxInclude'] == true;

      if (taxInclude) {
        includedTax += itemTax;
      } else {
        additionalTax += itemTax;
      }
    }

    debugPrint(
        '🧾 [StockConfirm] Purchase tax breakdown | includedTax=${includedTax.toStringAsFixed(2)} | additionalTax=${additionalTax.toStringAsFixed(2)}');

    return {
      'includedTax': includedTax,
      'additionalTax': additionalTax,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPayment =
        widget.paymentData != null && widget.paymentData!.hasPaymentMethods;
    final double paidAmount = widget.paymentData?.totalAmount ?? 0;
    final double supplierOldBalance = widget.supplierOldBalance ?? 0;

    // Calculate current supplier balance correctly
    // Current Balance = (Old Balanceance + New Purchase) - Payment Made
    final double totalDue = supplierOldBalance + widget.totalAmount;
    final double currentSupplierBalance = totalDue - paidAmount;

    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 800;
    final bool hasStockItems =
        widget.stockItems != null && widget.stockItems!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? 480 : 640,
          minWidth: isSmallScreen ? 400 : 560,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.showPaymentWarning
                    ? Colors.orange.shade50
                    : ColorManager.kPrimaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.showPaymentWarning
                          ? Colors.orange.withOpacity(0.15)
                          : ColorManager.kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.showPaymentWarning
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_long_rounded,
                      color: widget.showPaymentWarning
                          ? Colors.orange
                          : ColorManager.kPrimaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s16,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.itemCount} item${widget.itemCount > 1 ? 's' : ''} to be submitted",
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s12,
                            0.27,
                            Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.grey.shade600, size: 22),
                    onPressed: () {
                      if (widget.onCancel != null) widget.onCancel!();
                      Navigator.of(context).pop(false);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning message for no payment
                    if (widget.showPaymentWarning) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Submitting without payment. Full amount will be recorded as balance due.",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s12,
                                  0.27,
                                  Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Stock Items Table
                    if (hasStockItems) ...[
                      _buildItemsTable(),
                      const SizedBox(height: 12),
                    ],

                    // Summary Section
                    _buildSummarySection(
                      hasPayment: hasPayment,
                      paidAmount: paidAmount,
                      supplierOldBalance: supplierOldBalance,
                      currentSupplierBalance: currentSupplierBalance,
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CustomRoundButton(
                      fct: () {
                        if (widget.onCancel != null) widget.onCancel!();
                        Navigator.pop(context, false);
                      },
                      title: widget.cancelButtonText,
                      height: 44,
                      width: 150,
                      fontSize: FontSize.s13,
                      borderColor: Colors.grey.shade400,
                      boxColor: Colors.white,
                      textColor: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomRoundButton(
                      fct: () {
                        widget.onConfirm();
                        Navigator.pop(context, true);
                      },
                      title: widget.confirmButtonText,
                      height: 44,
                      width: 150,
                      fontSize: FontSize.s13,
                      borderColor: ColorManager.kPrimaryColor,
                      boxColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    final items = widget.stockItems!;
    final int totalItems = items.length;
    final bool needsExpand = totalItems > _maxVisibleItems;
    final List<Map<String, dynamic>> visibleItems =
        _isItemsExpanded ? items : items.take(_maxVisibleItems).toList();

    double previewTaxTotal = 0.0;
    for (final item in visibleItems) {
      final qty = _toDouble(item['quantity']);
      final taxPerUnit = _toDouble(item['taxAmountPurchase']);
      previewTaxTotal += qty * taxPerUnit;
    }
    debugPrint(
        '🧾 [StockConfirm] Table preview | rows=${visibleItems.length} | taxTotal=${previewTaxTotal.toStringAsFixed(2)}');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    'No',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Product',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price × Qty',
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Tax',
                    textAlign: TextAlign.right,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s11,
                      0.27,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Body
          ...visibleItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final productName = item['productName'] ?? 'Unknown';
            final quantity =
                int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
            final purchaseRate =
                double.tryParse(item['purchaseRate']?.toString() ?? '0') ?? 0;
            final taxPerUnit = _toDouble(item['taxAmountPurchase']);
            final taxAmount = taxPerUnit * quantity;
            final total = quantity * purchaseRate;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.27,
                        Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${purchaseRate.toStringAsFixed(0)} × $quantity',
                      textAlign: TextAlign.center,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.27,
                        Colors.grey.shade600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${taxAmount.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.27,
                        Colors.teal.shade700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${total.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s11,
                        0.27,
                        Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // Expand/Collapse button
          if (needsExpand)
            InkWell(
              onTap: () {
                setState(() {
                  _isItemsExpanded = !_isItemsExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.05),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isItemsExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: ColorManager.kPrimaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isItemsExpanded
                          ? 'Show Less'
                          : 'Show All ${totalItems - _maxVisibleItems} More Items',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.27,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required bool hasPayment,
    required double paidAmount,
    required double supplierOldBalance,
    required double currentSupplierBalance,
  }) {
    final purchaseTax = _getPurchaseTaxBreakdown();
    final includedTax = purchaseTax['includedTax'] ?? 0.0;
    final additionalTax = purchaseTax['additionalTax'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Items & Quantity Row
          Row(
            children: [
              Expanded(
                child: _buildCompactSummaryItem(
                  'Total Items',
                  '${widget.itemCount}',
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryItem(
                  'Total Quantity',
                  '${_getTotalQuantity()}',
                  Icons.shopping_cart_outlined,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Purchase Amount
          _buildSummaryRow(
            "Total Purchase Amount",
            "${widget.totalAmount.toStringAsFixed(2)}",
            isBold: true,
            valueColor: ColorManager.textColor,
          ),

          if (includedTax > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              "Included Purchase Tax",
              "${includedTax.toStringAsFixed(2)}",
              valueColor: Colors.teal.shade700,
            ),
          ],

          if (additionalTax > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              "Additional Purchase Tax",
              "${additionalTax.toStringAsFixed(2)}",
              valueColor: Colors.orange.shade700,
            ),
            const SizedBox(height: 4),
            _buildSummaryRow(
              "Total Purchase + Tax",
              "${(widget.totalAmount + additionalTax).toStringAsFixed(2)}",
              isBold: true,
              valueColor: Colors.black87,
            ),
          ],

          // Old Supplier Balance
          if (supplierOldBalance != 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow(
              "Old Supplier Balance",
              "${supplierOldBalance.toStringAsFixed(2)}",
              valueColor: supplierOldBalance > 0
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
            ),
          ],

          // Payment breakdown
          if (hasPayment) ...[
            const Divider(height: 16),
            Text(
              'Payment Breakdown',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.27,
                Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.paymentData!.primaryMethod != null &&
                widget.paymentData!.primaryAmount.isNotEmpty) ...[
              _buildPaymentMethodRow(
                widget.paymentData!.primaryMethod!,
                double.tryParse(widget.paymentData!.primaryAmount) ?? 0,
                0,
              ),
            ],
            if (widget.paymentData!.secondaryMethod != null &&
                widget.paymentData!.secondaryAmount.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildPaymentMethodRow(
                widget.paymentData!.secondaryMethod!,
                double.tryParse(widget.paymentData!.secondaryAmount) ?? 0,
                1,
              ),
            ],
            const Divider(height: 16),
            _buildSummaryRow(
              "Total Paid Amount",
              "${paidAmount.toStringAsFixed(2)}",
              valueColor: ColorManager.kSuccessColor,
              isBold: true,
            ),
          ],

          const Divider(height: 16),

          // Current Supplier Balance (Final)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: currentSupplierBalance > 0
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentSupplierBalance > 0
                    ? Colors.red.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Current Supplier Balance",
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.27,
                    currentSupplierBalance > 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
                Text(
                  "${currentSupplierBalance.toStringAsFixed(2)}",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s15,
                    0.27,
                    currentSupplierBalance > 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.27,
                  Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s14,
                  0.27,
                  color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              isBold ? FontWeightManager.semiBold : FontWeightManager.regular,
              FontSize.s12,
              0.27,
              Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: buildCustomStyle(
              isBold ? FontWeightManager.bold : FontWeightManager.semiBold,
              isBold ? FontSize.s14 : FontSize.s12,
              0.27,
              valueColor ?? ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(
      MasterDataValue method, double amount, int index) {
    final color = _getMethodColor(method, index);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            _getMethodIcon(method),
            color: color,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getMethodName(method),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          "${amount.toStringAsFixed(2)}",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.27,
            color,
          ),
        ),
      ],
    );
  }
}
