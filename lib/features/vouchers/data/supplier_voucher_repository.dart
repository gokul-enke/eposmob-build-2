import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/supplier_voucher.dart';
import 'supplier_voucher_api.dart';

class SupplierVoucherRepository {
  SupplierVoucherRepository({SupplierVoucherApi? api})
      : api = api ?? SupplierVoucherApi();
  final SupplierVoucherApi api;
  Future<List<SupplierVoucher>> fetch(String token) => api.fetch(token);
  Future<String> requireTenant() => api.requireTenant();
  Future<Map<String, dynamic>> create(
          String token, String tenant, Map<String, dynamic> body) =>
      api.create(APPUrl.createSupplierVoucher, token, tenant, body);
  Future<List<Map<String, dynamic>>?> choices(String? token) =>
      api.choices(APPUrl.getSuppliers, token);
}
