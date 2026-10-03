import 'package:flutter/material.dart';

/// Narrow-screen list of cards with 10 px gaps, bouncing scroll, optional
/// pull-to-refresh and an empty state.
class AppCardList<T> extends StatelessWidget {
  const AppCardList({
    super.key,
    required this.items,
    required this.cardBuilder,
    required this.emptyState,
    this.rowNumberOf,
    this.onRefresh,
  });

  final List<T> items;

  /// Builds the card for [item]; the second argument is the 1-based row
  /// number across pages.
  final Widget Function(T item, int rowNumber) cardBuilder;
  final Widget emptyState;
  final int Function(int index)? rowNumberOf;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: items.isEmpty ? 1 : items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (items.isEmpty) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 310),
            child: Center(child: emptyState),
          );
        }
        final number = rowNumberOf?.call(index) ?? index + 1;
        return cardBuilder(items[index], number);
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
