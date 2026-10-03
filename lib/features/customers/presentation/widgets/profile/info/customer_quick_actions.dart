import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

/// Edit / View orders / Message shortcuts at the bottom of the info tab.
class CustomerQuickActions extends StatelessWidget {
  const CustomerQuickActions({
    super.key,
    required this.onEdit,
    required this.onViewOrders,
    required this.onMessage,
  });

  final VoidCallback onEdit;
  final VoidCallback onViewOrders;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customer_profile.view_section_quick_actions'.tr,
      icon: Icons.bolt_outlined,
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.edit_outlined,
              label: 'customer_profile.view_label_edit_customer'.tr,
              color: AppColors.primary,
              onTap: onEdit,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActionTile(
              icon: Icons.history_outlined,
              label: 'customer_profile.view_label_view_orders'.tr,
              color: AppColors.green,
              onTap: onViewOrders,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ActionTile(
              icon: Icons.chat_outlined,
              label: 'customer_profile.view_label_message'.tr,
              color: AppColors.primary,
              onTap: onMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.control);
    return Material(
      color: color.withValues(alpha: .08),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
