import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/services/list_excel_export_service.dart';

void main() {
  test('exports every supplied row with headers and numeric values', () async {
    final directory = await Directory.systemTemp.createTemp('list-export-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final file = await ListExcelExportService.export<_Row>(
      items: const [
        _Row('First', 12.5),
        _Row('Second', -4),
      ],
      columns: [
        ListExportColumn(
          label: 'No',
          value: (_, index) => index + 1,
        ),
        ListExportColumn(
          label: 'Name',
          value: (row, _) => row.name,
        ),
        ListExportColumn(
          label: 'Balance',
          value: (row, _) => row.balance,
        ),
      ],
      fileNamePrefix: 'supplier list',
      sheetName: 'Suppliers',
      outputDirectory: directory,
    );

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('.xlsx'));
    final workbook = Excel.decodeBytes(await file.readAsBytes());
    final rows = workbook.tables['Suppliers']!.rows;
    expect(rows, hasLength(3));
    expect(rows[0].map((cell) => cell?.value.toString()).toList(),
        ['No', 'Name', 'Balance']);
    expect(rows[1][0]?.value.toString(), '1');
    expect(rows[1][1]?.value.toString(), 'First');
    expect(rows[1][2]?.value, const DoubleCellValue(12.5));
    expect(rows[2][1]?.value.toString(), 'Second');
    expect(rows[2][2]?.value.toString(), '-4');
  });

  test('rejects an empty export', () async {
    expect(
      () => ListExcelExportService.export<_Row>(
        items: const [],
        columns: [
          ListExportColumn(label: 'Name', value: (row, _) => row.name),
        ],
        fileNamePrefix: 'suppliers',
        sheetName: 'Suppliers',
      ),
      throwsStateError,
    );
  });

  test('removes only stale exports with the same file prefix', () async {
    final directory = await Directory.systemTemp.createTemp('list-cleanup-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final stale = File(
      '${directory.path}${Platform.pathSeparator}suppliers-stale.xlsx',
    );
    final recent = File(
      '${directory.path}${Platform.pathSeparator}suppliers-recent.xlsx',
    );
    final unrelated = File(
      '${directory.path}${Platform.pathSeparator}orders-stale.xlsx',
    );
    for (final file in [stale, recent, unrelated]) {
      await file.writeAsBytes([1]);
    }
    await stale.setLastModified(
      DateTime.now().subtract(const Duration(hours: 25)),
    );
    await unrelated.setLastModified(
      DateTime.now().subtract(const Duration(hours: 25)),
    );

    await ListExcelExportService.export<_Row>(
      items: const [_Row('First', 1)],
      columns: [
        ListExportColumn(label: 'Name', value: (row, _) => row.name),
      ],
      fileNamePrefix: 'suppliers',
      sheetName: 'Suppliers',
      outputDirectory: directory,
    );

    expect(await stale.exists(), isFalse);
    expect(await recent.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  testWidgets('export button creates and shares the generated file once',
      (tester) async {
    late Directory directory;
    late File file;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('share-button-');
      file = File(
        '${directory.path}${Platform.pathSeparator}export.xlsx',
      );
      await file.writeAsBytes([1, 2, 3]);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
    });
    final createFile = Completer<File>();
    final shareFile = Completer<void>();
    File? sharedFile;
    var shareCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportShareButton(
            createFile: () => createFile.future,
            shareFile: (value, _) {
              shareCalls++;
              sharedFile = value;
              return shareFile.future;
            },
            label: 'Export',
            loadingLabel: 'Exporting...',
            tooltip: 'Export and share',
            errorMessage: 'Export failed',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Export'));
    await tester.pump();
    expect(find.text('Exporting...'), findsOneWidget);

    createFile.complete(file);
    await tester.pump();
    expect(shareCalls, 1);
    expect(sharedFile?.path, file.path);

    shareFile.complete();
    await tester.pump();
    expect(find.text('Export'), findsOneWidget);
    expect(shareCalls, 1);
  });

  testWidgets('export errors use the existing app notification banner',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportShareButton(
            createFile: () => Future<File>.error(StateError('failed')),
            shareFile: (_, __) async {},
            label: 'Export',
            loadingLabel: 'Exporting...',
            tooltip: 'Export and share',
            errorMessage: 'Could not export suppliers',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not export suppliers'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 5));
  });
}

class _Row {
  const _Row(this.name, this.balance);

  final String name;
  final double balance;
}
