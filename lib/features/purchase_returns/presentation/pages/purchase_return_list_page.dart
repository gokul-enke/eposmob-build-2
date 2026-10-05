import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/purchases/presentation/widgets/purchase_orders_responsive.dart';
import '../state/purchase_return_list_controller.dart';
import '../navigation/purchase_return_navigation.dart';
import '../widgets/list/purchase_return_list_view.dart';
import 'purchase_return_details_page.dart';

class PurchaseReturnListPage extends StatefulWidget {
  const PurchaseReturnListPage({super.key});
  @override
  State<PurchaseReturnListPage> createState() => _PurchaseReturnListPageState();
}

class _PurchaseReturnListPageState extends State<PurchaseReturnListPage> {
  late final PurchaseReturnListController controller;
  @override
  void initState() {
    super.initState();
    final purchases = context.read<PurchaseProvider>();
    final auth = context.read<AuthModel>();
    controller = PurchaseReturnListController(
      fetch: (filter, page) => purchases.purchaseReturnProvider.fetchPage(
          accessToken: auth.token ?? '',
          page: page,
          supplierId: filter.supplierId,
          dateFrom: filter.dateFrom,
          dateTo: filter.dateTo),
      fetchSuppliers: () async {
        await purchases.listAllSuppliers(auth.token ?? '', null);
        return List.of(purchases.supplierList);
      },
      fallbackError: 'purchase_return.err_load'.tr,
      onError: (message) {
        if (mounted) showScaffoldError(context: context, message: message);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        controller.update(
            () => controller.showFilters = !purchaseOrdersIsPhone(context));
    });
    controller.initialize(canLoad: auth.token?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PurchaseReturnListView(
            context: context,
            controller: controller,
            currency: currency,
            onCreate: PurchaseReturnNavigation.openCreate,
            onView: (item) => showDialog(
                context: context,
                builder: (_) =>
                    PurchaseReturnDetailsPage(returnData: item))).build());
  }
}
