import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_pagination_control.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/supplier.dart';
import '../../providers/auth_model.dart';
import '../../providers/supplier_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  bool initLoading = false;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    debugPrint("📌 loadInitData started for Suppliers");
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("📌 Access token length: ${accessToken?.length ?? 0}");

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      debugPrint("📌 Calling supplierProvider.fetchSuppliers");
      await supplierProvider.fetchSuppliers(
        accessToken: accessToken ?? "",
        supplierName: null, // No filter when loading initial data
      );

      debugPrint(
          "📌 Loaded ${supplierProvider.supplierList?.length ?? 0} suppliers");
    } catch (error) {
      debugPrint("❌ Supplier listing error: ${error.toString()}");
      showScaffold(context: context, message: "Error fetching suppliers");
    } finally {
      setState(() {
        initLoading = false;
      });
      debugPrint("📌 loadInitData finished");
    }
  }

  Future<void> refreshData() async {
    setState(() {
      searchTextController.clear();
    });
    loadInitData();
  }

  Future<void> searchSuppliers() async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      String searchText = searchTextController.text.trim();
      await supplierProvider.fetchSuppliers(
        accessToken: accessToken ?? "",
        supplierName: searchText,
      );
    } catch (error) {
      debugPrint("❌ Supplier search error: ${error.toString()}");
      showScaffold(context: context, message: "Error searching suppliers");
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final suppliers = supplierProvider.supplierList ?? [];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
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
            color: Colors.white,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                const SizedBox(height: 15),
                supplierProvider.isLoading
                    ? _buildLoadingIndicator()
                    : suppliers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                "No suppliers found",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : _buildSupplierTable(suppliers),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Supplier List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        // CustomRoundButton(
        //   title: "Add New Supplier",
        //   fct: () {
        //     // Navigate to add supplier screen
        //     // This would be implemented in a future feature
        //     showDialog(
        //       context: context,
        //       builder: (context) => AlertDialog(
        //         title: const Text("Coming Soon"),
        //         content: const Text("Add Supplier functionality coming soon."),
        //         actions: [
        //           TextButton(
        //             onPressed: () => Navigator.pop(context),
        //             child: const Text("OK"),
        //           ),
        //         ],
        //       ),
        //     );
        //   },
        //   fontSize: 12,
        //   height: 45,
        //   width: 200,
        // ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          _buildSearchTextField(),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 30),
            child: CustomRoundButton(
              title: "Search",
              fct: searchSuppliers,
              height: 45,
              width: size.width * 0.09,
              fontSize: FontSize.s12,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, top: 30),
            child: CustomRoundButton(
              title: "Reset",
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: refreshData,
              height: 45,
              width: size.width * 0.09,
              fontSize: FontSize.s12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTextField() {
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
          SizedBox(
            height: 45,
            width: 120,
            child: TextFormField(
              controller: searchTextController,
              onChanged: (value) {
                setState(() {
                  // Update state if needed
                });
              },
              onFieldSubmitted: (value) {
                // Trigger search when Enter key is pressed
                searchSuppliers();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Name",
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierTable(List<Supplier> suppliers) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(top: 20),
      circleRadius: 7,
      offsetValue: const Offset(1, 1),
      child: Table(
        columnWidths: const {
          0: FractionColumnWidth(0.2),
          1: FractionColumnWidth(0.2),
          2: FractionColumnWidth(0.2),
          3: FractionColumnWidth(0.3),
          4: FractionColumnWidth(0.1),
        },
        border: const TableBorder.symmetric(
          outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
          inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildTableHeader(),
          ...suppliers.map((supplier) => _buildSupplierRow(supplier)).toList(),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _buildTableCell("Name"),
        _buildTableCell("Email"),
        _buildTableCell("Phone"),
        _buildTableCell("Address"),
        _buildTableCell("Action"),
      ],
    );
  }

  TableRow _buildSupplierRow(Supplier supplier) {
    return TableRow(
      children: [
        _buildSupplierCell(supplier.name),
        _buildSupplierCell(supplier.email),
        _buildSupplierCell(supplier.phone),
        _buildSupplierCell(supplier.address),
        _buildActionCell(supplier),
      ],
    );
  }

  TableCell _buildTableCell(String title) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            title,
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

  TableCell _buildSupplierCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            content,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s9,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  TableCell _buildActionCell(Supplier supplier) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  onPressed: () {
                    // View supplier details
                    final supplierProvider =
                        Provider.of<SupplierProvider>(context, listen: false);
                    supplierProvider.selectSupplier(supplier);

                    showDialog(
                      context: context,
                      builder: (context) => SupplierDetailModal(supplier: supplier),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const BuildBoxShadowContainer(
      margin: EdgeInsets.only(top: 20),
      circleRadius: 7,
      offsetValue: Offset(1, 1),
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class SupplierDetailModal extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailModal({Key? key, required this.supplier})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Supplier Details",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Supplier Information Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Supplier Information",
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s16,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow("Name", supplier.name),
                    const SizedBox(height: 8),
                    _buildInfoRow("Email", supplier.email),
                    const SizedBox(height: 8),
                    _buildInfoRow("Phone", supplier.phone),
                    const SizedBox(height: 8),
                    _buildInfoRow("Address", supplier.address),
                    const SizedBox(height: 8),
                    _buildInfoRow("Product Categories", supplier.productCategories),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButton(
                  fct: () => Navigator.of(context).pop(),
                  title: "Close",
                  fontSize: FontSize.s12,
                  height: MediaQuery.of(context).size.height * .05,
                  width: 60,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            "$label: ",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.30,
              Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.30,
              Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
