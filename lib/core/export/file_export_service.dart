import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// Hands an exported file to the user: **Save As** on Windows, the system
/// **share sheet** everywhere else.
///
/// Windows uses Save As because the native share UI (DataTransferManager)
/// can terminate the app process.
abstract final class FileExportService {
  static const xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Delivers [file]. [onStage] receives short progress texts ("Waiting for
  /// Save As…", "Saving…"). Returns normally when the user cancels.
  static Future<void> deliver(
    BuildContext context,
    File file, {
    required String mimeType,
    String? shareText,
    Rect? shareOrigin,
    ValueChanged<String>? onStage,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await _saveAs(context, file, onStage: onStage);
      return;
    }
    onStage?.call('list.export_waiting_share'.tr);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            name: file.uri.pathSegments.last,
            mimeType: mimeType,
            length: await file.length(),
          ),
        ],
        text: shareText,
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  static Future<void> _saveAs(
    BuildContext context,
    File file, {
    ValueChanged<String>? onStage,
  }) async {
    final name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final extension = dot == -1 ? null : name.substring(dot + 1).toLowerCase();

    onStage?.call('list.export_waiting_save'.tr);
    final destination = await FilePicker.platform.saveFile(
      fileName: name,
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
      lockParentWindow: true,
    );
    if (destination == null) return;

    final path = extension == null ||
            destination.toLowerCase().endsWith('.$extension')
        ? destination
        : '$destination.$extension';
    // The dialog only confirmed the path it returned, not one with an
    // added extension, so ask before replacing that file.
    if (path != destination && await File(path).exists()) {
      if (!context.mounted) return;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('list.export_overwrite_title'.tr),
          content: Text('list.export_overwrite_message'
              .trParams({'name': File(path).uri.pathSegments.last})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('list.export_cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('list.export_overwrite'.tr),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }
    if (File(path).absolute.path.toLowerCase() !=
        file.absolute.path.toLowerCase()) {
      onStage?.call('list.export_saving'.tr);
      await file.copy(path);
    }
  }
}

/// Busy state + stage text for an export started from a header action.
///
/// ```dart
/// HeaderAction(
///   icon: Icons.ios_share_rounded,
///   label: _export.stage ?? exportLabel,
///   busy: _export.busy,
///   onPressed: () => _export.run(context, createFile: _createFile),
/// )
/// ```
class ExportController extends ChangeNotifier {
  ExportController({this.deliver = FileExportService.deliver});

  /// Replaceable for tests.
  final Future<void> Function(
    BuildContext context,
    File file, {
    required String mimeType,
    String? shareText,
    Rect? shareOrigin,
    ValueChanged<String>? onStage,
  }) deliver;

  bool _busy = false;
  String? _stage;
  bool _disposed = false;

  bool get busy => _busy;

  /// Current progress text while [busy] (e.g. "Waiting for Save As…").
  String? get stage => _stage;

  /// Shows [text] as the stage (e.g. "Fetching page 2 of 5") while busy.
  void setStage(String? text) {
    if (_stage == text) return;
    _stage = text;
    _notify();
  }

  /// Creates the file and delivers it. Returns false when creating or
  /// delivering failed (show your error message then); true otherwise,
  /// including when the user cancelled Save As. Ignored while busy.
  Future<bool> run(
    BuildContext context, {
    required Future<File> Function() createFile,
    String mimeType = FileExportService.xlsxMimeType,
    String? shareText,
    Rect? shareOrigin,
  }) async {
    if (_busy) return true;
    _busy = true;
    _stage = null;
    _notify();
    try {
      final file = await createFile();
      if (!file.existsSync()) {
        throw StateError('The exported file was not created.');
      }
      if (!context.mounted) return true;
      await deliver(
        context,
        file,
        mimeType: mimeType,
        shareText: shareText,
        shareOrigin: shareOrigin,
        onStage: setStage,
      );
      return true;
    } catch (error) {
      debugPrint('Export failed: $error');
      return false;
    } finally {
      _busy = false;
      _stage = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
