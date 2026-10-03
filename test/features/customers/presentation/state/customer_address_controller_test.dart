import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_address_controller.dart';

class _Calls {
  final reloads = <(String, int)>[];
  final creates = <(String, Map<String, dynamic>)>[];
  final updates = <(String, int, Map<String, dynamic>)>[];
}

CustomerAddressController _controller(
  _Calls calls, {
  CustomerListModelData? customer,
  String? token = 'tok',
  dynamic reloadResponse,
  dynamic saveResponse,
  Object? saveError,
}) {
  return CustomerAddressController(
    customer: customer ??
        CustomerListModelData(
          id: 7,
          name: 'Asha',
          phone: '555',
          addresses: [Address(id: 1, address: 'Old Street', type: 'Home')],
        ),
    readToken: () async => token,
    reloadCustomer: (t, id) async {
      calls.reloads.add((t, id));
      return reloadResponse;
    },
    createAddress: (t, data) async {
      calls.creates.add((t, data));
      if (saveError != null) throw saveError;
      return saveResponse;
    },
    updateAddress: (t, id, data) async {
      calls.updates.add((t, id, data));
      if (saveError != null) throw saveError;
      return saveResponse;
    },
  );
}

void main() {
  group('reload', () {
    test('replaces the customer with the fetched one', () async {
      final calls = _Calls();
      final controller = _controller(calls, reloadResponse: {
        'status': 'success',
        'data': {
          'id': 7,
          'name': 'Asha',
          'addresses': [
            {'id': 1, 'address': 'Old Street'},
            {'id': 2, 'address': 'New Street'},
          ],
        },
      });

      await controller.reload();

      expect(calls.reloads, [('tok', 7)]);
      expect(controller.addresses.map((a) => a.address),
          ['Old Street', 'New Street']);
      expect(controller.isLoading, isFalse);
      expect(controller.loadFailed, isFalse);
    });

    test('keeps the current list when the API fails', () async {
      final calls = _Calls();
      final controller = _controller(calls, reloadResponse: {
        'status': 'error',
      });

      await controller.reload();

      expect(controller.addresses.single.address, 'Old Street');
      expect(controller.loadFailed, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test('does nothing for a customer without an id', () async {
      final calls = _Calls();
      final controller =
          _controller(calls, customer: CustomerListModelData(name: 'X'));

      await controller.reload();

      expect(calls.reloads, isEmpty);
    });

    test('flags a failure when there is no token', () async {
      final calls = _Calls();
      final controller = _controller(calls, token: null);

      await controller.reload();

      expect(calls.reloads, isEmpty);
      expect(controller.loadFailed, isTrue);
    });
  });

  group('save', () {
    final payload = {'customer_id': 7, 'address': 'New Street'};

    test('adds a new address and appends it', () async {
      final calls = _Calls();
      final controller = _controller(calls, saveResponse: {
        'status': 'success',
        'message': 'Address added',
        'data': {'id': 2, 'address': 'New Street', 'type': 'Office'},
      });

      final result = await controller.save(data: payload);

      expect(calls.creates, [('tok', payload)]);
      expect(calls.updates, isEmpty);
      expect(result.success, isTrue);
      expect(result.message, 'Address added');
      expect(result.address?.id, 2);
      expect(controller.addresses.map((a) => a.id), [1, 2]);
      expect(controller.isSaving, isFalse);
    });

    test('updates an existing address in place', () async {
      final calls = _Calls();
      final controller = _controller(calls, saveResponse: {
        'status': 'success',
        'data': {'id': 1, 'address': 'Renamed Street'},
      });
      final existing = controller.addresses.single;

      final result = await controller.save(data: payload, existing: existing);

      expect(calls.updates, [('tok', 1, payload)]);
      expect(calls.creates, isEmpty);
      expect(result.message, 'general.success'.tr);
      expect(controller.addresses.single.address, 'Renamed Street');
    });

    test('falls back to the payload when an add returns no data', () async {
      final calls = _Calls();
      final controller =
          _controller(calls, saveResponse: {'status': 'success'});

      final result = await controller.save(data: payload);

      expect(result.success, isTrue);
      expect(result.address?.address, 'New Street');
      expect(controller.addresses, hasLength(2));
    });

    test('returns the server message on failure', () async {
      final calls = _Calls();
      final controller = _controller(calls, saveResponse: {
        'status': 'error',
        'message': 'Pincode invalid',
      });

      final result = await controller.save(data: payload);

      expect(result.success, isFalse);
      expect(result.message, 'Pincode invalid');
      expect(result.address, isNull);
      expect(controller.addresses, hasLength(1));
    });

    test('reports thrown errors with the error prefix', () async {
      final calls = _Calls();
      final controller = _controller(calls, saveError: Exception('offline'));

      final result = await controller.save(data: payload);

      expect(result.success, isFalse);
      expect(result.message, startsWith('general.error_prefix'.tr));
      expect(result.message, contains('offline'));
      expect(controller.isSaving, isFalse);
    });

    test('asks to log in again without a token', () async {
      final calls = _Calls();
      final controller = _controller(calls, token: null);

      final result = await controller.save(data: payload);

      expect(result.success, isFalse);
      expect(result.message, 'customer_profile.error_login_again'.tr);
      expect(calls.creates, isEmpty);
    });
  });

  test('buildAddressPayload prefers the edited address name and phone', () {
    final customer = CustomerListModelData(id: 7, name: 'Asha', phone: '555');

    final added = buildAddressPayload(
      customer: customer,
      address: 'Line 1',
      city: 'Kochi',
      landmark: 'Temple',
      type: 'Home',
      stateId: '1',
      districtId: '2',
      pincodeId: '3',
    );
    final edited = buildAddressPayload(
      customer: customer,
      existing: Address(id: 1, name: 'Office desk', phone: '999'),
      address: 'Line 1',
      city: '',
      landmark: '',
      type: 'Office',
    );

    expect(added, {
      'customer_id': 7,
      'name': 'Asha',
      'phone': '555',
      'address': 'Line 1',
      'city': 'Kochi',
      'state_id': '1',
      'district_id': '2',
      'pincode_id': '3',
      'landmark': 'Temple',
      'type': 'Home',
    });
    expect(edited['name'], 'Office desk');
    expect(edited['phone'], '999');
    expect(edited['state_id'], isNull);
  });
}
