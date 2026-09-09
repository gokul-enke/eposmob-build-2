import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'package:pos_machine/resources/recovery_text.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';

/// Keeps submission scope and protects the active cart during checkout.
/// Billing owns its loading state and snackbar; recovery lives in Sales.
class OrderSubmissionStatus extends StatefulWidget {
  const OrderSubmissionStatus(
      {super.key, required this.child, this.coordinator});
  final Widget child;
  final OrderSubmissionCoordinator? coordinator;
  @override
  State<OrderSubmissionStatus> createState() => _OrderSubmissionStatusState();
}

class _OrderSubmissionStatusState extends State<OrderSubmissionStatus> {
  late final coordinator =
      widget.coordinator ?? OrderSubmissionCoordinator.instance;
  String? _session;
  int _scopeGeneration = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthModel>();
    final store = context.watch<StoreSessionProvider>().activeStore?.storeId;
    final session = '${auth.userId}|${auth.token}|$store|${APPUrl.baseURL}';
    if (_session != session) {
      _session = session;
      final generation = ++_scopeGeneration;
      unawaited(_selectScope(generation));
    }
  }

  Future<void> _selectScope(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _scopeGeneration) return;
    coordinator.selectScope(OrderSubmissionCoordinator.scopeFor(
        Uri.parse(APPUrl.addToOrderUrl),
        prefs.getString('api_key') ?? '',
        prefs.getInt('active_store_id')));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) => ExcludeFocus(
          excluding: coordinator.isBusy,
          child: AbsorbPointer(
              absorbing: coordinator.isBusy, child: widget.child)));
}

class OrdersToReviewPage extends StatefulWidget {
  const OrdersToReviewPage({super.key, this.coordinator});
  final OrderSubmissionCoordinator? coordinator;
  @override
  State<OrdersToReviewPage> createState() => _OrdersToReviewPageState();
}

class _OrdersToReviewPageState extends State<OrdersToReviewPage> {
  late final coordinator =
      widget.coordinator ?? OrderSubmissionCoordinator.instance;
  String? _error;
  bool _finishing = false;

  Future<void> _removeReviewLog(Map<String, dynamic> record) async {
    if (_finishing || coordinator.isBusy) return;
    final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _dialog(
                dialogContext: dialogContext,
                title: 'Remove review log',
                icon: Icons.delete_outline,
                body: Text(recoveryText(
                    'Remove this log from this device? This does not delete or cancel the order in the admin panel. Remove it only after checking the order.')),
                actions: [
                  OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(recoveryText('Keep for review'))),
                  FilledButton(
                      key: const ValueKey('review-remove-confirm'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB42318)),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(recoveryText('Remove review log'))),
                ]));
    if (approved != true || !mounted || coordinator.isBusy) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      await coordinator.removeReviewLog(record['id'] as String);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            recoveryText('Could not remove the log. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _finishConfirmed(Map<String, dynamic> record) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      final products = context.read<LocalProductProvider>();
      if (products.cartSessionId != (record['cart_session_id'] ?? 'legacy')) {
        // Identical products do not imply that this is the original sale.
        await coordinator.markReviewed(record['id'] as String);
        return;
      }
      final snapshot = Map<String, dynamic>.from(record['snapshot'] as Map);
      // The POST reverses items. Only clear the original cart, never a newer
      // one that happened to be opened before a late response arrived.
      final originalItems = jsonEncode(snapshot['items']);
      final currentItems =
          jsonEncode(products.buildOrderItemsPayload().reversed.toList());
      final hasCart = products.cartItems.isNotEmpty;
      if ((hasCart && originalItems != currentItems) ||
          (products.currentOrder != null &&
              products.currentOrder!.id != record['local_draft_id'])) {
        throw StateError(recoveryText(
            'The current cart differs from the saved attempt. It has been kept unchanged. Restore the original cart to finish this order.'));
      }
      if (hasCart) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => _dialog(
            dialogContext: dialogContext,
            title: 'Finish saved order',
            icon: Icons.check_circle_outline,
            body: Text(recoveryText(
                'The current cart matches the saved items. Confirm that this is the original sale before clearing it.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(recoveryText('Keep for review'))),
              FilledButton(
                  key: const ValueKey('submission-clear-matching-cart'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(recoveryText('Clear this matching cart'))),
            ],
          ),
        );
        if (approved != true || !mounted) return;
        // Recheck after the dialog; asynchronous refresh must not change what
        // was reviewed while the operator was deciding.
        if (jsonEncode(products.buildOrderItemsPayload().reversed.toList()) !=
                currentItems ||
            products.currentOrder?.id != record['local_draft_id']) {
          throw StateError(recoveryText(
              'The current cart differs from the saved attempt. It has been kept unchanged. Restore the original cart to finish this order.'));
        }
        if (record['local_draft_id'] is String) {
          products.deleteSavedOrder(record['local_draft_id'] as String);
        }
        products.clearCartAfterOrder();
        products.clearCurrentOrder();
      }
      await products.flushPersistence();
      await coordinator.acknowledge(record['id'] as String);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  static const _ink = ColorManager.kTitleTextColor;
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE4EAF1);
  static const _blue = ColorManager.kPrimaryColor;

  ThemeData _reviewTheme(BuildContext context) => Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _blue,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _ink,
          surfaceTint: Colors.transparent),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _line),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _blue)));

  String _amount(dynamic value) =>
      value == null ? '—' : AmountHelper.formatAmount(value);
  String _total(Map<String, dynamic> record) {
    final currency =
        context.read<AppSettingsProvider?>()?.appSettings?.currency ?? '';
    return '$currency ${_amount(record['total'])}'.trim();
  }

  Widget _status(Map<String, dynamic> record) {
    final confirmed = record['state'] == 'confirmed';
    final color = confirmed ? const Color(0xFF16764A) : const Color(0xFF936014);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color:
                confirmed ? const Color(0xFFECF8F1) : const Color(0xFFFFF5E2),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(confirmed ? Icons.check_circle_outline : Icons.schedule_outlined,
              size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
              child: Text(
                  recoveryText(confirmed
                      ? 'Order confirmed'
                      : 'Confirmation not received'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color))),
        ]));
  }

  Widget _note(String text, {bool warning = false}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFFFF8EB) : const Color(0xFFEDF5FF),
          borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline,
            size: 20, color: warning ? const Color(0xFF936014) : _blue),
        const SizedBox(width: 10),
        Expanded(
            child: Text(recoveryText(text),
                style:
                    const TextStyle(fontSize: 13, height: 1.6, color: _ink))),
      ]));

  Widget _detail(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(recoveryText(label),
            style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
      ]);

  Widget _dialog(
          {required BuildContext dialogContext,
          required String title,
          required IconData icon,
          required Widget body,
          required List<Widget> actions}) =>
      Theme(
          data: _reviewTheme(context),
          child: Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                        child: Row(children: [
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEDF5FF),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Icon(icon, color: _blue, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(recoveryText(title),
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      color: _ink))),
                          IconButton(
                              tooltip: recoveryText('Close'),
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close, size: 21)),
                        ])),
                    const Divider(height: 1, color: _line),
                    Flexible(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20), child: body)),
                    const Divider(height: 1, color: _line),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.end,
                                children: actions))),
                  ]))));

  void _reviewAttempt(Map<String, dynamic> record) {
    final snapshot = Map<String, dynamic>.from(record['snapshot'] as Map);
    final items = (snapshot['items'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final products = context.read<LocalProductProvider?>()?.products;
    final names = {
      if (products != null)
        for (final product in products) product.productId: product.productName
    };
    showDialog<void>(
        context: context,
        builder: (dialogContext) => _dialog(
                dialogContext: dialogContext,
                title: 'Order details',
                icon: Icons.receipt_long_outlined,
                body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _status(record),
                      const SizedBox(height: 20),
                      Wrap(spacing: 32, runSpacing: 16, children: [
                        _detail(
                            'Time',
                            DateHelper.formatISODateToIST(
                                record['created_at']?.toString() ?? '')),
                        if (record['order_id'] != null)
                          _detail('Saved order',
                              '${record['order_number'] ?? record['order_id']}'),
                      ]),
                      const SizedBox(height: 20),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          color: const Color(0xFFF4F7FA),
                          child: Row(children: [
                            Expanded(
                                flex: 3,
                                child: Text(recoveryText('Item'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            Expanded(
                                child: Text(recoveryText('Qty'),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            Expanded(
                                flex: 2,
                                child: Text(recoveryText('Unit price'),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                          ])),
                      for (final item in items)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: const BoxDecoration(
                                border:
                                    Border(bottom: BorderSide(color: _line))),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text(
                                          names[item['product_id']] ??
                                              '#${item['product_id']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500))),
                                  Expanded(
                                      child: Text('${item['quantity'] ?? '—'}',
                                          textAlign: TextAlign.end)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(_amount(item['price']),
                                          textAlign: TextAlign.end)),
                                ])),
                      if (items.isEmpty)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(recoveryText('No saved items.'))),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(children: [
                            Expanded(
                                child: Text(recoveryText('Total'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            Expanded(
                                child: Text(_total(record),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: _ink))),
                          ])),
                      if (record['state'] != 'confirmed')
                        _note(
                            'Retrying may create a duplicate order. Compare these attempts with the admin panel and cancel any duplicate orders there.',
                            warning: true),
                      const SizedBox(height: 12),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.all(12),
                          title: Text(recoveryText('Details for support'),
                              style:
                                  const TextStyle(fontSize: 13, color: _muted)),
                          children: [
                            SizedBox(
                                width: double.infinity,
                                child: SelectableText(
                                    const JsonEncoder.withIndent('  ').convert({
                                      'created_at': record['created_at'],
                                      'submission_id': record['id'],
                                      'order_number': record['order_number'],
                                      'sale': record['snapshot'],
                                    }),
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        height: 1.5)))
                          ]),
                    ]),
                actions: [
                  OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(recoveryText('Close')))
                ]));
  }

  Widget _orderCard(Map<String, dynamic> record) {
    final items = (record['snapshot'] as Map?)?['items'] as List? ?? const [];
    return Container(
        key: ValueKey('review-order-${record['id']}'),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(builder: (context, constraints) {
                final summary = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _status(record),
                      const SizedBox(height: 16),
                      Text(
                          DateHelper.formatISODateToIST(
                              record['created_at'] as String),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                      const SizedBox(height: 6),
                      Text('${recoveryText('Items')}: ${items.length}',
                          style: const TextStyle(fontSize: 13, color: _muted)),
                      if (record['order_id'] != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '${recoveryText('Saved order')}: ${record['order_number'] ?? record['order_id']}',
                                style: const TextStyle(color: _muted))),
                    ]);
                final total = Column(
                    crossAxisAlignment: constraints.maxWidth < 500
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end,
                    children: [
                      Text(recoveryText('Total'),
                          style: const TextStyle(fontSize: 12, color: _muted)),
                      const SizedBox(height: 6),
                      Text(_total(record),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                    ]);
                return constraints.maxWidth < 500
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [summary, const SizedBox(height: 20), total])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: summary),
                            const SizedBox(width: 24),
                            ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * .45),
                                child: total)
                          ]);
              })),
          const Divider(height: 1, color: _line),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                    key: ValueKey('review-details-${record['id']}'),
                    onPressed: () => _reviewAttempt(record),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(recoveryText('Review details'))),
                if (record['state'] == 'confirmed')
                  OutlinedButton(
                      onPressed:
                          _finishing ? null : () => _finishConfirmed(record),
                      child: Text(recoveryText('Finish saved order'))),
                TextButton.icon(
                    key: ValueKey('review-remove-${record['id']}'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318)),
                    onPressed: _finishing || coordinator.isBusy
                        ? null
                        : () => _removeReviewLog(record),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(recoveryText('Remove review log'))),
              ])),
        ]));
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: _reviewTheme(context),
      child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
              child: ListenableBuilder(
                  listenable: coordinator,
                  builder: (context, _) {
                    final records = coordinator.ordersToReview;
                    return LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                                padding: EdgeInsets.all(
                                    constraints.maxWidth < 600 ? 16 : 28),
                                child: Align(
                                    alignment: AlignmentDirectional.topStart,
                                    child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 1120),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                if (ModalRoute.of(context)
                                                        ?.settings
                                                        .name ==
                                                    '/orders-to-review')
                                                  BackButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context)),
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFEDF5FF),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12)),
                                                    child: const Icon(
                                                        Icons
                                                            .fact_check_outlined,
                                                        color: _blue,
                                                        size: 26)),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                    child: Text(
                                                        recoveryText(
                                                            'Orders to review'),
                                                        style: const TextStyle(
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: _ink))),
                                                const SizedBox(width: 12),
                                                Text('${records.length}',
                                                    style: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _muted)),
                                              ]),
                                              const SizedBox(height: 24),
                                              _note(
                                                  'You can keep billing or retry an unconfirmed sale. Retrying may create duplicates. Compare these attempts with the admin panel.'),
                                              if (_error != null)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 16),
                                                    child: _note(_error!,
                                                        warning: true)),
                                              if (records.isEmpty)
                                                Container(
                                                    width: double.infinity,
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 20),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 64),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: _line)),
                                                    child: Column(children: [
                                                      const Icon(Icons.task_alt,
                                                          size: 44,
                                                          color: Color(
                                                              0xFF16764A)),
                                                      const SizedBox(
                                                          height: 16),
                                                      Text(
                                                          recoveryText(
                                                              'No orders need review.'),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: _ink)),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                          recoveryText(
                                                              'New orders that need checking will appear here.'),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                                  color: _muted,
                                                                  height: 1.5)),
                                                    ])),
                                              for (final record in records)
                                                _orderCard(record),
                                            ])))));
                  }))));
}
