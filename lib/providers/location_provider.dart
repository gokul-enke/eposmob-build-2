import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:pos_machine/models/get_districts.dart';
import 'package:pos_machine/models/get_states.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationProvider extends ChangeNotifier {
  List<MapEntry<String, String>> stateList = [];
  List<MapEntry<String, String>> districtList = [];
  List<MapEntry<String, String>> pincodeList = [];

  Future<void> listAllStates(String accessToken) async {
    // debugPrint("LIST ALL STATES");

    final url = Uri.parse(APPUrl.listStates);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetStatesModel statesResponse = GetStatesModel.fromJson(jsonData);

        stateList = statesResponse.data?.entries.toList() ?? [];

        notifyListeners();
      } else {
        // Handle error
        // debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exception
      // debugPrint('Exception: $e');
    }
  }

  Future<void> listAllDistricts(
      {required String accessToken, required String stateId}) async {
    // debugPrint("LIST ALL DISTRICTS");

    final url = Uri.parse("${APPUrl.listDistricts}?state_id=$stateId");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetDistrictsModel districtsResponse =
            GetDistrictsModel.fromJson(jsonData);

        districtList = districtsResponse.data?.entries.toList() ?? [];

        notifyListeners();
      } else {
        // Handle error
        // debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exception
      // debugPrint('Exception: $e');
    }
  }

  Future<void> listAllPincodes(
      {required String accessToken, required String districtId}) async {
    debugPrint("🔄 CALLING PINCODE API - District ID: $districtId");

    final url = Uri.parse("${APPUrl.listPincodes}?district_id=$districtId");
    debugPrint("📡 API URL: $url");

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("❌ API key not found");
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint("🚀 Making HTTP request to backend...");
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });

      debugPrint("📥 Backend response - Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        debugPrint("✅ SUCCESS: Got data from backend");
        debugPrint("📋 Response: ${response.body}");

        final jsonData = json.decode(response.body);
        GetDistrictsModel pincodesResponse =
            GetDistrictsModel.fromJson(jsonData);

        pincodeList = pincodesResponse.data?.entries.toList() ?? [];
        debugPrint("📊 Backend returned ${pincodeList.length} pincodes");

        if (pincodeList.isNotEmpty) {
          debugPrint("🎯 Sample: ${pincodeList.take(2).toList()}");
        } else {
          debugPrint("⚠️ Backend returned EMPTY list");
        }

        notifyListeners();
      } else {
        debugPrint("❌ Backend ERROR - Status: ${response.statusCode}");
        debugPrint("💥 Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("🚨 Exception: $e");
    }
  }
}
