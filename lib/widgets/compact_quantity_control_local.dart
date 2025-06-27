import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
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

  const CompactQuantityControlLocal({
    Key? key,
    required this.quantity,
    required this.productId,
    this.product,
    this.cartId,
    this.unitPrice,
    this.productUnit,
    this.cartItemId,
    this.onQuantityChanged,
    this.selectedStock,
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

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.quantity;
    _controller = TextEditingController(text: _currentQuantity.toString());
    _focusNode = FocusNode();
    
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

  @override
  void didUpdateWidget(CompactQuantityControlLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the quantity prop has changed
    if (widget.quantity != oldWidget.quantity &&
        widget.quantity != _currentQuantity) {
      setState(() {
        _currentQuantity = widget.quantity;
        _controller.text = _currentQuantity.toString();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
      _controller.text = _currentQuantity.toString();
    });

    // Cancel existing timer if any
    _debounceTimer?.cancel();

    // Store the latest pending quantity
    _pendingQuantity = newQuantity;

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
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      if (newQuantity > widget.quantity) {
        // Calculate difference and add to cart
        final num difference = newQuantity - widget.quantity;
        
        // 🔧 FIX: Get current custom price and MRP from the existing cart item
        double? customPrice;
        double? customMrp;
        final existingItem = localProductProvider.cartItems.firstWhere(
          (item) => item.product.productId == widget.productId && 
                   item.selectedStock?.id == widget.selectedStock?.id,
          orElse: () => throw StateError('Item not found'),
        );
        customPrice = existingItem.price;
        customMrp = existingItem.mrp;
        
        localProductProvider.addToCart(
          product: widget.product!,
          quantity: difference,
          price: customPrice, // 🔧 FIX: Pass the current custom price
          mrp: customMrp, // 🔧 FIX: Pass the current custom MRP
          isIncreamentUsingCompactQuantityControl: true,
          selectedStock: widget.selectedStock,
        );
      } else if (newQuantity < widget.quantity) {
        // Calculate difference for decrements too
        final num difference = widget.quantity - newQuantity;
        // Call decrementCartItem for each item to remove
        for (int i = 0; i < difference; i++) {
          localProductProvider.decrementCartItem(
              widget.productId, widget.selectedStock);
        }
      }
    } finally {
      _isUpdating = false;
      _pendingQuantity = null;
    }
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
          width: 32,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 12),
            inputFormatters: [
              if (widget.productUnit == 'KG' || widget.productUnit == 'LT')
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              if (widget.productUnit != 'LT' && widget.productUnit != 'KG')
                FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 3),
            ),
            onTap: () {
              // Use a post-frame callback to ensure text selection happens after the tap is processed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_controller.text.isNotEmpty && _focusNode.hasFocus) {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                }
              });
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
