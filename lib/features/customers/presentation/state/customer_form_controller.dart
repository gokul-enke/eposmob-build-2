import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/core/ui/location/location_picker_dialog.dart';
import 'package:pos_machine/providers/location_provider.dart';

import '../../data/customer_payloads.dart';
import '../../data/customer_repository.dart';
import '../../domain/models/customer_list.dart';
import 'customer_edit_changes.dart';
import 'customer_form_values.dart';
import 'customer_location_selection.dart';

export 'customer_form_values.dart';
export 'customer_location_selection.dart';

/// State of the customer form, for creating a customer or editing one.
///
/// Create mode sends every field (same payload as the old add-customer
/// forms); edit mode sends only the fields that differ from [original].
class CustomerFormController extends ChangeNotifier {
  CustomerFormController.create({
    required this.repository,
    LocationProvider? locations,
    this.accessToken,
    this.businessFieldsEnabled = false,
    String? initialPhone,
    String? initialName,
    Future<int?> Function()? persistedStoreId,
  })  : original = null,
        location = CustomerLocationSelection(
          provider: locations,
          accessToken: accessToken,
        ),
        _persistedStoreId =
            persistedStoreId ?? const TenantSession().activeStoreId {
    balance.text = '0';
    paymentType = CustomerPaymentType.toReceive;
    if (initialPhone != null) {
      phone.text = initialPhone;
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      showPhoneErrorOnLoad = digits.isNotEmpty && digits.length < 10;
    }
    final name = initialName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      firstName.text = parts.first;
      if (parts.length > 1) lastName.text = parts.skip(1).join(' ');
    }
    _listenToLocation();
  }

  CustomerFormController.edit(
    CustomerListModelData customer, {
    required this.repository,
    this.accessToken,
    this.businessFieldsEnabled = false,
  })  : original = customer,
        location = CustomerLocationSelection(),
        _persistedStoreId = const TenantSession().activeStoreId {
    final nameParts = (customer.name ?? '').split(' ');
    firstName.text = nameParts.first;
    lastName.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    email.text = customer.email ?? '';
    phone.text = customer.phone ?? '';
    altPhone.text = customer.altPhone ?? '';
    // Shown unsigned; the sign comes from the payment type.
    balance.text = (customer.balance?.abs() ?? 0.0).toStringAsFixed(2);
    customerType = customer.customerType ?? 'B2C';
    crNumber.text = customer.kycValue('CR NUMBER') ?? '';
    vatNumber.text = customer.kycValue('VAT NUMBER') ?? '';
    gender = customer.gender;
    final dob = customer.dob;
    final parsedDob = dob == null ? null : DateTime.tryParse(dob);
    dateOfBirth.text =
        parsedDob != null ? formatCustomerDate(parsedDob) : (dob ?? '');
    paymentType = CustomerPaymentType.parse(
      customer.paymentType,
      fallback: CustomerPaymentType.toPay,
    );
    _listenToLocation();
  }

  final CustomerRepository repository;
  final String? accessToken;

  /// Shows customer type, CR and VAT number.
  final bool businessFieldsEnabled;

  /// The customer being edited; `null` in create mode.
  final CustomerListModelData? original;
  final CustomerLocationSelection location;
  final Future<int?> Function() _persistedStoreId;

  bool get isEdit => original != null;

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final altPhone = TextEditingController();
  final building = TextEditingController();
  final streetAddress = TextEditingController();
  final country = TextEditingController();
  final dateOfBirth = TextEditingController();
  final balance = TextEditingController();
  final crNumber = TextEditingController();
  final vatNumber = TextEditingController();

  String? gender;
  String customerType = 'B2C';
  CustomerPaymentType paymentType = CustomerPaymentType.none;

  /// Create mode: the prefilled phone is too short, so validate right away.
  bool showPhoneErrorOnLoad = false;

  bool _busy = false;
  bool get busy => _busy;

  bool get isBusinessCustomer => customerType.toUpperCase() == 'B2B';

  bool _disposed = false;

  void _listenToLocation() => location.addListener(_notify);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ----------------------------------------------------------------- inputs

  void setGender(String? value) {
    gender = value;
    _notify();
  }

  void setCustomerType(String value) {
    customerType = value;
    _notify();
  }

  void setPaymentType(CustomerPaymentType value) {
    paymentType = value;
    _notify();
  }

  void setDateOfBirth(DateTime date) {
    dateOfBirth.text = formatCustomerDate(date);
    _notify();
  }

  /// Create mode: fills the country saved at login when the field is empty.
  void prefillCountry(String? savedCountry) {
    final value = savedCountry?.trim() ?? '';
    if (country.text.trim().isEmpty && value.isNotEmpty) {
      country.text = value;
      _notify();
    }
  }

  /// Fills country and street address from a picked map location and
  /// matches state / district / pincode.
  Future<void> applyPickedLocation(LocationResult result) async {
    country.text = result.country;
    streetAddress.text = result.formattedAddress;
    _notify();
    await location.applyPickedLocation(result);
  }

  // ------------------------------------------------------------- validation

  static final _createEmail =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final _editEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  String? validateFirstName(String? value) {
    if (isEdit && (value == null || value.isEmpty)) {
      return 'customer_profile.validator_first_name_required'.tr;
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (isEdit) {
      return _editEmail.hasMatch(value)
          ? null
          : 'customer_profile.validator_email_invalid'.tr;
    }
    return _createEmail.hasMatch(value)
        ? null
        : 'add_customer.err_email_invalid'.tr;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return isEdit
          ? 'customer_profile.validator_phone_required'.tr
          : 'add_customer.err_phone_required'.tr;
    }
    if (!isEdit && value.replaceAll('-', '').length < 10) {
      return 'add_customer.err_phone_invalid'.tr;
    }
    return null;
  }

  String? validateCrNumber(String? value) =>
      !isEdit && isBusinessCustomer && (value == null || value.trim().isEmpty)
          ? 'add_customer.err_cr_required'.tr
          : null;

  String? validateVatNumber(String? value) =>
      !isEdit && isBusinessCustomer && (value == null || value.trim().isEmpty)
          ? 'add_customer.err_vat_required'.tr
          : null;

  String? validateBalance(String? value) {
    if (!isEdit || value == null || value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null) return 'customer_profile.validator_balance_invalid'.tr;
    if (parsed < 0) return 'customer_profile.validator_balance_negative'.tr;
    return null;
  }

  // --------------------------------------------------------------- payloads

  /// Building and street address joined with `, `.
  String get composedAddress => [
        building.text.trim(),
        streetAddress.text.trim()
      ].where((part) => part.isNotEmpty).join(', ');

  String get createdPhone => phone.text.replaceAll('-', '');
  String get createdName => '${firstName.text} ${lastName.text}';

  /// Create-mode payload fields. City is the district id, state the state
  /// id. Without business fields the customer is always B2C.
  CustomerFields buildCreateFields() => CustomerFields(
        phone: createdPhone,
        name: createdName,
        email: email.text,
        address: composedAddress,
        pincode: location.pincodeValue,
        city: location.districtId ?? '',
        state: location.stateId ?? '',
        country: country.text,
        balance: balance.text.trim(),
        paymentType: paymentType.apiValue,
        altPhone: altPhone.text.trim(),
        gender: gender ?? '',
        dob: dateOfBirth.text.trim(),
        customerType: businessFieldsEnabled ? customerType : 'B2C',
        crNumber: businessFieldsEnabled ? crNumber.text.trim() : '',
        vatNumber: businessFieldsEnabled ? vatNumber.text.trim() : '',
      );

  /// Edit mode: the fields that changed, or `null` when nothing did.
  CustomerEditChanges? buildEditChanges() =>
      CustomerEditChanges.compute(this, original!);

  // ----------------------------------------------------------------- submit

  /// Saves the form. Call only after the [Form] validated.
  /// [activeStoreId] is the session's store (create mode); the stored
  /// active store and then `1` are used when it is null.
  Future<CustomerFormOutcome> submit({int? activeStoreId}) async {
    if (_busy) return const CustomerFormFailed('');
    if (isEdit) return _submitEdit();
    if (paymentType == CustomerPaymentType.none) {
      return CustomerFormFailed('customer.select_payment_type'.tr);
    }
    _setBusy(true);
    try {
      final storeId =
          (activeStoreId ?? await _persistedStoreId() ?? 1).toString();
      final phoneValue = createdPhone;
      final nameValue = createdName;
      final value = await repository.create(
        accessToken ?? '',
        buildCreateFields(),
        storeId: storeId,
      );
      if (value is Map && value['status'] == 'success') {
        return CustomerCreated(
          message: '${value['message']}',
          result: {
            'status': 'success',
            'phone': phoneValue,
            'name': nameValue,
            'response': value,
          },
        );
      }
      return CustomerFormFailed(_createErrorMessage(value));
    } catch (error) {
      return CustomerFormFailed('${'add_customer.err_prefix'.tr}$error');
    } finally {
      _setBusy(false);
    }
  }

  static String _createErrorMessage(dynamic value) {
    final errors = value is Map ? value['errors'] : null;
    if (errors is Map && errors.isNotEmpty) {
      return errors.values
          .map((error) => error is List ? error.join(', ') : error.toString())
          .join('\n');
    }
    final message = value is Map ? value['message'] : null;
    return message?.toString() ?? 'add_customer.err_unknown'.tr;
  }

  Future<CustomerFormOutcome> _submitEdit() async {
    final token = accessToken;
    if (token == null) {
      return CustomerFormFailed('customer_profile.error_login_again'.tr);
    }
    final customerId = original!.id;
    final changes = buildEditChanges();
    if (customerId != null && changes == null) return const CustomerUnchanged();
    _setBusy(true);
    try {
      if (customerId == null) throw Exception('Invalid customer ID');
      final response = await repository.update(
        token,
        customerId,
        changes!.fields,
      );
      if (response is Map && response['status'] == 'success') {
        return CustomerUpdated(
          customer: changes.updatedCustomer,
          message: response['message']?.toString() ??
              'customer_profile.updated_successfully'.tr,
        );
      }
      return CustomerFormFailed(CustomerEditChanges.errorMessage(response));
    } catch (error) {
      debugPrint('[CustomerFormController] update failed: $error');
      return CustomerFormFailed('${'general.error_prefix'.tr} $error');
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    _notify();
  }

  /// Create mode: empties the form after a save on the add-customer page.
  void clear() {
    for (final controller in [
      firstName,
      lastName,
      email,
      phone,
      altPhone,
      building,
      streetAddress,
      country,
      dateOfBirth,
      balance,
      crNumber,
      vatNumber,
    ]) {
      controller.clear();
    }
    gender = null;
    customerType = 'B2C';
    paymentType = CustomerPaymentType.toReceive;
    showPhoneErrorOnLoad = false;
    location.clear();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    location.removeListener(_notify);
    location.dispose();
    for (final controller in [
      firstName,
      lastName,
      email,
      phone,
      altPhone,
      building,
      streetAddress,
      country,
      dateOfBirth,
      balance,
      crNumber,
      vatNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}

extension CustomerKycValue on CustomerListModelData {
  /// The value of the KYC entry named [key] (upper case), if any.
  String? kycValue(String key) {
    for (final item in kyc ?? const <Kyc>[]) {
      if ((item.key ?? '').toUpperCase() == key && item.value != null) {
        return item.value;
      }
    }
    return null;
  }
}
