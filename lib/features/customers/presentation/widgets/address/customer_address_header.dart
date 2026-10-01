import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Title row of the address tab: icon, title, customer name, refresh and
/// add buttons. Collapses the add button to an icon when [compact].
class CustomerAddressHeader extends StatelessWidget {
  const CustomerAddressHeader({
    super.key,
    required this.customerName,
    required this.onAdd,
    required this.onRefresh,
    this.compact = false,
    this.refreshFailed = false,
  });

  final String? customerName;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;
  final bool compact;

  /// Shows a warning that the latest refresh did not succeed.
  final bool refreshFailed;

  @override
  Widget build(BuildContext context) {
    final name = customerName?.trim() ?? '';
    return Row(
      children: [
        AppIconTile(
          icon: Icons.location_on_outlined,
          size: compact ? 40 : 46,
          background: AppColors.softBlue,
          foreground: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'customer_address.section_title'.tr,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? AppTextStyles.sectionTitle.copyWith(fontSize: 16)
                    : AppTextStyles.pageTitleCompact,
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${'general.customer_prefix'.tr}$name',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.pageSubtitle,
                ),
              ],
              if (refreshFailed) ...[
                const SizedBox(height: AppSpacing.xs),
                AppBadge(
                  label: 'customer_address.refresh_failed'.tr,
                  tone: AppBadgeTone.warning,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppSquareIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'customer_address.refresh'.tr,
          onPressed: onRefresh,
        ),
        const SizedBox(width: AppSpacing.sm),
        if (compact)
          AppSquareIconButton(
            icon: Icons.add_rounded,
            tooltip: 'customer_address.tooltip_add'.tr,
            onPressed: onAdd,
            foreground: AppColors.primary,
          )
        else
          AppPrimaryButton(
            icon: Icons.add_rounded,
            label: 'customer_address.btn_add_new'.tr,
            onPressed: onAdd,
          ),
      ],
    );
  }
}
