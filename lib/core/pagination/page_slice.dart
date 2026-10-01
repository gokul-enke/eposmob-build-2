/// One page cut out of an in-memory list.
class PageSlice<T> {
  const PageSlice({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
  });

  /// Cuts page [page] (1-based) of [perPage] items out of [source].
  ///
  /// There is always at least one page. A [page] past the end is clamped to
  /// the last page; a [page] below 1 is clamped to 1.
  factory PageSlice.of(List<T> source,
      {required int page, required int perPage}) {
    assert(perPage > 0, 'perPage must be positive');
    final totalPages = source.isEmpty ? 1 : (source.length / perPage).ceil();
    final current = page.clamp(1, totalPages);
    final start = (current - 1) * perPage;
    final end = (start + perPage).clamp(0, source.length);
    return PageSlice(
      items: start >= source.length ? <T>[] : source.sublist(start, end),
      currentPage: current,
      totalPages: totalPages,
      totalItems: source.length,
    );
  }

  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
}
