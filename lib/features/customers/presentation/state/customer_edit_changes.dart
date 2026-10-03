import 'package:get/get.dart';

import '../../data/customer_payloads.dart';
import '../../domain/models/customer_list.dart';
import 'customer_form_controller.dart';

/// Edit mode: the fields that differ from the saved customer, plus the
/// customer as it will look after the update succeeds.
class CustomerEditChanges {
  const CustomerEditChanges._(this.fields, this.updatedCustomer);

  /// Only changed fields are non-null.
  final CustomerFields fields;
  final CustomerListModelData updatedCustomer;

  /// `null` when nothing changed.
  static CustomerEditChanges? compute(
    CustomerFormController form,
    CustomerListModelData original,
  ) {
    final paymentType = form.paymentType == CustomerPaymentType.none
        ? null
        : form.paymentType.apiValue;
    final signedBalance = _signedBalance(form.balance.text, form.paymentType);
    final name = '${form.firstName.text} ${form.lastName.text}'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final dob = form.dateOfBirth.text.trim();

    final business = form.businessFieldsEnabled;
    final fields = CustomerFields(
      phone: _changed(original.phone, form.phone.text),
      name: _changed(original.name, name),
      email: _changed(original.email, form.email.text),
      altPhone: _changed(original.altPhone, form.altPhone.text),
      gender: _changed(original.gender, form.gender),
      dob: _changed(original.dob, dob),
      balance: _changedBalance(
        original.balance?.toStringAsFixed(2) ?? '',
        signedBalance ?? '',
      ),
      paymentType: _changed(original.paymentType?.toLowerCase(), paymentType),
      // Hidden business fields are left as they are on the server.
      customerType: business
          ? _changed(original.customerType ?? 'B2C', form.customerType)
          : null,
      crNumber: business
          ? _changed(original.kycValue('CR NUMBER'), form.crNumber.text)
          : null,
      vatNumber: business
          ? _changed(original.kycValue('VAT NUMBER'), form.vatNumber.text)
          : null,
    );
    final hasChanges = [
      fields.phone,
      fields.name,
      fields.email,
      fields.altPhone,
      fields.gender,
      fields.dob,
      fields.balance,
      fields.paymentType,
      fields.customerType,
      fields.crNumber,
      fields.vatNumber,
    ].any((value) => value != null);
    if (!hasChanges) return null;

    final updated = CustomerListModelData(
      id: original.id,
      name: name,
      email: form.email.text,
      phone: form.phone.text,
      altPhone: form.altPhone.text.isNotEmpty
          ? form.altPhone.text
          : original.altPhone,
      gender: form.gender ?? original.gender,
      dob: dob.isNotEmpty ? dob : original.dob,
      profileImage: original.profileImage,
      storeId: original.storeId,
      userId: original.userId,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      deletedAt: original.deletedAt,
      cardNumber: original.cardNumber,
      loyaltyPoints: original.loyaltyPoints,
      validFrom: original.validFrom,
      validUntil: original.validUntil,
      cardStatus: original.cardStatus,
      membershipName: original.membershipName,
      membershipCode: original.membershipCode,
      minRedeemablePoints: original.minRedeemablePoints,
      pricePerPoint: original.pricePerPoint,
      balance: double.tryParse(signedBalance ?? '') ?? original.balance,
      paymentType: paymentType ?? original.paymentType,
      customerType: business ? form.customerType : original.customerType,
      address: original.address,
      pincode: original.pincode,
      city: original.city,
      state: original.state,
      country: original.country,
      district: original.district,
      companyId: original.companyId,
      storeName: original.storeName,
      kyc: original.kyc,
      transactions: original.transactions,
      orders: original.orders,
      addresses: original.addresses,
    );
    return CustomerEditChanges._(fields, updated);
  }

  /// The trimmed [current] value, or `null` when it equals [original].
  static String? _changed(String? original, String? current) {
    final before = (original ?? '').trim();
    final after = (current ?? '').trim();
    return before == after ? null : after;
  }

  static String? _changedBalance(String original, String current) {
    final before = original.trim();
    final after = current.trim();
    final beforeNumber = double.tryParse(before);
    final afterNumber = double.tryParse(after);
    if (beforeNumber != null && afterNumber != null) {
      return beforeNumber == afterNumber ? null : after;
    }
    return before == after ? null : after;
  }

  /// The balance with its sign: negative when the customer has to pay.
  static String? _signedBalance(String text, CustomerPaymentType type) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final amount = parsed.abs();
    return (type == CustomerPaymentType.toPay ? -amount : amount)
        .toStringAsFixed(2);
  }

  /// Message for a failed update response.
  static String errorMessage(dynamic response) {
    final fallback = 'customer_profile.error_update_failed'.tr;
    if (response is! Map) return fallback;
    final message = response['message'];
    if (message is Map) {
      return message.entries
          .map((entry) => entry.value is List
              ? '${entry.key}: ${(entry.value as List).join(', ')}'
              : '${entry.key}: ${entry.value}')
          .join('\n');
    }
    if (message is String) return message;
    final errors = response['errors'];
    if (errors is Map) {
      return errors.entries
          .map((entry) => entry.value is List
              ? '${entry.key}: ${(entry.value as List).join(', ')}'
              : '${entry.key}: ${entry.value}')
          .join('\n');
    }
    return fallback;
  }
}
