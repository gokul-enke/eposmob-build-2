import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

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
      fontSize: 11,
      color: Colors.grey.shade600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    filled: readOnly,
    fillColor: readOnly ? Colors.grey.shade50 : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: readOnly ? Colors.grey.shade200 : Colors.grey.shade400,
        width: readOnly ? 1 : 1.2,
      ),
    ),
  );
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

  double _displayPrice() {
    return BillingCrashGuards.safePrice(
      widget.item.displayPrice ?? widget.item.price,
    );
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.formatPrice(_displayPrice()),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _attachSelectAllOnFocus(_focusNode, _textController);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitPrice();
    }
  }

  void _commitPrice() {
    final parsed = double.tryParse(_textController.text);
    if (parsed == null) {
      _textController.text = widget.controller.formatPrice(_displayPrice());
      return;
    }

    final provider = context.read<LocalProductProvider>();
    final result = widget.controller.commitDisplayPrice(
      provider: provider,
      item: widget.item,
      displayPrice: parsed,
    );

    if (result.clampedToDisplayPrice != null) {
      final clampedText =
          widget.controller.formatPrice(result.clampedToDisplayPrice!);
      _textController.text = clampedText;
      showScaffoldError(
        context: context,
        message:
            'Price can\'t go below the minimum sale price of $clampedText.',
      );
    }
  }

  @override
  void didUpdateWidget(MobileCartPriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.item.price != widget.item.price) {
      _textController.text = widget.controller.formatPrice(_displayPrice());
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
      onTap: () => _selectAllText(_textController),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: _cartFieldDecoration(label: 'Price'),
      onChanged: (value) {
        widget.controller.updateDisplayPriceWhileEditing(
          provider: context.read<LocalProductProvider>(),
          item: widget.item,
          text: value,
        );
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
      text: widget.controller.formatPrice(_displayMrp()),
    );
    _focusNode = FocusNode();
    _attachSelectAllOnFocus(_focusNode, _textController);
  }

  @override
  void didUpdateWidget(MobileCartMrpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.item.mrp != widget.item.mrp) {
      _textController.text = widget.controller.formatPrice(_displayMrp());
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
    context.watch<LocalProductProvider>();

    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onTap: () => _selectAllText(_textController),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: _cartFieldDecoration(label: 'MRP'),
      onChanged: (value) {
        widget.controller.updateDisplayMrpWhileEditing(
          provider: context.read<LocalProductProvider>(),
          item: widget.item,
          text: value,
        );
      },
      onSubmitted: (_) {
        final parsed = double.tryParse(_textController.text);
        if (parsed == null) {
          _textController.text = widget.controller.formatPrice(_displayMrp());
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
    final taxAmount = controller.inclusiveTaxAmount(
      unitPrice: BillingCrashGuards.safePrice(item.price),
      quantity: item.quantity,
      taxRate: taxRate,
    );

    return Row(
      children: [
        if (showTaxRate) ...[
          Expanded(
            child: _MobileCartReadOnlyField(
              key: ValueKey('tax-rate-${item.product.productId}'),
              label: 'Tax %',
              value: taxRate.toString(),
            ),
          ),
          if (showTaxAmount) const SizedBox(width: 8),
        ],
        if (showTaxAmount)
          Expanded(
            child: _MobileCartReadOnlyField(
              key: ValueKey('tax-amt-${item.product.productId}'),
              label: 'Tax',
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
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700,
      ),
      decoration: _cartFieldDecoration(label: widget.label, readOnly: true),
    );
  }
}
