import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../../domain/models/customer_list.dart';
import '../../customer_avatar.dart';
import '../../customer_labels.dart';
import 'customer_info_format.dart';

/// Name, type and status of the customer at the top of the info tab.
class CustomerInfoHeader extends StatelessWidget {
  const CustomerInfoHeader({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CustomerAvatar(name: customer.name, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              CustomerLabels.name(customer.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CustomerTypeBadge(type: customer.customerType),
          const SizedBox(width: AppSpacing.xs),
          AppBadge(
            label: 'customer_profile.view_label_active'.tr,
            tone: AppBadgeTone.success,
          ),
        ],
      ),
    );
  }
}

/// Email and phone numbers.
class CustomerContactSection extends StatelessWidget {
  const CustomerContactSection({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customer_profile.view_section_contact'.tr,
      icon: Icons.contact_phone_outlined,
      child: InfoGrid(
        children: [
          InfoRow(
            icon: Icons.email_outlined,
            label: 'customer_profile.view_label_email'.tr,
            value: CustomerInfoFormat.orNotProvided(customer.email),
          ),
          InfoRow(
            icon: Icons.phone_outlined,
            label: 'customer_profile.view_label_phone'.tr,
            value: CustomerInfoFormat.orNotProvided(customer.phone),
          ),
          InfoRow(
            icon: Icons.phone_android_outlined,
            label: 'customer_profile.view_label_alt_phone'.tr,
            value: CustomerInfoFormat.orNotProvided(customer.altPhone),
          ),
        ],
      ),
    );
  }
}

/// Balance, payment type, points and personal details.
class CustomerAccountSection extends StatelessWidget {
  const CustomerAccountSection({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customer_profile.view_section_account'.tr,
      icon: Icons.account_circle_outlined,
      child: InfoGrid(
        children: [
          InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'customer_profile.view_label_balance'.tr,
            value: CustomerInfoFormat.amount(customer.balance),
            valueColor: AppColors.amount(customer.balance ?? 0),
          ),
          InfoRow(
            icon: Icons.payment_outlined,
            label: 'customer_profile.view_label_payment_type'.tr,
            value: CustomerInfoFormat.paymentType(customer.paymentType),
            valueColor: CustomerInfoFormat.paymentTypeColor(
              customer.paymentType,
            ),
          ),
          InfoRow(
            icon: Icons.credit_score_outlined,
            label: 'customer_profile.view_label_loyalty_points'.tr,
            value: '${customer.loyaltyPoints ?? 0}',
            valueColor: AppColors.green,
          ),
          InfoRow(
            icon: Icons.person_outline,
            label: 'customer_profile.view_label_gender'.tr,
            value: CustomerInfoFormat.gender(customer.gender),
          ),
          InfoRow(
            icon: Icons.cake_outlined,
            label: 'customer_profile.view_label_dob'.tr,
            value: CustomerInfoFormat.orNotProvided(customer.dob),
          ),
          InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'customer_profile.view_label_member_since'.tr,
            value: CustomerInfoFormat.memberSince(customer.createdAt),
          ),
          InfoRow(
            icon: Icons.shopping_bag_outlined,
            label: 'customer_profile.view_label_total_orders'.tr,
            value: '${customer.orders?.length ?? 0}',
          ),
        ],
      ),
    );
  }
}

/// KYC documents with their expiry dates.
class CustomerKycSection extends StatelessWidget {
  const CustomerKycSection({super.key, required this.documents});

  final List<Kyc> documents;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customer_profile.view_section_kyc'.tr,
      icon: Icons.verified_user_outlined,
      child: InfoGrid(
        children: [
          for (final kyc in documents)
            InfoRow(
              icon: Icons.document_scanner_outlined,
              label: kyc.key?.trim().isNotEmpty == true
                  ? kyc.key!
                  : 'customer_profile.view_label_document'.tr,
              value: CustomerInfoFormat.orNotProvided(kyc.value),
              trailing: kyc.expiryDate?.trim().isNotEmpty == true
                  ? Text(
                      '${'customer_profile.view_label_expires'.tr}: '
                      '${kyc.expiryDate}',
                      style: AppTextStyles.sectionHint,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Store name and company id.
class CustomerStoreSection extends StatelessWidget {
  const CustomerStoreSection({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'customer_profile.view_section_store'.tr,
      icon: Icons.store_outlined,
      child: InfoGrid(
        children: [
          InfoRow(
            icon: Icons.business_outlined,
            label: 'customer_profile.view_label_store_name'.tr,
            value: CustomerInfoFormat.orNotAvailable(customer.storeName),
          ),
          if (customer.companyId != null)
            InfoRow(
              icon: Icons.corporate_fare_outlined,
              label: 'customer_profile.view_label_company_id'.tr,
              value: '${customer.companyId}',
            ),
        ],
      ),
    );
  }
}

/// Loyalty card fields that are set, or a "no loyalty information" note.
class CustomerLoyaltyCardSection extends StatelessWidget {
  const CustomerLoyaltyCardSection({super.key, required this.customer});

  final CustomerListModelData customer;

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final rows = <Widget>[
      if (_has(c.cardNumber))
        InfoRow(
          icon: Icons.credit_card,
          label: 'customer_profile.view_label_card_number'.tr,
          value: c.cardNumber!,
        ),
      if (_has(c.membershipName))
        InfoRow(
          icon: Icons.star_outline,
          label: 'customer_profile.view_label_membership'.tr,
          value: c.membershipName!,
        ),
      if (_has(c.membershipCode))
        InfoRow(
          icon: Icons.qr_code,
          label: 'customer_profile.view_label_membership_code'.tr,
          value: c.membershipCode!,
        ),
      if (_has(c.validFrom))
        InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'customer_profile.view_label_valid_from'.tr,
          value: c.validFrom!,
        ),
      if (_has(c.validUntil))
        InfoRow(
          icon: Icons.event_busy_outlined,
          label: 'customer_profile.view_label_valid_until'.tr,
          value: c.validUntil!,
        ),
      if (_has(c.cardStatus))
        InfoRow(
          icon: Icons.info_outline,
          label: 'customer_profile.view_label_card_status'.tr,
          value: c.cardStatus!,
          valueColor: c.cardStatus!.trim().toLowerCase() == 'active'
              ? AppColors.green
              : AppColors.muted,
        ),
      if (c.minRedeemablePoints != null)
        InfoRow(
          icon: Icons.redeem,
          label: 'customer_profile.view_label_min_redeemable'.tr,
          value: '${c.minRedeemablePoints}',
        ),
      if (c.pricePerPoint != null)
        InfoRow(
          icon: Icons.payments_outlined,
          label: 'customer_profile.view_label_price_per_point'.tr,
          value: CustomerInfoFormat.amount(c.pricePerPoint),
        ),
    ];

    return SectionCard(
      title: 'customer_profile.view_section_loyalty'.tr,
      icon: Icons.card_giftcard_outlined,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'customer_profile.view_msg_no_loyalty_info'.tr,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
            )
          : InfoGrid(children: rows),
    );
  }
}
