import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart'
    as pagination;
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dropdown_with_search.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/customer_voucher_print.dart';

class CustomerVoucherListScreen extends StatefulWidget {
  const CustomerVoucherListScreen({super.key});

  @override
  State<CustomerVoucherListScreen> createState() =>
      _CustomerVoucherListScreenState();
}

class _CustomerVoucherListScreenState extends State<CustomerVoucherListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitialized = false;
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController voucherNumberController = TextEditingController();
  String? selectedType;
  String? selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadVouchers();
    });
  }

  Future<void> loadVouchers() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }

      await Provider.of<CustomerVoucherProvider>(context, listen: false)
          .listAllCustomerVouchers(accessToken: accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading vouchers: $error")),
      );
    }
  }

  void searchVouchers() {
    debugPrint("Searching with filters");
    CustomerVoucherProvider provider =
        Provider.of<CustomerVoucherProvider>(context, listen: false);
    provider.applyFilters(
      customerName: searchTextController.text,
      voucherNumber: voucherNumberController.text,
      type: selectedType,
      status: selectedStatus,
    );
  }

  void resetSearch() {
    debugPrint("Resetting all filters");
    setState(() {
      searchTextController.clear();
      voucherNumberController.clear();
      selectedType = null;
      selectedStatus = null;
    });

    Provider.of<CustomerVoucherProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    debugPrint("Refreshing data");
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    setState(() {
      searchTextController.clear();
    });

    await Provider.of<CustomerVoucherProvider>(context, listen: false)
        .listAllCustomerVouchers(accessToken: accessToken);
  }

  Future<void> _showVoucherActionsSheet(CustomerVoucher voucher) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'More Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orange.withOpacity(0.12),
                    child: const Icon(Icons.description, color: Colors.orange),
                  ),
                  title: const Text('ZATCA Phase 2'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _performZatcaPhase2SendWithPdf(voucher);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.purple.withOpacity(0.12),
                    child: const Icon(Icons.sync, color: Colors.purple),
                  ),
                  title: const Text('Resync Voucher'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _performZatcaPhase2Resync(voucher);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.12),
                    child: Icon(Icons.send,
                        color: ColorManager.kPrimaryColor),
                  ),
                  title: const Text('Send to ZATCA'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _performZatcaPhase2Send(voucher);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performZatcaPhase2SendWithPdf(CustomerVoucher voucher) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Send With PDF] Start for voucher '+voucher.voucherNumber+' (ID: '+voucher.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Processing ZATCA Phase 2...');
      showLoadingOverlay(context, message: 'Processing...');

      final provider = Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send With PDF] Response: '+result.toString());
      if (result is Map && ((result['status'] == 'success') || (result['success'] == true) || (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber = (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        }
        showScaffold(
          context: context,
          message: 'Voucher '+voucherNumber+' processed under ZATCA Phase 2.',
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ?? 'Failed to process ZATCA Phase 2';
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: '+msg.toString());
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send With PDF] EXCEPTION: '+e.toString());
      showScaffoldError(context: context, message: 'Error: '+e.toString());
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Resync(CustomerVoucher voucher) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Resync] Start for voucher '+voucher.voucherNumber+' (ID: '+voucher.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Resync] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Resyncing voucher with ZATCA...');
      showLoadingOverlay(context, message: 'Resyncing...');

      final provider = Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherResync(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Resync] Response: '+result.toString());
      if (result is Map) {
        final bool ok = (result['status'] == 'success') || (result['success'] == true) || (result['status'] == true);
        final data = (result['data'] is Map) ? result['data'] as Map : null;
        final String voucherNumber = data?['voucher_number']?.toString() ?? voucher.voucherNumber;
        final String resyncStatus = data?['resync_status']?.toString() ?? (ok ? 'success' : 'failed');
        final String? rawError = data?['error']?.toString();
        if (ok) {
          showScaffold(
            context: context,
            message: 'Voucher '+voucherNumber+' resynced with status: '+resyncStatus,
          );
        } else {
          String detail = rawError != null
              ? rawError.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
              : (result['message']?.toString() ?? 'Failed to resync voucher');
          if (detail.length > 220) detail = detail.substring(0, 220)+'...';
          final errMsg = 'Resync failed for '+voucherNumber+' (status: '+resyncStatus+'). '+detail;
          debugPrint('[ZATCA][Phase2 Resync] ERROR: '+errMsg);
          showScaffoldError(context: context, message: errMsg);
        }
      } else {
        showScaffoldError(context: context, message: 'Failed to resync voucher');
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Resync] EXCEPTION: '+e.toString());
      showScaffoldError(context: context, message: 'Error: '+e.toString());
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Send(CustomerVoucher voucher) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Send] Start for voucher '+voucher.voucherNumber+' (ID: '+voucher.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Sending to ZATCA...');
      showLoadingOverlay(context, message: 'Sending...');

      final provider = Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send] Response: '+result.toString());
      if (result is Map && ((result['status'] == 'success') || (result['success'] == true) || (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber = (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        showScaffold(
          context: context,
          message: 'Voucher '+voucherNumber+' submitted to ZATCA successfully.',
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ?? 'Failed to send to ZATCA';
        debugPrint('[ZATCA][Phase2 Send] ERROR: '+msg.toString());
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send] EXCEPTION: '+e.toString());
      showScaffoldError(context: context, message: 'Error: '+e.toString());
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _downloadAndOpenPdf(String url, {String? suggestedFileName}) async {
    try {
      if (kIsWeb) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
        showScaffold(context: context, message: 'Opened PDF in browser');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final String fileName = (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
          ? suggestedFileName
          : 'voucher_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String savePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      await OpenFile.open(savePath);
      showScaffold(context: context, message: 'PDF downloaded');
    } catch (e) {
      debugPrint('[ZATCA][PDF] ERROR while downloading/opening: '+e.toString());
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      showScaffoldError(context: context, message: 'Failed to open PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                const SizedBox(height: 20),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Customer Voucher List",
              style: buildCustomStyle(FontWeightManager.semiBold,
                  FontSize.s20, 0.30, ColorManager.textColor),
            ),
            CustomRoundButton(
              title: "Create Voucher",
              fct: () {
                Get.find<SideBarController>().index.value = 71; // Create Voucher Screen
              },
              fontSize: FontSize.s12,
              height: 45,
              width: 150,
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // First row of search fields
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerNameSearch(),
              const SizedBox(width: 10),
              _buildVoucherNumberSearch(),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildTypeFilter(),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildStatusFilter(),
              ),
            ],
          ),
        ),
        // Second row with reset button
        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: CustomRoundButton(
                  title: "Reset",
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: resetSearch,
                  height: 45,
                  width: 150,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerNameSearch() {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Customer Name",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: searchTextController,
              onChanged: (value) => searchVouchers(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Customer Name",
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

  Widget _buildVoucherNumberSearch() {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Voucher No",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 8),
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
                hintText: "Voucher No",
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Type",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<CustomerVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> typeOptions = voucherProvider.getTypeOptions();

              return BuildDropDownWithSearch<String>(
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Status",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<CustomerVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> statusOptions = voucherProvider.getStatusOptions();

              return BuildDropDownWithSearch<String>(
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
      child: Consumer<CustomerVoucherProvider>(
        builder: (context, voucherProvider, child) {
          final isLoading = voucherProvider.isLoading;
          final voucherList = voucherProvider.voucherListDetails;

          return Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : BuildBoxShadowContainer(
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
                                columnWidths: {
                                  0: const FlexColumnWidth(
                                      1.4), // Voucher Number
                                  1: const FlexColumnWidth(
                                      1.6), // Customer Name
                                  2: const FlexColumnWidth(0.9), // Type
                                  3: const FlexColumnWidth(1.3), // Voucher Date
                                  4: const FlexColumnWidth(1.3), // Due Date
                                  5: const FlexColumnWidth(
                                      1.0), // Payment Method
                                  6: const FlexColumnWidth(0.9), // Amount
                                  7: const FlexColumnWidth(0.9), // Status
                                  8: FlexColumnWidth(
                                      MediaQuery.of(context).size.width < 900
                                          ? 2.2
                                          : 1.5),
                                },
                                border: null,
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  TableRow(
                                    children: [
                                      _buildTableHeader("Voucher Number"),
                                      _buildTableHeader("Customer Name"),
                                      _buildTableHeader("Type"),
                                      _buildTableHeader("Voucher Date"),
                                      _buildTableHeader("Due Date"),
                                      _buildTableHeader("Payment Method"),
                                      _buildTableHeader("Amount"),
                                      _buildTableHeader("Status"),
                                      _buildTableHeader("Action"),
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
                                      ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.stylus,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                                  child: voucherList == null ||
                                          voucherList.isEmpty
                                      ? _buildNoVouchersFoundUI()
                                      : SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
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
                                                  MediaQuery.of(context)
                                                              .size
                                                              .width <
                                                          900
                                                      ? 2.2
                                                      : 1.5),
                                            },
                                            border: null,
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            children: voucherList
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final int index = entry.key;
                                              final voucher = entry.value;
                                              return TableRow(
                                                decoration: BoxDecoration(
                                                  color: index % 2 == 0
                                                      ? Colors.white
                                                      : Colors.grey
                                                          .withOpacity(0.1),
                                                ),
                                                children: [
                                                  _buildTableCell(
                                                      voucher.voucherNumber),
                                                  _buildTableCell(voucher
                                                      .customer.user.name
                                                      .toString()),
                                                  _buildTableCell(voucher.type),
                                                  _buildTableCell(
                                                      voucher.voucherDate),
                                                  _buildTableCell(
                                                      voucher.dueDate),
                                                  _buildTableCell(
                                                      voucher.paymentMethod),
                                                  _buildTableCell(
                                                      '₹${voucher.amount}'),
                                                  Center(
                                                    child: _buildStatusChip(
                                                        voucher.status),
                                                  ),
                                                  Center(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const SizedBox(
                                                              width: 8),
                                                          BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child: IconButton(
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
                                                                  _showVoucherDetails(
                                                                      voucher),
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 36,
                                                                minHeight: 36,
                                                              ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                            ),
                                                          ),
                                                          BuildBoxShadowContainer(
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.print,
                                                                size: 18,
                                                                color: ColorManager
                                                                    .kPrimaryColor
                                                                    .withOpacity(
                                                                        0.9),
                                                              ),
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            CustomerVoucherPrintPage(
                                                                      voucher:
                                                                          voucher,
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
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                            ),
                                                          ),
                                                          BuildBoxShadowContainer(
                                                            margin: const EdgeInsets.only(left: 5, right: 5),
                                                            circleRadius: 5,
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.more_vert,
                                                                size: 18,
                                                                color: ColorManager.kPrimaryColor.withOpacity(0.9),
                                                              ),
                                                              onPressed: () => _showVoucherActionsSheet(voucher),
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<CustomerVoucherProvider>(
        builder: (context, voucherProvider, child) {
      debugPrint(
          "Building pagination controls: currentPage=${voucherProvider.currentPage}, totalPages=${voucherProvider.totalPages}");
      return pagination.PaginationControl(
        currentPage: voucherProvider.currentPage,
        totalPages: voucherProvider.totalPages,
        onPageChanged: (int page) {
          debugPrint("Page changed to: $page");
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
            'No vouchers found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
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

  void _showVoucherDetails(CustomerVoucher voucher) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width / 1.5,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voucher Items Details',
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s24,
                        0.36,
                        Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Voucher Header Info
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Voucher Number', voucher.voucherNumber),
                              _buildDetailRow('Customer Name', voucher.customer.user.name),
                              _buildDetailRow('Customer Phone', voucher.customer.user.phone),
                              _buildDetailRow('Type', voucher.type),
                              _buildDetailRow('Voucher Date', voucher.voucherDate),
                              _buildDetailRow('Due Date', voucher.dueDate),
                              _buildDetailRow('Status', voucher.status),
                              _buildDetailRow('Payment Method', voucher.paymentMethod),
                            ],
                          ),
                        ),
                        const Divider(height: 2),
                        const SizedBox(height: 20),
                        // Items Table
                        Text(
                          'Voucher Items',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s16,
                            0.27,
                            Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  _buildTableHeaderCell('VOUCHER'),
                                  _buildTableHeaderCell('ITEM NAME'),
                                  _buildTableHeaderCell('QUANTITY'),
                                  _buildTableHeaderCell('UNIT AMOUNT'),
                                  _buildTableHeaderCell('TAX'),
                                  _buildTableHeaderCell('TOTAL AMOUNT'),
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
                        const SizedBox(height: 24),
                        // Grand Total
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Grand Total:',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${voucher.amount}',
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
        );
      },
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
          ColorManager.kPrimaryColor,
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
