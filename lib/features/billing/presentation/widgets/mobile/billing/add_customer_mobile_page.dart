import 'package:flutter/material.dart';
import 'package:pos_machine/newcomponents/custom_customer_form.dart';

/// Full-screen mobile "Add New Customer" page with the same fields,
/// validation, and submit logic as the desktop checkout modal form.
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
      backgroundColor: Colors.white,
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
                child: CustomCustomerForm(
                  initialMobileNumber: initialMobileNumber,
                  initialCustomerName: initialCustomerName,
                  isModal: true,
                  isMobileLayout: true,
                  onCancel: () => Navigator.of(context).pop(),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Add New Customer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
/// [showAddCustomerModal] on success.
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
