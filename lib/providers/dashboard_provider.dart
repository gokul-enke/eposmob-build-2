import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../resources/app_url.dart';

class DashboardProvider {
  //                 *********************** DASHBOARD API ***************************************************

  Future<dynamic> dashbaord(String accessToken, BuildContext context) async {
    // debugPrintdebugPrint("dashbaord");

    final url = Uri.parse(APPUrl.dashBoardUrl);
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      });

      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Data Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }

  Future<List<GraphData>> fetchGraphData(String accessToken) async {
    final url =
        Uri.parse(APPUrl.dashBoardGraphUrl); // Replace with actual endpoint
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          final dynamic data = responseData['data'];
          if (data is List) {
            return data.map((item) => GraphData.fromJson(item)).toList();
          } else {
            throw const FormatException('Expected data to be a list');
          }
        } else {
          throw HttpException(
              responseData['message'] ?? 'Failed to load graph data');
        }
      } else {
        throw HttpException(
            'Failed to load graph data. Status code: ${response.statusCode}');
      }
    } catch (error) {
      // debugPrintdebugPrint('Error fetching graph data: $error');
      rethrow;
    }
  }

  // Dummy Graph Data
  // Future<List<GraphData>> fetchGraphData(String accessToken) async {
  //   // Simulate sample data for testing
  //   final List<GraphData> sampleData = _generateSampleData();

  //   // Return the sample data directly without making an actual HTTP request
  //   return sampleData;
  // }

  // List<GraphData> _generateSampleData() {
  //   final now = DateTime.now();
  //   final List<GraphData> data = [];

  //   for (int i = 0; i < 10; i++) {
  //     final date = now.subtract(Duration(days: i));
  //     final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  //     final count =
  //         i + Random().nextInt(10); // Sample count, you can adjust this

  //     data.add(GraphData(
  //       date: DateTime.parse(formattedDate),
  //       count: count,
  //     ));
  //   }

  //   return data;
  // }

  Future<Map<String, dynamic>> listCartItnes(BuildContext context) async {
    // debugPrintdebugPrint("dashbaord");

    final url = Uri.parse(
        "https://safai.enke.ae/api/carts/list-cart-items?customer_id=5");
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer 8|bTQHp0upEnGCgNEwbYo0bdhLLEg3CKBSvU6QPJe5',
        'Content-Type': 'application/json'
      });

      // debugPrintdebugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrintdebugPrint(json.decode(response.body).toString());
        return json.decode(response.body);
      } else if (response.statusCode > 400) {
        throw const HttpException("Data Not Found.Try Again!");
      } else {
        throw const HttpException('Failed to load data ,Try Again Later!');
      }
    } catch (error) {
      rethrow;
    } finally {}
  }
}

class GraphData {
  final DateTime date;
  final int count;

  GraphData({required this.date, required this.count});

  factory GraphData.fromJson(Map<String, dynamic> json) {
    return GraphData(
      date: DateTime.parse(json['date']),
      count: json['count'],
    );
  }
}
