import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/customers/presentation/widgets/form/customer_form.dart';

/// Full-screen mobile "Add New Customer" page with the same fields,
/// validation, and submit logic as the add-customer dialog.
class AddCustomerMobilePage extends StatelessWidget {
  const AddCustomerMobilePage({
    super.key,
    this.initialMobileNumber = '',
    this.initialCustomerName,
  });

  final String initialMobileNumber;
  final String? initialCustomerName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: CustomerForm.create(
                  initialPhone: initialMobileNumber,
                  initialName: initialCustomerName,
                  autofocus: true,
                  cancelLabel: 'add_customer.btn_close'.tr,
                  onCancel: () => Navigator.of(context).pop(),
                  onCreated: (result) => Navigator.of(context).pop(result),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back, color: AppColors.heading),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'add_customer.title'.tr,
                style: AppTextStyles.pageTitleCompact,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Opens the mobile add-customer page and returns the same result map as
/// `showAddCustomerDialog` on success.
Future<dynamic> openAddCustomerMobilePage(
  BuildContext context, {
  String mobileNumber = '',
  String? customerName,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddCustomerMobilePage(
        initialMobileNumber: mobileNumber,
        initialCustomerName: customerName,
      ),
    ),
  );
}
