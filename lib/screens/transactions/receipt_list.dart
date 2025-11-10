import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'create_receipt_modal.dart';

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
  String? selectedStatus;
  String? paymentMethod;

  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadReceipts();
    });
  }

  Future<void> loadReceipts() async {
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

      // Load all receipts for local pagination
      await Provider.of<InvoiceProvider>(context, listen: false)
          .loadAllReceipts(accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      debugPrint("Error loading receipts: $error");
      showScaffold(
          context: context, message: "Error fetching receipts: $error");
    }
  }

  Future<void> refreshReceipts() async {
    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
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
          context: context, message: "Error refreshing receipts: $error");
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
        page: 1);
  }

  void resetSearch() {
    setState(() {
      searchTextController.clear();
      receiptNumberController.clear();
      paymentReferenceController.clear();
      phoneController.clear();
      emailController.clear();
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
                _buildHeader(size),
                const SizedBox(height: 15),
                _buildSearchBar(size),
                const SizedBox(height: 15),
                Container(
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
          "Receipt List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: "Create Receipt",
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
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeChip(String paymentMethod) {
    // Check if multiple payment methods (contains comma or multiple methods)
    bool isMixed = paymentMethod.contains(',') || 
                   paymentMethod.contains('CASH') && paymentMethod.contains('CARD') ||
                   paymentMethod.contains('CASH') && paymentMethod.contains('UPI') ||
                   paymentMethod.contains('CARD') && paymentMethod.contains('UPI');
    
    String displayText = isMixed ? 'Mixed' : 'Invoice Payment';
    Color backgroundColor = isMixed 
        ? Colors.orange.withOpacity(0.1) 
        : Colors.blue.withOpacity(0.1);
    Color textColor = isMixed ? Colors.orange : Colors.blue;

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

  Widget _buildSearchBar(Size size) {
    return Column(
      children: [
        // First row with exactly 4 fields
        SizedBox(
          height: 90,
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

        // Second row with the 5th field and reset button
        SizedBox(
          height: 90,
          child: Row(
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

              // Eighth field - Reset Button

              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10.0, top: 42),
                  child: CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: resetSearch,
                    height: 45,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Phone",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: phoneController,
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Phone Number",
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

  Widget _buildEmailSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Email",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: emailController,
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Email Address",
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

// Update all field widgets to use full width
  Widget _buildReceiptNumberSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Receipt Number",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity, // Take full available width
            circleRadius: 7,
            child: TextFormField(
              controller: receiptNumberController,
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Receipt No.",
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

  Widget _buildPaymentReferenceSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Payment Reference",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(height: 8),
          BuildBoxShadowContainer(
            circleRadius: 7,
            height: 45,
            width: double.infinity, // Take full available width
            child: TextFormField(
              controller: paymentReferenceController,
              onChanged: (value) {
                searchReceipts();
              },
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Reference No.",
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
          Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              List<String> statusOptions =
                  invoiceProvider.getReceiptStatusOptions();

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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Payment Method",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<InvoiceProvider>(
            builder: (context, invoiceProvider, child) {
              List<String> paymentMethodOptions =
                  invoiceProvider.getPaymentMethodOptions();

              return BuildDropDownWithSearch<String>(
                title: null,
                showName: false,
                hintText: 'All Payment',
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Name",
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.27, Colors.black.withOpacity(0.6)),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity, // Take full available width
            circleRadius: 7,
            child: TextFormField(
              controller: searchTextController,
              onChanged: (value) {
                searchReceipts();
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

  void _showReceiptDetails(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt Payment Details',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Two-column layout for main details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoField('Receipt Number:', receipt.receiptNumber),
                        const SizedBox(height: 24),
                        _buildInfoField('Amount:', receipt.amount),
                        const SizedBox(height: 24),
                        _buildInfoField('Status:', receipt.receiptStatus),
                        const SizedBox(height: 24),
                        _buildInfoField('Payment Reference:', receipt.paymentReference),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoField('Customer:', receipt.customer.user.name),
                        const SizedBox(height: 24),
                        _buildInfoField('Company:', receipt.company?.name ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Payment details table
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'DATE',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'INVOICE',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'PAYMENT METHOD',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'STATUS',
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'PAID AMOUNT',
                                textAlign: TextAlign.right,
                                style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s12,
                                  0.18,
                                  Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Table rows
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildPaymentRow(
                              DateHelper.formatDate(receipt.createdAt),
                              receipt.paymentReference.isNotEmpty 
                                  ? receipt.paymentReference 
                                  : 'General Payment',
                              receipt.paymentMethod,
                              receipt.receiptStatus,
                              receipt.amount,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Summary section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Balance:',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s14,
                                      0.21,
                                      Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  Text(
                                    receipt.customer.balance ?? '0',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s14,
                                      0.21,
                                      Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Grand Total:',
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s14,
                                      0.21,
                                      Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  Text(
                                    receipt.amount,
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s14,
                                      0.21,
                                      Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Close button
              Align(
                alignment: Alignment.centerLeft,
                child: CustomRoundButton(
                  title: "Close",
                  boxColor: Colors.white,
                  textColor: Colors.black87,
                  borderColor: Colors.grey.shade300,
                  fct: () => Navigator.pop(context),
                  height: 40,
                  width: 100,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.21,
            Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaymentRow(
    String date,
    String invoice,
    String paymentMethod,
    String status,
    String amount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.19,
                Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              invoice,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.19,
                Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              paymentMethod,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.19,
                Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              status,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.19,
                Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.19,
                Colors.black87,
              ),
            ),
          ),
        ],
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
                          6: FlexColumnWidth(1.0), // Action
                        },
                        border: null,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              _buildTableHeader("Receipt Number"),
                              _buildTableHeader("Customer Name"),
                              _buildTableHeader("Amount"),
                              _buildTableHeader("Type"),
                              _buildTableHeader("Status"),
                              _buildTableHeader("Payment Reference"),
                              _buildTableHeader("Action"),
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
                                    'No receipts available',
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
                                      5: FlexColumnWidth(2.0), // Payment Reference
                                      6: FlexColumnWidth(1.0), // Action
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
                                            _buildTableCell(
                                                receipt.receiptNumber),
                                            _buildTableCell(receipt
                                                .customer.user.name
                                                .toString()),
                                            _buildTableCell(receipt.amount),
                                            Center(
                                                child: _buildTypeChip(
                                                    receipt.paymentMethod)),
                                            Center(
                                                child: _buildStatusChip(
                                                    receipt.receiptStatus)),
                                            _buildTableCell(
                                                receipt.paymentReference),
                                            Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: BuildBoxShadowContainer(
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
                                                    // onPressed: () {
                                                    //   String? token = Provider.of<AuthModel>(context, listen: false).token;
                                                    //   InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                                                    //   invoiceProvider.callDetailsOfReceipt(
                                                    //       id: receipt.id, accessToken: token ?? "");
                                                    //   sideBarController.index.value = 48;
                                                    // },
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
