import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class CompactQuantityControl extends StatefulWidget {
  final int quantity;
  final Function(int newQuantity) onQuantityChanged;

  const CompactQuantityControl({
    Key? key,
    required this.quantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  _CompactQuantityControlState createState() => _CompactQuantityControlState();
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
    if (newQuantity >= 0) {
      setState(() {
        _currentQuantity = newQuantity;
        _controller.text = _currentQuantity.toString(); // Update text field
      });
      widget.onQuantityChanged(newQuantity);
    }
  }

  void _incrementQuantity() {
    int newQuantity = _currentQuantity + 1;
    _updateQuantity(newQuantity);
  }

  void _decrementQuantity() {
    int newQuantity = _currentQuantity - 1;
    _updateQuantity(newQuantity);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
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
            width: 40, // Fixed width for the text field
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
                _updateQuantity(newQuantity ??
                    _currentQuantity); // Fallback to current quantity
              },
              // onChanged: (value) {
              //   int? newQuantity = int.tryParse(value);
              //   if (newQuantity != null) {
              //     _updateQuantity(newQuantity);
              //   }
              // },
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
      ),
    );
  }
}
