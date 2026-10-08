import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pos_machine/core/network/tenant_session.dart';

/// Export-only invalidation. Paging does not change the filters; Reset does,
/// even if the user resets an already unfiltered list. Filter inputs are
/// compared by text, so focus, cursor and selection changes never abort.
class PurchaseListExportGuard {
  PurchaseListExportGuard(this.inputs);
  final List<TextEditingController> inputs;
  int _generation = 0;
  bool _disposed = false;
  void invalidate() => _generation++;

  List<String> _texts() => [for (final input in inputs) input.text];

  Future<Future<void> Function()> capture({
    required TenantSession session,
    required String? Function() token,
    required Object Function() configuration,
    required bool Function() allowed,
  }) async {
    final generation = _generation;
    final originalTexts = _texts();
    final originalToken = token();
    final originalConfiguration = configuration();
    final tenant = await session.apiKey();
    final store = await session.activeStoreId();
    bool unchanged() =>
        !_disposed &&
        generation == _generation &&
        listEquals(_texts(), originalTexts) &&
        allowed() &&
        token() == originalToken &&
        configuration() == originalConfiguration;
    Future<void> check() async {
      if (originalToken == null ||
          originalToken.isEmpty ||
          tenant == null ||
          tenant.isEmpty ||
          !unchanged() ||
          await session.apiKey() != tenant ||
          await session.activeStoreId() != store ||
          !unchanged()) {
        throw StateError('Purchase export context changed');
      }
    }

    await check();
    return check;
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}
