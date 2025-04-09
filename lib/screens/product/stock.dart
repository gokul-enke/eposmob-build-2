import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/resources/app_url.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';

import '../../models/list_stock.dart';
import '../../providers/auth_model.dart';
import '../../providers/grid_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final TextEditingController stockNameController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  ListStockModelData? selectedStock;
  bool initLoading = false;
  bool isInitialized = false;
  List<String> categories = ["All Categories"]; // Default category option

  @override
  void initState() {
    super.initState();
    loadInitData();
    categoryController.text = "All Categories"; // Initialize with default value
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }

      // Load all stocks for local pagination
      await Provider.of<GridSelectionProvider>(context, listen: false)
          .loadAllStocks(accessToken);

      // Extract unique categories from stocks
      _extractCategories();

      setState(() {
        isInitialized = true;
        initLoading = false;
      });
    } catch (error) {
      debugPrint("Error loading stocks: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading stocks: $error")),
      );
      setState(() {
        initLoading = false;
      });
    }
  }

  void _extractCategories() {
    final provider = Provider.of<GridSelectionProvider>(context, listen: false);
    final allStocks = provider.allStocks;

    if (allStocks != null && allStocks.isNotEmpty) {
      // Extract unique categories
      final uniqueCategories = allStocks
          .map((stock) => stock.categoryName ?? "")
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList();

      // Sort categories alphabetically
      uniqueCategories.sort();

      setState(() {
        categories = ["All Categories", ...uniqueCategories];
      });
    }
  }

  void searchStocks() {
    GridSelectionProvider provider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    provider.applyStockFiltersLocally(
      filterName: stockNameController.text,
      filterCategory: categoryController.text == "All Categories"
          ? null
          : categoryController.text,
      page: 1,
    );
  }

  void resetSearch() {
    setState(() {
      stockNameController.clear();
      categoryController.text = "All Categories";
    });
    Provider.of<GridSelectionProvider>(context, listen: false)
        .resetStockFilters();
  }

  void _showStockDetails(ListStockModelData stock) {
    setState(() {
      selectedStock = stock;
    });

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
                  const Text(
                    'Stock Details',
                    style: TextStyle(
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
                    _buildDetailRow('Product Name', stock.productName ?? 'N/A'),
                    _buildDetailRow('Category', stock.categoryName ?? 'N/A'),
                    _buildDetailRow('Store Name', stock.storeName ?? 'N/A'),
                    _buildDetailRow('Supplier', stock.supplierName ?? 'N/A'),
                    _buildDetailRow('Unit', stock.unit ?? 'N/A'),
                    _buildDetailRow(
                        'Retail Price', stock.retailPrice?.toString() ?? 'N/A'),
                    _buildDetailRow('MRP', stock.mrp?.toString() ?? 'N/A'),
                    _buildDetailRow('Purchase Price',
                        stock.purchaseRate?.toString() ?? 'N/A'),
                    _buildDetailRow('Quantity', stock.qty?.toString() ?? 'N/A'),
                    _buildDetailRow('Rack', stock.rack ?? 'N/A'),
                    _buildDetailRow('Wholesale Price',
                        stock.wholesalePrice?.toString() ?? 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
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
    // Controllers for editable fields
    final TextEditingController retailPriceController =
        TextEditingController(text: stock.retailPrice);
    final TextEditingController mrpController =
        TextEditingController(text: stock.mrp);
    final TextEditingController purchasePriceController =
        TextEditingController(text: stock.purchaseRate);
    final TextEditingController quantityController =
        TextEditingController(text: stock.qty?.toString() ?? '0');
    final TextEditingController rackController =
        TextEditingController(text: stock.rack);

    // State for racks dropdown
    Map<String, String> racksData = {};
    String? selectedRack = stock.rack;

    // Fetch racks data
    Future<void> fetchRacksData() async {
      debugPrint("fetchRacksData API called");

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint("Authentication token is missing");
        return;
      }

      debugPrint(
          "Using token: ${accessToken.substring(0, min(accessToken.length, 10))}...");

      try {
        final url = Uri.parse(APPUrl.getRacksDataValues);
        debugPrint("Making API call to ${url.toString()}");

        final response = await http.get(url, headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json'
        });

        debugPrint('API response status code: ${response.statusCode}');
        debugPrint(
            'API response body: ${response.body.substring(0, min(response.body.length, 100))}...');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            racksData = Map<String, String>.from(data['data']);
            debugPrint("Successfully loaded ${racksData.length} racks");
          } else {
            debugPrint("API returned error status: ${data['message']}");
          }
        } else {
          debugPrint('Error in API response: ${response.reasonPhrase}');
        }
      } catch (error) {
        debugPrint('Exception in fetchRacksData: $error');
      }
    }

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
            maxWidth: MediaQuery.of(context).size.width * 0.7,
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
                    'Edit Stock: ${stock.productName}',
                    style: const TextStyle(
                      fontSize: 20,
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // First row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Retail Price
                          Expanded(
                            child: _buildEditableField(
                              'Retail Price',
                              retailPriceController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // MRP
                          Expanded(
                            child: _buildEditableField(
                              'MRP',
                              mrpController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Second row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Purchase Price
                          Expanded(
                            child: _buildEditableField(
                              'Purchase Price',
                              purchasePriceController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Quantity
                          Expanded(
                            child: _buildEditableField(
                              'Quantity',
                              quantityController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Third row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rack
                          Expanded(
                            child: FutureBuilder(
                              future: fetchRacksData(),
                              builder: (context, snapshot) {
                                return StatefulBuilder(
                                    builder: (context, setState) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rack',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: racksData
                                                    .containsKey(selectedRack)
                                                ? selectedRack
                                                : null,
                                            isExpanded: true,
                                            hint: const Text('Select Rack'),
                                            items:
                                                racksData.entries.map((entry) {
                                              return DropdownMenuItem<String>(
                                                value: entry.key,
                                                child: Text(entry.value),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                setState(() {
                                                  selectedRack = newValue;
                                                  rackController.text =
                                                      newValue;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Empty space for alignment
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Cancel",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                  const SizedBox(width: 16),
                  CustomRoundButton(
                    title: "Update",
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: () async {
                      // Get the access token
                      String? accessToken =
                          Provider.of<AuthModel>(context, listen: false).token;

                      if (accessToken == null || accessToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Authentication token is missing")),
                        );
                        return;
                      }

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      // Call the update function
                      final success = await Provider.of<GridSelectionProvider>(
                              context,
                              listen: false)
                          .updateStockDetails(
                        stockId: stock.stockId!,
                        retailPrice: retailPriceController.text,
                        mrp: mrpController.text,
                        purchasePrice: purchasePriceController.text,
                        quantity: quantityController.text,
                        rack: rackController.text,
                        accessToken: accessToken,
                      );

                      // Close the loading dialog
                      Navigator.pop(context);

                      // Close the edit dialog
                      Navigator.pop(context);

                      if (success) {
                        showScaffold(
                            context: context,
                            message: "Stock updated successfully");
                      } else {
                        showScaffoldError(
                            context: context,
                            message: "Failed to update stock");
                      }
                    },
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

  Widget _buildEditableField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.20,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 4),
          BuildBoxShadowContainer(
            circleRadius: 7,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            height: 45,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: 'Enter $label',
                hintStyle: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.27,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Product Stock List",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        SizedBox(
                          width: isSmallScreen
                              ? size.width * 0.3
                              : size.width * 0.15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Stock Name ",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 15),
                                height: 45,
                                child: TextField(
                                  controller: stockNameController,
                                  onChanged: (value) {
                                    searchStocks();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Stock Name',
                                    hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: isSmallScreen
                              ? size.width * 0.3
                              : size.width * 0.15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Category",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 15),
                                height: 45,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  value: categoryController.text,
                                  hint: Text(
                                    'Please Select',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  items: categories
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value == "All Categories"
                                            ? 'Please Select'
                                            : value,
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      categoryController.text = newValue!;
                                    });
                                    searchStocks();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomRoundButton(
                              title: "Search",
                              fct: () => {searchStocks()},
                              height: 45,
                              width: isSmallScreen
                                  ? size.width * 0.2
                                  : size.width * 0.08,
                              fontSize: FontSize.s12,
                              boxColor: ColorManager.kPrimaryColor,
                              textColor: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            CustomRoundButton(
                              title: "Reset",
                              boxColor: Colors.white,
                              textColor: ColorManager.kPrimaryColor,
                              borderColor: ColorManager.kPrimaryColor,
                              fct: resetSearch,
                              height: 45,
                              width: isSmallScreen
                                  ? size.width * 0.2
                                  : size.width * 0.08,
                              fontSize: FontSize.s12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: initLoading ||
                              Provider.of<GridSelectionProvider>(context,
                                      listen: true)
                                  .stockIsLoading
                          ? const Center(
                              child: CircularProgressIndicator.adaptive())
                          : Consumer<GridSelectionProvider>(
                              builder: (context, gridProvider, child) {
                                List<ListStockModelData>?
                                    listStockModelDataList =
                                    gridProvider.getListStockModelDataList;

                                if (listStockModelDataList == null ||
                                    listStockModelDataList.isEmpty) {
                                  return const Center(
                                      child: Text("No stock data available"));
                                }

                                return BuildBoxShadowContainer(
                                  margin: const EdgeInsets.only(top: 5),
                                  circleRadius: 7,
                                  offsetValue: const Offset(2, 2),
                                  blurRadius: 8.0,
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      // Fixed table header
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
                                            0: FlexColumnWidth(2.0), // Product
                                            1: FlexColumnWidth(1.5), // Barcode
                                            2: FlexColumnWidth(
                                                1.2), // Retail Price
                                            3: FlexColumnWidth(1.2), // MRP
                                            4: FlexColumnWidth(
                                                1.2), // Purchase Price
                                            5: FlexColumnWidth(0.8), // Quantity
                                            6: FlexColumnWidth(0.8), // Unit
                                            7: FlexColumnWidth(1.0), // Rack
                                            8: FlexColumnWidth(
                                                1.5), // Order Date
                                            9: FlexColumnWidth(1.5), // Action
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                _buildTableHeader('Product'),
                                                _buildTableHeader('Barcode'),
                                                _buildTableHeader(
                                                    'Retail Price'),
                                                _buildTableHeader('MRP'),
                                                _buildTableHeader(
                                                    'Purchase Price'),
                                                _buildTableHeader('Quantity'),
                                                _buildTableHeader('Unit'),
                                                _buildTableHeader('Rack'),
                                                _buildTableHeader('Order Date'),
                                                _buildTableHeader('Action'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Scrollable table body
                                      Expanded(
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: ScrollConfiguration(
                                            behavior:
                                                ScrollConfiguration.of(context)
                                                    .copyWith(
                                              dragDevices: {
                                                PointerDeviceKind.mouse,
                                                PointerDeviceKind.touch,
                                                PointerDeviceKind.stylus,
                                                PointerDeviceKind.trackpad,
                                              },
                                            ),
                                            child: SingleChildScrollView(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              scrollDirection: Axis.vertical,
                                              child: Table(
                                                columnWidths: const {
                                                  0: FlexColumnWidth(
                                                      2.0), // Product
                                                  1: FlexColumnWidth(
                                                      1.5), // Barcode
                                                  2: FlexColumnWidth(
                                                      1.2), // Retail Price
                                                  3: FlexColumnWidth(
                                                      1.2), // MRP
                                                  4: FlexColumnWidth(
                                                      1.2), // Purchase Price
                                                  5: FlexColumnWidth(
                                                      0.8), // Quantity
                                                  6: FlexColumnWidth(
                                                      0.8), // Unit
                                                  7: FlexColumnWidth(
                                                      1.0), // Rack
                                                  8: FlexColumnWidth(
                                                      1.5), // Order Date
                                                  9: FlexColumnWidth(
                                                      1.5), // Action
                                                },
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  // Table Rows
                                                  ...listStockModelDataList
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final int index = entry.key;
                                                    final stock = entry.value;
                                                    return TableRow(
                                                      decoration: BoxDecoration(
                                                        color: index % 2 == 0
                                                            ? Colors.white
                                                            : Colors.grey
                                                                .withOpacity(
                                                                    0.1),
                                                      ),
                                                      children: [
                                                        _buildTableCell(
                                                            '${stock.productName}'),
                                                        _buildTableCell(
                                                            'N/A'), // Barcode
                                                        _buildTableCell(
                                                            '${stock.retailPrice}'),
                                                        _buildTableCell(
                                                            stock.mrp ?? "N/A"),
                                                        _buildTableCell(stock
                                                                .purchaseRate ??
                                                            "N/A"),
                                                        _buildTableCell(
                                                            '${stock.qty}'),
                                                        _buildTableCell(
                                                            '${stock.unit}'),
                                                        _buildTableCell(
                                                            stock.rack ??
                                                                "N/A"),
                                                        _buildTableCell(DateHelper
                                                            .formatISODate(stock
                                                                    .orderDate ??
                                                                "")), // Order Date
                                                        Center(
                                                          child: Row(
                                                            children: [
                                                              BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5,
                                                                          right:
                                                                              5),
                                                                  color: ColorManager
                                                                      .kPrimaryColor
                                                                      .withOpacity(
                                                                          0.9),
                                                                  circleRadius:
                                                                      5,
                                                                  child:
                                                                      IconButton(
                                                                    icon:
                                                                        const Icon(
                                                                      Icons
                                                                          .edit,
                                                                      size: 18,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    onPressed: () =>
                                                                        _showEditStockModal(
                                                                            stock),
                                                                  )),
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        8.0),
                                                                child:
                                                                    BuildBoxShadowContainer(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5,
                                                                          right:
                                                                              5),
                                                                  circleRadius:
                                                                      5,
                                                                  child:
                                                                      IconButton(
                                                                    icon: Icon(
                                                                      Icons
                                                                          .visibility,
                                                                      size: 18,
                                                                      color: ColorManager
                                                                          .kPrimaryColor
                                                                          .withOpacity(
                                                                              0.9),
                                                                    ),
                                                                    onPressed: () =>
                                                                        _showStockDetails(
                                                                            stock),
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                      minWidth:
                                                                          36,
                                                                      minHeight:
                                                                          36,
                                                                    ),
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                  ),
                                                                ),
                                                              ),
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
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    PaginationControl(
                      currentPage: Provider.of<GridSelectionProvider>(context,
                              listen: true)
                          .stockCurrentPage,
                      totalPages: Provider.of<GridSelectionProvider>(context,
                              listen: true)
                          .stockTotalPages,
                      onPageChanged: (int page) {
                        Provider.of<GridSelectionProvider>(context,
                                listen: false)
                            .goToStockPage(page);
                      },
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
}
