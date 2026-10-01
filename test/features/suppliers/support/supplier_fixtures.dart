import 'package:pos_machine/features/suppliers/data/supplier_repository.dart';
import 'package:pos_machine/features/suppliers/domain/models/supplier.dart';

/// A supplier built through the real JSON parser.
Supplier supplier({
  int id = 1,
  String name = 'Supplier',
  String email = '',
  String phone = '',
  String address = '',
  double balance = 0,
}) =>
    Supplier.fromJson({
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'current_balance': balance,
    });

/// `count` suppliers "Supplier 1".."Supplier n"; even ids have a positive
/// balance, odd ids a negative one.
List<Supplier> numberedSuppliers(int count) => [
      for (var i = 1; i <= count; i++)
        supplier(
          id: i,
          name: 'Supplier $i',
          email: 'supplier$i@test.com',
          phone: '555${i.toString().padLeft(4, '0')}',
          balance: i.isEven ? i.toDouble() : -i.toDouble(),
        ),
    ];

/// [SupplierRepository] whose directory is an in-memory list.
class FakeSupplierRepository extends SupplierRepository {
  FakeSupplierRepository([List<Supplier>? suppliers])
      : suppliers = suppliers ?? [];

  List<Supplier> suppliers;
  int fetches = 0;
  Object? fetchError;
  final created = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  Map<String, dynamic> mutationResponse = {'status': 'success'};
  final transactionQueries = <Map<String, Object?>>[];

  @override
  Future<List<Supplier>?> fetchAll(String accessToken, {String? name}) async {
    fetches++;
    final error = fetchError;
    if (error != null) throw error;
    return List.of(suppliers);
  }

  @override
  Future<Map<String, dynamic>> fetchTransactions(
    String accessToken, {
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) async {
    transactionQueries.add({'supplierId': supplierId, 'page': page});
    return {'status': 'success', 'data': []};
  }

  @override
  Future<Map<String, dynamic>> create(
    String accessToken, {
    required String name,
    required String email,
    required String phone,
    required String balance,
    required String paymentStatus,
    required String address,
    required String altPhone,
    String? taxNumber,
    List<SupplierKyc> kyc = const [],
  }) async {
    created.add({'name': name, 'phone': phone, 'balance': balance});
    return mutationResponse;
  }

  @override
  Future<Map<String, dynamic>> update(
    String accessToken, {
    required int id,
    required String name,
    required String phone,
    required double balance,
    String? email,
    String? address,
    String? altPhone,
    String? paymentStatus,
    String? taxNumber,
    List<SupplierKyc>? kyc,
  }) async {
    updated.add({'id': id, 'name': name});
    return mutationResponse;
  }
}
