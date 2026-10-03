import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../domain/models/supplier.dart';
import 'supplier_form_values.dart';
import 'supplier_provider.dart';

export 'supplier_form_values.dart';

/// State of the supplier form, for creating a supplier or editing one.
///
/// Create mode sends the same payload as the old add-supplier dialog; edit
/// mode the same as the old profile edit form (every field, other KYC
/// entries kept).
class SupplierFormController extends ChangeNotifier {
  SupplierFormController.create({required this.provider, this.accessToken})
      : original = null {
    balance.text = '0.00';
  }

  SupplierFormController.edit(
    Supplier supplier, {
    required this.provider,
    this.accessToken,
  }) : original = supplier {
    name.text = supplier.name;
    email.text = supplier.email;
    phone.text = supplier.phone;
    altPhone.text = supplier.altPhone ?? '';
    address.text = supplier.address;
    taxNumber.text = supplier.taxNumber ?? '';
    crNumber.text = supplierKycValue(supplier, SupplierKycKeys.crNumber);
    vatNumber.text = supplierKycValue(supplier, SupplierKycKeys.vatNumber);
    // Shown unsigned; the sign comes from the payment type.
    balance.text = supplier.balance.abs().toStringAsFixed(2);
    paymentType = SupplierPaymentType.parse(supplier.paymentType);
  }

  /// Sends the create / update requests (and refreshes the directory).
  final SupplierProvider provider;
  final String? accessToken;

  /// The supplier being edited; `null` in create mode.
  final Supplier? original;

  bool get isEdit => original != null;

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final altPhone = TextEditingController();
  final address = TextEditingController();
  final taxNumber = TextEditingController();
  final crNumber = TextEditingController();
  final vatNumber = TextEditingController();
  final balance = TextEditingController();

  SupplierPaymentType paymentType = SupplierPaymentType.toPay;

  bool _busy = false;
  bool get busy => _busy;

  bool _disposed = false;

  List<TextEditingController> get _fields => [
        name,
        email,
        phone,
        altPhone,
        address,
        taxNumber,
        crNumber,
        vatNumber,
        balance,
      ];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setPaymentType(SupplierPaymentType value) {
    paymentType = value;
    _notify();
  }

  // ------------------------------------------------------------- validation

  static final _email =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return isEdit
          ? 'add_supplier.error_name_required'.tr
          : 'add_supplier.validator_required'.tr;
    }
    return null;
  }

  /// Optional; checked when creating only (as before), so a stored email in
  /// an unusual format does not block editing.
  String? validateEmail(String? value) {
    if (isEdit || value == null || value.isEmpty) return null;
    return _email.hasMatch(value)
        ? null
        : 'add_supplier.validator_email_invalid'.tr;
  }

  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'add_supplier.error_phone_required'.tr;
    }
    if (!isEdit && value.replaceAll('-', '').length < 10) {
      return 'add_supplier.validator_phone_invalid'.tr;
    }
    return null;
  }

  String? validateBalance(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null) return 'supplier_profile.edit_val_invalid_balance'.tr;
    if (parsed < 0) return 'supplier_profile.edit_val_negative_balance'.tr;
    return null;
  }

  // --------------------------------------------------------------- payloads

  String get createdPhone => phone.text.replaceAll('-', '');

  /// CR and VAT entries when filled. Edit mode keeps the supplier's other
  /// KYC entries.
  List<SupplierKyc> buildKyc() => [
        if (crNumber.text.trim().isNotEmpty)
          SupplierKyc(
            key: SupplierKycKeys.crNumber,
            value: crNumber.text.trim(),
          ),
        if (vatNumber.text.trim().isNotEmpty)
          SupplierKyc(
            key: SupplierKycKeys.vatNumber,
            value: vatNumber.text.trim(),
          ),
        ...?original?.kyc.where(
          (entry) => !SupplierKycKeys.edited.contains(entry.key.toUpperCase()),
        ),
      ];

  static String? _nullIfEmpty(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }

  // ----------------------------------------------------------------- submit

  /// Saves the form. Call only after the [Form] validated.
  Future<SupplierFormOutcome> submit() async {
    if (_busy) return const SupplierFormFailed('');
    if (name.text.trim().isEmpty) {
      return SupplierFormFailed('add_supplier.error_name_required'.tr);
    }
    if (phone.text.trim().isEmpty) {
      return SupplierFormFailed('add_supplier.error_phone_required'.tr);
    }
    _setBusy(true);
    try {
      return isEdit ? await _update() : await _create();
    } finally {
      _setBusy(false);
    }
  }

  Future<SupplierFormOutcome> _create() async {
    final nameValue = name.text;
    final phoneValue = createdPhone;
    try {
      final response = await provider.addSupplier(
        name: nameValue.trim(),
        email: email.text.trim(),
        phone: phoneValue,
        accessToken: accessToken ?? '',
        balance: balance.text.trim(),
        paymentStatus: paymentType.apiValue,
        address: address.text.trim(),
        altPhone: altPhone.text.replaceAll('-', ''),
        taxNumber: taxNumber.text.trim(),
        kyc: buildKyc(),
      );
      if (response['status'] == 'success') {
        return SupplierCreated(
          message: '${response['message']}',
          result: {
            'status': 'success',
            'name': nameValue,
            'phone': phoneValue,
            'response': Map<String, dynamic>.from(response),
          },
        );
      }
      return SupplierFormFailed(_createErrorMessage(response));
    } catch (error) {
      debugPrint('[SupplierFormController] create failed: $error');
      return SupplierFormFailed(
        'add_supplier.error_adding_supplier'.trParams({'error': '$error'}),
      );
    }
  }

  static String _createErrorMessage(Map<String, dynamic> response) {
    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return errors.values
          .map((error) => error is List ? error.join(', ') : error.toString())
          .join('\n');
    }
    return response['message']?.toString() ?? 'add_supplier.error_unknown'.tr;
  }

  Future<SupplierFormOutcome> _update() async {
    try {
      final response = await provider.updateSupplier(
        id: original!.id,
        name: name.text.trim(),
        phone: phone.text.trim(),
        accessToken: accessToken ?? '',
        balance: double.tryParse(balance.text.trim()) ?? 0.0,
        email: _nullIfEmpty(email.text),
        address: _nullIfEmpty(address.text),
        altPhone: _nullIfEmpty(altPhone.text),
        taxNumber: taxNumber.text.trim(),
        kyc: buildKyc(),
        paymentStatus: paymentType.apiValue,
      );
      if (response['status']?.toString().toLowerCase() == 'success') {
        return SupplierUpdated(message: 'supplier_profile.edit_msg_success'.tr);
      }
      return SupplierFormFailed(
        response['message']?.toString() ??
            'supplier_profile.edit_msg_failed'.tr,
      );
    } catch (error) {
      debugPrint('[SupplierFormController] update failed: $error');
      return SupplierFormFailed('supplier_profile.edit_msg_failed'.tr);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    _notify();
  }

  /// Create mode: empties the form for "create another".
  void clear() {
    for (final controller in _fields) {
      controller.clear();
    }
    balance.text = '0.00';
    paymentType = SupplierPaymentType.toPay;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final controller in _fields) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// The value of [supplier]'s KYC entry [key] (any case), falling back to
/// the legacy `cr_number` / `vat_number` fields.
String supplierKycValue(Supplier supplier, String key) {
  for (final entry in supplier.kyc) {
    if (entry.key.toUpperCase() == key.toUpperCase()) return entry.value;
  }
  return switch (key) {
    SupplierKycKeys.crNumber => supplier.crNumber ?? '',
    SupplierKycKeys.vatNumber => supplier.vatNumber ?? '',
    _ => '',
  };
}
