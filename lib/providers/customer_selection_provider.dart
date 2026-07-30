import 'package:flutter/material.dart';
import 'package:pos_machine/models/customer_list.dart';

class CustomerSelectionProvider extends ChangeNotifier {
  CustomerListModelData? _selectedCustomer;
  String? _selectedCustomerPhone;
  int? _selectedCustomerID;
  bool _isDefaultCustomer = false;

  // Getters
  CustomerListModelData? get selectedCustomer => _selectedCustomer;
  String? get selectedCustomerPhone => _selectedCustomerPhone;
  int? get selectedCustomerID => _selectedCustomerID;
  String? get selectedCustomerName => _selectedCustomer?.name;

  // Check if a customer is selected
  bool get hasSelectedCustomer =>
      _selectedCustomer != null && _selectedCustomerID != null;

  // Check if current customer is the default customer (first from list)
  bool get isDefaultCustomer => _isDefaultCustomer;

  /// Set the selected customer
  void setSelectedCustomer(CustomerListModelData customer,
      {bool isDefault = false}) {
    debugPrint("🔄 CUSTOMER SELECTION PROVIDER - Setting customer:");
    debugPrint("  - Customer ID: ${customer.id}");
    debugPrint("  - Customer Name: ${customer.name}");
    debugPrint("  - Customer Phone: ${customer.phone}");
    debugPrint("  - Is Default Customer: $isDefault");

    _selectedCustomer = customer;
    _selectedCustomerID = customer.id;
    _selectedCustomerPhone = customer.phone;
    _isDefaultCustomer = isDefault;

    debugPrint("✅ Customer set in provider - notifying listeners");
    notifyListeners();
  }

  /// Clear the selected customer
  void clearSelectedCustomer() {
    debugPrint("🔄 CUSTOMER SELECTION PROVIDER - Clearing customer selection");
    debugPrint("  - Previous customer: ${_selectedCustomer?.name}");

    _selectedCustomer = null;
    _selectedCustomerID = null;
    _selectedCustomerPhone = null;
    _isDefaultCustomer = false;

    debugPrint("✅ Customer cleared from provider - notifying listeners");
    notifyListeners();
  }

  void reconcileWithCustomers(List<CustomerListModelData> customers) {
    final selectedId = _selectedCustomerID;
    if (selectedId == null) return;
    final matches = customers.where((customer) => customer.id == selectedId);
    if (matches.isEmpty) {
      clearSelectedCustomer();
      return;
    }
    final wasDefault = _isDefaultCustomer;
    setSelectedCustomer(matches.first, isDefault: wasDefault);
  }

  /// Update customer phone (for cases where phone is entered manually)
  void updateCustomerPhone(String phone) {
    debugPrint(
        "🔄 CUSTOMER SELECTION PROVIDER - Updating customer phone: $phone");
    _selectedCustomerPhone = phone;
    notifyListeners();
  }

  /// Get customer info as a map for debugging
  Map<String, dynamic> getCustomerInfo() {
    return {
      'hasCustomer': hasSelectedCustomer,
      'customerId': _selectedCustomerID,
      'customerName': _selectedCustomer?.name,
      'customerPhone': _selectedCustomerPhone,
    };
  }
}
