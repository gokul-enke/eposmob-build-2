import 'package:pos_machine/resources/app_url.dart';
import '../domain/models/customer_voucher.dart';
import 'customer_voucher_api.dart';

class CustomerVoucherRepository {
  CustomerVoucherRepository({CustomerVoucherApi? api})
      : api = api ?? CustomerVoucherApi();
  final CustomerVoucherApi api;
  Future<List<CustomerVoucher>> fetch(String token,
          {String? dateFrom, String? dateTo}) =>
      api.fetch(token, dateFrom: dateFrom, dateTo: dateTo);
  Future<String> requireTenant() => api.requireTenant();
  Future<Map<String, dynamic>> create(
          String token, String tenant, Map<String, dynamic> body) =>
      api.create(APPUrl.createCustomerVoucher, token, tenant, body);
  Future<dynamic> zatcaPrint(int id, String token) =>
      api.zatca(APPUrl.zatcaPhase2VoucherPrint, token, id);
  Future<dynamic> zatcaResync(int id, String token) =>
      api.zatca(APPUrl.zatcaPhase2VoucherResync, token, id);
  Future<List<Map<String, dynamic>>?> choices(String? token) =>
      api.choices(APPUrl.customerListUrl, token);
}
