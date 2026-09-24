import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_container_box.dart';

enum RestrictedPaymentType { cash, card, upi }

class RestrictedPaymentData {
  final RestrictedPaymentType? primaryMethod;
  final RestrictedPaymentType? secondaryMethod;
  final String primaryAmount;
  final String secondaryAmount;

  RestrictedPaymentData({
    this.primaryMethod,
    this.secondaryMethod,
    this.primaryAmount = '',
    this.secondaryAmount = '',
  });

  bool get hasPaymentMethods =>
      primaryMethod != null || secondaryMethod != null;

  double get totalAmount {
    double primary = double.tryParse(primaryAmount) ?? 0;
    double secondary = double.tryParse(secondaryAmount) ?? 0;
    return primary + secondary;
  }

  RestrictedPaymentData copyWith({
    RestrictedPaymentType? primaryMethod,
    RestrictedPaymentType? secondaryMethod,
    String? primaryAmount,
    String? secondaryAmount,
  }) {
    return RestrictedPaymentData(
      primaryMethod: primaryMethod ?? this.primaryMethod,
      secondaryMethod: secondaryMethod ?? this.secondaryMethod,
      primaryAmount: primaryAmount ?? this.primaryAmount,
      secondaryAmount: secondaryAmount ?? this.secondaryAmount,
    );
  }
}

/// Payment selector with restricted combinations:
/// - Cash + Card ✅
/// - Cash + UPI ✅
/// - Cash only ✅
/// - Card only ✅
/// - UPI only ✅
/// - Card + UPI ❌ (Not allowed)
class BuildRestrictedPaymentSelector extends StatefulWidget {
  final String? title;
  final List<RestrictedPaymentType> availableMethods;
  final Function(RestrictedPaymentData) onPaymentChanged;
  final RestrictedPaymentData? initialData;
  final bool showTotalAmount;
  final double? expectedAmount;
  final String? restrictionMessage;
  final bool showRestrictionInfo;

  const BuildRestrictedPaymentSelector({
    Key? key,
    this.title = '',
    this.availableMethods = const [
      RestrictedPaymentType.cash,
      RestrictedPaymentType.card,
      RestrictedPaymentType.upi,
    ],
    required this.onPaymentChanged,
    this.initialData,
    this.showTotalAmount = false,
    this.expectedAmount,
    this.restrictionMessage,
    this.showRestrictionInfo = false, // Default to not showing the info box
  }) : super(key: key);

  @override
  State<BuildRestrictedPaymentSelector> createState() =>
      _BuildRestrictedPaymentSelectorState();
}

class _BuildRestrictedPaymentSelectorState
    extends State<BuildRestrictedPaymentSelector> {
  RestrictedPaymentType? primaryMethod;
  RestrictedPaymentType? secondaryMethod;
  final TextEditingController primaryAmountController = TextEditingController();
  final TextEditingController secondaryAmountController =
      TextEditingController();
  final FocusNode _primaryAmountFocusNode = FocusNode();
  final FocusNode _secondaryAmountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      primaryMethod = widget.initialData!.primaryMethod;
      secondaryMethod = widget.initialData!.secondaryMethod;
      primaryAmountController.text = widget.initialData!.primaryAmount;
      secondaryAmountController.text = widget.initialData!.secondaryAmount;
    }
  }

  @override
  void dispose() {
    primaryAmountController.dispose();
    secondaryAmountController.dispose();
    _primaryAmountFocusNode.dispose();
    _secondaryAmountFocusNode.dispose();
    super.dispose();
  }

  String _getMethodName(RestrictedPaymentType method) {
    switch (method) {
      case RestrictedPaymentType.cash:
        return 'general.cash'.tr;
      case RestrictedPaymentType.card:
        return 'general.card'.tr;
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

  bool _isMethodDisabled(RestrictedPaymentType method) {
    // If Card is selected, UPI is disabled
    if (method == RestrictedPaymentType.upi &&
        (primaryMethod == RestrictedPaymentType.card ||
            secondaryMethod == RestrictedPaymentType.card)) {
      return true;
    }

    // If UPI is selected, Card is disabled
    if (method == RestrictedPaymentType.card &&
        (primaryMethod == RestrictedPaymentType.upi ||
            secondaryMethod == RestrictedPaymentType.upi)) {
      return true;
    }

    return false;
  }

  void _selectPaymentMethod(RestrictedPaymentType method) {
    // Check if method is disabled due to restrictions
    if (_isMethodDisabled(method)) {
      _showRestrictionMessage();
      return;
    }

    setState(() {
      if (primaryMethod == method) {
        // Deselecting primary method
        primaryMethod = secondaryMethod;
        secondaryMethod = null;
        primaryAmountController.text = secondaryAmountController.text;
        secondaryAmountController.clear();
      } else if (secondaryMethod == method) {
        // Deselecting secondary method
        secondaryMethod = null;
        secondaryAmountController.clear();
      } else {
        // Selecting new method
        if (primaryMethod == null) {
          primaryMethod = method;
          // Auto-focus on the primary amount field
          Future.delayed(const Duration(milliseconds: 100), () {
            _primaryAmountFocusNode.requestFocus();
          });
        } else if (secondaryMethod == null) {
          // Check restriction before adding secondary method
          if (_wouldViolateRestriction(primaryMethod!, method)) {
            _showRestrictionMessage();
            return;
          }
          secondaryMethod = method;
          // Auto-focus on the secondary amount field
          Future.delayed(const Duration(milliseconds: 100), () {
            _secondaryAmountFocusNode.requestFocus();
          });
        } else {
          // Replace secondary with new selection (if allowed)
          if (_wouldViolateRestriction(primaryMethod!, method)) {
            _showRestrictionMessage();
            return;
          }
          secondaryMethod = method;
          secondaryAmountController.clear();
          // Auto-focus on the secondary amount field
          Future.delayed(const Duration(milliseconds: 100), () {
            _secondaryAmountFocusNode.requestFocus();
          });
        }
      }
    });
    _notifyChange();
  }

  bool _wouldViolateRestriction(
      RestrictedPaymentType method1, RestrictedPaymentType method2) {
    // Card + UPI combination is not allowed
    return (method1 == RestrictedPaymentType.card &&
            method2 == RestrictedPaymentType.upi) ||
        (method1 == RestrictedPaymentType.upi &&
            method2 == RestrictedPaymentType.card);
  }

  void _showRestrictionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.restrictionMessage ??
              'general.card_upi_not_allowed_together'.tr,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            Colors.white,
          ),
        ),
        backgroundColor: ColorManager.kErrorColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _notifyChange() {
    widget.onPaymentChanged(RestrictedPaymentData(
      primaryMethod: primaryMethod,
      secondaryMethod: secondaryMethod,
      primaryAmount: primaryAmountController.text,
      secondaryAmount: secondaryAmountController.text,
    ));
  }

  bool _isMethodSelected(RestrictedPaymentType method) {
    return primaryMethod == method || secondaryMethod == method;
  }

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title ?? 'general.select_payment_method'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),

          // Restriction info (only show if enabled)
          if (widget.showRestrictionInfo && widget.restrictionMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.restrictionMessage!,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.27,
                        Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Payment method buttons
          Row(
            children: widget.availableMethods.map((method) {
              bool isSelected = _isMethodSelected(method);
              bool isDisabled = _isMethodDisabled(method);
              Color methodColor = _getMethodColor(method);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: method != widget.availableMethods.last ? 8 : 0,
                  ),
                  child: Opacity(
                    opacity: isDisabled ? 0.4 : 1.0,
                    child: GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () => _selectPaymentMethod(method),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? methodColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDisabled
                                ? Colors.grey.shade300
                                : (isSelected
                                    ? methodColor
                                    : Colors.grey.shade300),
                            width: 2,
                          ),
                          boxShadow: isSelected && !isDisabled
                              ? [
                                  BoxShadow(
                                    color: methodColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getMethodIcon(method),
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : (isSelected ? Colors.white : methodColor),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getMethodName(method),
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.27,
                                isDisabled
                                    ? Colors.grey.shade400
                                    : (isSelected ? Colors.white : methodColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Amount input fields
          if (primaryMethod != null || secondaryMethod != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (primaryMethod != null)
                  Expanded(
                    child: _buildAmountInput(
                      method: primaryMethod!,
                      controller: primaryAmountController,
                      placeholder:
                          'general.enter_payment_amount'.trParams({
                            'method': _getMethodName(primaryMethod!)
                          }),
                      focusNode: _primaryAmountFocusNode,
                    ),
                  ),
                if (primaryMethod != null && secondaryMethod != null)
                  const SizedBox(width: 12),
                if (secondaryMethod != null)
                  Expanded(
                    child: _buildAmountInput(
                      method: secondaryMethod!,
                      controller: secondaryAmountController,
                      placeholder:
                          'general.enter_payment_amount'.trParams({
                            'method': _getMethodName(secondaryMethod!)
                          }),
                      focusNode: _secondaryAmountFocusNode,
                    ),
                  ),
              ],
            ),
          ],

          // Total amount display
          if (widget.showTotalAmount &&
              (primaryMethod != null || secondaryMethod != null)) ...[
            const SizedBox(height: 12),
            _buildTotalDisplay(),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountInput({
    required RestrictedPaymentType method,
    required TextEditingController controller,
    required String placeholder,
    required FocusNode focusNode,
  }) {
    return BuildBoxShadowContainer(
      circleRadius: 8,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.grey.shade500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: Icon(
            Icons.currency_rupee,
            color: _getMethodColor(method),
            size: 18,
          ),
        ),
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.27,
          ColorManager.textColor,
        ),
        onChanged: (value) => _notifyChange(),
      ),
    );
  }

  Widget _buildTotalDisplay() {
    double primaryAmount = double.tryParse(primaryAmountController.text) ?? 0;
    double secondaryAmount =
        double.tryParse(secondaryAmountController.text) ?? 0;
    double total = primaryAmount + secondaryAmount;

    Color totalColor = widget.expectedAmount != null
        ? (total == widget.expectedAmount
            ? ColorManager.kSuccessColor
            : ColorManager.kErrorColor)
        : ColorManager.kPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: totalColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: totalColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${'general.total'.tr}: ${total.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              totalColor,
            ),
          ),
          if (widget.expectedAmount != null) ...[
            Text(
              '${'general.expected'.tr}: '
              '${widget.expectedAmount!.toStringAsFixed(2)}',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                Colors.grey.shade600,
              ),
            ),
            Icon(
              total == widget.expectedAmount ? Icons.check_circle : Icons.error,
              color: totalColor,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}
