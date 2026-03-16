import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/customer_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';

class CustomerProvider extends ChangeNotifier {
  List<CustomerListModelData>? customerList = [];
  List<CustomerListModelData>? _allCustomers =
      []; // Store all customers for local filtering
  CustomerListModelData? selectedCustomer;
  // For report dropdown bindings
  String? selectedCustomerId;
  String? selectedCustomerName;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;
  String? _filterName;
  String? _filterEmail;
  String? _filterPhone;
  String? _filterBalance;
  bool _isLoading = false;

  // Getters
  List<CustomerListModelData>? get getCustomerList => customerList;
  List<CustomerListModelData>? get allCustomers => _allCustomers;
  CustomerListModelData? get getSelectedCustomer => selectedCustomer;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;
  bool get isLoading => _isLoading;

  // Select a customer
  void selectCustomer(CustomerListModelData customer) {
    selectedCustomer = customer;
    selectedCustomerId = customer.id?.toString();
    selectedCustomerName = customer.name;
    notifyListeners();
  }

  // Setters used by report dropdowns
  void setSelectedCustomerId(String? id) {
    selectedCustomerId = id;
    notifyListeners();
  }

  void setSelectedCustomerName(String? name) {
    selectedCustomerName = name;
    notifyListeners();
  }

  // Apply local pagination and filtering
  void applyFiltersLocally({
    String? filterName,
    String? filterEmail,
    String? filterPhone,
    String? filterBalance,
    int page = 1,
  }) {
    if (_allCustomers == null || _allCustomers!.isEmpty) {
      customerList = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    // Save filter values
    _filterName = filterName;
    _filterEmail = filterEmail;
    _filterPhone = filterPhone;
    _filterBalance = filterBalance;
    _currentPage = page;

    // Apply filters
    List<CustomerListModelData> filteredList = [..._allCustomers!];

    if (filterName != null && filterName.isNotEmpty) {
      filteredList = filteredList
          .where((customer) =>
              customer.name != null &&
              customer.name!.toLowerCase().contains(filterName.toLowerCase()))
          .toList();
    }

    if (filterEmail != null && filterEmail.isNotEmpty) {
      filteredList = filteredList
          .where((customer) =>
              customer.email != null &&
              customer.email!.toLowerCase().contains(filterEmail.toLowerCase()))
          .toList();
    }

    if (filterPhone != null && filterPhone.isNotEmpty) {
      filteredList = filteredList
          .where((customer) =>
              customer.phone != null && customer.phone!.contains(filterPhone))
          .toList();
    }

    // Apply balance filter
    if (filterBalance != null && filterBalance.isNotEmpty) {
      filteredList = filteredList.where((customer) {
        double? balance = customer.balance;
        if (balance == null) return false;

        switch (filterBalance) {
          case 'Positive (+ve)':
            return balance > 0;
          case 'Negative (-ve)':
            return balance < 0;
          case 'Zero (0)':
            return balance == 0;
          default:
            return true; // 'All' or any other value
        }
      }).toList();
    }

    // Calculate pagination
    _totalPages = (filteredList.length / _itemsPerPage).ceil();
    _totalPages = _totalPages == 0 ? 1 : _totalPages;

    // Ensure current page is valid
    if (_currentPage > _totalPages) {
      _currentPage = _totalPages;
    }

    // Apply pagination
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filteredList.length) {
      customerList = [];
    } else {
      endIndex =
          endIndex > filteredList.length ? filteredList.length : endIndex;
      customerList = filteredList.sublist(startIndex, endIndex);
    }

    notifyListeners();
  }

  // Reset filters and pagination
  void resetFilters() {
    _filterName = null;
    _filterEmail = null;
    _filterPhone = null;
    _filterBalance = null;
    _currentPage = 1;

    if (_allCustomers != null && _allCustomers!.isNotEmpty) {
      applyFiltersLocally(page: 1);
    }
  }

  // Lightweight fetch for dropdown usage (similar to SupplierProvider.fetchSuppliers)
  Future<void> fetchCustomers({
    required String accessToken,
    String? customerName,
    bool listAll = true,
  }) async {
    try {
      await listCustomer(
        accessToken: accessToken,
        filterName: customerName,
        page: 1,
        loadAll: listAll,
      );
      // When loadAll=true, listCustomer populates _allCustomers and paginates locally
      // Notify listeners so dropdowns can rebuild with latest data
      notifyListeners();
    } catch (e) {
      debugPrint('fetchCustomers error: $e');
      rethrow;
    }
  }

  // Change page
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    applyFiltersLocally(
        filterName: _filterName,
        filterEmail: _filterEmail,
        filterPhone: _filterPhone,
        filterBalance: _filterBalance,
        page: page);
  }

  //                 *********************** LIST CUSTOMER API ***************************************************

  Future<dynamic> listCustomer({
    required String accessToken,
    String? filterName,
    String? filterEmail,
    String? filterPhone,
    String? filterAgeRange,
    bool sortAscending = false,
    int page = 1,
    bool loadAll = false, // Add parameter to load all customers
  }) async {
    _isLoading = true;
    notifyListeners();

    debugPrint("listCustomer API called");

    final queryParameters = <String, String>{
      'page': page.toString(),
      if (sortAscending) 'sort_asc': 'true',
      // If loadAll is true, request a large page size to get all customers
      if (loadAll) 'per_page': '1000',
    };

    if (filterName != null && filterName.isNotEmpty) {
      queryParameters['filter_name'] = filterName;
    }
    if (filterEmail != null && filterEmail.isNotEmpty) {
      queryParameters['filter_email'] = filterEmail;
    }
    if (filterPhone != null && filterPhone.isNotEmpty) {
      queryParameters['filter_phone'] = filterPhone;
    }
    if (filterAgeRange != null && filterAgeRange.isNotEmpty) {
      queryParameters['filter_age_range'] = filterAgeRange;
    }
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    // Add store_id to query parameters
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }

    final url = Uri.parse(APPUrl.customerListUrl)
        .replace(queryParameters: queryParameters);
    try {
      debugPrint("Making API call to ${url.toString()}");
      debugPrint(
          "Using token: ${accessToken.substring(0, min(accessToken.length, 10))}...");

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      debugPrint('API response status code: ${response.statusCode}');
      debugPrint(
          'API response body: ${response.body.substring(0, min(response.body.length, 100))}...');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(jsonData);

        if (loadAll) {
          // Store all customers for local filtering and pagination
          _allCustomers = customerListModel.data;
          applyFiltersLocally(page: 1);
        } else {
          customerList = customerListModel.data;
          notifyListeners();
        }

        _isLoading = false;
        notifyListeners();
        return jsonData;
      } else {
        debugPrint('Error in API response: ${response.reasonPhrase}');
        _isLoading = false;
        notifyListeners();
        return {
          "status": "error",
          "message": "Failed to load customers: ${response.reasonPhrase}",
        };
      }
    } catch (error) {
      debugPrint('Exception in listCustomer: $error');
      _isLoading = false;
      notifyListeners();
      return {
        "status": "error",
        "message": "Error: $error",
      };
    }
  }

  // Load all customers for local filtering
  Future<void> loadAllCustomers(String accessToken) async {
    await listCustomer(
      accessToken: accessToken,
      loadAll: true,
    );
  }

  //                 *********************** ADD CUSTOMER API ***************************************************

  Future<dynamic> addCustomer(
      String accessToken,
      String phone,
      String storeID,
      String name,
      String email,
      String address,
      String pincode,
      String city, // send ID string when available
      String state, // send ID string when available
      String country,
      BuildContext context,
      {String? balance,
      String? paymentType,
      String? altPhone,
      String? gender,
      String? dob,
      String? customerType,
      String? crNumber,
      String? vatNumber}) async {
    debugPrint("addCustomer API called");
    final Map<String, dynamic> apiBodyData = {
      'phone': phone,
      'name': name,
      'email': email,
      'store_id': storeID,
      'address': address,
      'pin_code': pincode,
      'city': city,
      'state': state,
      'country': country,
    };

    // Add optional parameters if provided
    if (balance != null && balance.isNotEmpty) {
      apiBodyData['balance'] = balance;
    }
    if (paymentType != null && paymentType.isNotEmpty) {
      apiBodyData['payment_type'] = paymentType;
    }
    if (customerType != null && customerType.isNotEmpty) {
      apiBodyData['customer_type'] = customerType;
    }
    if (crNumber != null && crNumber.isNotEmpty) {
      apiBodyData['cr_number'] = crNumber;
    }
    if (vatNumber != null && vatNumber.isNotEmpty) {
      apiBodyData['vat_number'] = vatNumber;
    }
    if (altPhone != null && altPhone.isNotEmpty) {
      apiBodyData['alt_phone'] = altPhone;
    }
    if (gender != null && gender.isNotEmpty) {
      apiBodyData['gender'] = gender;
    }
    if (dob != null && dob.isNotEmpty) {
      apiBodyData['dob'] = dob;
    }
    if (customerType != null && customerType.isNotEmpty) {
      apiBodyData['customer_type'] = customerType;
    }
    if (crNumber != null && crNumber.isNotEmpty) {
      apiBodyData['cr_number'] = crNumber;
    }
    if (vatNumber != null && vatNumber.isNotEmpty) {
      apiBodyData['vat_number'] = vatNumber;
    }
    debugPrint("API request body: ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addCustomerUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      debugPrint("Making API call to ${url.toString()}");
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      debugPrint('API response status code: ${response.statusCode}');
      debugPrint('API response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Customer added successfully");
        return json.decode(response.body);
      } else {
        debugPrint("API error: ${response.reasonPhrase}");
        // Parse the error response
        if (response.body.isNotEmpty) {
          try {
            final errorJson = json.decode(response.body);
            debugPrint("Error response JSON: $errorJson");
            // Return the error response instead of throwing an exception
            return errorJson;
          } catch (e) {
            debugPrint("Could not parse error response: $e");
            return {
              "status": "error",
              "message": "Failed to add customer: ${response.reasonPhrase}",
              "errors": {
                "general": ["Error processing your request"]
              }
            };
          }
        } else {
          return {
            "status": "error",
            "message": "Failed to add customer: ${response.reasonPhrase}",
            "errors": {
              "general": ["Error processing your request"]
            }
          };
        }
      }
    } catch (error) {
      debugPrint("Exception in addCustomer: $error");
      return {
        "status": "error",
        "message": "Failed to connect to server",
        "errors": {
          "connection": [error.toString()]
        }
      };
    }
  }

  Future<dynamic> updateCustomer(
    String accessToken,
    String phone,
    String name,
    String email,
    String address,
    String pincode,
    String city,
    String state,
    String country,
    int customerId,
    BuildContext context, {
    String? altPhone,
    String? gender,
    String? dob,
    int? storeId,
    String? balance,
    String? paymentType,
    String? customerType,
    String? crNumber,
    String? vatNumber,
  }) async {
    debugPrint("updateCustomer API called");
    final Map<String, dynamic> apiBodyData = {
      'phone': phone,
      'name': name,
      'email': email,
      'address': address,
      'pin_code': pincode,
      'city': city,
      'state': state,
      'country': country,
      'customer_id': customerId,
    };

    // Add optional fields if provided
    if (altPhone != null && altPhone.isNotEmpty) {
      apiBodyData['alt_phone'] = altPhone;
    }
    if (gender != null && gender.isNotEmpty) {
      apiBodyData['gender'] = gender;
    }
    if (dob != null && dob.isNotEmpty) {
      apiBodyData['dob'] = dob;
    }
    if (storeId != null) {
      apiBodyData['store_id'] = storeId;
    }
    if (balance != null && balance.isNotEmpty) {
      apiBodyData['balance'] = balance;
    }
    if (paymentType != null && paymentType.isNotEmpty) {
      apiBodyData['payment_type'] = paymentType;
    }
    if (customerType != null && customerType.isNotEmpty) {
      apiBodyData['customer_type'] = customerType;
    }
    if (crNumber != null && crNumber.isNotEmpty) {
      apiBodyData['cr_number'] = crNumber;
    }
    if (vatNumber != null && vatNumber.isNotEmpty) {
      apiBodyData['vat_number'] = vatNumber;
    }
    debugPrint("API request body: ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.updateCustomerUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      debugPrint("Making API call to ${url.toString()}");
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      debugPrint('API response status code: ${response.statusCode}');
      debugPrint('API response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Customer updated successfully");
        return json.decode(response.body);
      } else {
        debugPrint("API error: ${response.reasonPhrase}");
        // Parse the error response
        if (response.body.isNotEmpty) {
          try {
            final errorJson = json.decode(response.body);
            debugPrint("Error response JSON: $errorJson");
            // Return the error response instead of throwing an exception
            return errorJson;
          } catch (e) {
            debugPrint("Could not parse error response: $e");
            return {
              "status": "error",
              "message": "Failed to update customer: ${response.reasonPhrase}",
              "errors": {
                "general": ["Error processing your request"]
              }
            };
          }
        } else {
          return {
            "status": "error",
            "message": "Failed to update customer: ${response.reasonPhrase}",
            "errors": {
              "general": ["Error processing your request"]
            }
          };
        }
      }
    } catch (error) {
      debugPrint("Exception in updateCustomer: $error");
      return {
        "status": "error",
        "message": "Failed to connect to server",
        "errors": {
          "connection": [error.toString()]
        }
      };
    }
  }

// *********************** FIND CUSTOMER BY PHONE API ***************************************************

  Future<dynamic> findCustomerByPhone(
      String accessToken, String phoneNumber, BuildContext context) async {
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');
    
    final Map<String, String> queryParameters = {'filter_phone': phoneNumber};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.customerListUrl).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $phoneNumber');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      // debugPrint('response: ${response.toString()}');
      // debugPrint('response status: ${response.statusCode}');
      // debugPrint('response body: ${response.body}');

      if (response.statusCode == 200) {
        // debugPrint('Decoded response: ${json.decode(response.body)}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customer Not Found. Try Again!");
      } else {
        throw const HttpException('Failed to load data, Try Again Later!');
      }
    } catch (error) {
      // debugPrint('Error: ${error.toString()}');
      rethrow;
    }
  }

// *********************** FIND CUSTOMER BY PHONE API ***************************************************

  Future<dynamic> findCustomerByName(
      String accessToken, String customerName, BuildContext context) async {
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');
    
    final Map<String, String> queryParameters = {'filter_name': customerName};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse(APPUrl.customerListUrl).replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $phoneNumber');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      // debugPrint('response: ${response.toString()}');
      // debugPrint('response status: ${response.statusCode}');
      // debugPrint('response body: ${response.body}');

      if (response.statusCode == 200) {
        // debugPrint('Decoded response: ${json.decode(response.body)}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customer Not Found. Try Again!");
      } else {
        throw const HttpException('Failed to load data, Try Again Later!');
      }
    } catch (error) {
      // debugPrint('Error: ${error.toString()}');
      rethrow;
    }
  }

// *********************** FETCH USER BY ID ***************************************************

  Future<dynamic> fetchUserById(
      String accessToken, int userId, BuildContext context) async {
    debugPrint("fetchUserById API called for user ID: $userId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');
    
    final Map<String, String> queryParameters = {};
    if (activeStoreId != null) {
      queryParameters['store_id'] = activeStoreId.toString();
    }
    final url = Uri.parse('${APPUrl.userDetailsUrl}/$userId').replace(queryParameters: queryParameters);

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $userId');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });

      debugPrint('fetchUserById response status: ${response.statusCode}');
      debugPrint('fetchUserById response body: ${response.body.toString()}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          CustomerListModelData customer =
              CustomerListModelData.fromJson(data['data']);
          // debugPrint("User Data ${customer.toString()}");
          selectedCustomer = customer;
          notifyListeners();
        }
        // debugPrint('Decoded response: ${json.decode(response.body)}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customer Not Found. Try Again!");
      } else {
        throw const HttpException('Failed to load data, Try Again Later!');
      }
    } catch (error) {
      debugPrint('fetchUserById Error: ${error.toString()}');
      rethrow;
    }
  }

  //                 *********************** ADD ADDRESS API ***************************************************
  Future<dynamic> addAddress({
    required String accessToken,
    required Map<String, dynamic> addressData,
  }) async {
    debugPrint("addAddress API called");
    final url = Uri.parse(APPUrl.executiveAddAddressUrl);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.post(
        url,
        body: json.encode(addressData),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('addAddress response status: ${response.statusCode}');
      debugPrint('addAddress response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("Exception in addAddress: $e");
      return {"status": "error", "message": e.toString()};
    }
  }

  //                 *********************** UPDATE ADDRESS API ***************************************************
  Future<dynamic> updateAddress({
    required String accessToken,
    required int addressId,
    required Map<String, dynamic> addressData,
  }) async {
    debugPrint("updateAddress API called for ID: $addressId");
    final url = Uri.parse("${APPUrl.executiveUpdateAddressUrl}/$addressId");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.post(
        url,
        body: json.encode(addressData),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'X-Tenant': apiKey,
        },
      );

      debugPrint('updateAddress response status: ${response.statusCode}');
      debugPrint('updateAddress response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("Exception in updateAddress: $e");
      return {"status": "error", "message": e.toString()};
    }
  }
}
