import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/product/widgets/adjust_stock_modal.dart';
import 'package:pos_machine/screens/product/widgets/move_stock_modal.dart';
import 'package:pos_machine/screens/product/widgets/withdraw_stock_modal.dart';
import 'package:pos_machine/widgets/edit_stock_dialog.dart';
import 'package:provider/provider.dart';
import '../navigation/stock_navigation.dart';
import '../state/stock_list_controller.dart';
import '../../data/stock_list_snapshot.dart';
import '../../domain/stock_list_query.dart';
import '../export/stock_list_excel.dart';
import '../widgets/list/stock_list_header.dart';
import '../widgets/list/stock_list_layout.dart';
import '../widgets/list/stock_list_row_actions.dart';

class StockListPage extends StatefulWidget {
  const StockListPage({super.key, this.exportController});
  final ExportController? exportController;
  static const filterToggleKey = ValueKey('stock-filter-toggle');
  static const exportKey = ValueKey('stock-list-export');
  static const refreshKey = ValueKey('stock-list-refresh');
  @override
  State<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends State<StockListPage> {
  late final AuthModel _auth;
  late final StockProvider _stocks;
  late final PurchaseProvider _purchases;
  late final CategoryProvider _categories;
  late final AppSettingsProvider _settings;
  late final RoleProvider _role;
  late final StockListController _controller;
  late final StockNavigation _navigation;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  bool _stockWasLoading = false;
  bool _variantFeatureEnabled() =>
      _settings.appSettings?.productVariantEnabled ?? false;
  bool _canViewPurchasePrice() =>
      _role.currentUserHasPermissionSync(purchaseOrdersAccessPermission);

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthModel>();
    _stocks = context.read<StockProvider>();
    _purchases = context.read<PurchaseProvider>();
    _categories = context.read<CategoryProvider>();
    _settings = context.read<AppSettingsProvider>();
    _role = context.read<RoleProvider>();
    _navigation = StockNavigation(Get.put(SideBarController()));
    _export = widget.exportController ?? ExportController();
    _export.addListener(_rebuild);
    _controller = StockListController(
        ensureCategories: () async {
          if (!_categories.isCategoriesLoaded) {
            await _categories.ensureCategoriesLoaded();
          }
        },
        fetchStocks: _stocks.loadAllStocks,
        fetchStores: (token) => _purchases.listAllStores(token, null),
        readCategoryNames: () =>
            (_categories.category ?? []).map((item) => item.categoryName ?? ''),
        readStoreNames: () =>
            (_stocks.allStocks ?? []).map((item) => item.storeName ?? ''),
        readVariantEnabled: _variantFeatureEnabled,
        resetFilters: _stocks.resetStockFilters,
        applyFilters: (query) => _stocks.applyStockFiltersLocally(
            filterName: query.name,
            filterCategory: query.category,
            filterBarcode: query.barcode,
            filterRack: query.rack,
            filterStore: query.store,
            filterStatus: query.status,
            includeVariants: query.includeVariants,
            page: 1));
    _stockWasLoading = _stocks.stockIsLoading;
    _stocks.addListener(_stockChanged);
    _settings.addListener(_rebuild);
    _role.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.setFiltersVisible(MediaQuery.sizeOf(context).width >=
          ListLayoutBreakpoints.mobileBelow);
      _load();
    });
  }

  Future<void> _load() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      AppToast.error(context, 'stock.auth_token_missing'.tr);
      return;
    }
    try {
      await _controller.load(token);
    } catch (error) {
      if (mounted) {
        AppToast.error(context,
            'stock.error_loading_stocks'.trParams({'error': '$error'}));
      }
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _stockChanged() {
    if (!mounted) return;
    final finishedLoading = _stockWasLoading && !_stocks.stockIsLoading;
    // Consume the loading edge before restoring: filtering also notifies us.
    _stockWasLoading = _stocks.stockIsLoading;
    final applied = _controller.appliedQuery;
    if (finishedLoading &&
        !_controller.loading &&
        _controller.initialized &&
        applied != null) {
      final providerQuery = StockListQuery(
          name: _stocks.stockFilterName ?? '',
          category: _stocks.stockFilterCategory,
          barcode: _stocks.stockFilterBarcode,
          rack: _stocks.stockFilterRack,
          store: _stocks.stockFilterStore,
          status: _stocks.stockFilterStatus,
          includeVariants: applied.includeVariants);
      if (!applied.sameFiltersAs(providerQuery)) {
        _controller.restoreAppliedFilters();
      }
    }
    _rebuild();
  }

  @override
  void dispose() {
    _stocks.removeListener(_stockChanged);
    _settings.removeListener(_rebuild);
    _role.removeListener(_rebuild);
    _controller.dispose();
    _export.removeListener(_rebuild);
    if (widget.exportController == null) _export.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  Widget _actions(ListStockModelData stock, bool isMobile) =>
      StockListRowActions(
          isMobile: isMobile,
          stock: stock,
          onEdit: _showEditStockModal,
          onView: _showStockDetails,
          onAdjust: _showAdjustStockModal,
          onMove: _showMoveStockModal,
          onWithdraw: _showWithdrawStockModal);
  Future<void> _copyBarcode(ListStockModelData stock) async {
    final barcode = stock.barCode;
    if (barcode == null || barcode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: barcode));
    if (mounted) {
      AppToast.success(context,
          'stock.copied_to_clipboard'.trParams({'label': 'stock.barcode'.tr}));
    }
  }

  Future<void> _exportStocks() async {
    if (_export.busy) return;
    // Commit only pending text edits; exporting never resets an unchanged page.
    _controller.flushSearch();
    if (_controller.loading ||
        _stocks.stockIsLoading ||
        !_controller.initialized ||
        _controller.loadError != null) {
      return;
    }
    if (_stocks.listStockModelDataList?.isEmpty ?? true) {
      AppToast.info(context, 'stock.no_stock_filtered'.tr);
      return;
    }
    final applied = _controller.appliedQuery;
    if (applied == null) return;
    final snapshot = stockListSnapshot(
        _stocks.allStocks ?? const <ListStockModelData>[], applied,
        secondaryName: _stocks.stockFilterNameSecondary);
    final canViewCost = _canViewPurchasePrice();
    final variants = _variantFeatureEnabled();
    final exported = await _export.run(context,
        createFile: () => exportStockListExcel(snapshot,
            canViewPurchasePrice: canViewCost, variantEnabled: variants));
    if (!exported && mounted) {
      AppToast.error(context, 'stock.list_export_error'.tr);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final rows =
            _stocks.listStockModelDataList ?? const <ListStockModelData>[];
        final loading = _controller.loading || _stocks.stockIsLoading;
        final failed = _controller.loadError != null;
        return stockListLayout(
          inputs: _controller,
          rows: rows,
          loading: loading,
          failed: failed,
          header: stockListHeader(
              inputs: _controller,
              export: _export,
              loading: loading,
              failed: failed,
              hasRows: rows.isNotEmpty,
              onExport: _exportStocks,
              onRefresh: _load,
              onAdd: _navigation.openAdd),
          canViewPurchasePrice: _canViewPurchasePrice(),
          variantEnabled: _variantFeatureEnabled(),
          tableScroll: _tableScroll,
          onRefresh: _load,
          actions: _actions,
          onCopy: _copyBarcode,
          pagination: ListPagination(
              currentPage: _stocks.stockCurrentPage,
              totalPages: _stocks.stockTotalPages,
              itemsPerPage: _stocks.stockItemsPerPage,
              onPageChanged: (page) {
                if (_controller.flushSearch()) return;
                _stocks.goToStockPage(page);
              },
              countLabel:
                  'stock.list_count'.trParams({'count': '${rows.length}'})),
        );
      });
  void _showStockDetails(ListStockModelData stock) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'stock.details_title'.tr,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow('stock.product_name'.tr,
                        stock.productName ?? 'stock.na'.tr),
                    if (_variantFeatureEnabled() &&
                        stock.productVariantId != null)
                      _buildDetailRow(
                        'stock.product_variant'.tr,
                        stock.variantName?.trim().isNotEmpty == true
                            ? stock.variantName!
                            : 'Variant #${stock.productVariantId}',
                      ),
                    _buildDetailRow('stock.category'.tr,
                        stock.categoryName ?? 'stock.na'.tr),
                    _buildDetailRow('stock.store_name'.tr,
                        stock.storeName ?? 'stock.na'.tr),
                    _buildDetailRow('stock.supplier'.tr,
                        stock.supplierName ?? 'stock.na'.tr),
                    _buildDetailRow(
                        'stock.unit'.tr, stock.unit ?? 'stock.na'.tr),
                    _buildDetailRow('stock.retail_price'.tr,
                        stock.retailPrice?.toString() ?? 'stock.na'.tr),
                    _buildDetailRow(
                        'stock.mrp'.tr, stock.mrp?.toString() ?? 'stock.na'.tr),
                    if (_canViewPurchasePrice())
                      _buildDetailRow('stock.purchase_price'.tr,
                          stock.purchaseRate?.toString() ?? 'stock.na'.tr),
                    _buildDetailRow('stock.quantity'.tr,
                        stock.qty?.toString() ?? 'stock.na'.tr),
                    _buildDetailRow(
                        'stock.rack'.tr, stock.rack ?? 'stock.na'.tr),
                    _buildDetailRow(
                        'stock.barcode'.tr, stock.barCode ?? 'stock.na'.tr),
                    _buildDetailRow('stock.wholesale_price'.tr,
                        stock.wholesalePrice?.toString() ?? 'stock.na'.tr),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: 'stock.close'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditStockModal(ListStockModelData stock) {
    if (stock.stockId == null) {
      showScaffoldError(
        context: context,
        message: 'stock.edit_missing_id'.tr,
      );
      return;
    }

    showEditStockDialog(
      context: context,
      stockId: stock.stockId!,
      title: 'stock.edit_stock_title'
          .trParams({'productName': stock.productName ?? ''}),
      initialRetailPrice: stock.retailPrice ?? '',
      initialMrp: stock.mrp ?? '',
      initialPurchasePrice: stock.purchaseRate ?? '',
      showPurchasePrice: _canViewPurchasePrice(),
      initialQuantity: stock.qty?.toString() ?? '0',
      initialRack: stock.rack ?? '',
    );
  }

  void _showAdjustStockModal(ListStockModelData stock) {
    debugPrint(
        '🛠️ SHOW ADJUST STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    showDialog(
      context: context,
      builder: (context) => AdjustStockModal(stock: stock),
    );
  }

  void _showMoveStockModal(ListStockModelData stock) {
    debugPrint(
        '🚚 SHOW MOVE STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    final purchaseProvider = _purchases;
    debugPrint('   STORES AVAILABLE: ${purchaseProvider.storeList.length}');
    showDialog(
      context: context,
      builder: (context) => MoveStockModal(
        stock: stock,
        stores: purchaseProvider.storeList,
      ),
    );
  }

  void _showWithdrawStockModal(ListStockModelData stock) {
    debugPrint(
        '💸 SHOW WITHDRAW STOCK MODAL: ID=${stock.stockId}, Name=${stock.productName}');
    showDialog(
      context: context,
      builder: (context) => WithdrawStockModal(stock: stock),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
