import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:pos_machine/models/get_districts.dart';
import 'package:pos_machine/models/get_states.dart';
import 'package:pos_machine/resources/app_url.dart';

class LocationProvider extends ChangeNotifier {
  List<MapEntry<String, String>> stateList = [];
  List<MapEntry<String, String>> districtList = [];

  Future<void> listAllStates(String accessToken) async {
    // debugPrintdebugPrint("LIST ALL STATES");

    final url = Uri.parse(APPUrl.listStates);
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrintdebugPrint('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetStatesModel statesResponse = GetStatesModel.fromJson(jsonData);

        stateList = statesResponse.data?.entries.toList() ?? [];

        notifyListeners();
      } else {
        // Handle error
        // debugPrintdebugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exception
      // debugPrintdebugPrint('Exception: $e');
    }
  }

  Future<void> listAllDistricts(
      {required String accessToken, required String stateId}) async {
    // debugPrintdebugPrint("LIST ALL DISTRICTS");

    final url = Uri.parse("${APPUrl.listDistricts}?state_id=$stateId");
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrintdebugPrint('Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetDistrictsModel districtsResponse =
            GetDistrictsModel.fromJson(jsonData);

        districtList = districtsResponse.data?.entries.toList() ?? [];

        notifyListeners();
      } else {
        // Handle error
        // debugPrintdebugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exception
      // debugPrintdebugPrint('Exception: $e');
    }
  }
}
