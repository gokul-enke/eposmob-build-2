import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/customer_list.dart';
import 'info/customer_info_sections.dart';
import 'info/customer_quick_actions.dart';
import 'info/customer_recent_transactions_section.dart';

/// Read-only overview of a customer: contact, account, KYC (ZATCA phase 1
/// only), store, loyalty card, recent transactions and quick actions.
class CustomerInfoTab extends StatelessWidget {
  const CustomerInfoTab({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onViewOrders,
    required this.onMessage,
  });

  final CustomerListModelData customer;
  final VoidCallback onEdit;
  final VoidCallback onViewOrders;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final showKyc = context.select<AppSettingsProvider, bool>(
      (settings) => settings.appSettings?.zatcaPhase1Enabled ?? false,
    );
    final currency = context.select<AppSettingsProvider, String>(
      (settings) => settings.appSettings?.currency ?? 'INR',
    );
    final kyc = customer.kyc ?? const <Kyc>[];
    final transactions = customer.transactions ?? const <CustomerTransaction>[];
    final hasStore = customer.storeName?.trim().isNotEmpty == true;

    final sections = <Widget>[
      CustomerInfoHeader(customer: customer),
      CustomerContactSection(customer: customer),
      CustomerAccountSection(customer: customer),
      if (showKyc && kyc.isNotEmpty) CustomerKycSection(documents: kyc),
      if (hasStore) CustomerStoreSection(customer: customer),
      CustomerLoyaltyCardSection(customer: customer),
      if (transactions.isNotEmpty)
        CustomerRecentTransactionsSection(
          transactions: transactions,
          fallbackCurrency: currency,
        ),
      CustomerQuickActions(
        onEdit: onEdit,
        onViewOrders: onViewOrders,
        onMessage: onMessage,
      ),
    ];

    // Only a handful of sections, so they are built eagerly.
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
