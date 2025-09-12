import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_pagination_control.dart';
import '../../components/build_round_button.dart';
import '../../components/build_text_fields.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/supplier.dart';
import '../../providers/auth_model.dart';
import '../../providers/supplier_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'add_supplier_modal.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController searchEmailController = TextEditingController();
  final TextEditingController searchPhoneController = TextEditingController();
  String selectedBalanceFilter = 'All';
  bool initLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadInitData();
    });
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

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    await Provider.of<SupplierProvider>(context, listen: false).fetchSuppliers(
      accessToken: accessToken,
      supplierName: null,
    );
  }

  // void searchSuppliers(String value) {
  //   try {
  //     String? accessToken =
  //         Provider.of<AuthModel>(context, listen: false).token;
  //     if (accessToken == null || accessToken.isEmpty) return;

  //     SupplierProvider supplierProvider =
  //         Provider.of<SupplierProvider>(context, listen: false);
  //     supplierProvider.applyFiltersLocally(supplierName: value);
  //   } catch (error) {
  //     debugPrint("❌ Supplier search error: ${error.toString()}");
  //     showScaffold(context: context, message: "Error searching suppliers");
  //   }
  // }

  void searchSuppliers({
    String name = '',
    String email = '',
    String phone = '',
    String balance = 'All',
  }) {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      if (accessToken == null || accessToken.isEmpty) return;

      SupplierProvider supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);

      // Apply all filters locally
      supplierProvider.applyFiltersLocally(
        supplierName: name,
        supplierEmail: email,
        supplierPhone: phone,
        filterBalance: balance,
      );
    } catch (error) {
      debugPrint("❌ Supplier search error: ${error.toString()}");
      showScaffold(context: context, message: "Error searching suppliers");
    }
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 15),
              _buildSearchBar(size),
              const SizedBox(height: 15),
              Expanded(
                child: Consumer<SupplierProvider>(
                  builder: (context, supplierProvider, child) {
                    final isLoading = supplierProvider.isLoading;
                    final suppliers = supplierProvider.supplierList ?? [];

                    return Column(
                      children: [
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator.adaptive())
                              : BuildBoxShadowContainer(
                                  width: size.width,
                                  margin: const EdgeInsets.only(top: 20),
                                  circleRadius: 7,
                                  offsetValue: const Offset(1, 1),
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
                                            0: FlexColumnWidth(0.4), // No
                                            1: FlexColumnWidth(1.8), // Name
                                            2: FlexColumnWidth(2.0), // Email
                                            3: FlexColumnWidth(1.3), // Phone
                                            4: FlexColumnWidth(1.5), // Address
                                            5: FlexColumnWidth(1.2), // Balance
                                            6: FlexColumnWidth(
                                                1.5), // Current Balance
                                            7: FlexColumnWidth(0.8), // Action
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              children: [
                                                _buildTableHeader('No'),
                                                _buildTableHeader('Name'),
                                                _buildTableHeader('Email'),
                                                _buildTableHeader('Phone'),
                                                _buildTableHeader('Address'),
                                                _buildTableHeader('Balance'),
                                                _buildTableHeader(
                                                    'Current Balance'),
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
                                              child: suppliers.isEmpty
                                                  ? Container(
                                                      height: 300,
                                                      width: double.infinity,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons.business,
                                                            size: 60,
                                                            color: ColorManager
                                                                .kPrimaryColor
                                                                .withOpacity(
                                                                    0.7),
                                                          ),
                                                          const SizedBox(
                                                              height: 15),
                                                          Text(
                                                            'No suppliers found',
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .medium,
                                                              FontSize.s18,
                                                              0.27,
                                                              ColorManager
                                                                  .textColor,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            'Try adjusting your search criteria',
                                                            style:
                                                                buildCustomStyle(
                                                              FontWeightManager
                                                                  .regular,
                                                              FontSize.s14,
                                                              0.20,
                                                              Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : Table(
                                                      columnWidths: const {
                                                        0: FlexColumnWidth(
                                                            0.4), // No
                                                        1: FlexColumnWidth(
                                                            1.8), // Name
                                                        2: FlexColumnWidth(
                                                            2.0), // Email
                                                        3: FlexColumnWidth(
                                                            1.3), // Phone
                                                        4: FlexColumnWidth(
                                                            1.5), // Address
                                                        5: FlexColumnWidth(
                                                            1.2), // Balance
                                                        6: FlexColumnWidth(
                                                            1.5), // Current Balance
                                                        7: FlexColumnWidth(
                                                            0.8), // Action
                                                      },
                                                      border: null,
                                                      defaultVerticalAlignment:
                                                          TableCellVerticalAlignment
                                                              .middle,
                                                      children: suppliers
                                                          .asMap()
                                                          .entries
                                                          .map((entry) {
                                                        final int index =
                                                            entry.key;
                                                        final supplier =
                                                            entry.value;
                                                        return TableRow(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: index % 2 ==
                                                                    0
                                                                ? Colors.white
                                                                : Colors.grey
                                                                    .withOpacity(
                                                                        0.1),
                                                          ),
                                                          children: [
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                '${index + 1 + (supplierProvider.currentPage - 1) * supplierProvider.itemsPerPage}',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier.name,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier.email,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier.phone,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier.address
                                                                        .isNotEmpty
                                                                    ? supplier
                                                                        .address
                                                                    : 'N/A',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier
                                                                    .balance,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  Colors.black,
                                                                ),
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              child: Text(
                                                                supplier
                                                                    .currentBalance
                                                                    .toStringAsFixed(
                                                                        2),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    buildCustomStyle(
                                                                  FontWeightManager
                                                                      .medium,
                                                                  FontSize.s9,
                                                                  0.13,
                                                                  supplier.paymentType ==
                                                                          'to_pay'
                                                                      ? Colors
                                                                          .red
                                                                      : supplier.paymentType ==
                                                                              'to_receive'
                                                                          ? Colors
                                                                              .green
                                                                          : Colors
                                                                              .black,
                                                                ),
                                                              ),
                                                            ),
                                                            Center(
                                                              child: Padding(
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
                                                                    onPressed:
                                                                        () {
                                                                      supplierProvider
                                                                          .selectSupplier(
                                                                              supplier);
                                                                      // Navigate to supplier details using sidebar controller (like sales screen)
                                                                      Get.find<
                                                                              SideBarController>()
                                                                          .index
                                                                          .value = 57; // New index for supplier details
                                                                    },
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
                                                            ),
                                                          ],
                                                        );
                                                      }).toList(),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        PaginationControl(
                          currentPage: supplierProvider.currentPage,
                          totalPages: supplierProvider.totalPages,
                          onPageChanged: (int page) {
                            supplierProvider.goToPage(page);
                          },
                        ),
                        const SizedBox(height: 15),
                      ],
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Supplier List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: "Add New Supplier",
          fct: () async {
            // Show the add supplier modal
            final result = await showAddSupplierModal(
                context, MediaQuery.of(context).size);

            // If the supplier was added successfully, refresh the list
            if (result != null && result["status"] == "success") {
              refreshData();
            }
          },
          fontSize: 12,
          height: 45,
          width: 150,
        ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          // Name Search Field
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Name",
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    width: double.infinity, // Take full available width
                    onchanged: (value) {
                      if (value != null) {
                        Future.microtask(() {
                          if (value.isEmpty &&
                              searchEmailController.text.isEmpty &&
                              searchPhoneController.text.isEmpty &&
                              selectedBalanceFilter == 'All') {
                            Provider.of<SupplierProvider>(context,
                                    listen: false)
                                .resetFilters();
                          } else {
                            searchSuppliers(
                              name: value,
                              email: searchEmailController.text,
                              phone: searchPhoneController.text,
                              balance: selectedBalanceFilter,
                            );
                          }
                        });
                      }
                    },
                    controller: searchTextController,
                    size: size,
                    hintText: 'Name',
                  ),
                ],
              ),
            ),
          ),

          // Email Search Field
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Email",
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    width: double.infinity, // Take full available width
                    onchanged: (value) {
                      if (value != null) {
                        Future.microtask(() {
                          if (value.isEmpty &&
                              searchTextController.text.isEmpty &&
                              searchPhoneController.text.isEmpty &&
                              selectedBalanceFilter == 'All') {
                            Provider.of<SupplierProvider>(context,
                                    listen: false)
                                .resetFilters();
                          } else {
                            searchSuppliers(
                              name: searchTextController.text,
                              email: value,
                              phone: searchPhoneController.text,
                              balance: selectedBalanceFilter,
                            );
                          }
                        });
                      }
                    },
                    controller: searchEmailController,
                    size: size,
                    hintText: 'Email',
                  ),
                ],
              ),
            ),
          ),

          // Phone Search Field
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Phone",
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                    ),
                  ),
                  buildColumnWidgetForTextFields(
                    height: 45,
                    width: double.infinity, // Take full available width
                    onchanged: (value) {
                      if (value != null) {
                        Future.microtask(() {
                          if (value.isEmpty &&
                              searchTextController.text.isEmpty &&
                              searchEmailController.text.isEmpty &&
                              selectedBalanceFilter == 'All') {
                            Provider.of<SupplierProvider>(context,
                                    listen: false)
                                .resetFilters();
                          } else {
                            searchSuppliers(
                              name: searchTextController.text,
                              email: searchEmailController.text,
                              phone: value,
                              balance: selectedBalanceFilter,
                            );
                          }
                        });
                      }
                    },
                    controller: searchPhoneController,
                    size: size,
                    hintText: 'Phone',
                  ),
                ],
              ),
            ),
          ),

          // Balance Filter Dropdown
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Balance",
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    alignment: Alignment.centerLeft,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    padding: const EdgeInsets.only(left: 15),
                    height: 45,
                    width: double.infinity,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedBalanceFilter,
                      hint: Text(
                        "Select Balance",
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.27,
                          ColorManager.textColor.withOpacity(.5),
                        ),
                      ),
                      items: [
                        'All',
                        'Positive (+ve)',
                        'Negative (-ve)',
                        'Zero (0)'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.27,
                              ColorManager.textColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedBalanceFilter = newValue;
                          });
                          Future.microtask(() {
                            if (newValue == 'All' &&
                                searchTextController.text.isEmpty &&
                                searchEmailController.text.isEmpty &&
                                searchPhoneController.text.isEmpty) {
                              Provider.of<SupplierProvider>(context,
                                      listen: false)
                                  .resetFilters();
                            } else {
                              searchSuppliers(
                                name: searchTextController.text,
                                email: searchEmailController.text,
                                phone: searchPhoneController.text,
                                balance: newValue,
                              );
                            }
                          });
                        }
                      },
                      underline: Container(),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reset Button
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0, top: 30),
              child: CustomRoundButton(
                title: "Reset",
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: () {
                  setState(() {
                    searchTextController.clear();
                    searchEmailController.clear();
                    searchPhoneController.clear();
                    selectedBalanceFilter = 'All';
                  });
                  Future.microtask(() {
                    Provider.of<SupplierProvider>(context, listen: false)
                        .resetFilters();
                  });
                },
                height: 45,
                width: double.infinity, // Take full available width
                fontSize: FontSize.s12,
              ),
            ),
          ),
        ],
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
          maxWidth: MediaQuery.of(context).size.width / 2,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Supplier Details",
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s24,
                    0.36,
                    ColorManager.textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Supplier Information Card
            Expanded(
              child: SingleChildScrollView(
                // padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildInfoRow("Name", supplier.name),
                    const SizedBox(height: 8),
                    _buildInfoRow("Email", supplier.email),
                    const SizedBox(height: 8),
                    _buildInfoRow("Phone", supplier.phone),
                    const SizedBox(height: 8),
                    if (supplier.altPhone != null &&
                        supplier.altPhone!.isNotEmpty) ...[
                      _buildInfoRow("Alternative Phone", supplier.altPhone!),
                      const SizedBox(height: 8),
                    ],
                    _buildInfoRow("Address", supplier.address),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        "Product Categories", supplier.productCategories),
                    const SizedBox(height: 8),
                    _buildInfoRow("Balance", supplier.balance),
                    const SizedBox(height: 8),
                    _buildInfoRowWithColor(
                        "Current Balance",
                        supplier.currentBalance.toStringAsFixed(2),
                        supplier.paymentType),
                    const SizedBox(height: 8),
                    _buildInfoRowWithColor("Balance Status",
                        supplier.balanceStatus, supplier.paymentType),
                    const SizedBox(height: 8),
                    _buildInfoRow("Payment Type", supplier.paymentType),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              "$label ",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.21,
                Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.21,
                Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithColor(
      String label, String value, String paymentType) {
    Color textColor = paymentType == 'to_pay'
        ? Colors.red
        : paymentType == 'to_receive'
            ? Colors.green
            : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              "$label ",
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.21,
                Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.21,
                textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
