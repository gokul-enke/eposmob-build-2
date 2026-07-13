import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for product barcode screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kProductBarcodePhoneBreakpoint = 600;

bool productBarcodeIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kProductBarcodePhoneBreakpoint;

double productBarcodeHorizontalPadding(double width) =>
    width < kProductBarcodePhoneBreakpoint ? 12.0 : 20.0;

double productBarcodeVerticalPadding(double width) =>
    width < kProductBarcodePhoneBreakpoint ? 12.0 : 16.0;

/// Shopify-style content card with subtle border and shadow.
class ProductBarcodeContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const ProductBarcodeContentCard({
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
class ProductBarcodePageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ProductBarcodePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = productBarcodeIsPhone(context);

    if (isPhone && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
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
                maxLines: 2,
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
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Selection count pill shown when products are selected.
class ProductBarcodeSelectionBadge extends StatelessWidget {
  final int count;

  const ProductBarcodeSelectionBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.25),
        ),
      ),
      child: Text(
        '$count selected',
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.13,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}

/// Icon action with plain colored icon on a white shadow box.
class ProductBarcodeIconAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onPressed;

  const ProductBarcodeIconAction({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 32,
        height: 32,
        child: BuildBoxShadowContainer(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          circleRadius: 5,
          child: IconButton(
            icon: Icon(icon, size: 18, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable table wrapper for narrow screens.
class ProductBarcodeResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const ProductBarcodeResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 960,
  });

  @override
  Widget build(BuildContext context) {
    return ProductBarcodeContentCard(
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

/// Filter fields that stack on phones and flow in a row on desktop.
class ProductBarcodeFilterLayout extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ProductBarcodeFilterLayout({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (productBarcodeIsPhone(context)) {
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Two-column layout that stacks on phones.
class ProductBarcodeTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const ProductBarcodeTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (productBarcodeIsPhone(context)) {
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
      children: [
        Expanded(child: start),
        SizedBox(width: spacing),
        Expanded(child: end),
      ],
    );
  }
}

/// Label + value chip for mobile cards and detail dialogs.
class ProductBarcodeInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const ProductBarcodeInfoChip({
    super.key,
    required this.label,
    required this.value,
    this.copyable = false,
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
          Row(
            children: [
              Flexible(
                child: SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.15,
                    ColorManager.textColor,
                  ),
                ),
              ),
              if (copyable && value.isNotEmpty && value != 'N/A') ...[
                const SizedBox(width: 6),
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      showScaffold(
                        context: context,
                        message: '$label copied to clipboard',
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.black38,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Polished loading state.
class ProductBarcodeLoadingState extends StatelessWidget {
  final String message;

  const ProductBarcodeLoadingState({
    super.key,
    this.message = 'Loading products...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: ColorManager.kPrimaryColor,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s13,
              0.15,
              ColorManager.kGreyColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Polished empty state.
class ProductBarcodeEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ProductBarcodeEmptyState({
    super.key,
    this.title = 'No products found',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_2_outlined,
                size: 40,
                color: ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.kTitleTextColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.15,
                  Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filter toggle with active-indicator dot.
class ProductBarcodeFilterToggle extends StatelessWidget {
  final bool showFilters;
  final bool hasActiveFilters;
  final VoidCallback onToggle;

  const ProductBarcodeFilterToggle({
    super.key,
    required this.showFilters,
    required this.hasActiveFilters,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onToggle,
            tooltip: showFilters ? 'Hide Filters' : 'Show Filters',
          ),
          if (hasActiveFilters)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
