import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of an order-document download.
///
/// The document endpoints stream raw PDF bytes and require both the bearer
/// token and the tenant header, so the file has to be fetched here and
/// written to disk — handing the URL to the OS would fail with a 401.
class OrderDocumentResult {
  final File? file;
  final String? errorMessage;

  const OrderDocumentResult._({this.file, this.errorMessage});

  factory OrderDocumentResult.success(File file) =>
      OrderDocumentResult._(file: file);

  factory OrderDocumentResult.failure(String message) =>
      OrderDocumentResult._(errorMessage: message);

  bool get isSuccess => file != null;
}

class OrderDocumentService {
  const OrderDocumentService();

  /// Downloads the PDF at [url] and writes it to the temp directory.
  ///
  /// [fallbackFileName] is used when the response carries no
  /// `Content-Disposition` header.
  Future<OrderDocumentResult> download({
    required String url,
    required String accessToken,
    required String fallbackFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        return OrderDocumentResult.failure(
            'sales_order_details.msg_api_key_missing'.tr);
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 401) {
        return OrderDocumentResult.failure(
            'sales_order_details.msg_session_expired'.tr);
      }

      // The backend uses 422 with its own message for "this document does not
      // apply to this order" — surface that text rather than a generic error.
      if (response.statusCode == 422) {
        return OrderDocumentResult.failure(
            _messageFromJson(response.body) ??
                'sales_order_details.msg_document_not_available'.tr);
      }

      if (response.statusCode != 200) {
        return OrderDocumentResult.failure(
            _messageFromJson(response.body) ??
                "${'sales_order_details.msg_document_download_failed'.tr} (${response.statusCode})");
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return OrderDocumentResult.failure('sales_order_details.msg_document_empty'.tr);
      }

      final directory = await getTemporaryDirectory();
      final fileName = _fileNameFrom(
            response.headers['content-disposition'],
          ) ??
          fallbackFileName;
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return OrderDocumentResult.success(file);
    } on SocketException {
      return OrderDocumentResult.failure(
          'sales_order_details.msg_no_internet'.tr);
    } catch (error) {
      debugPrint('Error downloading order document: $error');
      return OrderDocumentResult.failure(
          'sales_order_details.msg_document_download_error'.tr);
    }
  }

  /// Pulls `filename="bill-ORD-0001.pdf"` out of a Content-Disposition header.
  /// Quotes are optional in the responses we get, hence the two groups.
  static String? _fileNameFrom(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) return null;
    final match = RegExp(r'filename\s*=\s*"?([^";]+)"?')
        .firstMatch(contentDisposition);
    final name = match?.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    // Strip any path segments a header might smuggle in.
    return name.split(RegExp(r'[\\/]')).last;
  }

  /// Error responses are JSON like {"status":"failed","message":"..."}.
  static String? _messageFromJson(String body) {
    if (body.isEmpty || !body.trimLeft().startsWith('{')) return null;
    final match = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(body);
    final message = match?.group(1)?.trim();
    return (message == null || message.isEmpty) ? null : message;
  }
}
