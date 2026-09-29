import 'dart:async';

import 'package:pos_machine/models/order_submission_payload.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

/// How `Confirm Order` treats the server. Controlled per tenant by the
/// `OFFLINE_FIRST_SALES` app setting.
enum SaleConfirmationMode {
  /// The sale is final once it is durable on this device; the one server
  /// attempt runs in the background.
  offlineFirst,

  /// The confirm button waits for the server. The cart is cleared and the
  /// receipt printed only after the server verifiably accepts the sale.
  onlineFirst,
}

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
    required this.message,
    this.needsAttention = false,
    this.printError,
  });

  final T localSale;
  final Future<LocalSaleSyncRecord> backgroundSync;

  /// Cashier-facing outcome, shared by every surface.
  final String message;

  /// True when the sale was kept but its server outcome must be reviewed in
  /// Sales → Confirmed Orders. Surfaces show [message] as an error.
  final bool needsAttention;
  final Object? printError;

  bool get printSucceeded => printError == null;
}

/// An online-first confirmation that did not complete. The cart is left as it
/// was, so the cashier can correct it and confirm again.
class OnlineSaleNotConfirmed implements Exception {
  const OnlineSaleNotConfirmed(this.message);

  final String message;

  @override
  String toString() => message;
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
    SaleConfirmationMode mode = SaleConfirmationMode.offlineFirst,
    required String sourceCartSessionId,
    required OrderSubmissionPayload payload,
    required String accessToken,
    bool attemptServerSync = true,
    String? tenantKey,
    Uri? endpoint,
    required FutureOr<LocalSaleIdentity<T>> Function() persistLocalSale,
    required Future<void> Function() flushLocalPersistence,
    required FutureOr<void> Function(T sale) commitLocalWorkspace,
    required FutureOr<void> Function(T sale) rollbackLocalSale,
    FutureOr<void> Function(T sale)? printLocalReceipt,
    FutureOr<void> Function(LocalSaleSyncRecord record)? onSyncFinished,
  }) async {
    // Online-first only applies while the server is reachable. With no
    // internet or Offline Mode on, the sale falls back to offline-first so
    // the till keeps selling; it is reviewed and sent later.
    final onlineFirst =
        mode == SaleConfirmationMode.onlineFirst && attemptServerSync;
    if (onlineFirst && accessToken.trim().isEmpty) {
      throw const OnlineSaleNotConfirmed(
        'Please log in again. The order was not placed; the cart is '
        'unchanged.',
      );
    }

    // Online-first still writes the snapshot and outbox record before the
    // request, so an ambiguous outcome or a crash mid-request stays reviewable.
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

    if (onlineFirst) {
      return _confirmOnline(
        identity: identity,
        accessToken: accessToken,
        tenantKey: tenantKey,
        endpoint: endpoint,
        flushLocalPersistence: flushLocalPersistence,
        commitLocalWorkspace: commitLocalWorkspace,
        rollbackLocalSale: rollbackLocalSale,
        printLocalReceipt: printLocalReceipt,
        onSyncFinished: onSyncFinished,
      );
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

    final printError = await _print(printLocalReceipt, identity.value);

    final backgroundSync = (attemptServerSync
            ? outbox.submitOnce(
                localOrderId: identity.localOrderId,
                accessToken: accessToken,
                tenantKey: tenantKey,
                endpoint: endpoint,
              )
            : outbox.markNeedsReviewBeforeSend(
                identity.localOrderId,
                message: 'The sale is saved locally and was not sent because '
                    'Offline Mode is enabled. Verify it is absent from Sales '
                    'before retrying.',
              ))
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
      message: _withPrintOutcome(
        attemptServerSync
            ? 'Order confirmed locally. Server sync continues in the '
                'background.'
            : 'Order confirmed locally. Offline Mode prevented the server '
                'request; review it in Sync attention.',
        printLocalReceipt,
        printError,
      ),
    );
  }

  /// Waits for the one server attempt, then finishes the sale according to
  /// the verified outcome:
  /// - synced: clear the cart and print;
  /// - rejected: remove the local sale and keep the cart for correction;
  /// - ambiguous: clear the cart without printing and keep the sale for
  ///   review, because it may already exist on the server.
  Future<LocalFirstSaleResult<T>> _confirmOnline<T>({
    required LocalSaleIdentity<T> identity,
    required String accessToken,
    required String? tenantKey,
    required Uri? endpoint,
    required Future<void> Function() flushLocalPersistence,
    required FutureOr<void> Function(T sale) commitLocalWorkspace,
    required FutureOr<void> Function(T sale) rollbackLocalSale,
    required FutureOr<void> Function(T sale)? printLocalReceipt,
    required FutureOr<void> Function(LocalSaleSyncRecord record)?
        onSyncFinished,
  }) async {
    final record = await outbox.submitOnce(
      localOrderId: identity.localOrderId,
      accessToken: accessToken,
      tenantKey: tenantKey,
      endpoint: endpoint,
    );

    if (record.state == LocalSaleSyncState.rejected) {
      // Drop the outbox record first: a leftover record would make the next
      // app start treat this still-open cart as already confirmed.
      await outbox.discardRejected(identity.localOrderId);
      await rollbackLocalSale(identity.value);
      await flushLocalPersistence();
      throw OnlineSaleNotConfirmed(
        '${record.message ?? 'The server rejected this order.'} '
        'The cart is unchanged.',
      );
    }

    final synced = record.state == LocalSaleSyncState.synced;
    try {
      await commitLocalWorkspace(identity.value);
      await flushLocalPersistence();
    } catch (_) {
      throw OnlineSaleNotConfirmed(
        synced
            ? 'The server accepted this order, but the cart could not be '
                'cleared. Do not confirm it again; check Sales → Confirmed '
                'Orders.'
            : 'The server did not confirm this order and the cart could not '
                'be cleared. Do not confirm it again; review it in Sales → '
                'Confirmed Orders.',
      );
    }

    if (onSyncFinished != null) {
      try {
        await onSyncFinished(record);
      } catch (_) {
        // Post-sync cache refresh is best effort; the sync state is final.
      }
    }

    if (!synced) {
      return LocalFirstSaleResult<T>(
        localSale: identity.value,
        backgroundSync: Future.value(record),
        needsAttention: true,
        printError: printLocalReceipt == null
            ? null
            : StateError('Not printed: the server did not confirm this order.'),
        message: 'The server did not confirm this order. It is saved in '
            'Sales → Confirmed Orders; check the admin panel before '
            'retrying it there. No receipt was printed.',
      );
    }

    final printError = await _print(printLocalReceipt, identity.value);
    return LocalFirstSaleResult<T>(
      localSale: identity.value,
      backgroundSync: Future.value(record),
      printError: printError,
      message: _withPrintOutcome(
        'Order placed successfully.',
        printLocalReceipt,
        printError,
      ),
    );
  }

  static Future<Object?> _print<T>(
    FutureOr<void> Function(T sale)? printLocalReceipt,
    T sale,
  ) async {
    if (printLocalReceipt == null) return null;
    try {
      await printLocalReceipt(sale);
      return null;
    } catch (error) {
      return error;
    }
  }

  static String _withPrintOutcome(
    String message,
    Function? printLocalReceipt,
    Object? printError,
  ) {
    if (printLocalReceipt == null || printError == null) return message;
    return '$message The receipt could not be printed.';
  }
}
