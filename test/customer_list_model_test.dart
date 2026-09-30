import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  group('CustomerListModel', () {
    test('parses the paginated customer-searchbar response', () {
      final model = CustomerListModel.fromJson({
        'status': 'success',
        'message': 'Customers',
        'data': {
          'current_page': 1,
          'last_page': 3,
          'per_page': 100,
          'total': 205,
          'data': [
            {'id': 10, 'name': 'First customer'},
            {'id': 11, 'name': 'Second customer'},
          ],
        },
      });

      expect(model.data, hasLength(2));
      expect(model.data!.first.id, 10);
      expect(model.data!.last.name, 'Second customer');
      expect(model.currentPage, 1);
      expect(model.lastPage, 3);
      expect(model.perPage, 100);
      expect(model.total, 205);
    });

    test('keeps supporting the legacy flat customer response', () {
      final model = CustomerListModel.fromJson({
        'status': 'success',
        'data': [
          {'id': 20, 'name': 'Legacy customer'},
        ],
      });

      expect(model.data, hasLength(1));
      expect(model.data!.single.id, 20);
      expect(model.data!.single.name, 'Legacy customer');
      expect(model.lastPage, isNull);
    });

    test('reads top-level pagination used by older API variants', () {
      final model = CustomerListModel.fromJson({
        'status': 'success',
        'data': [
          {'id': 30, 'name': 'Top-level pagination'},
        ],
        'pagination': {
          'current_page': '1',
          'last_page': '2',
          'per_page': '100',
          'total': '101',
        },
      });

      expect(model.data, hasLength(1));
      expect(model.currentPage, 1);
      expect(model.lastPage, 2);
      expect(model.perPage, 100);
      expect(model.total, 101);
    });

    test('serialization keeps the established flat data contract', () {
      final json = CustomerListModel(
        status: 'success',
        currentPage: 1,
        lastPage: 2,
        data: [CustomerListModelData(id: 40, name: 'Customer')],
      ).toJson();

      expect(json['data'], isA<List>());
      expect((json['data'] as List).single['id'], 40);
    });

    test('treats missing or malformed customer data as an empty list', () {
      expect(CustomerListModel.fromJson({}).data, isEmpty);
      expect(
        CustomerListModel.fromJson({'data': 'invalid'}).data,
        isEmpty,
      );
    });

    test('uses phone, email and id when the customer name is blank', () {
      expect(
        CustomerListModelData(id: 1, name: 'Named', phone: '111').displayLabel,
        'Named',
      );
      expect(
        CustomerListModelData(id: 2, name: ' ', phone: '222').displayLabel,
        '222',
      );
      expect(
        CustomerListModelData(id: 3, email: 'customer@example.com')
            .displayLabel,
        'customer@example.com',
      );
      expect(CustomerListModelData(id: 4).displayLabel, '#4');
    });
  });
}
