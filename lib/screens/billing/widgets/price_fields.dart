import 'package:flutter/material.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

// Custom widget for price text field with stable controller and focus node
class PriceTextField extends StatefulWidget {
  final dynamic item;
  final dynamic localProductProvider;

  const PriceTextField({
    Key? key,
    required this.item,
    required this.localProductProvider,
  }) : super(key: key);

  @override
  State<PriceTextField> createState() => _PriceTextFieldState();
}

class _PriceTextFieldState extends State<PriceTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.item.price.toString());
    focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(PriceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if price has changed
    if (oldWidget.item.price != widget.item.price) {
      controller.text = widget.item.price.toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the price has changed and update the controller if needed
        final currentPrice = widget.item.price.toString();
        if (!focusNode.hasFocus && controller.text != currentPrice) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentPrice;
            }
          });
        }

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'Price',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          onTap: () {
            // Use a post-frame callback to ensure text selection happens after the tap is processed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.text.isNotEmpty && focusNode.hasFocus) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            });
          },
          onChanged: (newPrice) {
            // Validate and update immediately on change
            final parsedPrice = double.tryParse(newPrice);
            if (parsedPrice != null && parsedPrice >= 0) {
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedPrice,
              );
            } else if (newPrice.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
              );
            }
          },
          onSubmitted: (newPrice) {
            // Validate and update on submit
            final parsedPrice = double.tryParse(newPrice);
            if (parsedPrice != null && parsedPrice >= 0) {
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedPrice,
              );
            } else {
              // Revert to original price if invalid
              controller.text = widget.item.price.toString();
            }
          },
        );
      },
    );
  }
}

// Custom widget for MRP text field with stable controller and focus node
class MrpTextField extends StatefulWidget {
  final dynamic item;
  final dynamic localProductProvider;

  const MrpTextField({
    Key? key,
    required this.item,
    required this.localProductProvider,
  }) : super(key: key);

  @override
  State<MrpTextField> createState() => _MrpTextFieldState();
}

class _MrpTextFieldState extends State<MrpTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller =
        TextEditingController(text: (widget.item.mrp ?? 0.0).toString());
    focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(MrpTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if MRP has changed
    if (oldWidget.item.mrp != widget.item.mrp) {
      controller.text = (widget.item.mrp ?? 0.0).toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the MRP has changed and update the controller if needed
        final currentMrp = (widget.item.mrp ?? 0.0).toString();
        if (!focusNode.hasFocus && controller.text != currentMrp) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentMrp;
            }
          });
        }

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'MRP',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          onTap: () {
            // Use a post-frame callback to ensure text selection happens after the tap is processed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.text.isNotEmpty && focusNode.hasFocus) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            });
          },
          onChanged: (newMrp) {
            // Validate and update immediately on change
            final parsedMrp = double.tryParse(newMrp);
            if (parsedMrp != null && parsedMrp >= 0) {
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedMrp,
              );
            } else if (newMrp.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
              );
            }
          },
          onSubmitted: (newMrp) {
            // Validate and update on submit
            final parsedMrp = double.tryParse(newMrp);
            if (parsedMrp != null && parsedMrp >= 0) {
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedMrp,
              );
            } else {
              // Revert to original MRP if invalid
              controller.text = (widget.item.mrp ?? 0.0).toString();
            }
          },
        );
      },
    );
  }
} 