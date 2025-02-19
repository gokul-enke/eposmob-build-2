import 'dart:convert';
import 'dart:io';

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

  // // Call details of a customer
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
    // debugPrintdebugPrint("listCustomer");

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
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });
      // debugPrintdebugPrint('inside ${response.body.toString()}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(jsonData);
        customerList = customerListModel.data;
        notifyListeners();
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return jsonData;
      } else if (response.statusCode > 400) {
        throw const HttpException("Customers Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
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
    // debugPrintdebugPrint("listCustomer");
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
    // debugPrintdebugPrint("add customer apiBodyData ${apiBodyData.toString()}");
    final url = Uri.parse(APPUrl.addCustomerUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          });
      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customers Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

// *********************** FIND CUSTOMER BY PHONE API ***************************************************

  Future<dynamic> findCustomerByPhone(
      String accessToken, String phoneNumber, BuildContext context) async {
    final url =
        Uri.parse('${APPUrl.customerListUrl}?filter_phone=$phoneNumber');

    try {
      // debugPrintdebugPrint('accessToken: $accessToken');
      // debugPrintdebugPrint('phoneNumber: $phoneNumber');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      // debugPrintdebugPrint('response: ${response.toString()}');
      // debugPrintdebugPrint('response status: ${response.statusCode}');
      // debugPrintdebugPrint('response body: ${response.body}');

      if (response.statusCode == 200) {
        // debugPrintdebugPrint('Decoded response: ${json.decode(response.body)}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customer Not Found. Try Again!");
      } else {
        throw const HttpException('Failed to load data, Try Again Later!');
      }
    } catch (error) {
      // debugPrintdebugPrint('Error: ${error.toString()}');
      rethrow;
    }
  }

// *********************** FETCH USER BY ID ***************************************************

  Future<dynamic> fetchUserById(
      String accessToken, int userId, BuildContext context) async {
    final url = Uri.parse('${APPUrl.userDetailsUrl}/$userId');

    try {
      // debugPrintdebugPrint('accessToken: $accessToken');
      // debugPrintdebugPrint('phoneNumber: $userId');

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      // debugPrintdebugPrint('response: ${response.toString()}');
      // debugPrintdebugPrint('response status: ${response.statusCode}');
      // debugPrintdebugPrint('response body: ${response.body.toString()}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          CustomerListModelData customer =
              CustomerListModelData.fromJson(data['data']);
          // debugPrintdebugPrint("User Data ${customer.toString()}");
          selectedCustomer = customer;
          notifyListeners();
        }
        // debugPrintdebugPrint('Decoded response: ${json.decode(response.body)}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Customer Not Found. Try Again!");
      } else {
        throw const HttpException('Failed to load data, Try Again Later!');
      }
    } catch (error) {
      // debugPrintdebugPrint('Error: ${error.toString()}');
      rethrow;
    }
  }
}
