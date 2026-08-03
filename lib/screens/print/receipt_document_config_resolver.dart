import 'package:pos_machine/models/document_configurations.dart';

typedef DocumentConfigLookup = DocumentConfig? Function(String type);

/// Resolves the document configuration used by sales receipt printing.
///
/// Standard paper prefers the A4-specific record. Combined sales/return jobs
/// fall back to the normal bill records so a missing optional return template
/// does not make printing unavailable.
DocumentConfig? resolveReceiptDocumentConfig({
  required DocumentConfigLookup lookup,
  String? documentConfigType,
  required bool hasReturns,
  String? paperSize,
}) {
  final requestedType = documentConfigType?.trim();
  final isStandard = paperSize == 'A4' || paperSize == 'A5';

  DocumentConfig? firstMatch(Iterable<String> types) {
    for (final type in types) {
      final config = lookup(type);
      if (config != null) return config;
    }
    return null;
  }

  const billTypes = <String>['Bill', 'bill'];
  const billA4Types = <String>['Bill A4', 'bill_a4', 'bill-a4'];
  const salesReturnTypes = <String>[
    'Sales and Return Bill',
    'sales and return bill',
    'sales_and_return_bill',
    'sales-and-return-bill',
  ];
  const salesReturnA4Types = <String>[
    'Sales and Return Bill A4',
    'sales and return bill a4',
    'sales_and_return_bill_a4',
    'sales-and-return-bill-a4',
  ];

  DocumentConfig? resolveBill() => firstMatch(
        isStandard ? <String>[...billA4Types, ...billTypes] : billTypes,
      );

  DocumentConfig? resolveSalesAndReturnBill() => firstMatch(
        isStandard
            ? <String>[
                ...salesReturnA4Types,
                ...salesReturnTypes,
                ...billA4Types,
                ...billTypes,
              ]
            : <String>[...salesReturnTypes, ...billTypes],
      );

  if (requestedType != null && requestedType.isNotEmpty) {
    switch (requestedType.toLowerCase()) {
      case 'bill':
        return resolveBill();
      case 'sales and return bill':
      case 'sales_and_return_bill':
      case 'sales-and-return-bill':
        return resolveSalesAndReturnBill();
      default:
        return firstMatch(<String>[requestedType, requestedType.toLowerCase()]);
    }
  }

  if (hasReturns) return resolveSalesAndReturnBill();
  return resolveBill();
}
