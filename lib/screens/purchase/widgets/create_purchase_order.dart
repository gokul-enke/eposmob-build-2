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
  int? id; // NEW! Track the existing purchase item ID
  String barcode;

  Category? categoryData;
  GetProduct? productData;
  String unit;
  String quantity;
  String purchaseRate;

  String retailPrice;
  String mrp;
  DateTime? expDate;

  String wholesalePrice;
  String wholesaleMinUnit;
  String rack;
  bool taxInclude;

  bool receive;
  TextEditingController qtyCtrl;
  TextEditingController purchasePriceCtrl;
  TextEditingController retailPriceCtrl;
  TextEditingController mrpCtrl;
  TextEditingController wholesalePriceCtrl;

  PurchaseOrderItem({
    this.barcode = '',
    this.categoryData,
    this.productData,
    this.unit = '',
    this.quantity = '1',
    this.purchaseRate = '',
    this.retailPrice = '',
    this.mrp = '',
    this.expDate,
    this.wholesalePrice = '',
    this.wholesaleMinUnit = '',
    this.rack = '',
    this.taxInclude = false,
    this.receive = true,
    this.id,
  })  : qtyCtrl = TextEditingController(text: quantity),
        purchasePriceCtrl = TextEditingController(text: purchaseRate),
        retailPriceCtrl = TextEditingController(text: retailPrice),
        mrpCtrl = TextEditingController(text: mrp),
        wholesalePriceCtrl = TextEditingController(text: wholesalePrice) {
    // Default to 1 year from today if not specified
    expDate ??= DateTime.now().add(const Duration(days: 365));
  }

  void syncControllers() {
    qtyCtrl.text = quantity;
    purchasePriceCtrl.text = purchaseRate;
    retailPriceCtrl.text = retailPrice;
    mrpCtrl.text = mrp;
    wholesalePriceCtrl.text = wholesalePrice;
  }
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
  final TextEditingController voucherNumberController = TextEditingController();
  final TextEditingController invoiceRefController = TextEditingController();

  // Settings
  bool receiveNow = false;

  // Row controllers maps
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController productSearchController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController wholesalePriceController =
      TextEditingController();
  final TextEditingController wholesaleMinUnitController =
      TextEditingController();
  final TextEditingController rackController = TextEditingController();

  List<PurchaseOrderItem> orderItems = [];
  PurchaseOrderItem currentItem = PurchaseOrderItem();
  bool includeTax = false;

  // Multiple Payment Methods
  final Set<String> _selectedPaymentMethods = {'CASH'};
  final Map<String, TextEditingController> _paymentControllers = {
    'CASH': TextEditingController(),
    'CARD': TextEditingController(),
    'UPI': TextEditingController(),
  };

  GetStoreModelData? selectedStore;
  GetSuppliersModelData? selectedSupplier;
  DateTime selectedDate = DateTime.now();
  int?
      purchaseOrderId; // NEW! Track if we are editing/receiving an existing order

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

      // Handle pre-population if activePurchaseOrderDetails is set
      if (purchaseProvider.activePurchaseOrderDetails != null) {
        final data = purchaseProvider.activePurchaseOrderDetails!;
        setState(() {
          // Header
          purchaseOrderId = data['id']; // NEW! Capture the ID
          voucherNumberController.text =
              data['voucher_number']?.toString() ?? "";
          invoiceRefController.text = data['invoice_ref']?.toString() ?? "";
          if (data['purchase_date'] != null) {
            selectedDate =
                DateTime.tryParse(data['purchase_date']) ?? DateTime.now();
          }

          // Store
          if (data['store'] != null) {
            selectedStore = GetStoreModelData.fromJson(data['store']);
            storeSearchController.text = selectedStore?.name ?? "";
          }

          // Supplier
          if (data['supplier'] != null) {
            selectedSupplier = GetSuppliersModelData.fromJson(data['supplier']);
            supplierSearchController.text = selectedSupplier?.name ?? "";
          }

          // Items - Support both 'items' (new list API) and 'purchase_items' (old/detail API)
          final itemsList = data['items'] ?? data['purchase_items'];
          if (itemsList != null) {
            orderItems = (itemsList as List).map((item) {
              return PurchaseOrderItem(
                id: item['id'], // NEW! SET THE ITEM ID
                barcode: (item['bar_code'] ?? item['barcode'] ?? "").toString(),

                quantity: item['quantity']?.toString() ?? "1",
                purchaseRate:
                    (item['unit_price'] ?? item['purchase_rate'] ?? "")
                        .toString(),
                unit: (item['unit'] ?? "").toString(),
                productData: (item['product'] != null)
                    ? GetProduct.fromJson(item['product'])
                    : (item['product_name'] != null || item['name'] != null
                        ? GetProduct(
                            productId: int.tryParse(
                                (item['product_id'] ?? item['id'] ?? "")
                                    .toString()),
                            productName: item['product_name'] ?? item['name'])
                        : null),

                // Map additional fields if present in the response
                retailPrice: item['retail_price']?.toString() ?? "",
                mrp: item['mrp']?.toString() ?? "",
                wholesalePrice: item['wholesale_price']?.toString() ?? "",
                wholesaleMinUnit: item['wholesale_min_unit']?.toString() ?? "",
                rack: item['rack']?.toString() ?? "",
              )
                ..receive = (item['status'] == 'Y')
                ..syncControllers();
            }).toList();
            _syncPaidAmount();
          }
        });
      }
    }
  }

  void _addItem() {
    if (currentItem.productData == null) {
      Get.snackbar("Error", "Please select a product to add",
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    setState(() {
      currentItem.taxInclude = includeTax;
      currentItem.syncControllers();
      orderItems.add(currentItem);
      currentItem = PurchaseOrderItem();

      // Clear controllers
      barcodeController.clear();
      unitController.clear();
      quantityController.text = '1';
      rateController.clear();
      retailPriceController.clear();
      mrpController.clear();
      wholesalePriceController.clear();
      wholesaleMinUnitController.clear();
      rackController.clear();
      categorySearchController.clear();
      productSearchController.clear();
      includeTax = false;
      _syncPaidAmount();
    });
  }

  void _removeItem(int index) {
    if (orderItems.length > index) {
      setState(() {
        orderItems.removeAt(index);
        _syncPaidAmount();
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

  double get totalReceivedAmount {
    double total = 0;
    for (var item in orderItems) {
      if (item.receive) {
        double qty = double.tryParse(item.quantity) ?? 0;
        double rate = double.tryParse(item.purchaseRate) ?? 0;
        total += (qty * rate);
      }
    }
    return total;
  }

  void _syncPaidAmount() {
    double amtToPay = totalReceivedAmount;
    if (_selectedPaymentMethods.isNotEmpty) {
      // Clear all first
      _paymentControllers.forEach((key, controller) => controller.clear());

      // Put the amount into the first selected method
      String firstMethod = _selectedPaymentMethods.first;
      _paymentControllers[firstMethod]?.text = amtToPay.toStringAsFixed(2);
    }
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
        child: FocusTraversalGroup(
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductDetailsTitle(),
                        _buildItemForm(),
                        const SizedBox(height: 20),
                        _buildTaxDetails(),
                        const SizedBox(height: 15),
                        _buildAddItemButton(),
                        const SizedBox(height: 20),
                        _buildAddedItemsTable(),
                        const SizedBox(height: 20),
                        // _buildItemsToReceivePreview(),

                        const SizedBox(height: 20),
                        _buildPaymentSection(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldColumn(String title, Widget child,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: title,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s13,
                0.2, ColorManager.textColor),
            children: isRequired
                ? [
                    const TextSpan(
                        text: ' *', style: TextStyle(color: Colors.red))
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _buildHeader() {
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: _buildFieldColumn(
                "Purchase Date",
                CalendarPickerTableCell(
                  onDateSelected: (date) => setState(() => selectedDate = date),
                  initialDate: selectedDate,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Voucher Number",
                _buildInlineField(
                    voucherNumberController, "e.g., 2200", (v) {}),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Store",
                BuildDropDownWithSearch<GetStoreModelData>(
                  title: null,
                  showName: false,
                  hintText: "Select Store",
                  value: selectedStore,
                  items: purchaseProvider.getStoreList ?? [],
                  onChanged: (val) => setState(() => selectedStore = val),
                  displayText: (val) => val.name ?? "",
                  searchController: storeSearchController,
                  height: 40,
                ),
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2
        Row(
          children: [
            Expanded(
              child: _buildFieldColumn(
                "Supplier",
                BuildDropDownWithSearch<GetSuppliersModelData>(
                  title: null,
                  showName: false,
                  hintText: "Select Supplier",
                  value: selectedSupplier,
                  items: purchaseProvider.getSupplierList ?? [],
                  onChanged: (val) => setState(() => selectedSupplier = val),
                  displayText: (val) => val.user?.name ?? val.name ?? "",
                  searchController: supplierSearchController,
                  height: 40,
                ),
                isRequired: true,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Invoice Reference",
                _buildInlineField(invoiceRefController, "", (v) {}),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: receiveNow,
                    onChanged: (v) {
                      setState(() {
                        receiveNow = v ?? false;
                        _syncPaidAmount();
                      });
                    },
                    visualDensity: VisualDensity.compact, // Tighter layout
                  ),
                  const SizedBox(width: 4),
                  Text("Receive Now",
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s13, 0.2, ColorManager.textColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductDetailsTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
      ),
      child: Text("Product Details",
          style: buildCustomStyle(FontWeightManager.bold, FontSize.s16, 0.2,
              ColorManager.textColor)),
    );
  }

  Widget _buildItemForm() {
    final item = currentItem;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Barcode | Category | Product  + Delete Action removed
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _buildFieldColumn(
                  "Barcode",
                  _buildInlineField(barcodeController, "Enter barcode",
                      (v) => item.barcode = v),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 3,
                child: _buildFieldColumn(
                  "Category",
                  BuildDropDownWithSearch<Category>(
                    title: null,
                    showName: false,
                    hintText: "Select category",
                    value: item.categoryData,
                    items: categoryProvider.category ?? [],
                    onChanged: (val) => setState(() => item.categoryData = val),
                    displayText: (val) =>
                        val.categoryName ?? val.categorySlug ?? "Unknown",
                    searchController: categorySearchController,
                    height: 40,
                  ),
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 3,
                child: _buildFieldColumn(
                  "Product",
                  BuildDropDownWithSearch<GetProduct>(
                    title: null,
                    showName: false,
                    hintText: "Select a product",
                    value: item.productData,
                    items: localProductProvider.products
                        .where((p) =>
                            item.categoryData == null ||
                            p.categoryId == item.categoryData?.categoryId)
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        item.productData = val;
                        if (val != null) {
                          item.barcode = val.barcode ?? "";
                          barcodeController.text = item.barcode;

                          item.unit = val.unit ?? "";
                          unitController.text = item.unit;

                          item.purchaseRate = val.purchasePrice ?? "";
                          rateController.text = item.purchaseRate;

                          item.retailPrice = val.price?.price?.toString() ?? "";
                          retailPriceController.text = item.retailPrice;

                          item.mrp = val.mrp?.toString() ?? "";
                          mrpController.text = item.mrp;

                          item.wholesalePrice =
                              val.price?.price?.toString() ?? "";
                          wholesalePriceController.text = item.wholesalePrice;
                        }
                      });
                    },
                    displayText: (val) => val.productName ?? "",
                    searchController: productSearchController,
                    height: 40,
                  ),
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Row 2: Unit | Quantity | Purchase rate
          Row(
            children: [
              Expanded(
                child: _buildFieldColumn(
                  "Unit",
                  _buildInlineField(unitController, "Select product unit",
                      (v) => item.unit = v),
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Quantity",
                  _buildInlineField(quantityController, "1",
                      (v) => setState(() => item.quantity = v),
                      isNumber: true),
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Purchase rate",
                  _buildInlineField(rateController, "Purchase price",
                      (v) => setState(() => item.purchaseRate = v),
                      isNumber: true, prefixText: "SAR  "),
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Row 3: Retail price | Mrp | Expiry Date
          Row(
            children: [
              Expanded(
                child: _buildFieldColumn(
                  "Retail price",
                  _buildInlineField(retailPriceController, "Retail price", (v) {
                    setState(() {
                      item.retailPrice = v;
                    });
                  }, isNumber: true, prefixText: "SAR  "),
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Mrp",
                  _buildInlineField(mrpController, "MRP", (v) => item.mrp = v,
                      isNumber: true, prefixText: "SAR  "),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Expiry Date",
                  CalendarPickerTableCell(
                    onDateSelected: (date) =>
                        setState(() => item.expDate = date),
                    initialDate: item.expDate ?? DateTime.now(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Row 4: Wholesale price | Minimum Units for Wholesale | Rack
          Row(
            children: [
              Expanded(
                child: _buildFieldColumn(
                  "Wholesale price",
                  _buildInlineField(wholesalePriceController, "Wholesale price",
                      (v) {
                    setState(() {
                      item.wholesalePrice = v;
                    });
                  }, isNumber: true, prefixText: "SAR  "),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Minimum Units for Wholesale",
                  _buildInlineField(
                      wholesaleMinUnitController,
                      "Enter minimum wholesale units",
                      (v) => item.wholesaleMinUnit = v,
                      isNumber: true),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFieldColumn(
                  "Rack",
                  _buildInlineField(
                      rackController, "Select an option", (v) => item.rack = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineField(
      TextEditingController controller, String hint, Function(String) onChanged,
      {bool isNumber = false, String? prefixText}) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(
        // Wrap with Center
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: buildCustomStyle(
                FontWeightManager.medium, FontSize.s12, 0.2, Colors.grey),
            border: InputBorder.none,
            isCollapsed: true, // Replaces isDense and zero padding
          ),
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2,
              ColorManager.textColor),
        ),
      ),
    );
  }

  Widget _buildTaxDetails() {
    double retailOrig = double.tryParse(currentItem.retailPrice) ?? 0;
    double wholeOrig = double.tryParse(currentItem.wholesalePrice) ?? 0;

    double rBase = retailOrig;
    double rTax = 0;
    double wBase = wholeOrig;
    double wTax = 0;

    if (includeTax) {
      rBase = retailOrig / 1.15;
      rTax = retailOrig - rBase;
      wBase = wholeOrig / 1.15;
      wTax = wholeOrig - wBase;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text("Tax Details",
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                    0.2, ColorManager.textColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: includeTax,
                        onChanged: (v) => setState(() => includeTax = v),
                        activeColor: Colors.blueAccent,
                      ),
                      Text("Including Tax",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                    ],
                  ),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text("Retail Price + Tax",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                      const SizedBox(height: 5),
                      Text(
                          "${retailOrig.toStringAsFixed(2)} (Tax: ${rTax.toStringAsFixed(2)})",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey.shade700)),
                    ])),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text("Wholesale Price + Tax",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                      const SizedBox(height: 5),
                      Text(
                          "${wholeOrig.toStringAsFixed(2)} (Tax: ${wTax.toStringAsFixed(2)})",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey.shade700)),
                    ])),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAddItemButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: CustomRoundButton(
        title: "+ Add Item",
        fct: _addItem,
        width: 120,
        height: 40,
        fontSize: 12,
        boxColor: Colors.blueAccent,
        textColor: Colors.white,
      ),
    );
  }

  Widget _buildTableTextField(
      TextEditingController controller, Function(String) onChanged,
      {double width = 80}) {
    return Container(
      width: width,
      height: 40, // Changed from 35 to 40 for consistency
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),

      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2,
              ColorManager.textColor),
        ),
      ),
    );
  }

  Widget _buildQtyField(PurchaseOrderItem item) {
    return Row(children: [
      InkWell(
        onTap: () {
          double current = double.tryParse(item.qtyCtrl.text) ?? 1;
          if (current > 1) {
            setState(() {
              item.qtyCtrl.text = (current - 1).toString();
              item.quantity = item.qtyCtrl.text;
              _syncPaidAmount();
            });
          }
        },
        child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: const Icon(Icons.remove, size: 14)),
      ),
      const SizedBox(width: 5),
      _buildTableTextField(item.qtyCtrl, (v) {
        setState(() {
          item.quantity = v;
          _syncPaidAmount();
        });
      }, width: 60),
      const SizedBox(width: 5),
      InkWell(
        onTap: () {
          double current = double.tryParse(item.qtyCtrl.text) ?? 1;
          setState(() {
            item.qtyCtrl.text = (current + 1).toString();
            item.quantity = item.qtyCtrl.text;
            _syncPaidAmount();
          });
        },
        child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: const Icon(Icons.add, size: 14)),
      ),
    ]);
  }

  Widget _buildAddedItemsTable() {
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text("Items added",
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                      0.2, ColorManager.textColor)),
            ),
            if (orderItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("No items added yet",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 60,
                    columns: [
                      DataColumn(
                          label: Text("Receive",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Product",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Unit",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("QTY",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Purchase Price",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Retail Price",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("MRP",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Wholesale Price",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                      DataColumn(
                          label: Text("Action",
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.2,
                                  Colors.grey.shade600))),
                    ],
                    rows: [
                      ...orderItems.asMap().entries.map((e) {
                        var item = e.value;
                        return DataRow(cells: [
                          DataCell(Checkbox(
                            value: item.receive,
                            onChanged: (v) {
                              setState(() {
                                item.receive = v ?? false;
                                _syncPaidAmount();
                              });
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            activeColor: Colors.blueAccent,
                          )),
                          DataCell(Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productData?.productName ?? "-",
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor)),
                                Text(item.productData?.barcode ?? item.barcode,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s10,
                                        0.2,
                                        Colors.grey)),
                              ])),
                          DataCell(Text(item.unit,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.2, ColorManager.textColor))),
                          DataCell(_buildQtyField(item)),
                          DataCell(
                              _buildTableTextField(item.purchasePriceCtrl, (v) {
                            setState(() {
                              item.purchaseRate = v;
                              _syncPaidAmount();
                            });
                          })),
                          DataCell(
                              _buildTableTextField(item.retailPriceCtrl, (v) {
                            setState(() {
                              item.retailPrice = v;
                              _syncPaidAmount();
                            });
                          })),
                          DataCell(_buildTableTextField(item.mrpCtrl, (v) {
                            setState(() {
                              item.mrp = v;
                              _syncPaidAmount();
                            });
                          })),
                          DataCell(_buildTableTextField(item.wholesalePriceCtrl,
                              (v) {
                            setState(() {
                              item.wholesalePrice = v;
                              _syncPaidAmount();
                            });
                          })),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () => _removeItem(e.key),
                          )),
                        ]);
                      }).toList()
                    ]),
              )
          ],
        ));
  }

  /* Widget _buildItemsToReceivePreview() {
    List<PurchaseOrderItem> receivedItems = orderItems.where((i) => i.receive).toList();
    if (receivedItems.isEmpty) return const SizedBox.shrink();

    double totalAmt = 0;
    int totalQty = 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text("Items to Receive - Preview", style: buildCustomStyle(FontWeightManager.bold, FontSize.s14, 0.2, ColorManager.textColor)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text("Product", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Unit", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("QTY", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Purchase Price", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Retail Price", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("MRP", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Wholesale Price", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Rack", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
                DataColumn(label: Text("Total", style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12, 0.2, Colors.grey.shade600))),
              ],
              rows: [
                ...receivedItems.map((item) {
                  double qty = double.tryParse(item.quantity) ?? 0;
                  double price = double.tryParse(item.purchaseRate) ?? 0;
                  double total = qty * price;
                  totalAmt += total;
                  totalQty += qty.toInt();

                  return DataRow(
                    cells: [
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productData?.productName ?? "-", style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor)),
                          Text(item.productData?.barcode ?? item.barcode, style: buildCustomStyle(FontWeightManager.medium, FontSize.s10, 0.2, Colors.grey)),
                        ]
                      )),
                      DataCell(Text(item.unit, style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text(qty.toStringAsFixed(2), style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text("SAR ${item.purchaseRate}", style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text("SAR ${item.retailPrice}", style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text("SAR ${item.mrp}", style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text("SAR ${item.wholesalePrice}", style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text(item.rack.isEmpty ? "N/A" : item.rack, style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2, ColorManager.textColor))),
                      DataCell(Text("SAR ${total.toStringAsFixed(2)}", style: buildCustomStyle(FontWeightManager.bold, FontSize.s12, 0.2, ColorManager.textColor))),
                    ]
                  );
                }),
                DataRow(
                  cells: [
                    DataCell(Text("Preview Total:", style: buildCustomStyle(FontWeightManager.bold, FontSize.s13, 0.2, ColorManager.textColor))),
                    DataCell(const Text("")),
                    DataCell(Text(totalQty.toString(), style: buildCustomStyle(FontWeightManager.bold, FontSize.s13, 0.2, ColorManager.textColor))),
                    DataCell(const Text("")),
                    DataCell(const Text("")),
                    DataCell(const Text("")),
                    DataCell(const Text("")),
                    DataCell(const Text("")),
                    DataCell(Text("SAR ${totalAmt.toStringAsFixed(2)}", style: buildCustomStyle(FontWeightManager.bold, FontSize.s13, 0.2, ColorManager.textColor))),
                  ]
                )
              ]
            ),
          )
        ],
      )
    );
  } */

  Widget _buildPaymentSection() {
    return Column(children: [
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Text("Select Payment Methods",
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                      0.2, ColorManager.textColor)),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Expanded(
                      child: _buildPaymentMethodButton('CASH', Icons.money)),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          _buildPaymentMethodButton('CARD', Icons.credit_card)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildPaymentMethodButton('UPI', Icons.qr_code)),
                ],
              ),
            )
          ],
        ),
      ),
      const SizedBox(height: 20),
      ..._selectedPaymentMethods
          .map((method) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Paid $method",
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s13, 0.2, ColorManager.textColor)),
                        const SizedBox(height: 10),
                        _buildInlineField(_paymentControllers[method]!,
                            "Enter $method Amount", (v) {},
                            isNumber: true),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    ]);
  }

  Widget _buildPaymentMethodButton(String method, IconData icon) {
    bool isSelected = _selectedPaymentMethods.contains(method);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_selectedPaymentMethods.length > 1) {
              _selectedPaymentMethods.remove(method);
              _paymentControllers[method]?.clear();
            }
          } else {
            _selectedPaymentMethods.add(method);
          }
          _syncPaidAmount();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.blueAccent, size: 16),
            const SizedBox(width: 8),
            Text(method,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                    0.2, isSelected ? Colors.white : Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Total Amount",
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s12, 0.2, Colors.grey)),
            Text(
                "Order: SAR ${totalAmount.toStringAsFixed(2)}\nReceive: SAR ${totalReceivedAmount.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s15,
                    0.2, ColorManager.textColor)),
          ],
        ),
        const SizedBox(width: 30),
        Expanded(
          child: CustomRoundButton(
            title: (receiveNow || totalReceivedAmount > 0 || purchaseOrderId != null)
                ? "Finish"
                : "Create Purchase Order",
            fct: () async {
              if (_formKey.currentState!.validate()) {
                if (selectedSupplier == null || selectedStore == null) {
                  Get.snackbar("Error", "Please select Supplier and Store",
                      backgroundColor: Colors.red, colorText: Colors.white);
                  return;
                }

                if (orderItems.isEmpty) {
                  Get.snackbar("Error",
                      "Please add at least one item from the form above",
                      backgroundColor: Colors.red, colorText: Colors.white);
                  return;
                }

                // Calculate total paid amount across all selected methods
                double totalPaidAmt = 0;
                Map<String, double> paidAmountsMap = {};
                for (String method in _selectedPaymentMethods) {
                  double amt = double.tryParse(
                          _paymentControllers[method]?.text ?? "") ??
                      0;
                  if (amt > 0) {
                    totalPaidAmt += amt;
                    paidAmountsMap[method] = amt;
                  }
                }

                // VALIDATION: If receiving, must be fully paid
                if ((receiveNow || purchaseOrderId != null) &&
                    totalPaidAmt < totalAmount) {
                  Get.snackbar("Error",
                      "Full payment of SAR ${totalAmount.toStringAsFixed(2)} is required when receiving products. Entered: SAR ${totalPaidAmt.toStringAsFixed(2)}",
                      backgroundColor: Colors.red, colorText: Colors.white);
                  return;
                }

                bool hasPayment = totalPaidAmt > 0;

                // Build the items list for API
                List<Map<String, dynamic>> apiItems = [];
                for (var i in orderItems) {
                  // Mode: Receiving an existing order
                  if (purchaseOrderId != null) {
                    apiItems.add({
                      "purchase_item_id": i.id,
                      "quantity": double.tryParse(i.quantity) ?? 1,
                      "unit_price": double.tryParse(i.purchaseRate) ?? 0,
                      "receive": i.receive,
                      if (i.receive) ...{
                        "retail_price": double.tryParse(i.retailPrice) ?? 0,
                        "wholesale_price":
                            double.tryParse(i.wholesalePrice) ?? 0,
                        "mrp": double.tryParse(i.mrp) ?? 0,
                        "tax_include": i.taxInclude,
                        if (i.wholesaleMinUnit.isNotEmpty)
                          "wholesale_min_unit":
                              double.tryParse(i.wholesaleMinUnit) ?? 1,
                        if (i.rack.isNotEmpty) "rack": i.rack,
                        if (i.expDate != null)
                          "expiry_date":
                              "${i.expDate!.year}-${i.expDate!.month.toString().padLeft(2, '0')}-${i.expDate!.day.toString().padLeft(2, '0')}",
                        "batch_number": i.barcode.isNotEmpty ? i.barcode : null,
                      }
                    });
                  }
                  // Mode: Creating a new order
                  else {
                    apiItems.add({
                      "product_id": i.productData?.productId,
                      "quantity": double.tryParse(i.quantity) ?? 1,
                      "unit_price": double.tryParse(i.purchaseRate) ?? 0,
                      "receive": i.receive,
                      if (i.receive) ...{
                        "retail_price": double.tryParse(i.retailPrice) ?? 0,
                        "wholesale_price":
                            double.tryParse(i.wholesalePrice) ?? 0,
                        "mrp": double.tryParse(i.mrp) ?? 0,
                        "tax_include": i.taxInclude,
                        if (i.wholesaleMinUnit.isNotEmpty)
                          "wholesale_min_unit":
                              double.tryParse(i.wholesaleMinUnit) ?? 1,
                        if (i.rack.isNotEmpty) "rack": i.rack,
                        "expiry_date": i.expDate != null
                            ? "${i.expDate!.year}-${i.expDate!.month.toString().padLeft(2, '0')}-${i.expDate!.day.toString().padLeft(2, '0')}"
                            : "",
                      }
                    });
                  }
                }

                String? token =
                    Provider.of<AuthModel>(context, listen: false).token;
                if (token != null) {
                  final provider =
                      Provider.of<PurchaseProvider>(context, listen: false);

                  // Format date as YYYY-MM-DD
                  String formattedDate =
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final result = (purchaseOrderId != null)
                      ? await provider.receivePurchaseOrder(
                          accessToken: token,
                          purchaseId: purchaseOrderId.toString(),
                          items: apiItems,
                          invoiceRef: invoiceRefController.text, // NEW!
                          paymentMethods:
                              hasPayment ? paidAmountsMap.keys.toList() : null,
                          paidAmounts: hasPayment ? paidAmountsMap : null,
                        )
                      : await provider.createPurchaseOrder(
                          accessToken: token,
                          purchaseDate: formattedDate,
                          supplierId: selectedSupplier!.id.toString(),
                          storeId: selectedStore!.id.toString(),
                          voucherNumber: voucherNumberController.text,
                          invoiceRef: invoiceRefController.text,
                          receiveNow: receiveNow,
                          paymentMethods:
                              hasPayment ? paidAmountsMap.keys.toList() : null,
                          paidAmounts: hasPayment ? paidAmountsMap : null,
                          items: apiItems,
                        );

                  // Hide loading indicator
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  if (result != null &&
                      (result['status'] == 'success' ||
                          result['status'] == true ||
                          (result['message']
                                  ?.toString()
                                  .toLowerCase()
                                  .contains('success') ??
                              false))) {
                    Get.snackbar("Success",
                        result['message'] ?? "Purchase order created",
                        backgroundColor: Colors.green, colorText: Colors.white);

                    // Reload list
                    await provider.listPurchaseOrders(
                      accessToken: token,
                      storeId: "all",
                    );

                    // Navigate back
                    sideBarController.index.value = 81;
                  } else {
                    Get.snackbar(
                        "Error", result?['message'] ?? "Failed to create",
                        backgroundColor: Colors.red, colorText: Colors.white);
                  }
                }
              }
            },
            width: 200,
            height: 45,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    voucherNumberController.dispose();
    invoiceRefController.dispose();
    categorySearchController.dispose();
    productSearchController.dispose();
    barcodeController.dispose();
    unitController.dispose();
    quantityController.dispose();
    rateController.dispose();
    retailPriceController.dispose();
    mrpController.dispose();
    wholesalePriceController.dispose();
    wholesaleMinUnitController.dispose();
    rackController.dispose();
    _paymentControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }
}
