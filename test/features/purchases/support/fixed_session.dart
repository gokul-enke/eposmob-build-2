import 'package:pos_machine/core/network/tenant_session.dart';

class FixedSession extends TenantSession {
  const FixedSession({this.key = 'tenant-test', this.store = 42});
  final String? key;
  final int? store;
  @override
  Future<String?> apiKey() async => key;
  @override
  Future<int?> activeStoreId() async => store;
}
