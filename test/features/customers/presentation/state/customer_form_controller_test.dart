import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/data/customer_payloads.dart';
import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_form_controller.dart';

class FakeCustomerRepository extends CustomerRepository {
  CustomerFields? createdFields;
  String? createdStoreId;
  CustomerFields? updatedFields;
  int? updatedId;
  int createCalls = 0;
  int updateCalls = 0;
  dynamic createResponse = {'status': 'success', 'message': 'Created'};
  dynamic updateResponse = {'status': 'success', 'message': 'Updated'};
  Completer<void>? gate;

  @override
  Future<dynamic> create(
    String accessToken,
    CustomerFields fields, {
    required String storeId,
  }) async {
    createCalls++;
    createdFields = fields;
    createdStoreId = storeId;
    await gate?.future;
    return createResponse;
  }

  @override
  Future<dynamic> update(
    String accessToken,
    int customerId,
    CustomerFields fields, {
    int? storeId,
  }) async {
    updateCalls++;
    updatedId = customerId;
    updatedFields = fields;
    return updateResponse;
  }
}

CustomerListModelData _customer({String? customerType, double? balance}) =>
    CustomerListModelData(
      id: 42,
      name: 'Jane Mary Doe',
      email: 'jane@example.com',
      phone: '5551234567',
      altPhone: '',
      gender: 'female',
      dob: '1990-05-01',
      balance: balance ?? -20,
      paymentType: 'to_pay',
      customerType: customerType ?? 'B2C',
      kyc: [Kyc(key: 'CR Number', value: 'CR-1')],
    );

void main() {
  late FakeCustomerRepository repository;

  setUp(() => repository = FakeCustomerRepository());

  CustomerFormController create({
    bool business = false,
    String? phone,
    String? name,
    int? persisted,
  }) =>
      CustomerFormController.create(
        repository: repository,
        accessToken: 'token',
        businessFieldsEnabled: business,
        initialPhone: phone,
        initialName: name,
        persistedStoreId: () async => persisted,
      );

  group('create mode', () {
    test('prefills phone and splits the name', () {
      final form = create(phone: '98765', name: '  John  Ronald Doe ');
      addTearDown(form.dispose);
      expect(form.firstName.text, 'John');
      expect(form.lastName.text, 'Ronald Doe');
      expect(form.showPhoneErrorOnLoad, isTrue);
      expect(form.balance.text, '0');
      expect(form.paymentType, CustomerPaymentType.toReceive);
    });

    test('sends the full payload and returns the dialog result', () async {
      final form = create(phone: '987-6543-210', name: 'John Doe');
      addTearDown(form.dispose);
      form.email.text = 'john@example.com';
      form.building.text = ' Tower 1 ';
      form.streetAddress.text = 'Main Road';
      form.country.text = 'India';
      form.altPhone.text = ' 111 ';
      form.setGender('male');
      form.setDateOfBirth(DateTime(1990, 2, 3));

      final outcome = await form.submit(activeStoreId: 7);

      expect(outcome, isA<CustomerCreated>());
      final created = outcome as CustomerCreated;
      expect(created.message, 'Created');
      expect(created.result['status'], 'success');
      expect(created.result['phone'], '9876543210');
      expect(created.result['name'], 'John Doe');
      expect(created.result['response'], repository.createResponse);

      final fields = repository.createdFields!;
      expect(repository.createdStoreId, '7');
      expect(fields.phone, '9876543210');
      expect(fields.name, 'John Doe');
      expect(fields.email, 'john@example.com');
      expect(fields.address, 'Tower 1, Main Road');
      expect(fields.country, 'India');
      expect(fields.city, '');
      expect(fields.state, '');
      expect(fields.pincode, '');
      expect(fields.balance, '0');
      expect(fields.paymentType, 'to_receive');
      expect(fields.altPhone, '111');
      expect(fields.gender, 'male');
      expect(fields.dob, '1990-02-03');
      expect(fields.customerType, 'B2C');
      expect(fields.crNumber, '');
      expect(fields.vatNumber, '');
    });

    test('falls back to the stored store id, then 1', () async {
      final stored = create(phone: '9876543210', persisted: 3);
      addTearDown(stored.dispose);
      await stored.submit();
      expect(repository.createdStoreId, '3');

      final none = create(phone: '9876543210');
      addTearDown(none.dispose);
      await none.submit();
      expect(repository.createdStoreId, '1');
    });

    test('B2B fields are required and sent only when enabled', () async {
      final form = create(business: true, phone: '9876543210');
      addTearDown(form.dispose);
      expect(form.validateCrNumber(''), isNull);
      form.setCustomerType('B2B');
      expect(form.validateCrNumber(' '), isNotNull);
      expect(form.validateVatNumber(''), isNotNull);
      form.crNumber.text = ' CR9 ';
      form.vatNumber.text = 'VAT9';
      await form.submit();
      expect(repository.createdFields!.customerType, 'B2B');
      expect(repository.createdFields!.crNumber, 'CR9');
      expect(repository.createdFields!.vatNumber, 'VAT9');

      final disabled = create(phone: '9876543210');
      addTearDown(disabled.dispose);
      disabled.setCustomerType('B2B');
      disabled.crNumber.text = 'CR9';
      await disabled.submit();
      expect(repository.createdFields!.customerType, 'B2C');
      expect(repository.createdFields!.crNumber, '');
    });

    test('validates phone and email', () {
      final form = create();
      addTearDown(form.dispose);
      expect(form.validatePhone(''), isNotNull);
      expect(form.validatePhone('123-4567'), isNotNull);
      expect(form.validatePhone('123-4567-890'), isNull);
      expect(form.validateEmail(''), isNull);
      expect(form.validateEmail('bad@'), isNotNull);
      expect(form.validateEmail('a.b@c.io'), isNull);
      expect(form.validateFirstName(''), isNull);
      expect(form.validateBalance('.'), isNull);
    });

    test('requires a payment type', () async {
      final form = create(phone: '9876543210');
      addTearDown(form.dispose);
      form.setPaymentType(CustomerPaymentType.none);
      final outcome = await form.submit();
      expect(outcome, isA<CustomerFormFailed>());
      expect(repository.createCalls, 0);
    });

    test('is busy while saving and ignores a second submit', () async {
      final form = create(phone: '9876543210');
      addTearDown(form.dispose);
      repository.gate = Completer<void>();
      final pending = form.submit();
      await Future<void>.delayed(Duration.zero);
      expect(form.busy, isTrue);
      final second = await form.submit();
      expect(second, isA<CustomerFormFailed>());
      repository.gate!.complete();
      await pending;
      expect(form.busy, isFalse);
      expect(repository.createCalls, 1);
    });

    test('joins server errors into the failure message', () async {
      repository.createResponse = {
        'status': 'error',
        'message': 'Invalid',
        'errors': {
          'phone': ['taken', 'bad'],
          'email': 'wrong',
        },
      };
      final form = create(phone: '9876543210');
      addTearDown(form.dispose);
      final outcome = await form.submit();
      expect((outcome as CustomerFormFailed).message, 'taken, bad\nwrong');
    });

    test('clear empties the form', () {
      final form = create(phone: '9876543210', name: 'John');
      addTearDown(form.dispose);
      form.setGender('male');
      form.clear();
      expect(form.phone.text, isEmpty);
      expect(form.firstName.text, isEmpty);
      expect(form.gender, isNull);
      expect(form.paymentType, CustomerPaymentType.toReceive);
    });
  });

  group('edit mode', () {
    CustomerFormController edit(CustomerListModelData customer,
            {bool business = false}) =>
        CustomerFormController.edit(
          customer,
          repository: repository,
          accessToken: 'token',
          businessFieldsEnabled: business,
        );

    test('initialises from the customer', () {
      final form = edit(_customer(), business: true);
      addTearDown(form.dispose);
      expect(form.isEdit, isTrue);
      expect(form.firstName.text, 'Jane');
      expect(form.lastName.text, 'Mary Doe');
      expect(form.balance.text, '20.00');
      expect(form.paymentType, CustomerPaymentType.toPay);
      expect(form.crNumber.text, 'CR-1');
      expect(form.dateOfBirth.text, '1990-05-01');
    });

    test('sends nothing when nothing changed', () async {
      final form = edit(_customer());
      addTearDown(form.dispose);
      expect(form.buildEditChanges(), isNull);
      expect(await form.submit(), isA<CustomerUnchanged>());
      expect(repository.updateCalls, 0);
    });

    test('sends only the changed fields', () async {
      final form = edit(_customer());
      addTearDown(form.dispose);
      form.email.text = 'new@example.com';
      final outcome = await form.submit();

      expect(outcome, isA<CustomerUpdated>());
      expect(repository.updatedId, 42);
      final fields = repository.updatedFields!;
      expect(fields.email, 'new@example.com');
      for (final value in [
        fields.phone,
        fields.name,
        fields.altPhone,
        fields.gender,
        fields.dob,
        fields.balance,
        fields.paymentType,
        fields.customerType,
        fields.crNumber,
        fields.vatNumber,
        fields.address,
        fields.city,
      ]) {
        expect(value, isNull);
      }
      final updated = (outcome as CustomerUpdated).customer;
      expect(updated.email, 'new@example.com');
      expect(updated.id, 42);
      expect(updated.kyc, isNotEmpty);
    });

    test('signs the balance from the payment type', () async {
      final form = edit(_customer());
      addTearDown(form.dispose);
      form.balance.text = '30';
      form.setPaymentType(CustomerPaymentType.toReceive);
      await form.submit();
      expect(repository.updatedFields!.balance, '30.00');
      expect(repository.updatedFields!.paymentType, 'to_receive');
    });

    test('leaves hidden business fields alone', () async {
      final form = edit(_customer(customerType: 'B2B'));
      addTearDown(form.dispose);
      form.phone.text = '5550000000';
      await form.submit();
      expect(repository.updatedFields!.phone, '5550000000');
      expect(repository.updatedFields!.customerType, isNull);
      expect(repository.updatedFields!.crNumber, isNull);
    });

    test('sends business fields when enabled', () async {
      final form = edit(_customer(), business: true);
      addTearDown(form.dispose);
      form.setCustomerType('B2B');
      form.vatNumber.text = 'VAT1';
      await form.submit();
      expect(repository.updatedFields!.customerType, 'B2B');
      expect(repository.updatedFields!.vatNumber, 'VAT1');
      expect(repository.updatedFields!.crNumber, isNull);
    });

    test('edit validation rules', () {
      final form = edit(_customer());
      addTearDown(form.dispose);
      expect(form.validateFirstName(''), isNotNull);
      expect(form.validatePhone('123'), isNull);
      expect(form.validatePhone(''), isNotNull);
      expect(form.validateBalance('.'), isNotNull);
      expect(form.validateBalance('12.5'), isNull);
    });

    test('reports a message map from a failed update', () async {
      repository.updateResponse = {
        'status': 'error',
        'message': {
          'phone': ['taken'],
        },
      };
      final form = edit(_customer());
      addTearDown(form.dispose);
      form.phone.text = '5550000000';
      final outcome = await form.submit();
      expect((outcome as CustomerFormFailed).message, 'phone: taken');
    });

    test('asks to log in again without a token', () async {
      final form = CustomerFormController.edit(
        _customer(),
        repository: repository,
      );
      addTearDown(form.dispose);
      form.phone.text = '5550000000';
      expect(await form.submit(), isA<CustomerFormFailed>());
      expect(repository.updateCalls, 0);
    });
  });

  test('location names match loosely', () {
    expect(LocationNameMatcher.matches('Riyadh Province', 'riyadh'), isTrue);
    expect(LocationNameMatcher.matches('Ernakulam', 'Ernakulum'), isTrue);
    expect(LocationNameMatcher.matches('Kerala', 'Punjab'), isFalse);
  });
}
