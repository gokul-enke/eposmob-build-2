import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
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
    super.key,
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
    this.autofocus = true,
  });

  @override
  State<BuildDropDownWithSearch<T>> createState() =>
      _BuildDropDownWithSearchState<T>();
}

class _BuildDropDownWithSearchState<T>
    extends State<BuildDropDownWithSearch<T>> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    _searchFocusNode = FocusNode();
    // Intercept key events while the search field is focused
    _searchFocusNode.onKey = _onSearchKey;
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    _searchFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onSearchKey(FocusNode node, RawKeyEvent event) {
    // Only react on key down to avoid duplicate handling
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final BuildContext? searchCtx = node.context;
      if (searchCtx != null) {
        // Defer to next microtask to avoid TextField reasserting focus
        Future.microtask(() {
          final scope = FocusScope.of(searchCtx);
          final moved = scope.focusInDirection(TraversalDirection.down);
          if (!moved) {
            scope.nextFocus();
          }
        });
      }
      // Mark as handled so the TextField doesn't consume the key
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            constraints: BoxConstraints(
              minHeight:
                  widget.height ?? MediaQuery.of(context).size.height * .07,
              maxHeight:
                  widget.height ?? MediaQuery.of(context).size.height * .07,
            ),
            child: DropdownSearch<T>(
              items: (filter, infiniteScrollProps) => widget.items,
              dropdownBuilder: (context, selectedItem) {
                final bool hasValue = selectedItem != null;
                final String text = hasValue
                    ? widget.displayText(selectedItem as T)
                    : widget.hintText;
                final TextStyle style = hasValue
                    ? buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s13,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      )
                    : buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.27,
                        ColorManager.textColor.withOpacity(.5),
                      );
                return SizedBox.expand(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 8),
                      child: Text(
                        text,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
              decoratorProps: DropDownDecoratorProps(
                decoration: InputDecoration(
                  hintText: null,
                  hintStyle: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding:
                      widget.contentPadding ?? const EdgeInsets.only(left: 15),
                  suffixIcon: Center(
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: ColorManager.textColor.withOpacity(.6),
                    ),
                  ),
                  suffixIconConstraints: BoxConstraints(
                    minHeight: widget.height ??
                        MediaQuery.of(context).size.height * .07,
                    minWidth: 40,
                  ),
                ),
                baseStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s13,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: widget.autofocus,
                  decoration: InputDecoration(
                    hintText: widget.searchHintText ?? 'Search...',
                    hintStyle: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      Colors.grey.shade600,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide(color: Colors.blue.shade600),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.27,
                    Colors.black87,
                  ),
                ),
                // Clear the search query when popup is closed
                onDismissed: () {
                  _searchController.clear();
                },
                menuProps: MenuProps(
                  backgroundColor: Colors.white,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(7),
                ),
                itemBuilder: (context, item, isDisabled, isSelected) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Colors.blue.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.displayText(item),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isSelected ? Colors.blue.shade800 : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: null,
                      softWrap: true,
                    ),
                  );
                },
                emptyBuilder: (context, searchEntry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    child: Text(
                      'No items found',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.27,
                        Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
                loadingBuilder: (context, searchEntry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                searchDelay: const Duration(milliseconds: 300),
              ),
              selectedItem: widget.value,
              itemAsString: widget.displayText,
              onChanged: (val) {
                // Propagate change
                widget.onChanged(val);
                // Clear search when user selects an item or clears selection
                _searchController.clear();
              },
              compareFn: (a, b) {
                if (a == null && b == null) return true;
                if (a == null || b == null) return false;
                // Compare using provided displayText mapping for generic types
                try {
                  return widget.displayText(a) == widget.displayText(b);
                } catch (_) {
                  return a == b;
                }
              },
              filterFn: (item, filter) {
                return widget
                    .displayText(item)
                    .toLowerCase()
                    .contains(filter.toLowerCase());
              },
              suffixProps: DropdownSuffixProps(
                clearButtonProps: ClearButtonProps(
                  isVisible: true,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: ColorManager.textColor.withOpacity(.6),
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
