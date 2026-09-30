import 'package:flutter/material.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';

import '../receipt_layout_params.dart';
import '../receipt_sections.dart';
import '../receipt_configuration_contract.dart';
import 'layout_rows.dart';

/// Shares PDF return metadata visibility and language decisions with thermal
/// themes while retaining each theme's dividers, item tables and totals.
void appendReturnMetadataRows(List<ReceiptRow> rows, ReceiptLayoutParams params,
    {required double scale, required double gap}) {
  final section = params.returnsSection;
  if (section == null) return;
  final rtl = !params.receiptLanguageMode.isEnglish;
  void block(String heading, List<(String, String)> values) {
    if (values.isEmpty) return;
    if (heading.isNotEmpty) {
      rows.add(TextRow(heading, isBold: true, scale: scale));
      rows.add(SpacingRow(gap));
    }
    for (final (label, value) in values) {
      final labelColumn = ReceiptTableColumn(label,
          weight: 0.45,
          align: rtl ? TextAlign.right : TextAlign.left,
          isBold: true,
          scale: scale);
      final valueColumn = ReceiptTableColumn(value,
          weight: 0.55,
          align: TextAlign.left,
          scale: scale,
          textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(value)
              ? TextDirection.rtl
              : TextDirection.ltr);
      rows.add(MultiLineReceiptTableRow(
          rtl ? [valueColumn, labelColumn] : [labelColumn, valueColumn]));
    }
    rows.add(SpacingRow(gap));
  }

  if (section.subtitle.isNotEmpty) {
    rows.add(TextRow(section.subtitle, scale: scale));
    rows.add(SpacingRow(gap));
  }
  block(section.supplierHeading, section.supplierRows);
  block(section.creditNoteHeading, section.creditNoteRows);
  block(section.customerHeading, section.customerRows);
  if (section.itemsHeading.isNotEmpty) {
    rows.add(TextRow(section.itemsHeading, isBold: true, scale: scale));
    rows.add(SpacingRow(gap));
  }
}

void appendReturnFooterRows(
    List<ReceiptRow> rows, ReceiptLayoutParams params) {
  final section = params.returnsSection;
  final remarks = section?.remarksRow;
  if (remarks != null) {
    rows.add(SpacingRow(4));
    rows.add(TextRow(remarks.$1, isBold: true, scale: 0.85));
    if (remarks.$2.isNotEmpty) {
      rows.add(TextRow(remarks.$2, scale: 0.85));
    }
  }
  final signatory = section?.signatory ?? '';
  if (signatory.isEmpty) return;
  rows.add(SpacingRow(20));
  rows.add(TextRow('____________________', scale: 0.85));
  rows.add(TextRow(signatory, scale: 0.85));
}

void appendReturnTaxSummaryRows(List<ReceiptRow> rows, ReceiptLayoutParams params,
    {required double scale}) {
  final summary = params.returnTaxSummary;
  if (summary == null) return;
  final rtl = !params.receiptLanguageMode.isEnglish;
  void tableRow(List<String> values, {bool bold = false}) {
    final cells = [
      for (final value in values)
        ReceiptTableColumn(value, weight: 1 / 3, align: TextAlign.center,
          isBold: bold, scale: scale,
          textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(value)
              ? TextDirection.rtl : TextDirection.ltr),
    ];
    rows.add(MultiLineReceiptTableRow(rtl ? cells.reversed.toList() : cells));
  }
  rows.add(SpacingRow(8));
  rows.add(TextRow(summary.heading, isBold: true, scale: scale));
  tableRow(summary.headers, bold: true);
  for (final row in summary.rows) {
    tableRow([row.$1, row.$2, row.$3]);
  }
  tableRow([summary.totalRow.$1, summary.totalRow.$2, summary.totalRow.$3], bold: true);
}

/// Dense return tables need full label/value rows on narrow thermal paper.
/// Returns false when the ordinary theme table has enough room.
bool appendDenseReturnItemRows(
    List<ReceiptRow> rows, ReceiptLayoutParams params,
    {required double scale, required double gap}) {
  final section = params.returnsSection;
  final maxColumns = params.is58mm ? 6 : 8;
  if (section == null || section.columns.length <= maxColumns) return false;
  final rtl = !params.receiptLanguageMode.isEnglish;
  for (var index = 0; index < section.lines.length; index++) {
    final line = section.lines[index];
    for (final column in section.columns) {
      final label = [column.label.arabic, column.label.english]
          .where((part) => part.isNotEmpty)
          .join('\n');
      final value = column.key == 'showReturnParticulars'
          ? params
              .itemNameLines(params.orderReturns!.returnItems![index])
              .join(' ')
          : line[column.key] ?? '';
      final labelCell = ReceiptTableColumn(label,
          weight: 0.62,
          align: rtl ? TextAlign.right : TextAlign.left,
          isBold: true,
          scale: scale);
      final valueCell = ReceiptTableColumn(value,
          weight: 0.38,
          align: rtl ? TextAlign.left : TextAlign.right,
          scale: scale,
          textDirection: RegExp(r'[\u0600-\u06ff]').hasMatch(value)
              ? TextDirection.rtl
              : TextDirection.ltr);
      rows.add(MultiLineReceiptTableRow(
          rtl ? [valueCell, labelCell] : [labelCell, valueCell]));
    }
    rows.add(SpacingRow(gap));
    if (index + 1 < section.lines.length) rows.add(StandardThinDividerRow());
  }
  return true;
}
