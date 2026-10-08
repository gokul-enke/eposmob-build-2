import '../domain/category_list_entry.dart';

/// Port over the existing all-scope directory; no provider, HTTP or UI state.
class CategoryListSource {
  CategoryListSource(
      {required this.readEntries,
      required this.ensureLoaded,
      required this.isBusy,
      required this.addListener,
      required this.removeListener});
  final List<CategoryListEntry> Function() readEntries;
  final Future<void> Function() ensureLoaded;
  final bool Function() isBusy;
  final void Function(void Function()) addListener, removeListener;
}
