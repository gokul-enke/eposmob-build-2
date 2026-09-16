import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_invoice_account_type.dart';
import 'package:pos_machine/models/get_voucher_account_type.dart';

void main() {
  group('account type response parsing', () {
    test('treats a null data payload as an empty voucher account map', () {
      final model = GetVoucherAccountTypesModel.fromJson({
        'status': 'success',
        'message': 'No account types configured',
        'data': null,
      });

      expect(model.getVoucherAccountTypesModelData, isEmpty);
      expect(model.toJson()['data'], isEmpty);
    });

    test('treats a non-map data payload as an empty invoice account map', () {
      final model = GetInvoiceAccountTypesModel.fromJson({
        'status': 'success',
        'message': 'No account types configured',
        'data': <dynamic>[],
      });

      expect(model.getInvoiceAccountTypesModelData, isEmpty);
      expect(model.toJson()['data'], isEmpty);
    });

    test('normalizes account type keys and values to strings', () {
      final model = GetVoucherAccountTypesModel.fromJson({
        'status': 'success',
        'data': <dynamic, dynamic>{1: 'Cash', '2': 42, 'ignored': null},
      });

      expect(model.getVoucherAccountTypesModelData, <String, String>{
        '1': 'Cash',
        '2': '42',
      });
    });
  });
}
