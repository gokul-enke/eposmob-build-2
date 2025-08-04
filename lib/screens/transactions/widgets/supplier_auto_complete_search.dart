import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierAutocomplete extends StatefulWidget {
  final Size size;
  final Function(String) onSelected;
  final List<String> supplierList;
  final TextEditingController controller;
  final bool autofocus;

  const SupplierAutocomplete({
    Key? key,
    required this.size,
    required this.onSelected,
    required this.supplierList,
    required this.controller,
    this.autofocus = false,
  }) : super(key: key);

  void reset() {
    final state = _SupplierAutocompleteState();
    state.resetField();
  }

  @override
  State<SupplierAutocomplete> createState() => _SupplierAutocompleteState();
}

class _SupplierAutocompleteState extends State<SupplierAutocomplete> {
  int? _highlightedOptionIndex;
  final FocusNode _textFieldFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 48.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.text.isEmpty) {
      widget.onSelected('');
    }
  }
  void _resetAllState() {
  if (mounted) {
    setState(() {
      _highlightedOptionIndex = null;
      _scrollController.jumpTo(0);
    });
  }
  widget.controller.clear();
  widget.onSelected('');
}
  
   void resetField() {
  _resetAllState();
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

  List<String> _searchSuppliers(String query) {
    if (query.isEmpty) {
      return const <String>[];
    }

    return widget.supplierList
        .where((supplier) => supplier.toLowerCase().contains(query.toLowerCase()))
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

          final searchResults = _searchSuppliers(textEditingValue.text);
          _highlightedOptionIndex = null;
          currentOptions = searchResults;
          return currentOptions;
        },
        onSelected: (String selectedSupplier) {
          widget.controller.text = selectedSupplier;
          widget.onSelected(selectedSupplier);
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

          // Sync the internal controller with external controller
          if (textEditingController.text != widget.controller.text) {
            textEditingController.text = widget.controller.text;
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
                    final selectedSupplier =
                        currentOptions.elementAt(_highlightedOptionIndex!);
                    widget.onSelected(selectedSupplier);
                    widget.controller.text = selectedSupplier;
                    focusNode.unfocus();
                  }
                }
              }
            },
            child: TextField(
              controller: widget.controller,
              focusNode: focusNode,
              autofocus: widget.autofocus,
              decoration: InputDecoration(
                hintText: 'Search supplier',
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
              onChanged: (value) => widget.onSelected(value),
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
                          widget.controller.text = option;
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