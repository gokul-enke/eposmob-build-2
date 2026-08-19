import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for stock screens.
///
/// Presentational only — no business logic, providers or navigation.

const double kStockPhoneBreakpoint = 600;

bool stockIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kStockPhoneBreakpoint;

double stockHorizontalPadding(double width) =>
    width < kStockPhoneBreakpoint ? 12.0 : 20.0;

/// Shopify-style content card with subtle border and shadow.
class StockContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const StockContentCard({
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

/// Icon action with >=44px tap target.
class StockIconAction extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String tooltip;
  final VoidCallback? onPressed;

  const StockIconAction({
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

/// Label + value chip for mobile stock cards.
class StockInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? valueBgColor;

  const StockInfoChip({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBgColor,
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
          Container(
            padding: valueBgColor != null
                ? const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  )
                : EdgeInsets.zero,
            decoration: valueBgColor != null
                ? BoxDecoration(
                    color: valueBgColor,
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.15,
                valueColor ?? ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pagination that wraps on narrow screens instead of overflowing.
class StockPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const StockPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 4, top: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _StockPageButton(
            title: 'pagination.previous'.tr,
            onPressed:
                currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Text(
              'pagination.page_of'.trParams({'current': '$currentPage', 'total': '$totalPages'}),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.15,
                ColorManager.textColor,
              ),
            ),
          ),
          _StockPageButton(
            title: 'pagination.next'.tr,
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StockPageButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  const _StockPageButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Text(
            title,
            style: TextStyle(
              color: onPressed != null ? Colors.blue : Colors.grey,
              fontSize: 12,
              decoration: onPressed != null ? TextDecoration.underline : null,
              decorationColor: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}
