import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class CompactQuantityControl extends StatefulWidget {
  final int quantity;
  final int productId;
  final int? cartItemId;
  final String? unitPrice;

  const CompactQuantityControl({
    Key? key,
    required this.quantity,
    required this.productId,
    this.unitPrice,
    this.cartItemId,
  }) : super(key: key);

  @override
  State<CompactQuantityControl> createState() => _CompactQuantityControlState();
}

class _CompactQuantityControlState extends State<CompactQuantityControl> {
  late TextEditingController _controller;
  late int _currentQuantity;

  @override
  void initState() {
    super.initState();
    _currentQuantity = widget.quantity;
    _controller = TextEditingController(text: _currentQuantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQuantity) {
    // Only allow updates through the API response
    if (newQuantity >= 0) {
      setState(() {
        _currentQuantity = newQuantity;
        _controller.text = _currentQuantity.toString(); // Update text field
      });
    }
  }

  Future<void> _incrementQuantity() async {
    // Make API call to increase quantity
    int newQuantity = _currentQuantity + 1;

    // Retrieve access token and user ID
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int userId = Provider.of<AuthModel>(context, listen: false).userId!;

    // Update cart via API
    var response =
        await Provider.of<CartProvider>(context, listen: false).addToCartAPI(
      accessToken: accessToken ?? "",
      customerId: userId,
      unitPrice: widget.unitPrice,
      productId: widget.productId,
      quantity: 1, // Increment by 1
    );

    // Handle the API response
    if (response["status"] == "success") {
      _updateQuantity(newQuantity); // Update UI if API call is successful
    } else {
      // Display error message
      showScaffoldError(
        context: context,
        message: response["message"] ?? "Error Occurred! Try Again",
      );
    }
  }

  Future<void> _decrementQuantity() async {
    int newQuantity = _currentQuantity - 1;

    if (newQuantity >= 0) {
      // Make API call to decrease quantity
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      int userId = Provider.of<AuthModel>(context, listen: false).userId!;

      // Call your API method to decrement the quantity
      var response = await Provider.of<CartProvider>(context, listen: false)
          .decrementCartItemQuantityAPI(
        accessToken: accessToken ?? "",
        customerId: userId,
        productId: widget.cartItemId!,
        remove: '',
        quantity: newQuantity, // set to new quantity
      );

      // Check if the API call was successful
      if (response["status"] == "success") {
        _updateQuantity(newQuantity); // Update UI if successful
      } else {
        showScaffoldError(
          context: context,
          message: response["message"] ?? "Error Occurred! Try Again",
        );
      }
    }
  }

  Future<void> _chnageQuantity(int newQuantity) async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int userId = Provider.of<AuthModel>(context, listen: false).userId!;
    if (newQuantity > widget.quantity) {
      Provider.of<CartProvider>(context, listen: false)
          .addToCartAPI(
        accessToken: accessToken!,
        customerId: userId,
        unitPrice: widget.unitPrice,
        productId: widget.productId,
        quantity: newQuantity - widget.quantity,
      )
          .then(
        (value) {
          AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
          if (value["status"] == "success") {
            if (mounted) {
              showScaffold(
                context: context,
                message: 'Quantity Updated Successfully',
              );
            }
            _updateQuantity(newQuantity);
          } else {
            if (mounted) {
              showScaffoldError(
                context: context,
                message: addToCartModel.message ?? "Error Occured ! Try Again",
              );
            }
          }
        },
      );
    } else if (newQuantity < widget.quantity) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<CartProvider>(context, listen: false)
          .decrementCartItemQuantityAPI(
        accessToken: accessToken ?? "",
        customerId: Provider.of<AuthModel>(context, listen: false).userId!,
        productId: widget.cartItemId!,
        remove: '',
        quantity: newQuantity,
      )
          .then(
        (value) {
          AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
          if (value["status"] == "success") {
            if (mounted) {
              showScaffold(
                context: context,
                message: 'Quantity Updated Successfully',
              );
            }
            _updateQuantity(newQuantity);
          } else {
            if (mounted) {
              showScaffoldError(
                context: context,
                message: addToCartModel.message ?? "Error Occured ! Try Again",
              );
            }
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _decrementQuantity,
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
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 5),
            ),
            onSubmitted: (value) {
              int? newQuantity = int.tryParse(value);
              _chnageQuantity(newQuantity ?? _currentQuantity);
            },
          ),
        ),
        InkWell(
          onTap: _incrementQuantity,
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
