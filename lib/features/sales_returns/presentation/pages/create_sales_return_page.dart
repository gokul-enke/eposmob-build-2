import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:provider/provider.dart';
import '../navigation/sales_return_navigation.dart';
import '../state/sales_return_form_controller.dart';
import '../state/sales_return_form_ports.dart';
import '../widgets/form/sales_return_form_view.dart';

class CreateSalesReturnPage extends StatefulWidget {
  const CreateSalesReturnPage({super.key});
  @override
  State<CreateSalesReturnPage> createState() => _CreateSalesReturnPageState();
}

class _CreateSalesReturnPageState extends State<CreateSalesReturnPage> {
  late final SalesReturnFormController controller;
  late final SalesProvider sales;
  late final AppSettingsProvider settings;
  @override
  void initState() {
    super.initState();
    sales = context.read<SalesProvider>();
    final auth = context.read<AuthModel>();
    settings = context.read<AppSettingsProvider>();
    final repository = sales.salesReturns.repository;
    controller = SalesReturnFormController(SalesReturnFormPorts(
        token: () => auth.token ?? '',
        storeId: const TenantSession().activeStoreId,
        passedNumber: () => sales.getOrderNumber,
        passedId: () => sales.getOrderId,
        clearNavigation: () {
          sales.setOrderNumber('');
          sales.setOrderId('');
        },
        fetchOrders: sales.fetchOrders,
        orders: () => sales.orders,
        currentPage: () => sales.currentPage,
        totalPages: () => sales.totalPages,
        items: (number) =>
            repository.fetchItems(auth.token ?? '', orderId: number),
        details: (number) =>
            sales.listOrderDetails(context, number, auth.token ?? ''),
        submit: repository.api.submit,
        complete: repository.api.complete,
        error: (message) {
          if (mounted) showScaffoldError(context: context, message: message);
        }));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, sales, settings]),
      builder: (context, _) => SalesReturnFormSections(
              context: context,
              controller: controller,
              currency: settings.appSettings?.currency ?? 'INR',
              onBack: SalesReturnNavigation.openList)
          .build());
}
