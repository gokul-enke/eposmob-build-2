import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/helpers/system_keyboard_policy.dart';
import 'package:provider/provider.dart';

class ProductAutocomplete extends StatefulWidget {
  final Size size;
  final Function(GetProduct, Stock?) onSelected;
  final List<GetProduct> productList;
  final GlobalKey? autocompleteProductKey;
  final bool autofocus;
  final bool suppressSystemKeyboardOnAndroid;

  const ProductAutocomplete({
    super.key,
    required this.size,
    required this.onSelected,
    required this.productList,
    this.autocompleteProductKey,
    this.autofocus = false,
    this.suppressSystemKeyboardOnAndroid = false,
  });

  @override
  State<ProductAutocomplete> createState() => _ProductAutocompleteState();
}

class _ProductAutocompleteState extends State<ProductAutocomplete> {
  // Track the highlighted index
  int? _highlightedOptionIndex;
  final FocusNode _textFieldFocus = FocusNode();
  // Add scroll controller for automatic scrolling
  final ScrollController _scrollController = ScrollController();
  // Define item height for scrolling calculations - adjusted to include margins
  final double _itemHeight =
      48.0; // Increased to account for margins and padding

  // Tracks previous controller text to differentiate text changes from selection changes
  String _previousControllerText = '';

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function to scroll to the selected item
  void _scrollToHighlightedItem() {
    if (_highlightedOptionIndex == null) return;

    // Calculate the offset to scroll to, with the item index
    final double scrollOffset = _highlightedOptionIndex! * _itemHeight;

    // Get the current scroll position and visible height
    final double currentScroll = _scrollController.offset;
    const double visibleHeight = 180.0; // maxHeight in constraints

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

  // Independent search method that doesn't affect the provider's filteredProducts
  // Only searches sellable products for billing screens
  List<GetProduct> _searchProducts(String query) {
    if (query.isEmpty) {
      return const <GetProduct>[];
    }

    final productProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final itemCodeEnabled =
        appSettingsProvider.appSettings?.itemCodeEnabled ?? false;
    final lowerQuery = query.toLowerCase();

    // Search through only sellable products for billing autocomplete
    return productProvider.sellableProducts.where((product) {
      final nameMatch =
          (product.productName ?? '').toLowerCase().contains(lowerQuery);
      if (nameMatch) return true;
      if (itemCodeEnabled) {
        final itemCode = product.itemCode ?? '';
        if (itemCode.isNotEmpty && itemCode.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    debugPrint("🎯 AUTOCOMPLETE PRODUCT SELECTION:");
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
      addToCartDirectly: true, // Add product directly to cart on selection
      // Customer info will be fetched from global provider in the helper
    );
  }

  @override
  Widget build(BuildContext context) {
    // Store current options for Enter key selection
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

          // Use our independent search method instead of calling listAllProducts
          final searchResults = _searchProducts(textEditingValue.text);

          // Reset highlighted index when options change
          _highlightedOptionIndex = null;
          currentOptions = searchResults;
          return currentOptions;
        },
        displayStringForOption: (GetProduct product) =>
            product.productName ?? '',
        onSelected: (GetProduct selectedProduct) async {
          await _handleProductSelection(selectedProduct);
          // Hide virtual keyboard after product selection
          Provider.of<KeyboardProvider>(context, listen: false).hide();
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          final keyboardProvider =
              Provider.of<KeyboardProvider>(context, listen: false);
          final bool suppressSystemKeyboard =
              SystemKeyboardPolicy.shouldSuppressForContext(
            context: context,
            fieldWantsVirtualKeyboardOnly:
              widget.suppressSystemKeyboardOnAndroid,
            );
          // Make sure the autocomplete keeps focus while typing via virtual keyboard
          void _ensureFocus() {
            if (!focusNode.hasFocus) {
              focusNode.requestFocus();
            }

            final currentText = textEditingController.text;
            final previousText = _previousControllerText;
            _previousControllerText = currentText;

            // Only snap cursor to end when text was actually appended (virtual
            // keyboard typing). This preserves Ctrl+A, arrow keys, cursor
            // placement, and other selection operations.
            if (currentText.length > previousText.length &&
                currentText.startsWith(previousText)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (textEditingController.text == currentText) {
                  textEditingController.selection = TextSelection.fromPosition(
                    TextPosition(offset: textEditingController.text.length),
                  );
                }
              });
            }
          }

          // Attach the listener once; remove any existing to avoid duplicates
          _previousControllerText = textEditingController.text;
          textEditingController.removeListener(_ensureFocus);
          textEditingController.addListener(_ensureFocus);
          // Replace the provided focusNode with our own
          return KeyboardListener(
            focusNode: _textFieldFocus,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.keyA &&
                    HardwareKeyboard.instance.isControlPressed) {
                  // Ctrl+A: select all text in the field
                  textEditingController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: textEditingController.text.length,
                  );
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    if (_highlightedOptionIndex == null) {
                      _highlightedOptionIndex = 0;
                    } else {
                      _highlightedOptionIndex = _highlightedOptionIndex! + 1;
                    }
                  });
                  // Scroll to show the highlighted item
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
                  // Scroll to show the highlighted item
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToHighlightedItem();
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  // Handle Enter key to select highlighted item
                  if (_highlightedOptionIndex != null &&
                      currentOptions.isNotEmpty &&
                      _highlightedOptionIndex! < currentOptions.length) {
                    // Get the selected product
                    final selectedProduct =
                        currentOptions.elementAt(_highlightedOptionIndex!);
                    // Handle product selection with stock logic
                    _handleProductSelection(selectedProduct);
                    // Clear the text field
                    textEditingController.clear();
                    // Clear the focus
                    focusNode.unfocus();

                    // Hide virtual keyboard after selection via keyboard
                    Provider.of<KeyboardProvider>(context, listen: false)
                        .hide();
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
              hintText: 'common.search_product'.tr,
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
          // Get currency from app settings
          final appSettingsProvider =
              Provider.of<AppSettingsProvider>(context, listen: false);
          final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
          final itemCodeEnabled =
              appSettingsProvider.appSettings?.itemCodeEnabled ?? false;

          // Update current options reference for Enter key handling
          currentOptions = options;

          // Ensure highlighted index is within bounds
          if (_highlightedOptionIndex != null &&
              _highlightedOptionIndex! >= options.length) {
            _highlightedOptionIndex = options.length - 1;
          }

          return Align(
            alignment: Alignment.topLeft,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              constraints: BoxConstraints(
                maxHeight: 300,
                maxWidth: widget.size.width / 4,
              ),
              color: Colors.white,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemExtent:
                    _itemHeight, // Set fixed item height for predictable scrolling
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
                        color:
                            isHighlighted ? Colors.blue.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(
                          option.productName ?? '',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 11,
                            color: isHighlighted
                                ? Colors.blue.shade800
                                : Colors.black87,
                            fontWeight: isHighlighted
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (itemCodeEnabled &&
                                (option.itemCode ?? '').isNotEmpty)
                            ? Text(
                                option.itemCode!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isHighlighted
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          '$currency ${option.price?.price ?? ''}',
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
