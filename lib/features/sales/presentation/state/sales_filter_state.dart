import 'package:flutter/foundation.dart';

mixin SalesFilterState on ChangeNotifier {
  // Filter visibility state
  bool _showFilters = false;
  bool get showFilters => _showFilters;

  void toggleFilters() {
    _showFilters = !_showFilters;
    notifyListeners();
  }

  void setFiltersVisibility(bool value) {
    _showFilters = value;
    notifyListeners();
  }

  // Filter parameters
  String? _filterOrderNumber;
  String? _filterCustomerName;
  String? _filterPhone;
  String? _filterPrice;
  String? _filterEmail;
  String? _filterStore;
  String? _filterStatus;
  DateTime? _filterDate;

  String? get filterOrderNumber => _filterOrderNumber;
  String? get filterCustomerName => _filterCustomerName;
  String? get filterPhone => _filterPhone;
  String? get filterPrice => _filterPrice;
  String? get filterEmail => _filterEmail;
  String? get filterStore => _filterStore;
  String? get filterStatus => _filterStatus;
  DateTime? get filterDate => _filterDate;

  void setFilterOrderNumber(String? value) {
    _filterOrderNumber = value;
    notifyListeners();
  }

  void setFilterCustomerName(String? value) {
    _filterCustomerName = value;
    notifyListeners();
  }

  void setFilterPhone(String? value) {
    _filterPhone = value;
    notifyListeners();
  }

  void setFilterPrice(String? value) {
    _filterPrice = value;
    notifyListeners();
  }

  void setFilterEmail(String? value) {
    _filterEmail = value;
    notifyListeners();
  }

  void setFilterStore(String? value) {
    _filterStore = value;
    notifyListeners();
  }

  void setFilterStatus(String? value) {
    _filterStatus = value;
    notifyListeners();
  }

  void setFilterDate(DateTime? value) {
    _filterDate = value;
    notifyListeners();
  }

  void clearAllFilters() {
    _filterOrderNumber = null;
    _filterCustomerName = null;
    _filterPhone = null;
    _filterPrice = null;
    _filterEmail = null;
    _filterStore = null;
    _filterStatus = null;
    _filterDate = null;
    notifyListeners();
  }

  bool get hasActiveFilters {
    return _filterOrderNumber != null ||
        _filterCustomerName != null ||
        _filterPhone != null ||
        _filterPrice != null ||
        _filterEmail != null ||
        _filterStore != null ||
        _filterStatus != null ||
        _filterDate != null;
  }
}
