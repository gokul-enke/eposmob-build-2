import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class CompanyAccountsScreen extends StatefulWidget {
  const CompanyAccountsScreen({super.key});

  @override
  State<CompanyAccountsScreen> createState() => _CompanyAccountsScreenState();
}

class _CompanyAccountsScreenState extends State<CompanyAccountsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  String? selectedPaymentMethod;
  String? selectedType;
  String? selectedStatus;
  bool isLoading = false;

  // Company accounts data - will be populated from API
  List<CompanyAccountData> accountsData = [];

  @override
  void initState() {
    super.initState();
    loadAccountsData();
  }

  Future<void> loadAccountsData() async {
    setState(() {
      isLoading = true;
    });
    try {
      // TODO: Implement actual API call to fetch company accounts
      // CompanyAccountProvider provider = Provider.of<CompanyAccountProvider>(context, listen: false);
      // await provider.fetchCompanyAccounts(context);
      // setState(() {
      //   accountsData = provider.companyAccounts;
      // });
    } catch (error) {
      debugPrint('Error loading company accounts: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void searchAccounts() {
    // TODO: Implement actual search/filter functionality
    // Apply filters based on:
    // - fromDateController.text
    // - toDateController.text
    // - selectedPaymentMethod
    // - selectedType
    // - selectedStatus
    debugPrint(
        "Searching with filters - From: ${fromDateController.text}, To: ${toDateController.text}, Payment: $selectedPaymentMethod, Type: $selectedType, Status: $selectedStatus");
    loadAccountsData();
  }

  void resetFilters() {
    setState(() {
      fromDateController.clear();
      toDateController.clear();
      selectedPaymentMethod = null;
      selectedType = null;
      selectedStatus = null;
    });
    loadAccountsData();
  }

  // Date selection method
  Future<void> _selectDate(BuildContext context,
      {required bool isFromDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorManager.kPrimaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
            cardColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      if (isFromDate) {
        fromDateController.text = formattedDate;
      } else {
        toDateController.text = formattedDate;
      }
      searchAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadAccountsData,
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
                _buildFilters(size),
                const SizedBox(height: 20),
                _buildAccountsTable(),
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
          "Company Accounts",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        CustomRoundButton(
          title: "New Company Account",
          fct: () {
            sideBarController.index.value =
                60; // Navigate to Add Company Account screen
          },
          fontSize: 12,
          height: 45,
          width: 200,
        ),
      ],
    );
  }

  Widget _buildFilters(Size size) {
    return Column(
      children: [
        // First row: From Date, To Date, Payment Method, Type
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildFromDateFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildToDateFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildPaymentMethodFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildTypeFilter()),
            ],
          ),
        ),
        // Second row: Status, Empty spaces, Reset Button
        SizedBox(
          height: 90,
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildStatusFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: Container()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: Container()),
              const SizedBox(width: 15),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42),
                  child: CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: resetFilters,
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

  Widget _buildFromDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "From Date",
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
            controller: fromDateController,
            onTap: () => _selectDate(context, isFromDate: true),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "DD/MM/YYYY",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "To Date",
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
            controller: toDateController,
            onTap: () => _selectDate(context, isFromDate: false),
            readOnly: true,
            cursorColor: ColorManager.kPrimaryColor,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.18, ColorManager.textColor),
            decoration: decoration.copyWith(
              hintText: "DD/MM/YYYY",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              prefixIcon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodFilter() {
    return Column(
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
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedPaymentMethod,
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "All Methods",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  "All Methods",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Cash",
                child: Text(
                  "Cash",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Bank Transfer",
                child: Text(
                  "Bank Transfer",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "UPI",
                child: Text(
                  "UPI",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Credit Card",
                child: Text(
                  "Credit Card",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedPaymentMethod = value;
              });
              searchAccounts();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilter() {
    return Column(
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
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedType,
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "All Types",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  "All Types",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Income",
                child: Text(
                  "Income",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Expense",
                child: Text(
                  "Expense",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedType = value;
              });
              searchAccounts();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
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
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: decoration.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              hintText: "All Status",
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s10, 0.18, ColorManager.textColor),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  "All Status",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Completed",
                child: Text(
                  "Completed",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Pending",
                child: Text(
                  "Pending",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
              DropdownMenuItem(
                value: "Failed",
                child: Text(
                  "Failed",
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.18, ColorManager.textColor),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedStatus = value;
              });
              searchAccounts();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsTable() {
    return Expanded(
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
                  // Table header
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
                        0: FlexColumnWidth(2.0), // Name
                        1: FlexColumnWidth(1.8), // Payment Method Type
                        2: FlexColumnWidth(1.2), // Type
                        3: FlexColumnWidth(1.5), // Received Amount
                        4: FlexColumnWidth(1.5), // Sent Amount
                        5: FlexColumnWidth(1.2), // Status
                        6: FlexColumnWidth(1.0), // Action
                      },
                      children: [
                        TableRow(
                          children: [
                            _buildTableHeader("Name"),
                            _buildTableHeader("Payment Method Type"),
                            _buildTableHeader("Type"),
                            _buildTableHeader("Received Amount"),
                            _buildTableHeader("Sent Amount"),
                            _buildTableHeader("Status"),
                            _buildTableHeader("Action"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Table body
                  Expanded(
                    child: accountsData.isEmpty
                        ? _buildNoDataFoundUI()
                        : SingleChildScrollView(
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.0),
                                1: FlexColumnWidth(1.8),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(1.5),
                                4: FlexColumnWidth(1.5),
                                5: FlexColumnWidth(1.2),
                                6: FlexColumnWidth(1.0),
                              },
                              children:
                                  accountsData.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final account = entry.value;
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey.withOpacity(0.1),
                                  ),
                                  children: [
                                    _buildTableCell(account.name),
                                    _buildTableCell(account.paymentMethodType),
                                    Center(child: _buildTypeChip(account.type)),
                                    _buildTableCell(
                                        "₹${account.receivedAmount.toStringAsFixed(2)}"),
                                    _buildTableCell(
                                        "₹${account.sentAmount.toStringAsFixed(2)}"),
                                    Center(
                                        child:
                                            _buildStatusChip(account.status)),
                                    Center(
                                      child: IconButton(
                                        icon: Icon(Icons.visibility,
                                            size: 18,
                                            color: ColorManager.kPrimaryColor),
                                        onPressed: () =>
                                            _showAccountDetails(account),
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
            ),
    );
  }

  Widget _buildNoDataFoundUI() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.7)),
          const SizedBox(height: 15),
          Text('No company accounts found',
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s18,
                  0.27, ColorManager.textColor)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(title,
          textAlign: TextAlign.center,
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18,
              ColorManager.kPrimaryColor)),
    );
  }

  TableCell _buildTableCell(String content) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(content,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
                FontWeightManager.medium, FontSize.s9, 0.13, Colors.black)),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color backgroundColor = type.toLowerCase() == 'income'
        ? Colors.green.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);
    Color textColor =
        type.toLowerCase() == 'income' ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Text(type.toUpperCase(),
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      default:
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showAccountDetails(CompanyAccountData account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Account Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${account.name}'),
            Text('Payment Method: ${account.paymentMethodType}'),
            Text('Type: ${account.type}'),
            Text(
                'Received Amount: ₹${account.receivedAmount.toStringAsFixed(2)}'),
            Text('Sent Amount: ₹${account.sentAmount.toStringAsFixed(2)}'),
            Text('Status: ${account.status}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }
}

// Data model for Company Account
class CompanyAccountData {
  final String name;
  final String paymentMethodType;
  final String type;
  final double receivedAmount;
  final double sentAmount;
  final String status;

  CompanyAccountData({
    required this.name,
    required this.paymentMethodType,
    required this.type,
    required this.receivedAmount,
    required this.sentAmount,
    required this.status,
  });
}
