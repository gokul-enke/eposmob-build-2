import 'dart:async';

import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

class LocalSaleIdentity<T> {
  const LocalSaleIdentity({
    required this.value,
    required this.localOrderId,
    required this.localOrderNumber,
  });

  final T value;
  final String localOrderId;
  final String localOrderNumber;
}

class LocalFirstSaleResult<T> {
  const LocalFirstSaleResult({
    required this.localSale,
    required this.backgroundSync,
    this.printError,
  });

  final T localSale;
  final Future<LocalSaleSyncRecord> backgroundSync;
  final Object? printError;

  bool get printSucceeded => printError == null;
}

/// Shared transaction boundary for every local-first POS surface.
///
/// Surface adapters provide their local persistence and UI reset callbacks;
/// this coordinator owns the invariant ordering and the app-level background
/// hand-off. It deliberately has no Flutter or BuildContext dependency.
class LocalFirstSaleCoordinator {
  const LocalFirstSaleCoordinator(this.outbox);

  final LocalSaleSyncService outbox;

  Future<LocalFirstSaleResult<T>> confirm<T>({
    required LocalSaleSurface surface,
    LocalSaleOperation operation = LocalSaleOperation.confirmedSale,
    required String sourceCartSessionId,
    required OrderSubmissionPayload payload,
    required String accessToken,
    String? tenantKey,
    Uri? endpoint,
    required FutureOr<LocalSaleIdentity<T>> Function() persistLocalSale,
    required Future<void> Function() flushLocalPersistence,
    required FutureOr<void> Function(T sale) commitLocalWorkspace,
    required FutureOr<void> Function(T sale) rollbackLocalSale,
    FutureOr<void> Function(T sale)? printLocalReceipt,
    FutureOr<void> Function(LocalSaleSyncRecord record)? onSyncFinished,
  }) async {
    final identity = await persistLocalSale();
    var enqueued = false;
    try {
      await flushLocalPersistence();
      await outbox.enqueue(
        localOrderId: identity.localOrderId,
        localOrderNumber: identity.localOrderNumber,
        sourceCartSessionId: sourceCartSessionId,
        surface: surface,
        operation: operation,
        payload: operation == LocalSaleOperation.confirmExistingOrder
            ? payload.toUpdateApiJson()
            : payload.toApiJson(),
      );
      enqueued = true;
    } catch (_) {
      if (!enqueued) {
        await rollbackLocalSale(identity.value);
        await flushLocalPersistence();
      }
      rethrow;
    }

    try {
      await commitLocalWorkspace(identity.value);
      await flushLocalPersistence();
    } catch (_) {
      await outbox.markNeedsReviewBeforeSend(
        identity.localOrderId,
        message: 'The sale is safe locally, but checkout cleanup was '
            'interrupted before the first server attempt. Restart the app '
            'and review this sale.',
      );
      rethrow;
    }

    Object? printError;
    if (printLocalReceipt != null) {
      try {
        await printLocalReceipt(identity.value);
      } catch (error) {
        printError = error;
      }
    }

    final backgroundSync = outbox
        .submitOnce(
      localOrderId: identity.localOrderId,
      accessToken: accessToken,
      tenantKey: tenantKey,
      endpoint: endpoint,
    )
        .then((record) async {
      if (onSyncFinished != null) await onSyncFinished(record);
      return record;
    });

    // The future is returned for observability/tests while ownership remains
    // with the app-scoped outbox if the originating page is disposed.
    unawaited(backgroundSync.then<void>((_) {}, onError: (_, __) {}));

    return LocalFirstSaleResult<T>(
      localSale: identity.value,
      backgroundSync: backgroundSync,
      printError: printError,
    );
  }
}
