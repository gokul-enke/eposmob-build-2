import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/receipt_document_config_resolver.dart';

void main() {
  DocumentConfig config(String type) => DocumentConfig(type: type);

  test('combined standard print prefers Sales and Return Bill A4', () {
    final configs = <String, DocumentConfig>{
      'Sales and Return Bill': config('Sales and Return Bill'),
      'Sales and Return Bill A4': config('Sales and Return Bill A4'),
      'Bill A4': config('Bill A4'),
    };

    final resolved = resolveReceiptDocumentConfig(
      lookup: (type) => configs[type],
      documentConfigType: 'Sales and Return Bill',
      hasReturns: true,
      paperSize: 'A4',
    );

    expect(resolved?.type, 'Sales and Return Bill A4');
  });

  test('combined standard print falls back through return and bill configs',
      () {
    final returnConfigs = <String, DocumentConfig>{
      'Sales and Return Bill': config('Sales and Return Bill'),
      'Bill A4': config('Bill A4'),
    };
    final billConfigs = <String, DocumentConfig>{
      'Bill A4': config('Bill A4'),
    };

    expect(
      resolveReceiptDocumentConfig(
        lookup: (type) => returnConfigs[type],
        documentConfigType: 'Sales and Return Bill',
        hasReturns: true,
        paperSize: 'A5',
      )?.type,
      'Sales and Return Bill',
    );
    expect(
      resolveReceiptDocumentConfig(
        lookup: (type) => billConfigs[type],
        documentConfigType: 'Sales and Return Bill',
        hasReturns: true,
        paperSize: 'A4',
      )?.type,
      'Bill A4',
    );
  });

  test('thermal combined print uses non-A4 return configuration', () {
    final configs = <String, DocumentConfig>{
      'Sales and Return Bill': config('Sales and Return Bill'),
      'Sales and Return Bill A4': config('Sales and Return Bill A4'),
    };

    final resolved = resolveReceiptDocumentConfig(
      lookup: (type) => configs[type],
      documentConfigType: 'Sales and Return Bill',
      hasReturns: true,
      paperSize: '80mm',
    );

    expect(resolved?.type, 'Sales and Return Bill');
  });

  test('normal standard print continues to prefer Bill A4', () {
    final configs = <String, DocumentConfig>{
      'Bill': config('Bill'),
      'Bill A4': config('Bill A4'),
    };

    final resolved = resolveReceiptDocumentConfig(
      lookup: (type) => configs[type],
      documentConfigType: 'Bill',
      hasReturns: false,
      paperSize: 'A4',
    );

    expect(resolved?.type, 'Bill A4');
  });
}
