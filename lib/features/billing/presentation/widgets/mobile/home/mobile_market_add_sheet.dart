import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Bottom sheet for adding a market product with custom price, quantity, and
/// optional sale-unit — mirrors desktop billing product-entry fields.
Future<MobileMarketAddFormValues?> showMobileMarketAddSheet({
  required BuildContext context,
  required GetProduct product,
}) {
  return showModalBottomSheet<MobileMarketAddFormValues>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _MobileMarketAddSheet(product: product),
  );
}

class _MobileMarketAddSheet extends StatefulWidget {
  const _MobileMarketAddSheet({required this.product});

  final GetProduct product;

  @override
  State<_MobileMarketAddSheet> createState() => _MobileMarketAddSheetState();
}

class _MobileMarketAddSheetState extends State<_MobileMarketAddSheet> {
  static const _controller = BillingMobileMarketController();

  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _mrpController;
  late final FocusNode _quantityFocus;
  late final FocusNode _priceFocus;
  late final FocusNode _mrpFocus;

  String _selectedUnit = 'base';

  @override
  void initState() {
    super.initState();
    _quantityController =
        TextEditingController(text: _controller.defaultQuantityText());
    _priceController = TextEditingController(
      text: _controller.formatAddFieldPrice(
        _controller.defaultUnitPrice(widget.product),
      ),
    );
    _mrpController = TextEditingController(
      text: _controller.formatAddFieldPrice(
        _controller.defaultMrp(widget.product),
      ),
    );

    _quantityFocus = FocusNode();
    _priceFocus = FocusNode();
    _mrpFocus = FocusNode();

    for (final node in [_quantityFocus, _priceFocus, _mrpFocus]) {
      final controller = node == _quantityFocus
          ? _quantityController
          : node == _priceFocus
              ? _priceController
              : _mrpController;
      _attachSelectAllOnFocus(node, controller);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _quantityFocus.requestFocus();
    });
  }

  void _attachSelectAllOnFocus(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      if (node.hasFocus && controller.text.isNotEmpty) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
  }

  void _selectAll(TextEditingController controller) {
    if (controller.text.isEmpty) return;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    _mrpFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final showMrp =
        context.read<AppSettingsProvider>().appSettings?.showMrpPos ?? false;
    final parseResult = _controller.parseAddForm(
      quantityText: _quantityController.text,
      priceText: _priceController.text,
      mrpText: showMrp ? _mrpController.text : null,
    );

    if (!parseResult.success) {
      showScaffoldError(
        context: context,
        message: parseResult.errorMessage ?? 'Invalid input',
      );
      return;
    }

    final saleUnit = _controller.resolveSaleUnit(widget.product, _selectedUnit);
    final values = parseResult.values!.copyWith(selectedSaleUnit: saleUnit);
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product.productName ?? 'Product';
    final showMrp =
        context.watch<AppSettingsProvider>().appSettings?.showMrpPos ?? false;
    final unitOptions = _controller.saleUnitOptionsForProduct(widget.product);
    final canChangeUnit = _controller.canChangeSaleUnit(widget.product);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (canChangeUnit) ...[
            InputDecorator(
              decoration: _fieldDecoration(label: 'Sale unit'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedUnit,
                  items: [
                    for (final option in unitOptions)
                      DropdownMenuItem(
                        value: option.value,
                        child: Text(
                          option.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedUnit = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _SelectAllNumberField(
                  controller: _quantityController,
                  focusNode: _quantityFocus,
                  label: 'Quantity',
                  onTap: () => _selectAll(_quantityController),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SelectAllNumberField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  label: 'Unit price',
                  onTap: () => _selectAll(_priceController),
                ),
              ),
            ],
          ),
          if (showMrp) ...[
            const SizedBox(height: 12),
            _SelectAllNumberField(
              controller: _mrpController,
              focusNode: _mrpFocus,
              label: 'MRP',
              onTap: () => _selectAll(_mrpController),
            ),
          ],
          const SizedBox(height: 20),
          Semantics(
            label: 'Add product to cart',
            button: true,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                      'Add to cart',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: Colors.grey.shade600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

class _SelectAllNumberField extends StatelessWidget {
  const _SelectAllNumberField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onTap: onTap,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
