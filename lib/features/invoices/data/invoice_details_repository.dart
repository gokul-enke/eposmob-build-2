import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/models/invoice_details.dart';
import 'package:pos_machine/resources/app_url.dart';

/// A request-local details read: another dialog cannot replace its result.
/// Uses the same URL, store scope and headers as the compatibility provider.
class InvoiceDetailsRepository {
  const InvoiceDetailsRepository({this.client});
  final http.Client? client;

  Future<InvoiceDetails?> fetch({
    required int id,
    required String accessToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    final storeId = prefs.getInt('active_store_id');
    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException('API key not found. Please restart the app.');
    }
    final uri = Uri.parse('${APPUrl.detailsOfInvoice}/$id').replace(
      queryParameters: {if (storeId != null) 'store_id': '$storeId'},
    );
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'X-Tenant': apiKey
    };
    final response = client == null
        ? await http.get(uri, headers: headers)
        : await client!.get(uri, headers: headers);
    if (response.statusCode != 200) return null;
    final details = InvoiceDetails.fromJson(jsonDecode(response.body)['data']);
    if (details.id != id) return null;
    return details;
  }
}
