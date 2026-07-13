import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for quotation screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kQuotationsPhoneBreakpoint = 600;

bool quotationsIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kQuotationsPhoneBreakpoint;

double quotationsHorizontalPadding(double width) =>
    width < kQuotationsPhoneBreakpoint ? 12.0 : 20.0;

double quotationsVerticalPadding(double width) =>
    width < kQuotationsPhoneBreakpoint ? 12.0 : 16.0;

/// Fixed-height list page shell with pull-to-refresh.
class QuotationsListShell extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const QuotationsListShell({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kQuotationsPhoneBreakpoint;

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
            horizontal: quotationsHorizontalPadding(width),
            vertical: quotationsVerticalPadding(width),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Details page shell with white background and responsive padding.
class QuotationsDetailsShell extends StatelessWidget {
  final Widget child;

  const QuotationsDetailsShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kQuotationsPhoneBreakpoint;

    return Container(
      color: Colors.white,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isPhone ? 12 : 20,
        vertical: isPhone ? 8 : 12,
      ),
      child: child,
    );
  }
}

/// Shopify-style content card with subtle border and shadow.
class QuotationsContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const QuotationsContentCard({
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
class QuotationsPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const QuotationsPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = quotationsIsPhone(context);

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
                child: Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
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
class QuotationsSectionTitle extends StatelessWidget {
  final String title;

  const QuotationsSectionTitle({super.key, required this.title});

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

/// Status pill for quotation status.
class QuotationsStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const QuotationsStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label.isEmpty ? '—' : label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.13,
          color,
        ),
      ),
    );
  }
}

/// Icon action with >=44px tap target.
class QuotationsIconAction extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  const QuotationsIconAction({
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
class QuotationsResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const QuotationsResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return QuotationsContentCard(
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

/// Filter fields that stack on phones and flow in rows on desktop.
class QuotationsFilterLayout extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const QuotationsFilterLayout({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (quotationsIsPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      );
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: children
          .map(
            (child) => SizedBox(
              width: (MediaQuery.of(context).size.width - 80) / 4,
              child: child,
            ),
          )
          .toList(),
    );
  }
}

/// Two-column layout that stacks on phones.
class QuotationsTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const QuotationsTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (quotationsIsPhone(context)) {
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

/// Detail info chips that stack on phone.
class QuotationsDetailGrid extends StatelessWidget {
  final List<Widget> children;

  const QuotationsDetailGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (quotationsIsPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Label + value chip for detail screens and mobile cards.
class QuotationsInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const QuotationsInfoChip({
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
          SelectableText(
            value,
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
