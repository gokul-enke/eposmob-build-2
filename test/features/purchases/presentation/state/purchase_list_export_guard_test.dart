import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_list_export_guard.dart';

class _Session extends TenantSession {
  String? tenant = 'tenant';
  int? store = 4;
  void Function()? duringStoreRead;
  @override
  Future<String?> apiKey() async => tenant;
  @override
  Future<int?> activeStoreId() async {
    duringStoreRead?.call();
    return store;
  }
}

void main() {
  for (final change in [
    'filter',
    'reset',
    'token',
    'tenant',
    'store',
    'configuration',
    'permission',
    'dispose',
    'token during scope read'
  ]) {
    test('invalidates export after $change', () async {
      final input = TextEditingController();
      final guard = PurchaseListExportGuard([input]);
      final session = _Session();
      String? token = 'token';
      var configuration = 'endpoint';
      var allowed = true;
      final check = await guard.capture(
          session: session,
          token: () => token,
          configuration: () => configuration,
          allowed: () => allowed);
      switch (change) {
        case 'filter':
          input.text = 'Supplier';
          break;
        case 'reset':
          guard.invalidate();
          break;
        case 'token':
          token = null;
          break;
        case 'tenant':
          session.tenant = 'other';
          break;
        case 'store':
          session.store = 5;
          break;
        case 'configuration':
          configuration = 'other';
          break;
        case 'permission':
          allowed = false;
          break;
        case 'dispose':
          guard.dispose();
          break;
        case 'token during scope read':
          session.duringStoreRead = () => token = 'other';
          break;
      }
      await expectLater(check(), throwsStateError);
      if (change != 'dispose') guard.dispose();
      input.dispose();
    });
  }

  test('focus and selection changes keep the export running', () async {
    final input = TextEditingController(text: '2026-09-01');
    final guard = PurchaseListExportGuard([input]);
    final check = await guard.capture(
        session: _Session(),
        token: () => 'token',
        configuration: () => 'endpoint',
        allowed: () => true);
    // Tapping a read-only date field moves the cursor without editing text.
    input.selection = const TextSelection.collapsed(offset: 4);
    await expectLater(check(), completes);
    guard.dispose();
    input.dispose();
  });
}
