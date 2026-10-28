/// Remembers the category last picked on a sales screen, so coming back to
/// the screen (switching sidebar tabs, leaving and reopening Sales) keeps that
/// category instead of falling back to "All". Kept in memory for the session.
class SalesCategoryMemory {
  SalesCategoryMemory._();

  /// Category id used by the desktop sidebar and the restaurant/store menu.
  /// 0 = All, -1 = Favourites (restaurant menu only).
  static int categoryId = 0;

  /// Category name used by the mobile market home chips; null = All.
  static String? categoryName;

  /// Returns [id] when it is still a valid choice, otherwise 0 (All).
  /// A remembered category can disappear after a store switch or resync.
  static int resolveCategoryId(int id, Iterable<int?> availableIds,
      {bool allowFavourites = false}) {
    if (id == 0) return 0;
    if (id == -1) return allowFavourites ? -1 : 0;
    return availableIds.contains(id) ? id : 0;
  }
}
