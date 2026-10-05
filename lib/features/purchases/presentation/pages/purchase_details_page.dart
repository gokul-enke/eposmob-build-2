import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:provider/provider.dart';

import '../state/purchase_provider.dart';
import '../widgets/details/purchase_details_view.dart';

class PurchaseDetailsPage extends StatelessWidget {
  const PurchaseDetailsPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context)) {
      return SafeArea(
          child: Center(
              child: Text('purchase.permission_required_view_details'.tr)));
    }
    final purchase = context.watch<PurchaseProvider>();
    final grid = context.watch<GridSelectionProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<AppSettingsProvider>().appSettings;
    return PurchaseDetailsView(
        purchase: PurchaseDetailsInput(
            activePurchaseOrderDetails: purchase.activePurchaseOrderDetails,
            getVoucherDetails: purchase.getVoucherDetails,
            getlistPurchaseItemView: purchase.getlistPurchaseItemView,
            storeName: purchase.storeName,
            supplierName: purchase.supplierName),
        products: grid.getProducts,
        categories: [
          ...?categories.category,
          ...categories.sellableCategories,
          ...categories.purchasableCategories,
          ...categories.allCategories
        ],
        currency: (settings?.currency.trim().isNotEmpty ?? false)
            ? settings!.currency.trim()
            : 'SAR');
  }
}
