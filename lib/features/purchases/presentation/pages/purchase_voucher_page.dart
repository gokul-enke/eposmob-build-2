import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../navigation/purchase_navigation.dart';
import '../state/legacy_purchase_list_controller.dart';
import '../state/purchase_provider.dart';
import '../widgets/legacy_list/legacy_purchase_list_actions.dart';
import '../widgets/legacy_list/purchase_voucher_view.dart';

class LegacyPurchaseVoucherListPage extends StatefulWidget {
  const LegacyPurchaseVoucherListPage({super.key});
  @override
  State<LegacyPurchaseVoucherListPage> createState() =>
      _LegacyPurchaseVoucherListPageState();
}

class _LegacyPurchaseVoucherListPageState
    extends State<LegacyPurchaseVoucherListPage> {
  late final PurchaseProvider purchases;
  late final AuthModel auth;
  late final LegacyPurchaseListController controller;
  @override
  void initState() {
    super.initState();
    purchases = context.read<PurchaseProvider>();
    auth = context.read<AuthModel>();
    controller = LegacyPurchaseListController(
        fetchVouchers: ({filterAmount, filterStore, page}) {
      final token = auth.token;
      if (token == null || token.isEmpty) throw StateError('Session expired');
      return purchases.repository.fetchLegacyVouchersPage(
          accessToken: token,
          filterAmount: filterAmount,
          filterStore: filterStore,
          page: page);
    });
    controller.load(1, true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context))
      return SafeArea(
          child:
              Center(child: Text('purchase_voucher.permission_required'.tr)));
    context.watch<PurchaseProvider>();
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LegacyPurchaseVoucherListView(
            controller: controller,
            actions: LegacyPurchaseListActions(
                getStoreList: purchases.getStoreList,
                getSupplierList: purchases.getSupplierList,
                storeName: purchases.storeName,
                supplierName: purchases.supplierName,
                callVoucherDetails: purchases.callVoucherDetails),
            onAddVoucher: () => PurchaseNavigation.openIndex(
                SideBarController.legacyPurchaseVoucherEntryScreenIndex)));
  }
}
