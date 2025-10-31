import 'package:flutter/material.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../responsive.dart';

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
    final double leadingBox = resolvedIconSize + 4.0; // small padding around icon
    final double gap = widget.horizontalGap ?? 12.0;
    return widget.selected
        ? Column(
            children: [
              Stack(
                children: [
                  Positioned(
                    left: ResponsiveWidget.isTablet(context) ? 10 : 20,
                    right: ResponsiveWidget.isTablet(context) ? 10 : 20,
                    child: Container(
                      alignment: Alignment.center,
                      // width intentionally omitted so it won't stretch full width
                      height: MediaQuery.of(context).size.height * .055,
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ListTile(
                    selected: widget.selected,
                    contentPadding: ResponsiveWidget.isTablet(context)
                        ? const EdgeInsets.only(left: 15, right: 10)
                        : const EdgeInsets.only(left: 45, right: 15),
                    horizontalTitleGap: gap,
                    visualDensity:
                        const VisualDensity(vertical: -4, horizontal: 0),
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
                    trailing: _isExpanded
                        ? const Icon(
                            Icons.keyboard_arrow_up_sharp,
                            color: Colors.white,
                          )
                        : const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                    title: Text(
                      widget.title,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s14, 0.21, ColorManager.textColor),
                    ),
                  ),
                ],
              ),
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // First sub-item - only show if permission allows
                      if (widget.showTitle1 == true)
                        ListTile(
                          selected: _selectedTileIndex == 0,
                          selectedTileColor: _selectedTileIndex == 0
                              ? Colors.blue.withOpacity(0.1)
                              : null,
                          contentPadding: ResponsiveWidget.isTablet(context)
                              ? const EdgeInsets.only(left: 15, right: 10)
                              : const EdgeInsets.only(left: 45, right: 15),
                          horizontalTitleGap: 0.0,
                          visualDensity:
                              const VisualDensity(vertical: -4, horizontal: 0),
                          minVerticalPadding: 0,
                          onTap: () => _onTapTile(0, widget.onTapTitle1),
                          leading: const BubbleIcon(),
                          title: Text(
                            widget.listTitle1,
                            style: buildCustomStyle(FontWeightManager.medium,
                                FontSize.s11, 0.21, ColorManager.textColor),
                          ),
                        ),
                      // Second sub-item - only show if permission allows and title exists
                      widget.listTitle2 != null && widget.showTitle2 == true
                          ? ListTile(
                              selected: _selectedTileIndex == 1,
                              selectedTileColor: _selectedTileIndex == 1
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                              contentPadding: ResponsiveWidget.isTablet(context)
                                  ? const EdgeInsets.only(left: 15, right: 10)
                                  : const EdgeInsets.only(left: 45, right: 15),
                              horizontalTitleGap: 0.0,
                              visualDensity: const VisualDensity(
                                  vertical: -4, horizontal: 0),
                              minVerticalPadding: 0,
                              onTap: () => _onTapTile(1, widget.onTapTitle2!),
                              leading: const BubbleIcon(),
                              title: Text(
                                widget.listTitle2 ?? '',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.21,
                                    ColorManager.textColor),
                              ),
                            )
                          : Container(),
                      // Third sub-item - only show if permission allows and title exists
                      widget.listTitle3 != null && widget.showTitle3 == true
                          ? ListTile(
                              selected: _selectedTileIndex == 2,
                              selectedTileColor: _selectedTileIndex == 2
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                              contentPadding: ResponsiveWidget.isTablet(context)
                                  ? const EdgeInsets.only(left: 15, right: 10)
                                  : const EdgeInsets.only(left: 45, right: 15),
                              horizontalTitleGap: 0.0,
                              visualDensity: const VisualDensity(
                                  vertical: -4, horizontal: 0),
                              minVerticalPadding: 0,
                              onTap: () => _onTapTile(2, widget.onTapTitle3!),
                              leading: const BubbleIcon(),
                              title: Text(
                                widget.listTitle3 ?? '',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.21,
                                    ColorManager.textColor),
                              ),
                            )
                          : Container(),
                      widget.listTitle4 != null && widget.showTitle4 == true
                          ? ListTile(
                              selected: _selectedTileIndex == 3,
                              selectedTileColor: _selectedTileIndex == 3
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                              contentPadding: ResponsiveWidget.isTablet(context)
                                  ? const EdgeInsets.only(left: 15, right: 10)
                                  : const EdgeInsets.only(left: 45, right: 15),
                              horizontalTitleGap: 0.0,
                              visualDensity: const VisualDensity(
                                  vertical: -4, horizontal: 0),
                              minVerticalPadding: 0,
                              onTap: () => _onTapTile(3, widget.onTapTitle4!),
                              leading: const BubbleIcon(),
                              title: Text(
                                widget.listTitle4 ?? '',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.21,
                                    ColorManager.textColor),
                              ),
                            )
                          : Container(),
                      // Fifth sub-item - only show if permission allows and title exists
                      widget.listTitle5 != null && widget.showTitle5 == true
                          ? ListTile(
                              selected: _selectedTileIndex == 4,
                              selectedTileColor: _selectedTileIndex == 4
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                              contentPadding: ResponsiveWidget.isTablet(context)
                                  ? const EdgeInsets.only(left: 15, right: 10)
                                  : const EdgeInsets.only(left: 45, right: 15),
                              horizontalTitleGap: 0.0,
                              visualDensity: const VisualDensity(
                                  vertical: -4, horizontal: 0),
                              minVerticalPadding: 0,
                              onTap: () => _onTapTile(4, widget.onTapTitle5!),
                              leading: const BubbleIcon(),
                              title: Text(
                                widget.listTitle5 ?? '',
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.21,
                                    ColorManager.textColor),
                              ),
                            )
                          : Container(),
                    ],
                  ),
                ),
            ],
          )
        : ListTile(
            selected: widget.selected,
            contentPadding: ResponsiveWidget.isTablet(context)
                ? const EdgeInsets.only(left: 15, right: 10)
                : const EdgeInsets.only(left: 45, right: 15),
            horizontalTitleGap: gap,
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            minVerticalPadding: 0,
            onTap: widget.onTap,
            minLeadingWidth: leadingBox,
            leading: SizedBox(
              width: leadingBox,
              height: leadingBox,
              child: Center(
                child: widget.icon != null
                    ? Icon(
                        widget.icon,
                        size: resolvedIconSize,
                        color: widget.selected
                            ? Colors.white
                            : ColorManager.kPrimaryColor,
                      )
                    : WebsafeSvg.asset(
                        widget.iconPath!,
                        width: resolvedIconSize,
                        height: resolvedIconSize,
                        colorFilter: ColorFilter.mode(
                          widget.selected
                              ? Colors.white
                              : ColorManager.kPrimaryColor,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
            title: Text(
              widget.title,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                  0.21, ColorManager.textColor),
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
