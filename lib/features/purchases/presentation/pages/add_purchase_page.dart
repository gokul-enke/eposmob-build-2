import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:provider/provider.dart';

import '../navigation/purchase_navigation.dart';
import '../state/legacy_purchase_form_controller.dart';
import '../state/purchase_provider.dart';
import '../widgets/legacy_form/legacy_purchase_form_view.dart';

class LegacyAddPurchasePage extends StatefulWidget {
  const LegacyAddPurchasePage({super.key});
  @override
  State<LegacyAddPurchasePage> createState() => _LegacyAddPurchasePageState();
}

class _LegacyAddPurchasePageState extends State<LegacyAddPurchasePage> {
  final formKey = GlobalKey<FormState>();
  late final PurchaseProvider purchases;
  late final AuthModel auth;
  late final CategoryProvider categories;
  late final GridSelectionProvider products;
  late final LegacyPurchaseFormController controller;
  NavigatorState? progressNavigator;
  DialogRoute<void>? progressRoute;
  @override
  void initState() {
    super.initState();
    purchases = context.read<PurchaseProvider>();
    auth = context.read<AuthModel>();
    categories = context.read<CategoryProvider>();
    products = context.read<GridSelectionProvider>();
    controller = LegacyPurchaseFormController(
        readStores: () => purchases.getStoreList,
        readSuppliers: () => purchases.getSupplierList,
        readItems: () => purchases.purchaseItems,
        fetchItems: () => purchases.listAllPurchaseItems(auth.token ?? ''),
        addItem: (
                {required categoryId,
                required productId,
                required quantity,
                required unit,
                required supplierId,
                required storeId,
                required batchNumber}) =>
            purchases.repository.addPurchaseItem(
                categoryId: categoryId,
                productId: productId,
                quantity: quantity,
                unit: unit,
                supplierId: supplierId,
                storeId: storeId,
                batchNumber: batchNumber,
                accessToken: auth.token ?? ''),
        removeItem: (id) => purchases.repository
            .removePurchaseItem(itemId: id, accessToken: auth.token ?? ''),
        finishPurchase: (id) => purchases.repository
            .addPurchase(purchaseId: id, accessToken: auth.token ?? ''),
        onMessage: (message) {
          if (mounted) showScaffold(context: context, message: message);
        },
        onBusy: _busy,
        onBack: () {
          _busy(false);
          if (mounted) PurchaseNavigation.openLegacyList();
        });
    controller.productList = products.getCategoryProductList;
    controller.loadData();
  }

  void _busy(bool busy) {
    if (!busy) {
      final route = progressRoute;
      progressRoute = null;
      if (route?.isActive ?? false) progressNavigator?.removeRoute(route!);
      return;
    }
    if (!mounted || progressRoute != null) return;
    progressNavigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator.adaptive()));
    progressRoute = route;
    progressNavigator!.push(route);
  }

  @override
  void dispose() {
    controller.dispose();
    final route = progressRoute;
    final navigator = progressNavigator;
    progressRoute = null;
    if (route != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) navigator?.removeRoute(route);
      });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context))
      return SafeArea(
          child: Center(child: Text('add_purchase.permission_required'.tr)));
    context.watch<PurchaseProvider>();
    context.watch<CategoryProvider>();
    context.watch<GridSelectionProvider>();
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LegacyPurchaseFormView(
            controller: controller,
            formKey: formKey,
            categoryList: categories.category,
            unitList: purchases.getUnitList,
            onBack: PurchaseNavigation.openLegacyList,
            selectCategory: (category, index) async {
              categories.selectCategory(index, category.categoryName ?? '',
                  category.productsCount ?? 0);
              products.updateCategory(category.categoryId ?? 0);
              final list = products.selectedProductsUpOnCategory;
              await categories.setParentCategory('${category.categoryId ?? 0}');
              return list;
            }));
  }
}
