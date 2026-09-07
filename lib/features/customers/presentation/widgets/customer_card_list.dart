import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'customer_ui.dart';

class CustomerCardList extends StatelessWidget {
  const CustomerCardList({
    super.key,
    required this.customers,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onViewCustomer,
    this.onRefresh,
  });

  final List<CustomerListModelData>? customers;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<CustomerListModelData> onViewCustomer;
  final Future<void> Function()? onRefresh;

  Widget _customerCard({
    required int displayNumber,
    required CustomerListModelData customer,
  }) {
    final balance = customer.balance ?? 0;
    final customerName = CustomerDisplay.name(customer.name);

    return CustomerSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomerAvatar(name: customer.name, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CustomerUiColors.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#$displayNumber',
                      style: const TextStyle(
                        color: CustomerUiColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CustomerTypeBadge(type: customer.customerType),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CustomerUiColors.canvas,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomerMetric(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'customers.balance'.tr,
                    value: balance.toStringAsFixed(2),
                    valueColor: balance >= 0
                        ? CustomerUiColors.green
                        : CustomerUiColors.red,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: CustomerUiColors.border,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomerMetric(
                    icon: Icons.phone_outlined,
                    label: 'customers.phone'.tr,
                    value: customer.phone?.isNotEmpty == true
                        ? customer.phone!
                        : 'customers.not_provided'.tr,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onViewCustomer(customer),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: Text('customers.view_profile'.tr),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: ColorManager.kPrimaryColor,
                side: const BorderSide(color: CustomerUiColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount:
          customers == null || customers!.isEmpty ? 1 : customers!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (customers == null || customers!.isEmpty) {
          return const SizedBox(height: 310, child: CustomerEmptyState());
        }

        final customer = customers![index];
        final displayNumber = index + 1 + (currentPage - 1) * itemsPerPage;
        return _customerCard(
          displayNumber: displayNumber,
          customer: customer,
        );
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
