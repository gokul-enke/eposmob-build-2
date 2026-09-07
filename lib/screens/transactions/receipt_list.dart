import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart' as new_dialog;

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'create_receipt_modal.dart';
import 'widgets/common_details_dialog.dart';
import 'widgets/share_helper.dart';
import 'receipt_list_mobile.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController receiptNumberController = TextEditingController();
  final TextEditingController paymentReferenceController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedStatus;
  String? paymentMethod;

  final FocusNode receiptNoFocusNode = FocusNode();
  final FocusNode referenceNoFocusNode = FocusNode();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode statusFocusNode = FocusNode();
  final FocusNode paymentMethodFocusNode = FocusNode();

  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadReceipts();
    });
  }

  @override
  void dispose() {
    searchTextController.dispose();
    receiptNumberController.dispose();
    paymentReferenceController.dispose();
    phoneController.dispose();
    emailController.dispose();
    dateFromController.dispose();
    dateToController.dispose();
    receiptNoFocusNode.dispose();
    referenceNoFocusNode.dispose();
    nameFocusNode.dispose();
    phoneFocusNode.dispose();
    emailFocusNode.dispose();
    statusFocusNode.dispose();
    paymentMethodFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadReceipts() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt.auth_token_missing'.tr)),
        );
        return;
      }

      // Load all receipts for local pagination
      await Provider.of<InvoiceProvider>(context, listen: false)
          .loadAllReceipts(accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      debugPrint("Error loading receipts: $error");
      showScaffold(
          context: context, message: 'receipt.error_fetching_receipts'.tr.replaceAll('@error', error.toString()));
    }
  }

  Future<void> refreshReceipts() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt.auth_token_missing'.tr)),
        );
        return;
      }

      // Reload all receipts
      await Provider.of<InvoiceProvider>(context, listen: false)
          .loadAllReceipts(accessToken);
      setState(() {});
    } catch (error) {
      debugPrint("Error refreshing receipts: $error");
      showScaffold(
          context: context, message: 'receipt.error_refreshing_receipts'.tr.replaceAll('@error', error.toString()));
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
      searchReceipts();
    }
  }

  void searchReceipts() {
    final String searchText = searchTextController.text.trim();
    debugPrint("Searching for receipts with name: '$searchText'");

    InvoiceProvider provider =
        Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyReceiptFilters(
        name: searchText,
        receiptNumber: receiptNumberController.text,
        paymentReference: paymentReferenceController.text,
        receiptStatus: selectedStatus,
        phone: phoneController.text,
        email: emailController.text,
        paymentMethod: paymentMethod,
        dateFrom: dateFromController.text.isEmpty
            ? null
            : dateFromController.text,
        dateTo: dateToController.text.isEmpty
            ? null
            : dateToController.text,
        page: 1);
  }

  void resetSearch() {
    debugPrint("Resetting all filters");
    setState(() {
      searchTextController.clear();
      receiptNumberController.clear();
      paymentReferenceController.clear();
      phoneController.clear();
      emailController.clear();
      dateFromController.clear();
      dateToController.clear();
      selectedStatus = null;
      paymentMethod = null;
    });

    Provider.of<InvoiceProvider>(context, listen: false).resetReceiptFilters();
  }

  Future<void> refreshData() async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    await Provider.of<InvoiceProvider>(context, listen: false)
        .loadAllReceipts(accessToken);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              return ReceiptMobileView(
                receipts: invoiceProvider.getListReceipt ?? const <Receipt>[],
                isLoading: invoiceProvider.isLoading,
                receiptNumberController: receiptNumberController,
                paymentReferenceController: paymentReferenceController,
                searchTextController: searchTextController,
                phoneController: phoneController,
                emailController: emailController,
                receiptNoFocusNode: receiptNoFocusNode,
                referenceNoFocusNode: referenceNoFocusNode,
                nameFocusNode: nameFocusNode,
                phoneFocusNode: phoneFocusNode,
                emailFocusNode: emailFocusNode,
                selectedStatus: selectedStatus,
                selectedPaymentMethod: paymentMethod,
                statusOptions: invoiceProvider.getReceiptStatusOptions()
                    .where((s) => s != 'All Status').toList(),
                paymentMethodOptions: invoiceProvider.getPaymentMethodOptions()
                    .where((m) => m != 'All Payment Methods').toList(),
                onSearchChanged: searchReceipts,
                onReset: resetSearch,
                onStatusChanged: (v) {
                  setState(() => selectedStatus = v);
                  searchReceipts();
                },
                onPaymentMethodChanged: (v) {
                  setState(() => paymentMethod = v);
                  searchReceipts();
                },
                onViewDetails: _showReceiptDetails,
                onShare: (receipt) => ShareHelper.showShareReceiptSheet(
                  context: context,
                  receipt: receipt,
                ),
                currentPage: invoiceProvider.receiptCurrentPage,
                totalPages: invoiceProvider.receiptTotalPages,
                onPageChanged: (page) => invoiceProvider.goToReceiptPage(page),
                onCreateReceipt: () async {
                  final result = await showCreateReceiptModal(context, size);
                  if (result == true) await refreshReceipts();
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
            child: ListView(
              children: [
                _buildHeader(size),
                const SizedBox(height: 10),
                _buildSearchBar(size),
                // const SizedBox(height: 10),
                SizedBox(
                  height: size.height * 0.6,
                  child: _buildReceiptTable(),
                ),
                const SizedBox(height: 15),
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
          'receipt.list_title'.tr,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: 'receipt.create_receipt_button'.tr,
          fct: () async {
            final result = await showCreateReceiptModal(context, size);
            if (result == true) {
              // Refresh the list if receipt was created successfully
              await refreshReceipts();
            }
          },
          width: 200,
          height: 45,
          fontSize: 12,
          radius: 5,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'paid':
      case 'PAID':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'FAIL':
      case 'FAILED':
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
        UiCodeLabels.status(status),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeChip(Receipt receipt) {
    final payments = receipt.receiptPayments;
    final int invoiceCount = payments.where((p) => p.invoiceId != null).length;
    final int generalCount = payments.where((p) => p.invoiceId == null).length;

    String displayText;
    Color backgroundColor;
    Color textColor;

    if (invoiceCount > 0 && generalCount > 0) {
      displayText = 'receipt.type_mixed'.tr;
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
    } else if (invoiceCount > 0) {
      displayText = 'receipt.type_invoice_payment'.tr;
      backgroundColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue;
    } else {
      displayText = 'receipt.type_general_payment'.tr;
      backgroundColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
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
                hintText: 'receipt.date_range_hint'.tr,
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
                hintText: 'receipt.date_range_hint'.tr,
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

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // First row with exactly 4 fields
        SizedBox(
          height: 55,
          child: Row(
            children: [
              // first field
              Expanded(
                flex: 1,
                child: _buildReceiptNumberSearch(),
              ),

              // Second field
              Expanded(
                flex: 1,
                child: _buildPaymentReferenceSearch(),
              ),

              // Third field
              Expanded(
                flex: 1,
                child: _buildSearchTextField(),
              ),

              // Fourth field
              Expanded(
                flex: 1,
                child: _buildPhoneSearch(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Second row with 3 fields
        SizedBox(
          height: 55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fifth field
              Expanded(
                flex: 1,
                child: _buildEmailSearch(),
              ),

              // sixth field
              Expanded(
                flex: 1,
                child: _buildStatusFilter(),
              ),

              //seventh field
              Expanded(
                flex: 1,
                child: _buildPaymentMethodSearch(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Third row with date range search and reset button
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
              Expanded(
                flex: 1,
                child: CustomRoundButton(
                  title: 'general.reset'.tr,
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: resetSearch,
                  height: 45,
                  width: double.infinity,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: phoneController,
              focusNode: phoneFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: 'receipt.phone_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: emailController,
            focusNode: emailFocusNode,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            onChanged: (value) {
              searchReceipts();
            },
            cursorColor: ColorManager.kPrimaryColor,
            cursorHeight: 13,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: 'receipt.email_hint'.tr,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIconColor: Colors.black,
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
                borderRadius: BorderRadius.circular(7),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ],
    );
  }

// Update all field widgets to use full width
  Widget _buildReceiptNumberSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity, // Take full available width
          circleRadius: 7,
          child: TextFormField(
            controller: receiptNumberController,
            focusNode: receiptNoFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            onChanged: (value) {
              searchReceipts();
            },
            cursorColor: ColorManager.kPrimaryColor,
            cursorHeight: 13,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: 'receipt.receipt_no_hint'.tr,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIconColor: Colors.black,
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
                borderRadius: BorderRadius.circular(7),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentReferenceSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuildBoxShadowContainer(
            circleRadius: 7,
            height: 45,
            width: double.infinity, // Take full available width
            child: TextFormField(
              controller: paymentReferenceController,
              focusNode: referenceNoFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: 'receipt.reference_no_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
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
          Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              List<String> statusOptions =
                  invoiceProvider.getReceiptStatusOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: statusFocusNode,
                title: null,
                showName: false,
                hintText: 'receipt.hint_all_status'.tr,
                value: selectedStatus,
                items: statusOptions
                    .where((status) => status != "All Status")
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedStatus = newValue;
                  });
                  searchReceipts();
                },
                displayText: (status) => status,
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              List<String> paymentMethodOptions =
                  invoiceProvider.getPaymentMethodOptions();

              return BuildDropDownWithSearch<String>(
                focusNode: paymentMethodFocusNode,
                title: null,
                showName: false,
                hintText: 'receipt.hint_all_payment'.tr,
                value: paymentMethod,
                items: paymentMethodOptions
                    .where((method) => method != "All Payment Methods")
                    .toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    paymentMethod = newValue;
                  });
                  searchReceipts();
                },
                displayText: (method) => method,
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              );
            },
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
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity, // Take full available width
            circleRadius: 7,
            child: TextFormField(
              controller: searchTextController,
              focusNode: nameFocusNode,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: 'receipt.name_hint'.tr,
                hintStyle: buildCustomStyle(FontWeightManager.medium,
                    FontSize.s10, 0.18, ColorManager.textColor),
                prefixIconColor: Colors.black,
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptDetails(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'receipt.receipt_details_title'.tr,
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('receipt.field_receipt_number'.tr, receipt.receiptNumber, copyable: true),
            CommonDetailsDialog.buildKeyValueRow('receipt.field_customer'.tr, receipt.customer.user.name),
            CommonDetailsDialog.buildKeyValueRow('receipt.field_amount'.tr, receipt.amount),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('receipt.field_company'.tr, receipt.company.name),
            CommonDetailsDialog.buildKeyValueRow('receipt.field_status'.tr, receipt.receiptStatus),
            CommonDetailsDialog.buildKeyValueRow('receipt.field_payment_reference'.tr, receipt.paymentReference),
          ],
        ],
        sectionTitle: 'receipt.payments_section_title'.tr,
        tableContent: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_date'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt.col_invoice'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.col_method'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'receipt.field_amount'.tr,
                      textAlign: TextAlign.right,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.15,
                        ColorManager.kTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            ...receipt.receiptPayments.map((p) {
              final dateStr = DateHelper.formatDate(
                DateTime.tryParse(p.paymentDate) ?? receipt.createdAt,
              );
              final invStr = p.invoiceId != null
                  ? 'INV-${p.invoiceId}'
                  : (p.description?.isNotEmpty == true
                      ? p.description!
                      : 'receipt.type_general_payment'.tr);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dateStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        invStr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paymentMethod,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.paidAmount,
                        textAlign: TextAlign.right,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s13,
                          0.19,
                          ColorManager.kTitleTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
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
              value.isNotEmpty ? value : 'general.na'.tr,
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
          ColorManager.kTitleTextColor,
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

  Widget _buildReceiptTable() {
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        final isLoading = invoiceProvider.isLoading;
        final receiptList = invoiceProvider.getListReceipt;

        return isLoading
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
                        columnWidths: const {
                          0: FlexColumnWidth(1.5), // Receipt Number
                          1: FlexColumnWidth(2.0), // Customer Name
                          2: FlexColumnWidth(1.5), // Amount
                          3: FlexColumnWidth(1.5), // Type
                          4: FlexColumnWidth(1.5), // Status
                          5: FlexColumnWidth(2.0), // Payment Reference
                          6: FlexColumnWidth(1.5), // Action
                        },
                        border: null,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildTableHeader('receipt.col_receipt_number'.tr),
                              _buildTableHeader('receipt.col_customer_name'.tr),
                              _buildTableHeader('receipt.field_amount'.tr),
                              _buildTableHeader('receipt.col_type'.tr),
                              _buildTableHeader('receipt.col_status'.tr),
                              _buildTableHeader('receipt.col_payment_reference'.tr),
                              _buildTableHeader('receipt.col_action'.tr),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Scrollable table body
                    Expanded(
                      child: receiptList == null || receiptList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 60,
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'receipt.no_receipts_available'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s18,
                                      0.27,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'receipt.try_adjusting_search'.tr,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.20,
                                      Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : MouseRegion(
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
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  scrollDirection: Axis.vertical,
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.5), // Receipt Number
                                      1: FlexColumnWidth(2.0), // Customer Name
                                      2: FlexColumnWidth(1.5), // Amount
                                      3: FlexColumnWidth(1.5), // Type
                                      4: FlexColumnWidth(1.5), // Status
                                      5: FlexColumnWidth(
                                          2.0), // Payment Reference
                                      6: FlexColumnWidth(1.5), // Action
                                    },
                                    border: null,
                                    defaultVerticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    children: [
                                      ...receiptList
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final int index = entry.key;
                                        final receipt = entry.value;
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            color: index % 2 == 0
                                                ? Colors.white
                                                : Colors.grey.withOpacity(0.1),
                                          ),
                                          children: [
                                            TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      receipt.receiptNumber,
                                                      textAlign:
                                                          TextAlign.center,
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
                                                                text: receipt
                                                                    .receiptNumber));
                                                        new_dialog.showScaffold(
                                                          context: context,
                                                          message:
                                                              'receipt.copied_to_clipboard'.tr,
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
                                                    receipt.customer.user.name.toString(),
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
                                            _buildTableCell(receipt.amount),
                                            Center(
                                                child: _buildTypeChip(receipt)),
                                            Center(
                                                child: _buildStatusChip(
                                                    receipt.receiptStatus)),
                                            TableCell(
                                              verticalAlignment:
                                                  TableCellVerticalAlignment
                                                      .middle,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      receipt.paymentReference,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: buildCustomStyle(
                                                        FontWeightManager.medium,
                                                        FontSize.s9,
                                                        0.13,
                                                        Colors.black,
                                                      ),
                                                    ),
                                                    if (receipt.paymentReference.isNotEmpty) ...[
                                                      const SizedBox(width: 6),
                                                      GestureDetector(
                                                        onTap: () {
                                                          Clipboard.setData(
                                                              ClipboardData(
                                                                  text: receipt
                                                                      .paymentReference));
                                                          new_dialog.showScaffold(
                                                            context: context,
                                                            message:
                                                                'receipt.copied_to_clipboard'.tr,
                                                          );
                                                        },
                                                        child: const Icon(
                                                          Icons.copy,
                                                          size: 14,
                                                          color: Colors.black38,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(4.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    BuildBoxShadowContainer(
                                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                                      circleRadius: 5,
                                                      child: IconButton(
                                                        icon: Icon(
                                                          Icons.visibility,
                                                          size: 18,
                                                          color: ColorManager
                                                              .kPrimaryColor
                                                              .withOpacity(0.9),
                                                        ),
                                                        onPressed: () {
                                                          _showReceiptDetails(
                                                              receipt);
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
                                                      margin: const EdgeInsets.symmetric(horizontal: 2),
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
                                                          ShareHelper.showShareReceiptSheet(
                                                            context: context,
                                                            receipt: receipt,
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
                                      }),
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
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        return PaginationControl(
          currentPage: invoiceProvider.receiptCurrentPage,
          totalPages: invoiceProvider.receiptTotalPages,
          onPageChanged: (int page) {
            invoiceProvider.goToReceiptPage(page);
          },
        );
      },
    );
  }
}
