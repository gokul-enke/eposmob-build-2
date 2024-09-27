import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/list_purchase.dart';
import '../../providers/auth_model.dart';
import '../../providers/purchase_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  // State variables
  bool initLoading = false;
  List<VoucherDetail>? voucherDetailsList = [];
  List<PurchaseItem>? purchaseDetailsList = [];
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController purchaserNameController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController supplierIdController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  DateTime? selectedDate;
  GetStoreModelData? storeSelected;
  GetSuppliersModelData? supplier;
  String? selectedSupplierId;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  // Load initial data
  Future<void> loadInitData() async {
    setState(() {
      initLoading = true;
    });

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    await purchaseProvider.listPurchase(
        accessToken: accessToken ?? "", page: 1);

    purchaseDetailsList = purchaseProvider.getPurchaseDetailsList;
    debugPrint("Purchase Details List ${purchaseDetailsList!.length}");
    setState(() {
      initLoading = false;
    });
  }

  // Search purchases
  Future<void> searchPurchase(int page) async {
    debugPrint("Category search called");
    setState(() {
      initLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      PurchaseProvider purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);

      await purchaseProvider.listPurchase(
        accessToken: accessToken ?? "",
        filterName: purchaserNameController.text,
        filterStore: storeController.text,
        page: page,
      );

      debugPrint("Purchase Details List ${purchaseDetailsList!.length}");
      setState(() {
        purchaseDetailsList = purchaseProvider.getPurchaseDetailsList;
      });
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  // Reset search inputs
  void resetSearch() {
    loadInitData();
    setState(() {
      purchaserNameController.clear();
      storeController.clear();
      productNameController.clear();
      selectedSupplierId = null;
      supplierIdController.clear();
      selectedDate = null;
      dateController.clear();
    });
  }

  // Build UI
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: true);
    SideBarController sideBarController = Get.put(SideBarController());
    List<GetStoreModelData>? storeList = purchaseProvider.getStoreList;
    List<GetSuppliersModelData>? supplierList =
        purchaseProvider.getSupplierList;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: ListView(
            children: [
              // Header
              _buildHeader(sideBarController),

              const SizedBox(height: 15),

              // Search Filters
              _buildSearchFilters(size, storeList, supplierList),

              // Search Buttons
              // _buildSearchButtons(size),

              // Purchase List
              _buildPurchaseList(size, purchaseProvider),

              // Pagination
              PaginationControl(
                currentPage:
                    Provider.of<PurchaseProvider>(context, listen: true)
                        .currentPage,
                totalPages: Provider.of<PurchaseProvider>(context, listen: true)
                    .totalPages,
                onPageChanged: (int page) {
                  searchPurchase(page);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the header section
  Widget _buildHeader(SideBarController sideBarController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Purchase List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: "Create New Purchase",
          fct: () {
            sideBarController.index.value = 20;
          },
          fontSize: 12,
          height: 45,
          width: 200,
        ),
      ],
    );
  }

  // Builds the search filters section
  Widget _buildSearchFilters(Size size, List<GetStoreModelData>? storeList,
      List<GetSuppliersModelData>? supplierList) {
    return Column(
      children: [
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPurchaserNameField(size),
              _buildProductNameField(size),
              _buildStoreDropdown(size, storeList),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSupplierDropdown(size, supplierList),
              _buildDateField(size),
              _buildSearchButtons(size),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaserNameField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Name",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          buildColumnWidgetForTextFields(
            height: 45,
            width: 120,
            controller: purchaserNameController,
            size: size,
            hintText: 'Purchaser Name',
            onchanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildProductNameField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Product",
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          buildColumnWidgetForTextFields(
            height: 45,
            width: 120,
            controller: productNameController,
            size: size,
            hintText: 'Product Name',
            onchanged: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDropdown(Size size, List<GetStoreModelData>? storeList) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Store",
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          SizedBox(
            height: 45,
            width: 150,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              child: DropdownButtonFormField<GetStoreModelData>(
                decoration: const InputDecoration(border: InputBorder.none),
                value: storeSelected,
                hint: Text(
                  'Select Store',
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5)),
                ),
                items: storeList!.map((GetStoreModelData store) {
                  return DropdownMenuItem<GetStoreModelData>(
                    value: store,
                    child: Text(
                      store.name ?? '',
                      style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5)),
                    ),
                  );
                }).toList(),
                onChanged: (GetStoreModelData? storeModelData) {
                  if (storeModelData != null) {
                    setState(() {
                      storeSelected = storeModelData;
                      storeController.text = "${storeModelData.id ?? 1}";
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierDropdown(
      Size size, List<GetSuppliersModelData>? supplierList) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Supplier",
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          SizedBox(
            height: 45,
            width: 150,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              padding: const EdgeInsets.only(left: 15),
              child: DropdownButtonFormField<GetSuppliersModelData>(
                decoration: const InputDecoration(border: InputBorder.none),
                value: supplier,
                hint: Text(
                  'Select Supplier',
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.27,
                      ColorManager.textColor.withOpacity(.5)),
                ),
                items: supplierList!.map((GetSuppliersModelData supplier) {
                  return DropdownMenuItem<GetSuppliersModelData>(
                    value: supplier,
                    child: Text(supplier.name ?? '',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        )),
                  );
                }).toList(),
                onChanged: (GetSuppliersModelData? suppliersModelData) {
                  setState(() {
                    supplier = suppliersModelData;
                    supplierIdController.text =
                        "${suppliersModelData?.id ?? 1}";
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(Size size) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Date",
                style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                    0.27, Colors.black.withOpacity(0.6))),
          ),
          BuildBoxShadowContainer(
            circleRadius: 7,
            height: 45,
            width: 150,
            child: Center(
              child: CalendarPickerTableCell(
                onDateSelected: (DateTime date) {
                  selectedDate = date;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build the buttons for search and reset
  Widget _buildSearchButtons(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15.0, top: 35),
          child: Column(
            children: [
              CustomRoundButton(
                title: "Search",
                fct: () {
                  searchPurchase(1);
                },
                height: 45,
                width: size.width * 0.09,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 35),
          child: Column(
            children: [
              CustomRoundButton(
                title: "Reset",
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: resetSearch,
                height: 45,
                width: size.width * 0.09,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build the purchase list table
  Widget _buildPurchaseList(Size size, PurchaseProvider purchaseProvider) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 20),
      circleRadius: 7,
      child: initLoading
          ? _buildLoadingTable()
          : _buildDataTable(size, purchaseProvider),
    );
  }

  // Loading table placeholder
  Widget _buildLoadingTable() {
    // Similar loading structure can be added here
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30.0),
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }

  // Data Table building logic
  Widget _buildDataTable(Size size, PurchaseProvider purchaseProvider) {
    debugPrint(
        "Data Table :- ${purchaseProvider.purchaseItemListAllPurchase!.length}");
    return Table(
      columnWidths: const {
        0: FractionColumnWidth(0.01),
        1: FractionColumnWidth(0.06),
        2: FractionColumnWidth(0.06),
        3: FractionColumnWidth(0.06),
      },
      border: const TableBorder.symmetric(
        outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
        inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableHeader(),
        ...purchaseDetailsList!.asMap().entries.map((entry) {
          return _buildTableRow(entry.key, entry.value, purchaseProvider);
        }).toList(),
      ],
    );
  }

  // Table Header
  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _buildTableCell("No"),
        _buildTableCell("Purchaser Name"),
        _buildTableCell("Amount"),
        _buildTableCell("Action"),
      ],
    );
  }

  // Build individual table cell for headers & rows
  TableCell _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.18, ColorManager.textColor),
          ),
        ),
      ),
    );
  }

  // Building rows of the data table
  TableRow _buildTableRow(
      int index, PurchaseItem purchase, PurchaseProvider purchaseProvider) {
    debugPrint("voucher.amountTotal ${purchase.unitPrice}");
    return TableRow(
      children: [
        _buildTableCell((index + 1).toString()),
        _buildTableCell("Sales Executive"),
        _buildTableCell("${purchase.unitPrice! * purchase.quantity!.toInt()}"),
        _buildActionCell(purchase, purchaseProvider)
      ],
    );
  }

  // Action cell with icons
  TableCell _buildActionCell(
      PurchaseItem purchase, PurchaseProvider purchaseProvider) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Row(
            children: [
              BuildBoxShadowContainer(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                circleRadius: 5,
                child: IconButton(
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                  ),
                  onPressed: () {
                    debugPrint("purchase.voucherId ${purchase.voucherId}");
                    debugPrint("purchase.purchaseId ${purchase.purchaseId}");
                    purchaseProvider.callVoucherDetails(
                        voucherId: purchase.voucherId ?? 0,
                        purchaseId: purchase.purchaseId ?? 0);
                    Get.put(SideBarController()).index.value = 36;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
