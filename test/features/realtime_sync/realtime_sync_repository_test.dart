import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/offers/data/product_offer_repository.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_repository.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';

class _CountingOffers extends ProductOfferRepository {
  int refreshes = 0;

  @override
  Future<bool> refresh({bool full = false}) async {
    refreshes++;
    return true;
  }
}

class _CartLine implements LocalCartItem {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A till with one line in the cart, so catalog changes are deferred.
class _OpenCart implements LocalProductProvider {
  @override
  List<LocalCartItem> get cartItems => [_CartLine()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Not reached: a deferred pull stops before fetching anything.
class _Customers implements CustomerProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CustomerSelection implements CustomerSelectionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stocks implements StockProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sales implements SalesProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntityApi implements RealtimeEntityApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const session = RealtimeSyncSession(
    backendBaseUrl: 'https://pos.example.test',
    companyId: 3,
    storeId: 1,
    tenantApiKey: 'tenant',
    accessToken: 'token',
  );
  const offersAndProducts = RealtimeChangeSet(
    offers: EntityChangeSet(upserted: [9]),
    products: EntityChangeSet(upserted: [1]),
  );

  late _CountingOffers offers;
  late RealtimeSyncRepository repository;

  setUp(() {
    offers = _CountingOffers();
    repository = RealtimeSyncRepository(
      entityApi: _EntityApi(),
      localProducts: _OpenCart(),
      customers: _Customers(),
      customerSelection: _CustomerSelection(),
      stocks: _Stocks(),
      sales: _Sales(),
      offers: offers,
    );
  });

  Future<void> apply(
    String? updatedFrom, {
    String updatedTo = '2026-10-06T12:00:05Z',
    RealtimeChangeSet changes = offersAndProducts,
    RealtimeSyncSession activeSession = session,
  }) =>
      repository.apply(
        session: activeSession,
        changes: changes,
        updatedFrom: updatedFrom,
        updatedTo: updatedTo,
        isCurrent: () => true,
      );

  test('offers are fetched once while the cart defers the same window',
      () async {
    for (var pull = 0; pull < 3; pull++) {
      await expectLater(
        apply('2026-10-06T12:00:00Z'),
        throwsA(isA<RealtimeSyncDeferredException>()),
      );
    }
    expect(offers.refreshes, 1);
  });

  test('a new cursor window fetches offers again', () async {
    await expectLater(
      apply('2026-10-06T12:00:00Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    await expectLater(
      apply('2026-10-06T12:00:05Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    expect(offers.refreshes, 2);
  });

  test('a fresh server cutoff alone does not refetch offers', () async {
    // While the cart is open every deferred pull carries a new `synced_at`.
    for (final updatedTo in [
      '2026-10-06T12:00:05Z',
      '2026-10-06T12:00:10Z',
      '2026-10-06T12:00:15Z',
    ]) {
      await expectLater(
        apply('2026-10-06T12:00:00Z', updatedTo: updatedTo),
        throwsA(isA<RealtimeSyncDeferredException>()),
      );
    }
    expect(offers.refreshes, 1);
  });

  test('a new server event refreshes the same offer while the cart stays open',
      () async {
    await expectLater(
      apply('2026-10-06T12:00:00Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    repository.noteRemoteChange();
    await expectLater(
      apply('2026-10-06T12:00:00Z', updatedTo: '2026-10-06T12:00:10Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    expect(offers.refreshes, 2);
  });

  test('a cancellation in the same window refreshes offers again', () async {
    await expectLater(
      apply('2026-10-06T12:00:00Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    await expectLater(
      apply('2026-10-06T12:00:00Z',
          changes: const RealtimeChangeSet(
            offers: EntityChangeSet(deleted: [9]),
            products: EntityChangeSet(upserted: [1]),
          )),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    expect(offers.refreshes, 2);
  });

  test('another tenant refreshes offers even for the same cursor window',
      () async {
    await expectLater(
      apply('2026-10-06T12:00:00Z'),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    await expectLater(
      apply('2026-10-06T12:00:00Z',
          activeSession: const RealtimeSyncSession(
            backendBaseUrl: 'https://pos.example.test',
            companyId: 3,
            storeId: 1,
            tenantApiKey: 'another-tenant',
            accessToken: 'token',
          )),
      throwsA(isA<RealtimeSyncDeferredException>()),
    );
    expect(offers.refreshes, 2);
  });

  test('reordering the same changed ids does not repeat an offer fetch',
      () async {
    for (final ids in [
      [9, 10],
      [10, 9]
    ]) {
      await expectLater(
        apply('2026-10-06T12:00:00Z',
            changes: RealtimeChangeSet(
              offers: EntityChangeSet(upserted: ids),
              products: const EntityChangeSet(upserted: [1]),
            )),
        throwsA(isA<RealtimeSyncDeferredException>()),
      );
    }
    expect(offers.refreshes, 1);
  });
}
