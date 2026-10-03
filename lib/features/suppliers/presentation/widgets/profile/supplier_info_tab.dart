import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import 'info/supplier_info_sections.dart';
import 'info/supplier_quick_actions.dart';

/// Read-only overview of a supplier: contact, account, address, KYC and
/// quick actions.
class SupplierInfoTab extends StatelessWidget {
  const SupplierInfoTab({
    super.key,
    required this.supplier,
    required this.onEdit,
    required this.onViewOrders,
  });

  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      SupplierInfoHeader(supplier: supplier),
      SupplierContactSection(supplier: supplier),
      SupplierAccountSection(supplier: supplier),
      SupplierAddressSection(supplier: supplier),
      SupplierKycSection(entries: supplier.kyc),
      SupplierQuickActions(onEdit: onEdit, onViewOrders: onViewOrders),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            sections[i],
          ],
        ],
      ),
    );
  }
}
