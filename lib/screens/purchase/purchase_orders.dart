import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/models/list_purchase.dart';

import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';

import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  const AddPurchaseOrderScreen({super.key});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController supplierSearchController =
      TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();

  bool initLoading = false;
  bool _showFilters = false;
  static const int _itemsPerPage = 15;
  List<String> suppliers = ["All"];
  List<String> stores = ["All"];

  @override
  void initState() {
    super.initState();
    supplierController.text = "All";
    storeController.text = "All";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showFilters = !purchaseOrdersIsPhone(context);
        });
      }
    });
    loadInitData();
  }

  void loadInitData() async {
    final provider = Provider.of<PurchaseProvider>(context, listen: false);
    provider.activePurchaseOrderDetails = null;
    provider.voucherDetails = null;
    provider.listPurchaseItemView = [];

    setState(() => initLoading = true);

    try {
      String? token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null && token.isNotEmpty) {
        final provider = Provider.of<PurchaseProvider>(context, listen: false);
        await provider.listAllStores(token, null);
        await provider.listAllSuppliers(token, null);
        await provider.listPurchaseOrders(
          accessToken: token,
          storeId: "all", // Align with UI default "All"
        );

        if (mounted) {
          setState(() {
            stores = ["All", ...provider.storeList.map((e) => e.name ?? "")];
            suppliers = [
              "All",
              ...provider.supplierList.map((e) => e.user?.name ?? e.name ?? "")
            ];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading filter data: $e");
    } finally {
      if (mounted) setState(() => initLoading = false);
    }
  }

  Future<void> _fetchPurchases({int? page}) async {
    setState(() => initLoading = true);
    try {
      String? token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null && token.isNotEmpty) {
        final provider = Provider.of<PurchaseProvider>(context, listen: false);

        String? selectedSupplierId;
        if (supplierController.text != "All") {
          final supplier = provider.supplierList.firstWhere(
              (s) => (s.user?.name ?? s.name) == supplierController.text,
              orElse: () => provider.supplierDemo);
          if ((supplier.id ?? 0) > 0) {
            selectedSupplierId = supplier.id?.toString();
          }
        }

        String? selectedStoreId;
        if (storeController.text != "All") {
          final store = provider.storeList.firstWhere(
              (s) => s.name == storeController.text,
              orElse: () => provider.storeDemo);
          if ((store.id ?? 0) > 0) {
            selectedStoreId = store.id?.toString();
          } else {
            selectedStoreId = "all";
          }
        } else {
          selectedStoreId = "all";
        }

        final String? dateFrom = fromDateController.text.trim().isEmpty
            ? null
            : fromDateController.text.trim();
        final String? dateTo = toDateController.text.trim().isEmpty
            ? null
            : toDateController.text.trim();

        await provider.listPurchaseOrders(
          accessToken: token,
          storeId: selectedStoreId,
          supplierId: selectedSupplierId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          page: page,
        );
      }
    } finally {
      if (mounted) setState(() => initLoading = false);
    }
  }

  Future<void> _handleOrderAction(
      PurchaseOrderData item, int targetIndex) async {
    final token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null) return;

    final provider = Provider.of<PurchaseProvider>(context, listen: false);

    // If we have items in the list (new API format), use them for both View and Create/Receive
    if (item.items != null && item.items!.isNotEmpty) {
      // 1. Prepare data for CreatePurchaseOrderScreen (index 82)
      // We map the item back to a Map format so the Screen's pre-population logic works even if detail API fails
      provider.activePurchaseOrderDetails = {
        'id': item.id,
        'voucher_number': item.voucherNumber,
        'purchase_date': item.purchaseDate,
        'amount_total': item.amountTotal,
        'discount': item.discount,
        'status': item.status,
        'items': item.items
            ?.map((i) => {
                  'id': i.id,
                  'category_id': i.categoryId,
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'product_variant_id': i.productVariantId,
                  'variant_name': i.variantName,
                  'store_id': i.storeId,
                  'supplier_id': i.supplierId,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'total_price': i.totalPrice,
                  'calculated_purchase_rate': i.calculatedPurchaseRate,
                  'tax_include': i.taxInclude ?? true,
                  'tax_include_purchase':
                      i.taxIncludePurchase ?? i.taxInclude ?? true,
                  'expiry_date': i.expiryDate,
                  'batch_number': i.batchNumber,
                  'unit': i.unit,
                  'status': i.status,
                })
            .toList(),
        'store': item.store != null
            ? {'id': item.store?.id, 'name': item.store?.name}
            : null,
        'supplier': item.supplier != null
            ? {'id': item.supplier?.id, 'name': item.supplier?.name}
            : null,
      };

      // 2. Prepare data for ViewPurchaseWidget (index 36)
      provider.listPurchaseItemView = item.items!
          .map((i) => PurchaseItem(
                id: i.id,
                productId: i.productId,
                name: i.productName,
                quantity: int.tryParse(i.quantity ?? "0") ?? 0,
                unitPrice: int.tryParse(i.unitPrice?.split('.')[0] ?? "0") ?? 0,
                unit: i.unit,
              ))
          .toList();

      provider.voucherDetails = VoucherDetail(
        id: item.id,
        voucherNumber: item.voucherNumber,
        purchaseDate: item.purchaseDate,
        amountTotal: int.tryParse(item.amountTotal?.split('.')[0] ?? "0") ?? 0,
        status: item.status,
      );

      provider.ListPurchaseModelDataDetails = ListPurchaseModelData(
        id: item.id,
        amountTotal: int.tryParse(item.amountTotal?.split('.')[0] ?? "0") ?? 0,
        status: item.status,
      );

      Get.find<SideBarController>().index.value = targetIndex;
      return;
    }

    // Fallback: fetch details if items are missing in the list
    await provider.fetchPurchaseOrderDetails(
      accessToken: token,
      purchaseId: item.id.toString(),
    );

    // Navigate
    Get.find<SideBarController>().index.value = targetIndex;
  }

  void resetSearch() {
    setState(() {
      supplierController.text = "All";
      storeController.text = "All";
      fromDateController.clear();
      toDateController.clear();
    });
    _fetchPurchases();
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  bool _hasActiveFilters() {
    return supplierController.text != "All" ||
        storeController.text != "All" ||
        fromDateController.text.isNotEmpty ||
        toDateController.text.isNotEmpty;
  }

  bool _canReceiveOrder(PurchaseOrderData item) {
    if (item.itemsReceived == null) return false;
    final parts = item.itemsReceived!.split('/');
    if (parts.length != 2) return false;
    final received = int.tryParse(parts[0].trim()) ?? 0;
    final total = int.tryParse(parts[1].trim()) ?? 0;
    return received < total && total > 0;
  }

  String _itemsReceivedLabel(PurchaseOrderData item) {
    if (item.itemsReceived == null || item.itemsReceived!.isEmpty) {
      return "0 / 0";
    }
    return item.itemsReceived!;
  }

  Widget _buildFilterToggleButton() {
    final hasFilters = _hasActiveFilters();

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
          ),
          if (hasFilters)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewPurchasePrice(context)) {
      return const SafeArea(
        child: Center(
          child:
              Text('Purchase permission is required to view purchase orders.'),
        ),
      );
    }

    final provider = Provider.of<PurchaseProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context).appSettings;
    final currency = (appSettings?.currency.trim().isNotEmpty ?? false)
        ? appSettings!.currency.trim()
        : 'SAR';
    final purchases = provider.purchaseOrdersList;
    final currentPage = provider.listPurchaseOrderCurrentPage <= 0
        ? 1
        : provider.listPurchaseOrderCurrentPage;
    final startSerial = (currentPage - 1) * _itemsPerPage;
    final totalAmount = purchases.fold<double>(0,
        (sum, item) => sum + (double.tryParse(item.amountTotal ?? '0') ?? 0.0));
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersListShell(
      onRefresh: refreshData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(provider),
          const SizedBox(height: 12),
          if (!isPhone || _showFilters) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: _buildFiltersCard(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: PurchaseOrdersContentCard(
              padding: EdgeInsets.zero,
              child: initLoading
                  ? _buildLoadingState()
                  : purchases.isEmpty
                      ? _buildEmptyState()
                      : isPhone
                          ? _buildMobileList(
                              purchases: purchases,
                              startSerial: startSerial,
                              currency: currency,
                            )
                          : _buildDesktopTable(
                              purchases: purchases,
                              startSerial: startSerial,
                              currency: currency,
                            ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryFooter(currency: currency, totalAmount: totalAmount),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
            child: PaginationControl(
              currentPage: provider.listPurchaseOrderCurrentPage,
              totalPages: provider.listPurchaseOrderTotalPages,
              onPageChanged: (page) {
                _fetchPurchases(page: page);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PurchaseProvider provider) {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersPageHeader(
      title: "Purchase Order",
      subtitle: "View and manage purchase orders",
      leading: isPhone ? _buildFilterToggleButton() : null,
      trailing: SizedBox(
        width: isPhone ? double.infinity : 180,
        child: CustomRoundButton(
          title: "Create Purchase Order",
          fct: () {
            provider.activePurchaseOrderDetails = null;
            provider.voucherDetails = null;
            provider.listPurchaseItemView = [];
            final SideBarController sideBarController = Get.find();
            sideBarController.index.value = 82;
          },
          fontSize: 12,
          height: 44,
          width: isPhone ? double.infinity : 180,
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersContentCard(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PurchaseOrdersSectionTitle(title: 'Filters'),
          const SizedBox(height: 12),
          if (isPhone) ...[
            _buildFilterDropdown(
              "Supplier",
              supplierController,
              suppliers,
              supplierSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDropdown(
              "Store",
              storeController,
              stores,
              storeSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDate("From Date", fromDateController, expanded: false),
            const SizedBox(height: 10),
            _buildFilterDate("To Date", toDateController, expanded: false),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: resetSearch,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomRoundButton(
                    title: "Apply",
                    fct: _fetchPurchases,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFilterDropdown(
                  "Supplier",
                  supplierController,
                  suppliers,
                  supplierSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDropdown(
                  "Store",
                  storeController,
                  stores,
                  storeSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDate("From Date", fromDateController),
                const SizedBox(width: 15),
                _buildFilterDate("To Date", toDateController),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                Expanded(
                  child: CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: resetSearch,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(40),
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(ColorManager.kPrimaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _hasActiveFilters();

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? "No purchase orders match your filters"
                  : "No purchase orders found",
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                Colors.grey.shade600,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'Clear filters',
                fct: resetSearch,
                fontSize: 12,
                height: 44,
                width: 140,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList({
    required List<PurchaseOrderData> purchases,
    required int startSerial,
    required String currency,
  }) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: purchases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = purchases[index];
        final serialNumber = startSerial + index + 1;
        return _buildMobilePurchaseCard(
          item: item,
          serialNumber: serialNumber,
          currency: currency,
        );
      },
    );
  }

  Widget _buildCompactFieldBox({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePurchaseCard({
    required PurchaseOrderData item,
    required int serialNumber,
    required String currency,
  }) {
    final canReceive = _canReceiveOrder(item);
    final itemsReceived = _itemsReceivedLabel(item);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.purchaseDate ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.supplier?.name ?? '—'} · #$serialNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'View order',
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: BuildBoxShadowContainer(
                        color: ColorManager.kPrimaryColor.withOpacity(0.9),
                        circleRadius: 6,
                        child: IconButton(
                          icon: const Icon(Icons.visibility,
                              size: 14, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _handleOrderAction(item, 36),
                        ),
                      ),
                    ),
                  ),
                  if (canReceive) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Receive items',
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: BuildBoxShadowContainer(
                          color: const Color(0xFFE7F8EC),
                          circleRadius: 6,
                          child: IconButton(
                            icon: const Icon(Icons.add,
                                size: 14, color: Colors.green),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _handleOrderAction(item, 82),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Store',
                  value: item.store?.name ?? '—',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Total Price',
                  value: '$currency ${item.amountTotal ?? '0'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _buildReceivedBadgeWidget(itemsReceived),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable({
    required List<PurchaseOrderData> purchases,
    required int startSerial,
    required String currency,
  }) {
    return PurchaseOrdersResponsiveTable(
      table: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: ColorManager.tableBGColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 2.0,
                ),
              ],
            ),
            child: Table(
              columnWidths: const {
                0: FractionColumnWidth(0.08),
                1: FractionColumnWidth(0.14),
                2: FractionColumnWidth(0.16),
                3: FractionColumnWidth(0.20),
                4: FractionColumnWidth(0.12),
                5: FractionColumnWidth(0.14),
                6: FractionColumnWidth(0.16),
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader("SL"),
                    _buildTableHeader("Purchase Date"),
                    _buildTableHeader("Store"),
                    _buildTableHeader("Supplier"),
                    _buildTableHeader("Total Price"),
                    _buildTableHeader("Received Items"),
                    _buildTableHeader("Action"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Table(
                columnWidths: const {
                  0: FractionColumnWidth(0.08),
                  1: FractionColumnWidth(0.14),
                  2: FractionColumnWidth(0.16),
                  3: FractionColumnWidth(0.20),
                  4: FractionColumnWidth(0.12),
                  5: FractionColumnWidth(0.14),
                  6: FractionColumnWidth(0.16),
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  ...purchases.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final PurchaseOrderData item = entry.value;
                    final int serialNumber = startSerial + index + 1;
                    final canReceive = _canReceiveOrder(item);

                    return TableRow(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.grey.withOpacity(0.1),
                      ),
                      children: [
                        _buildTableCell(serialNumber.toString()),
                        _buildTableCell(item.purchaseDate ?? ""),
                        _buildTableCell(item.store?.name ?? ""),
                        _buildTableCell(item.supplier?.name ?? ""),
                        _buildTableCell("$currency ${item.amountTotal}"),
                        _buildReceivedBadge(_itemsReceivedLabel(item)),
                        _buildActionCell(
                          item: item,
                          canReceive: canReceive,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter({
    required String currency,
    required double totalAmount,
  }) {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersContentCard(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isPhone ? 14 : 20,
        vertical: isPhone ? 14 : 16,
      ),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Summary",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s14,
                    0.2,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Price",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        Colors.grey,
                      ),
                    ),
                    Text(
                      "$currency ${totalAmount.toStringAsFixed(2)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  "Summary",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s14,
                    0.2,
                    ColorManager.textColor,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Price",
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        Colors.grey,
                      ),
                    ),
                    Text(
                      "$currency ${totalAmount.toStringAsFixed(2)}",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    TextEditingController controller,
    List<String> items,
    TextEditingController searchController, {
    bool expanded = true,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 5),
        BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: "All",
          value: controller.text == "All" ? null : controller.text,
          items: items.where((e) => e != "All").toList(),
          onChanged: (val) {
            setState(() => controller.text = val ?? "All");
            _fetchPurchases();
          },
          displayText: (val) => val,
          searchController: searchController,
          height: 45,
          margin: EdgeInsets.zero,
        ),
      ],
    );

    return expanded ? Expanded(child: field) : field;
  }

  Widget _buildFilterDate(
    String label,
    TextEditingController controller, {
    bool expanded = true,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            DateTime? picked = await showAutoDismissDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                controller.text =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
              _fetchPurchases();
            }
          },
          child: AbsorbPointer(
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "yyyy-mm-dd",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        ColorManager.textColor,
                      ),
                      readOnly: true,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return expanded ? Expanded(child: field) : field;
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 16.0,
          horizontal: 8.0,
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(15.0),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCell({
    required PurchaseOrderData item,
    required bool canReceive,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PurchaseOrdersIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'View order',
                onPressed: () => _handleOrderAction(item, 36),
              ),
              if (canReceive) ...[
                const SizedBox(width: 4),
                PurchaseOrdersIconAction(
                  icon: Icons.add,
                  backgroundColor: const Color(0xFFE7F8EC),
                  iconColor: Colors.green,
                  tooltip: 'Receive items',
                  onPressed: () => _handleOrderAction(item, 82),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedBadgeWidget(String itemsReceived) {
    int received = 0;
    int total = 0;
    final parts = itemsReceived.split('/');
    if (parts.length == 2) {
      received = int.tryParse(parts[0].trim()) ?? 0;
      total = int.tryParse(parts[1].trim()) ?? 0;
    }

    final isFull = total > 0 && received == total;
    final hasProgress = total > 0 && received > 0 && received < total;
    final backgroundColor = isFull
        ? const Color(0xFFE7F8EC)
        : hasProgress
            ? const Color(0xFFFFF4DD)
            : const Color(0xFFF3F5F7);
    final borderColor = isFull
        ? const Color(0xFF65C16F)
        : hasProgress
            ? const Color(0xFFF0B54A)
            : const Color(0xFFD7DDE3);
    final iconColor = isFull
        ? const Color(0xFF2E9B42)
        : hasProgress
            ? const Color(0xFFB97A00)
            : const Color(0xFF7B8794);
    final icon = isFull
        ? Icons.check_circle_rounded
        : hasProgress
            ? Icons.timelapse_rounded
            : Icons.inventory_2_outlined;

    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            itemsReceived,
            style: TextStyle(
              fontWeight: FontWeightManager.semiBold,
              fontSize: FontSize.s12,
              color: isFull
                  ? const Color(0xFF166534)
                  : hasProgress
                      ? const Color(0xFF8A5A00)
                      : const Color(0xFF4B5563),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedBadge(String itemsReceived) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
        child: Center(
          child: _buildReceivedBadgeWidget(itemsReceived),
        ),
      ),
    );
  }
}
