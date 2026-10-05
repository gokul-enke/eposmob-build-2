import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:provider/provider.dart';

import '../state/purchase_provider.dart';
import '../widgets/legacy_details/purchase_voucher_details_view.dart';

class LegacyPurchaseVoucherDetailsPage extends StatelessWidget {
  const LegacyPurchaseVoucherDetailsPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context))
      return SafeArea(
          child: Center(child: Text('view_voucher.permission_required'.tr)));
    final purchases = context.watch<PurchaseProvider>();
    final products = context.watch<GridSelectionProvider>();
    final voucher = purchases.getVoucherDetails;
    return LegacyPurchaseVoucherDetailsView(
        voucherDetails: voucher,
        listPurchaseItems: purchases.getlistPurchaseItemView,
        store:
            purchases.storeName(voucher == null ? 1 : voucher.storeId ?? 1) ??
                '',
        supplier: purchases
                .supplierName(voucher == null ? 1 : voucher.supplierId ?? 1) ??
            '',
        productName: products.productName);
  }
}
