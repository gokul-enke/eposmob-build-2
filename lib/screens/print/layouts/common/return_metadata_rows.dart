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
  block(section.creditNoteHeading, section.creditNoteRows);
  block(section.customerHeading, section.customerRows);
  if (section.itemsHeading.isNotEmpty) {
    rows.add(TextRow(section.itemsHeading, isBold: true, scale: scale));
    rows.add(SpacingRow(gap));
  }
}

void appendReturnSignatoryRows(List<ReceiptRow> rows, ReceiptLayoutParams params) {
  final signatory = params.returnsSection?.signatory ?? '';
  if (signatory.isEmpty) return;
  rows.add(SpacingRow(20));
  rows.add(TextRow('____________________', scale: 0.85));
  rows.add(TextRow(signatory, scale: 0.85));
}
