import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for purchase order screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kPurchaseOrdersPhoneBreakpoint = 600;

bool purchaseOrdersIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kPurchaseOrdersPhoneBreakpoint;

double purchaseOrdersHorizontalPadding(double width) =>
    width < kPurchaseOrdersPhoneBreakpoint ? 12.0 : 20.0;

double purchaseOrdersVerticalPadding(double width) =>
    width < kPurchaseOrdersPhoneBreakpoint ? 12.0 : 16.0;

/// Fixed-height list page shell with pull-to-refresh.
class PurchaseOrdersListShell extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PurchaseOrdersListShell({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kPurchaseOrdersPhoneBreakpoint;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: ColorManager.kPrimaryColor,
        child: Container(
          color: Colors.white,
          margin: EdgeInsetsDirectional.only(
            start: isPhone ? 4 : 10,
            end: isPhone ? 4 : 10,
            top: isPhone ? 8 : 20,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: purchaseOrdersHorizontalPadding(width),
            vertical: purchaseOrdersVerticalPadding(width),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shopify-style content card with subtle border and shadow.
class PurchaseOrdersContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const PurchaseOrdersContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 14,
      showShadow: true,
      blurRadius: 10,
      offsetValue: const Offset(0, 3),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      color: color ?? Colors.white,
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Page title with optional subtitle and trailing action.
class PurchaseOrdersPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const PurchaseOrdersPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = purchaseOrdersIsPhone(context);

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.10,
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 10),
            trailing!,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.10,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Section label used above tables and filter groups.
class PurchaseOrdersSectionTitle extends StatelessWidget {
  final String title;

  const PurchaseOrdersSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s14,
        0.25,
        ColorManager.textColor,
      ),
    );
  }
}

/// Icon action with >=44px tap target.
class PurchaseOrdersIconAction extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  const PurchaseOrdersIconAction({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: BuildBoxShadowContainer(
          color: backgroundColor,
          circleRadius: 10,
          child: IconButton(
            icon: Icon(icon, size: 18, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable table wrapper for narrow screens.
class PurchaseOrdersResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const PurchaseOrdersResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return PurchaseOrdersContentCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= minWidth) {
              return table;
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: table,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Label + value chip for mobile cards.
class PurchaseOrdersInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const PurchaseOrdersInfoChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.15,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column layout that stacks on phones.
class PurchaseOrdersTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const PurchaseOrdersTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (purchaseOrdersIsPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          start,
          SizedBox(height: spacing),
          end,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: start),
        SizedBox(width: spacing),
        Expanded(child: end),
      ],
    );
  }
}
