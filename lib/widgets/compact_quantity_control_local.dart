import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class CompactQuantityControlLocal extends StatefulWidget {
  final num quantity;
  final int productId;
  final GetProduct? product;
  final int? cartId;
  final int? cartItemId;
  final String? unitPrice;
  final String? productUnit;
  final Function()? onQuantityChanged;
  final Stock? selectedStock;
  final LocalCartItem cartItem;
  final int editRequestId;
  final String? editRequestKey;

  const CompactQuantityControlLocal({
    Key? key,
    required this.quantity,
    required this.productId,
    required this.cartItem,
    this.product,
    this.cartId,
    this.unitPrice,
    this.productUnit,
    this.cartItemId,
    this.onQuantityChanged,
    this.selectedStock,
    this.editRequestId = 0,
    this.editRequestKey,
  }) : super(key: key);

  @override
  State<CompactQuantityControlLocal> createState() =>
      _CompactQuantityControlLocalState();
}

class _CompactQuantityControlLocalState
    extends State<CompactQuantityControlLocal> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late num _currentQuantity;
  Timer? _debounceTimer;
  bool _isUpdating = false;

  // Queue to store pending quantity updates
  num? _pendingQuantity;

  // Handle controller text changes (including from virtual keyboard)
  void _onControllerChanged() {
    final parsed = num.tryParse(_controller.text);
    if (parsed != null && parsed != _currentQuantity) {
      _handleQuantityChange(parsed);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentQuantity = _displayQuantityForBase(widget.quantity);
    _controller =
        TextEditingController(text: _formatQuantity(_currentQuantity));
    _focusNode = FocusNode();

    // Listen to controller changes so virtual-keyboard input is captured
    _controller.addListener(_onControllerChanged);

    // Add listener to focus node to handle quantity changes when focus is lost
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        num? newQuantity = num.tryParse(_controller.text);
        if (newQuantity != null) {
          _handleQuantityChange(newQuantity);
        }
      }
    });
  }

  void _beginEditing() {
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text.isNotEmpty && _focusNode.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
    Provider.of<KeyboardProvider>(context, listen: false).show(
      'number',
      _controller,
      replaceOnFirstInput: true,
    );
  }

  bool _shouldHandleEditRequest(CompactQuantityControlLocal oldWidget) {
    return widget.editRequestId != oldWidget.editRequestId &&
        widget.editRequestKey != null &&
        widget.editRequestKey == _cartIdentityKey(widget.cartItem);
  }

  @override
  void didUpdateWidget(CompactQuantityControlLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool itemChanged = widget.productId != oldWidget.productId ||
        _cartIdentityKey(widget.cartItem) !=
            _cartIdentityKey(oldWidget.cartItem);

    if (itemChanged) {
      _debounceTimer?.cancel();
      _pendingQuantity = null;
      _isUpdating = false;
      _currentQuantity = _displayQuantityForBase(widget.quantity);
      _controller.text = _formatQuantity(_currentQuantity);

      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      if (keyboardProvider.showKeyboard &&
          identical(keyboardProvider.controller, _controller)) {
        keyboardProvider.hide();
      }

      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
      return;
    }

    if (_shouldHandleEditRequest(oldWidget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _beginEditing();
        }
      });
    }

    // Check if the quantity prop has changed
    if (widget.quantity != oldWidget.quantity &&
        widget.quantity != _currentQuantity) {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      final bool isEditing = _focusNode.hasFocus ||
          (keyboardProvider.showKeyboard &&
              identical(keyboardProvider.controller, _controller));

      if (!isEditing) {
        setState(() {
          _currentQuantity = _displayQuantityForBase(widget.quantity);
          _controller.text = _formatQuantity(_currentQuantity);
        });
      } else {
        // Just update the internal current value to stay in sync without touching text
        _currentQuantity = _displayQuantityForBase(widget.quantity);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Update UI immediately but debounce API calls
  void _handleQuantityChange(num newQuantity) {
    if (newQuantity < 0) return;

    // Update UI immediately
    setState(() {
      _currentQuantity = newQuantity;

      // Only update the TextEditingController when the field is *not* being
      // edited by the user. This prevents the current selection from being
      // reset on every key-stroke (which caused the previously typed digit to
      // be replaced). It now behaves the same way as PriceTextField.
      if (!_focusNode.hasFocus) {
        _controller.text = _formatQuantity(_currentQuantity);
      }
    });

    // Cancel existing timer if any
    _debounceTimer?.cancel();

    // Store the latest pending quantity
    _pendingQuantity = _toBaseQuantity(newQuantity);

    // Debounce API call
    _debounceTimer = Timer(const Duration(milliseconds: 0), () {
      if (_pendingQuantity != null && !_isUpdating) {
        _syncWithProvider(_pendingQuantity!);
      }
    });

    if (widget.onQuantityChanged != null) {
      widget.onQuantityChanged!(); // Use the null-aware operator
    }
  }

  Future<void> _syncWithProvider(num newQuantity) async {
    if (_isUpdating) return;

    _isUpdating = true;
    try {
      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        context: context,
        cartItem: widget.cartItem,
        newQuantity: newQuantity,
      );

      if (mounted) {
        _applyQuantityValue(result.appliedQuantity);
      }
    } finally {
      _isUpdating = false;
      _pendingQuantity = null;
    }
  }

  void _applyQuantityValue(num quantity) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentQuantity = _displayQuantityForBase(quantity);
      if (!_focusNode.hasFocus) {
        _controller.text = _formatQuantity(_currentQuantity);
      }
    });
  }

  String _cartIdentityKey(LocalCartItem item) {
    final groupKey = item.stockGroupIds.join('_');
    return '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-$groupKey-${item.saleUnitId ?? 'base'}';
  }

  num _displayQuantityForBase(num baseQuantity) {
    return widget.cartItem.toDisplayQuantity(baseQuantity);
  }

  num _toBaseQuantity(num displayQuantity) {
    return widget.cartItem.toBaseQuantity(displayQuantity);
  }

  String _formatQuantity(num value) {
    if (value is int) {
      return value.toString();
    }
    final roundedValue = value.roundToDouble();
    if ((value.toDouble() - roundedValue).abs() < 0.0001) {
      return roundedValue.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _handleQuantityChange(_currentQuantity - 1),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorManager.kPrimaryColor.withOpacity(0.1),
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.remove,
                size: 12, color: ColorManager.kPrimaryColor),
          ),
        ),
        SizedBox(
          width: 50,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 11),
            inputFormatters: [
              if (widget.productUnit == 'KG' ||
                  widget.productUnit == 'KGS' ||
                  widget.productUnit == 'LT')
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              if (widget.productUnit != 'LT' &&
                  widget.productUnit != 'KG' &&
                  widget.productUnit != 'KGS')
                FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 3),
            ),
            onTap: () {
              _beginEditing();
            },
            onSubmitted: (value) {
              num? newQuantity = num.tryParse(value);
              if (newQuantity != null) {
                _handleQuantityChange(newQuantity);
              }
            },
          ),
        ),
        InkWell(
          onTap: () => _handleQuantityChange(_currentQuantity + 1),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: ColorManager.kPrimaryColor,
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.add,
                size: 12, color: ColorManager.kSecondaryColor),
          ),
        ),
      ],
    );
  }
}
