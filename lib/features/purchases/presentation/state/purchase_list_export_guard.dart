import 'package:flutter/widgets.dart';
import 'package:pos_machine/core/network/tenant_session.dart';

/// Export-only invalidation. Paging does not change the filters; Reset does,
/// even if the user resets an already unfiltered list.
class PurchaseListExportGuard {
  PurchaseListExportGuard(this.inputs) {
    for (final input in inputs) {
      input.addListener(invalidate);
    }
  }
  final List<TextEditingController> inputs;
  int _generation = 0;
  bool _disposed = false;
  void invalidate() => _generation++;

  Future<Future<void> Function()> capture({
    required TenantSession session,
    required String? Function() token,
    required Object Function() configuration,
    required bool Function() allowed,
  }) async {
    final generation = _generation;
    final originalToken = token();
    final originalConfiguration = configuration();
    final tenant = await session.apiKey();
    final store = await session.activeStoreId();
    Future<void> check() async {
      if (_disposed ||
          generation != _generation ||
          originalToken == null ||
          originalToken.isEmpty ||
          tenant == null ||
          tenant.isEmpty ||
          !allowed() ||
          token() != originalToken ||
          configuration() != originalConfiguration ||
          await session.apiKey() != tenant ||
          await session.activeStoreId() != store ||
          _disposed ||
          generation != _generation ||
          !allowed() ||
          token() != originalToken ||
          configuration() != originalConfiguration) {
        throw StateError('Purchase export context changed');
      }
    }

    await check();
    return check;
  }

  void dispose() {
    _disposed = true;
    invalidate();
    for (final input in inputs) {
      input.removeListener(invalidate);
    }
  }
}
