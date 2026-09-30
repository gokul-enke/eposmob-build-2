import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/resources/app_url.dart';

const List<String> _thermalPaperSizes = ['112mm', '80mm', '58mm'];

/// Fetches the tenant-configured default paper size / template per printer
/// profile and seeds them into SharedPreferences — normally only into slots
/// the user has not already chosen locally, and only with values the backend's
/// own `options` payload recognizes as valid. Store bootstrap can force the
/// server values so every explicit store selection starts from a fresh sync.
///
/// Ordinary refreshes never overwrite an existing local selection. A forced
/// store-selection refresh does overwrite it, while any missing/null/
/// unrecognized API value is still skipped so the current local value or the
/// hardcoded fallback (in [PrinterSettings]) remains available.
class PrinterSettingsProvider extends ChangeNotifier {
  PrinterSettingsProvider({http.Client? client}) : _client = client;

  final http.Client? _client;

  bool isLoading = false;
  String? errorMessage;

  /// Marker key recording that [prefsKey] was set by an explicit user choice
  /// in Printer Settings — as opposed to a value another screen (e.g. the
  /// print flow) wrote implicitly just so it had something to read. Only a
  /// user-set value should block the API default from applying.
  static String userSelectedFlagKey(String prefsKey) =>
      '${prefsKey}_user_selected';

  /// Call from Printer Settings whenever the user actually changes a paper
  /// size / theme dropdown, so future syncs know not to override it.
  static Future<void> markUserSelected(
    SharedPreferences prefs,
    String prefsKey,
  ) async {
    await prefs.setBool(userSelectedFlagKey(prefsKey), true);
  }

  Future<void> fetchAndApplyDefaults({
    required String accessToken,
    bool forceServerValues = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException('API key not found. Please restart the app.');
      }

      final uri = Uri.parse(APPUrl.printerSettings);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      };
      final request = _client == null
          ? http.get(uri, headers: headers)
          : _client!.get(uri, headers: headers);
      final response = await request.timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load printer settings: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      if (jsonData is! Map<String, dynamic>) {
        throw const FormatException('Unexpected printer settings response');
      }

      await _applyResponse(
        jsonData,
        prefs,
        forceServerValues: forceServerValues,
      );
      debugPrint(
        forceServerValues
            ? '✅ [PrinterSettingsProvider] Server defaults force-synced after store selection'
            : '✅ [PrinterSettingsProvider] Defaults applied where unset',
      );
    } catch (e) {
      errorMessage = e.toString();
      // Non-fatal: local prefs / hardcoded fallbacks already cover this.
      debugPrint('⚠️ [PrinterSettingsProvider] Failed to apply defaults: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyResponse(
    Map<String, dynamic> jsonData,
    SharedPreferences prefs, {
    required bool forceServerValues,
  }) async {
    final data = jsonData['data'];
    final options = jsonData['options'];
    if (data is! Map || options is! Map) return;

    final validPaperSizes = _stringKeys(options['paper_sizes']);
    final validThermalTemplates = _stringKeys(options['thermal_templates']);
    final validPaperTemplates = _stringKeys(options['paper_templates']);

    await _applySegment(
      prefs: prefs,
      paperSize: data['b2c_paper_size']?.toString(),
      template: data['b2c_template']?.toString(),
      paperSizeKey: 'default_paper_size',
      templateKey: 'billing_receipt_theme',
      validPaperSizes: validPaperSizes,
      validThermalTemplates: validThermalTemplates,
      validPaperTemplates: validPaperTemplates,
      forceServerValues: forceServerValues,
    );

    await _applySegment(
      prefs: prefs,
      paperSize: data['b2b_paper_size']?.toString(),
      template: data['b2b_template']?.toString(),
      paperSizeKey: 'default_paper_size_b2b',
      templateKey: 'billing_receipt_theme_b2b',
      validPaperSizes: validPaperSizes,
      validThermalTemplates: validThermalTemplates,
      validPaperTemplates: validPaperTemplates,
      forceServerValues: forceServerValues,
    );
  }

  Future<void> _applySegment({
    required SharedPreferences prefs,
    required String? paperSize,
    required String? template,
    required String paperSizeKey,
    required String templateKey,
    required Set<String> validPaperSizes,
    required Set<String> validThermalTemplates,
    required Set<String> validPaperTemplates,
    required bool forceServerValues,
  }) async {
    // Ordinary refreshes preserve explicit Printer Settings choices. Store
    // selection passes forceServerValues so a new store session always starts
    // from the server defaults. A key can also hold an implicit fallback
    // written by another screen; that does not count as a user choice.
    final paperSizeUserSelected =
        prefs.getBool(userSelectedFlagKey(paperSizeKey)) ?? false;
    final templateUserSelected =
        prefs.getBool(userSelectedFlagKey(templateKey)) ?? false;

    String? resolvedPaperSize;
    if ((forceServerValues || !paperSizeUserSelected) &&
        paperSize != null &&
        paperSize.isNotEmpty &&
        validPaperSizes.contains(paperSize)) {
      await prefs.setString(paperSizeKey, paperSize);
      resolvedPaperSize = paperSize;
    } else {
      resolvedPaperSize = prefs.getString(paperSizeKey);
    }

    if ((!forceServerValues && templateUserSelected) ||
        template == null ||
        template.isEmpty) {
      return;
    }

    final isThermal = _thermalPaperSizes.contains(resolvedPaperSize);
    final validTemplates =
        isThermal ? validThermalTemplates : validPaperTemplates;
    if (validTemplates.contains(template)) {
      await prefs.setString(templateKey, template.toLowerCase());
    }
  }

  Set<String> _stringKeys(dynamic map) {
    if (map is! Map) return const {};
    return map.keys.map((key) => key.toString()).toSet();
  }
}
