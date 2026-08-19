import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dialog_box.dart' hide showScaffold, showScaffoldError, showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
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
import '../../providers/app_settings_provider.dart';
import '../../providers/customer_voucher_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/customer_voucher_print.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';
import 'customer_voucher_list_mobile.dart'; 

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
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedType;
  String? selectedStatus;

  final FocusNode nameFocusNode = FocusNode();
  final FocusNode voucherNoFocusNode = FocusNode();
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
    searchTextController.dispose();
    voucherNumberController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    nameFocusNode.dispose();
    voucherNoFocusNode.dispose();
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
          SnackBar(content: Text('customer_voucher.auth_token_missing'.tr)),
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
        SnackBar(content: Text('customer_voucher.error_loading_vouchers'.tr.replaceAll('@error', error.toString()))),
      );
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? pickedDate = await showAutoDismissDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: ColorManager.kPrimaryColor,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
      final TimeOfDay resolvedTime = pickedTime ??
          (isFromDate
              ? const TimeOfDay(hour: 0, minute: 0)
              : const TimeOfDay(hour: 23, minute: 59));
      final DateTime fullDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        resolvedTime.hour,
        resolvedTime.minute,
      );
      final formattedDateTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
      setState(() {
        if (isFromDate) {
          dateFromController.text = formattedDateTime;
        } else {
          dateToController.text = formattedDateTime;
        }
      });
      searchVouchers();
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
      dateFrom: dateFromController.text.isEmpty
          ? null
          : dateFromController.text,
      dateTo: dateToController.text.isEmpty
          ? null
          : dateToController.text,
    );
  }

  void resetSearch() {
    debugPrint("Resetting all filters");
    setState(() {
      searchTextController.clear();
      voucherNumberController.clear();
      dateFromController.clear();
      dateToController.clear();
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
        final appSettings =
            Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings;
        final bool phase2 = appSettings?.zatcaPhase2Enabled ?? false;

        final List<Widget> dynamicItems = [];

        // Always add the Share option
        dynamicItems.add(
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
              child: const Icon(Icons.share, color: ColorManager.kPrimaryColor),
            ),
            title: Text('customer_voucher.share_action'.tr),
            onTap: () {
              Navigator.pop(ctx);
              ShareHelper.showShareCustomerVoucherSheet(
                context: context,
                voucher: voucher,
              );
            },
          ),
        );

        // Only render ZATCA options when Phase 2 is enabled in settings
        if (phase2) {
          dynamicItems.addAll([
            // ZATCA Phase 2 (with PDF download/open)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.withOpacity(0.12),
                child: const Icon(Icons.description, color: Colors.orange),
              ),
              title: Text('customer_voucher.zatca_phase2_action'.tr),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase2SendWithPdf(voucher);
              },
            ),
            // Send Credit Note to ZATCA (no PDF open)
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                child:
                    const Icon(Icons.send, color: ColorManager.kPrimaryColor),
              ),
              title: Text('customer_voucher.send_credit_note_action'.tr),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase2Send(voucher);
              },
            ),
          ]);
        }

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
                Text(
                  'customer_voucher.more_options_title'.tr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ...dynamicItems,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performZatcaPhase2SendWithPdf(CustomerVoucher voucher) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send With PDF] Start for voucher ${voucher.voucherNumber} (ID: ${voucher.id})');
      if (token == null || token.isEmpty) {
        debugPrint(
            '[ZATCA][Phase2 Send With PDF] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(context: context, message: 'customer_voucher.processing_zatca_phase2'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.processing'.tr);

      final provider =
          Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send With PDF] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber =
            (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        }
        showScaffold(
          context: context,
          message: 'customer_voucher.processed_phase2'.tr.replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.process_phase2_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send With PDF] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'customer_voucher.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _performZatcaPhase2Send(CustomerVoucher voucher) async {
    try {
      final String? token =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint(
          '[ZATCA][Phase2 Send] Start for voucher ${voucher.voucherNumber} (ID: ${voucher.id})');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send] ERROR: Missing authentication token');
        showScaffoldError(
            context: context, message: 'customer_voucher.missing_token'.tr);
        return;
      }

      showScaffold(context: context, message: 'customer_voucher.sending_to_zatca'.tr);
      showLoadingOverlay(context, message: 'customer_voucher.sending'.tr);

      final provider =
          Provider.of<CustomerVoucherProvider>(context, listen: false);
      final result = await provider.zatcaPhase2VoucherPrint(
        id: voucher.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send] Response: $result');
      if (result is Map &&
          ((result['status'] == 'success') ||
              (result['success'] == true) ||
              (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String voucherNumber =
            (data['voucher_number']?.toString() ?? voucher.voucherNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        showScaffold(
          context: context,
          message: 'customer_voucher.submitted_to_zatca'.tr.replaceAll('@number', voucherNumber),
        );
      } else {
        final msg = (result is Map ? result['message'] : null) ??
            'customer_voucher.send_to_zatca_failed'.tr;
        debugPrint('[ZATCA][Phase2 Send] ERROR: $msg');
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Send] EXCEPTION: $e');
      showScaffoldError(context: context, message: 'customer_voucher.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _downloadAndOpenPdf(String url,
      {String? suggestedFileName}) async {
    try {
      if (kIsWeb) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
        showScaffold(context: context, message: 'customer_voucher.opened_pdf_browser'.tr);
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final String fileName =
          (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
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
      showScaffold(context: context, message: 'customer_voucher.pdf_downloaded'.tr);
    } catch (e) {
      debugPrint('[ZATCA][PDF] ERROR while downloading/opening: $e');
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      showScaffoldError(context: context, message: 'customer_voucher.failed_open_pdf'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<CustomerVoucherProvider>(
            builder: (context, voucherProvider, child) {
              return CustomerVoucherMobileView(
                vouchers: voucherProvider.voucherListDetails ?? const <CustomerVoucher>[],
                isLoading: voucherProvider.isLoading,
                searchTextController: searchTextController,
                voucherNumberController: voucherNumberController,
                nameFocusNode: nameFocusNode,
                voucherNoFocusNode: voucherNoFocusNode,
                selectedType: selectedType,
                selectedStatus: selectedStatus,
                typeOptions: voucherProvider.getTypeOptions()
                    .where((t) => t != 'All Types').toList(),
                statusOptions: voucherProvider.getStatusOptions()
                    .where((s) => s != 'All Status').toList(),
                onSearchChanged: searchVouchers,
                onReset: resetSearch,
                onTypeChanged: (v) {
                  setState(() => selectedType = v);
                  searchVouchers();
                },
                onStatusChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchVouchers();
                },
                onViewDetails: _showVoucherDetails,
                onShowActions: _showVoucherActionsSheet,
                currentPage: voucherProvider.currentPage,
                totalPages: voucherProvider.totalPages,
                onPageChanged: (page) => voucherProvider.goToPage(page),
                onCreateVoucher: () =>
                    Get.find<SideBarController>().index.value = 71,
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
                // const SizedBox(height: 10),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'customer_voucher.list_title'.tr,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            CustomRoundButton(
              title: 'customer_voucher.create_voucher_button'.tr,
              fct: () {
                Get.find<SideBarController>().index.value =
                    71; // Create Voucher Screen
              },
              fontSize: FontSize.s12,
              height: 45,
              width: 150,
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // First row of search fields
        SizedBox(
          height: 55,
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
        // Second row with date range search and reset button
        SizedBox(
          height: 55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildDateRangeSearch(),
              ),
              const SizedBox(width: 10),
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

  Widget _buildCustomerNameSearch() {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Text(
          //     "Customer Name",
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
              controller: searchTextController,
              onChanged: (value) => searchVouchers(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'customer_voucher.customer_name_hint'.tr,
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
                hintText: 'customer_voucher.voucher_no_hint'.tr,
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
          Consumer<CustomerVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> typeOptions = voucherProvider.getTypeOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: typeFocusNode,
                title: null,
                showName: false,
                hintText: 'customer_voucher.hint_all_types'.tr,
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
          Consumer<CustomerVoucherProvider>(
            builder: (context, voucherProvider, child) {
              List<String> statusOptions = voucherProvider.getStatusOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: statusFocusNode,
                title: null,
                showName: false,
                hintText: 'customer_voucher.hint_all_status'.tr,
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

  Widget _buildDateRangeSearch() {
    return Row(
      children: [
        Expanded(
          child: BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: dateFromController,
              onTap: () => _selectDate(context, isFromDate: true),
              readOnly: true,
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'customer_voucher.date_range_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor.withOpacity(.5)),
                prefixIcon: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
                contentPadding: const EdgeInsets.only(left: 15, top: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: dateToController,
              onTap: () => _selectDate(context, isFromDate: false),
              readOnly: true,
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'customer_voucher.date_range_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor.withOpacity(.5)),
                prefixIcon: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
                contentPadding: const EdgeInsets.only(left: 15, top: 12),
              ),
            ),
          ),
        ),
      ],
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
                                      _buildTableHeader('customer_voucher.col_voucher_number'.tr),
                                      _buildTableHeader('customer_voucher.customer_name_hint'.tr),
                                      _buildTableHeader('customer_voucher.col_type'.tr),
                                      _buildTableHeader('customer_voucher.col_voucher_date'.tr),
                                      _buildTableHeader('customer_voucher.col_due_date'.tr),
                                      _buildTableHeader('customer_voucher.col_payment_method'.tr),
                                      _buildTableHeader('customer_voucher.col_paid_amount'.tr),
                                      _buildTableHeader('customer_voucher.col_status'.tr),
                                      _buildTableHeader('customer_voucher.col_action'.tr),
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
                                                   TableCell(
                                                     verticalAlignment:
                                                         TableCellVerticalAlignment
                                                             .middle,
                                                     child: Padding(
                                                       padding:
                                                           const EdgeInsets.all(
                                                               8.0),
                                                       child: Row(
                                                         mainAxisAlignment:
                                                             MainAxisAlignment
                                                                 .center,
                                                         children: [
                                                           Text(
                                                             voucher
                                                                 .voucherNumber,
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
                                                           const SizedBox(
                                                               width: 6),
                                                           GestureDetector(
                                                             onTap: () {
                                                               Clipboard.setData(
                                                                   ClipboardData(
                                                                       text: voucher
                                                                           .voucherNumber));
                                                               showScaffold(
                                                                 context:
                                                                     context,
                                                                 message:
                                                                     'customer_voucher.voucher_number_copied'.tr,
                                                               );
                                                             },
                                                             child: const Icon(
                                                               Icons.copy,
                                                               size: 14,
                                                               color: Colors
                                                                   .black38,
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
                                                           voucher.customer.user.name.toString(),
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
                                                  _buildTableCell(
                                                      voucher.voucherDate),
                                                  _buildTableCell(
                                                      voucher.dueDate),
                                                  _buildTableCell(
                                                      voucher.paymentMethod),
                                                  _buildTableCell(
                                                      '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${voucher.amount}'),
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
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 5),
                                                            circleRadius: 5,
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons.more_vert,
                                                                size: 18,
                                                                color: ColorManager
                                                                    .kPrimaryColor
                                                                    .withOpacity(
                                                                        0.9),
                                                              ),
                                                              onPressed: () =>
                                                                  _showVoucherActionsSheet(
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
            'customer_voucher.no_vouchers_found'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'customer_voucher.try_adjusting_search'.tr,
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
      builder: (context) => CommonDetailsDialog(
        title: 'customer_voucher.details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_voucher_number'.tr, voucher.voucherNumber, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.customer_name_hint'.tr, voucher.customer.user.name),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.field_customer_phone'.tr, voucher.customer.user.phone, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_type'.tr, voucher.type),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_voucher_date'.tr, voucher.voucherDate),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_due_date'.tr, voucher.dueDate),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_status'.tr, voucher.status),
            CommonDetailsDialog.buildKeyValueRow('customer_voucher.col_payment_method'.tr, voucher.paymentMethod),
          ],
        ],
        sectionTitle: 'customer_voucher.items_section_title'.tr,
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
                      _buildTableHeaderCell('customer_voucher.col_voucher'.tr),
                      _buildTableHeaderCell('customer_voucher.col_item_name'.tr),
                      _buildTableHeaderCell('customer_voucher.col_quantity_upper'.tr),
                      _buildTableHeaderCell('customer_voucher.col_unit_amount_upper'.tr),
                      _buildTableHeaderCell('customer_voucher.col_tax_upper'.tr),
                      _buildTableHeaderCell('customer_voucher.col_total_amount_upper'.tr),
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
                'customer_voucher.grand_total_label'.tr,
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
