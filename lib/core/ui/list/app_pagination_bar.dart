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
  });

  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;

  /// e.g. "20 customers on this page".
  final String countLabel;

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
  });

  AppPaginationBar.fromState(ListPagination state, {Key? key})
      : this(
          key: key,
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          countLabel: state.countLabel,
          onPageChanged: state.onPageChanged,
        );

  static const compactBreakpoint = 440.0;

  final int currentPage;
  final int totalPages;
  final String countLabel;
  final ValueChanged<int> onPageChanged;

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
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'pagination.page_of'.trParams({
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
                onPressed: currentPage < totalPages
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
          return Row(children: [count, const Spacer(), pager]);
        },
      ),
    );
  }
}
