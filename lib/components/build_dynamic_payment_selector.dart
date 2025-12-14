import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/models/master_data.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'build_container_box.dart';

/// Payment data that holds the selected payment methods and amounts
/// Uses MasterDataValue to store the actual payment method with its ID
class DynamicPaymentData {
  final MasterDataValue? primaryMethod;
  final MasterDataValue? secondaryMethod;
  final String primaryAmount;
  final String secondaryAmount;

  DynamicPaymentData({
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

  /// Get primary payment method ID for API
  int? get primaryMethodId => primaryMethod?.id;

  /// Get secondary payment method ID for API
  int? get secondaryMethodId => secondaryMethod?.id;

  DynamicPaymentData copyWith({
    MasterDataValue? primaryMethod,
    MasterDataValue? secondaryMethod,
    String? primaryAmount,
    String? secondaryAmount,
  }) {
    return DynamicPaymentData(
      primaryMethod: primaryMethod ?? this.primaryMethod,
      secondaryMethod: secondaryMethod ?? this.secondaryMethod,
      primaryAmount: primaryAmount ?? this.primaryAmount,
      secondaryAmount: secondaryAmount ?? this.secondaryAmount,
    );
  }
}

/// Dynamic payment selector that uses payment methods from API
/// - Supports split payments (up to 2 methods)
/// - Shows payment method buttons dynamically from API data
/// - Returns payment method IDs for API submission
class BuildDynamicPaymentSelector extends StatefulWidget {
  final String title;
  final List<MasterDataValue> paymentMethods;
  final Function(DynamicPaymentData) onPaymentChanged;
  final DynamicPaymentData? initialData;
  final bool showTotalAmount;
  final double? expectedAmount;
  final int maxMethods; // Maximum number of payment methods (default 2)
  final bool isLoading;

  const BuildDynamicPaymentSelector({
    Key? key,
    this.title = "Select Payment Method",
    required this.paymentMethods,
    required this.onPaymentChanged,
    this.initialData,
    this.showTotalAmount = false,
    this.expectedAmount,
    this.maxMethods = 2,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<BuildDynamicPaymentSelector> createState() =>
      _BuildDynamicPaymentSelectorState();
}

class _BuildDynamicPaymentSelectorState
    extends State<BuildDynamicPaymentSelector> {
  MasterDataValue? primaryMethod;
  MasterDataValue? secondaryMethod;
  final TextEditingController primaryAmountController = TextEditingController();
  final TextEditingController secondaryAmountController =
      TextEditingController();
  final FocusNode _primaryAmountFocusNode = FocusNode();
  final FocusNode _secondaryAmountFocusNode = FocusNode();

  // Color palette for payment methods
  final List<Color> _methodColors = [
    ColorManager.kButtonGreen, // Cash-like
    ColorManager.kButtonBlue, // Card-like
    ColorManager.kPrimaryColor, // UPI-like
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

  Color _getMethodColor(MasterDataValue method) {
    // Try to match by value first
    final index = widget.paymentMethods.indexOf(method);
    return _methodColors[index % _methodColors.length];
  }

  IconData _getMethodIcon(MasterDataValue method) {
    // Try to find icon by value
    final value = method.value.toUpperCase();
    return _methodIcons[value] ?? Icons.payment;
  }

  void _selectPaymentMethod(MasterDataValue method) {
    setState(() {
      if (primaryMethod?.id == method.id) {
        // Deselecting primary method
        primaryMethod = secondaryMethod;
        secondaryMethod = null;
        primaryAmountController.text = secondaryAmountController.text;
        secondaryAmountController.clear();
      } else if (secondaryMethod?.id == method.id) {
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
        } else if (secondaryMethod == null && widget.maxMethods > 1) {
          secondaryMethod = method;
          // Auto-focus on the secondary amount field
          Future.delayed(const Duration(milliseconds: 100), () {
            _secondaryAmountFocusNode.requestFocus();
          });
        } else if (widget.maxMethods > 1) {
          // Replace secondary with new selection
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

  void _notifyChange() {
    widget.onPaymentChanged(DynamicPaymentData(
      primaryMethod: primaryMethod,
      secondaryMethod: secondaryMethod,
      primaryAmount: primaryAmountController.text,
      secondaryAmount: secondaryAmountController.text,
    ));
  }

  bool _isMethodSelected(MasterDataValue method) {
    return primaryMethod?.id == method.id || secondaryMethod?.id == method.id;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return BuildBoxShadowContainer(
        circleRadius: 12,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.30,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      );
    }

    if (widget.paymentMethods.isEmpty) {
      return BuildBoxShadowContainer(
        circleRadius: 12,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.30,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No payment methods available',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return BuildBoxShadowContainer(
      circleRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),

          // Payment method buttons - distributed across full width
          LayoutBuilder(
            builder: (context, constraints) {
              final methodCount = widget.paymentMethods.length;
              if (methodCount == 0) return const SizedBox.shrink();

              return Row(
                children: widget.paymentMethods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final method = entry.value;
                  bool isSelected = _isMethodSelected(method);
                  Color methodColor = _getMethodColor(method);

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == methodCount - 1 ? 0 : 4,
                      ),
                      child: GestureDetector(
                        onTap: () => _selectPaymentMethod(method),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? methodColor : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? methodColor
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            boxShadow: isSelected
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
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Icon(
                                _getMethodIcon(method),
                                color: isSelected ? Colors.white : methodColor,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  method.description.isNotEmpty
                                      ? method.description
                                      : method.value,
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s14,
                                    0.27,
                                    isSelected ? Colors.white : methodColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
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
                          'Enter ${primaryMethod!.description.isNotEmpty ? primaryMethod!.description : primaryMethod!.value} Amount',
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
                          'Enter ${secondaryMethod!.description.isNotEmpty ? secondaryMethod!.description : secondaryMethod!.value} Amount',
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
    required MasterDataValue method,
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
            'Total: ₹${total.toStringAsFixed(2)}',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              totalColor,
            ),
          ),
          if (widget.expectedAmount != null) ...[
            Text(
              'Expected: ₹${widget.expectedAmount!.toStringAsFixed(2)}',
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
