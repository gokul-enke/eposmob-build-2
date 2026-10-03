import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/export/file_export_service.dart';

/// An [ExportController] that keeps the page's `createFile` instead of
/// saving or sharing, so a test can build the workbook itself.
class CapturingExport extends ExportController {
  Future<File> Function()? createFile;
  int runs = 0;

  @override
  Future<bool> run(BuildContext context,
      {required Future<File> Function() createFile,
      String mimeType = FileExportService.xlsxMimeType,
      String? shareText,
      Rect? shareOrigin}) async {
    runs++;
    this.createFile = createFile;
    return true;
  }
}

/// Points path_provider at a fresh temp directory for the test.
Future<void> useTempExportDirectory(WidgetTester tester, String prefix) async {
  final dir =
      (await tester.runAsync(() => Directory.systemTemp.createTemp(prefix)))!;
  addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => dir.path);
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
}
