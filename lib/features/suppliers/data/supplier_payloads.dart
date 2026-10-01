import '../domain/models/supplier.dart';

/// Request bodies for the supplier endpoints.
abstract final class SupplierPayloads {
  static Map<String, dynamic> create({
    required String name,
    required String email,
    required String phone,
    required String balance,
    required String paymentStatus,
    required String address,
    required String altPhone,
    String? taxNumber,
    List<SupplierKyc> kyc = const [],
  }) =>
      {
        'name': name,
        'email': email,
        'phone': phone,
        'balance': double.tryParse(balance) ?? 0.0,
        'type': 1,
        'address': address,
        'alt_phone': altPhone,
        'tax_number': taxNumber?.trim() ?? '',
        'payment_type': paymentStatus,
        'kyc': kyc.map((entry) => entry.toJson()).toList(),
      };

  static Map<String, dynamic> update({
    required int id,
    required String name,
    required String phone,
    required double balance,
    String? email,
    String? address,
    String? altPhone,
    String? paymentStatus,
    String? taxNumber,
    List<SupplierKyc>? kyc,
  }) =>
      {
        'id': id,
        'name': name,
        'phone': phone,
        'balance': balance,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (altPhone != null) 'alt_phone': altPhone,
        if (paymentStatus != null) 'payment_type': paymentStatus,
        if (taxNumber != null) 'tax_number': taxNumber.trim(),
        if (kyc != null) 'kyc': kyc.map((entry) => entry.toJson()).toList(),
      };
}
