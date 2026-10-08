import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
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

  static final Set<_PriceTextFieldState> _mounted = {};

  /// Commits a price the cashier typed but has not confirmed yet with blur,
  /// Enter or Tab. Keyboard shortcuts (checkout, discount, pay) do not move
  /// focus, so they call this before acting on the cart; otherwise checkout
  /// would open with the old price and the typed one would land afterwards.
  static void commitPendingEdits() {
    for (final state in List.of(_mounted)) {
      state._commitPendingEdit();
    }
  }
}

class _PriceTextFieldState extends State<PriceTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;
  bool _suppressPriceListener = false;
  bool _priceEdited = false;
  double? _automaticPriceAtFocus;
  late String _lastControllerText;

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

  /// Whether [displayPrice] is the current price of a line whose price is
  /// still automatic (standard, wholesale or offer). Committing it is not an
  /// edit: the line must not become manual, lose its offer, or be clamped to
  /// the minimum margin (which never applies to offer prices). Offer prices
  /// carry up to 3 decimals, so values within half a thousandth match.
  bool _isUnchangedAutomaticPrice(double displayPrice) {
    if (widget.item.isManualPriceOverride == true) return false;
    return (displayPrice - _displayPrice()).abs() < 0.0005;
  }

  void _setControllerText(String text) {
    _suppressPriceListener = true;
    _lastControllerText = text;
    controller.text = text;
    _suppressPriceListener = false;
  }

  void _setControllerValue(TextEditingValue value) {
    _suppressPriceListener = true;
    _lastControllerText = value.text;
    controller.value = value;
    _suppressPriceListener = false;
  }

  // Listener to sync controller changes (including on-screen keyboard input) with provider
  void _handleTextChanged() {
    if (_suppressPriceListener) return;
    // Selection changes also notify the controller. They are not price edits.
    if (controller.text == _lastControllerText) return;
    _lastControllerText = controller.text;

    // Keep input local until blur/Enter/Tab, including virtual-keyboard input.
    _priceEdited = true;
  }

  @override
  void initState() {
    super.initState();
    PriceTextField._mounted.add(this);
    controller = TextEditingController(text: _displayPrice().toString());
    _lastControllerText = controller.text;
    focusNode = FocusNode(onKeyEvent: (node, event) => _handleFieldKey(event));

    // Listen for any text changes from either physical or virtual keyboards
    controller.addListener(_handleTextChanged);
    // Enforce the minimum sale price whenever the field loses focus (e.g. the
    // cashier taps another field without explicitly submitting).
    focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (focusNode.hasFocus) {
      _priceEdited = false;
      _automaticPriceAtFocus = widget.item.isManualPriceOverride == true
          ? null
          : _displayPrice();
      _setControllerText(_displayPrice().toString());
    } else {
      _commitPrice();
    }
  }

  bool _isPriceEditing(KeyboardProvider keyboardProvider) =>
      focusNode.hasFocus ||
          (keyboardProvider.showKeyboard &&
              identical(keyboardProvider.controller, controller));

  /// Clamps the entered price up to the product's minimum sale price when it
  /// would otherwise drop below the configured discount floor.
  /// Returns true when a clamp was applied (price was below the floor).
  bool _enforceMinSalePrice() {
    final parsedPrice = double.tryParse(controller.text);
    if (parsedPrice == null) return false;
    if (_isUnchangedAutomaticPrice(parsedPrice)) return false;

    final double? minBase =
        widget.localProductProvider.minimumSalePriceForCartItem(widget.item);
    if (minBase == null) return false;

    final enteredBase = _toBasePrice(parsedPrice);
    // Small epsilon to avoid rounding-induced false positives.
    if (enteredBase >= minBase - 0.001) return false;

    widget.localProductProvider.updateItemPrice(
      widget.item.product.productId!,
      widget.item.selectedStock,
      minBase,
      stockGroupIds: widget.item.stockGroupIds,
      saleUnitId: widget.item.saleUnitId,
      variantId: widget.item.variantId,
    );

    final minDisplay =
        (widget.item.toDisplayAmount(minBase) ?? minBase) as double;
    final text = _formatPrice(minDisplay);
    _setControllerValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ));

    if (mounted) {
      showScaffoldError(
        context: context,
        message:
            'Price can\'t go below the minimum sale price of ${_formatPrice(minDisplay)}.',
      );
    }
    return true;
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

  void _commitPrice() {
    final parsedPrice = double.tryParse(controller.text);
    if (!_priceEdited ||
        (parsedPrice != null &&
            (_isUnchangedAutomaticPrice(parsedPrice) ||
                (_automaticPriceAtFocus != null &&
                    (parsedPrice - _automaticPriceAtFocus!).abs() < 0.0005)))) {
      // Retyping the original automatic value follows any newer offer too.
      _setControllerText(_displayPrice().toString());
    } else if (parsedPrice != null && parsedPrice >= 0) {
      // Clamp to the minimum sale price; only set the entered price when it is
      // at or above the floor.
      if (!_enforceMinSalePrice()) {
        widget.localProductProvider.updateItemPrice(
          widget.item.product.productId!,
          widget.item.selectedStock,
          _toBasePrice(parsedPrice),
          stockGroupIds: widget.item.stockGroupIds,
          saleUnitId: widget.item.saleUnitId,
          variantId: widget.item.variantId,
        );
      }
    } else {
      _setControllerText(_displayPrice().toString());
    }
    _priceEdited = false;
  }

  void _commitAndEndEditing() {
    _commitPrice();
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
    return '${item.product.productId}-${item.selectedStock?.id ?? 'base'}-$groupKey-${item.saleUnitId ?? 'base'}-${item.variantId ?? 'variant-base'}';
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
      _setControllerText(_displayPrice().toString());
    }
    if (_shouldHandleEditRequest(oldWidget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _beginEditing();
        }
      });
    }
  }

  void _commitPendingEdit() {
    if (mounted && _priceEdited) _commitPrice();
  }

  @override
  void dispose() {
    PriceTextField._mounted.remove(this);
    controller.removeListener(_handleTextChanged);
    focusNode.removeListener(_handleFocusChange);
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

        // Preserve actual cashier edits while the field or its virtual
        // keyboard is active. An untouched field follows automatic prices.
        final keyboardProvider =
            Provider.of<KeyboardProvider>(context, listen: false);

        if (!_isPriceEditing(keyboardProvider) &&
            controller.text != currentPrice) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isPriceEditing(keyboardProvider)) {
              _setControllerText(_displayPrice().toString());
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
            hintText: 'product_detail.price'.tr,
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: fontProvider.billingTableInputSize,
            ),
          ),
          onTap: () {
            _beginEditing();
          },
          onChanged: (newPrice) {
            _priceEdited = true;
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
        variantId: widget.item.variantId,
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
            hintText: 'product_detail.mrp'.tr,
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
                variantId: widget.item.variantId,
              );
            } else if (newMrp.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
                stockGroupIds: widget.item.stockGroupIds,
                saleUnitId: widget.item.saleUnitId,
                variantId: widget.item.variantId,
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
                variantId: widget.item.variantId,
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
            hintText: 'billing.tax'.tr,
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
