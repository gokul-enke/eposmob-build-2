import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/supplier.dart';
import 'supplier_info_format.dart';

/// Name, id and status of the supplier at the top of the info tab.
class SupplierInfoHeader extends StatelessWidget {
  const SupplierInfoHeader({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final name = SupplierInfoFormat.name(supplier.name);
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          AppAvatar(name: supplier.name, semanticLabel: name, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  SupplierInfoFormat.id(supplier.id),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            label: 'supplier_profile.view_status_active'.tr,
            tone: AppBadgeTone.success,
          ),
        ],
      ),
    );
  }
}

/// Email, phone numbers and tax number.
class SupplierContactSection extends StatelessWidget {
  const SupplierContactSection({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.view_contact_title'.tr,
      icon: Icons.contact_phone_outlined,
      child: InfoGrid(
        children: [
          InfoRow(
            icon: Icons.email_outlined,
            label: 'supplier_profile.label_email'.tr,
            value: SupplierInfoFormat.orNotProvided(supplier.email),
          ),
          InfoRow(
            icon: Icons.phone_outlined,
            label: 'supplier_profile.label_phone'.tr,
            value: SupplierInfoFormat.orNotProvided(supplier.phone),
          ),
          InfoRow(
            icon: Icons.phone_android_outlined,
            label: 'supplier_profile.view_label_alt_phone'.tr,
            value: SupplierInfoFormat.orNotProvided(supplier.altPhone),
          ),
          InfoRow(
            icon: Icons.receipt_long_outlined,
            label: 'supplier_profile.view_label_tax_number'.tr,
            value: SupplierInfoFormat.orNotProvided(supplier.taxNumber),
          ),
        ],
      ),
    );
  }
}

/// Balance, payment type, balance status and product categories.
class SupplierAccountSection extends StatelessWidget {
  const SupplierAccountSection({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.view_account_title'.tr,
      icon: Icons.account_circle_outlined,
      child: InfoGrid(
        children: [
          InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'supplier_profile.view_label_current_balance'.tr,
            value: SupplierInfoFormat.amount(supplier.currentBalance),
            valueColor: AppColors.amount(supplier.currentBalance),
          ),
          InfoRow(
            icon: Icons.payment_outlined,
            label: 'supplier_profile.view_label_payment_type'.tr,
            value: SupplierInfoFormat.paymentType(supplier.paymentType),
          ),
          InfoRow(
            icon: Icons.info_outline,
            label: 'supplier_profile.view_label_balance_status'.tr,
            value: SupplierInfoFormat.orNa(supplier.balanceStatus),
            valueColor:
                SupplierInfoFormat.balanceStatusColor(supplier.paymentType),
          ),
          InfoRow(
            icon: Icons.category_outlined,
            label: 'supplier_profile.view_label_product_categories'.tr,
            value: SupplierInfoFormat.orNa(supplier.productCategories),
          ),
        ],
      ),
    );
  }
}

/// The supplier's address.
class SupplierAddressSection extends StatelessWidget {
  const SupplierAddressSection({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.view_address_title'.tr,
      icon: Icons.location_on_outlined,
      child: InfoRow(
        icon: Icons.place_outlined,
        label: 'supplier_profile.label_address'.tr,
        value: SupplierInfoFormat.orNotProvided(supplier.address),
      ),
    );
  }
}

/// KYC entries, or a single "Not provided" row when there are none.
class SupplierKycSection extends StatelessWidget {
  const SupplierKycSection({super.key, required this.entries});

  final List<SupplierKyc> entries;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'supplier_profile.view_kyc_title'.tr,
      icon: Icons.verified_user_outlined,
      child: InfoGrid(
        children: entries.isEmpty
            ? [
                InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'supplier_profile.view_label_kyc'.tr,
                  value: 'supplier_profile.not_provided'.tr,
                ),
              ]
            : [
                for (final entry in entries)
                  InfoRow(
                    icon: Icons.badge_outlined,
                    label: entry.key.trim().isEmpty
                        ? 'supplier_profile.view_label_kyc'.tr
                        : entry.key,
                    value: SupplierInfoFormat.orNotProvided(entry.value),
                  ),
              ],
      ),
    );
  }
}
