import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:provider/provider.dart';

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

  // Dummy data matching the provided image
  final List<Map<String, dynamic>> dummyPurchases = [
    {
      "date": "2026-01-19",
      "store": "EEZEE DEMO Store",
      "supplier": "Supplier EEZEE DEMO",
      "price": "₹7,784.00",
      "received": 7,
      "total": 7,
      "selected": false,
    },
    {
      "date": "2026-01-07",
      "store": "EEZEE DEMO Store",
      "supplier": "Arban supplier",
      "price": "₹1,350.00",
      "received": 1,
      "total": 1,
      "selected": false,
    },
    {
      "date": "2026-01-03",
      "store": "EEZEE DEMO Store",
      "supplier": "Arban supplier",
      "price": "₹480.00",
      "received": 0,
      "total": 1,
      "selected": false,
    },
    {
      "date": "2026-01-03",
      "store": "EEZEE DEMO Store",
      "supplier": "Arban supplier",
      "price": "₹4,590.00",
      "received": 3,
      "total": 3,
      "selected": false,
    },
  ];

  @override
  void initState() {
    super.initState();
    supplierController.text = "All";
    storeController.text = "All";
    loadInitData();
  }

  void loadInitData() async {
    setState(() => initLoading = true);
    try {
      String? token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null && token.isNotEmpty) {
        final provider = Provider.of<PurchaseProvider>(context, listen: false);
        await provider.listAllStores(token, null);
        await provider.listAllSuppliers(token, null);

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

  void resetSearch() {
    setState(() {
      supplierController.text = "All";
      storeController.text = "All";
      fromDateController.clear();
      toDateController.clear();
    });
  }

  void _showPurchaseDetails(Map<String, dynamic> purchase) {
    // Standard view details logic
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Text("Filters",
                        style: buildCustomStyle(FontWeightManager.bold,
                            FontSize.s16, 0.2, ColorManager.textColor)),
                    const SizedBox(width: 20),
                    TextButton(
                      onPressed: resetSearch,
                      child: Text("Reset",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s14, 0.2, Colors.red)),
                    ),
                  ],
                ),
                CustomRoundButton(
                  title: "Create Purchase Order",
                  fct: () {
                    final SideBarController sideBarController = Get.find();
                    sideBarController.index.value = 82;
                  },
                  fontSize: 12,
                  height: 40,
                  width: 180,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Filters Row
            Row(
              children: [
                _buildFilterDropdown("Supplier", supplierController, suppliers,
                    supplierSearchController),
                const SizedBox(width: 15),
                _buildFilterDropdown(
                    "Store", storeController, stores, storeSearchController),
                const SizedBox(width: 15),
                _buildFilterDate("From Date", fromDateController),
                const SizedBox(width: 15),
                _buildFilterDate("To Date", toDateController),
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
                                  ...dummyPurchases
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final int index = entry.key;
                                    final item = entry.value;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.withOpacity(0.1),
                                      ),
                                      children: [
                                        _buildTableCell(item['date']),
                                        _buildTableCell(item['store']),
                                        _buildTableCell(item['supplier']),
                                        _buildTableCell(item['price']),
                                        _buildReceivedBadge(
                                            item['received'], item['total']),
                                        Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    color: Colors.blueAccent,
                                                    size: 18),
                                                onPressed: () =>
                                                    _showPurchaseDetails(item),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                              if (item['received'] ==
                                                  item['total']) ...[
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      debugPrint("Add action"),
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
                      Text("₹14,204.00",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s14, 0.2, ColorManager.textColor)),
                    ],
                  ),
                  const SizedBox(width: 80), // Alignment padding
                ],
              ),
            ),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Showing 1 to 4 of 4 results",
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.2, Colors.grey)),
                Row(
                  children: [
                    Text("Per page",
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.2, Colors.grey)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: 10,
                          items: [10, 20, 50]
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text("$e")))
                              .toList(),
                          onChanged: (v) {},
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, ColorManager.textColor),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, TextEditingController controller,
      List<String> items, TextEditingController search) {
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
            onChanged: (val) => setState(() => controller.text = val ?? "All"),
            displayText: (val) => val,
            searchController: search,
            height: 40,
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
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                        hintText: "mm/dd/yyyy",
                        border: InputBorder.none,
                        isDense: true),
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.2, ColorManager.textColor),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (picked != null)
                        setState(() => controller.text =
                            "${picked.month}/${picked.day}/${picked.year}");
                    },
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Colors.grey),
              ],
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

  Widget _buildReceivedBadge(int received, int total) {
    bool isFull = received == total;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isFull ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text("$received / $total",
            style: buildCustomStyle(FontWeightManager.bold, FontSize.s12, 0.2,
                isFull ? Colors.green.shade700 : Colors.orange.shade700)),
      ),
    );
  }
}
