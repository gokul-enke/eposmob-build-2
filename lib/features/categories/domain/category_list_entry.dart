class CategoryListEntry {
  CategoryListEntry(
      {this.id, this.name, this.slug, Map<String, String>? translations})
      : translations = Map.unmodifiable(translations ?? const {});
  final int? id;
  final String? name, slug;
  final Map<String, String> translations;
  bool sameValues(CategoryListEntry other) =>
      id == other.id &&
      name == other.name &&
      slug == other.slug &&
      translations.length == other.translations.length &&
      translations.entries
          .every((entry) => other.translations[entry.key] == entry.value);
}

/// Same case-insensitive name/translation substring rule as category management.
List<CategoryListEntry> filterCategoryEntries(
    List<CategoryListEntry> entries, String query) {
  if (query.isEmpty) return List.unmodifiable(entries);
  final lower = query.toLowerCase();
  return List.unmodifiable(entries.where((entry) =>
      (entry.name?.toLowerCase().contains(lower) ?? false) ||
      entry.translations.values
          .any((name) => name.toLowerCase().contains(lower))));
}
