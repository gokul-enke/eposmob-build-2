import 'package:flutter/material.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import 'side_menu.dart';

class DrawerListTileExpandableColumn extends StatefulWidget {
  final String? iconPath;
  final IconData? icon;
  final String title;
  final String listTitle1;
  final String? listTitle2;
  final int? items;
  final bool selected;
  final VoidCallback onTapTitle1;
  final VoidCallback? onTapTitle2;
  final VoidCallback onTap;
  final VoidCallback? onTapTitle3;
  final String? listTitle3;
  final VoidCallback? onTapTitle4;
  final String? listTitle4;
  final VoidCallback? onTapTitle5;
  final String? listTitle5;
  // Optional: allow custom icon size per tile (kept consistent with DrawerListTile)
  final double? iconSize;
  // Optional: allow custom horizontal gap between icon and title per tile
  final double? horizontalGap;
  
  // Permission parameters for sub-items
  final bool? showTitle1;
  final bool? showTitle2;
  final bool? showTitle3;
  final bool? showTitle4;
  final bool? showTitle5;

  const DrawerListTileExpandableColumn({
    super.key,
    this.iconPath,
    this.icon,
    required this.title,
    required this.selected,
    required this.onTapTitle1,
    required this.onTap,
    required this.listTitle1,
    this.listTitle2,
    this.onTapTitle2,
    this.items,
    this.listTitle3,
    this.onTapTitle3,
    this.listTitle4,
    this.onTapTitle4,
    this.listTitle5,
    this.onTapTitle5,
    // Permission defaults - show all by default for backward compatibility
    this.showTitle1 = true,
    this.showTitle2 = true,
    this.showTitle3 = true,
    this.showTitle4 = true,
    this.showTitle5 = true,
    this.iconSize,
    this.horizontalGap,
  });

  @override
  State<DrawerListTileExpandableColumn> createState() =>
      _DrawerListTileExpandableColumnState();
}

class _DrawerListTileExpandableColumnState
    extends State<DrawerListTileExpandableColumn> {
  bool _isExpanded = true;
  int _selectedTileIndex = 0;

  void _onTapTile(int index, VoidCallback onTap) {
    setState(() {
      _selectedTileIndex = index;
    });
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final double resolvedIconSize = widget.iconSize ?? 18.0;
    final double leadingBox = resolvedIconSize + 4.0;
    final double gap = widget.horizontalGap ?? 12.0;
    
    // Check if sidebar is collapsed
    final sidebarState = context.findAncestorStateOfType<CollapsibleSidebarState>();
    final isSidebarExpanded = sidebarState?.isExpanded ?? true;

    // Collapsed state - icon only with tooltip
    if (!isSidebarExpanded) {
      return Tooltip(
        message: widget.title,
        preferBelow: false,
        verticalOffset: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container
              (
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected
                      ? ColorManager.kPrimaryColor.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: Center(
                  child: widget.icon != null
                      ? Icon(
                          widget.icon,
                          size: 20,
                          color: ColorManager.kPrimaryColor,
                        )
                      : WebsafeSvg.asset(
                          widget.iconPath!,
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            ColorManager.kPrimaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded state
    return widget.selected
        ? Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ColorManager.kPrimaryColor,
                      ColorManager.kPrimaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: ColorManager.kPrimaryColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  selected: widget.selected,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  horizontalTitleGap: gap,
                  visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                  minVerticalPadding: 0,
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  minLeadingWidth: leadingBox,
                  leading: SizedBox(
                    width: leadingBox,
                    height: leadingBox,
                    child: Center(
                      child: widget.icon != null
                          ? Icon(
                              widget.icon,
                              color: Colors.white,
                              size: resolvedIconSize,
                            )
                          : WebsafeSvg.asset(
                              widget.iconPath!,
                              width: resolvedIconSize,
                              height: resolvedIconSize,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                            ),
                    ),
                  ),
                  trailing: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2),
                  child: Column(
                    children: [
                      // First sub-item - only show if permission allows
                      if (widget.showTitle1 == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedTileIndex == 0
                                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            selected: _selectedTileIndex == 0,
                            contentPadding: const EdgeInsets.only(left: 20, right: 10),
                            horizontalTitleGap: 8.0,
                            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                            minVerticalPadding: 0,
                            onTap: () => _onTapTile(0, widget.onTapTitle1),
                            leading: const BubbleIcon(),
                            title: Text(
                              widget.listTitle1,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ),
                      // Second sub-item - only show if permission allows and title exists
                      if (widget.listTitle2 != null && widget.showTitle2 == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedTileIndex == 1
                                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            selected: _selectedTileIndex == 1,
                            contentPadding: const EdgeInsets.only(left: 20, right: 10),
                            horizontalTitleGap: 8.0,
                            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                            minVerticalPadding: 0,
                            onTap: () => _onTapTile(1, widget.onTapTitle2!),
                            leading: const BubbleIcon(),
                            title: Text(
                              widget.listTitle2 ?? '',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ),
                      // Third sub-item - only show if permission allows and title exists
                      if (widget.listTitle3 != null && widget.showTitle3 == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedTileIndex == 2
                                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            selected: _selectedTileIndex == 2,
                            contentPadding: const EdgeInsets.only(left: 20, right: 10),
                            horizontalTitleGap: 8.0,
                            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                            minVerticalPadding: 0,
                            onTap: () => _onTapTile(2, widget.onTapTitle3!),
                            leading: const BubbleIcon(),
                            title: Text(
                              widget.listTitle3 ?? '',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ),
                      // Fourth sub-item
                      if (widget.listTitle4 != null && widget.showTitle4 == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedTileIndex == 3
                                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            selected: _selectedTileIndex == 3,
                            contentPadding: const EdgeInsets.only(left: 20, right: 10),
                            horizontalTitleGap: 8.0,
                            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                            minVerticalPadding: 0,
                            onTap: () => _onTapTile(3, widget.onTapTitle4!),
                            leading: const BubbleIcon(),
                            title: Text(
                              widget.listTitle4 ?? '',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ),
                      // Fifth sub-item - only show if permission allows and title exists
                      if (widget.listTitle5 != null && widget.showTitle5 == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                            color: _selectedTileIndex == 4
                                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            selected: _selectedTileIndex == 4,
                            contentPadding: const EdgeInsets.only(left: 20, right: 10),
                            horizontalTitleGap: 8.0,
                            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                            minVerticalPadding: 0,
                            onTap: () => _onTapTile(4, widget.onTapTitle5!),
                            leading: const BubbleIcon(),
                            title: Text(
                              widget.listTitle5 ?? '',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.21,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          )
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 0.5, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  selected: widget.selected,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  horizontalTitleGap: gap,
                  visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
                  minVerticalPadding: 0,
                  minLeadingWidth: leadingBox,
                  leading: SizedBox(
                    width: leadingBox,
                    height: leadingBox,
                    child: Center(
                      child: widget.icon != null
                          ? Icon(
                              widget.icon,
                              size: resolvedIconSize,
                              color: ColorManager.kPrimaryColor,
                            )
                          : WebsafeSvg.asset(
                              widget.iconPath!,
                              width: resolvedIconSize,
                              height: resolvedIconSize,
                              colorFilter: const ColorFilter.mode(
                                ColorManager.kPrimaryColor,
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    widget.title,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                  ),
                ),
              ),
            ),
          );
  }
}

class BubbleIcon extends StatelessWidget {
  const BubbleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white, // White interior
        border: Border.all(
          color: Colors.black.withOpacity(0.7), // Black outline
          width: 1.0, // Outline width
        ),
      ),
    );
  }
}
