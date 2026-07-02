import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/live_time_display.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/open_cash_drawer_button.dart';
import 'package:pos_machine/widgets/sync_button.dart';

/// Compact billing chrome for mobile: order context, clock, sync, connectivity.
class BillingStatusHeader extends StatelessWidget {
  const BillingStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final localProvider = context.watch<LocalProductProvider>();
    final billingProvider = context.watch<BillingProvider>();

    final currentOrder = localProvider.currentOrder;
    final isEditingOrder = currentOrder != null;
    final orderLabel = isEditingOrder
        ? 'Edit #${currentOrder.orderNumber}'
        : 'New order';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 2, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              orderLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiveTimeDisplay(fontSize: 13, fontWeight: FontWeight.w600),
              const SizedBox(width: 7),
              Theme(
                data: Theme.of(context).copyWith(
                  visualDensity: VisualDensity.compact,
                  iconButtonTheme: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SyncButton(
                      showTooltip: true,
                      showText: false,
                      size: 24,
                    ),
                    const SizedBox(width: 5),
                    OpenCashDrawerButton(
                      color: Colors.grey.shade600,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child: _ConnectivityIcon(
                          hasInternet: billingProvider.hasInternet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectivityIcon extends StatelessWidget {
  const _ConnectivityIcon({required this.hasInternet});

  final bool hasInternet;

  @override
  Widget build(BuildContext context) {
    final color = hasInternet ? Colors.green : Colors.red;
    return Icon(
      hasInternet ? Icons.wifi : Icons.wifi_off,
      size: 24,
      color: color,
    );
  }
}
