import '../domain/models/supplier.dart';
import 'supplier_api.dart';
import 'supplier_payloads.dart';

/// Single entry point to supplier data.
class SupplierRepository {
  SupplierRepository({SupplierApi? api}) : api = api ?? SupplierApi();

  final SupplierApi api;

  /// Every supplier of the active store; `null` when the server refused.
  Future<List<Supplier>?> fetchAll(String accessToken, {String? name}) =>
      api.fetchAll(accessToken, name: name);

  Future<Map<String, dynamic>> fetchTransactions(
    String accessToken, {
    String? supplierName,
    String? supplierId,
    String? transactionType,
    String? fromDate,
    String? toDate,
    bool listAll = true,
    int? page,
  }) =>
      api.fetchTransactions(
        accessToken,
        supplierName: supplierName,
        supplierId: supplierId,
        transactionType: transactionType,
        fromDate: fromDate,
        toDate: toDate,
        listAll: listAll,
        page: page,
      );

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
  }) =>
      api.create(
        accessToken,
        SupplierPayloads.create(
          name: name,
          email: email,
          phone: phone,
          balance: balance,
          paymentStatus: paymentStatus,
          address: address,
          altPhone: altPhone,
          taxNumber: taxNumber,
          kyc: kyc,
        ),
      );

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
  }) =>
      api.update(
        accessToken,
        SupplierPayloads.update(
          id: id,
          name: name,
          phone: phone,
          balance: balance,
          email: email,
          address: address,
          altPhone: altPhone,
          paymentStatus: paymentStatus,
          taxNumber: taxNumber,
          kyc: kyc,
        ),
      );
}
