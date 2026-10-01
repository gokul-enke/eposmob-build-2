import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';

import '../../domain/models/supplier.dart';
import '../navigation/supplier_navigation.dart';
import '../state/supplier_profile_tab.dart';
import '../state/supplier_provider.dart';
import '../widgets/profile/supplier_address_tab.dart';
import '../widgets/profile/supplier_edit_tab.dart';
import '../widgets/profile/supplier_info_tab.dart';
import '../widgets/profile/supplier_orders_tab.dart';
import '../widgets/profile/supplier_profile_summary.dart';
import '../widgets/profile/supplier_transactions_tab.dart';

/// Profile of the supplier selected in [SupplierProvider]: summary, tab
/// navigation and the selected tab's content.
class SupplierProfilePage extends StatefulWidget {
  const SupplierProfilePage({super.key});

  @override
  State<SupplierProfilePage> createState() => _SupplierProfilePageState();
}

class _SupplierProfilePageState extends State<SupplierProfilePage> {
  SupplierProfileTab _tab = SupplierProfileTab.info;

  void _select(SupplierProfileTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final supplier = context.select<SupplierProvider, Supplier?>(
      (provider) => provider.selectedSupplier,
    );
    if (supplier == null) {
      return Center(
        child: Text(
          'supplier_profile.label_no_supplier'.tr,
          style: AppTextStyles.body,
        ),
      );
    }

    final compact =
        MediaQuery.sizeOf(context).width < DetailLayoutBreakpoints.mobileBelow;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: DetailPageScaffold<SupplierProfileTab>(
        title: 'supplier_profile.title'.tr,
        backLabel: 'supplier_profile.btn_all_suppliers'.tr,
        onBack: SupplierNavigation.openList,
        summary: SupplierProfileSummary(supplier: supplier),
        tabs: [
          for (final tab in SupplierProfileTab.values)
            DetailTab(
              id: tab,
              label: _label(tab, compact: compact),
              icon: _icon(tab),
            ),
        ],
        selectedTab: _tab,
        onTabSelected: _select,
        content: KeyedSubtree(
          // A different supplier or tab gets fresh tab state.
          key: ValueKey('${_tab.name}-${supplier.id}'),
          child: _content(supplier),
        ),
      ),
    );
  }

  Widget _content(Supplier supplier) => switch (_tab) {
        SupplierProfileTab.info => SupplierInfoTab(
            supplier: supplier,
            onEdit: () => _select(SupplierProfileTab.edit),
            onViewOrders: () => _select(SupplierProfileTab.orders),
          ),
        SupplierProfileTab.edit => SupplierEditTab(supplier: supplier),
        SupplierProfileTab.transactions =>
          SupplierTransactionsTab(supplier: supplier),
        SupplierProfileTab.orders => SupplierOrdersTab(supplier: supplier),
        SupplierProfileTab.address => SupplierAddressTab(supplier: supplier),
      };

  /// The address tab has a shorter chip label on phones.
  static String _label(SupplierProfileTab tab, {required bool compact}) =>
      switch (tab) {
        SupplierProfileTab.info => 'supplier_profile.tab_information'.tr,
        SupplierProfileTab.edit => 'supplier_profile.tab_edit_details'.tr,
        SupplierProfileTab.transactions =>
          'supplier_profile.tab_transactions'.tr,
        SupplierProfileTab.orders => 'supplier_profile.tab_all_orders'.tr,
        SupplierProfileTab.address => compact
            ? 'supplier_profile.tab_address'.tr
            : 'supplier_profile.tab_supplier_address'.tr,
      };

  static IconData _icon(SupplierProfileTab tab) => switch (tab) {
        SupplierProfileTab.info => Icons.person_outline,
        SupplierProfileTab.edit => Icons.edit_outlined,
        SupplierProfileTab.transactions => Icons.receipt_long_outlined,
        SupplierProfileTab.orders => Icons.shopping_cart_outlined,
        SupplierProfileTab.address => Icons.location_on_outlined,
      };
}
