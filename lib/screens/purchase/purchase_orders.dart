import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
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
          selectedSupplierId = supplier.id?.toString();
        }

        String? selectedStoreId;
        if (storeController.text != "All") {
          final store = provider.storeList.firstWhere(
              (s) => s.name == storeController.text,
              orElse: () => provider.storeDemo);
          selectedStoreId = store.id?.toString();
        } else {
          selectedStoreId = "all";
        }


        await provider.listPurchaseOrders(
          accessToken: token,
          storeId: selectedStoreId,
          supplierId: selectedSupplierId,
          filterDate: fromDateController.text,
          page: page,
        );
      }
    } finally {
      if (mounted) setState(() => initLoading = false);
    }
  }

  Future<void> _handleOrderAction(PurchaseOrderData item, int targetIndex) async {
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
          'items': item.items?.map((i) => {
            'id': i.id,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
            'unit': i.unit,
            'status': i.status,
          }).toList(),
          'store': item.store != null ? { 'id': item.store?.id, 'name': item.store?.name } : null,
          'supplier': item.supplier != null ? { 'id': item.supplier?.id, 'name': item.supplier?.name } : null,
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PurchaseProvider>(context);
    final purchases = provider.purchaseOrdersList;
    final totalAmount = purchases.fold<double>(0,
        (sum, item) => sum + (double.tryParse(item.amountTotal ?? '0') ?? 0.0));

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Purchase Order",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.3, ColorManager.textColor)),
                CustomRoundButton(
                  title: "Create Purchase Order",
                  fct: () {
                    final SideBarController sideBarController = Get.find();
                    sideBarController.index.value = 82;
                  },
                  fontSize: 12,
                  height: 45,
                  width: 180,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Filters Row
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildFilterDropdown("Supplier", supplierController,
                        suppliers, supplierSearchController),
                    const SizedBox(width: 15),
                    _buildFilterDropdown("Store", storeController, stores,
                        storeSearchController),
                    const SizedBox(width: 15),
                    _buildFilterDate("From Date", fromDateController),
                    const SizedBox(width: 15),
                    _buildFilterDate("To Date", toDateController),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: Container()),
                    const SizedBox(width: 15),
                    Expanded(child: Container()),
                    const SizedBox(width: 15),
                    Expanded(child: Container()),
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            // Table Structure matching Stock Screen
            const SizedBox(height: 10),
            Expanded(
              child: BuildBoxShadowContainer(
                margin: const EdgeInsets.only(top: 5),
                circleRadius: 7,
                offsetValue: const Offset(2, 2),
                blurRadius: 8.0,
                color: Colors.white,
                child: Column(
                  children: [
                    // Fixed table header matching Stock style
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
                          0: FlexColumnWidth(1.2), // Date
                          1: FlexColumnWidth(1.5), // Store
                          2: FlexColumnWidth(2.0), // Supplier
                          3: FlexColumnWidth(1.2), // Total Price
                          4: FlexColumnWidth(1.0), // Received Items
                          5: FlexColumnWidth(1.0), // Actions
                        },
                        border: null,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
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
                    // Scrollable Table Body
                    Expanded(
                      child: initLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1.2),
                                  1: FlexColumnWidth(1.5),
                                  2: FlexColumnWidth(2.0),
                                  3: FlexColumnWidth(1.2),
                                  4: FlexColumnWidth(1.0),
                                  5: FlexColumnWidth(1.0),
                                },
                                border: null,
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  ...purchases.asMap().entries.map((entry) {
                                    final int index = entry.key;
                                    final PurchaseOrderData item = entry.value;

                                    bool canReceive = false;
                                    if (item.itemsReceived != null) {
                                      final parts =
                                          item.itemsReceived!.split('/');
                                      if (parts.length == 2) {
                                        int r =
                                            int.tryParse(parts[0].trim()) ?? 0;
                                        int t =
                                            int.tryParse(parts[1].trim()) ?? 0;
                                        canReceive = r < t && t > 0;
                                      }
                                    }

                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.withOpacity(0.1),
                                      ),
                                      children: [
                                        _buildTableCell(
                                            item.purchaseDate ?? ""),
                                        _buildTableCell(item.store?.name ?? ""),
                                        _buildTableCell(
                                            item.supplier?.name ?? ""),
                                        _buildTableCell(
                                            "SAR ${item.amountTotal}"),
                                        _buildReceivedBadge(
                                            (item.itemsReceived == null || item.itemsReceived!.isEmpty) 
                                                ? "0 / 0" 
                                                : item.itemsReceived!),
                                        Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    color: Colors.blueAccent,
                                                    size: 18),
                                                onPressed: () => _handleOrderAction(item, 36), // ViewPurchaseWidget

                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                              if (canReceive) ...[
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                   onTap: () => _handleOrderAction(item, 82), // Create/Receive screen

                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Icon(Icons.add,
                                                        color: Colors.white,
                                                        size: 16),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
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
            // Summary Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Text("Summary",
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s14, 0.2, ColorManager.textColor)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Price",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey)),
                      Text("SAR ${totalAmount.toStringAsFixed(2)}",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s14, 0.2, ColorManager.textColor)),
                    ],
                  ),
                  const SizedBox(width: 80), // Alignment padding
                ],
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? textColor, Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              textColor ?? Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedBadge(String itemsReceived) {
    bool isFull = false;
    final parts = itemsReceived.split('/');
    if (parts.length == 2 &&
        parts[0].trim() == parts[1].trim() &&
        parts[1].trim() != "0") {
      isFull = true;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFull ? Colors.green.shade100 : Colors.blue.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isFull ? Colors.green.shade400 : Colors.blue.shade400, width: 1.5),
        ),
        child: Text(itemsReceived,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            )),
      ),
    );
  }
}
