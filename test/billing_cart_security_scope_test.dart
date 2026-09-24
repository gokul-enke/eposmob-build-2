import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodSource(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'Missing method marker: $marker');

  var parentheses = 0;
  var openBrace = -1;
  for (var index = start; index < source.length; index++) {
    if (source[index] == '(') parentheses++;
    if (source[index] == ')') parentheses--;
    if (source[index] == '{' && parentheses == 0) {
      openBrace = index;
      break;
    }
  }
  expect(openBrace, isNonNegative, reason: 'Missing method body: $marker');

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }

  fail('Unterminated method body: $marker');
}

void main() {
  final desktopSource =
      File('lib/features/billing/presentation/pages/billing_page.dart')
          .readAsStringSync();
  final mobileSource =
      File('lib/features/billing/presentation/pages/billing_page_mobile.dart')
          .readAsStringSync();

  test('desktop security gate is limited to explicit manual cart clear', () {
    final manualClear =
        _methodSource(desktopSource, 'Future<void> _clearCartManually()');
    expect(manualClear, contains('PosSecurityKeyDialog.verify'));

    for (final marker in [
      'Future<void> _saveOrder(',
      'Future<void> _saveOrderAndPrint()',
      'Future<void> _createOrderAndPrint()',
      'Future<void> _confirmOrder()',
    ]) {
      expect(
        _methodSource(desktopSource, marker),
        isNot(contains('_clearCartManually')),
        reason: '$marker must clear automatically after success',
      );
    }

    final quotation = _methodSource(
      desktopSource,
      'Future<void> _createQuotationFromCheckout(',
    );
    expect(quotation, isNot(contains('_clearCartManually')));
    expect(quotation, contains('_clearOrderWorkspace'));
  });

  test('mobile order completion never calls the manual cart-clear gate', () {
    final manualClear =
        _methodSource(mobileSource, 'Future<void> _clearCartManually()');
    expect(manualClear, contains('PosSecurityKeyDialog.verify'));

    for (final marker in [
      'Future<void> saveOrder()',
      'Future<void> saveOrderAndPrint()',
      'Future<void> createOrderAndPrint()',
      'Future<void> confirmOrder()',
    ]) {
      expect(
        _methodSource(mobileSource, marker),
        isNot(contains('_clearCartManually')),
        reason: '$marker must clear automatically after success',
      );
    }

    final quotation =
        _methodSource(mobileSource, 'Future<void> createQuotation(');
    expect(quotation, isNot(contains('_clearCartManually')));
    expect(quotation, contains('_controller.clearCartData(context)'));
  });

  test('automatic cart cleanup layers do not depend on the security dialog',
      () {
    for (final path in [
      'lib/providers/local_product_provider.dart',
      'lib/services/checkout_service.dart',
      'lib/features/billing/controllers/billing_mobile_controller.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('PosSecurityKeyDialog')),
        reason: '$path must remain independent of the manual UI gate',
      );
    }
  });
}
