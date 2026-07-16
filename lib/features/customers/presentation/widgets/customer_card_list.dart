import 'package:flutter/material.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerCardList extends StatelessWidget {
  const CustomerCardList({
    super.key,
    required this.customers,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onViewCustomer,
  });

  final List<CustomerListModelData>? customers;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<CustomerListModelData> onViewCustomer;

  Widget _customerTypeBadge(String? type) {
    final value = (type ?? 'B2C').toUpperCase();
    final isB2B = value == 'B2B';
    final background = isB2B ? Colors.green.shade50 : Colors.blue.shade50;
    final foreground = isB2B ? Colors.green.shade700 : Colors.blue.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withValues(alpha: 0.3)),
      ),
      child: Text(
        value,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.18,
          foreground,
        ),
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ColorManager.kGreyColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.1,
                  ColorManager.kGreyColor,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.1,
                  valueColor ?? ColorManager.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customerCard({
    required int displayNumber,
    required CustomerListModelData customer,
  }) {
    final balance = customer.balance ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  customer.name != null && customer.name!.isNotEmpty
                      ? customer.name![0].toUpperCase()
                      : '#',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.2,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unnamed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.kTitleTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$displayNumber',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.1,
                        ColorManager.kGreyColor,
                      ),
                    ),
                  ],
                ),
              ),
              _customerTypeBadge(customer.customerType),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Balance',
                  value: balance.toStringAsFixed(2),
                  valueColor:
                      balance >= 0 ? ColorManager.kSuccessColor : Colors.red,
                ),
              ),
              Expanded(
                child: _metric(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: customer.phone ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onViewCustomer(customer),
              icon: const Icon(
                Icons.visibility,
                size: 18,
                color: ColorManager.kPrimaryColor,
              ),
              label: Text(
                'View Profile',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.2,
                  ColorManager.kPrimaryColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      height: 300,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 60,
            color: ColorManager.kPrimaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No customers found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (customers == null || customers!.isEmpty) {
      return _emptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: customers!.length,
      itemBuilder: (context, index) {
        final customer = customers![index];
        final displayNumber = index + 1 + (currentPage - 1) * itemsPerPage;

        return _customerCard(
          displayNumber: displayNumber,
          customer: customer,
        );
      },
    );
  }
}
