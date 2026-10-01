import 'package:flutter/material.dart';

import '../display/app_icon_tile.dart';
import '../layout/app_surface.dart';
import '../tokens/app_colors.dart';

/// Mobile wrapper that hides the filter fields behind an expandable tile.
class CollapsibleFilterTile extends StatefulWidget {
  const CollapsibleFilterTile({
    super.key,
    required this.title,
    required this.collapsedSubtitle,
    required this.expandedSubtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String collapsedSubtitle;
  final String expandedSubtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<CollapsibleFilterTile> createState() => _CollapsibleFilterTileState();
}

class _CollapsibleFilterTileState extends State<CollapsibleFilterTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        // The tile needs its own Material so its ink isn't hidden by the
        // surface decoration.
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (value) => setState(() => _expanded = value),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: EdgeInsets.zero,
            leading: const AppIconTile(icon: Icons.tune_rounded, iconSize: 18),
            title: Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _expanded ? widget.expandedSubtitle : widget.collapsedSubtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            children: [widget.child],
          ),
        ),
      ),
    );
  }
}
