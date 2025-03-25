import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/customer_list.dart';

import '../resources/app_url.dart';

class CustomerProvider extends ChangeNotifier {
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;

  List<CustomerListModelData>? get getCustomerList => customerList;
  CustomerListModelData? get getSelectedCustomer => selectedCustomer;

  // Select a customer
  void selectCustomer(CustomerListModelData customer) {
    selectedCustomer = customer;
    notifyListeners();
  }

  // Call details of a customer
  // void callCustomerDetails({required int customerId}) {
  //   CustomerListModelData customer =
  //       customerList!.firstWhere((element) => element.id == customerId);
  //   selectedCustomer = customer;
  //   notifyListeners();
  // }

  //                 *********************** LIST CUSTOMER API ***************************************************

  Future<dynamic> listCustomer({
    required String accessToken,
    String? filterName,
    String? filterEmail,
    String? filterPhone,
    String? filterAgeRange,
    bool sortAscending = false,
    int page = 1,
  }) async {
    debugPrint("listCustomer API called");

    final queryParameters = <String, String>{
      'page': page.toString(),
      if (sortAscending) 'sort_asc': 'true',
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

    final url = Uri.parse(APPUrl.customerListUrl)
        .replace(queryParameters: queryParameters);
    try {
      debugPrint("Making API call to ${url.toString()}");
      debugPrint(
          "Using token: ${accessToken.substring(0, min(accessToken.length, 10))}...");

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });
      debugPrint('API response status code: ${response.statusCode}');
      debugPrint(
          'API response body: ${response.body.substring(0, min(response.body.length, 100))}...');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(jsonData);
        customerList = customerListModel.data;
        notifyListeners();
        return jsonData;
      } else if (response.statusCode >= 400) {
        debugPrint("API error in listCustomer: ${response.reasonPhrase}");
        if (response.body.isNotEmpty) {
          try {
            final errorJson = json.decode(response.body);
            debugPrint("Error response: $errorJson");
            // Return the error response instead of throwing an exception
            return {
              "status": "error",
              "message": "Customers Not Found.Try Again!",
              "errors": errorJson
            };
          } catch (e) {
            debugPrint("Could not parse error response: $e");
          }
        }
        return {"status": "error", "message": "Customers Not Found.Try Again!"};
      } else {
        debugPrint("Unexpected status code: ${response.statusCode}");
        return {
          "status": "error",
          "message": "Failed to load data, Try Again Later!"
        };
      }
    } catch (error) {
      debugPrint("Exception in listCustomer: $error");
      return {"status": "error", "message": error.toString()};
    } finally {}
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
      String city,
      String state,
      String country,
      BuildContext context) async {
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
    debugPrint("API request body: ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addCustomerUrl);
    try {
      debugPrint("Making API call to ${url.toString()}");
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
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
      BuildContext context) async {
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
    debugPrint("API request body: ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.updateCustomerUrl);
    try {
      debugPrint("Making API call to ${url.toString()}");
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
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
    final url =
        Uri.parse('${APPUrl.customerListUrl}?filter_phone=$phoneNumber');

    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $phoneNumber');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
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
    final url =
        Uri.parse('${APPUrl.customerListUrl}?filter_name=$customerName');

    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $phoneNumber');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
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
    final url = Uri.parse('${APPUrl.userDetailsUrl}/$userId');

    try {
      // debugPrint('accessToken: $accessToken');
      // debugPrint('phoneNumber: $userId');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      // debugPrint('response: ${response.toString()}');
      // debugPrint('response status: ${response.statusCode}');
      // debugPrint('response body: ${response.body.toString()}');

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
      // debugPrint('Error: ${error.toString()}');
      rethrow;
    }
  }
}
