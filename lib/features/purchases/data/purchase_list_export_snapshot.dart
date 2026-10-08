/// Request-local pagination for the two purchase list exports. Never writes to
/// a provider or list controller. The endpoint exposes page metadata, not a
/// total row count or a snapshot token.
class PurchaseExportPage<T> {
  const PurchaseExportPage(this.currentPage, this.lastPage, this.rows);
  final int? currentPage;
  final int? lastPage;
  final List<T>? rows;
}

Future<List<T>> collectPurchaseExport<T>({
  required Future<PurchaseExportPage<T>> Function(int page) fetch,
  required int? Function(T row) idOf,
  required Future<void> Function() checkScope,
  void Function(int page, int total)? onProgress,
}) async {
  final rows = <T>[];
  final ids = <int>{};
  int? lastPage;
  for (var page = 1;; page++) {
    await checkScope();
    final result = await fetch(page);
    await checkScope();
    final last = result.lastPage;
    final batch = result.rows;
    if (result.currentPage != page ||
        last == null ||
        last < page ||
        (lastPage != null && lastPage != last) ||
        batch == null ||
        batch.isEmpty) {
      throw StateError('Purchase export pagination changed or is incomplete');
    }
    lastPage = last;
    for (final row in batch) {
      final id = idOf(row);
      if (id == null || id <= 0 || !ids.add(id)) {
        throw StateError('Purchase export contains missing or duplicate IDs');
      }
      rows.add(row);
    }
    onProgress?.call(page, last);
    if (page == last) break;
  }
  return List.unmodifiable(rows);
}
