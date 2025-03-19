import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/supplier.dart';
import '../resources/app_url.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier>? _supplierList;
  bool _isLoading = false;
  Supplier? _selectedSupplier;

  List<Supplier>? get supplierList => _supplierList;
  bool get isLoading => _isLoading;
  Supplier? get selectedSupplier => _selectedSupplier;

  // Default constructor
  SupplierProvider() {
    _supplierList = [];
  }

  // Select a supplier
  void selectSupplier(Supplier supplier) {
    _selectedSupplier = supplier;
    notifyListeners();
  }

  // Clear selected supplier
  void clearSelectedSupplier() {
    _selectedSupplier = null;
    notifyListeners();
  }

  // Fetch all suppliers from API
  Future<List<Supplier>?> fetchSuppliers({
    required String accessToken,
    String? supplierName,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Build URL with search parameter if supplierName is provided
    String urlString = APPUrl.getSuppliers;
    if (supplierName != null && supplierName.isNotEmpty) {
      urlString += '?supplier_name=$supplierName';
    }
    final url = Uri.parse(urlString);
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      debugPrint('Supplier API Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        SupplierResponse supplierResponse = SupplierResponse.fromJson(jsonData);
        
        _supplierList = supplierResponse.data;
        debugPrint('Fetched ${_supplierList?.length ?? 0} suppliers');
        
        _isLoading = false;
        notifyListeners();
        return _supplierList;
      } else {
        debugPrint('Error fetching suppliers: ${response.body}');
        _isLoading = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      debugPrint('Exception in fetchSuppliers: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Add a new supplier
  Future<Map<String, dynamic>> addSupplier({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String productCategories,
    required String accessToken,
  }) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, dynamic> apiBodyData = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'product_categories': productCategories,
    };

    final url = Uri.parse(APPUrl.getSuppliers);
    
    try {
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      _isLoading = false;
      notifyListeners();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh the supplier list
        await fetchSuppliers(accessToken: accessToken);
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Failed to add supplier: ${response.body}'
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'status': 'error',
        'message': 'Exception when adding supplier: $e'
      };
    }
  }
} 