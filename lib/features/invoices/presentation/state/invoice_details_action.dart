import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import '../../data/invoice_details_repository.dart';
import '../widgets/invoice_details_dialog.dart';

mixin InvoiceDetailsAction<W extends StatefulWidget> on State<W> {
  InvoiceDetailsRepository get invoiceDetailsRepository =>
      const InvoiceDetailsRepository();

  Future<void> showInvoiceDetails(Invoice invoice) async {
    final String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      showScaffoldError(context: context, message: 'invoice.missing_token'.tr);
      return;
    }

    showLoadingOverlay(context, message: 'invoice.loading_details'.tr);
    try {
      final details = await invoiceDetailsRepository.fetch(
        id: invoice.id,
        accessToken: token,
      );
      hideLoadingOverlay();

      if (!mounted) return;

      if (details == null) {
        showScaffoldError(
            context: context, message: 'invoice.failed_load_details'.tr);
        return;
      }

      showDialog(
        context: context,
        builder: (context) => InvoiceDetailsDialog(details: details),
      );
    } catch (e) {
      hideLoadingOverlay();
      if (!mounted) return;
      showScaffoldError(
          context: context,
          message: 'invoice.error_loading_details'
              .tr
              .replaceAll('@error', e.toString()));
    }
  }
}
