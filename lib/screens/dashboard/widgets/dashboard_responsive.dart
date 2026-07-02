import 'package:flutter/material.dart';

import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

/// Shared responsive helpers for the dashboards.
///
/// This file only contains presentational widgets. It never touches business
/// logic, providers or data fetching - callers pass in already-computed values.

/// Computes how many stat cards fit per row for a given available [width].
///
/// Scales from a single column on very small phones up to five columns on
/// wide desktop layouts, matching a modern admin dashboard grid.
int dashboardCrossAxisCount(double width) {
  if (width < 360) return 1;
  if (width < 620) return 2;
  if (width < 920) return 3;
  if (width < 1200) return 4;
  return 5;
}

/// Lays out [cards] in a responsive, non-overflowing grid.
///
/// Uses a [LayoutBuilder] so the number of columns adapts to the real width
/// the section is given (works inside both mobile and desktop shells). Every
/// card is sized to an equal width so the grid stays tidy and aligned.
class ResponsiveStatGrid extends StatelessWidget {
  final List<Widget> cards;
  final double spacing;
  final double runSpacing;
  final double cardHeight;
  final EdgeInsetsGeometry padding;
  final int? maxColumns;

  const ResponsiveStatGrid({
    super.key,
    required this.cards,
    this.spacing = 14,
    this.runSpacing = 14,
    this.cardHeight = 150,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.maxColumns,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double available = constraints.maxWidth;
          int columns = dashboardCrossAxisCount(available);
          if (maxColumns != null && columns > maxColumns!) {
            columns = maxColumns!;
          }
          if (columns > cards.length) columns = cards.length;
          if (columns < 1) columns = 1;

          final double itemWidth =
              (available - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: itemWidth,
                    height: cardHeight,
                    child: card,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

/// A modern, Shopify-like stat card with an icon chip, an optional trend pill,
/// a prominent value, a label and a muted sub-label.
///
/// [valueWidget] can be supplied when the caller needs to wrap the value in a
/// provider consumer (e.g. currency formatting); otherwise [value] is used.
class DashboardStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Widget? valueWidget;
  final Color color;
  final IconData icon;
  final String? trendLabel;
  final bool showTrend;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.icon,
    this.valueWidget,
    this.trendLabel = "+12%",
    this.showTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 14,
      padding: const EdgeInsets.all(14),
      showShadow: true,
      blurRadius: 10,
      offsetValue: const Offset(0, 3),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (showTrend)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up,
                          size: 12, color: Colors.green[600]),
                      const SizedBox(width: 3),
                      Text(
                        trendLabel ?? "+12%",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s10,
                          0.10,
                          Colors.green[600]!,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              valueWidget ??
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s20,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s14,
                  0.15,
                  ColorManager.textColor,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.10,
                  Colors.grey[600]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A consistent, aligned section header used above each stat grid.
///
/// [trailing] is typically a period selector / dropdown supplied by the caller
/// (whose logic remains untouched).
class DashboardSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
