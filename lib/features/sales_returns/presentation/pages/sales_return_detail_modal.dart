import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales_returns/presentation/printing/sales_return_print_items.dart';
import 'package:pos_machine/helpers/return_print_identity.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:provider/provider.dart';

import '../../domain/models/list_sales_return.dart';
import '../state/sales_return_details_controller.dart';
import '../widgets/details/sales_return_detail_view.dart';

class SalesReturnDetailModal extends StatefulWidget {
  const SalesReturnDetailModal({super.key, required this.order});
  final SalesReturnOrder order;
  @override
  State<SalesReturnDetailModal> createState() => _SalesReturnDetailModalState();
}

class _SalesReturnDetailModalState extends State<SalesReturnDetailModal> {
  late final SalesReturnDetailsController controller;
  late final AppSettingsProvider settings;
  @override
  void initState() {
    super.initState();
    final sales = context.read<SalesProvider>();
    final auth = context.read<AuthModel>();
    settings = context.read<AppSettingsProvider>();
    final repository = sales.salesReturns.repository;
    controller = SalesReturnDetailsController(
        fetch: (number) =>
            repository.fetchItems(auth.token ?? '', orderId: number));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.load(widget.order.order?.orderNumber);
    });
  }

  void _print() {
    final order = widget.order;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ReturnBillPrintPage(
                returnItems: buildTransactionReturnPrintItems(
                    order.items, controller.items),
                returnTotalAmount: order.totalAmount,
                orderDate: ReturnPrintIdentity.fromTransaction(order).date,
                orderNumber: ReturnPrintIdentity.fromTransaction(order).number,
                originalInvoiceNumber: order.order?.orderNumber,
                originalInvoiceDate: order.order?.orderDate,
                customerName: order.order?.customer?.user?.name)));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, settings]),
      builder: (context, _) => SalesReturnDetailSections(
          context: context,
          order: widget.order,
          controller: controller,
          currency: settings.appSettings?.currency ?? 'INR',
          onPrint: _print,
          onClose: () => Navigator.of(context).pop()).build());
}
