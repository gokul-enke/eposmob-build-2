import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Document I/O only; user feedback belongs to the presentation action.
class VoucherPdfService {
  Future<bool> open(String url, {String? suggestedFileName}) async {
    if (kIsWeb) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
      return true;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          suggestedFileName != null && suggestedFileName.trim().isNotEmpty
              ? suggestedFileName
              : 'voucher_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savePath = '${dir.path}/$fileName';
      await Dio().download(url, savePath,
          options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              validateStatus: (status) => status != null && status < 500));
      await OpenFile.open(savePath);
      return false;
    } catch (_) {
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      rethrow;
    }
  }
}
