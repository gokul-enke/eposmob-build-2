import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';

/// [TenantSession] with fixed values.
class FakeTenantSession extends TenantSession {
  const FakeTenantSession({this.key = 'tenant', this.storeId = 1});

  final String? key;
  final int? storeId;

  @override
  Future<String?> apiKey() async => key;

  @override
  Future<int?> activeStoreId() async => storeId;
}

/// JSON response helper.
http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);
