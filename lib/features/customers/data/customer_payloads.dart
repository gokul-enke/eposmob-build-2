/// Field values for creating or updating a customer.
///
/// For [CustomerPayloads.create] empty optional values are left out; for
/// [CustomerPayloads.update] every non-null value is sent (an empty string
/// clears the field on the server).
class CustomerFields {
  const CustomerFields({
    this.phone,
    this.name,
    this.email,
    this.address,
    this.pincode,
    this.city,
    this.state,
    this.country,
    this.altPhone,
    this.gender,
    this.dob,
    this.balance,
    this.paymentType,
    this.customerType,
    this.crNumber,
    this.vatNumber,
  });

  final String? phone;
  final String? name;
  final String? email;
  final String? address;
  final String? pincode;

  /// City / district id (as a string) when known.
  final String? city;

  /// State id (as a string) when known.
  final String? state;
  final String? country;
  final String? altPhone;
  final String? gender;

  /// `yyyy-MM-dd`.
  final String? dob;
  final String? balance;
  final String? paymentType;
  final String? customerType;
  final String? crNumber;
  final String? vatNumber;
}

/// Request bodies for the customer endpoints.
abstract final class CustomerPayloads {
  static Map<String, dynamic> create(CustomerFields fields,
      {required String storeId}) {
    final body = <String, dynamic>{
      'phone': fields.phone ?? '',
      'name': fields.name ?? '',
      'email': fields.email ?? '',
      'store_id': storeId,
      'address': fields.address ?? '',
      'pin_code': fields.pincode ?? '',
      'city': fields.city ?? '',
      'state': fields.state ?? '',
      'country': fields.country ?? '',
    };
    void putIfNotEmpty(String key, String? value) {
      if (value != null && value.isNotEmpty) body[key] = value;
    }

    putIfNotEmpty('balance', fields.balance);
    putIfNotEmpty('payment_type', fields.paymentType);
    putIfNotEmpty('customer_type', fields.customerType);
    putIfNotEmpty('cr_number', fields.crNumber);
    putIfNotEmpty('vat_number', fields.vatNumber);
    putIfNotEmpty('alt_phone', fields.altPhone);
    putIfNotEmpty('gender', fields.gender);
    putIfNotEmpty('dob', fields.dob);
    return body;
  }

  static Map<String, dynamic> update(
    int customerId,
    CustomerFields fields, {
    int? storeId,
  }) {
    final body = <String, dynamic>{'customer_id': customerId};
    void putIfNotNull(String key, Object? value) {
      if (value != null) body[key] = value;
    }

    putIfNotNull('phone', fields.phone);
    putIfNotNull('name', fields.name);
    putIfNotNull('email', fields.email);
    putIfNotNull('address', fields.address);
    putIfNotNull('pin_code', fields.pincode);
    putIfNotNull('city', fields.city);
    putIfNotNull('state', fields.state);
    putIfNotNull('country', fields.country);
    putIfNotNull('alt_phone', fields.altPhone);
    putIfNotNull('gender', fields.gender);
    putIfNotNull('dob', fields.dob);
    putIfNotNull('store_id', storeId);
    putIfNotNull('balance', fields.balance);
    putIfNotNull('payment_type', fields.paymentType);
    putIfNotNull('customer_type', fields.customerType);
    putIfNotNull('cr_number', fields.crNumber);
    putIfNotNull('vat_number', fields.vatNumber);
    return body;
  }
}
