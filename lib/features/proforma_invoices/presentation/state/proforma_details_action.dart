import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:provider/provider.dart';

import '../../data/proforma_details_repository.dart';
import '../../domain/proforma_details.dart';
import '../widgets/proforma_details_dialog.dart';

mixin ProformaRowActions<T extends StatefulWidget> on State<T> {
  Future<void> showProformaDetails(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'];
    if (invoiceId == null) {
      showScaffoldError(
          context: context,
          message: 'proforma_invoice.invoice_id_not_found'.tr);
      return;
    }

    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final response =
          await ProformaDetailsRepository(Provider.of<QuotationsProvider>(
        context,
        listen: false,
      )).fetchDetails(
        accessToken: authProvider.token ?? '',
        invoiceId: invoiceId,
      );
      if (!mounted) return;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _openDetailsDialog(data);
      } else if (data is Map) {
        _openDetailsDialog(Map<String, dynamic>.from(data));
      } else {
        showScaffoldError(
            context: context, message: 'proforma_invoice.details_not_found'.tr);
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
            context: context,
            message: 'proforma_invoice.failed_load_details'.tr);
      }
    }
  }

  void _openDetailsDialog(Map<String, dynamic> data) {
    final details = ProformaDetails.fromMap(data);
    showDialog(
      context: context,
      builder: (_) => ProformaDetailsDialog(details: details),
    );
  }
}
