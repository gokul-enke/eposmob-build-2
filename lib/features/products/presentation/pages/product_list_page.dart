import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import '../../data/product_list_source.dart';
import '../export/product_list_excel.dart';
import '../state/product_list_controller.dart';
import '../widgets/list/product_list_card.dart';
import '../widgets/list/product_list_filters.dart';
import '../widgets/list/product_list_labels.dart';
import '../widgets/list/product_list_table.dart';

/// Only the catalog listing. Existing product dialogs remain outside this feature.
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key, this.export});
  final ExportController? export;
  static const filterKey = ValueKey('product-filter-toggle');
  static const exportKey = ValueKey('product-list-export');
  static const refreshKey = ValueKey('product-list-refresh');
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late final LocalProductProvider _catalog;
  late final CategoryProvider _categories;
  late final AppSettingsProvider _settings;
  late final RoleProvider _role;
  late final ProductListController _list;
  late final ExportController _export;
  final _tableScroll = ScrollController();
  bool _visibilityInitialized = false;
  bool get _itemCodeEnabled => _settings.appSettings?.itemCodeEnabled ?? false;
  bool get _canViewPurchasePrice =>
      _role.currentUserHasPermissionSync(purchaseOrdersAccessPermission);
  @override
  void initState() {
    super.initState();
    _catalog = context.read<LocalProductProvider>();
    _categories = context.read<CategoryProvider>();
    _settings = context.read<AppSettingsProvider>();
    _role = context.read<RoleProvider>();
    _export = widget.export ?? ExportController();
    _list = ProductListController(
      source: ProductListSource(
          readCatalog: () => _catalog.products,
          deleteProduct: _catalog.deleteProductAPI),
      itemsPerPage: _catalog.itemsPerPage,
      ensureCategories: () async {
        if (!_categories.isCategoriesLoaded) {
          await _categories.ensureCategoriesLoaded();
        }
      },
    );
    _catalog.addListener(_catalogChanged);
    _categories.addListener(_rebuild);
    _settings.addListener(_rebuild);
    _role.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _list.initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visibilityInitialized) {
      _list.filtersVisible =
          MediaQuery.sizeOf(context).width >= ListLayoutBreakpoints.mobileBelow;
      _visibilityInitialized = true;
    }
  }

  void _catalogChanged() {
    if (mounted) _list.reloadCatalog();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalog.removeListener(_catalogChanged);
    _categories.removeListener(_rebuild);
    _settings.removeListener(_rebuild);
    _role.removeListener(_rebuild);
    _list.dispose();
    _tableScroll.dispose();
    if (widget.export == null) _export.dispose();
    super.dispose();
  }

  void _view(GetProduct product) => showDialog<void>(
      context: context,
      builder: (_) => ProductDetailsDialog(
          product: product, enforcePurchasePricePermission: true));
  Future<void> _add() async {
    await showDialog<void>(
        context: context, builder: (_) => const AddProductWithBarcodeModal());
    if (mounted) _list.reloadCatalog();
  }

  Future<void> _delete(GetProduct product) async {
    final id = product.productId;
    if (id == null || _list.deleting) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text('product.confirm_delete_title'.tr),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('product.confirm_delete_message'.tr),
                    Text('product.delete_product_label'
                        .trParams({'name': ProductListLabels.name(product)})),
                    Text('product.barcode_label'.trParams(
                        {'code': ProductListLabels.value(product.barcode)})),
                    if (product.itemCode?.isNotEmpty == true)
                      Text('product.item_code_label'
                          .trParams({'code': product.itemCode!})),
                    Text('product.price_label'.trParams({
                      'price': ProductListLabels.value(product.price?.price)
                    })),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text('general.cancel'.tr)),
                AppOutlinedButton(
                    label: 'product.delete'.tr,
                    foreground: AppColors.red,
                    onPressed: () => Navigator.pop(dialog, true)),
              ],
            ));
    if (confirmed != true || !mounted) return;
    try {
      final success = await _list.delete(id);
      if (!mounted) return;
      if (success) {
        AppToast.success(context, 'product.deleted_success'.tr);
      } else {
        AppToast.error(context, 'product.delete_failed'.tr);
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'product.delete_failed'.tr);
    }
  }

  Future<void> _runExport() async {
    if (!_list.canExport || _export.busy) return;
    List<GetProduct> snapshot;
    try {
      snapshot = _list.exportSnapshot();
    } catch (_) {
      if (mounted) {
        if (_list.all.isEmpty) {
          AppToast.info(context, 'product.no_products'.tr);
        } else {
          AppToast.error(context, 'product_list.export_error'.tr);
        }
      }
      return;
    }
    final itemCodeEnabled = _itemCodeEnabled;
    final canViewPurchasePrice = _canViewPurchasePrice;
    final success = await _export.run(context,
        shareText: 'product.title'.tr,
        createFile: () => exportProductList(snapshot,
            itemCodeEnabled: itemCodeEnabled,
            canViewPurchasePrice: canViewPurchasePrice));
    if (!success && mounted) {
      AppToast.error(context, 'product_list.export_error'.tr);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_list, _export]),
      builder: (context, _) {
        final mobile = MediaQuery.sizeOf(context).width <
            ListLayoutBreakpoints.mobileBelow;
        final rows = _list.rows;
        return ListPageScaffold<GetProduct>(
          header: PageHeader(
              icon: Icons.inventory_2_outlined,
              title: 'product.title'.tr,
              subtitle: 'product_list.subtitle'.tr,
              onAdd: _list.deleting ? null : _add,
              addLabel: 'product.add'.tr,
              addShortLabel: 'product.add'.tr,
              actions: [
                HeaderAction(
                    key: ProductListPage.filterKey,
                    icon: _list.filtersVisible
                        ? Icons.filter_alt_rounded
                        : Icons.filter_alt_outlined,
                    label: _list.filtersVisible
                        ? 'product.hide_filters'.tr
                        : 'product.show_filters'.tr,
                    active: _list.filtersVisible,
                    badge: !_list.filtersVisible && _list.hasFilters,
                    onPressed: _list.toggleFilters),
                HeaderAction(
                    key: ProductListPage.exportKey,
                    icon: Icons.ios_share_rounded,
                    label: _export.busy
                        ? _export.stage ?? 'list.exporting'.tr
                        : 'list.export'.tr,
                    busy: _export.busy,
                    onPressed: _list.canExport ? _runExport : null),
                HeaderAction(
                    key: ProductListPage.refreshKey,
                    icon: Icons.refresh_rounded,
                    label: 'list.refresh'.tr,
                    onPressed:
                        _list.loading || _list.deleting ? null : _list.refresh),
              ]),
          showFilters: _list.filtersVisible,
          filters: productListFilters(_list, _categories.category ?? [],
              itemCodeEnabled: _itemCodeEnabled, mobile: mobile),
          toolbar: _list.error == null
              ? null
              : Row(children: [
                  Expanded(
                      child: Text('product_list.load_error'.tr,
                          style: AppTextStyles.body)),
                  TextButton(
                      onPressed: _list.loading ? null : _list.initialize,
                      child: Text('product_list.retry'.tr)),
                ]),
          isLoading: _list.loading || _list.deleting,
          items: rows,
          columns: productListColumns(
              itemCodeEnabled: _itemCodeEnabled,
              canViewPurchasePrice: _canViewPurchasePrice,
              onView: _view,
              onDelete: _delete,
              deleting: _list.deleting),
          cardBuilder: (product, number) => ProductListCard(
              product: product,
              number: number,
              itemCodeEnabled: _itemCodeEnabled,
              canViewPurchasePrice: _canViewPurchasePrice,
              onView: () => _view(product),
              onDelete: product.productId == null || _list.deleting
                  ? null
                  : () => _delete(product)),
          emptyState: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'product.no_products'.tr,
              subtitle: 'product_list.empty_hint'.tr),
          pagination: ListPagination(
              currentPage: _list.page,
              totalPages: _list.totalPages,
              itemsPerPage: _list.itemsPerPage,
              onPageChanged: _list.goToPage,
              countLabel:
                  'product_list.count'.trParams({'count': '${rows.length}'})),
          onRowTap: _view,
          onRefresh: _list.refresh,
          minTableWidth: ListLayoutBreakpoints.maxContentWidth,
          tableScrollController: _tableScroll,
        );
      });
}
