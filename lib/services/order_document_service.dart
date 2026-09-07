import 'dart:async';
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

  static const Duration _downloadTimeout = Duration(seconds: 60);

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

      // Generous, because a delivery note runs to roughly 800 KB — but finite,
      // so a server that accepts the connection and then stalls cannot leave
      // the download buttons spinning forever.
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(_downloadTimeout);

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
      // Sanitised whichever source it came from: the header is written by the
      // server, and the fallback embeds the order number.
      final fileName = _safeFileName(
        _fileNameFrom(response.headers['content-disposition']) ??
            fallbackFileName,
      );
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return OrderDocumentResult.success(file);
    } on TimeoutException {
      debugPrint('Order document download timed out after $_downloadTimeout');
      return OrderDocumentResult.failure(
          'sales_order_details.msg_document_timed_out'.tr);
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
    return name;
  }

  /// Keeps a name to a single, writable file. A separator would otherwise
  /// point at a directory that does not exist and fail the write; the other
  /// characters are simply illegal in filenames on Windows.
  static String _safeFileName(String name) {
    final cleaned = name
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
        .trim();
    return cleaned.isEmpty ? 'document.pdf' : cleaned;
  }

  /// Error responses are JSON like {"status":"failed","message":"..."}.
  static String? _messageFromJson(String body) {
    if (body.isEmpty || !body.trimLeft().startsWith('{')) return null;
    final match = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(body);
    final message = match?.group(1)?.trim();
    return (message == null || message.isEmpty) ? null : message;
  }
}
