import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class BuildDropDownWithSearch<T> extends StatefulWidget {
  final String? title;
  final String hintText;
  final T? value;
  final List<T> items;
  final Function(T?) onChanged;
  final String Function(T) displayText;
  final TextEditingController? searchController; // Made optional for compatibility
  final bool isRequired;
  final double? height;
  final String? searchHintText;
  final bool showName;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final double? width;
  final bool autofocus;

  const BuildDropDownWithSearch({
    Key? key,
    this.title,
    required this.hintText,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.displayText,
    this.searchController, // Made optional
    this.isRequired = false,
    this.height,
    this.searchHintText,
    this.showName = true,
    this.margin,
    this.contentPadding,
    this.width,
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<BuildDropDownWithSearch<T>> createState() => _BuildDropDownWithSearchState<T>();
}

class _BuildDropDownWithSearchState<T> extends State<BuildDropDownWithSearch<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _userHasTyped = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.searchController ?? TextEditingController();
    _focusNode = FocusNode();
    
    // Set initial text if value is provided
    if (widget.value != null) {
      _controller.text = widget.displayText(widget.value!);
    }
    
    // Add listener to track when user types
    _controller.addListener(() {
      if (!_userHasTyped && _controller.text.isNotEmpty) {
        setState(() {
          _userHasTyped = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(BuildDropDownWithSearch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text when value changes externally
    if (widget.value != oldWidget.value) {
      if (widget.value != null) {
        _controller.text = widget.displayText(widget.value!);
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    // Only dispose if we created the controller
    if (widget.searchController == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  List<T> _getSuggestions(String search) {
    if (search.isEmpty) {
      return widget.items;
    }
    
    return widget.items.where((item) {
      return widget.displayText(item)
          .toLowerCase()
          .contains(search.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showName && widget.title != null) ...[
          BuildTextTile(
            title: widget.title!,
            isStarRed: widget.isRequired,
            isTextField: true,
            textStyle: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
          if (!widget.isRequired) const SizedBox(height: 8),
        ],
        
        Container(
          margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          width: widget.width,
          child: TypeAheadField<T>(
            controller: _controller,
            focusNode: _focusNode,
            
            // Auto focus settings
            builder: (context, controller, focusNode) {
              return GestureDetector(
                onTap: () {
                  // When clicked, focus the field for searching and prepare for typing
                  focusNode.requestFocus();
                  setState(() {
                    _userHasTyped = true; // Allow suggestions when clicked
                  });
                },
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  height: widget.height ?? MediaQuery.of(context).size.height * .07,
                  padding: widget.contentPadding ?? const EdgeInsets.only(left: 15),
                  margin: EdgeInsets.zero,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: widget.autofocus,
                    onTap: () {
                      // When text field is tapped, select all text for easy replacement
                      setState(() {
                        _userHasTyped = true; // Allow suggestions when text field clicked
                      });
                      if (controller.text.isNotEmpty) {
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: controller.text.length,
                        );
                      }
                    },
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Close icon - only show when there's a selection
                          if (widget.value != null && controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                controller.clear();
                                widget.onChanged(null);
                                setState(() {
                                  _userHasTyped = true; // Keep this true to show suggestions
                                });
                                // Focus the field to show dropdown with all items
                                focusNode.requestFocus();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: ColorManager.textColor.withOpacity(.6),
                                ),
                              ),
                            ),
                          // Dropdown arrow
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            
            // Suggestions callback
            suggestionsCallback: (search) async {
              // Add a small delay to debounce
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Only show suggestions after user starts typing
              if (!_userHasTyped && search.isEmpty) {
                return <T>[]; // Return empty list when not typing yet
              }
              
              return _getSuggestions(search);
            },
            
            // Item builder with hover and keyboard navigation effects
            itemBuilder: (context, item) {
              // Check if this is the first item in the current suggestions
              final suggestions = _getSuggestions(_controller.text);
              final isFirst = suggestions.isNotEmpty && suggestions.first == item;
              
              return _KeyboardNavigationItem<T>(
                item: item,
                displayText: widget.displayText,
                isFirst: isFirst,
              );
            },
            
            // On selection
            onSelected: (item) {
              _controller.text = widget.displayText(item);
              widget.onChanged(item);
              setState(() {
                _userHasTyped = false; // Reset typing flag after selection
              });
            },
            
            // Decoration
            decorationBuilder: (context, child) {
              return Material(
                type: MaterialType.card,
                elevation: 0,
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 6,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            
            // Empty builder
            emptyBuilder: (context) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'No items found',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    Colors.grey.shade600,
                  ),
                ),
              );
            },
            
            // Loading builder
            loadingBuilder: (context) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading...',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
            
            // Error builder
            errorBuilder: (context, error) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Error loading items',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    Colors.red.shade600,
                  ),
                ),
              );
            },
            
            // Configuration
            hideOnEmpty: false,
            hideOnError: false,
            hideOnLoading: false,
            hideOnSelect: true,
            hideOnUnfocus: true,
            debounceDuration: const Duration(milliseconds: 200), // Faster response
            animationDuration: const Duration(milliseconds: 150), // Snappier animation
            retainOnLoading: true,
            
            // List configuration
            listBuilder: (context, children) {
              return ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: children,
              );
            },
            
            // Offset to position dropdown correctly
            offset: const Offset(1, 1),
            
            // Constraints
            constraints: const BoxConstraints(
              maxHeight: 200,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom item widget that responds to both mouse hover and keyboard focus
class _KeyboardNavigationItem<T> extends StatefulWidget {
  final T item;
  final String Function(T) displayText;
  final bool isFirst;

  const _KeyboardNavigationItem({
    Key? key,
    required this.item,
    required this.displayText,
    this.isFirst = false,
  }) : super(key: key);

  @override
  State<_KeyboardNavigationItem<T>> createState() => _KeyboardNavigationItemState<T>();
}

class _KeyboardNavigationItemState<T> extends State<_KeyboardNavigationItem<T>> {
  bool _isHovered = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    
    // Don't auto-focus the first item anymore - let user search first
    // The keyboard navigation will work when user presses arrow keys
  }

  void _onFocusChanged() {
    // Rebuild the widget when focus changes to update highlighting
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || _focusNode.hasFocus;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Focus(
        focusNode: _focusNode,
        child: MouseRegion(
          onEnter: (_) {
            if (mounted) {
              setState(() {
                _isHovered = true;
              });
            }
          },
          onExit: (_) {
            if (mounted) {
              setState(() {
                _isHovered = false;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.blue.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: _focusNode.hasFocus 
                ? Border.all(color: Colors.blue.shade300, width: 1)
                : null,
            ),
            child: Text(
              widget.displayText(widget.item),
              style: buildCustomStyle(
                isHighlighted ? FontWeightManager.semiBold : FontWeightManager.medium,
                FontSize.s12,
                0.27,
                isHighlighted ? Colors.blue.shade800 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
