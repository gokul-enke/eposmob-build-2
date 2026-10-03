import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/customer_display.dart';
import '../../../domain/models/customer_list.dart';
import 'loyalty/customer_loyalty_card.dart';

/// The customer's loyalty card and points details.
class CustomerLoyaltyTab extends StatelessWidget {
  const CustomerLoyaltyTab({super.key, required this.customer});

  final CustomerListModelData customer;

  static String _orDash(String? value) =>
      value != null && value.trim().isNotEmpty ? value : '--';

  @override
  Widget build(BuildContext context) {
    final currency = context.select<AppSettingsProvider, String>(
      (settings) => settings.appSettings?.currency ?? 'INR',
    );
    final cardNumber = customer.cardNumber?.trim().isNotEmpty == true
        ? customer.cardNumber!
        : 'customer_profile.view_msg_not_available'.tr;
    final pricePerPoint = (customer.pricePerPoint ?? 0).toStringAsFixed(2);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        SectionCard(
          title: 'customer_loyalty.title_program'.tr,
          icon: Icons.card_membership,
          child: CustomerLoyaltyCard(
            holderName: CustomerNames.realName(customer.name) ??
                'customer_loyalty.label_customer_name'.tr,
            cardNumber: cardNumber,
            tierName: customer.membershipName,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'customer_profile.view_section_loyalty'.tr,
          icon: Icons.loyalty_outlined,
          child: InfoGrid(
            children: [
              InfoRow(
                icon: Icons.star_border_purple500_outlined,
                label: 'customer_loyalty.loyalty_points'.tr,
                value: '${customer.loyaltyPoints ?? 0}',
                valueColor: AppColors.green,
              ),
              InfoRow(
                icon: Icons.redeem,
                label: 'customer_loyalty.min_redeemable'.tr,
                value: '${customer.minRedeemablePoints ?? 0}',
              ),
              InfoRow(
                icon: Icons.price_change_outlined,
                label: 'customer_loyalty.price_per_point'.tr,
                value: '$currency$pricePerPoint',
              ),
              InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'customer_loyalty.valid_from'.tr,
                value: _orDash(customer.validFrom),
              ),
              InfoRow(
                icon: Icons.event_busy_outlined,
                label: 'customer_loyalty.valid_until'.tr,
                value: _orDash(customer.validUntil),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
