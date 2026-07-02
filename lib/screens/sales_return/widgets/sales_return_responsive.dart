import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for sales return screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kSalesReturnPhoneBreakpoint = 600;

bool salesReturnIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kSalesReturnPhoneBreakpoint;

double salesReturnHorizontalPadding(double width) =>
    width < kSalesReturnPhoneBreakpoint ? 12.0 : 20.0;

double salesReturnVerticalPadding(double width) =>
    width < kSalesReturnPhoneBreakpoint ? 12.0 : 16.0;

/// Scrollable page shell with pull-to-refresh for the create-return screen.
class SalesReturnScrollShell extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const SalesReturnScrollShell({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kSalesReturnPhoneBreakpoint;

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
          padding: EdgeInsets.all(isPhone ? 4 : 8),
          child: child,
        ),
      ),
    );
  }
}

/// Fixed-height list page shell with pull-to-refresh.
class SalesReturnListShell extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const SalesReturnListShell({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kSalesReturnPhoneBreakpoint;

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
            horizontal: salesReturnHorizontalPadding(width),
            vertical: salesReturnVerticalPadding(width),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shopify-style content card with subtle border and shadow.
class SalesReturnContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const SalesReturnContentCard({
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

/// Page title with optional subtitle.
class SalesReturnPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SalesReturnPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);

    if (isPhone && trailing != null) {
      return Column(
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
          const SizedBox(height: 10),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

/// Section label used above tables and forms.
class SalesReturnSectionTitle extends StatelessWidget {
  final String title;

  const SalesReturnSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s18,
        0.28,
        ColorManager.textColor,
      ),
    );
  }
}

/// Status pill for return order status.
class SalesReturnStatusBadge extends StatelessWidget {
  final String label;
  final bool isCompleted;

  const SalesReturnStatusBadge({
    super.key,
    required this.label,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? Colors.green.shade700 : Colors.orange.shade800;
    final bgColor = isCompleted
        ? Colors.green.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.13,
              color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon action with >=44px tap target.
class SalesReturnIconAction extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onPressed;

  const SalesReturnIconAction({
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
class SalesReturnResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const SalesReturnResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 860,
  });

  @override
  Widget build(BuildContext context) {
    return SalesReturnContentCard(
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

/// Two summary cards that stack on phones.
class SalesReturnTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const SalesReturnTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);

    if (isPhone) {
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

/// Action buttons that stack on phones.
class SalesReturnActionRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const SalesReturnActionRow({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (salesReturnIsPhone(context)) {
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
      mainAxisAlignment: alignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ],
    );
  }
}

/// Responsive row of order detail chips (stacks on phone).
class SalesReturnDetailGrid extends StatelessWidget {
  final List<Widget> children;

  const SalesReturnDetailGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);

    if (isPhone) {
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

/// Step hint bar that wraps on narrow screens.
class SalesReturnStepBar extends StatelessWidget {
  final List<Widget> steps;

  const SalesReturnStepBar({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.2),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: steps,
      ),
    );
  }
}

/// Label pill used in section headers.
class SalesReturnLabelPill extends StatelessWidget {
  final String label;
  final Color color;

  const SalesReturnLabelPill({
    super.key,
    required this.label,
    this.color = ColorManager.kPrimaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.25,
          color,
        ),
      ),
    );
  }
}
