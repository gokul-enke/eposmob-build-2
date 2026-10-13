import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import '../commands/confirm_and_delete_local_sale.dart';
import '../commands/confirm_and_dismiss_local_sale.dart';
import '../commands/confirm_and_sync_local_sales.dart';
import '../commands/edit_local_sale_request.dart';
import '../commands/local_sales_services.dart';
import '../commands/print_local_sale.dart';
import '../commands/show_local_sale_details.dart';
import '../commands/show_local_sale_sync_log.dart';
import '../widgets/local_orders/local_sale_attention_card.dart';
import '../widgets/local_orders/local_sales_header.dart';

enum _AttentionFilter { all, needsReview, rejected, notSent }

class ConfirmedOrdersPage extends StatefulWidget {
  const ConfirmedOrdersPage({super.key});

  @override
  State<ConfirmedOrdersPage> createState() => _ConfirmedOrdersPageState();
}

class _ConfirmedOrdersPageState extends State<ConfirmedOrdersPage> {
  late final LocalSalesServices _services;
  final Set<String> _selectedIds = {};
  final _search = TextEditingController();
  _AttentionFilter _filter = _AttentionFilter.all;
  bool _batchActive = false;
  bool _sending = false;
  int _completed = 0;
  int _total = 0;
  LocalSaleBatchResult? _batchResult;
  String? _batchError;

  @override
  void initState() {
    super.initState();
    _services = LocalSalesServices.capture(context);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SavedOrder> _attentionOrders(
          LocalProductProvider provider, LocalSaleSyncService sync) =>
      provider.confirmedOrders.where((order) {
        final record = sync.recordFor(order.id);
        return record?.state != LocalSaleSyncState.synced &&
            record?.isDismissed != true;
      }).toList();

  bool _matchesFilter(_AttentionFilter filter, LocalSaleSyncRecord? record) =>
      switch (filter) {
        _AttentionFilter.all => true,
        _AttentionFilter.needsReview =>
          record?.state == LocalSaleSyncState.needsReview,
        _AttentionFilter.rejected =>
          record?.state == LocalSaleSyncState.rejected,
        _AttentionFilter.notSent =>
          record == null || record.state == LocalSaleSyncState.queued,
      };

  bool _matchesSearch(SavedOrder order) {
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        order.orderNumber.toLowerCase().contains(query) ||
        (order.customerName?.toLowerCase().contains(query) ?? false);
  }

  bool _canSync(SavedOrder order, LocalSaleSyncService sync) {
    final record = sync.recordFor(order.id);
    return !sync.isSubmitting(order.id) &&
        (record == null || record.canEditRequest);
  }

  Future<void> _syncOrders(List<SavedOrder> orders) async {
    if (_batchActive || _services.sync.isBatchSyncing || orders.isEmpty) return;
    setState(() => _batchActive = true);
    try {
      final confirmed = await confirmSyncLocalSales(context, orders, _services);
      if (!confirmed || !mounted) return;
      setState(() {
        _sending = true;
        _completed = 0;
        _total = orders.length;
        _batchResult = null;
        _batchError = null;
      });
      final result = await syncVerifiedLocalSales(context, orders, _services,
          onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _completed = completed;
            _total = total;
          });
        }
      });
      if (mounted) {
        setState(() {
          _batchResult = result;
          // Every order in the batch got its one attempt; start fresh.
          _selectedIds.removeAll(orders.map((order) => order.id));
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _batchError = error is StateError
            ? error.message.toString()
            : 'Could not finish syncing. Review the remaining orders and their logs.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _batchActive = false;
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1680),
              child: Consumer2<LocalProductProvider, LocalSaleSyncService>(
                  builder: (context, provider, sync, _) {
                final busy = _batchActive || sync.isBatchSyncing;
                final orders = _attentionOrders(provider, sync);
                final counts = {
                  for (final filter in _AttentionFilter.values)
                    filter: orders
                        .where((order) =>
                            _matchesFilter(filter, sync.recordFor(order.id)))
                        .length,
                };
                final visible = orders
                    .where((order) =>
                        _matchesFilter(_filter, sync.recordFor(order.id)) &&
                        _matchesSearch(order))
                    .toList();
                final narrowed = _filter != _AttentionFilter.all ||
                    _search.text.trim().isNotEmpty;
                final eligible =
                    visible.where((order) => _canSync(order, sync)).toList();
                final eligibleIds = eligible.map((order) => order.id).toSet();
                // Selection follows what is on screen so a hidden order is
                // never synced by surprise.
                _selectedIds.retainAll(visible.map((order) => order.id));
                final selected = eligible
                    .where((order) => _selectedIds.contains(order.id))
                    .toList();
                final allSelected =
                    eligible.isNotEmpty && selected.length == eligible.length;
                return LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  final padding = compact ? 16.0 : 24.0;
                  return CustomScrollView(
                      key: const ValueKey('confirmed-orders-scroll'),
                      slivers: [
                        SliverPadding(
                          padding:
                              EdgeInsets.fromLTRB(padding, padding, padding, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LocalSalesHeader(visibleCount: orders.length),
                                  if (orders.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    _buildToolbar(
                                      compact: compact,
                                      busy: busy,
                                      counts: counts,
                                      eligible: eligible,
                                      eligibleIds: eligibleIds,
                                      selected: selected,
                                      allSelected: allSelected,
                                      narrowed: narrowed,
                                    ),
                                  ],
                                  if (_sending) _buildProgress(),
                                  if (_batchResult != null ||
                                      _batchError != null)
                                    _buildResultBanner(),
                                  const SizedBox(height: 20),
                                ]),
                          ),
                        ),
                        if (visible.isEmpty)
                          SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                  padding: EdgeInsets.all(padding),
                                  child: orders.isEmpty
                                      ? const _EmptyState(
                                          icon: Icons.cloud_done_outlined,
                                          color: Color(0xFF16764A),
                                          title: 'No sales need sync attention.',
                                          subtitle:
                                              'Synced orders are available in Sales.')
                                      : _EmptyState(
                                          icon: Icons.filter_alt_off_outlined,
                                          color: const Color(0xFF64748B),
                                          title: 'No orders match this view.',
                                          subtitle:
                                              'Try another status or clear the search.',
                                          action: TextButton(
                                              key: const ValueKey(
                                                  'reset-order-filters'),
                                              onPressed: _resetFilters,
                                              child: const Text(
                                                  'Show all orders')))))
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                                padding, 0, padding, padding),
                            sliver: SliverMasonryGrid.count(
                              crossAxisCount:
                                  ((constraints.maxWidth - padding * 2) / 360)
                                      .floor()
                                      .clamp(1, 4),
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childCount: visible.length,
                              itemBuilder: (context, index) => _buildCard(
                                  visible[index], sync, busy, eligibleIds),
                            ),
                          ),
                      ]);
                });
              }),
            ),
          ),
        ),
      );

  void _resetFilters() => setState(() {
        _filter = _AttentionFilter.all;
        _search.clear();
      });

  Widget _buildToolbar({
    required bool compact,
    required bool busy,
    required Map<_AttentionFilter, int> counts,
    required List<SavedOrder> eligible,
    required Set<String> eligibleIds,
    required List<SavedOrder> selected,
    required bool allSelected,
    required bool narrowed,
  }) {
    final search = SizedBox(
      width: compact ? double.infinity : 280,
      height: 44,
      child: TextField(
        key: const ValueKey('search-attention-orders'),
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search order or customer',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(_search.clear)),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      ),
    );
    const labels = {
      _AttentionFilter.all: 'All',
      _AttentionFilter.needsReview: 'Needs review',
      _AttentionFilter.rejected: 'Rejected',
      _AttentionFilter.notSent: 'Not sent',
    };
    final chips = [
      for (final filter in _AttentionFilter.values)
        if (filter == _AttentionFilter.all || counts[filter]! > 0)
          ChoiceChip(
            key: ValueKey('filter-${filter.name}'),
            label: Text('${labels[filter]} · ${counts[filter]}'),
            selected: _filter == filter,
            showCheckmark: false,
            onSelected: (_) => setState(() => _filter = filter),
            labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _filter == filter
                    ? ColorManager.kPrimaryColor
                    : const Color(0xFF475569)),
            selectedColor: const Color(0xFFE8F1FD),
            backgroundColor: Colors.white,
            side: BorderSide(
                color: _filter == filter
                    ? ColorManager.kPrimaryColor
                    : const Color(0xFFE2E8F0)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
    ];
    // One swipeable row on phones keeps the first order above the fold.
    final filters = compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final chip in chips)
                Padding(padding: const EdgeInsets.only(right: 8), child: chip),
            ]))
        : Wrap(spacing: 8, runSpacing: 8, children: chips);
    final actions = Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
                key: const ValueKey('select-all-orders'),
                tristate: true,
                value: selected.isEmpty
                    ? false
                    : allSelected
                        ? true
                        : null,
                semanticLabel: 'Select all orders ready to sync',
                onChanged: busy || eligible.isEmpty
                    ? null
                    : (_) => setState(() {
                          if (allSelected) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(eligibleIds);
                          }
                        })),
            Text('${selected.length} selected',
                style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
          if (selected.isNotEmpty)
            TextButton(
                key: const ValueKey('clear-order-selection'),
                onPressed: busy ? null : () => setState(_selectedIds.clear),
                child: const Text('Clear')),
          FilledButton.icon(
              key: const ValueKey('sync-selected-orders'),
              onPressed:
                  busy || selected.isEmpty ? null : () => _syncOrders(selected),
              icon: const Icon(Icons.sync, size: 19),
              label: Text('Sync selected (${selected.length})'),
              style: FilledButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44))),
          OutlinedButton.icon(
              key: const ValueKey('sync-all-orders'),
              onPressed:
                  busy || eligible.isEmpty ? null : () => _syncOrders(eligible),
              icon: const Icon(Icons.cloud_upload_outlined, size: 19),
              label: Text(narrowed
                  ? 'Sync shown (${eligible.length})'
                  : 'Sync all (${eligible.length})'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                  side: const BorderSide(color: ColorManager.kPrimaryColor),
                  minimumSize: const Size(0, 44))),
        ]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (compact) ...[
          search,
          const SizedBox(height: 10),
          filters,
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: filters),
            const SizedBox(width: 12),
            search,
          ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
        actions,
      ]),
    );
  }

  Widget _buildProgress() => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Syncing orders · $_completed of $_total completed',
              key: const ValueKey('bulk-sync-progress'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F3D75))),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: _total == 0 ? 0 : _completed / _total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4)),
        ]),
      );

  Widget _buildResultBanner() {
    final result = _batchResult;
    final problems = result == null
        ? 1
        : result.rejected + result.needsReview + result.failed;
    final (color, background, icon, title) = _batchError != null
        ? (
            const Color(0xFFB42318),
            const Color(0xFFFEF3F2),
            Icons.error_outline,
            'Sync stopped',
          )
        : problems == 0
            ? (
                const Color(0xFF16764A),
                const Color(0xFFEAF7EF),
                Icons.check_circle_outline,
                'Sync finished',
              )
            : (
                const Color(0xFF9A5B07),
                const Color(0xFFFFF7E8),
                Icons.info_outline,
                'Sync finished · some orders still need attention',
              );
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_batchError ?? result!.summary,
                key: const ValueKey('bulk-sync-result'),
                style: const TextStyle(
                    color: Color(0xFF334155), fontSize: 13, height: 1.45)),
          ]),
        ),
        IconButton(
            key: const ValueKey('dismiss-bulk-sync-result'),
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 18),
            color: const Color(0xFF64748B),
            onPressed: () => setState(() {
                  _batchResult = null;
                  _batchError = null;
                })),
      ]),
    );
  }

  Widget _buildCard(SavedOrder order, LocalSaleSyncService sync, bool busy,
          Set<String> eligibleIds) =>
      LocalSaleAttentionCard(
        key: ValueKey('attention-order-${order.id}'),
        order: order,
        syncRecord: sync.recordFor(order.id),
        currency: _services.settings.appSettings?.currency ?? 'INR',
        selected: _selectedIds.contains(order.id),
        actionsEnabled: !busy && !sync.isSubmitting(order.id),
        onSelectionChanged: busy || !eligibleIds.contains(order.id)
            ? null
            : (value) => setState(() {
                  if (value) {
                    _selectedIds.add(order.id);
                  } else {
                    _selectedIds.remove(order.id);
                  }
                }),
        onView: () => showLocalSaleDetails(context, order, _services),
        onSync: () => _syncOrders([order]),
        onEdit: () => editLocalSaleRequest(context, order, _services),
        onDismiss: () => confirmAndDismissLocalSale(context, order, _services),
        onDelete: () => confirmAndDeleteLocalSale(context, order, _services),
        onLog: () => showLocalSaleSyncLog(context, order.id, _services),
        onPrint: () => printLocalSale(context, order, _services),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      this.action});

  final IconData icon;
  final Color color;
  final String title, subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]);
}
