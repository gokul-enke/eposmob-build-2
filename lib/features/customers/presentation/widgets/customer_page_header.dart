import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'customer_ui.dart';

class CustomerPageHeader extends StatelessWidget {
  const CustomerPageHeader({
    super.key,
    required this.onAddCustomer,
    this.onRefresh,
  });

  final VoidCallback onAddCustomer;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 40 : 46,
              height: compact ? 40 : 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CustomerUiColors.softBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                color: ColorManager.kPrimaryColor,
                size: compact ? 21 : 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'customers.title'.tr,
                    style: TextStyle(
                      color: CustomerUiColors.heading,
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      'customers.subtitle'.tr,
                      style: const TextStyle(
                        color: CustomerUiColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRefresh != null) ...[
              Tooltip(
                message: 'customers.refresh'.tr,
                child: OutlinedButton(
                  onPressed: onRefresh,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    foregroundColor: CustomerUiColors.body,
                    side: const BorderSide(color: CustomerUiColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(compact ? 'customers.add_short'.tr : 'customers.add'.tr),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: ColorManager.kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}
