import 'dart:convert';
import 'dart:io';

import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../domain/models/supplier_voucher.dart';
import 'voucher_http.dart';

class SupplierVoucherApi extends VoucherHttp {
  SupplierVoucherApi(
      {super.httpGet,
      super.httpPost,
      TenantSession session = const TenantSession()})
      : super(session: session);

  SupplierVoucherModel _parse(dynamic payload,
      {required int expectedPage, int? expectedLastPage}) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid voucher response.');
    }
    final status = payload['status']?.toString().toLowerCase();
    if (['failed', 'failure', 'error', 'false'].contains(status)) {
      throw const FormatException('The voucher API reported a failure.');
    }
    final data = payload['data'];
    List<dynamic> rows;
    int lastPage;
    if (data is List && expectedPage == 1 && expectedLastPage == null) {
      rows = data;
      lastPage = 1;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      final current = int.tryParse('${data['current_page']}');
      final last = int.tryParse('${data['last_page']}');
      if (current != expectedPage ||
          last == null ||
          last < expectedPage ||
          (expectedLastPage != null && last != expectedLastPage)) {
        throw const FormatException('Invalid voucher pagination.');
      }
      rows = data['data'] as List;
      lastPage = last;
    } else {
      throw const FormatException('Missing voucher page data.');
    }
    if (rows.any((row) => row is! Map<String, dynamic>) ||
        (rows.isEmpty && lastPage > 1)) {
      throw const FormatException('Incomplete voucher page data.');
    }
    return SupplierVoucherModel.fromJson(payload);
  }

  Future<List<SupplierVoucher>> fetch(String token) async {
    final tenant = await requireTenant();
    final store = await session.activeStoreId();
    final query = {
      'page': '1',
      'per_page': '1000',
      if (store != null) 'store_id': '$store'
    };
    final uri = Uri.parse(APPUrl.listSupplierVouchers);
    final response = await get(uri.replace(queryParameters: query),
        headers: headers(token, tenant));
    if (response.statusCode != 200) {
      throw HttpException('Failed to load vouchers (${response.statusCode}).');
    }
    final first = _parse(jsonDecode(response.body), expectedPage: 1);
    final vouchers = [...first.data];
    for (int page = first.currentPage + 1; page <= first.lastPage; page++) {
      final next = await get(
          uri.replace(queryParameters: {...query, 'page': '$page'}),
          headers: headers(token, tenant));
      if (next.statusCode != 200) {
        throw HttpException(
            'Failed to load voucher page $page (${next.statusCode}).');
      }
      vouchers.addAll(_parse(jsonDecode(next.body),
              expectedPage: page, expectedLastPage: first.lastPage)
          .data);
    }
    final ids = <int>{};
    if (vouchers.any((voucher) => !ids.add(voucher.id))) {
      throw const FormatException('Duplicate vouchers across API pages.');
    }
    return vouchers;
  }
}
