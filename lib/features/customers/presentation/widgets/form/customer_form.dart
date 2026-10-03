import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/location/location_picker_dialog.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_form_controller.dart';
import '../../state/customer_provider.dart';
import 'customer_form_sections.dart';
import 'customer_location_fields.dart';

/// The one customer form, for creating (add-customer dialog, add-customer
/// page, billing's mobile page) and editing (profile "Edit details").
///
/// Reads the session providers, owns its [CustomerFormController] and
/// reports a successful save through [onCreated] / [onUpdated].
class CustomerForm extends StatefulWidget {
  /// Create mode. [onCreated] receives the map the add-customer dialog
  /// resolves to. With [clearOnCreated] the form empties itself after a save
  /// (add-customer page). Without [cancelLabel] no cancel button is shown.
  const CustomerForm.create({
    super.key,
    this.initialPhone,
    this.initialName,
    this.autofocus = false,
    this.clearOnCreated = false,
    this.onCreated,
    this.onCancel,
    this.submitLabel,
    this.cancelLabel,
  })  : customer = null,
        onUpdated = null;

  /// Edit mode for [customer]; sends only changed fields.
  const CustomerForm.edit({
    super.key,
    required CustomerListModelData this.customer,
    this.onUpdated,
  })  : initialPhone = null,
        initialName = null,
        autofocus = false,
        clearOnCreated = false,
        onCreated = null,
        onCancel = null,
        submitLabel = null,
        cancelLabel = null;

  final CustomerListModelData? customer;
  final String? initialPhone;
  final String? initialName;
  final bool autofocus;
  final bool clearOnCreated;
  final ValueChanged<Map<String, dynamic>>? onCreated;
  final ValueChanged<CustomerListModelData>? onUpdated;
  final VoidCallback? onCancel;
  final String? submitLabel;
  final String? cancelLabel;

  /// Below this width the action buttons stack full-width.
  static const stackActionsBelow = 520.0;

  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameFocus = FocusNode();
  late final CustomerFormController _form;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthModel>().token;
    final repository = context.read<CustomerProvider>().repository;
    final settings = context.read<AppSettingsProvider>().appSettings;
    final customer = widget.customer;
    _form = customer != null
        ? CustomerFormController.edit(
            customer,
            repository: repository,
            accessToken: token,
            businessFieldsEnabled: settings?.zatcaPhase1Enabled ?? false,
          )
        : CustomerFormController.create(
            repository: repository,
            locations: context.read<LocationProvider>(),
            accessToken: token,
            businessFieldsEnabled: settings?.companyB2BEnabled ?? false,
            initialPhone: widget.initialPhone,
            initialName: widget.initialName,
          );
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  /// Create mode: focus, country from login, location from the store.
  Future<void> _prefill() async {
    if (!mounted) return;
    if (widget.autofocus) _firstNameFocus.requestFocus();
    final prefs = context.read<SharedPreferenceProvider>();
    final stores = context.read<PurchaseProvider>().storeList;
    final country = await prefs.getCountryName();
    if (!mounted) return;
    _form.prefillCountry(country);
    final activeStoreId = await prefs.getActiveStoreId();
    if (!mounted) return;
    await _form.location.prefillFromStore(
      stores: stores,
      activeStoreId: activeStoreId,
    );
  }

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_form.dateOfBirth.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ??
          (_isEdit ? now : DateTime(now.year - 18, now.month, now.day)),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) _form.setDateOfBirth(picked);
  }

  Future<void> _pickOnMap() async {
    final result = await showDialog<LocationResult>(
      context: context,
      builder: (_) => const LocationPickerDialog(),
    );
    if (result != null && mounted) await _form.applyPickedLocation(result);
  }

  Future<void> _submit() async {
    if (_form.busy || !(_formKey.currentState?.validate() ?? false)) return;
    final customers = context.read<CustomerProvider>();
    final activeStoreId = _isEdit
        ? null
        : context.read<StoreSessionProvider>().activeStore?.storeId;
    final outcome = await _form.submit(activeStoreId: activeStoreId);
    if (!mounted) return;
    switch (outcome) {
      case CustomerCreated(:final result, :final message):
        customers.refreshAfterMutationInBackground(_form.accessToken ?? '');
        AppToast.success(context, message);
        if (widget.clearOnCreated) _form.clear();
        widget.onCreated?.call(result);
      case CustomerUpdated(:final customer, :final message):
        AppToast.success(context, message);
        customers.selectCustomer(customer);
        widget.onUpdated?.call(customer);
      case CustomerUnchanged():
        AppToast.info(context, 'customer_profile.msg_no_changes'.tr);
      case CustomerFormFailed(:final message):
        if (message.isNotEmpty) {
          AppToast.error(context, message);
        }
    }
  }

  Future<void> _confirmPasswordReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text('customer_profile.dialog_change_password_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'customer_profile.dialog_change_password_content'.tr,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          AppOutlinedButton(
            label: 'general.cancel'.tr,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppPrimaryButton(
            label: 'customer_profile.dialog_send_link'.tr,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AppToast.success(context, 'customer_profile.dialog_password_reset_sent'.tr);
  }

  Widget _actions(bool stacked) {
    if (_isEdit) {
      return FormActionsBar(
        stacked: stacked,
        busy: _form.busy,
        submitLabel: 'customer_profile.btn_save_changes'.tr,
        onSubmit: _submit,
        cancelLabel: 'customer_profile.btn_change_password'.tr,
        onCancel: _confirmPasswordReset,
      );
    }
    return FormActionsBar(
      stacked: stacked,
      busy: _form.busy,
      submitLabel: widget.submitLabel ?? 'add_customer.btn_submit'.tr,
      onSubmit: _submit,
      cancelLabel: widget.cancelLabel,
      onCancel: widget.onCancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < CustomerForm.stackActionsBelow;
          return Form(
            key: _formKey,
            autovalidateMode: _form.showPhoneErrorOnLoad
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: AbsorbPointer(
              absorbing: _form.busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomerDetailsSection(
                    form: _form,
                    firstNameFocus: _firstNameFocus,
                    onPickDateOfBirth: _pickDateOfBirth,
                  ),
                  if (!_isEdit) ...[
                    const SizedBox(height: AppSpacing.lg),
                    CustomerAddressSection(
                      form: _form,
                      onPickOnMap: _pickOnMap,
                    ),
                  ],
                  if (_form.businessFieldsEnabled) ...[
                    const SizedBox(height: AppSpacing.lg),
                    CustomerBusinessSection(form: _form),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  CustomerBalanceSection(form: _form),
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
