import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import 'customer_form.dart';

/// Opens the add-customer form in a dialog. Resolves to the create result
/// map (`{'status': 'success', 'phone', 'name', 'response'}`) or `null` when
/// cancelled.
Future<dynamic> showAddCustomerDialog(
  BuildContext context, {
  String? mobileNumber,
  String? customerName,
}) {
  // Clear any focused field behind the dialog to avoid multiple cursors.
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<dynamic>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _AddCustomerDialog(
      mobileNumber: mobileNumber ?? '',
      customerName: customerName,
    ),
  );
}

class _AddCustomerDialog extends StatelessWidget {
  const _AddCustomerDialog({required this.mobileNumber, this.customerName});

  final String mobileNumber;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screen.height * 0.9),
          child: AppDialog(
            title: 'add_customer.title'.tr,
            maxWidth: screen.width > 700 ? 600 : double.infinity,
            child: CustomerForm.create(
              initialPhone: mobileNumber,
              initialName: customerName,
              autofocus: true,
              cancelLabel: 'add_customer.btn_close'.tr,
              onCancel: () => Navigator.of(context).pop(),
              onCreated: (result) => Navigator.of(context).pop(result),
            ),
          ),
        ),
      ),
    );
  }
}
