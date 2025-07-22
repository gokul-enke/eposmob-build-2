import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

class CustomerAutocomplete extends StatefulWidget {
  final Size size;
  final Function(String) onSelected;
  final List<String> customerList;
  final bool autofocus;

  const CustomerAutocomplete({
    Key? key,
    required this.size,
    required this.onSelected,
    required this.customerList,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<CustomerAutocomplete> createState() => _CustomerAutocompleteState();
}

class _CustomerAutocompleteState extends State<CustomerAutocomplete> {
  int? _highlightedOptionIndex;
  final FocusNode _textFieldFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 48.0;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedItem() {
    if (_highlightedOptionIndex == null) return;

    final double scrollOffset = _highlightedOptionIndex! * _itemHeight;
    final double currentScroll = _scrollController.offset;
    const double visibleHeight = 180.0;
    const double bufferSpace = 4.0;

    if (scrollOffset < currentScroll + bufferSpace) {
      _scrollController.animateTo(
        scrollOffset > 0 ? scrollOffset - bufferSpace : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (scrollOffset + _itemHeight >
        currentScroll + visibleHeight - bufferSpace) {
      _scrollController.animateTo(
        scrollOffset - visibleHeight + _itemHeight + bufferSpace,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  List<String> _searchCustomers(String query) {
    if (query.isEmpty) {
      return const <String>[];
    }

    return widget.customerList
        .where((customer) => customer.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    Iterable<String> currentOptions = const Iterable<String>.empty();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            currentOptions = const Iterable<String>.empty();
            return currentOptions;
          }

          final searchResults = _searchCustomers(textEditingValue.text);
          _highlightedOptionIndex = null;
          currentOptions = searchResults;
          return currentOptions;
        },
        onSelected: (String selectedCustomer) {
          widget.onSelected(selectedCustomer);
          _textEditingController.text = selectedCustomer;
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
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
                    final selectedCustomer =
                        currentOptions.elementAt(_highlightedOptionIndex!);
                    widget.onSelected(selectedCustomer);
                    textEditingController.text = selectedCustomer;
                    focusNode.unfocus();
                  }
                }
              }
            },
            child: buildColumnWidgetForTextFields(
              controller: textEditingController,
              focusNode: focusNode,
              autofocus: widget.autofocus,
              size: widget.size,
              hintText: 'Search Customer',
              onSubmitted: (_) => onFieldSubmitted(),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          currentOptions = options;

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
                          option,
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
                        onTap: () {
                          onSelected(option);
                          _textEditingController.text = option;
                        },
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