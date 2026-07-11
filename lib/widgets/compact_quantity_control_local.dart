import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
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
  final VoidCallback? onEditingComplete;
  final int refreshRequestId;
  final String? refreshRequestKey;
  final num? refreshQuantity;

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
    this.onEditingComplete,
    this.refreshRequestId = 0,
    this.refreshRequestKey,
    this.refreshQuantity,
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
  bool _isEditingQuantityText = false;

  // Queue to store pending quantity updates
  num? _pendingQuantity;

  // Handle controller text changes (including from virtual keyboard)
  void _onControllerChanged() {
    final text = _controller.text.trim();
    if (_isEditingQuantityText &&
        (text.isEmpty || text == '0' || text == '0.')) {
      return;
    }

    final parsed = num.tryParse(text);
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
    _focusNode = FocusNode(onKeyEvent: (node, event) => _handleFieldKey(event));

    // Listen to controller changes so virtual-keyboard input is captured
    _controller.addListener(_onControllerChanged);

    // Add listener to focus node to handle quantity changes when focus is lost
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        if (_isEditingQuantityText) {
          num? newQuantity = num.tryParse(_controller.text);
          _isEditingQuantityText = false;
          if (newQuantity != null) {
            _handleQuantityChange(newQuantity, updateControllerText: true);
          }
        }
      }
    });
  }

  void _beginEditing() {
    _isEditingQuantityText = true;
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

  void _commitAndEndEditing() {
    final newQuantity = num.tryParse(_controller.text);
    if (newQuantity != null) {
      _handleQuantityChange(newQuantity, updateControllerText: true);
    }

    _isEditingQuantityText = false;
    Provider.of<KeyboardProvider>(context, listen: false).hide();
    _focusNode.unfocus();
    widget.onEditingComplete?.call();
  }

  KeyEventResult _handleFieldKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _commitAndEndEditing();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _handleQuantityChange(_currentQuantity + 1, updateControllerText: true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _handleQuantityChange(_currentQuantity - 1, updateControllerText: true);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _shouldHandleEditRequest(CompactQuantityControlLocal oldWidget) {
    return widget.editRequestId != oldWidget.editRequestId &&
        widget.editRequestKey != null &&
        widget.editRequestKey == _cartIdentityKey(widget.cartItem);
  }

  bool _shouldHandleRefreshRequest(CompactQuantityControlLocal oldWidget) {
    return widget.refreshRequestId != oldWidget.refreshRequestId &&
        widget.refreshRequestKey != null &&
        widget.refreshRequestKey == _cartIdentityKey(widget.cartItem) &&
        widget.refreshQuantity != null;
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
      _isEditingQuantityText = false;
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

    if (_shouldHandleRefreshRequest(oldWidget)) {
      debugPrint(
        '🧮 [CompactQuantityControlLocal] explicit refresh '
        'productId=${widget.productId}, quantity=${widget.refreshQuantity}',
      );
      _isEditingQuantityText = false;
      _applyQuantityValue(widget.refreshQuantity!, forceControllerText: true);
      return;
    }

    // Check if the quantity prop has changed
    final displayQuantity = _displayQuantityForBase(widget.quantity);
    if (displayQuantity != _currentQuantity) {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      final bool isEditing = _isEditingQuantityText ||
          (keyboardProvider.showKeyboard &&
              identical(keyboardProvider.controller, _controller));

      if (!isEditing) {
        setState(() {
          _currentQuantity = displayQuantity;
          _controller.text = _formatQuantity(_currentQuantity);
        });
      } else {
        // Just update the internal current value to stay in sync without touching text
        _currentQuantity = displayQuantity;
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
  void _handleQuantityChange(
    num newQuantity, {
    bool updateControllerText = false,
  }) {
    if (newQuantity < 0) return;

    // Update UI immediately
    setState(() {
      _currentQuantity = newQuantity;

      // Only update the TextEditingController when the field is *not* being
      // edited by the user. This prevents the current selection from being
      // reset on every key-stroke (which caused the previously typed digit to
      // be replaced). It now behaves the same way as PriceTextField.
      if (updateControllerText || !_isEditingQuantityText) {
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

  void _applyQuantityValue(
    num quantity, {
    bool forceControllerText = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentQuantity = _displayQuantityForBase(quantity);
      if (forceControllerText || !_isEditingQuantityText) {
        _controller.text = _formatQuantity(_currentQuantity);
      }
    });
  }

  String _cartIdentityKey(LocalCartItem item) {
    final groupKey = item.stockGroupIds.join('_');
    return '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-$groupKey-${item.saleUnitId ?? 'base'}-${item.variantId ?? 'variant-base'}';
  }

  num _displayQuantityForBase(num baseQuantity) {
    return _roundDisplayQuantity(
        widget.cartItem.toDisplayQuantity(baseQuantity));
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
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  num _roundDisplayQuantity(num value) {
    if (value is int) {
      return value;
    }

    final roundedValue = value.roundToDouble();
    if ((value.toDouble() - roundedValue).abs() < 0.0001) {
      return roundedValue.toInt();
    }

    return double.parse(value.toStringAsFixed(3));
  }

  void _syncControllerTextAfterBuild({
    required num displayQuantity,
    required String reason,
  }) {
    if (_isEditingQuantityText) {
      return;
    }

    final displayText = _formatQuantity(displayQuantity);
    if (_currentQuantity == displayQuantity &&
        _controller.text == displayText) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isEditingQuantityText) {
        return;
      }

      debugPrint(
        '🧮 [CompactQuantityControlLocal] sync text ($reason) '
        'productId=${widget.productId}, '
        'widgetQuantity=${widget.quantity}, '
        'displayQuantity=$displayQuantity, '
        'currentQuantity=$_currentQuantity, '
        'controllerText="${_controller.text}" -> "$displayText"',
      );

      setState(() {
        _currentQuantity = displayQuantity;
        _controller.text = displayText;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncControllerTextAfterBuild(
      displayQuantity: _displayQuantityForBase(widget.quantity),
      reason: 'build',
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _handleQuantityChange(
            _currentQuantity - 1,
            updateControllerText: true,
          ),
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
            inputFormatters: quantityInputFormattersForUnit(widget.productUnit),
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
              _commitAndEndEditing();
            },
          ),
        ),
        InkWell(
          onTap: () => _handleQuantityChange(
            _currentQuantity + 1,
            updateControllerText: true,
          ),
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
