import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class CompactQuantityControl extends StatefulWidget {
  final num quantity;
  final int productId;
  final int? cartItemId;
  final int? cartId;
  final String? unitPrice;
  final String? productUnit;
  final Function()? onQuantityChanged;

  const CompactQuantityControl({
    Key? key,
    required this.quantity,
    required this.productId,
    this.unitPrice,
    this.productUnit,
    this.cartItemId,
    this.cartId,
    this.onQuantityChanged,
  }) : super(key: key);

  @override
  State<CompactQuantityControl> createState() => _CompactQuantityControlState();
}

class _CompactQuantityControlState extends State<CompactQuantityControl> {
  late TextEditingController _controller;
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
  }

  @override
  void didUpdateWidget(CompactQuantityControl oldWidget) {
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
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingQuantity != null && !_isUpdating) {
        _syncWithServer(_pendingQuantity!);
      }
    });

    if (widget.onQuantityChanged != null) {
      widget.onQuantityChanged!(); // Use the null-aware operator
    }
  }

  Future<void> _syncWithServer(num newQuantity) async {
    if (_isUpdating) return;

    _isUpdating = true;
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      int userId = Provider.of<AuthModel>(context, listen: false).userId!;

      if (newQuantity > widget.quantity) {
        // Calculate difference and make single API call
        final difference = newQuantity - widget.quantity;

        var response = await Provider.of<CartProvider>(context, listen: false)
            .addToCartAPI(
          accessToken: accessToken ?? "",
          customerId: userId,
          unitPrice: widget.unitPrice,
          productId: widget.productId,
          quantity: difference,
          cartId: widget.cartId,
        );

        if (response["status"] != "success") {
          // Revert UI on error
          _revertUIOnError(response["message"]);
        }
      } else if (newQuantity < widget.quantity) {
        var response = await Provider.of<CartProvider>(context, listen: false)
            .decrementCartItemQuantityAPI(
          accessToken: accessToken ?? "",
          customerId: userId,
          productId: widget.cartItemId!,
          remove: '',
          quantity: newQuantity,
          cartId: widget.cartId,
        );

        if (response["status"] != "success") {
          _revertUIOnError(response["message"]);
        }
      }
    } finally {
      _isUpdating = false;
      _pendingQuantity = null;
    }
  }

  void _revertUIOnError(String? message) {
    if (mounted) {
      setState(() {
        _currentQuantity = widget.quantity;
        _controller.text = _currentQuantity.toString();
      });
      showScaffoldError(
        context: context,
        message: message ?? "Error Occurred! Try Again",
      );
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
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.remove,
                size: 16, color: ColorManager.kPrimaryColor),
          ),
        ),
        SizedBox(
          width: 40,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              if (widget.productUnit == 'KG' || widget.productUnit == 'LT')
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              if (widget.productUnit != 'LT' && widget.productUnit != 'KG')
                FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 5),
            ),
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
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.add,
                size: 16, color: ColorManager.kSecondaryColor),
          ),
        ),
      ],
    );
  }
}
