import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/sales_returns/presentation/printing/sales_return_print_items.dart';
import 'package:pos_machine/helpers/return_print_identity.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/screens/print/return_bill_print.dart';
import 'package:pos_machine/features/sales_returns/presentation/pages/sales_return_detail_modal.dart';
import '../../data/sales_return_list_repository.dart';
import '../../domain/sales_return_list.dart';
import '../state/sales_return_list_controller.dart';
import '../export/sales_return_list_excel.dart';
import '../widgets/sales_return_list_rows.dart';

class SalesReturnListPage extends StatefulWidget {
  const SalesReturnListPage(
      {super.key, this.readSource, this.exportController});
  final Future<SalesReturnListSource> Function()? readSource;
  final ExportController? exportController;
  static const exportKey = ValueKey('sales-return-list-export');
  static const refreshKey = ValueKey('sales-return-list-refresh');
  @override
  State<SalesReturnListPage> createState() => _SalesReturnListPageState();
}

class _SalesReturnListPageState extends State<SalesReturnListPage> {
  late final SalesReturnListController _controller;
  late final ExportController _export;
  final _scroll = ScrollController();
  AuthModel? _auth;
  StoreSessionProvider? _stores;
  String? _token;
  int? _storeId;

  @override
  void initState() {
    super.initState();
    _controller = SalesReturnListController(widget.readSource ?? _readSource);
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    if (widget.readSource == null) {
      _auth = context.read<AuthModel>();
      _stores = context.read<StoreSessionProvider>();
      _token = _auth!.token;
      _storeId = _stores!.activeStore?.storeId;
      _auth!.addListener(_sessionChanged);
      _stores!.addListener(_sessionChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load(page: 1);
    });
  }

  Future<SalesReturnListSource> _readSource() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) throw StateError('Sales return list closed');
    return SalesReturnListRepository(SalesReturnListScope(
      token: _auth!.token ?? '',
      tenant: preferences.getString('api_key') ?? '',
      storeId: preferences.getInt('active_store_id'),
      endpoint: APPUrl.listSalesReturn,
    ));
  }

  void _sessionChanged() {
    if (!mounted) return;
    final token = _auth!.token, storeId = _stores!.activeStore?.storeId;
    if (token == _token && storeId == _storeId) return;
    _token = token;
    _storeId = storeId;
    _controller.invalidate();
    _controller.load(page: 1);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _view(SalesReturnOrder order) => showDialog<void>(
      context: context, builder: (_) => SalesReturnDetailModal(order: order));
  void _print(SalesReturnOrder order) {
    final identity = ReturnPrintIdentity.fromTransaction(order);
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ReturnBillPrintPage(
                  returnItems:
                      buildTransactionReturnPrintItems(order.items, const []),
                  returnTotalAmount: order.totalAmount,
                  orderDate: identity.date,
                  orderNumber: identity.number,
                  originalInvoiceNumber: order.order?.orderNumber,
                  originalInvoiceDate: order.order?.orderDate,
                  customerName: order.order?.customer?.user?.name,
                )));
  }

  Future<void> _copy(SalesReturnOrder row) async {
    await Clipboard.setData(ClipboardData(text: row.displayNumber));
    if (mounted) {
      AppToast.success(
          context,
          row.receiptNumber != null
              ? 'sales_return.bill_copy_success'.tr
              : 'sales_return.copy_success'.tr);
    }
  }

  Future<void> _exportRows() async {
    if (!_controller.canExport || _export.busy) return;
    final currency =
        context.read<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    final readSource = widget.readSource ?? _readSource;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final succeeded =
        await _export.run(context, shareOrigin: origin, createFile: () async {
      final source = await readSource();
      Future<bool> isCurrent() async =>
          mounted &&
          _controller.matchesScope(source.scope) &&
          source.scope.sameAs((await readSource()).scope);
      final rows = await salesReturnListSnapshot(source,
          isCurrent: isCurrent,
          onPage: (page, total) => _export.setStage(
              'sales_return.list_export_fetching'
                  .trParams({'page': '$page', 'total': '$total'})));
      final file = await exportSalesReturnList(rows, currency);
      if (!await isCurrent()) {
        throw StateError('Sales return export scope changed');
      }
      return file;
    });
    if (!succeeded && mounted) {
      AppToast.error(context, 'sales_return.list_export_error'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final data = _controller.data;
          final failed = _controller.error != null;
          final retry = AppOutlinedButton(
              label: 'restaurant.retry'.tr,
              icon: Icons.refresh_rounded,
              onPressed: () => _controller.load());
          return ListPageScaffold<SalesReturnOrder>(
            header: PageHeader(
                icon: Icons.assignment_return_outlined,
                title: 'sales_return.title'.tr,
                subtitle: 'sales_return.subtitle'.tr,
                actions: [
                  HeaderAction(
                      key: SalesReturnListPage.exportKey,
                      icon: Icons.ios_share_rounded,
                      label: _export.stage ?? 'sales_return.list_export'.tr,
                      busy: _export.busy,
                      onPressed: _controller.canExport ? _exportRows : null),
                  HeaderAction(
                      key: SalesReturnListPage.refreshKey,
                      icon: Icons.refresh_rounded,
                      label: 'list.refresh'.tr,
                      onPressed: _controller.loading || _export.busy
                          ? null
                          : () => _controller.load()),
                ]),
            isLoading: _controller.loading,
            items: data?.rows ?? const [],
            columns: salesReturnListColumns(
                currency: currency,
                onCopy: _copy,
                onView: _view,
                onPrint: _print),
            cardBuilder: (row, _) => salesReturnListCard(row,
                currency: currency,
                onCopy: _copy,
                onView: _view,
                onPrint: _print),
            minTableWidth: 980,
            tableScrollController: _scroll,
            toolbar: failed && data?.rows.isNotEmpty == true
                ? AppSurface(
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Text('sales_return.list_load_failed'.tr),
                        retry
                      ]))
                : null,
            emptyState: AppEmptyState(
                icon: failed
                    ? Icons.error_outline
                    : Icons.assignment_return_outlined,
                title: failed
                    ? 'sales_return.err_load'.tr
                    : 'sales_return.no_returns_found'.tr,
                subtitle: failed ? null : 'sales_return.start_return_hint'.tr,
                action: failed ? retry : null),
            onRefresh: () => _controller.load(),
            pagination: ListPagination(
                currentPage: data?.page ?? 1,
                totalPages: data?.pages ?? 1,
                itemsPerPage: data?.perPage ?? 10,
                enabled: !failed && !_export.busy,
                onPageChanged: (page) => _controller.load(page: page),
                countLabel: 'sales_return.list_count'
                    .trParams({'count': '${data?.rows.length ?? 0}'})),
          );
        });
  }

  @override
  void dispose() {
    _auth?.removeListener(_sessionChanged);
    _stores?.removeListener(_sessionChanged);
    _controller.dispose();
    _export.removeListener(_rebuild);
    if (widget.exportController == null) _export.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
