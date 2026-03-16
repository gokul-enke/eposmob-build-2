import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/bank.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BankProvider extends ChangeNotifier {
  static const String _cacheKeyPrefix = 'banks_cache_store_';
  static const String _cacheUpdatedAtPrefix = 'banks_cache_updated_at_store_';

  List<StoreBank> _banks = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _loadedStoreId;

  List<StoreBank> get banks => List.unmodifiable(_banks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get loadedStoreId => _loadedStoreId;

  StoreBank? get primaryBank {
    for (final bank in _banks) {
      if (bank.isActive && bank.bankAccounts.isNotEmpty) {
        return bank;
      }
    }
    for (final bank in _banks) {
      if (bank.bankAccounts.isNotEmpty) {
        return bank;
      }
    }
    if (_banks.isEmpty) {
      return null;
    }
    return _banks.first;
  }

  StoreBankAccount? get primaryBankAccount => primaryBank?.primaryAccount;

  Future<void> fetchBanks({
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (!forceRefresh &&
        _loadedStoreId == activeStoreId &&
        _banks.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    if (!forceRefresh) {
      await _loadCachedBanksForStore(activeStoreId, notify: false);
    }
    notifyListeners();

    if (apiKey == null || apiKey.isEmpty) {
      _isLoading = false;
      _errorMessage = 'API key not found. Please restart the app.';
      notifyListeners();
      throw const HttpException('API key not found. Please restart the app.');
    }

    if (accessToken.isEmpty) {
      _isLoading = false;
      _errorMessage = 'Access token not found.';
      notifyListeners();
      return;
    }

    final queryParams = <String, String>{};
    if (activeStoreId != null) {
      queryParams['store_id'] = activeStoreId.toString();
    }

    final url = Uri.parse(APPUrl.getBanks)
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to fetch banks. Status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> jsonData =
          json.decode(response.body) as Map<String, dynamic>;
      final bankList = BankListResponse.fromJson(jsonData);

      _banks = bankList.data;
      _loadedStoreId = activeStoreId;
      _errorMessage = null;

      await _saveSnapshot(activeStoreId, jsonData);
    } catch (error) {
      _errorMessage = error.toString();
      if (_banks.isEmpty) {
        await _loadCachedBanksForStore(activeStoreId, notify: false);
      }
      debugPrint('Error fetching banks: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCachedBanks() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadCachedBanksForStore(prefs.getInt('active_store_id'));
  }

  Future<void> clearLoadedBanks() async {
    _banks = [];
    _loadedStoreId = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _saveSnapshot(
    int? storeId,
    Map<String, dynamic> snapshotJson,
  ) async {
    if (storeId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cacheKeyPrefix$storeId',
      json.encode(snapshotJson),
    );
    await prefs.setString(
      '$_cacheUpdatedAtPrefix$storeId',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _loadCachedBanksForStore(
    int? storeId, {
    bool notify = true,
  }) async {
    if (storeId == null) {
      _banks = [];
      _loadedStoreId = null;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = prefs.getString('$_cacheKeyPrefix$storeId');
      if (snapshot == null || snapshot.isEmpty) {
        return;
      }

      final Map<String, dynamic> snapshotJson =
          json.decode(snapshot) as Map<String, dynamic>;
      final bankList = BankListResponse.fromJson(snapshotJson);

      _banks = bankList.data;
      _loadedStoreId = storeId;

      if (notify) {
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Error loading cached banks: $error');
    }
  }
}