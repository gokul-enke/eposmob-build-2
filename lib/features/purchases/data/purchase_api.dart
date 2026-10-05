import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/resources/api_locale.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'purchase_read_response.dart';
part 'purchase_api_lookups.dart';
part 'purchase_api_lists.dart';
part 'purchase_api_items.dart';
part 'purchase_api_orders.dart';

// Prepared separately from sending so legacy missing-tenant errors retain
// their original position outside (or inside) the provider's try/catch.
class PurchaseRequest {
  PurchaseRequest(this.url, this._send);
  final Uri url;
  final Future<http.Response> Function() _send;
  Future<PurchaseReadResponse> send() async =>
      PurchaseReadResponse(await _send());
}

typedef PurchaseHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});
typedef PurchaseHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding});

class PurchaseApi {
  PurchaseApi(
      {PurchaseHttpGet? httpGet,
      PurchaseHttpPost? httpPost,
      this.session = const TenantSession(),
      void Function(String?)? log})
      : _get = httpGet ?? http.get,
        _post = httpPost ?? http.post,
        debugPrint = log ?? _ignoreLog;
  final PurchaseHttpGet _get;
  final PurchaseHttpPost _post;
  final TenantSession session;
  final void Function(String?) debugPrint;
  static void _ignoreLog(String? _) {}
}
