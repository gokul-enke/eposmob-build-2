import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart' hide showScaffold, showScaffoldError, showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart'
    as pagination;
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dropdown_with_search.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/supplier_voucher_print.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';
import 'supplier_voucher_list_mobile.dart'; 

class SupplierVoucherListScreen extends StatefulWidget {
  const SupplierVoucherListScreen({super.key});

  @override
  State<SupplierVoucherListScreen> createState() =>
      _SupplierVoucherListScreenState();
}

class _SupplierVoucherListScreenState extends State<SupplierVoucherListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitialized = false;
  final TextEditingController voucherNumberController = TextEditingController();
  String? selectedType;
  String? selectedStatus;
  int? selectedSupplierId;

  final FocusNode supplierFocusNode = FocusNode();
  final FocusNode typeFocusNode = FocusNode();
  final FocusNode statusFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadVouchers();
    });
  }

  @override
  void dispose() {
    voucherNumberController.dispose();
    supplierFocusNode.dispose();
    typeFocusNode.dispose();
    statusFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadVouchers() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('supplier_voucher.auth_token_missing'.tr)),
        );
        return;
      }

      await Provider.of<SupplierVoucherProvider>(context, listen: false)
          .listAllSupplierVouchers(accessToken: accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('supplier_voucher.error_loading_vouchers'.tr.replaceAll('@error', error.toString()))),
      );
    }
  }

  void searchVouchers() {
    SupplierVoucherProvider provider =
        Provider.of<SupplierVoucherProvider>(context, listen: false);
    provider.applyFilters(
      supplierId: selectedSupplierId,
      voucherNumber: voucherNumberController.text,
      type: selectedType,
      status: selectedStatus,
    );
  }

  void resetSearch() {
    setState(() {
      voucherNumberController.clear();
      selectedType = null;
      selectedStatus = null;
      selectedSupplierId = null;
    });

    Provider.of<SupplierVoucherProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    setState(() {
      voucherNumberController.clear();
    });

    await Provider.of<SupplierVoucherProvider>(context, listen: false)
        .listAllSupplierVouchers(accessToken: accessToken);
  }

@override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<SupplierVoucherProvider>(
            builder: (context, voucherProvider, child) {
              // Build supplier map from allVouchers
              final supplierMap = <int, String>{};
              for (final v in voucherProvider.allVouchers ?? []) {
                supplierMap[v.supplier.id] = v.supplier.name;
              }
              return SupplierVoucherMobileView(
                vouchers: voucherProvider.voucherListDetails ?? const <SupplierVoucher>[],
                isLoading: voucherProvider.isLoading,
                voucherNumberController: voucherNumberController,
                supplierFocusNode: supplierFocusNode,
                typeFocusNode: typeFocusNode,
                statusFocusNode: statusFocusNode,
                selectedSupplierId: selectedSupplierId,
                selectedType: selectedType,
                selectedStatus: selectedStatus,
                supplierOptions: supplierMap,
                typeOptions: voucherProvider.getTypeOptions()
                    .where((t) => t != 'All Types').toList(),
                statusOptions: voucherProvider.getStatusOptions()
                    .where((s) => s != 'All Status').toList(),
                onSearchChanged: searchVouchers,
                onReset: resetSearch,
                onSupplierChanged: (v) {
                  setState(() => selectedSupplierId = v);
                  searchVouchers();
                },
                onTypeChanged: (v) {
                  setState(() => selectedType = v);
                  searchVouchers();
                },
                onStatusChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchVouchers();
                },
                onViewDetails: _showVoucherDetails,
                onShare: (voucher) => ShareHelper.showShareSupplierVoucherSheet(
                  context: context,
                  voucher: voucher,
                ),
                currentPage: voucherProvider.currentPage,
                totalPages: voucherProvider.totalPages,
                onPageChanged: (page) => voucherProvider.goToPage(page),
                onCreateVoucher: () {
                  final controller = Get.find<SideBarController>();
                  controller.index.value =
                      (controller.index.value == 75) ? 76 : 73;
                },
                onRefresh: refreshData,
              );
            },
          ),
        ),
      );
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 10),
                _buildSearchBar(size),
                const SizedBox(height: 10),
                _buildVoucherTable(),
                const SizedBox(height: 10),
                _buildPaginationControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'supplier_voucher.list_title'.tr,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: 'supplier_voucher.create_voucher_button'.tr,
          fct: () {
            final controller = Get.find<SideBarController>();
            // If this list was opened via Transactions alias (75), go to 76. Otherwise go to 73.
            controller.index.value = (controller.index.value == 75) ? 76 : 73;
          },
          fontSize: FontSize.s12,
          height: 45,
          width: 180,
        ),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        SizedBox(
          height: 55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSupplierFilter(),
              const SizedBox(width: 10),
              _buildVoucherNumberSearch(),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: _buildTypeFilter()),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: _buildStatusFilter()),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomRoundButton(
                title: 'general.reset'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                fct: resetSearch,
                height: 45,
                width: 150,
                fontSize: FontSize.s12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierFilter() {
    return Expanded(
      flex: 1,
      child: Consumer<SupplierVoucherProvider>(
        builder: (context, voucherProvider, child) {
          final uniqueSuppliers = <int, String>{};
          if (voucherProvider.allVouchers != null) {
            for (var voucher in voucherProvider.allVouchers!) {
              uniqueSuppliers[voucher.supplier.id] = voucher.supplier.name;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: Text(
              //     "Supplier",
              //     style: buildCustomStyle(FontWeightManager.regular,
              //         FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
              //   ),
              // ),
              // const SizedBox(height: 8),
              BuildDropDownWithSearch<int>(
                focusNode: supplierFocusNode,
                title: null,
                showName: false,
                hintText: 'supplier_voucher.all_suppliers_hint'.tr,
                value: selectedSupplierId,
                items: uniqueSuppliers.keys.toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    selectedSupplierId = newValue;
                  });
                  searchVouchers();
                },
                displayText: (int? id) {
                  if (id == null) return 'supplier_voucher.all_suppliers_hint'.tr;
                  return uniqueSuppliers[id] ?? 'general.unknown'.tr;
                },
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoucherNumberSearch() {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "Voucher No",
          //     style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
          //         0.27, Colors.black.withOpacity(0.6)),
          //   ),
          // ),
          // const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: voucherNumberController,
              onChanged: (value) => searchVouchers(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'supplier_voucher.voucher_no_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                contentPadding: const EdgeInsets.only(left: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<SupplierVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> typeOptions = voucherProvider.getTypeOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: typeFocusNode,
                title: null,
                showName: false,
                hintText: 'All Types',
                value: selectedType,
                items:
                    typeOptions.where((type) => type != "All Types").toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedType = newValue;
                  });
                  searchVouchers();
                },
                displayText: (type) => type.toUpperCase(),
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<SupplierVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> statusOptions = voucherProvider.getStatusOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: statusFocusNode,
                title: null,
                showName: false,
                hintText: 'All Status',
                value: selectedStatus,
                items: statusOptions
                    .where((status) => status != "All Status")
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedStatus = newValue;
                  });
                  searchVouchers();
                },
                displayText: (status) => status.toUpperCase(),
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherTable() {
    return Expanded(
      child: Consumer<SupplierVoucherProvider>(
        builder: (context, voucherProvider, child) {
          final isLoading = voucherProvider.isLoading;
          final voucherList = voucherProvider.voucherListDetails;

          return isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : voucherList == null || voucherList.isEmpty
                  ? _buildNoVouchersFoundUI()
                  : BuildBoxShadowContainer(
                      margin: const EdgeInsets.only(top: 5),
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
                              columnWidths: {
                                0: const FlexColumnWidth(1.4),
                                1: const FlexColumnWidth(1.6),
                                2: const FlexColumnWidth(0.9),
                                3: const FlexColumnWidth(1.3),
                                4: const FlexColumnWidth(1.3),
                                5: const FlexColumnWidth(1.0),
                                6: const FlexColumnWidth(0.9),
                                7: const FlexColumnWidth(0.9),
                                8: FlexColumnWidth(
                                    MediaQuery.of(context).size.width < 900
                                        ? 2.6
                                        : 1.8),
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildTableHeader('supplier_voucher.col_voucher_number'.tr),
                                    _buildTableHeader('supplier_voucher.col_supplier_name'.tr),
                                    _buildTableHeader('supplier_voucher.col_type'.tr),
                                    _buildTableHeader('supplier_voucher.col_voucher_date'.tr),
                                    _buildTableHeader('supplier_voucher.col_due_date'.tr),
                                    _buildTableHeader('supplier_voucher.col_payment_method'.tr),
                                    _buildTableHeader('supplier_voucher.col_paid_amount'.tr),
                                    _buildTableHeader('supplier_voucher.col_status'.tr),
                                    _buildTableHeader('supplier_voucher.col_action'.tr),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.vertical,
                              child: Table(
                                columnWidths: {
                                  0: const FlexColumnWidth(1.4),
                                  1: const FlexColumnWidth(1.6),
                                  2: const FlexColumnWidth(0.9),
                                  3: const FlexColumnWidth(1.3),
                                  4: const FlexColumnWidth(1.3),
                                  5: const FlexColumnWidth(1.0),
                                  6: const FlexColumnWidth(0.9),
                                  7: const FlexColumnWidth(0.9),
                                  8: FlexColumnWidth(
                                      MediaQuery.of(context).size.width < 900
                                          ? 2.6
                                          : 1.8),
                                },
                                border: null,
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children:
                                    voucherList.asMap().entries.map((entry) {
                                  final int index = entry.key;
                                  final voucher = entry.value;
                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0
                                          ? Colors.white
                                          : Colors.grey.withOpacity(0.1),
                                    ),
                                    children: [
                                       TableCell(
                                         verticalAlignment:
                                             TableCellVerticalAlignment.middle,
                                         child: Padding(
                                           padding: const EdgeInsets.all(8.0),
                                           child: Row(
                                             mainAxisAlignment:
                                                 MainAxisAlignment.center,
                                             children: [
                                               Text(
                                                 voucher.voucherNumber,
                                                 textAlign: TextAlign.center,
                                                 style: buildCustomStyle(
                                                   FontWeightManager.medium,
                                                   FontSize.s9,
                                                   0.13,
                                                   Colors.black,
                                                 ),
                                               ),
                                               const SizedBox(width: 6),
                                               GestureDetector(
                                                 onTap: () {
                                                   Clipboard.setData(
                                                       ClipboardData(
                                                           text: voucher
                                                               .voucherNumber));
                                                   showScaffold(
                                                     context: context,
                                                     message:
                                                         'supplier_voucher.voucher_number_copied'.tr,
                                                   );
                                                 },
                                                 child: const Icon(
                                                   Icons.copy,
                                                   size: 14,
                                                   color: Colors.black38,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                      TableCell(
                                        verticalAlignment: TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Center(
                                            child: SelectableText(
                                              voucher.supplier.name,
                                              textAlign: TextAlign.center,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s9,
                                                0.13,
                                                Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildTableCell(voucher.type),
                                      _buildTableCell(voucher.voucherDate),
                                      _buildTableCell(voucher.dueDate),
                                      _buildTableCell(voucher.paymentMethod),
                                      _buildTableCell(
                                          '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${voucher.amount}'),
                                      Center(
                                        child: _buildStatusChip(voucher.status),
                                      ),
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(width: 8),
                                              BuildBoxShadowContainer(
                                                margin: const EdgeInsets.only(
                                                    left: 5, right: 5),
                                                circleRadius: 5,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.visibility,
                                                    size: 18,
                                                    color: ColorManager
                                                        .kPrimaryColor
                                                        .withOpacity(0.9),
                                                  ),
                                                  onPressed: () =>
                                                      _showVoucherDetails(
                                                          voucher),
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 36,
                                                    minHeight: 36,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                              BuildBoxShadowContainer(
                                                margin: const EdgeInsets.only(
                                                    left: 5, right: 5),
                                                circleRadius: 5,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.print,
                                                    size: 18,
                                                    color: ColorManager
                                                        .kPrimaryColor
                                                        .withOpacity(0.9),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            SupplierVoucherPrintPage(
                                                          voucher: voucher,
                                                          returnToPreviousRoute:
                                                              true,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 36,
                                                    minHeight: 36,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                              BuildBoxShadowContainer(
                                                margin: const EdgeInsets.only(
                                                    left: 5, right: 5),
                                                circleRadius: 5,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.share,
                                                    size: 18,
                                                    color: ColorManager
                                                        .kPrimaryColor
                                                        .withOpacity(0.9),
                                                  ),
                                                  onPressed: () {
                                                    ShareHelper.showShareSupplierVoucherSheet(
                                                      context: context,
                                                      voucher: voucher,
                                                    );
                                                  },
                                                  constraints:
                                                      const BoxConstraints(
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
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
        },
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<SupplierVoucherProvider>(
        builder: (context, voucherProvider, child) {
      return pagination.PaginationControl(
        currentPage: voucherProvider.currentPage,
        totalPages: voucherProvider.totalPages,
        onPageChanged: (int page) {
          voucherProvider.goToPage(page);
        },
      );
    });
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
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

  TableCell _buildTableCell(String content) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          content,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s9,
            0.13,
            Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PAID':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'CANCELLED':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNoVouchersFoundUI() {
    return Container(
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'supplier_voucher.no_vouchers_found'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'supplier_voucher.try_adjusting_search'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showVoucherDetails(SupplierVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'supplier_voucher.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_voucher_number'.tr, voucher.voucherNumber, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_supplier_name'.tr, voucher.supplier.name),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.field_supplier_phone'.tr, voucher.supplier.phone, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_type'.tr, voucher.type),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_voucher_date'.tr, voucher.voucherDate),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_due_date'.tr, voucher.dueDate),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_status'.tr, voucher.status),
            CommonDetailsDialog.buildKeyValueRow('supplier_voucher.col_payment_method'.tr, voucher.paymentMethod),
          ],
        ],
        sectionTitle: 'supplier_voucher.items_section_title'.tr,
        tableContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: ColorManager.tableBGColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    children: [
                      _buildTableHeaderCell('supplier_voucher.col_voucher'.tr),
                      _buildTableHeaderCell('supplier_voucher.col_item_name'.tr),
                      _buildTableHeaderCell('supplier_voucher.col_quantity_upper'.tr),
                      _buildTableHeaderCell('supplier_voucher.col_unit_amount_upper'.tr),
                      _buildTableHeaderCell('supplier_voucher.col_tax_upper'.tr),
                      _buildTableHeaderCell('supplier_voucher.col_total_amount_upper'.tr),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Table Body
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1.5),
              },
              children: voucher.items.asMap().entries.map((entry) {
                final item = entry.value;
                final index = entry.key;
                return TableRow(
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? Colors.white
                        : Colors.grey.withOpacity(0.05),
                  ),
                  children: [
                    _buildTableBodyCell(voucher.voucherNumber),
                    _buildTableBodyCell(item.itemName),
                    _buildTableBodyCell(item.quantity),
                    _buildTableBodyCell(item.unitAmount),
                    _buildTableBodyCell(item.tax),
                    _buildTableBodyCell(item.totalAmount),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
        totalsContent: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'supplier_voucher.grand_total_label'.tr,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${voucher.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s18,
                  0.27,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }

  Widget _buildTableBodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.15,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
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
}
