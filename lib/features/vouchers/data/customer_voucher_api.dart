import 'dart:convert';
import 'dart:io';

import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/customer_voucher.dart';
import 'voucher_http.dart';

class CustomerVoucherApi extends VoucherHttp {
  CustomerVoucherApi(
      {super.httpGet,
      super.httpPost,
      TenantSession session = const TenantSession()})
      : super(session: session);

  Future<List<CustomerVoucher>> fetch(String token,
      {String? dateFrom, String? dateTo}) async {
    final tenant = await requireTenant();
    final store = await session.activeStoreId();
    final response = await get(
            Uri.parse(APPUrl.listCustomerVouchers).replace(queryParameters: {
              'page': '1',
              'per_page': '1000',
              if (store != null) 'store_id': '$store',
              if (dateFrom != null && dateFrom.isNotEmpty)
                'date_from': dateFrom,
              if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
            }),
            headers: headers(token, tenant))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Unable to load vouchers (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['status'] != true ||
        data['data'] is! List) {
      throw const FormatException('Invalid customer voucher response');
    }
    return CustomerVoucherModel.fromJson(data).data;
  }
}
