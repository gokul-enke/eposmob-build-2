import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/suppliers/presentation/widgets/form/supplier_form_host.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:provider/provider.dart';

import '../navigation/purchase_navigation.dart';
import '../state/purchase_order_form_controller.dart';
import '../state/purchase_order_form_ports.dart';
import '../state/purchase_provider.dart';
import '../widgets/form/purchase_order_form_view.dart';

class CreatePurchaseOrderPage extends StatefulWidget {
  const CreatePurchaseOrderPage({super.key});
  @override
  State<CreatePurchaseOrderPage> createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  final formKey = GlobalKey<FormState>();
  late final PurchaseOrderFormController controller;
  @override
  void initState() {
    super.initState();
    final purchases = context.read<PurchaseProvider>();
    final auth = context.read<AuthModel>();
    final products = context.read<LocalProductProvider>();
    final categories = context.read<CategoryProvider>();
    final master = context.read<MasterDataProvider>();
    final stores = context.read<StoreSessionProvider>();
    final stock = context.read<StockProvider>();
    final settings = context.read<AppSettingsProvider>();
    controller = PurchaseOrderFormController(
        ports: PurchaseOrderFormPorts(
      purchases: PurchaseFormPurchasePort(
          readStores: () => purchases.getStoreList,
          readSuppliers: () => purchases.getSupplierList,
          readUnits: () => purchases.getUnitList,
          readRacks: () => purchases.getMasterDataValues,
          readDetails: () => purchases.activePurchaseOrderDetails,
          writeDetails: (value) => purchases.activePurchaseOrderDetails = value,
          listAllStores: purchases.listAllStores,
          listAllSuppliers: purchases.listAllSuppliers,
          createPurchaseOrder: purchases.createPurchaseOrder,
          receivePurchaseOrder: purchases.receivePurchaseOrder,
          listPurchaseOrders: purchases.listPurchaseOrders),
      products: PurchaseFormProductsPort(
          read: () => products.products,
          filterProductByBarcode: products.filterProductByBarcode),
      categories: PurchaseFormCategoryPort(() => categories.category),
      masterData: PurchaseFormMasterDataPort(
          read: () => master.paymentMethods,
          fetchPaymentMethods: master.fetchPaymentMethods),
      stores: PurchaseFormStorePort(() {
        final active = stores.activeStore;
        return active == null
            ? null
            : GetStoreModelData(id: active.storeId, name: active.storeName);
      }),
      auth: PurchaseFormAuthPort(() => auth.token),
      stock: PurchaseFormStockPort(stock.calculateTaxAPI),
      currency: () {
        final value = settings.appSettings?.currency.trim();
        return value == null || value.isEmpty ? 'SAR' : value;
      },
      validate: () => formKey.currentState?.validate() ?? false,
      pickProduct: (barcode) async {
        if (!mounted) return null;
        return showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AddProductWithBarcodeModal(barcode: barcode));
      },
      pickSupplier: () async {
        if (!mounted) return null;
        return showAddSupplierDialog(context, showCreateAnother: false);
      },
      onError: (message) {
        if (mounted) showScaffoldError(context: context, message: message);
      },
      onSuccess: (message) {
        if (mounted) showScaffold(context: context, message: message);
      },
      onComplete: () {
        if (mounted) PurchaseNavigation.openList();
      },
    ));
    controller.initialize();
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
          child: Center(
              child: Text('purchase_order.permission_required_create'.tr)));
    context.watch<PurchaseProvider>();
    context.watch<LocalProductProvider>();
    context.watch<CategoryProvider>();
    context.watch<AppSettingsProvider>();
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PurchaseOrderFormView(
                context: context,
                controller: controller,
                formKey: formKey,
                onBack: PurchaseNavigation.openList)
            .build());
  }
}
