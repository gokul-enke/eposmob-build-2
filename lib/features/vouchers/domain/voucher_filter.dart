import 'models/customer_voucher.dart';
import 'models/supplier_voucher.dart';

List<CustomerVoucher> filterCustomerVouchers(List<CustomerVoucher> vouchers,
    {String? customerName,
    String? voucherNumber,
    String? type,
    String? status}) {
  // Filter vouchers
  List<CustomerVoucher> filteredVouchers = [...vouchers];

  // Filter by customer name
  if (customerName != null && customerName.isNotEmpty) {
    filteredVouchers = filteredVouchers.where((voucher) {
      final bool matchesName = voucher.customer.user.name
          .toLowerCase()
          .contains(customerName.toLowerCase());
      return matchesName;
    }).toList();
  }

  // Filter by voucher number
  if (voucherNumber != null && voucherNumber.isNotEmpty) {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.voucherNumber
          .toLowerCase()
          .contains(voucherNumber.toLowerCase());
    }).toList();
  }

  // Filter by type
  if (type != null && type.isNotEmpty && type != 'All Types') {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.type.toLowerCase() == type.toLowerCase();
    }).toList();
  }

  // Filter by status
  if (status != null && status.isNotEmpty && status != 'All Status') {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.status.toLowerCase() == status.toLowerCase();
    }).toList();
  }

  return filteredVouchers;
}

List<SupplierVoucher> filterSupplierVouchers(List<SupplierVoucher> vouchers,
    {int? filterSupplierId,
    String? filterVoucherNumber,
    String? filterType,
    String? filterStatus}) {
  // Filter vouchers
  List<SupplierVoucher> filteredVouchers = [...vouchers];

  // Filter by supplier id
  if (filterSupplierId != null && filterSupplierId > 0) {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.supplier.id == filterSupplierId;
    }).toList();
  }

  // Filter by voucher number
  if (filterVoucherNumber != null && filterVoucherNumber.isNotEmpty) {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.voucherNumber
          .toLowerCase()
          .contains(filterVoucherNumber.toLowerCase());
    }).toList();
  }

  // Filter by type
  if (filterType != null &&
      filterType.isNotEmpty &&
      filterType != 'All Types') {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.type.toLowerCase() == filterType.toLowerCase();
    }).toList();
  }

  // Filter by status
  if (filterStatus != null &&
      filterStatus.isNotEmpty &&
      filterStatus != 'All Status') {
    filteredVouchers = filteredVouchers.where((voucher) {
      return voucher.status.toLowerCase() == filterStatus.toLowerCase();
    }).toList();
  }

  return filteredVouchers;
}
