import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ListExportColumn<T> {
  const ListExportColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final Object? Function(T item, int index) value;
}

/// Creates share-ready Excel workbooks from arbitrary list data.
class ListExcelExportService {
  const ListExcelExportService._();

  /// Convert monetary values only; preserve invalid input rather than dropping it.
  static Object? numericValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.replaceAll(',', '').trim());
    return number != null && number.isFinite ? number : value;
  }

  static const staleExportAge = Duration(hours: 24);

  static Future<File> export<T>({
    required List<T> items,
    required List<ListExportColumn<T>> columns,
    required String fileNamePrefix,
    required String sheetName,
    Directory? outputDirectory,
  }) async {
    if (items.isEmpty) {
      throw StateError('There are no rows to export.');
    }
    if (columns.isEmpty) {
      throw StateError('There are no columns to export.');
    }

    final rows = <List<Object?>>[
      [for (final column in columns) column.label],
      for (var index = 0; index < items.length; index++)
        [for (final column in columns) column.value(items[index], index)],
    ];
    final safeSheetName = _safeSheetName(sheetName);
    // Pass only cell data to the worker, never column callbacks or UI state.
    final bytes = await _encodeInIsolate(rows, safeSheetName, columns.length);
    final directory = outputDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp = '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}-'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final safePrefix = fileNamePrefix
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final prefix = safePrefix.isEmpty ? 'export' : safePrefix;
    await _deleteStaleExports(
      directory: directory,
      fileNamePrefix: prefix,
      cutoff: now.subtract(staleExportAge),
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}$prefix-$timestamp.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _deleteStaleExports({
    required Directory directory,
    required String fileNamePrefix,
    required DateTime cutoff,
  }) async {
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('$fileNamePrefix-') ||
            !name.toLowerCase().endsWith('.xlsx')) {
          continue;
        }
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // Cleanup is best effort and must never block a new export.
        }
      }
    } on FileSystemException {
      // The export itself can still proceed when old files cannot be listed.
    }
  }

  static String _safeSheetName(String value) {
    final sanitized =
        value.trim().replaceAll(RegExp(r'''[\\/*?:\[\]]'''), ' ').trim();
    if (sanitized.isEmpty) return 'Export';
    return sanitized.length <= 31 ? sanitized : sanitized.substring(0, 31);
  }
}

List<int> _encodeWorkbook(
  List<List<Object?>> rows,
  String sheetName,
  int columnCount,
) {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', sheetName);
  final sheet = excel[sheetName];
  for (var index = 0; index < columnCount; index++) {
    sheet.setColumnWidth(index, 20);
  }
  for (final row in rows) {
    sheet.appendRow([for (final value in row) _cellValue(value)]);
  }

  final encoded = excel.encode() ??
      (throw StateError('Could not encode the Excel workbook.'));

  // excel 4.0.6 can leave the worksheet dimension at A1. Correcting it keeps
  // every exported row visible in readers that trust that metadata.
  final archive = ZipDecoder().decodeBytes(encoded);
  const worksheetPath = 'xl/worksheets/sheet1.xml';
  final worksheet = archive.findFile(worksheetPath);
  if (worksheet == null) {
    throw StateError('The Excel workbook is missing its worksheet.');
  }
  final xml = utf8.decode(worksheet.content as List<int>);
  final dimension = RegExp(r'<dimension ref="[^"]*"\s*/>');
  if (!dimension.hasMatch(xml)) {
    throw StateError('The Excel worksheet has no dimension.');
  }
  final lastColumn = _excelColumnName(columnCount);
  final corrected = xml.replaceFirst(
    dimension,
    '<dimension ref="A1:$lastColumn${rows.length}"/>',
  );
  final correctedBytes = utf8.encode(corrected);
  archive.addFile(
    ArchiveFile(worksheetPath, correctedBytes.length, correctedBytes),
  );
  return ZipEncoder().encode(archive) ??
      (throw StateError('Could not finalize the Excel workbook.'));
}

CellValue? _cellValue(Object? value) {
  if (value == null) return null;
  if (value is num) return DoubleCellValue(value.toDouble());
  return TextCellValue(value.toString());
}

String _excelColumnName(int columnCount) {
  var value = columnCount;
  var name = '';
  while (value > 0) {
    value--;
    name = String.fromCharCode('A'.codeUnitAt(0) + (value % 26)) + name;
    value ~/= 26;
  }
  return name;
}

Future<List<int>> _encodeInIsolate(
        List<List<Object?>> rows, String sheetName, int columnCount) =>
    Isolate.run(() => _encodeWorkbook(rows, sheetName, columnCount));
