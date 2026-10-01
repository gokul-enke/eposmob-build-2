import 'package:pos_machine/features/customers/data/customer_repository.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';

/// [CustomerRepository] whose directory is an in-memory list.
class FakeCustomerRepository extends CustomerRepository {
  FakeCustomerRepository([List<CustomerListModelData>? customers])
      : customers = customers ?? [];

  List<CustomerListModelData> customers;
  final queries = <CustomerQuery>[];
  final savedToCache = <List<CustomerListModelData>>[];
  var cacheCleared = false;

  /// When set, [list] returns this instead of the directory.
  CustomerListResult? nextResult;

  @override
  Future<CustomerListResult> list(
      String accessToken, CustomerQuery query) async {
    queries.add(query);
    final override = nextResult;
    if (override != null) return override;
    return CustomerDirectoryLoaded(
      customers: List.of(customers),
      fromCache: false,
      response: {'status': 'success'},
    );
  }

  @override
  Future<void> saveToCache(
    int? storeId,
    List<CustomerListModelData> customers,
  ) async =>
      savedToCache.add(List.of(customers));

  @override
  Future<void> clearCache() async => cacheCleared = true;
}

/// `count` customers named "Customer 1".."Customer n" with ids 1..n.
List<CustomerListModelData> numberedCustomers(int count) => [
      for (var i = 1; i <= count; i++)
        CustomerListModelData(
          id: i,
          name: 'Customer $i',
          phone: '555${i.toString().padLeft(4, '0')}',
          balance: i.isEven ? i.toDouble() : -i.toDouble(),
        ),
    ];
