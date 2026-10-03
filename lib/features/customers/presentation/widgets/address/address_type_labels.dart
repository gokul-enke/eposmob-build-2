import 'package:get/get.dart';

/// Address types offered by the address form, in display order. These are
/// the values sent to the API.
const List<String> kCustomerAddressTypes = ['Home', 'Office', 'Other'];

/// The default type for a new address.
const String kDefaultCustomerAddressType = 'Home';

/// Translated label for an address [type]; unknown types are shown as-is.
String customerAddressTypeLabel(String? type) {
  switch (type) {
    case 'Home':
      return 'customer_address.type_home'.tr;
    case 'Office':
      return 'customer_address.type_office'.tr;
    case 'Other':
    case null:
    case '':
      return 'customer_address.type_other'.tr;
    default:
      return type;
  }
}
