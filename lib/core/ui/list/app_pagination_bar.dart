import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../buttons/app_buttons.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_sizes.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

/// Everything a list page needs to draw its pagination bar.
@immutable
class ListPagination {
  const ListPagination({
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.countLabel,
    this.totalPagesKnown = true,
    this.enabled = true,
  });

  final int currentPage;
  final int totalPages;

  /// False for APIs which expose only whether another page exists.
  final bool totalPagesKnown;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;

  /// e.g. "20 customers on this page".
  final String countLabel;

  /// False keeps the displayed page/count while disabling navigation (for
  /// example, when retained rows do not match the newly selected filters).
  final bool enabled;

  /// 1-based number of the row at [index] on the current page.
  int rowNumber(int index) => index + 1 + (currentPage - 1) * itemsPerPage;
}

/// "N on this page" on the left, ‹ Page x of y › on the right. Stacks
/// vertically below 440 px.
class AppPaginationBar extends StatelessWidget {
  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.countLabel,
    required this.onPageChanged,
    this.enabled = true,
    this.totalPagesKnown = true,
  });

  AppPaginationBar.fromState(
    ListPagination state, {
    Key? key,
    bool enabled = true,
  }) : this(
          key: key,
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          countLabel: state.countLabel,
          onPageChanged: state.onPageChanged,
          enabled: enabled && state.enabled,
          totalPagesKnown: state.totalPagesKnown,
        );

  static const compactBreakpoint = 440.0;

  final int currentPage;
  final int totalPages;
  final bool totalPagesKnown;
  final String countLabel;
  final ValueChanged<int> onPageChanged;

  /// False disables both arrows (e.g. while a page is loading).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('app_pagination_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < compactBreakpoint;
          final count = Text(countLabel, style: AppTextStyles.caption);
          final pager = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSquareIconButton(
                tooltip: 'pagination.previous_page'.tr,
                icon: Icons.chevron_left_rounded,
                size: AppSizes.compactControl,
                radius: AppRadius.tile,
                onPressed: enabled && currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  (totalPagesKnown
                          ? 'pagination.page_of'
                          : 'pagination.current_page')
                      .trParams({
                    'current': '$currentPage',
                    'total': '$totalPages',
                  }),
                  style: const TextStyle(
                    color: AppColors.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppSquareIconButton(
                tooltip: 'pagination.next_page'.tr,
                icon: Icons.chevron_right_rounded,
                size: AppSizes.compactControl,
                radius: AppRadius.tile,
                onPressed: enabled && currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          );

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [count, const SizedBox(height: 8), pager],
            );
          }
          // The count takes the leftover width and ellipsizes, so long
          // labels never push the pager off the bar.
          return Row(
            children: [
              Expanded(
                child: Text(
                  countLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              pager,
            ],
          );
        },
      ),
    );
  }
}
