import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/services/play_store_review_access.dart';
import 'package:pos_machine/services/tenant_domain_service.dart';

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiKeyRequiredException extends AuthenticationException {
  const ApiKeyRequiredException()
      : super('Enter your API key before signing in.');
}

class AuthenticationProvider {
  //                 *********************** Login API ***************************************************

  Future<dynamic> login(
    String email,
    String password,
    BuildContext? context, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final normalizedEmail = email.trim();
      final prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key')?.trim();

      if (PlayStoreReviewAccess.matchesEmail(normalizedEmail)) {
        await TenantDomainService.discoverAndSave(
          PlayStoreReviewAccess.tenantKey,
          client: httpClient,
          timeout: timeout,
        );
        apiKey = PlayStoreReviewAccess.tenantKey;
      } else if (apiKey == null || apiKey.isEmpty) {
        throw const ApiKeyRequiredException();
      }

      final apiBodyData = <String, dynamic>{
        'email': normalizedEmail,
        'password': password,
      };
      final url = Uri.parse(APPUrl.loginUrl);
      final response =
          await httpClient.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Tenant': apiKey,
      }).timeout(timeout);

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

      dynamic payload;
      try {
        payload = json.decode(response.body);
      } catch (_) {
        payload = null;
      }

      if (payload is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 500) {
        return payload;
      }

      if (response.statusCode >= 500) {
        throw const AuthenticationException(
          'The login service is temporarily unavailable. Please try again.',
        );
      }

      throw AuthenticationException(
        'Login failed (HTTP ${response.statusCode}). Please try again.',
      );
    } on TimeoutException {
      throw const AuthenticationException(
        'Login timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw const AuthenticationException(
        'Unable to reach the login server. Check your connection and try again.',
      );
    } on TenantDomainException catch (e) {
      throw AuthenticationException(e.message);
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      throw const AuthenticationException(
        'Unable to complete login. Check your connection and try again.',
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

//                 *********************** LOGOUT API ***************************************************

  Future<dynamic> logout(
    String accessToken,
    BuildContext context, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
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
      }).timeout(timeout);
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
