import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/export/file_export_service.dart';

class _Picker extends FilePicker {
  _Picker(this.destination);

  final String? destination;
  String? suggestedName;
  List<String>? extensions;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    suggestedName = fileName;
    extensions = allowedExtensions;
    return destination;
  }
}

void main() {
  late Directory dir;
  late File source;
  late BuildContext pageContext;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('file-export-test-');
    source = File('${dir.path}/report.xlsx')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    dir.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            pageContext = context;
            return const SizedBox();
          }),
        ),
      );

  group('Windows Save As', () {
    testWidgets('copies the file to the chosen path and reports stages',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final picker = _Picker('${dir.path}/out.xlsx');
      FilePicker.platform = picker;
      await pumpApp(tester);
      final stages = <String>[];

      await tester.runAsync(() => FileExportService.deliver(
            pageContext,
            source,
            mimeType: FileExportService.xlsxMimeType,
            onStage: stages.add,
          ));

      expect(picker.suggestedName, 'report.xlsx');
      expect(picker.extensions, ['xlsx']);
      expect(File('${dir.path}/out.xlsx').readAsBytesSync(), [1, 2, 3]);
      expect(stages, [
        'list.export_waiting_save'.tr,
        'list.export_saving'.tr,
      ]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a cancelled dialog does nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      FilePicker.platform = _Picker(null);
      await pumpApp(tester);
      await tester.runAsync(() => FileExportService.deliver(
            pageContext,
            source,
            mimeType: FileExportService.xlsxMimeType,
          ));
      expect(dir.listSync(), hasLength(1));
      debugDefaultTargetPlatformOverride = null;
    });
    // The overwrite prompt for an added extension is covered end to end in
    // test/export_windows_save_test.dart (ExportShareButton delegates here).
  });

  group('ExportController', () {
    testWidgets('busy while running, stage forwarded, true on success',
        (tester) async {
      await pumpApp(tester);
      final gate = Completer<void>();
      final busyStates = <bool>[];
      final controller = ExportController(
        deliver: (context, file,
            {required mimeType, shareText, shareOrigin, onStage}) async {
          onStage?.call('Saving...');
          await gate.future;
        },
      );
      addTearDown(controller.dispose);
      controller.addListener(() => busyStates.add(controller.busy));

      final run = controller.run(pageContext, createFile: () async => source);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(controller.busy, isTrue);
      expect(controller.stage, 'Saving...');

      // A second run while busy is ignored.
      expect(await controller.run(pageContext, createFile: () async => source),
          isTrue);

      gate.complete();
      expect(await tester.runAsync(() => run), isTrue);
      expect(controller.busy, isFalse);
      expect(controller.stage, isNull);
      expect(busyStates.first, isTrue);
      expect(busyStates.last, isFalse);
    });

    testWidgets('false when the file cannot be created or delivered',
        (tester) async {
      await pumpApp(tester);
      final controller = ExportController(
        deliver: (context, file,
                {required mimeType, shareText, shareOrigin, onStage}) async =>
            throw StateError('share failed'),
      );
      addTearDown(controller.dispose);

      expect(
        await tester.runAsync(() => controller.run(pageContext,
            createFile: () async => File('${dir.path}/missing.xlsx'))),
        isFalse,
      );
      expect(
        await tester.runAsync(
            () => controller.run(pageContext, createFile: () async => source)),
        isFalse,
      );
      expect(controller.busy, isFalse);
    });
  });
}
