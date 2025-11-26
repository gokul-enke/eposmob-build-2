import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_restricted_payment_selector.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// A confirmation dialog for stock submission with payment summary
class StockConfirmationDialog extends StatelessWidget {
  final String title;
  final int itemCount;
  final double totalAmount;
  final RestrictedPaymentData? paymentData;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String confirmButtonText;
  final String cancelButtonText;
  final bool showPaymentWarning;
  final double? totalDueOverride;

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
  }) : super(key: key);

  /// Show confirmation dialog when submitting without payment
  static Future<bool?> showNoPaymentConfirmation({
    required BuildContext context,
    required int itemCount,
    required double totalAmount,
    required double totalDueAmount,
    required VoidCallback onConfirm,
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
        );
      },
    );
  }

  /// Show payment summary confirmation dialog
  static Future<bool?> showPaymentSummary({
    required BuildContext context,
    required int itemCount,
    required double totalAmount,
    required RestrictedPaymentData paymentData,
    double? totalDueAmount,
    required VoidCallback onConfirm,
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
        );
      },
    );
  }

  String _getMethodName(RestrictedPaymentType method) {
    switch (method) {
      case RestrictedPaymentType.cash:
        return 'Cash';
      case RestrictedPaymentType.card:
        return 'Card';
      case RestrictedPaymentType.upi:
        return 'UPI';
    }
  }

  IconData _getMethodIcon(RestrictedPaymentType method) {
    switch (method) {
      case RestrictedPaymentType.cash:
        return Icons.money;
      case RestrictedPaymentType.card:
        return Icons.credit_card;
      case RestrictedPaymentType.upi:
        return Icons.qr_code;
    }
  }

  Color _getMethodColor(RestrictedPaymentType method) {
    switch (method) {
      case RestrictedPaymentType.cash:
        return ColorManager.kButtonGreen;
      case RestrictedPaymentType.card:
        return ColorManager.kButtonBlue;
      case RestrictedPaymentType.upi:
        return ColorManager.kPrimaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPayment = paymentData != null && paymentData!.hasPaymentMethods;
    final double paidAmount = paymentData?.totalAmount ?? 0;
    // If caller passes an explicit due amount, use that. Otherwise fall back
    // to (totalAmount - paidAmount) logic.
    final double balanceAmount =
        totalDueOverride ?? (totalAmount - paidAmount);

    // Make dialog width responsive so content is fully readable
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 800;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          // Wider on desktop so long titles and warning text don't truncate
          maxWidth: isSmallScreen ? 420 : 560,
          minWidth: isSmallScreen ? 360 : 480,
          // Give a bit of vertical room so content breathes
          minHeight: 220,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: showPaymentWarning
                        ? Colors.orange.withOpacity(0.1)
                        : ColorManager.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    showPaymentWarning
                        ? Icons.warning_amber_rounded
                        : Icons.receipt_long_rounded,
                    color: showPaymentWarning
                        ? Colors.orange
                        : ColorManager.kPrimaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s18,
                          0.30,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$itemCount item${itemCount > 1 ? 's' : ''} to be submitted",
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.27,
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                  onPressed: () {
                    if (onCancel != null) onCancel!();
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Warning message for no payment
            if (showPaymentWarning) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You are about to submit stock without adding payment details. The full amount will be recorded as balance due.",
                        maxLines: 2,
                        softWrap: true,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.27,
                          Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stock Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    "Total Purchase Amount",
                    "₹${totalAmount.toStringAsFixed(2)}",
                    isBold: true,
                    valueColor: ColorManager.textColor,
                  ),
                  if (hasPayment) ...[
                    const Divider(height: 20),
                    // Payment breakdown
                    if (paymentData!.primaryMethod != null &&
                        paymentData!.primaryAmount.isNotEmpty) ...[
                      _buildPaymentMethodRow(
                        paymentData!.primaryMethod!,
                        double.tryParse(paymentData!.primaryAmount) ?? 0,
                      ),
                    ],
                    if (paymentData!.secondaryMethod != null &&
                        paymentData!.secondaryAmount.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildPaymentMethodRow(
                        paymentData!.secondaryMethod!,
                        double.tryParse(paymentData!.secondaryAmount) ?? 0,
                      ),
                    ],
                    const Divider(height: 20),
                    _buildSummaryRow(
                      "Total Paid",
                      "₹${paidAmount.toStringAsFixed(2)}",
                      valueColor: ColorManager.kSuccessColor,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      "Total Due Amount",
                      "₹${balanceAmount.toStringAsFixed(2)}",
                      valueColor: balanceAmount > 0
                          ? ColorManager.kErrorColor
                          : ColorManager.kSuccessColor,
                      isBold: true,
                    ),
                  ] else ...[
                    const Divider(height: 20),
                    _buildSummaryRow(
                      "Total Due Amount",
                      "₹${balanceAmount.toStringAsFixed(2)}",
                      valueColor: ColorManager.kErrorColor,
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomRoundButton(
                    fct: () {
                      if (onCancel != null) onCancel!();
                      Navigator.pop(context, false);
                    },
                    title: cancelButtonText,
                    height: 48,
                    width: 150,
                    fontSize: FontSize.s14,
                    borderColor: Colors.grey.shade400,
                    boxColor: Colors.white,
                    textColor: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomRoundButton(
                    fct: () {
                      onConfirm();
                      Navigator.pop(context, true);
                    },
                    title: confirmButtonText,
                    height: 48,
                    width: 150,
                    fontSize: FontSize.s14,
                    borderColor: ColorManager.kPrimaryColor,
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            isBold ? FontWeightManager.semiBold : FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            isBold ? FontWeightManager.bold : FontWeightManager.semiBold,
            isBold ? FontSize.s16 : FontSize.s14,
            0.27,
            valueColor ?? ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodRow(RestrictedPaymentType method, double amount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _getMethodColor(method).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            _getMethodIcon(method),
            color: _getMethodColor(method),
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _getMethodName(method),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.27,
            Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          "₹${amount.toStringAsFixed(2)}",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.27,
            _getMethodColor(method),
          ),
        ),
      ],
    );
  }
}
