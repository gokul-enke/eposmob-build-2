import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/data/purchase_list_export_snapshot.dart';

void main() {
  Future<List<int>> collect(List<PurchaseExportPage<int>> pages,
          {Future<void> Function()? scope}) =>
      collectPurchaseExport<int>(
          fetch: (p) async => pages[p - 1],
          idOf: (id) => id,
          checkScope: scope ?? () async {});
  test('collects every declared page including a short final page', () async {
    expect(
        await collect([
          const PurchaseExportPage(1, 2, [1, 2]),
          const PurchaseExportPage(2, 2, [3])
        ]),
        [1, 2, 3]);
  });
  for (final entry in <String, List<PurchaseExportPage<int>>>{
    'duplicate across pages': [
      const PurchaseExportPage(1, 2, [1, 2]),
      const PurchaseExportPage(2, 2, [2, 3])
    ],
    'duplicate on first page': [
      const PurchaseExportPage(1, 1, [1, 1])
    ],
    'missing page metadata': [
      const PurchaseExportPage(null, 1, [1])
    ],
    'wrong current page': [
      const PurchaseExportPage(2, 2, [1])
    ],
    'last page changed': [
      const PurchaseExportPage(1, 2, [1]),
      const PurchaseExportPage(2, 3, [2])
    ],
    'empty later page': [
      const PurchaseExportPage(1, 2, [1]),
      const PurchaseExportPage(2, 2, [])
    ],
    'missing rows': [const PurchaseExportPage<int>(1, 1, null)],
    'invalid ID': [
      const PurchaseExportPage(1, 1, [0])
    ],
    'invalid last page': [
      const PurchaseExportPage(1, 0, [1])
    ],
  }.entries) {
    test('rejects ${entry.key}',
        () => expect(collect(entry.value), throwsStateError));
  }
  test('validates scope before and after each request', () async {
    var checks = 0;
    expect(
        await collect([
          const PurchaseExportPage(1, 1, [1])
        ], scope: () async {
          checks++;
        }),
        [1]);
    expect(checks, 2);
  });
  test('does not fetch another page after scope changes', () async {
    var calls = 0;
    var changed = false;
    await expectLater(
        collectPurchaseExport<int>(
            fetch: (p) async {
              calls++;
              changed = true;
              return const PurchaseExportPage(1, 2, [1]);
            },
            idOf: (i) => i,
            checkScope: () async {
              if (changed) throw StateError('changed');
            }),
        throwsStateError);
    expect(calls, 1);
  });
}
