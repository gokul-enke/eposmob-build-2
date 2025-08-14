import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/restaurant/table_model.dart';
import '../../models/restaurant/table_list_model.dart';
import '../../resources/app_url.dart';

class TableProvider with ChangeNotifier {
  final List<TableModel> _tables = [];
  bool _isLoading = false;
  String? _error;

  List<TableModel> get tables => List.unmodifiable(_tables);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTables(
      {bool forceRefresh = false, String? accessToken}) async {
    debugPrint(
        '🚀 TableProvider: loadTables called - forceRefresh: $forceRefresh, current tables count: ${_tables.length}');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (forceRefresh || _tables.isEmpty) {
        debugPrint('📡 TableProvider: Fetching tables from API...');
        await _fetchTablesFromApi(accessToken: accessToken);
      } else {
        debugPrint(
            '📋 TableProvider: Using cached tables (${_tables.length} tables)');
      }
    } catch (e) {
      debugPrint('❌ TableProvider: Error loading tables: $e');
      _error = e.toString();

      // Fallback to mock data if API fails
      if (_tables.isEmpty) {
        debugPrint('🔄 TableProvider: Falling back to mock data');
        _tables.addAll(_mockTables());
        debugPrint('📋 TableProvider: Added ${_tables.length} mock tables');
      }
    } finally {
      _isLoading = false;
      debugPrint(
          '✅ TableProvider: loadTables completed - final tables count: ${_tables.length}, error: $_error');
      notifyListeners();
    }
  }

  Future<void> _fetchTablesFromApi({accessToken}) async {
    debugPrint('🔄 TableProvider: Starting to fetch tables from API...');

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    debugPrint(
        '🔑 TableProvider: API Key found: ${apiKey != null ? 'Yes' : 'No'}');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('❌ TableProvider: API key not found in SharedPreferences');
      throw const HttpException("API key not found. Please restart the app.");
    }

    final url = Uri.parse(APPUrl.getTableList);
    debugPrint('🌐 TableProvider: Making request to: $url');

    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
        'Authorization': 'Bearer $accessToken',
      };

      debugPrint('📤 TableProvider: Request headers: $headers');

      final response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
          '📥 TableProvider: Response status code: ${response.statusCode}');
      debugPrint('📥 TableProvider: Response headers: ${response.headers}');
      debugPrint('📥 TableProvider: Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('✅ TableProvider: Parsed JSON data: $jsonData');

        final tableListModel = TableListModel.fromJson(jsonData);
        debugPrint('📊 TableProvider: Model status: ${tableListModel.status}');
        debugPrint(
            '📊 TableProvider: Model message: ${tableListModel.message}');
        debugPrint(
            '📊 TableProvider: Model data count: ${tableListModel.data.length}');
        debugPrint('📊 TableProvider: Model data: ${tableListModel.data}');

        if (tableListModel.isSuccess) {
          _tables.clear();
          debugPrint('🗑️ TableProvider: Cleared existing tables');

          // Convert API data to TableModel
          int tableIndex = 1;
          tableListModel.data.forEach((key, value) {
            debugPrint(
                '🏷️ TableProvider: Processing table - Key: $key, Value: $value');

            final table = TableModel(
              id: key, // Use the key as ID (e.g., "TABLE_ONE")
              name: value, // Use the value as display name (e.g., "TABLE 1")
              capacity: 4, // Default capacity, can be enhanced later
              status: TableStatus.available, // Default status
              section: 1, // Default section
            );

            _tables.add(table);
            debugPrint(
                '➕ TableProvider: Added table ${tableIndex}: ID=${table.id}, Name=${table.name}');
            tableIndex++;
          });

          debugPrint(
              '✅ TableProvider: Successfully loaded ${_tables.length} tables from API');
          debugPrint('📋 TableProvider: Final table list:');
          for (int i = 0; i < _tables.length; i++) {
            final table = _tables[i];
            debugPrint(
                '   ${i + 1}. ID: ${table.id}, Name: ${table.name}, Status: ${table.status}');
          }
        } else {
          debugPrint(
              '❌ TableProvider: API returned unsuccessful status: ${tableListModel.status}');
          throw Exception('API returned error: ${tableListModel.message}');
        }
      } else {
        debugPrint('❌ TableProvider: HTTP Error ${response.statusCode}');
        debugPrint('❌ TableProvider: Error response body: ${response.body}');
        throw Exception('Failed to load tables: HTTP ${response.statusCode}');
      }
    } catch (error) {
      debugPrint(
          '💥 TableProvider: Exception occurred while fetching tables: $error');
      debugPrint('💥 TableProvider: Error type: ${error.runtimeType}');
      if (error is HttpException) {
        debugPrint('💥 TableProvider: HttpException message: ${error.message}');
      }
      rethrow;
    }
  }

  void updateTableStatus(String tableId, TableStatus status) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx].copyWith(status: status);
      notifyListeners();
    }
  }

  void assignServer(String tableId, String serverId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx].copyWith(assignedServerId: serverId);
      notifyListeners();
    }
  }

  void setCurrentOrder(String tableId, String orderId) {
    final idx = _tables.indexWhere((t) => t.id == tableId);
    if (idx != -1) {
      _tables[idx] = _tables[idx]
          .copyWith(currentOrderId: orderId, status: TableStatus.occupied);
      notifyListeners();
    }
  }

  TableModel? getById(String id) {
    return _tables.firstWhere((e) => e.id == id,
        orElse: () => _tables.isNotEmpty ? _tables.first : _mockTables().first);
  }

  /// Force refresh tables from API
  Future<void> refreshTables() async {
    debugPrint('🔄 TableProvider: refreshTables called - forcing API refresh');
    await loadTables(forceRefresh: true);
  }

  List<TableModel> _mockTables() {
    return List.generate(12, (i) {
      return TableModel(
        id: 'T${i + 1}',
        name: 'Table ${i + 1}',
        capacity: i % 4 + 2,
        status: i % 3 == 0 ? TableStatus.available : TableStatus.occupied,
        assignedServerId: i % 3 == 0 ? null : 'S${(i % 3) + 1}',
        currentOrderId: i % 3 == 0 ? null : 'O${i + 100}',
        reservationTime: null,
        section: 1,
      );
    });
  }
}
