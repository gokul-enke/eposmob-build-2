import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/helpers/date_helper.dart';

class AuthenticationProvider {
  //                 *********************** Login API ***************************************************

  Future<dynamic> login(
      String email, String password, BuildContext context) async {
    // debugPrint("login");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    final Map<String, dynamic> apiBodyData = {
      'email': email,
      'password': password,
    };
    debugPrint('Login request body: ${json.encode(apiBodyData)}');
    final url = Uri.parse(APPUrl.loginUrl);
    debugPrint('Login URL: $url');
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      
      // Sync server time from headers
      if (response.headers['date'] != null) {
        try {
          // Date header format: Wed, 21 Oct 2015 07:28:00 GMT
          final serverTime = HttpDate.parse(response.headers['date']!);
          DateHelper.setServerTime(serverTime);
        } catch (e) {
          debugPrint("Error parsing server date header: $e");
        }
      }

      debugPrint('Login response status code: ${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 401) {
        debugPrint('Login response body: ${response.body}');
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("User Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

//                 *********************** LOGOUT API ***************************************************

  Future<dynamic> logout(String accessToken, BuildContext context) async {
    // debugPrint("logout");

    final url = Uri.parse(APPUrl.logoutUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Logout Failed.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

  //                 *********************** FORGOT PASSWORD API ***************************************************

  Future<dynamic> forgotPassword(String email, BuildContext context) async {
    // debugPrint("forgotPassword");
    final Map<String, dynamic> apiBodyData = {
      'email': email,
    };
    // debugPrint(json.encode(apiBodyData));

    final url = Uri.parse(APPUrl.forgotPasswordUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json', 'api_key': apiKey});
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 401) {
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Action Failed.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }
  //                 *********************** RESET PASSWORD API ***************************************************

  Future<dynamic> resetPassword(String code, String password,
      String confirmPassword, BuildContext context) async {
    // debugPrint("resetPassword");

    final Map<String, dynamic> apiBodyData = {
      'code': code,
      'password': password,
      'password_confirmation': confirmPassword,
    };
    // debugPrint(json.encode(apiBodyData));
    final url = Uri.parse(APPUrl.resetPasswordUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json', 'api_key': apiKey});
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 401) {
        // debugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("User Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }
}
