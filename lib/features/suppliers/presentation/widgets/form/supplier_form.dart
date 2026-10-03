import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/supplier.dart';
import '../../state/supplier_form_controller.dart';
import '../../state/supplier_provider.dart';
import 'supplier_form_actions.dart';
import 'supplier_form_sections.dart';

/// The one supplier form, for creating (add-supplier dialog) and editing
/// (profile "Edit details").
///
/// Reads the session providers, owns its [SupplierFormController] and
/// reports a successful save through [onCreated] / [onUpdated].
class SupplierForm extends StatefulWidget {
  /// Create mode. [onCreated] receives the map the add-supplier dialog
  /// resolves to. With [showCreateAnother] a "create another" button saves
  /// and empties the form instead of reporting the result.
  const SupplierForm.create({
    super.key,
    this.showCreateAnother = true,
    this.autofocus = false,
    this.onCreated,
    this.onCancel,
  })  : supplier = null,
        onUpdated = null;

  /// Edit mode for [supplier].
  const SupplierForm.edit({
    super.key,
    required Supplier this.supplier,
    this.onUpdated,
  })  : showCreateAnother = false,
        autofocus = false,
        onCreated = null,
        onCancel = null;

  final Supplier? supplier;
  final bool showCreateAnother;
  final bool autofocus;
  final ValueChanged<Map<String, dynamic>>? onCreated;
  final VoidCallback? onUpdated;
  final VoidCallback? onCancel;

  /// Below this width the action buttons stack full-width.
  static const stackActionsBelow = 520.0;

  @override
  State<SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<SupplierForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  late final SupplierFormController _form;

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthModel>().token;
    final provider = context.read<SupplierProvider>();
    final supplier = widget.supplier;
    _form = supplier != null
        ? SupplierFormController.edit(
            supplier,
            provider: provider,
            accessToken: token,
          )
        : SupplierFormController.create(
            provider: provider,
            accessToken: token,
          );
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit({bool createAnother = false}) async {
    if (_form.busy || !(_formKey.currentState?.validate() ?? false)) return;
    final outcome = await _form.submit();
    if (!mounted) return;
    switch (outcome) {
      case SupplierCreated(:final result, :final message):
        AppToast.success(context, message);
        if (createAnother) {
          _form.clear();
          _nameFocus.requestFocus();
        } else {
          widget.onCreated?.call(result);
        }
      case SupplierUpdated(:final message):
        AppToast.success(context, message);
        widget.onUpdated?.call();
      case SupplierFormFailed(:final message):
        if (message.isNotEmpty) AppToast.error(context, message);
    }
  }

  Widget _actions(bool stacked) {
    if (_form.isEdit) {
      return FormActionsBar(
        stacked: stacked,
        busy: _form.busy,
        submitLabel: 'supplier_profile.edit_btn_save'.tr,
        onSubmit: _submit,
      );
    }
    return SupplierCreateActions(
      stacked: stacked,
      busy: _form.busy,
      onCreate: _submit,
      onCreateAnother:
          widget.showCreateAnother ? () => _submit(createAnother: true) : null,
      onClose: widget.onCancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < SupplierForm.stackActionsBelow;
          return Form(
            key: _formKey,
            child: AbsorbPointer(
              absorbing: _form.busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SupplierDetailsSection(form: _form, nameFocus: _nameFocus),
                  const SizedBox(height: AppSpacing.lg),
                  SupplierAddressSection(form: _form),
                  const SizedBox(height: AppSpacing.lg),
                  SupplierKycSection(form: _form),
                  const SizedBox(height: AppSpacing.lg),
                  SupplierBalanceSection(form: _form),
                  const SizedBox(height: AppSpacing.xl),
                  _actions(stacked),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
