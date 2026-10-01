import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import 'supplier_form.dart';

/// Opens the add-supplier form in a dialog. Resolves to the create result
/// map (`{'status': 'success', 'name', 'phone', 'response'}`) or `null` when
/// closed. With [showCreateAnother] the form also offers "create another",
/// which saves and keeps the dialog open.
Future<dynamic> showAddSupplierDialog(
  BuildContext context, {
  bool showCreateAnother = true,
}) {
  // Clear any focused field behind the dialog to avoid multiple cursors.
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<dynamic>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) =>
        AddSupplierDialog(showCreateAnother: showCreateAnother),
  );
}

/// The add-supplier dialog: [SupplierForm.create] in an [AppDialog].
class AddSupplierDialog extends StatelessWidget {
  const AddSupplierDialog({super.key, this.showCreateAnother = true});

  final bool showCreateAnother;

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
            title: 'add_supplier.title'.tr,
            subtitle: 'add_supplier.subtitle'.tr,
            maxWidth: screen.width > 700 ? 720 : double.infinity,
            child: SupplierForm.create(
              autofocus: true,
              showCreateAnother: showCreateAnother,
              onCancel: () => Navigator.of(context).pop(),
              onCreated: (result) => Navigator.of(context).pop(result),
            ),
          ),
        ),
      ),
    );
  }
}
