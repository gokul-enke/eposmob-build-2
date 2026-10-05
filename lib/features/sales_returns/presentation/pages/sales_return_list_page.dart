import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_detail_modal.dart';
import 'package:pos_machine/features/sales_returns/presentation/printing/sales_return_print_items.dart';
import 'package:pos_machine/helpers/return_print_identity.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:provider/provider.dart';

import '../../data/sales_return_repository.dart';
import '../../domain/models/list_sales_return.dart';
import '../state/sales_return_list_controller.dart';
import '../widgets/list/sales_return_list_view.dart';

class SalesReturnListPage extends StatefulWidget {
  const SalesReturnListPage({super.key, this.repository});
  final SalesReturnRepository? repository;
  @override
  State<SalesReturnListPage> createState() => _SalesReturnListPageState();
}

class _SalesReturnListPageState extends State<SalesReturnListPage> {
  late final SalesReturnListController controller;
  late final AppSettingsProvider settings;
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthModel>();
    final sales = context.read<SalesProvider>();
    final repository = widget.repository ?? sales.salesReturns.repository;
    settings = context.read<AppSettingsProvider>();
    controller = SalesReturnListController(
        fetch: (page) => repository.fetchPage(auth.token ?? '', page: page),
        onError: (error) {
          if (!mounted) return;
          showScaffoldError(
              context: context,
              message: error is Exception
                  ? error.toString().replaceFirst('Exception: ', '')
                  : 'sales_return.err_load'.tr);
        });
    controller.load();
  }

  void _copy(SalesReturnOrder order) {
    Clipboard.setData(ClipboardData(text: order.displayNumber));
    showScaffold(
        context: context,
        message: order.receiptNumber != null
            ? 'sales_return.bill_copy_success'.tr
            : 'sales_return.copy_success'.tr);
  }

  void _view(SalesReturnOrder order) => showDialog(
      context: context, builder: (_) => SalesReturnDetailModal(order: order));

  void _print(SalesReturnOrder order) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReturnBillPrintPage(
              returnItems:
                  buildTransactionReturnPrintItems(order.items, const []),
              returnTotalAmount: order.totalAmount,
              orderDate: ReturnPrintIdentity.fromTransaction(order).date,
              orderNumber: ReturnPrintIdentity.fromTransaction(order).number,
              originalInvoiceNumber: order.order?.orderNumber,
              originalInvoiceDate: order.order?.orderDate,
              customerName: order.order?.customer?.user?.name)));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, settings]),
      builder: (context, _) => SalesReturnListSections(
              context: context,
              controller: controller,
              currency: settings.appSettings?.currency ?? 'INR',
              onCopy: _copy,
              onView: _view,
              onPrint: _print)
          .build());
}
