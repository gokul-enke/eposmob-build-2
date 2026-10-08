import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';

typedef SalesHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});
typedef SalesHttpPost = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding});
Future<Map<String, String>> salesHeaders(TenantSession session, String token,
    {String missingKey = 'API key not found. Please restart the app.'}) async {
  final key = await session.apiKey();
  if (key == null || key.isEmpty) throw HttpException(missingKey);
  return TenantSession.headers(accessToken: token, apiKey: key);
}
