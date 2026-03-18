import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class PurchaseOrderItem {
  String barcode;
  Category? categoryData;
  GetProduct? productData;
  String quantity;
  String purchaseRate;
  String unit;
  String batchNumber;
  DateTime? expDate;
  bool isExpanded;

  PurchaseOrderItem({
    this.barcode = '',
    this.categoryData,
    this.productData,
    this.quantity = '1',
    this.purchaseRate = '0',
    this.unit = '',
    this.batchNumber = '',
    this.expDate,
    this.isExpanded = false,
  });
}

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final SideBarController sideBarController = Get.find();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Header controllers
  final TextEditingController supplierSearchController =
      TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();

  // Row controllers
  final Map<int, TextEditingController> categorySearchControllers = {};
  final Map<int, TextEditingController> productSearchControllers = {};
  final Map<int, TextEditingController> barcodeControllers = {};
  final Map<int, TextEditingController> quantityControllers = {};
  final Map<int, TextEditingController> rateControllers = {};

  List<PurchaseOrderItem> orderItems = [PurchaseOrderItem()];
  GetStoreModelData? selectedStore;
  GetSuppliersModelData? selectedSupplier;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token != null) {
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      await purchaseProvider.listAllStores(token, null);
      await purchaseProvider.listAllSuppliers(token, null);
    }
  }

  void _addItem() {
    setState(() {
      orderItems.add(PurchaseOrderItem());
    });
  }

  void _removeItem(int index) {
    if (orderItems.length > 1) {
      setState(() {
        orderItems.removeAt(index);
        // Clear controllers for this index (though mapping might need shift,
        // for simplicity in this draft we just clear)
      });
    }
  }

  double get totalAmount {
    double total = 0;
    for (var item in orderItems) {
      double qty = double.tryParse(item.quantity) ?? 0;
      double rate = double.tryParse(item.purchaseRate) ?? 0;
      total += (qty * rate);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: const Offset(1, 1))
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBackButton(
                onPressed: () => sideBarController.index.value = 81,
                text: "Back to Purchase Orders",
              ),
              const SizedBox(height: 10),
              Text("Create New Purchase Order",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.3, ColorManager.textColor)),
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTableHeaders(),
              Expanded(
                child: ListView.builder(
                  itemCount: orderItems.length,
                  itemBuilder: (context, index) => _buildItemRow(index),
                ),
              ),
              const SizedBox(height: 20),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    return Row(
      children: [
        Expanded(
          child: BuildDropDownWithSearch<GetSuppliersModelData>(
            title: "Supplier",
            hintText: "Select Supplier",
            value: selectedSupplier,
            items: purchaseProvider.getSupplierList ?? [],
            onChanged: (val) => setState(() => selectedSupplier = val),
            displayText: (val) => val.name ?? "",
            searchController: supplierSearchController,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: BuildDropDownWithSearch<GetStoreModelData>(
            title: "Store",
            hintText: "Select Store",
            value: selectedStore,
            items: purchaseProvider.getStoreList ?? [],
            onChanged: (val) => setState(() => selectedStore = val),
            displayText: (val) => val.name ?? "",
            searchController: storeSearchController,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: CalendarPickerTableCell(
            onDateSelected: (date) => setState(() => selectedDate = date),
            initialDate: selectedDate,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: ColorManager.tableBGColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerCell("Category")),
          Expanded(flex: 3, child: _headerCell("Product")),
          Expanded(flex: 2, child: _headerCell("Barcode")),
          Expanded(flex: 1, child: _headerCell("Qty")),
          Expanded(flex: 2, child: _headerCell("Rate")),
          Expanded(flex: 2, child: _headerCell("Total")),
          const SizedBox(width: 80), // For Actions
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Text(text,
        style: buildCustomStyle(
            FontWeightManager.bold, FontSize.s13, 0.2, ColorManager.textColor));
  }

  Widget _buildItemRow(int index) {
    final item = orderItems[index];
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              // Category
              Expanded(
                flex: 2,
                child: BuildDropDownWithSearch<Category>(
                  title: null,
                  showName: false,
                  hintText: "Category",
                  value: item.categoryData,
                  items: categoryProvider.category ?? [],
                  onChanged: (val) => setState(() => item.categoryData = val),
                  displayText: (val) => val.categoryName ?? "",
                  searchController: _getCategorySearchController(index),
                  height: 40,
                ),
              ),
              const SizedBox(width: 10),
              // Product
              Expanded(
                flex: 3,
                child: BuildDropDownWithSearch<GetProduct>(
                  title: null,
                  showName: false,
                  hintText: "Product",
                  value: item.productData,
                  items: localProductProvider.products
                      .where((p) =>
                          item.categoryData == null ||
                          p.categoryId == item.categoryData?.categoryId)
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      item.productData = val;
                      item.barcode = val?.barcode ?? "";
                      _getBarcodeController(index).text = item.barcode;
                    });
                  },
                  displayText: (val) => val.productName ?? "",
                  searchController: _getProductSearchController(index),
                  height: 40,
                ),
              ),
              const SizedBox(width: 10),
              // Barcode
              Expanded(
                flex: 2,
                child: _buildInlineField(_getBarcodeController(index),
                    "Barcode", (v) => item.barcode = v),
              ),
              const SizedBox(width: 10),
              // Qty
              Expanded(
                flex: 1,
                child: _buildInlineField(_getQuantityController(index), "0",
                    (v) => setState(() => item.quantity = v),
                    isNumber: true),
              ),
              const SizedBox(width: 10),
              // Rate
              Expanded(
                flex: 2,
                child: _buildInlineField(_getRateController(index), "0.00",
                    (v) => setState(() => item.purchaseRate = v),
                    isNumber: true),
              ),
              const SizedBox(width: 10),
              // Total
              Expanded(
                flex: 2,
                child: Text(
                  "SAR ${((double.tryParse(item.quantity) ?? 0) * (double.tryParse(item.purchaseRate) ?? 0)).toStringAsFixed(2)}",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s13, 0.2, Colors.black),
                ),
              ),
              // Actions
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          item.isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20),
                      onPressed: () =>
                          setState(() => item.isExpanded = !item.isExpanded),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (item.isExpanded) _buildExpandedSection(index),
      ],
    );
  }

  Widget _buildExpandedSection(int index) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
              child: _buildInlineField(
                  TextEditingController(text: orderItems[index].batchNumber),
                  "Batch Number",
                  (v) => orderItems[index].batchNumber = v)),
          const SizedBox(width: 15),
          Expanded(
              child: _buildInlineField(
                  TextEditingController(text: orderItems[index].unit),
                  "Unit",
                  (v) => orderItems[index].unit = v)),
          const SizedBox(width: 15),
          Expanded(
            child: CalendarPickerTableCell(
              onDateSelected: (date) =>
                  setState(() => orderItems[index].expDate = date),
              initialDate: orderItems[index].expDate ?? DateTime.now(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineField(
      TextEditingController controller, String hint, Function(String) onChanged,
      {bool isNumber = false}) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2,
            ColorManager.textColor),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        CustomRoundButton(
          title: "+ Add Item",
          fct: _addItem,
          width: 120,
          height: 45,
          fontSize: 12,
          boxColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Total Amount",
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s12, 0.2, Colors.grey)),
            Text("SAR ${totalAmount.toStringAsFixed(2)}",
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18,
                    0.2, ColorManager.textColor)),
          ],
        ),
        const SizedBox(width: 30),
        CustomRoundButton(
          title: "Create Purchase Order",
          fct: () {
            if (_formKey.currentState!.validate()) {
              debugPrint("Creating PO for ${selectedSupplier?.name}");
            }
          },
          width: 200,
          height: 45,
          fontSize: 12,
        ),
      ],
    );
  }

  // Controller Getters
  TextEditingController _getCategorySearchController(int index) =>
      categorySearchControllers.putIfAbsent(
          index, () => TextEditingController());
  TextEditingController _getProductSearchController(int index) =>
      productSearchControllers.putIfAbsent(
          index, () => TextEditingController());
  TextEditingController _getBarcodeController(int index) =>
      barcodeControllers.putIfAbsent(
          index, () => TextEditingController(text: orderItems[index].barcode));
  TextEditingController _getQuantityController(int index) =>
      quantityControllers.putIfAbsent(
          index, () => TextEditingController(text: orderItems[index].quantity));
  TextEditingController _getRateController(int index) =>
      rateControllers.putIfAbsent(index,
          () => TextEditingController(text: orderItems[index].purchaseRate));

  @override
  void dispose() {
    for (var c in categorySearchControllers.values) c.dispose();
    for (var c in productSearchControllers.values) c.dispose();
    for (var c in barcodeControllers.values) c.dispose();
    for (var c in quantityControllers.values) c.dispose();
    for (var c in rateControllers.values) c.dispose();
    super.dispose();
  }
}
