import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

// Price Selection Modal Widget
class PriceSelectionModal extends StatefulWidget {
  final Function(double) onPriceSelected;
  final String productName;
  final List<double> prices;

  const PriceSelectionModal({
    Key? key,
    required this.onPriceSelected,
    required this.productName,
    required this.prices,
  }) : super(key: key);

  @override
  State<PriceSelectionModal> createState() => _PriceSelectionModalState();
}

class _PriceSelectionModalState extends State<PriceSelectionModal> {
  final FocusNode _priceGridFocusNode = FocusNode();
  int _focusedPriceIndex = 0;

  @override
  void initState() {
    super.initState();
    _priceGridFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _priceGridFocusNode.dispose();
    super.dispose();
  }

  void _selectPrice(BuildContext context, String currency, double price) {
    debugPrint("🎯 PRICE MODAL: User selected price: $currency$price");
    widget.onPriceSelected(price);
    Navigator.of(context).pop(price);
  }

  void _cancel(BuildContext context) {
    debugPrint("🎯 PRICE MODAL: User cancelled price selection");
    Navigator.of(context).pop();
  }

  KeyEventResult _handlePriceGridKey(
      BuildContext context, String currency, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel(context);
      return KeyEventResult.handled;
    }

    if (widget.prices.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final index =
          _focusedPriceIndex.clamp(0, widget.prices.length - 1).toInt();
      _selectPrice(context, currency, widget.prices[index]);
      return KeyEventResult.handled;
    }

    int? delta;
    if (key == LogicalKeyboardKey.arrowRight) {
      delta = 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      delta = -1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      delta = 4;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      delta = -4;
    }

    if (delta == null) {
      return KeyEventResult.ignored;
    }

    setState(() {
      _focusedPriceIndex = (_focusedPriceIndex + delta!)
          .clamp(0, widget.prices.length - 1)
          .toInt();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // Get currency from app settings
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';

    debugPrint(
        "🎯 PRICE MODAL: Building price selection modal for: ${widget.productName}");
    debugPrint("🎯 PRICE MODAL: Available prices: ${widget.prices}");

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Price for',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.productName,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.16,
                ColorManager.kPrimaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Focus(
                focusNode: _priceGridFocusNode,
                autofocus: true,
                onKeyEvent: (node, event) =>
                    _handlePriceGridKey(context, currency, event),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: widget.prices.length,
                  itemBuilder: (context, index) {
                    final price = widget.prices[index];
                    final focusedIndex = widget.prices.isEmpty
                        ? null
                        : _focusedPriceIndex
                            .clamp(0, widget.prices.length - 1)
                            .toInt();
                    final isFocused =
                        _priceGridFocusNode.hasFocus && index == focusedIndex;
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _selectPrice(context, currency, price),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFocused
                                  ? ColorManager.kPrimaryColor
                                  : ColorManager.kPrimaryColor.withOpacity(0.3),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$currency ${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.16,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _cancel(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: ColorManager.kButtonRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.16,
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
