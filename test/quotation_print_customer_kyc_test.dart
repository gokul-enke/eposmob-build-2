import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
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

  group('order-style customer_details on quotation details', () {
    const service = QuotationPrintService();

    // Current quotation-details shape, as returned by the API today.
    Map<String, dynamic> currentResponse() => {
          'id': 170,
          'quotation_number': 'QTN-00126',
          'customer': {
            'id': 294,
            'name': 'Gokul VAT Test',
            'phone': '3213213212',
            'is_inline': false,
          },
          'kyc_info': {'cr_number': '1234567890', 'vat_number': '654654546546'},
          'address_id': null,
          'address': null,
          'delivery_method_name': 'Store Takeaway',
        };

    // Proposed shape: the current keys unchanged, plus the order-details
    // `customer_details` block.
    Map<String, dynamic> proposedResponse() => {
          ...currentResponse(),
          'customer_details': {
            'name': 'Gokul VAT Test',
            'email': 'accounts@example.com',
            'phone': '3213213212',
            'alternate_phone': '3232656532',
            'customer_id': 294,
            'customer_type': 'B2B',
            'address': [
              {
                'id': 28,
                'address': 'Calicut',
                'city': null,
                'landmark': 'Poolakode',
                'state_id': 37,
              },
            ],
            'customer_balance': -232,
          },
        };

    test('current response still parses and prints VAT / CR, no address', () {
      final payload = service
          .buildPrintPayload(QuotationDetailsData.fromJson(currentResponse()));

      expect(payload['customerName'], 'Gokul VAT Test');
      expect(payload['customerVatNumber'], '654654546546');
      expect(payload['customerCrNumber'], '1234567890');
      expect(payload['customerAddress'], isNull);
      expect(payload['customerEmail'], isNull);
    });

    test('customer_details adds address, email, alternate phone and type', () {
      final details = QuotationDetailsData.fromJson(proposedResponse());
      final payload = service.buildPrintPayload(details);

      expect(details.customer?.id, 294);
      expect(details.customer?.isInline, isFalse);
      expect(payload['customerAddress'], 'Calicut, Poolakode');
      expect(payload['customerEmail'], 'accounts@example.com');
      expect(payload['customerAlternatePhone'], '3232656532');
      expect(payload['customerType'], 'B2B');
      expect(payload['customerVatNumber'], '654654546546');
    });

    test('customer_details alone (no customer block) is enough', () {
      final json = proposedResponse()..remove('customer');
      final details = QuotationDetailsData.fromJson(json);

      expect(details.customer?.id, 294);
      expect(details.customer?.name, 'Gokul VAT Test');
      expect(details.customerAddressForDisplay, 'Calicut, Poolakode');
    });

    test('the quotation delivery address wins over the customer address', () {
      final details = QuotationDetailsData.fromJson({
        ...proposedResponse(),
        'address_id': 31,
        'address': {
          'address': 'King Fahd Road',
          'city': 'Riyadh',
          'state': {'id': 1, 'name': 'Riyadh Region'},
          'pincode': {'pin_code': '12211'},
        },
      });

      expect(details.customerAddressForDisplay,
          'King Fahd Road, Riyadh, Riyadh Region, 12211');
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
