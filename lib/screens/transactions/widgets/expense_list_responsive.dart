import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Shared responsive helpers for the expense list screen.
///
/// Presentational only — no business logic, providers or navigation.

const double kExpenseListPhoneBreakpoint = 600;

bool expenseListIsPhone(BuildContext context) =>
    MediaQuery.of(context).size.width < kExpenseListPhoneBreakpoint;

double expenseListHorizontalPadding(double width) =>
    width < kExpenseListPhoneBreakpoint ? 12.0 : 20.0;

double expenseListVerticalPadding(double width) =>
    width < kExpenseListPhoneBreakpoint ? 12.0 : 16.0;

/// Fixed-height list page shell with white background.
class ExpenseListShell extends StatelessWidget {
  final Widget child;

  const ExpenseListShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < kExpenseListPhoneBreakpoint;

    return SafeArea(
      child: Container(
        color: Colors.white,
        margin: EdgeInsetsDirectional.only(
          start: isPhone ? 4 : 10,
          end: isPhone ? 4 : 10,
          top: isPhone ? 8 : 20,
          bottom: isPhone ? 8 : 0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: expenseListHorizontalPadding(width),
          vertical: expenseListVerticalPadding(width),
        ),
        child: child,
      ),
    );
  }
}

/// Shopify-style content card with subtle border and shadow.
class ExpenseListContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const ExpenseListContentCard({
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

/// Page title with optional breadcrumb, filter action, and trailing action.
class ExpenseListPageHeader extends StatelessWidget {
  final String title;
  final Widget? breadcrumb;
  final Widget? filterAction;
  final Widget? trailing;

  const ExpenseListPageHeader({
    super.key,
    required this.title,
    this.breadcrumb,
    this.filterAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = expenseListIsPhone(context);

    final titleColumn = Column(
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
        if (breadcrumb != null) ...[
          const SizedBox(height: 4),
          breadcrumb!,
        ],
      ],
    );

    if (isPhone) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleColumn),
          if (filterAction != null || trailing != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trailing != null) trailing!,
                if (filterAction != null) filterAction!,
              ],
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleColumn),
        if (filterAction != null) ...[
          filterAction!,
          if (trailing != null) const SizedBox(width: 8),
        ],
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Section label used above tables and filter groups.
class ExpenseListSectionTitle extends StatelessWidget {
  final String title;

  const ExpenseListSectionTitle({super.key, required this.title});

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

/// Compact two-column mobile filter layout (matches sales MobileFilters pattern).
class ExpenseListMobileFilterFields extends StatelessWidget {
  final Widget categoryFilter;
  final Widget referenceFilter;
  final Widget debitFilter;
  final Widget statusFilter;

  const ExpenseListMobileFilterFields({
    super.key,
    required this.categoryFilter,
    required this.referenceFilter,
    required this.debitFilter,
    required this.statusFilter,
  });

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _labeledField('expense.category'.tr, categoryFilter),
              const SizedBox(height: 10),
              _labeledField('expense.hint_reference_no'.tr, referenceFilter),
              const SizedBox(height: 10),
              _labeledField('expense.filter_debit_account'.tr, debitFilter),
              const SizedBox(height: 10),
              _labeledField('expense.status'.tr, statusFilter),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _labeledField('expense.category'.tr, categoryFilter)),
                const SizedBox(width: 10),
                Expanded(child: _labeledField('expense.hint_reference_no'.tr, referenceFilter)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _labeledField('expense.filter_debit_account'.tr, debitFilter)),
                const SizedBox(width: 10),
                Expanded(child: _labeledField('expense.status'.tr, statusFilter)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Filter icon on the right of the title row (matches sales.dart).
class ExpenseListFilterToggle extends StatelessWidget {
  final bool showFilters;
  final bool hasActiveFilters;
  final VoidCallback onPressed;

  const ExpenseListFilterToggle({
    super.key,
    required this.showFilters,
    required this.hasActiveFilters,
    required this.onPressed,
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
              showFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onPressed,
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

/// Horizontally scrollable table wrapper for narrow-but-not-phone widths.
class ExpenseListResponsiveTable extends StatelessWidget {
  final Widget table;
  final double minWidth;

  const ExpenseListResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 880,
  });

  @override
  Widget build(BuildContext context) {
    return ExpenseListContentCard(
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

/// Label + value chip for mobile expense cards.
class ExpenseListInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const ExpenseListInfoChip({
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

/// Status pill with colour derived from the status string (visual only).
class ExpenseListStatusPill extends StatelessWidget {
  final String status;

  const ExpenseListStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    Color fg;
    Color bg;

    if (normalized.contains('SUCC') || normalized.contains('PAID')) {
      fg = Colors.green.shade700;
      bg = Colors.green.withOpacity(0.12);
    } else if (normalized.contains('PEND') || normalized.contains('WAIT')) {
      fg = Colors.orange.shade800;
      bg = Colors.orange.withOpacity(0.12);
    } else if (normalized.contains('FAIL') || normalized.contains('REJ')) {
      fg = Colors.red.shade700;
      bg = Colors.red.withOpacity(0.12);
    } else {
      fg = ColorManager.kPrimaryColor;
      bg = ColorManager.kPrimaryColor.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        normalized,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s10,
          0.05,
          fg,
        ),
      ),
    );
  }
}

/// View action with >=44px tap target.
class ExpenseListViewAction extends StatelessWidget {
  final VoidCallback onPressed;

  const ExpenseListViewAction({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: const Icon(Icons.visibility_outlined,
            color: ColorManager.kPrimaryColor, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
      ),
    );
  }
}
