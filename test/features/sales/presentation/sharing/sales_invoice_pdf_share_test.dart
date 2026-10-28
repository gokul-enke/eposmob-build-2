import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/presentation/sharing/sales_invoice_pdf_share.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  final pdf = File(r'C:\Users\me\Documents/epos/Invoice_1.pdf');

  test('Windows shares the PDF by a backslash-only path', () async {
    ShareParams? sent;
    await shareInvoicePdf(pdf, text: 'Invoice', subject: 'Invoice #1',
        isWindows: true, share: (params) async {
      sent = params;
      return const ShareResult('', ShareResultStatus.unavailable);
    });

    final file = sent!.files!.single;
    expect(file.path, r'C:\Users\me\Documents\epos\Invoice_1.pdf');
    expect(file.mimeType, 'application/pdf');
    expect(sent!.text, 'Invoice');
    expect(sent!.title, 'Invoice #1');
  });

  test('Windows "unavailable" still counts as a shown sheet', () async {
    final result = await shareInvoicePdf(pdf,
        text: 'Invoice',
        subject: 'Invoice #1',
        isWindows: true,
        share: (_) async =>
            const ShareResult('', ShareResultStatus.unavailable));

    expect(result?.status, ShareResultStatus.unavailable);
  });

  test('other platforms keep the path as it is', () async {
    ShareParams? sent;
    await shareInvoicePdf(File('/data/epos/Invoice_1.pdf'),
        text: 'Invoice', subject: 'Invoice #1', isWindows: false,
        share: (params) async {
      sent = params;
      return const ShareResult('', ShareResultStatus.success);
    });

    expect(sent!.files!.single.path, '/data/epos/Invoice_1.pdf');
  });

  test('a share that throws returns null so the caller can fall back',
      () async {
    final result = await shareInvoicePdf(pdf,
        text: 'Invoice',
        subject: 'Invoice #1',
        isWindows: true,
        share: (_) async => throw Exception('no share UI'));

    expect(result, isNull);
  });

  test('windowsNativePath turns every slash into a backslash', () {
    expect(windowsNativePath('C:/a/b.pdf'), r'C:\a\b.pdf');
    expect(windowsNativePath(r'C:\a\b.pdf'), r'C:\a\b.pdf');
  });
}
