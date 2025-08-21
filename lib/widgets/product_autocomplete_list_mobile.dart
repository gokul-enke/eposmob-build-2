import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:provider/provider.dart';

class MobileProductAutocomplete extends StatefulWidget {
  final Size size;
  final Function(GetProduct, Stock?) onSelected;
  final List<GetProduct> productList;
  final GlobalKey? autocompleteProductKey;
  final bool autofocus;

  const MobileProductAutocomplete({
    Key? key,
    required this.size,
    required this.onSelected,
    required this.productList,
    this.autocompleteProductKey,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<MobileProductAutocomplete> createState() => _MobileProductAutocompleteState();
}

class _MobileProductAutocompleteState extends State<MobileProductAutocomplete> {
  int? _highlightedOptionIndex;
  final FocusNode _textFieldFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 56.0; // Slightly larger for mobile touch targets
  final double _maxOptionsHeight = 300.0; // Reduced max height for mobile

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedItem() {
    if (_highlightedOptionIndex == null) return;

    final double scrollOffset = _highlightedOptionIndex! * _itemHeight;
    final double currentScroll = _scrollController.offset;
    final double visibleHeight = _maxOptionsHeight;

    const double bufferSpace = 8.0;

    if (scrollOffset < currentScroll + bufferSpace) {
      _scrollController.animateTo(
        scrollOffset > 0 ? scrollOffset - bufferSpace : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (scrollOffset + _itemHeight > currentScroll + visibleHeight - bufferSpace) {
      _scrollController.animateTo(
        scrollOffset - visibleHeight + _itemHeight + bufferSpace,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  List<GetProduct> _searchProducts(String query) {
    if (query.isEmpty) {
      return const <GetProduct>[];
    }

    final productProvider = Provider.of<LocalProductProvider>(context, listen: false);
    return productProvider.products
        .where((product) => (product.productName ?? '')
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    debugPrint("🎯 MOBILE AUTOCOMPLETE PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName}");

    final customerSelectionProvider = Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint("  - Customer: ${customerSelectionProvider.selectedCustomerName}");

    await ProductCartHelper.handleProductSelection(
      context: context,
      product: product,
      onSelected: widget.onSelected,
      addToCartDirectly: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    Iterable<GetProduct> currentOptions = const Iterable<GetProduct>.empty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                      _highlightedOptionIndex = (_highlightedOptionIndex! + 1) % currentOptions.length;
                    }
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToHighlightedItem();
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    if (_highlightedOptionIndex == null) {
                      _highlightedOptionIndex = currentOptions.length - 1;
                    } else {
                      _highlightedOptionIndex = (_highlightedOptionIndex! - 1) % currentOptions.length;
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
            child: _buildMobileTextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (_) => onFieldSubmitted(),
              onTap: () {
                keyboardProvider.show('text', textEditingController, replaceOnFirstInput: true);
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
  child: Material(
    elevation: 4.0,
    borderRadius: BorderRadius.circular(8), // ✅ match Barcode field
    child: Container(
      width: double.infinity, // ✅ same as Expanded TextField
      constraints: BoxConstraints(
        maxHeight: _maxOptionsHeight,
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // ✅ exactly like TextField
          borderSide: BorderSide(
            color: Colors.grey.shade400,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemExtent: _itemHeight,
        itemCount: options.length,
        itemBuilder: (BuildContext context, int index) {
          final option = options.elementAt(index);
          final bool isHighlighted = _highlightedOptionIndex == index;

          return InkWell(
            onTap: () => onSelected(option),
            child: Container(
              color: isHighlighted ? Colors.blue.shade50 : Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 14.0, // ✅ match Barcode TextField padding
              ),
              child: Text(
                option.productName ?? '',
                style: TextStyle(
                  fontSize: 16.0,
                  color: isHighlighted
                      ? Colors.blue.shade800
                      : Colors.black87,
                  fontWeight: isHighlighted
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    ),
  ),
);




          
        },
      ),
    );
  }

  Widget _buildMobileTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onSubmitted,
    required VoidCallback onTap,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        hintText: 'Search Product',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {},
        ),
      ),
      style: const TextStyle(fontSize: 16.0),
      onSubmitted: onSubmitted,
      onTap: onTap,
    );
  }
}

