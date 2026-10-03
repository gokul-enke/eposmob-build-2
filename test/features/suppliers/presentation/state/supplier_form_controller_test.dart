import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/suppliers/presentation/state/supplier_form_controller.dart';

import '../widgets/form/supplier_form_harness.dart';

void main() {
  group('create mode', () {
    late RecordingSupplierProvider provider;
    late SupplierFormController form;

    setUp(() {
      provider = RecordingSupplierProvider();
      form = SupplierFormController.create(
        provider: provider,
        accessToken: 'token',
      );
    });

    tearDown(() => form.dispose());

    test('starts with a zero balance, to pay', () {
      expect(form.isEdit, isFalse);
      expect(form.balance.text, '0.00');
      expect(form.paymentType, SupplierPaymentType.toPay);
    });

    test('validates name, email and phone', () {
      expect(form.validateName(''), 'This field is required');
      expect(form.validateName('Acme'), isNull);
      expect(form.validateEmail(''), isNull);
      expect(form.validateEmail('bad'), 'Enter a valid email address');
      expect(form.validateEmail('a@b.co'), isNull);
      expect(form.validatePhone(''), 'Phone number is required');
      expect(form.validatePhone('123-456'), 'Enter a valid phone number');
      expect(form.validatePhone('123-456-7890'), isNull);
      expect(form.validateBalance('.'), 'Please enter a valid balance');
      expect(form.validateBalance('12.5'), isNull);
    });

    test('submit sends the create payload and returns the dialog result',
        () async {
      form.name.text = ' Acme ';
      form.email.text = 'acme@example.com ';
      form.phone.text = '987-654-3210';
      form.altPhone.text = '555-123-4567';
      form.address.text = ' Street ';
      form.taxNumber.text = 'TX ';
      form.crNumber.text = 'CR-1';
      form.balance.text = '25.50';
      form.setPaymentType(SupplierPaymentType.toReceive);

      final outcome = await form.submit();

      final call = provider.created.single;
      expect(call['name'], 'Acme');
      expect(call['email'], 'acme@example.com');
      expect(call['phone'], '9876543210');
      expect(call['altPhone'], '5551234567');
      expect(call['address'], 'Street');
      expect(call['taxNumber'], 'TX');
      expect(call['balance'], '25.50');
      expect(call['paymentStatus'], 'to_receive');
      expect(call['accessToken'], 'token');
      expect(call['kyc'], {'CR_NUMBER': 'CR-1'});

      expect(outcome, isA<SupplierCreated>());
      final created = outcome as SupplierCreated;
      expect(created.message, 'Created');
      expect(created.result['status'], 'success');
      expect(created.result['name'], ' Acme ');
      expect(created.result['phone'], '9876543210');
      expect(created.result['response'], provider.createResponse);
    });

    test('server validation errors are joined into one message', () async {
      provider.createResponse = {
        'status': 'error',
        'errors': {
          'phone': ['taken', 'invalid'],
          'name': 'missing',
        },
      };
      form.name.text = 'Acme';
      form.phone.text = '9876543210';

      final outcome = await form.submit();

      expect(outcome, isA<SupplierFormFailed>());
      expect(
          (outcome as SupplierFormFailed).message, 'taken, invalid\nmissing');
    });

    test('an exception becomes an error message', () async {
      provider.throwOnCall = Exception('offline');
      form.name.text = 'Acme';
      form.phone.text = '9876543210';

      final outcome = await form.submit();

      expect(outcome, isA<SupplierFormFailed>());
      expect((outcome as SupplierFormFailed).message, contains('offline'));
      expect(form.busy, isFalse);
    });

    test('clear resets the form for the next supplier', () {
      form.name.text = 'Acme';
      form.crNumber.text = 'CR';
      form.balance.text = '5';
      form.setPaymentType(SupplierPaymentType.toReceive);

      form.clear();

      expect(form.name.text, isEmpty);
      expect(form.crNumber.text, isEmpty);
      expect(form.balance.text, '0.00');
      expect(form.paymentType, SupplierPaymentType.toPay);
    });
  });

  group('edit mode', () {
    late RecordingSupplierProvider provider;
    late SupplierFormController form;

    setUp(() {
      provider = RecordingSupplierProvider();
      form = SupplierFormController.edit(
        sampleSupplier(),
        provider: provider,
        accessToken: 'token',
      );
    });

    tearDown(() => form.dispose());

    test('prefills the supplier', () {
      expect(form.isEdit, isTrue);
      expect(form.name.text, 'Acme Traders');
      expect(form.phone.text, '9876543210');
      expect(form.crNumber.text, 'CR-9');
      expect(form.vatNumber.text, 'VAT-LEGACY');
      expect(form.balance.text, '150.50');
      expect(form.paymentType, SupplierPaymentType.toReceive);
    });

    test('unknown payment types fall back to to pay', () {
      final other = SupplierFormController.edit(
        sampleSupplier(paymentType: 'weird'),
        provider: provider,
      );
      addTearDown(other.dispose);
      expect(other.paymentType, SupplierPaymentType.toPay);
    });

    test('does not check email or phone format', () {
      expect(form.validateEmail('not-an-email'), isNull);
      expect(form.validatePhone('123'), isNull);
      expect(form.validatePhone(' '), 'Phone number is required');
      expect(form.validateName(''), 'Name is required');
    });

    test('submit sends every field and keeps other KYC entries', () async {
      form.email.clear();
      form.vatNumber.text = 'VAT-2';
      form.balance.text = '20';
      form.setPaymentType(SupplierPaymentType.toPay);

      final outcome = await form.submit();

      final call = provider.updated.single;
      expect(call['id'], 7);
      expect(call['name'], 'Acme Traders');
      expect(call['phone'], '9876543210');
      expect(call['email'], isNull);
      expect(call['address'], 'Main Street 1');
      expect(call['altPhone'], '5551234567');
      expect(call['taxNumber'], 'TX-1');
      expect(call['balance'], 20.0);
      expect(call['paymentStatus'], 'to_pay');
      expect(call['kyc'], {
        'CR_NUMBER': 'CR-9',
        'VAT_NUMBER': 'VAT-2',
        'LICENSE': 'L-1',
      });
      expect(outcome, isA<SupplierUpdated>());
      expect(
        (outcome as SupplierUpdated).message,
        'Supplier information updated successfully',
      );
    });

    test('a failed update returns the server message', () async {
      provider.updateResponse = {'status': 'error', 'message': 'Nope'};

      final outcome = await form.submit();

      expect((outcome as SupplierFormFailed).message, 'Nope');
    });

    test('an exception returns the generic failure', () async {
      provider.throwOnCall = Exception('boom');

      final outcome = await form.submit();

      expect(
        (outcome as SupplierFormFailed).message,
        'Failed to update supplier',
      );
    });
  });
}
