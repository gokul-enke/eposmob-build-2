import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

double? _parseAmountText(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String _formatAmountForDisplay(double value) =>
    AmountHelper.formatAmount(value);

/// Like [_formatAmountForDisplay], but keeps a third decimal when the price
/// has one (offer prices such as 29.997), as the desktop price field does.
String _formatPriceForDisplay(double value) =>
    NumberFormat('#,##0.00#').format(value);

String _formatAmountForEditing(double value) {
  final roundedValue = value.roundToDouble();
  if ((value - roundedValue).abs() < 0.0001) {
    return roundedValue.toInt().toString();
  }
  return value.toString();
}

void _selectAllText(TextEditingController controller) {
  if (controller.text.isEmpty) return;
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
}

void _attachSelectAllOnFocus(
  FocusNode node,
  TextEditingController controller,
) {
  node.addListener(() {
    if (node.hasFocus && controller.text.isNotEmpty) {
      _selectAllText(controller);
    }
  });
}

InputDecoration _cartFieldDecoration({
  required String label,
  bool readOnly = false,
}) {
  return InputDecoration(
    isDense: true,
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 10,
      color: Colors.grey.shade600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    filled: readOnly,
    fillColor: readOnly ? Colors.grey.shade50 : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade400,
        width: readOnly ? 1 : 1.2,
      ),
    ),
  );
}

/// Compact grid for price, MRP, and tax fields on mobile cart cards.
class MobileCartPriceSection extends StatelessWidget {
  const MobileCartPriceSection({
    super.key,
    required this.item,
    required this.controller,
    required this.showMrp,
    required this.showTaxRate,
    required this.showTaxAmount,
  });

  final LocalCartItem item;
  final BillingMobileCartController controller;
  final bool showMrp;
  final bool showTaxRate;
  final bool showTaxAmount;

  @override
  Widget build(BuildContext context) {
    final itemKey =
        '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-${item.saleUnitId ?? 'base'}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MobileCartPriceField(
                key: ValueKey('price-$itemKey'),
                item: item,
                controller: controller,
              ),
            ),
            if (showMrp) ...[
              const SizedBox(width: 8),
              Expanded(
                child: MobileCartMrpField(
                  key: ValueKey('mrp-$itemKey'),
                  item: item,
                  controller: controller,
                ),
              ),
            ],
          ],
        ),
        if (showTaxRate || showTaxAmount) ...[
          const SizedBox(height: 6),
          MobileCartTaxDisplay(
            item: item,
            controller: controller,
            showTaxRate: showTaxRate,
            showTaxAmount: showTaxAmount,
          ),
        ],
      ],
    );
  }
}

class MobileCartPriceField extends StatefulWidget {
  const MobileCartPriceField({
    super.key,
    required this.item,
    required this.controller,
  });

  final LocalCartItem item;
  final BillingMobileCartController controller;

  @override
  State<MobileCartPriceField> createState() => _MobileCartPriceFieldState();
}

class _MobileCartPriceFieldState extends State<MobileCartPriceField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _priceEdited = false;
  double? _automaticPriceAtFocus;

  /// Display price last written to the field. The cart re-prices lines in
  /// place (offer gained or lost, wholesale), so the parent widget's old and
  /// new `item` are the same object and cannot be compared.
  double? _shownPrice;

  double _displayPrice() {
    return BillingCrashGuards.safePrice(
      widget.item.displayPrice ?? widget.item.price,
    );
  }

  void _showDisplayPrice([double? price]) {
    final shown = price ?? _displayPrice();
    _shownPrice = shown;
    _textController.text = _focusNode.hasFocus
        ? _formatAmountForEditing(shown)
        : _formatPriceForDisplay(shown);
  }

  void _syncWithItemPrice() {
    if ((!_focusNode.hasFocus || !_priceEdited) &&
        _shownPrice != _displayPrice()) {
      _showDisplayPrice();
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _showDisplayPrice();
    _focusNode.addListener(_handleFocusChange);
    _attachSelectAllOnFocus(_focusNode, _textController);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _priceEdited = false;
      _automaticPriceAtFocus = widget.item.isManualPriceOverride
          ? null
          : _displayPrice();
      _textController.text = _formatAmountForEditing(_displayPrice());
      _selectAllText(_textController);
      return;
    }
    _commitPrice();
  }

  void _commitPrice() {
    // Offer changes can re-price the line while the field is focused. An
    // untouched field follows that price rather than committing stale text.
    final parsed = _parseAmountText(_textController.text);
    if (!_priceEdited || parsed == null ||
        (_automaticPriceAtFocus != null &&
            BillingMobileCartController.isSameDisplayPrice(
                parsed, _automaticPriceAtFocus!))) {
      _showDisplayPrice();
      _priceEdited = false;
      return;
    }

    // An unchanged standard or offer price is not committed (see
    // BillingMobileCartController.isUnchangedAutomaticPrice), so focusing
    // and leaving the field keeps the offer.
    final provider = context.read<LocalProductProvider>();
    final result = widget.controller.commitDisplayPrice(
      provider: provider,
      item: widget.item,
      displayPrice: parsed,
    );
    _priceEdited = false;

    if (result.clampedToDisplayPrice != null) {
      _showDisplayPrice(result.clampedToDisplayPrice!);
      showScaffoldError(
        context: context,
        message: 'Price can\'t go below the minimum sale price of '
            '${_textController.text}.',
      );
      return;
    }

    _showDisplayPrice();
  }

  @override
  void didUpdateWidget(MobileCartPriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWithItemPrice();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalProductProvider>();
    if ((!_focusNode.hasFocus || !_priceEdited) &&
        _shownPrice != _displayPrice()) {
      // Follow cart changes unless the cashier is editing the price.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncWithItemPrice();
      });
    }

    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onTap: () {
        if (!_focusNode.hasFocus) {
          _textController.text = _formatAmountForEditing(_displayPrice());
        }
        _selectAllText(_textController);
      },
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: _cartFieldDecoration(label: 'product_detail.price'.tr),
      onChanged: (value) {
        _priceEdited = true;
      },
      onSubmitted: (_) => _commitPrice(),
    );
  }
}

class MobileCartMrpField extends StatefulWidget {
  const MobileCartMrpField({
    super.key,
    required this.item,
    required this.controller,
  });

  final LocalCartItem item;
  final BillingMobileCartController controller;

  @override
  State<MobileCartMrpField> createState() => _MobileCartMrpFieldState();
}

class _MobileCartMrpFieldState extends State<MobileCartMrpField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  double _displayMrp() {
    return BillingCrashGuards.safeMrp(
      widget.item.displayMrp ?? widget.item.mrp,
    );
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: _formatAmountForDisplay(_displayMrp()),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _attachSelectAllOnFocus(_focusNode, _textController);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _textController.text = _formatAmountForEditing(_displayMrp());
      _selectAllText(_textController);
      return;
    }
    final parsed = _parseAmountText(_textController.text);
    _textController.text = _formatAmountForDisplay(
      parsed ?? _displayMrp(),
    );
  }

  @override
  void didUpdateWidget(MobileCartMrpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.item.mrp != widget.item.mrp) {
      _textController.text = _formatAmountForDisplay(_displayMrp());
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalProductProvider>();

    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onTap: () {
        if (!_focusNode.hasFocus) {
          _textController.text = _formatAmountForEditing(_displayMrp());
        }
        _selectAllText(_textController);
      },
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: _cartFieldDecoration(label: 'product_detail.mrp'.tr),
      onChanged: (value) {
        widget.controller.updateDisplayMrpWhileEditing(
          provider: context.read<LocalProductProvider>(),
          item: widget.item,
          text: value,
        );
      },
      onSubmitted: (_) {
        final parsed = _parseAmountText(_textController.text);
        if (parsed == null) {
          _textController.text = _formatAmountForDisplay(_displayMrp());
        } else {
          _textController.text = _formatAmountForDisplay(parsed);
        }
      },
    );
  }
}

class MobileCartTaxDisplay extends StatelessWidget {
  const MobileCartTaxDisplay({
    super.key,
    required this.item,
    required this.controller,
    required this.showTaxRate,
    required this.showTaxAmount,
  });

  final LocalCartItem item;
  final BillingMobileCartController controller;
  final bool showTaxRate;
  final bool showTaxAmount;

  @override
  Widget build(BuildContext context) {
    if (!showTaxRate && !showTaxAmount) {
      return const SizedBox.shrink();
    }

    final taxRate = BillingCrashGuards.safeTaxRate(item.taxRate);
    final taxAmount = item.amounts.tax;

    return Row(
      children: [
        if (showTaxRate) ...[
          Expanded(
            child: _MobileCartReadOnlyField(
              key: ValueKey('tax-rate-${item.product.productId}'),
              label: 'billing.tax_percent'.tr,
              value: taxRate.toString(),
            ),
          ),
          if (showTaxAmount) const SizedBox(width: 8),
        ],
        if (showTaxAmount)
          Expanded(
            child: _MobileCartReadOnlyField(
              key: ValueKey('tax-amt-${item.product.productId}'),
              label: 'billing.tax'.tr,
              value: AmountHelper.formatAmount(taxAmount),
            ),
          ),
      ],
    );
  }
}

class _MobileCartReadOnlyField extends StatefulWidget {
  const _MobileCartReadOnlyField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  State<_MobileCartReadOnlyField> createState() =>
      _MobileCartReadOnlyFieldState();
}

class _MobileCartReadOnlyFieldState extends State<_MobileCartReadOnlyField> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _attachSelectAllOnFocus(_focusNode, _textController);
  }

  @override
  void didUpdateWidget(_MobileCartReadOnlyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      readOnly: true,
      enableInteractiveSelection: true,
      onTap: () => _selectAllText(_textController),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700,
      ),
      decoration: _cartFieldDecoration(label: widget.label, readOnly: true),
    );
  }
}
