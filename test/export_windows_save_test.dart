import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/export_share_button.dart';

class _Picker extends FilePicker {
  _Picker(this.destination, {this.gate});
  final String? destination;
  final Completer<String?>? gate;
  int calls = 0;
  String? suggestedName;
  bool lockedParent = false;
  @override
  Future<String?> saveFile(
      {String? dialogTitle,
      String? fileName,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Uint8List? bytes,
      bool lockParentWindow = false}) async {
    calls++;
    lockedParent = lockParentWindow;
    suggestedName = fileName;
    return gate == null ? destination : await gate!.future;
  }
}

void main() {
  setUpAll(() => FilePicker.platform = _Picker(null));
  testWidgets(
      'export progress advances to Save As and resets after cancellation',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final directory =
        Directory.systemTemp.createTempSync('export-progress-test-');
    final file = File('${directory.path}/test.xlsx')..writeAsBytesSync([1]);
    final create = Completer<File>();
    final save = Completer<String?>();
    final progress = ValueNotifier<String?>('Fetching page 1 of 2');
    FilePicker.platform = _Picker(null, gate: save);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      progress.dispose();
      directory.deleteSync(recursive: true);
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExportShareButton(
      createFile: () => create.future,
      progressLabel: progress,
      label: 'Export',
      loadingLabel: 'Exporting',
      tooltip: 'Export',
      errorMessage: 'Failed',
      mimeType: 'application/xlsx',
    ))));
    final idleSize = tester.getSize(find.byType(FilledButton));
    await tester.tap(find.text('Export'));
    await tester.pump();
    progress.value =
        'Fetching page 999 of 1000 with a very long progress message';
    await tester.pump();
    expect(tester.getSize(find.byType(FilledButton)), idleSize);
    expect(find.byTooltip(progress.value!), findsOneWidget);
    progress.value = 'Fetching page 1 of 2';
    await tester.pump();
    expect(find.text('Fetching page 1 of 2'), findsOneWidget);
    progress.value = 'Creating Excel';
    await tester.pump();
    expect(find.text('Creating Excel'), findsOneWidget);
    create.complete(file);
    await tester.pumpAndSettle();
    expect(find.text('list.export_waiting_save'.tr), findsOneWidget);
    save.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
  for (final replace in [false, true]) {
    testWidgets('extensionless save confirms overwrite: $replace',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final directory =
          Directory.systemTemp.createTempSync('overwrite-confirm-test-');
      final source = File('${directory.path}/source.xlsx')
        ..writeAsBytesSync([1, 2]);
      final saved = File('${directory.path}/saved.xlsx')..writeAsBytesSync([9]);
      final picker = _Picker('${directory.path}/saved');
      FilePicker.platform = picker;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        directory.deleteSync(recursive: true);
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ExportShareButton(
        createFile: () async => source,
        label: 'Export',
        loadingLabel: 'Exporting',
        tooltip: 'Export',
        errorMessage: 'Failed',
        mimeType: 'application/xlsx',
      ))));
      await tester.runAsync(() async {
        await tester.tap(find.text('Export'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(saved.readAsBytesSync(), [9]);
      await tester.runAsync(() async {
        await tester.tap(find.descendant(
            of: find.byType(AlertDialog),
            matching:
                replace ? find.byType(FilledButton) : find.byType(TextButton)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(saved.readAsBytesSync(), replace ? [1, 2] : [9]);
      expect(find.text('Export'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final cancel in [false, true]) {
    testWidgets(
        cancel
            ? 'Windows save cancellation resets the button'
            : 'Windows export saves the generated bytes without native sharing',
        (tester) async {
      final originalPicker = FilePicker.platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final directory =
          Directory.systemTemp.createTempSync('windows-export-test-');
      final source = File('${directory.path}/source.xlsx');
      source.writeAsBytesSync([1, 2, 3, 4]);
      final saved = File('${directory.path}/saved.xlsx');
      final picker = _Picker(cancel ? null : saved.path);
      FilePicker.platform = picker;
      addTearDown(() {
        FilePicker.platform = originalPicker;
        debugDefaultTargetPlatformOverride = null;
        directory.deleteSync(recursive: true);
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ExportShareButton(
        createFile: () async => source,
        label: 'Export',
        loadingLabel: 'Exporting...',
        tooltip: 'Export',
        errorMessage: 'Export failed',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ))));
      await tester.runAsync(() async {
        await tester.tap(find.text('Export'));
        for (var attempt = 0; attempt < 100; attempt++) {
          if (cancel ? picker.calls > 0 : saved.existsSync()) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (!cancel) {
          expect(await saved.readAsBytes(), [1, 2, 3, 4]);
        }
      });
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(picker.suggestedName, 'source.xlsx');
      expect(picker.lockedParent, isTrue);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Export failed'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
