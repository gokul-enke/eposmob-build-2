import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/models/list_purchase.dart';

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
  static const int _itemsPerPage = 15;
  List<String> suppliers = ["All"];
  List<String> stores = ["All"];

  @override
  void initState() {
    super.initState();
    supplierController.text = "All";
    storeController.text = "All";
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
        'status': item.status,
        'items': item.items
            ?.map((i) => {
                  'id': i.id,
                  'category_id': i.categoryId,
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'store_id': i.storeId,
                  'supplier_id': i.supplierId,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'total_price': i.totalPrice,
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

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Purchase Order",
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                        CustomRoundButton(
                          title: "Create Purchase Order",
                          fct: () {
                            provider.activePurchaseOrderDetails = null;
                            provider.voucherDetails = null;
                            provider.listPurchaseItemView = [];
                            final SideBarController sideBarController =
                                Get.find();
                            sideBarController.index.value = 82;
                          },
                          fontSize: 12,
                          height: 45,
                          width: 180,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
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
                    const SizedBox(height: 20),
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
                            height: 45,
                            width: double.infinity,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: initLoading
                            ? const Center(
                                child: CircularProgressIndicator.adaptive())
                            : purchases.isEmpty
                                ? BuildBoxShadowContainer(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 20),
                                    circleRadius: 7,
                                    offsetValue: const Offset(1, 1),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 50.0),
                                      child: Center(
                                        child: Text(
                                          "No purchase orders found",
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s16,
                                            0.18,
                                            Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : BuildBoxShadowContainer(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0),
                                    width: double.infinity,
                                    circleRadius: 7,
                                    offsetValue: const Offset(2, 2),
                                    blurRadius: 8.0,
                                    color: Colors.white,
                                    child: Column(
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
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            children: [
                                              TableRow(
                                                children: [
                                                  _buildTableHeader("SL"),
                                                  _buildTableHeader(
                                                      "Purchase Date"),
                                                  _buildTableHeader("Store"),
                                                  _buildTableHeader("Supplier"),
                                                  _buildTableHeader(
                                                      "Total Price"),
                                                  _buildTableHeader(
                                                      "Received Items"),
                                                  _buildTableHeader("Action"),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            physics:
                                                const BouncingScrollPhysics(),
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
                                              defaultVerticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              children: [
                                                ...purchases
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                  final int index = entry.key;
                                                  final PurchaseOrderData item =
                                                      entry.value;
                                                  final int serialNumber =
                                                      startSerial + index + 1;

                                                  bool canReceive = false;
                                                  if (item.itemsReceived !=
                                                      null) {
                                                    final parts = item
                                                        .itemsReceived!
                                                        .split('/');
                                                    if (parts.length == 2) {
                                                      final received =
                                                          int.tryParse(parts[0]
                                                                  .trim()) ??
                                                              0;
                                                      final total =
                                                          int.tryParse(parts[1]
                                                                  .trim()) ??
                                                              0;
                                                      canReceive =
                                                          received < total &&
                                                              total > 0;
                                                    }
                                                  }

                                                  return TableRow(
                                                    decoration: BoxDecoration(
                                                      color: index % 2 == 0
                                                          ? Colors.white
                                                          : Colors.grey
                                                              .withOpacity(0.1),
                                                    ),
                                                    children: [
                                                      _buildTableCell(
                                                        serialNumber.toString(),
                                                      ),
                                                      _buildTableCell(
                                                        item.purchaseDate ?? "",
                                                      ),
                                                      _buildTableCell(
                                                        item.store?.name ?? "",
                                                      ),
                                                      _buildTableCell(
                                                        item.supplier?.name ??
                                                            "",
                                                      ),
                                                      _buildTableCell(
                                                        "$currency ${item.amountTotal}",
                                                      ),
                                                      _buildReceivedBadge(
                                                        (item.itemsReceived ==
                                                                    null ||
                                                                item.itemsReceived!
                                                                    .isEmpty)
                                                            ? "0 / 0"
                                                            : item
                                                                .itemsReceived!,
                                                      ),
                                                      _buildActionCell(
                                                        item: item,
                                                        canReceive: canReceive,
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
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
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, TextEditingController controller,
      List<String> items, TextEditingController searchController) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor)),
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
      ),
    );
  }

  Widget _buildFilterDate(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor)),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () async {
              DateTime? picked = await showDatePicker(
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            hintText: "yyyy-mm-dd",
                            border: InputBorder.none,
                            isDense: true),
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.2, ColorManager.textColor),
                        readOnly: true,
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
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
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
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
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BuildBoxShadowContainer(
                margin: const EdgeInsets.only(left: 5, right: 5),
                circleRadius: 5,
                child: IconButton(
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                  ),
                  onPressed: () => _handleOrderAction(item, 36),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              if (canReceive)
                BuildBoxShadowContainer(
                  margin: const EdgeInsets.only(left: 5, right: 5),
                  circleRadius: 5,
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.green,
                    ),
                    onPressed: () => _handleOrderAction(item, 82),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedBadge(String itemsReceived) {
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

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
        ),
      ),
    );
  }
}
