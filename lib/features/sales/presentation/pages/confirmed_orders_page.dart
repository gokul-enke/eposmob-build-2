import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

import '../commands/confirm_and_delete_local_sale.dart';
import '../commands/confirm_and_dismiss_local_sale.dart';
import '../commands/confirm_and_remove_local_sales.dart';
import '../commands/confirm_and_sync_local_sales.dart';
import '../commands/confirm_day_close_with_unsynced_sales.dart';
import '../commands/edit_local_sale_request.dart';
import '../commands/local_sales_services.dart';
import '../commands/print_local_sale.dart';
import '../commands/show_local_sale_details.dart';
import '../commands/show_local_sale_sync_log.dart';
import '../commands/update_local_sale_identity.dart';
import '../widgets/local_orders/local_sale_attention_card.dart';

enum _AttentionFilter { all, needsReview, rejected, notSent }

class ConfirmedOrdersPage extends StatefulWidget {
  const ConfirmedOrdersPage({super.key});

  static const filterToggleKey = ValueKey('attention-filter-toggle');

  @override
  State<ConfirmedOrdersPage> createState() => _ConfirmedOrdersPageState();
}

class _ConfirmedOrdersPageState extends State<ConfirmedOrdersPage> {
  late final LocalSalesServices _services;
  final Set<String> _selectedIds = {};
  final _search = TextEditingController();
  _AttentionFilter _filter = _AttentionFilter.all;
  bool _showFilters = true;
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

  bool _matchesSearch(SavedOrder order, LocalSaleSyncRecord? record) {
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        order.orderNumber.toLowerCase().contains(query) ||
        localSaleReceiptNumber(order, record).toLowerCase().contains(query) ||
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
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Consumer2<LocalProductProvider, LocalSaleSyncService>(
              builder: (context, provider, sync, _) {
            final busy = _batchActive || sync.isBatchSyncing;
            final orders = localSalesNeedingSync(provider, sync);
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
                    _matchesSearch(order, sync.recordFor(order.id)))
                .toList();
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
            final mobile = MediaQuery.sizeOf(context).width <
                ListLayoutBreakpoints.mobileBelow;
            final padding = mobile ? AppSpacing.md : AppSpacing.xl;
            final gap = mobile ? AppSpacing.md : AppSpacing.lg;
            return LayoutBuilder(builder: (context, constraints) {
              // Same centred content width as the other listing pages.
              final side = math.max(
                  padding,
                  (constraints.maxWidth -
                          ListLayoutBreakpoints.maxContentWidth) /
                      2);
              final contentWidth = constraints.maxWidth - side * 2;
              return CustomScrollView(
                  key: const ValueKey('confirmed-orders-scroll'),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, padding, side, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(
                                  busy: busy,
                                  total: orders.length,
                                  eligible: eligible),
                              if (orders.isNotEmpty) ...[
                                // Kept in the tree while hidden so the search
                                // and status keep applying.
                                Visibility(
                                  visible: _showFilters,
                                  maintainState: true,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: gap),
                                    child: _buildFilters(mobile, counts),
                                  ),
                                ),
                                SizedBox(height: gap),
                                _buildSelectionBar(
                                  busy: busy,
                                  eligible: eligible,
                                  eligibleIds: eligibleIds,
                                  selected: selected,
                                  allSelected: allSelected,
                                ),
                              ],
                              if (_sending) _buildProgress(),
                              if (_batchResult != null || _batchError != null)
                                _buildResultBanner(),
                              SizedBox(height: gap),
                            ]),
                      ),
                    ),
                    if (visible.isEmpty)
                      SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                              padding: EdgeInsets.all(padding),
                              child: Center(
                                child: orders.isEmpty
                                    ? const AppEmptyState(
                                        icon: Icons.cloud_done_outlined,
                                        title: 'No sales need sync attention.',
                                        subtitle:
                                            'Synced orders are available in Sales.')
                                    : AppEmptyState(
                                        icon: Icons.filter_alt_off_outlined,
                                        title: 'No orders match this view.',
                                        subtitle:
                                            'Try another status or clear the search.',
                                        action: AppOutlinedButton(
                                            key: const ValueKey(
                                                'reset-order-filters'),
                                            label: 'Show all orders',
                                            icon: Icons.restart_alt_rounded,
                                            onPressed: _resetFilters)),
                              )))
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, 0, side, padding),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount:
                              (contentWidth / 360).floor().clamp(1, 4),
                          mainAxisSpacing: AppSpacing.lg,
                          crossAxisSpacing: AppSpacing.lg,
                          childCount: visible.length,
                          itemBuilder: (context, index) => _buildCard(
                              visible[index], sync, busy, eligibleIds),
                        ),
                      ),
                  ]);
            });
          }),
        ),
      );

  void _resetFilters() => setState(() {
        _filter = _AttentionFilter.all;
        _search.clear();
      });

  bool get _filtered =>
      _filter != _AttentionFilter.all || _search.text.trim().isNotEmpty;

  Widget _buildHeader({
    required bool busy,
    required int total,
    required List<SavedOrder> eligible,
  }) =>
      PageHeader(
        icon: Icons.cloud_sync_outlined,
        title: 'Sync attention',
        subtitle: switch (total) {
          0 => 'Every order on this device has reached the server.',
          1 => '1 order on this device has not reached the server.',
          _ => '$total orders on this device have not reached the server.',
        },
        actions: [
          if (total > 0)
            HeaderAction.filters(
              key: ConfirmedOrdersPage.filterToggleKey,
              showFilters: _showFilters,
              showLabel: 'Show filters',
              hideLabel: 'Hide filters',
              badge: !_showFilters && _filtered,
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
        ],
        primaryActions: [
          if (total > 0)
            AppPrimaryButton(
              key: const ValueKey('sync-all-orders'),
              label: _filtered
                  ? 'Sync shown (${eligible.length})'
                  : 'Sync all (${eligible.length})',
              icon: Icons.cloud_upload_outlined,
              onPressed:
                  busy || eligible.isEmpty ? null : () => _syncOrders(eligible),
            ),
        ],
      );

  /// The shared search/filter panel; a collapsible tile on phones.
  Widget _buildFilters(bool mobile, Map<_AttentionFilter, int> counts) {
    const labels = {
      _AttentionFilter.all: 'All',
      _AttentionFilter.needsReview: 'Needs review',
      _AttentionFilter.rejected: 'Rejected',
      _AttentionFilter.notSent: 'Not sent',
    };
    final panel = FilterPanel(
      title: 'Find orders',
      hint: 'Search by receipt no. or customer, or pick a status.',
      resetLabel: 'Reset',
      embeddedResetLabel: 'Reset filters',
      onSearch: () => setState(() {}),
      onReset: _resetFilters,
      fields: [
        TextFilterField(
          controller: _search,
          label: 'Search',
          hint: 'Receipt no. or customer',
          icon: Icons.search_rounded,
        ),
        DropdownFilterField<_AttentionFilter>(
          label: 'Status',
          icon: Icons.flag_outlined,
          value: _filter,
          options: [
            for (final filter in _AttentionFilter.values)
              // Statuses with no orders are hidden unless selected.
              if (filter == _AttentionFilter.all ||
                  counts[filter]! > 0 ||
                  filter == _filter)
                FilterOption(filter, '${labels[filter]} (${counts[filter]})'),
          ],
          onChanged: (value) =>
              setState(() => _filter = value ?? _AttentionFilter.all),
        ),
      ],
    );
    if (!mobile) return panel;
    return CollapsibleFilterTile(
      title: 'Search and filters',
      collapsedSubtitle: 'Find an order by receipt no., customer or status',
      expandedSubtitle: 'Hide search and filters',
      child: panel.embedded(),
    );
  }

  Widget _buildSelectionBar({
    required bool busy,
    required List<SavedOrder> eligible,
    required Set<String> eligibleIds,
    required List<SavedOrder> selected,
    required bool allSelected,
  }) =>
      AppSurface(
        shadow: false,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
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
                Text('${selected.length} selected', style: AppTextStyles.value),
              ]),
              if (selected.isNotEmpty)
                TextButton(
                    key: const ValueKey('clear-order-selection'),
                    onPressed: busy ? null : () => setState(_selectedIds.clear),
                    child: const Text('Clear')),
              AppOutlinedButton(
                  key: const ValueKey('sync-selected-orders'),
                  label: 'Sync selected (${selected.length})',
                  icon: Icons.sync,
                  onPressed: busy || selected.isEmpty
                      ? null
                      : () => _syncOrders(selected)),
              Builder(builder: (context) {
                final removable = selected
                    .where((order) =>
                        localSaleCanRemove(_services.sync.recordFor(order.id)))
                    .length;
                return AppOutlinedButton(
                    key: const ValueKey('remove-selected-orders'),
                    label: 'Remove selected ($removable)',
                    icon: Icons.delete_outline,
                    foreground: AppColors.red,
                    onPressed: busy || removable == 0
                        ? null
                        : () => _removeOrders(selected));
              }),
            ]),
      );

  Future<void> _removeOrders(List<SavedOrder> orders) async {
    if (_batchActive) return;
    setState(() => _batchActive = true);
    try {
      final removed =
          await confirmAndRemoveLocalSales(context, orders, _services);
      if (mounted) setState(() => _selectedIds.removeAll(removed));
    } finally {
      if (mounted) setState(() => _batchActive = false);
    }
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      Set<String> eligibleIds) {
    final record = sync.recordFor(order.id);
    return LocalSaleAttentionCard(
      key: ValueKey('attention-order-${order.id}'),
      order: order,
      syncRecord: record,
      currency: _services.settings.appSettings?.currency ?? 'INR',
      receiptNumber: localSaleReceiptNumber(order, record),
      issuedAt: localSaleIssuedAt(order, record),
      onSaleDetailsChanged: ({receiptNumber, issuedAt}) =>
          updateLocalSaleIdentity(context, order, _services,
              receiptNumber: receiptNumber, issuedAt: issuedAt),
      selected: _selectedIds.contains(order.id),
      actionsEnabled: !busy && !sync.isSubmitting(order.id),
      submitting: sync.isSubmitting(order.id),
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
}
