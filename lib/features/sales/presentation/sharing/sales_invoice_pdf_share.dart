import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet with the invoice [pdf] attached.
///
/// Returns null when no share sheet could be shown; the caller then offers
/// its own fallback (open / copy the file).
///
/// Windows needs two things share_plus does not do for us:
/// * Its native side opens each file with WinRT
///   `StorageFile.GetFileFromPathAsync`, which rejects forward slashes and
///   silently drops the file. Our PDFs are saved as `<Documents>/epos/...`,
///   so the sheet opened with nothing in it ("Try that again").
/// * It always answers [ShareResultStatus.unavailable], even when the sheet
///   was shown, so that status is not a failure there.
Future<ShareResult?> shareInvoicePdf(
  File pdf, {
  required String text,
  required String subject,
  @visibleForTesting bool? isWindows,
  @visibleForTesting Future<ShareResult> Function(ShareParams params)? share,
}) async {
  final windows = isWindows ?? Platform.isWindows;
  final path = windows ? windowsNativePath(pdf.path) : pdf.path;
  try {
    return await (share ?? SharePlus.instance.share)(ShareParams(
      text: text,
      subject: subject,
      // The Windows sheet needs a title; without one it uses the text.
      title: subject,
      files: [XFile(path, mimeType: 'application/pdf')],
    ));
  } catch (error) {
    debugPrint('Invoice PDF share failed: $error');
    return null;
  }
}

/// [path] with backslashes only, as WinRT file APIs require.
@visibleForTesting
String windowsNativePath(String path) => path.replaceAll('/', r'\');
