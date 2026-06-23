import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:provider/provider.dart';

// Custom widget for price text field with stable controller and focus node
class PriceTextField extends StatefulWidget {
  final dynamic item;
  final dynamic localProductProvider;
  final int editRequestId;
  final String? editRequestKey;
  final VoidCallback? onEditingComplete;

  const PriceTextField({
    Key? key,
    required this.item,
    required this.localProductProvider,
    this.editRequestId = 0,
    this.editRequestKey,
    this.onEditingComplete,
  }) : super(key: key);

  @override
  State<PriceTextField> createState() => _PriceTextFieldState();
}

class _PriceTextFieldState extends State<PriceTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;

  double _displayPrice() {
    return (widget.item.displayPrice ?? widget.item.price ?? 0.0) as double;
  }

  double _toBasePrice(double displayPrice) {
    return (widget.item.toBaseAmount(displayPrice) ?? displayPrice) as double;
  }

  String _formatPrice(double value) {
    final roundedValue = value.roundToDouble();
    if ((value - roundedValue).abs() < 0.0001) {
      return roundedValue.toInt().toString();
    }
    return value.toString();
  }

  // Listener to sync controller changes (including on-screen keyboard input) with provider
  void _handleTextChanged() {
    final parsedPrice = double.tryParse(controller.text);
    if (parsedPrice != null && parsedPrice >= 0) {
      widget.localProductProvider.updateItemPrice(
        widget.item.product.productId!,
        widget.item.selectedStock,
        _toBasePrice(parsedPrice),
        stockGroupIds: widget.item.stockGroupIds,
        saleUnitId: widget.item.saleUnitId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _displayPrice().toString());
    focusNode = FocusNode(onKeyEvent: (node, event) => _handleFieldKey(event));

    // Listen for any text changes from either physical or virtual keyboards
    controller.addListener(_handleTextChanged);
  }

  void _beginEditing() {
    focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.text.isNotEmpty && focusNode.hasFocus) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
    Provider.of<KeyboardProvider>(context, listen: false).show(
      'number',
      controller,
      replaceOnFirstInput: true,
    );
  }

  void _stepPrice(int delta) {
    final currentPrice = double.tryParse(controller.text) ?? _displayPrice();
    final nextPrice = (currentPrice + delta).clamp(0.0, double.infinity);
    final text = _formatPrice(nextPrice);

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  void _commitAndEndEditing() {
    final parsedPrice = double.tryParse(controller.text);
    if (parsedPrice != null && parsedPrice >= 0) {
      widget.localProductProvider.updateItemPrice(
        widget.item.product.productId!,
        widget.item.selectedStock,
        _toBasePrice(parsedPrice),
        stockGroupIds: widget.item.stockGroupIds,
        saleUnitId: widget.item.saleUnitId,
      );
    } else {
      controller.text = _displayPrice().toString();
    }

    Provider.of<KeyboardProvider>(context, listen: false).hide();
    focusNode.unfocus();
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
      _stepPrice(1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _stepPrice(-1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _cartIdentityKey(dynamic item) {
    final groupKey = item.stockGroupIds.join('_');
    return '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-$groupKey-${item.saleUnitId ?? 'base'}';
  }

  bool _shouldHandleEditRequest(PriceTextField oldWidget) {
    return widget.editRequestId != oldWidget.editRequestId &&
        widget.editRequestKey != null &&
        widget.editRequestKey == _cartIdentityKey(widget.item);
  }

  @override
  void didUpdateWidget(PriceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only refresh controller text if the field is NOT focused
    if (!focusNode.hasFocus && oldWidget.item.price != widget.item.price) {
      controller.text = _displayPrice().toString();
    }
    if (_shouldHandleEditRequest(oldWidget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _beginEditing();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleTextChanged);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the price has changed and update the controller if needed
        final currentPrice = _displayPrice().toString();

        // Consider the field to be in-edit if it has focus OR a virtual keyboard is currently
        // shown for this controller. In that case we must NOT overwrite the text.
        final keyboardProvider =
            Provider.of<KeyboardProvider>(context, listen: false);
        final bool isEditing = focusNode.hasFocus ||
            (keyboardProvider.showKeyboard &&
                identical(keyboardProvider.controller, controller));

        if (!isEditing && controller.text != currentPrice) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentPrice;
            }
          });
        }

        final fontProvider =
            Provider.of<AppFontProvider>(context, listen: true);

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: fontProvider.billingTableInputSize),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'Price',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: fontProvider.billingTableInputSize,
            ),
          ),
          onTap: () {
            _beginEditing();
          },
          onChanged: (newPrice) {
            // Validate and update immediately on change
            final parsedPrice = double.tryParse(newPrice);
            if (parsedPrice != null && parsedPrice >= 0) {
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                _toBasePrice(parsedPrice),
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
              );
            } else if (newPrice.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
              );
            }
          },
          onSubmitted: (newPrice) {
            _commitAndEndEditing();
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

  double _displayMrp() {
    return (widget.item.displayMrp ?? widget.item.mrp ?? 0.0) as double;
  }

  double _toBaseMrp(double displayMrp) {
    return (widget.item.toBaseAmount(displayMrp) ?? displayMrp) as double;
  }

  // Listener to sync controller changes (including on-screen keyboard input) with provider
  void _handleTextChanged() {
    final parsedMrp = double.tryParse(controller.text);
    if (parsedMrp != null && parsedMrp >= 0) {
      widget.localProductProvider.updateItemMrp(
        widget.item.product.productId!,
        widget.item.selectedStock,
        _toBaseMrp(parsedMrp),
        stockGroupIds: widget.item.stockGroupIds,
        saleUnitId: widget.item.saleUnitId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _displayMrp().toString());
    focusNode = FocusNode();

    // Listen for any text changes from either physical or virtual keyboards
    controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(MrpTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only refresh controller text if the field is NOT focused
    if (!focusNode.hasFocus && oldWidget.item.mrp != widget.item.mrp) {
      controller.text = _displayMrp().toString();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleTextChanged);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the MRP has changed and update the controller if needed
        final currentMrp = _displayMrp().toString();

        final keyboardProvider =
            Provider.of<KeyboardProvider>(context, listen: false);
        final bool isEditing = focusNode.hasFocus ||
            (keyboardProvider.showKeyboard &&
                identical(keyboardProvider.controller, controller));

        if (!isEditing && controller.text != currentMrp) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentMrp;
            }
          });
        }

        final fontProvider =
            Provider.of<AppFontProvider>(context, listen: true);

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: fontProvider.billingTableInputSize),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'MRP',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: fontProvider.billingTableInputSize,
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

            Provider.of<KeyboardProvider>(context, listen: false).show(
              'number',
              controller,
              replaceOnFirstInput: true,
            );
          },
          onChanged: (newMrp) {
            // Validate and update immediately on change
            final parsedMrp = double.tryParse(newMrp);
            if (parsedMrp != null && parsedMrp >= 0) {
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                _toBaseMrp(parsedMrp),
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
              );
            } else if (newMrp.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
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
                _toBaseMrp(parsedMrp),
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
              );
            } else {
              // Revert to original MRP if invalid
              controller.text = _displayMrp().toString();
            }
          },
        );
      },
    );
  }
}

class TaxTextField extends StatelessWidget {
  final LocalCartItem item;
  final LocalProductProvider localProductProvider;

  const TaxTextField({
    super.key,
    required this.item,
    required this.localProductProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppFontProvider>(
      builder: (context, fontProvider, child) {
        // Display Tax Rate (Percentage) - Read Only
        final taxRate = (item.taxRate ?? 0.0).toString();

        return TextField(
          controller: TextEditingController(text: taxRate),

          readOnly: true, // Make read-only as requested
          enabled: false, // Visually disable editing
          textAlign: TextAlign.left,
          keyboardType: TextInputType.number,
          style: TextStyle(
              fontSize: fontProvider.billingTableInputSize,
              color: Colors.black),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'Tax',
            hintStyle: TextStyle(
              color: Colors.black,
              fontSize: fontProvider.billingTableInputSize,
            ),
          ),
        );
      },
    );
  }
}
