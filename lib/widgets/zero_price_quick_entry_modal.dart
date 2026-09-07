import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

/// Quick price/quantity entry dialog shown for zero-priced products,
/// before the product is added to the cart.
///
/// Pre-fills the price field with the customer's last bought price for the
/// product when [lastPurchase] is available. Pops `{'price': double,
/// 'quantity': num}` on Apply, or null when cancelled.
class ZeroPriceQuickEntryModal extends StatefulWidget {
  final GetProduct product;
  final num initialQuantity;
  final double? mrp;
  final num? stockQuantity;
  final String currency;
  final CustomerPurchaseItem? lastPurchase;
  final double? minimumPrice;

  const ZeroPriceQuickEntryModal({
    Key? key,
    required this.product,
    this.initialQuantity = 1,
    this.mrp,
    this.stockQuantity,
    required this.currency,
    this.lastPurchase,
    this.minimumPrice,
  }) : super(key: key);

  @override
  State<ZeroPriceQuickEntryModal> createState() =>
      _ZeroPriceQuickEntryModalState();
}

class _ZeroPriceQuickEntryModalState extends State<ZeroPriceQuickEntryModal> {
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  String? _errorText;

  static const _borderColor = Color(0xFFE2E8F0);
  static const _surfaceMuted = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    final double lastPrice = widget.lastPurchase?.priceValue ?? 0.0;
    _priceController = TextEditingController(
      text: lastPrice > 0 ? lastPrice.toStringAsFixed(2) : '',
    );
    _quantityController = TextEditingController(
      text: _formatQuantity(widget.initialQuantity),
    );
    _priceFocusNode.addListener(_onPriceFocusChange);
    _quantityFocusNode.addListener(_onQuantityFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusPriceField();
    });
  }

  void _onPriceFocusChange() {
    if (!mounted || !_priceFocusNode.hasFocus) return;
    _bindKeyboard(_priceController);
  }

  void _onQuantityFocusChange() {
    if (!mounted || !_quantityFocusNode.hasFocus) return;
    _bindKeyboard(_quantityController);
  }

  void _bindKeyboard(TextEditingController controller) {
    final keyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);
    if (!keyboardProvider.showKeyboardFeature) return;
    keyboardProvider.show('number', controller, replaceOnFirstInput: true);
  }

  void _focusPriceField() {
    _priceFocusNode.requestFocus();
    _priceController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _priceController.text.length,
    );
    _bindKeyboard(_priceController);
  }

  void _dismissKeyboardAndUnfocus() {
    if (!mounted) return;
    try {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      keyboardProvider.hide();
    } catch (_) {
      // Provider may already be gone during teardown.
    }
    _priceFocusNode.unfocus();
    _quantityFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  @override
  void dispose() {
    _priceFocusNode.removeListener(_onPriceFocusChange);
    _quantityFocusNode.removeListener(_onQuantityFocusChange);
    // Hide virtual keyboard so the background search field does not keep an
    // alphanumeric keyboard open after this dialog closes.
    try {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      if (identical(keyboardProvider.controller, _priceController) ||
          identical(keyboardProvider.controller, _quantityController)) {
        keyboardProvider.hide();
      }
    } catch (_) {}
    _priceController.dispose();
    _quantityController.dispose();
    _priceFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  String _formatQuantity(num quantity) {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toString();
  }

  num _currentQuantity() {
    return num.tryParse(_quantityController.text.trim()) ?? 0;
  }

  void _stepQuantity(num delta) {
    final num next = _currentQuantity() + delta;
    if (next < 1) return;
    setState(() {
      _quantityController.text = _formatQuantity(next);
    });
  }

  void _apply() {
    final double? price = double.tryParse(_priceController.text.trim());
    final num quantity = _currentQuantity();

    if (price == null || price <= 0) {
      setState(() => _errorText = 'Enter a valid price');
      _focusPriceField();
      return;
    }
    final double? minPrice = widget.minimumPrice;
    if (minPrice != null && price < minPrice - 0.001) {
      setState(() => _errorText =
          'Price is below the minimum sale price of ${minPrice.toStringAsFixed(2)}');
      _focusPriceField();
      return;
    }
    if (quantity <= 0) {
      setState(() => _errorText = 'Enter a valid quantity');
      _quantityFocusNode.requestFocus();
      _bindKeyboard(_quantityController);
      return;
    }

    _dismissKeyboardAndUnfocus();
    Navigator.of(context).pop(<String, dynamic>{
      'price': price,
      'quantity': quantity,
    });
  }

  void _cancel() {
    _dismissKeyboardAndUnfocus();
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    String? prefixText,
    bool hasError = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: hasError ? ColorManager.kErrorColor : _borderColor,
      ),
    );

    return InputDecoration(
      isDense: true,
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s14,
        0.18,
        ColorManager.kGreyColor,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: ColorManager.kPrimaryColor,
          width: 1.5,
        ),
      ),
      errorBorder: border,
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(
          color: ColorManager.kErrorColor,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final double mrp = widget.mrp ?? 0;
    final num? stockQuantity = widget.stockQuantity;
    final bool hasError = _errorText != null;
    final String? imageUrl = _resolvePrimaryImage(product);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorManager.kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sell_outlined,
                      size: 20,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'billing.set_price_quantity'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.bold,
                            FontSize.s16,
                            0.21,
                            ColorManager.kTitleTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'billing.enter_values_before_adding'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s12,
                            0.15,
                            ColorManager.kGreyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500, size: 22),
                    splashRadius: 20,
                    onPressed: _cancel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null) ...[
                          _ProductImage(url: imageUrl),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.productName ?? 'Unknown product',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.21,
                                  ColorManager.kTitleTextColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_hasProductMeta(
                                  product, mrp, stockQuantity)) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (product.unit != null &&
                                        product.unit!.isNotEmpty)
                                      _metaChip(
                                        Icons.straighten,
                                        product.unit!,
                                      ),
                                    if (mrp > 0)
                                      _metaChip(
                                        Icons.local_offer_outlined,
                                        '${widget.currency} ${mrp.toStringAsFixed(2)}',
                                      ),
                                    if (stockQuantity != null)
                                      _metaChip(
                                        Icons.inventory_2_outlined,
                                        '${'stock.stock_prefix'.tr}: $stockQuantity',
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quantity control
                  _sectionLabel('stock.quantity'.tr),
                  const SizedBox(height: 8),
                  _QuantityStepper(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    onDecrement: () => _stepQuantity(-1),
                    onIncrement: () => _stepQuantity(1),
                    onTap: () {
                      _quantityFocusNode.requestFocus();
                      _bindKeyboard(_quantityController);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Price field – listed after quantity in the tree, but is the
                  // intended initial focus target (see _focusPriceField).
                  _sectionLabel('${'product_detail.price'.tr} (${widget.currency})'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    onTap: () {
                      _bindKeyboard(_priceController);
                      _priceController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _priceController.text.length,
                      );
                    },
                    onSubmitted: (_) => _apply(),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    decoration: _fieldDecoration(
                      hintText: '0.00',
                      hasError: hasError,
                      prefixText: '${widget.currency} ',
                    ),
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.19,
                      ColorManager.kTitleTextColor,
                    ),
                  ),

                  if (hasError) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: ColorManager.kErrorColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorManager.kErrorColor.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.15,
                                Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: _surfaceMuted,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: _borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorManager.kTextColor,
                        side: const BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'general.cancel'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.18,
                          ColorManager.kTextColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.kPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'general.apply'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.18,
                          Colors.white,
                        ),
                      ),
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

  bool _hasProductMeta(GetProduct product, double mrp, num? stockQuantity) {
    return (product.unit != null && product.unit!.isNotEmpty) ||
        mrp > 0 ||
        stockQuantity != null;
  }

  String? _resolvePrimaryImage(GetProduct product) {
    if (product.attachment == null || product.attachment!.isEmpty) return null;
    for (final attachment in product.attachment!) {
      if (attachment.isPrimary == 1 && (attachment.filePath ?? '').isNotEmpty) {
        return attachment.filePath;
      }
    }
    final fallback = product.attachment!.first.filePath;
    return (fallback != null && fallback.isNotEmpty) ? fallback : null;
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s12,
        0.15,
        ColorManager.kTextColor,
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ColorManager.kGreyColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.14,
              ColorManager.kTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
        color: Colors.white,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F5F9),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 24,
              color: Colors.grey.shade400,
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onTap;

  const _QuantityStepper({
    required this.controller,
    required this.focusNode,
    required this.onDecrement,
    required this.onIncrement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StepperButton(
              icon: Icons.remove,
              onPressed: onDecrement,
              roundedLeft: true,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                onTap: onTap,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s16,
                  0.19,
                  ColorManager.kTitleTextColor,
                ),
              ),
            ),
            Container(width: 1, color: const Color(0xFFE2E8F0)),
            _StepperButton(
              icon: Icons.add,
              onPressed: onIncrement,
              roundedLeft: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool roundedLeft;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.roundedLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
