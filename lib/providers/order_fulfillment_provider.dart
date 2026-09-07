import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/order_fulfillment.dart';
import 'package:pos_machine/resources/api_locale.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderFulfillmentApiException implements Exception {
  final String message;

  const OrderFulfillmentApiException(this.message);

  @override
  String toString() => message;
}

/// API client for the order-level external delivery and packing flows.
///
/// It deliberately has no cached state: an order's logistics, staff and
/// packing files must be fresh each time the user opens a fulfilment dialog.
class OrderFulfillmentProvider {
  Future<List<ExternalLogistic>> fetchExternalLogistics({
    required String accessToken,
  }) async {
    final response = await _get(APPUrl.externalLogistics, accessToken);
    final data = response['data'];
    final values = data is Map ? data['external_logistics'] : data;
    return _mapList(values, ExternalLogistic.fromJson);
  }

  Future<List<ExternalLogisticWarehouse>> fetchWarehouses({
    required String accessToken,
    required int externalLogisticId,
  }) async {
    final response = await _get(
      APPUrl.externalLogisticWarehouses(externalLogisticId),
      accessToken,
    );
    final data = response['data'];
    final values = data is Map ? data['warehouses'] : data;
    return _mapList(values, ExternalLogisticWarehouse.fromJson);
  }

  Future<List<MasterDataValue>> fetchMasterDataValues({
    required String accessToken,
    required String code,
  }) async {
    final uri = ApiLocale.build(APPUrl.getMasterDataValues, {'code': code});
    final response = await _getUri(uri, accessToken);
    final data = response['data'];

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => MasterDataValue.fromJson(
              Map<String, dynamic>.from(item)))
          .where((item) => item.value.isNotEmpty)
          .toList();
    }
    if (data is Map) {
      return data.entries
          .map((entry) => MasterDataValue(
                id: 0,
                value: entry.key.toString(),
                description: entry.value?.toString() ?? entry.key.toString(),
                code: entry.key.toString(),
              ))
          .toList();
    }
    return const [];
  }

  Future<List<PackingStaff>> fetchPackingStaff({
    required String accessToken,
  }) async {
    final response = await _get(APPUrl.packingStaff, accessToken);
    final data = response['data'];
    final values = data is Map
        ? (data['staff'] ?? data['users'] ?? data['data'])
        : data;
    return _mapList(values, PackingStaff.fromJson)
        .where((staff) => staff.id > 0 && staff.name.isNotEmpty)
        .toList();
  }

  Future<void> createExternalDelivery({
    required String accessToken,
    required String orderNumber,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = _apiKey(prefs);
    final response = await http
        .post(
          Uri.parse(APPUrl.createExternalDelivery(orderNumber)),
          headers: ApiLocale.headers(apiKey: apiKey, accessToken: accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    _decodeOrThrow(response);
  }

  Future<OrderDetailsModelDataPacking> savePacking({
    required String accessToken,
    required String orderNumber,
    int? packedByUserId,
    String? packedByName,
    String? packedAt,
    List<PlatformFile> photos = const [],
    PlatformFile? video,
    List<String> photosToDelete = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(APPUrl.packingForOrder(orderNumber)),
    )
      ..headers.addAll(
          ApiLocale.headers(apiKey: _apiKey(prefs), accessToken: accessToken));

    void addField(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) request.fields[key] = trimmed;
    }

    if (packedByUserId != null) {
      request.fields['packed_by_user_id'] = packedByUserId.toString();
    }
    addField('packed_by_name', packedByName);
    addField('packed_at', packedAt);
    for (var index = 0; index < photosToDelete.length; index++) {
      final path = photosToDelete[index].trim();
      if (path.isNotEmpty) {
        // MultipartRequest stores fields in a map, so repeated literal
        // `photos_to_delete[]` keys would overwrite each other. Laravel
        // accepts the indexed form as the same request array.
        request.fields['photos_to_delete[$index]'] = path;
      }
    }
    for (final photo in photos) {
      request.files.add(await _multipartFile('packing_photos[]', photo));
    }
    if (video != null) {
      request.files.add(await _multipartFile('packing_video', video));
    }

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = _decodeOrThrow(response);
    final data = decoded['data'];
    final packing = data is Map ? data['packing'] : null;
    if (packing is! Map) {
      throw const OrderFulfillmentApiException(
          'Packing was saved but the updated packing details were not returned.');
    }
    return OrderDetailsModelDataPacking.fromJson(
        Map<String, dynamic>.from(packing));
  }

  Future<Map<String, dynamic>> _get(String url, String accessToken) =>
      _getUri(ApiLocale.build(url), accessToken);

  Future<Map<String, dynamic>> _getUri(Uri uri, String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http
        .get(
          uri,
          headers: ApiLocale.headers(
            apiKey: _apiKey(prefs),
            accessToken: accessToken,
            json: false,
          ),
        )
        .timeout(const Duration(seconds: 30));
    return _decodeOrThrow(response);
  }

  static String _apiKey(SharedPreferences prefs) {
    final apiKey = prefs.getString('api_key')?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const OrderFulfillmentApiException(
          'API key not found. Please restart the app.');
    }
    return apiKey;
  }

  static List<T> _mapList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<http.MultipartFile> _multipartFile(
      String field, PlatformFile file) async {
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return http.MultipartFile.fromPath(field, path, filename: file.name);
    }
    final bytes = file.bytes;
    if (bytes != null) {
      return http.MultipartFile.fromBytes(field, bytes, filename: file.name);
    }
    throw OrderFulfillmentApiException('Could not read ${file.name}.');
  }

  static Map<String, dynamic> _decodeOrThrow(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw OrderFulfillmentApiException(
          'The server returned an invalid response (${response.statusCode}).');
    }
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final apiStatus = map['status']?.toString().trim().toLowerCase();
    final succeeded = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (apiStatus == null || apiStatus.isEmpty || apiStatus == 'success');
    if (succeeded) return map;
    throw OrderFulfillmentApiException(_errorMessage(map, response.statusCode));
  }

  static String _errorMessage(Map<String, dynamic> response, int statusCode) {
    final message = response['message']?.toString().trim();
    final data = response['data'];
    if (data is Map) {
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }
    if (message != null && message.isNotEmpty) return message;
    return 'Request failed ($statusCode).';
  }
}
