import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class BuildMultiSelectDropDownWithSearch<T> extends StatefulWidget {
  final String? title;
  final String hintText;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) displayText;
  final Function(List<T>) onChanged;
  final bool isRequired;
  final double? height;
  final String? searchHintText;
  final bool showName;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final double? width;
  final bool autofocus;

  const BuildMultiSelectDropDownWithSearch({
    Key? key,
    this.title,
    required this.hintText,
    required this.items,
    required this.selectedItems,
    required this.displayText,
    required this.onChanged,
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
  State<BuildMultiSelectDropDownWithSearch<T>> createState() =>
      _BuildMultiSelectDropDownWithSearchState<T>();
}

class _BuildMultiSelectDropDownWithSearchState<T>
    extends State<BuildMultiSelectDropDownWithSearch<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late FocusNode _keyboardFocusNode;
  late LayerLink _layerLink;
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;
  List<T> _filteredItems = [];
  int? _selectedIndex;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // Define item height for scrolling calculations
  final double _itemHeight = 52.0;
  final double _maxDropdownHeight = 250.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _keyboardFocusNode = FocusNode();
    _layerLink = LayerLink();
    _filteredItems = widget.items;

    // Add listeners
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(BuildMultiSelectDropDownWithSearch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update filtered items if items list changes
    if (widget.items != oldWidget.items) {
      _filteredItems = widget.items;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _filterItems(_controller.text);
    if (_isDropdownOpen) {
      _updateOverlay();
    }
  }

  void _onFocusChanged() {
    if (!mounted) return;
    
    if (_focusNode.hasFocus && !_isDropdownOpen) {
      _showDropdown();
    }
    // Don't auto-close on focus loss for multi-select - let user click close button
    // This prevents the dropdown from closing when focus moves to search field
  }

  void _filterItems(String query) {
    setState(() {
      _isLoading = true;
    });

    // Simulate async filtering with debounce
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      List<T> filtered;
      if (query.isEmpty) {
        filtered = widget.items;
      } else {
        filtered = widget.items.where((item) {
          return widget
              .displayText(item)
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }

      setState(() {
        _filteredItems = filtered;
        _selectedIndex = null;
        _isLoading = false;
      });

      if (_isDropdownOpen) {
        _updateOverlay();
      }
    });
  }

  void _showDropdown() {
    if (!mounted || _isDropdownOpen) return;

    setState(() {
      _isDropdownOpen = true;
    });

    _filterItems(_controller.text);
    _createOverlay();
    
    // Request focus on keyboard node for navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  void _hideDropdown() {
    if (!mounted || !_isDropdownOpen) return;

    setState(() {
      _isDropdownOpen = false;
      _selectedIndex = null;
    });

    _removeOverlay();
    _keyboardFocusNode.unfocus();
  }

  void _createOverlay() {
    if (!mounted) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background barrier - only closes dropdown when tapped directly
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  debugPrint('🔻 Background tapped - closing multiselect dropdown');
                  _hideDropdown();
                },
              ),
            ),
          ),
          // The actual dropdown
          _MultiSelectDropdownOverlay<T>(
            key: ValueKey('overlay_${widget.selectedItems.length}_${widget.selectedItems.hashCode}'),
            layerLink: _layerLink,
            items: _filteredItems,
            selectedItems: widget.selectedItems,
            displayText: widget.displayText,
            onItemToggled: _onItemToggled,
            onClearAll: _clearAllSelections,
            selectedIndex: _selectedIndex,
            onIndexChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            isLoading: _isLoading,
            width: _getDropdownWidth(),
            scrollController: _scrollController,
            itemHeight: _itemHeight,
            maxHeight: _maxDropdownHeight,
            searchController: _controller,
            searchHintText: widget.searchHintText ?? "Search...",
            onClose: _hideDropdown,
          ),
        ],
      ),
    );

    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _updateOverlay() {
    if (!mounted) return;
    
    _removeOverlay();
    if (mounted) {
      _createOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onItemToggled(T item) {
    if (!mounted) return;
    
    final updated = List<T>.from(widget.selectedItems);
    if (updated.contains(item)) {
      updated.remove(item);
    } else {
      updated.add(item);
    }
    widget.onChanged(updated);
    
    // Update the overlay to reflect the new selection state
    if (_isDropdownOpen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isDropdownOpen) {
          _updateOverlay();
        }
      });
    }
  }

  void _clearAllSelections() {
    if (!mounted) return;
    
    debugPrint('🔄 Clearing all selections: ${widget.selectedItems.length} items');
    if (widget.selectedItems.isNotEmpty) {
      widget.onChanged([]);
      
      // Update the overlay to reflect the cleared state
      if (_isDropdownOpen && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isDropdownOpen) {
            _updateOverlay();
          }
        });
      }
    }
  }

  double _getDropdownWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 200;
    debugPrint('🔧 Dropdown width calculated: $width');
    return width;
  }

  void _scrollToSelectedItem() {
    if (_selectedIndex == null || !_scrollController.hasClients) return;

    final double scrollOffset = _selectedIndex! * _itemHeight;
    final double currentScroll = _scrollController.offset;
    final double visibleHeight = _maxDropdownHeight;
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

  void _handleKeyPress(RawKeyEvent event) {
    if (!_isDropdownOpen || _filteredItems.isEmpty) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateDown();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateUp();
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < _filteredItems.length) {
          _onItemToggled(_filteredItems[_selectedIndex!]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideDropdown();
        _focusNode.unfocus();
      }
    }
  }

  void _navigateDown() {
    setState(() {
      if (_selectedIndex == null) {
        _selectedIndex = 0;
      } else if (_selectedIndex! < _filteredItems.length - 1) {
        _selectedIndex = _selectedIndex! + 1;
      } else {
        _selectedIndex = 0; // Loop to top
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItem();
    });
    _updateOverlay();
  }

  void _navigateUp() {
    setState(() {
      if (_selectedIndex == null) {
        _selectedIndex = _filteredItems.length - 1;
      } else if (_selectedIndex! > 0) {
        _selectedIndex = _selectedIndex! - 1;
      } else {
        _selectedIndex = _filteredItems.length - 1; // Loop to bottom
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItem();
    });
    _updateOverlay();
  }

  void _removeSelectedItem(T item) {
    final updated = List<T>.from(widget.selectedItems);
    updated.remove(item);
    widget.onChanged(updated);
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
          margin: widget.margin ??
              const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
          width: widget.width,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: RawKeyboardListener(
              focusNode: _keyboardFocusNode,
              onKey: _handleKeyPress,
              child: GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                  if (!_isDropdownOpen) {
                    _showDropdown();
                  }
                },
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  height:
                      widget.height ?? MediaQuery.of(context).size.height * .07,
                  padding:
                      widget.contentPadding ?? const EdgeInsets.only(left: 15),
                  margin: EdgeInsets.zero,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    onTap: () {
                      if (!_isDropdownOpen) {
                        _showDropdown();
                      }
                    },
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.selectedItems.isEmpty
                          ? widget.hintText
                          : "${widget.selectedItems.length} items selected",
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
                          // Clear all button - only show when there are selections
                          if (widget.selectedItems.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                widget.onChanged([]);
                                _controller.clear();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: ColorManager.textColor.withOpacity(.6),
                                ),
                              ),
                            ),
                          // Dropdown arrow
                          Icon(
                            _isDropdownOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Selected items chips display
        if (widget.selectedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            margin: widget.margin ??
                const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selectedItems.map((item) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: IntrinsicWidth(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                          child: Text(
                            widget.displayText(item),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeSelectedItem(item),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MultiSelectDropdownOverlay<T> extends StatefulWidget {
  final LayerLink layerLink;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) displayText;
  final Function(T) onItemToggled;
  final VoidCallback onClearAll;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;
  final bool isLoading;
  final double width;
  final ScrollController scrollController;
  final double itemHeight;
  final double maxHeight;
  final TextEditingController searchController;
  final String searchHintText;
  final VoidCallback onClose;

  const _MultiSelectDropdownOverlay({
    Key? key,
    required this.layerLink,
    required this.items,
    required this.selectedItems,
    required this.displayText,
    required this.onItemToggled,
    required this.onClearAll,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.isLoading,
    required this.width,
    required this.scrollController,
    required this.itemHeight,
    required this.maxHeight,
    required this.searchController,
    required this.searchHintText,
    required this.onClose,
  }) : super(key: key);

  @override
  State<_MultiSelectDropdownOverlay<T>> createState() =>
      _MultiSelectDropdownOverlayState<T>();
}

class _MultiSelectDropdownOverlayState<T>
    extends State<_MultiSelectDropdownOverlay<T>> {
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();

    // Auto-focus search field when overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_MultiSelectDropdownOverlay<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild when selected items change
    if (widget.selectedItems != oldWidget.selectedItems) {
      debugPrint('🔄 Overlay selectedItems changed: ${widget.selectedItems.length} items');
      // The widget will rebuild automatically due to the state change
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Positioned(
      width: widget.width,
      child: CompositedTransformFollower(
        link: widget.layerLink,
        showWhenUnlinked: false,
        offset: const Offset(1, 1),
        child: Material(
          type: MaterialType.card,
          elevation: 0,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              boxShadow: [
                const BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search header
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: TextField(
                            controller: widget.searchController,
                            focusNode: _searchFocusNode,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.27,
                              ColorManager.textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.searchHintText,
                              hintStyle: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s11,
                                0.27,
                                ColorManager.textColor.withOpacity(.5),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon:
                                  widget.searchController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            widget.searchController.clear();
                                            _searchFocusNode.requestFocus();
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Items list
                Flexible(
                  child: _buildContent(),
                ),
                // Footer with selection count
                if (widget.selectedItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.blue.withOpacity(0.2)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.selectedItems.length} item${widget.selectedItems.length != 1 ? 's' : ''} selected",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            debugPrint('🔄 Clear all button tapped');
                            widget.onClearAll();
                          },
                          child: Text(
                            "Clear all",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
    }

    if (widget.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No items found',
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
    }

    // Ensure selected index is within bounds
    if (widget.selectedIndex != null &&
        widget.selectedIndex! >= widget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onIndexChanged(widget.items.length - 1);
      });
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemExtent: widget.itemHeight,
      itemCount: widget.items.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = widget.selectedItems.contains(item);
        final isHighlighted = widget.selectedIndex == index;

        return _MultiSelectDropdownItem<T>(
          item: item,
          displayText: widget.displayText,
          isSelected: isSelected,
          isHighlighted: isHighlighted,
          onTap: () => widget.onItemToggled(item),
          onHover: (isHovered) {
            if (isHovered) {
              widget.onIndexChanged(index);
            }
          },
        );
      },
    );
  }
}

class _MultiSelectDropdownItem<T> extends StatefulWidget {
  final T item;
  final String Function(T) displayText;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  final Function(bool) onHover;

  const _MultiSelectDropdownItem({
    Key? key,
    required this.item,
    required this.displayText,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
    required this.onHover,
  }) : super(key: key);

  @override
  State<_MultiSelectDropdownItem<T>> createState() =>
      _MultiSelectDropdownItemState<T>();
}

class _MultiSelectDropdownItemState<T>
    extends State<_MultiSelectDropdownItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isHighlighted;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        widget.onHover(false);
      },
      child: GestureDetector(
        onTap: () {
          debugPrint('✅ Multiselect item tapped: ${widget.displayText(widget.item)}');
          widget.onTap();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.blue.shade50
                : widget.isSelected
                    ? Colors.green.shade50
                    : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: widget.isSelected
                ? Border.all(color: Colors.green.shade200)
                : isHighlighted
                    ? Border.all(color: Colors.blue.shade200)
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Colors.green.shade600
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: widget.isSelected
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                // Text
                Expanded(
                  child: Text(
                    widget.displayText(widget.item),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isSelected
                          ? Colors.green.shade800
                          : isHighlighted
                              ? Colors.blue.shade800
                              : Colors.black87,
                      fontWeight: widget.isSelected || isHighlighted
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
