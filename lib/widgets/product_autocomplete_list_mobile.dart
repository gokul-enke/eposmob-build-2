import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/helpers/system_keyboard_policy.dart';
import 'package:provider/provider.dart';

class MobileProductAutocomplete extends StatefulWidget {
  final Size size;
  final Function(GetProduct, Stock?) onSelected;
  final List<GetProduct> productList;
  final GlobalKey? autocompleteProductKey;
  final bool autofocus;
  final bool suppressSystemKeyboardOnAndroid;

  const MobileProductAutocomplete({
    Key? key,
    required this.size,
    required this.onSelected,
    required this.productList,
    this.autocompleteProductKey,
    this.autofocus = false,
    this.suppressSystemKeyboardOnAndroid = false,
  }) : super(key: key);

  @override
  State<MobileProductAutocomplete> createState() => _MobileProductAutocompleteState();
}

class _MobileProductAutocompleteState extends State<MobileProductAutocomplete> {
  int? _highlightedOptionIndex;
  final FocusNode _textFieldFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 56.0; // Mobile-friendly touch targets
  final double _maxOptionsHeight = 300.0; // Reduced max height for mobile

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedItem() {
    if (_highlightedOptionIndex == null) return;

    // Calculate the offset to scroll to, with the item index
    final double scrollOffset = _highlightedOptionIndex! * _itemHeight;

    // Get the current scroll position and visible height
    final double currentScroll = _scrollController.offset;
    final double visibleHeight = _maxOptionsHeight;

    // Adding buffer space to ensure the item is fully visible
    const double bufferSpace = 4.0;

    // Check if item is already visible
    if (scrollOffset < currentScroll + bufferSpace) {
      // Item is above visible area or partially visible at the top - scroll up to it
      _scrollController.animateTo(
        scrollOffset > 0 ? scrollOffset - bufferSpace : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (scrollOffset + _itemHeight >
        currentScroll + visibleHeight - bufferSpace) {
      // Item is below visible area or partially visible at bottom - scroll down to it
      _scrollController.animateTo(
        scrollOffset - visibleHeight + _itemHeight + bufferSpace,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
    // If item is already fully visible, do nothing
  }

  List<GetProduct> _searchProducts(String query) {
    if (query.isEmpty) {
      return const <GetProduct>[];
    }

    final productProvider = Provider.of<LocalProductProvider>(context, listen: false);

    // Search through the complete products list, not the filtered one
    return productProvider.products
        .where((product) => (product.productName ?? '')
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    debugPrint("🎯 MOBILE AUTOCOMPLETE PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName}");
    debugPrint("  - Product Unit: ${product.unit}");
    debugPrint("  - Product ID: ${product.productId}");

    // Get customer info from global provider
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint(
        "  - Customer from provider: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint(
        "  - Customer ID from provider: ${customerSelectionProvider.selectedCustomerID}");

    await ProductCartHelper.handleProductSelection(
      context: context,
      product: product,
      onSelected: widget.onSelected,
      addToCartDirectly:
          true, // Add product directly to cart on selection
      // Customer info will be fetched from global provider in the helper
    );
  }

  @override
  Widget build(BuildContext context) {
    Iterable<GetProduct> currentOptions = const Iterable<GetProduct>.empty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Autocomplete<GetProduct>(
        key: widget.autocompleteProductKey,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            currentOptions = const Iterable<GetProduct>.empty();
            return currentOptions;
          }

          final searchResults = _searchProducts(textEditingValue.text);
          _highlightedOptionIndex = null;
          currentOptions = searchResults;
          return currentOptions;
        },
        displayStringForOption: (GetProduct product) => product.productName ?? '',
        onSelected: (GetProduct selectedProduct) async {
          await _handleProductSelection(selectedProduct);
          Provider.of<KeyboardProvider>(context, listen: false).hide();
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          final keyboardProvider = Provider.of<KeyboardProvider>(context, listen: false);
          final bool suppressSystemKeyboard =
              SystemKeyboardPolicy.shouldSuppressForContext(
            context: context,
            fieldWantsVirtualKeyboardOnly:
              widget.suppressSystemKeyboardOnAndroid,
            );
          
          void _ensureFocus() {
            if (!focusNode.hasFocus) {
              focusNode.requestFocus();
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textEditingController.selection = TextSelection.fromPosition(
                TextPosition(offset: textEditingController.text.length),
              );
            });
          }

          textEditingController.removeListener(_ensureFocus);
          textEditingController.addListener(_ensureFocus);
          
          return KeyboardListener(
            focusNode: _textFieldFocus,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    if (_highlightedOptionIndex == null) {
                      _highlightedOptionIndex = 0;
                    } else {
                      _highlightedOptionIndex = _highlightedOptionIndex! + 1;
                    }
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToHighlightedItem();
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    if (_highlightedOptionIndex == null) {
                      _highlightedOptionIndex = 0;
                    } else if (_highlightedOptionIndex! > 0) {
                      _highlightedOptionIndex = _highlightedOptionIndex! - 1;
                    }
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToHighlightedItem();
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  if (_highlightedOptionIndex != null &&
                      currentOptions.isNotEmpty &&
                      _highlightedOptionIndex! < currentOptions.length) {
                    final selectedProduct = currentOptions.elementAt(_highlightedOptionIndex!);
                    _handleProductSelection(selectedProduct);
                    textEditingController.clear();
                    focusNode.unfocus();
                    Provider.of<KeyboardProvider>(context, listen: false).hide();
                  }
                }
              }
            },
            child: buildColumnWidgetForTextFields(
              controller: textEditingController,
              focusNode: focusNode,
              autofocus: widget.autofocus,
              size: widget.size,
              width: double.infinity,
              hintText: 'Search Product',
              useSystemKeyboard: !suppressSystemKeyboard,
              onSubmitted: (_) => onFieldSubmitted(),
              onTap: () {
                // Show alphanumeric virtual keyboard connected to this controller
                keyboardProvider.show('text', textEditingController,
                    replaceOnFirstInput: true);
              },
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          currentOptions = options;

          if (_highlightedOptionIndex != null && _highlightedOptionIndex! >= options.length) {
            _highlightedOptionIndex = options.length - 1;
          }

return Align(
  alignment: Alignment.topLeft,
  child: BuildBoxShadowContainer(
    circleRadius: 7,
    constraints: BoxConstraints(
      maxHeight: _maxOptionsHeight,
      maxWidth: double.infinity,
    ),
    color: Colors.white,
    child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemExtent: _itemHeight,
      itemCount: options.length,
      itemBuilder: (BuildContext context, int index) {
        final option = options.elementAt(index);
        final bool isHighlighted = _highlightedOptionIndex == index;

        return MouseRegion(
          onEnter: (_) {
            setState(() {
              _highlightedOptionIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8, // Slightly more padding for mobile
              ),
              title: Text(
                option.productName ?? '',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 14, // Slightly larger for mobile
                  color: isHighlighted
                      ? Colors.blue.shade800
                      : Colors.black87,
                  fontWeight: isHighlighted
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${option.price?.price ?? ''} ${option.currency ?? ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? Colors.blue.shade900
                      : Colors.black87,
                ),
              ),
              onTap: () => onSelected(option),
            ),
          ),
        );
      },
    ),
  ),
);




          
        },
      ),
    );
  }


}

