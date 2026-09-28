import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/services/quotation_print_service.dart';

void main() {
  group('QuotationCustomer KYC parsing', () {
    test('reads VAT / CR from the customer kyc list', () {
      final details = QuotationDetailsData.fromJson({
        'id': 1,
        'customer': {
          'id': 7,
          'name': 'Acme Trading',
          'customer_type': 'b2b',
          'kyc': [
            {'key': 'VAT_NUMBER', 'value': ' 310000000000003 '},
            {'key': 'CR NUMBER', 'value': '1010101010'},
          ],
        },
      });

      expect(details.customer?.vatNumber, '310000000000003');
      expect(details.customer?.crNumber, '1010101010');
      expect(details.customer?.customerType, 'b2b');
    });

    test('reads VAT / CR from a top-level kyc_info', () {
      final details = QuotationDetailsData.fromJson({
        'id': 1,
        'customer': {'id': 7, 'name': 'Acme Trading'},
        'kyc_info': {'vat_number': '300', 'cr_number': '400'},
      });

      expect(details.customer?.vatNumber, '300');
      expect(details.customer?.crNumber, '400');
    });

    test('inline customers pick up kyc_info too', () {
      final details = QuotationDetailsData.fromJson({
        'id': 1,
        'customer_name': 'Walk-in Co',
        'kyc_info': {'vat_number': '300', 'cr_number': ''},
      });

      expect(details.customer?.isInline, isTrue);
      expect(details.customer?.vatNumber, '300');
      expect(details.customer?.crNumber, isNull);
    });
  });

  group('QuotationPrintService payload', () {
    const service = QuotationPrintService();

    QuotationDetailsData quotationWithKyc() => QuotationDetailsData.fromJson({
          'id': 1,
          'customer': {
            'id': 7,
            'name': 'Acme Trading',
            'customer_type': 'b2b',
            'vat_number': '111',
            'cr_number': '222',
          },
        });

    test('falls back to the quotation customer (list reprint)', () {
      final payload = service.buildPrintPayload(quotationWithKyc());

      expect(payload['customerVatNumber'], '111');
      expect(payload['customerCrNumber'], '222');
      expect(payload['customerType'], 'b2b');
    });

    test('caller values win over the quotation customer', () {
      final payload = service.buildPrintPayload(
        quotationWithKyc(),
        customerType: 'business',
        customerVatNumber: '999',
        customerCrNumber: '888',
      );

      expect(payload['customerVatNumber'], '999');
      expect(payload['customerCrNumber'], '888');
      expect(payload['customerType'], 'business');
    });

    test('blank caller values do not hide the quotation customer values', () {
      final payload = service.buildPrintPayload(
        quotationWithKyc(),
        customerVatNumber: '  ',
        customerCrNumber: '',
      );

      expect(payload['customerVatNumber'], '111');
      expect(payload['customerCrNumber'], '222');
    });

    test('no KYC anywhere leaves VAT / CR null', () {
      final payload = service.buildPrintPayload(QuotationDetailsData.fromJson({
        'id': 1,
        'customer': {'id': 7, 'name': 'Walk-in'},
      }));

      expect(payload['customerVatNumber'], isNull);
      expect(payload['customerCrNumber'], isNull);
    });

    test('billing customer KYC helpers match checkout key handling', () {
      final kyc = [
        Kyc(key: 'vat number', value: '310'),
        Kyc(key: 'COMMERCIAL_REGISTRATION', value: '101'),
      ];

      expect(QuotationPrintService.vatNumberFromKyc(kyc), '310');
      expect(QuotationPrintService.crNumberFromKyc(kyc), '101');
      expect(QuotationPrintService.vatNumberFromKyc(null), isNull);
    });
  });
}
