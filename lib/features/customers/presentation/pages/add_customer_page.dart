import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../navigation/customer_navigation.dart';
import '../widgets/form/customer_form.dart';

/// Sidebar "Add customer" page. The form empties itself after each save so
/// the next customer can be entered.
class AddCustomerPage extends StatelessWidget {
  const AddCustomerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = constraints.maxWidth < 600 ? 16.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: CustomerNavigation.openList,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: EdgeInsets.zero,
                          textStyle: AppTextStyles.button,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text('add_customer.back_to_customers'.tr),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'add_customer.title'.tr,
                        style: gutter < 24
                            ? AppTextStyles.pageTitleCompact
                            : AppTextStyles.pageTitle,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      CustomerForm.create(
                        clearOnCreated: true,
                        submitLabel: 'general.submit'.tr,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
