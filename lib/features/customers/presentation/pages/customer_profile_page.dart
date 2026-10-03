import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import '../../domain/models/customer_list.dart';
import '../navigation/customer_navigation.dart';
import '../state/customer_profile_tab.dart';
import '../state/customer_provider.dart';
import '../widgets/address/customer_address_tab.dart';
import '../widgets/profile/customer_chat_tab.dart';
import '../widgets/profile/customer_edit_tab.dart';
import '../widgets/profile/customer_info_tab.dart';
import '../widgets/profile/customer_loyalty_tab.dart';
import '../widgets/profile/customer_orders_tab.dart';
import '../widgets/profile/customer_profile_summary.dart';
import '../widgets/profile/customer_transactions_tab.dart';

/// Profile of the customer selected in [CustomerProvider]: summary, tab
/// navigation and the selected tab's content.
class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  CustomerProfileTab _tab = CustomerProfileTab.info;

  void _select(CustomerProfileTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.select<CustomerProvider, CustomerListModelData?>(
      (provider) => provider.getSelectedCustomer,
    );
    if (customer == null) {
      return Center(
        child: Text(
          'customer_profile.msg_no_customer_selected'.tr,
          style: AppTextStyles.body,
        ),
      );
    }

    final compact =
        MediaQuery.sizeOf(context).width < DetailLayoutBreakpoints.mobileBelow;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: DetailPageScaffold<CustomerProfileTab>(
        title: 'customer_profile.page_title'.tr,
        backLabel: 'customer_profile.btn_all_customers'.tr,
        onBack: CustomerNavigation.openList,
        summary: CustomerProfileSummary(customer: customer),
        tabs: [
          for (final tab in CustomerProfileTab.values)
            DetailTab(
              id: tab,
              label: _label(tab, compact: compact),
              icon: _icon(tab),
            ),
        ],
        selectedTab: _tab,
        onTabSelected: _select,
        content: KeyedSubtree(
          // A different customer or tab gets fresh tab state.
          key: ValueKey('${_tab.name}-${customer.id}'),
          child: _content(customer),
        ),
      ),
    );
  }

  Widget _content(CustomerListModelData customer) => switch (_tab) {
        CustomerProfileTab.info => CustomerInfoTab(
            customer: customer,
            onEdit: () => _select(CustomerProfileTab.edit),
            onViewOrders: () => _select(CustomerProfileTab.orders),
            onMessage: () => _select(CustomerProfileTab.chat),
          ),
        CustomerProfileTab.edit => CustomerEditTab(customer: customer),
        CustomerProfileTab.transactions =>
          CustomerTransactionsTab(customer: customer),
        CustomerProfileTab.orders => CustomerOrdersTab(customer: customer),
        CustomerProfileTab.address => CustomerAddressTab(customer: customer),
        CustomerProfileTab.loyalty => CustomerLoyaltyTab(customer: customer),
        CustomerProfileTab.chat => CustomerChatTab(customer: customer),
      };

  /// Short chip labels on phones, the longer sidebar labels on wide screens.
  static String _label(CustomerProfileTab tab, {required bool compact}) =>
      switch (tab) {
        CustomerProfileTab.info => compact
            ? 'customer_profile.tab_info'.tr
            : 'customer_profile.sidebar_information'.tr,
        CustomerProfileTab.edit => compact
            ? 'customer_profile.tab_edit'.tr
            : 'customer_profile.sidebar_edit_details'.tr,
        CustomerProfileTab.transactions => compact
            ? 'customer_profile.tab_transactions'.tr
            : 'customer_profile.sidebar_transactions'.tr,
        CustomerProfileTab.orders => compact
            ? 'customer_profile.tab_orders'.tr
            : 'customer_profile.sidebar_all_orders'.tr,
        CustomerProfileTab.address => compact
            ? 'customer_profile.tab_address'.tr
            : 'customer_profile.sidebar_customer_address'.tr,
        CustomerProfileTab.loyalty => compact
            ? 'customer_profile.tab_loyalty'.tr
            : 'customer_profile.sidebar_loyalty_card'.tr,
        CustomerProfileTab.chat => compact
            ? 'customer_profile.tab_chat'.tr
            : 'customer_profile.sidebar_chat'.tr,
      };

  static IconData _icon(CustomerProfileTab tab) => switch (tab) {
        CustomerProfileTab.info => Icons.person_outline,
        CustomerProfileTab.edit => Icons.edit_outlined,
        CustomerProfileTab.transactions => Icons.receipt_long_outlined,
        CustomerProfileTab.orders => Icons.shopping_bag_outlined,
        CustomerProfileTab.address => Icons.location_on_outlined,
        CustomerProfileTab.loyalty => Icons.card_membership_outlined,
        CustomerProfileTab.chat => Icons.chat_outlined,
      };
}
