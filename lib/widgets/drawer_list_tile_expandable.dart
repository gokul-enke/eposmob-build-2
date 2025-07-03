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
    return widget.selected
        ? Column(
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      width: 200,
                      height: MediaQuery.of(context).size.height * .055,
                      margin: ResponsiveWidget.isTablet(context)
                          ? const EdgeInsets.only(left: 10, bottom: 5)
                          : const EdgeInsets.only(left: 20, bottom: 5),
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
                    horizontalTitleGap: 0.0,
                    visualDensity:
                        const VisualDensity(vertical: -4, horizontal: 0),
                    minVerticalPadding: 0,
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    leading: widget.icon != null
                        ? Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 20,
                          )
                        : WebsafeSvg.asset(widget.iconPath!,
                            color: Colors.white),
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
                      widget.listTitle2 != null
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
                      widget.listTitle3 != null
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
                      widget.listTitle4 != null
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
            horizontalTitleGap: 0.0,
            visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
            minVerticalPadding: 0,
            onTap: widget.onTap,
            leading: widget.icon != null
                ? Icon(widget.icon,
                    size: 20,
                    color: widget.selected
                        ? Colors.white
                        : ColorManager.kPrimaryColor)
                : WebsafeSvg.asset(widget.iconPath!,
                    color: widget.selected
                        ? Colors.white
                        : ColorManager.kPrimaryColor),
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
