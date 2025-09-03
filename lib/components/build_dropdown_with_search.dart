import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController? searchController;
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
    this.searchController,
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
  State<BuildDropDownWithSearch<T>> createState() =>
      _BuildDropDownWithSearchState<T>();
}

class _BuildDropDownWithSearchState<T>
    extends State<BuildDropDownWithSearch<T>> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late LayerLink _layerLink;
  OverlayEntry? _overlayEntry;
  bool _userHasTyped = false;
  bool _isDropdownOpen = false;
  List<T> _filteredItems = [];
  int? _selectedIndex;
  int? _keyboardSelectedIndex;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dropdownKey = GlobalKey();

  final double _itemHeight = 48.0;
  final double _maxDropdownHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _controller = widget.searchController ?? TextEditingController();
    _focusNode = FocusNode();
    _layerLink = LayerLink();
    _filteredItems = widget.items;

    if (widget.value != null) {
      _controller.text = widget.displayText(widget.value!);
    }

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(BuildDropDownWithSearch<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value != null) {
        _controller.text = widget.displayText(widget.value!);
      } else {
        _controller.clear();
      }
    }

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

    if (widget.searchController == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_userHasTyped && _controller.text.isNotEmpty) {
      setState(() {
        _userHasTyped = true;
      });
    }

    _filterItems(_controller.text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_isDropdownOpen) {
      _selectedIndex = null;
      _showDropdown();
    } else if (!_focusNode.hasFocus && _isDropdownOpen) {
      // Add a small delay to allow for item selection before closing
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_focusNode.hasFocus && _isDropdownOpen) {
          _hideDropdown();
        }
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      List<T> filtered;
      if (query.isEmpty || !_userHasTyped) {
        filtered = _userHasTyped ? widget.items : [];
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
        _keyboardSelectedIndex = null;
        _isLoading = false;
      });

      if (_isDropdownOpen) {
        _updateOverlay();
      }
    });
  }

  void _showDropdown() {
    if (_isDropdownOpen) return;

    setState(() {
      _isDropdownOpen = true;
      _userHasTyped = true;
    });

    _filterItems(_controller.text);
    _createOverlay();
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;

    setState(() {
      _isDropdownOpen = false;
      _userHasTyped = false;
      _selectedIndex = null;
      _keyboardSelectedIndex = null;
    });

    _removeOverlay();
  }

  void _createOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Background barrier - only closes dropdown when tapped directly
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    debugPrint('🔻 Background tapped - closing dropdown');
                    _hideDropdown();
                    _focusNode.unfocus();
                  },
                ),
              ),
            ),
            // Dropdown content
            Positioned(
              width: _getDropdownWidth(),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(1, 1),
                child: Material(
                  key: _dropdownKey,
                  type: MaterialType.card,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    constraints: BoxConstraints(maxHeight: _maxDropdownHeight),
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
                    child: _buildDropdownContent(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _createOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdownContent() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
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
    }

    if (_filteredItems.isEmpty) {
      return Container(
        width: double.infinity,
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
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemExtent: _itemHeight,
      itemCount: _filteredItems.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isKeyboardSelected = _keyboardSelectedIndex == index;
        final isMouseSelected =
            _selectedIndex == index && _keyboardSelectedIndex == null;
        final isSelected = isKeyboardSelected || isMouseSelected;

        return _DropdownItem<T>(
          key: ValueKey('item_$index'),
          item: item,
          displayText: widget.displayText,
          isSelected: isSelected,
          onTap: () {
            debugPrint('✅ Dropdown item tapped: ${widget.displayText(item)}');
            _onItemSelected(item);
          },
          onHover: (isHovered) {
            if (isHovered && _keyboardSelectedIndex == null) {
              setState(() {
                _selectedIndex = index;
              });
            } else if (!isHovered &&
                _selectedIndex == index &&
                _keyboardSelectedIndex == null) {
              setState(() {
                _selectedIndex = null;
              });
            }
          },
        );
      },
    );
  }

  void _onItemSelected(T item) {
    debugPrint('🎯 Selected item: ${widget.displayText(item)}');
    _controller.text = widget.displayText(item);
    widget.onChanged(item);
    _hideDropdown();
    _focusNode.unfocus();

    setState(() {
      _userHasTyped = false;
    });
  }

  double _getDropdownWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 200;
  }

  void _scrollToSelectedItem() {
    if (_keyboardSelectedIndex == null || !_scrollController.hasClients) return;

    final double scrollOffset = _keyboardSelectedIndex! * _itemHeight;
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
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_keyboardSelectedIndex != null &&
            _keyboardSelectedIndex! >= 0 &&
            _keyboardSelectedIndex! < _filteredItems.length) {
          _onItemSelected(_filteredItems[_keyboardSelectedIndex!]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideDropdown();
        _focusNode.unfocus();
      }
    }
  }

  void _navigateDown() {
    setState(() {
      _selectedIndex = null;
      if (_keyboardSelectedIndex == null) {
        _keyboardSelectedIndex = 0;
      } else if (_keyboardSelectedIndex! < _filteredItems.length - 1) {
        _keyboardSelectedIndex = _keyboardSelectedIndex! + 1;
      } else {
        _keyboardSelectedIndex = 0;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItem();
    });
    _updateOverlay();
  }

  void _navigateUp() {
    setState(() {
      _selectedIndex = null;
      if (_keyboardSelectedIndex == null) {
        _keyboardSelectedIndex = _filteredItems.length - 1;
      } else if (_keyboardSelectedIndex! > 0) {
        _keyboardSelectedIndex = _keyboardSelectedIndex! - 1;
      } else {
        _keyboardSelectedIndex = _filteredItems.length - 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedItem();
    });
    _updateOverlay();
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
              focusNode: FocusNode(),
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
                      setState(() {
                        _userHasTyped = true;
                      });
                      if (_controller.text.isNotEmpty) {
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.text.length,
                        );
                      }
                      if (!_isDropdownOpen) {
                        _showDropdown();
                      }
                    },
                    onSubmitted: (_) {
                      if (_keyboardSelectedIndex != null &&
                          _keyboardSelectedIndex! >= 0 &&
                          _keyboardSelectedIndex! < _filteredItems.length) {
                        _onItemSelected(
                            _filteredItems[_keyboardSelectedIndex!]);
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
                          if (widget.value != null &&
                              _controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                debugPrint('❌ Clear icon tapped');
                                _controller.clear();
                                widget.onChanged(null);
                                setState(() {
                                  _userHasTyped = true;
                                });
                                _focusNode.requestFocus();
                                if (!_isDropdownOpen) {
                                  _showDropdown();
                                }
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
      ],
    );
  }
}

class _DropdownItem<T> extends StatefulWidget {
  final T item;
  final String Function(T) displayText;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(bool) onHover;

  const _DropdownItem({
    Key? key,
    required this.item,
    required this.displayText,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  }) : super(key: key);

  @override
  State<_DropdownItem<T>> createState() => _DropdownItemState<T>();
}

class _DropdownItemState<T> extends State<_DropdownItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || widget.isSelected;

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
          debugPrint('👉 GestureDetector tapped: ${widget.displayText(widget.item)}');
          widget.onTap();
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.blue.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.displayText(widget.item),
              style: TextStyle(
                fontSize: 12,
                color: isHighlighted ? Colors.blue.shade800 : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
