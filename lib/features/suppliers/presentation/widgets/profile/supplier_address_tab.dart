import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import 'info/supplier_info_format.dart';

/// Supplier profile "Address" tab: the supplier's business address with its
/// phone and email.
class SupplierAddressTab extends StatelessWidget {
  const SupplierAddressTab({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: SectionCard(
        title: 'supplier_profile.addr_title'.tr,
        subtitle: '${'supplier_profile.addr_supplier_prefix'.tr} '
            '${SupplierInfoFormat.orNa(supplier.name)}',
        icon: Icons.location_on_outlined,
        trailing: AppBadge(label: 'supplier_profile.addr_badge_business'.tr),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'supplier_profile.addr_card_title'.tr,
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.xs),
            InfoGrid(
              children: [
                InfoRow(
                  icon: Icons.place_outlined,
                  label: 'supplier_profile.label_address'.tr,
                  value: SupplierInfoFormat.orNotProvided(supplier.address),
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'supplier_profile.label_phone'.tr,
                  value: SupplierInfoFormat.orNotProvided(supplier.phone),
                ),
                InfoRow(
                  icon: Icons.email_outlined,
                  label: 'supplier_profile.label_email'.tr,
                  value: SupplierInfoFormat.orNotProvided(supplier.email),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
