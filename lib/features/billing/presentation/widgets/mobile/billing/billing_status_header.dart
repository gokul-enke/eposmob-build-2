import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/live_time_display.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/open_cash_drawer_button.dart';
import 'package:pos_machine/widgets/sync_button.dart';

/// Compact billing chrome for mobile: connectivity, order context, sync, clock.
class BillingStatusHeader extends StatelessWidget {
  const BillingStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final localProvider = context.watch<LocalProductProvider>();
    final billingProvider = context.watch<BillingProvider>();
    final customerSelection = context.watch<CustomerSelectionProvider>();
    final appSettings =
        context.watch<AppSettingsProvider>().appSettings;
    final showCustomerType = appSettings?.companyB2BEnabled ?? false;

    final currentOrder = localProvider.currentOrder;
    final isEditingOrder = currentOrder != null;
    final orderLabel = isEditingOrder
        ? '#${currentOrder.orderNumber}'
        : 'New order';
    final customerType = customerSelection.selectedCustomer?.customerType;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _ConnectivityChip(hasInternet: billingProvider.hasInternet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEditingOrder ? 'Edit $orderLabel' : orderLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (showCustomerType &&
              customerType != null &&
              customerType.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _CustomerTypeBadge(customerType: customerType),
            ),
          const LiveTimeDisplay(),
          const SizedBox(width: 4),
          const SyncButton(showTooltip: true, showText: false),
          OpenCashDrawerButton(
            color: Colors.grey.shade600,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class _ConnectivityChip extends StatelessWidget {
  const _ConnectivityChip({required this.hasInternet});

  final bool hasInternet;

  @override
  Widget build(BuildContext context) {
    final color = hasInternet ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasInternet ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            hasInternet ? 'Online' : 'Offline',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerTypeBadge extends StatelessWidget {
  const _CustomerTypeBadge({required this.customerType});

  final String customerType;

  @override
  Widget build(BuildContext context) {
    final normalized = customerType.trim().toUpperCase();
    final isB2B = normalized == 'B2B';
    final color = isB2B ? Colors.green.shade700 : Colors.blue.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
