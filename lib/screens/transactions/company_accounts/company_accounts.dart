import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/company_accounts.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/transactions/company_accounts/account_details_screen.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class CompanyAccountsScreen extends StatefulWidget {
  const CompanyAccountsScreen({super.key});

  @override
  State<CompanyAccountsScreen> createState() => _CompanyAccountsScreenState();
}

class _CompanyAccountsScreenState extends State<CompanyAccountsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  // Commenting out date filters as dates are not coming from backend
  // final TextEditingController fromDateController = TextEditingController();
  // final TextEditingController toDateController = TextEditingController();
  String? selectedPaymentMethod;
  String? selectedType;
  String? selectedStatus;
  bool isLoading = false;
  bool initLoading = false;

  // Company accounts data - will be populated from API
  // Removed local data model as we'll use provider data

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadAccountsData();
    });
  }

  Future<void> loadAccountsData() async {
    try {
      setState(() {
        initLoading = true;
      });

      CompanyAccountProvider companyAccountProvider =
          Provider.of<CompanyAccountProvider>(context, listen: false);
      SharedPreferenceProvider sharedPrefProvider =
          Provider.of<SharedPreferenceProvider>(context, listen: false);

      String? token = await sharedPrefProvider.getToken();

      debugPrint(
          'Loading company accounts with token: ${token != null ? "Available" : "Missing"}');

      if (token != null) {
        await companyAccountProvider.loadAllCompanyAccounts(token);
        debugPrint('Company accounts API call completed');

        // Check if we have data after the API call
        final accountsList =
            companyAccountProvider.getCompanyAccountsList ?? [];
        debugPrint('Number of accounts loaded: ${accountsList.length}');

        // Handle API error responses (like "no data found")
        if (accountsList.isEmpty && mounted) {
          // Don't show error for "no data found" as it's a valid state
          debugPrint('No company accounts data available');
        }
      } else {
        debugPrint('No access token available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Authentication token missing. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('Error loading company accounts: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  void searchAccounts() {
    // Apply filters using provider
    CompanyAccountProvider companyAccountProvider =
        Provider.of<CompanyAccountProvider>(context, listen: false);

    companyAccountProvider.applyFiltersLocally(
      filterPaymentMethod: selectedPaymentMethod,
      filterType: selectedType,
      filterStatus: selectedStatus,
      page: 1,
    );

    debugPrint(
        "Searching with filters - Payment: $selectedPaymentMethod, Type: $selectedType, Status: $selectedStatus");
  }

  void resetFilters() {
    setState(() {
      // Commenting out date controllers as dates are not from backend
      // fromDateController.clear();
      // toDateController.clear();
      selectedPaymentMethod = null;
      selectedType = null;
      selectedStatus = null;
    });

    // Reset filters in provider
    CompanyAccountProvider companyAccountProvider =
        Provider.of<CompanyAccountProvider>(context, listen: false);
    companyAccountProvider.resetFilters();
  }

  // Commenting out date selection method as dates are not coming from backend
  // Future<void> _selectDate(BuildContext context,
  //     {required bool isFromDate}) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2100),
  //     builder: (BuildContext context, Widget? child) {
  //       return Theme(
  //         data: ThemeData.light().copyWith(
  //           colorScheme: const ColorScheme.light(
  //             primary: ColorManager.kPrimaryColor,
  //             onPrimary: Colors.white,
  //             surface: Colors.white,
  //             onSurface: Colors.black,
  //           ),
  //           dialogBackgroundColor: Colors.white,
  //           cardColor: Colors.white,
  //         ),
  //         child: child!,
  //       );
  //     },
  //   );
  //
  //   if (picked != null) {
  //     final formattedDate =
  //         "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
  //     if (isFromDate) {
  //       fromDateController.text = formattedDate;
  //     } else {
  //       toDateController.text = formattedDate;
  //     }
  //     searchAccounts();
  //   }
  // }

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
        // CustomRoundButton(
        //   title: "New Company Account",
        //   fct: () {
        //     sideBarController.index.value =
        //         60; // Navigate to Add Company Account screen
        //   },
        //   fontSize: 12,
        //   height: 45,
        //   width: 200,
        // ),
      ],
    );
  }

  Widget _buildFilters(Size size) {
    return Column(
      children: [
        // First row: Payment Method, Type (Commented out date filters)
        SizedBox(
          height: 90,
          child: Row(
            children: [
              // Commenting out date filters as dates are not from backend
              // Expanded(flex: 1, child: _buildFromDateFilter()),
              // const SizedBox(width: 15),
              // Expanded(flex: 1, child: _buildToDateFilter()),
              // const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildPaymentMethodFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildTypeFilter()),
              const SizedBox(width: 15),
              Expanded(flex: 1, child: _buildStatusFilter()), // Empty space
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
              ), // Empty space
            ],
          ),
        ),
        // Second row: Status, Empty spaces, Reset Button
        // SizedBox(
        //   height: 90,
        //   child: Row(
        //     children: [
        //       Expanded(flex: 1, child: _buildStatusFilter()),
        //       const SizedBox(width: 15),
        //       Expanded(flex: 1, child: Container()),
        //       const SizedBox(width: 15),
        //       Expanded(flex: 1, child: Container()),
        //       const SizedBox(width: 15),
        //       Expanded(
        //         flex: 1,
        //         child: Padding(
        //           padding: const EdgeInsets.only(top: 42),
        //           child: CustomRoundButton(
        //             title: "Reset",
        //             boxColor: Colors.white,
        //             textColor: ColorManager.kPrimaryColor,
        //             fct: resetFilters,
        //             height: 45,
        //             width: double.infinity,
        //             fontSize: FontSize.s12,
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  // Commenting out date filter methods as dates are not coming from backend
  // Widget _buildFromDateFilter() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.all(8.0),
  //         child: Text(
  //           "From Date",
  //           style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
  //               0.27, Colors.black.withOpacity(0.6)),
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       BuildBoxShadowContainer(
  //         height: 45,
  //         width: double.infinity,
  //         circleRadius: 7,
  //         child: TextFormField(
  //           controller: fromDateController,
  //           onTap: () => _selectDate(context, isFromDate: true),
  //           readOnly: true,
  //           cursorColor: ColorManager.kPrimaryColor,
  //           style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
  //               0.18, ColorManager.textColor),
  //           decoration: decoration.copyWith(
  //             hintText: "DD/MM/YYYY",
  //             hintStyle: buildCustomStyle(FontWeightManager.medium,
  //                 FontSize.s10, 0.18, ColorManager.textColor),
  //             prefixIcon: Container(
  //               padding: const EdgeInsets.all(8),
  //               child: Icon(
  //                 Icons.calendar_today,
  //                 size: 16,
  //                 color: ColorManager.kPrimaryColor,
  //               ),
  //             ),
  //             filled: true,
  //             fillColor: Colors.white,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
  //
  // Widget _buildToDateFilter() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.all(8.0),
  //         child: Text(
  //           "To Date",
  //           style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
  //               0.27, Colors.black.withOpacity(0.6)),
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       BuildBoxShadowContainer(
  //         height: 45,
  //         width: double.infinity,
  //         circleRadius: 7,
  //         child: TextFormField(
  //           controller: toDateController,
  //           onTap: () => _selectDate(context, isFromDate: false),
  //           readOnly: true,
  //           cursorColor: ColorManager.kPrimaryColor,
  //           style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
  //               0.18, ColorManager.textColor),
  //           decoration: decoration.copyWith(
  //             hintText: "DD/MM/YYYY",
  //             hintStyle: buildCustomStyle(FontWeightManager.medium,
  //                 FontSize.s10, 0.18, ColorManager.textColor),
  //             prefixIcon: Container(
  //               padding: const EdgeInsets.all(8),
  //               child: Icon(
  //                 Icons.calendar_today,
  //                 size: 16,
  //                 color: ColorManager.kPrimaryColor,
  //               ),
  //             ),
  //             filled: true,
  //             fillColor: Colors.white,
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

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
        Consumer<CompanyAccountProvider>(
          builder: (context, companyAccountProvider, child) {
            List<String> paymentMethodOptions =
                companyAccountProvider.getPaymentMethodOptions();

            return BuildDropDownWithSearch<String>(
              title: null,
              showName: false,
              hintText: 'All Methods',
              value: selectedPaymentMethod,
              items: paymentMethodOptions
                  .where((method) => method != "All Methods")
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedPaymentMethod = newValue;
                });
                searchAccounts();
              },
              displayText: (method) => method,
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            );
          },
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
        Consumer<CompanyAccountProvider>(
          builder: (context, companyAccountProvider, child) {
            List<String> typeOptions = companyAccountProvider.getTypeOptions();

            return BuildDropDownWithSearch<String>(
              title: null,
              showName: false,
              hintText: 'All Types',
              value: selectedType,
              items: typeOptions.where((type) => type != "All Types").toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedType = newValue;
                });
                searchAccounts();
              },
              displayText: (type) => type,
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            );
          },
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
        Consumer<CompanyAccountProvider>(
          builder: (context, companyAccountProvider, child) {
            List<String> statusOptions =
                companyAccountProvider.getStatusOptions();

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
                searchAccounts();
              },
              displayText: (status) => status,
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountsTable() {
    return Expanded(
      child: Consumer<CompanyAccountProvider>(
        builder: (context, companyAccountProvider, child) {
          final isLoading = companyAccountProvider.isLoading || initLoading;
          final accountsList =
              companyAccountProvider.getCompanyAccountsList ?? [];

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
                        child: accountsList.isEmpty
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
                                      accountsList.asMap().entries.map((entry) {
                                    final int index = entry.key;
                                    final account = entry.value;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.withOpacity(0.1),
                                      ),
                                      children: [
                                        _buildTableCell(account.name ?? "N/A"),
                                        _buildTableCell(
                                            account.paymentMethodsString),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Center(
                                            child: _buildTypeChip(
                                                account.type ?? "Unknown"),
                                          ),
                                        ),
                                        _buildTableCell(
                                            "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${account.formattedReceived}"),
                                        _buildTableCell(
                                            "${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? 'INR'} ${account.formattedSent}"),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Center(
                                            child: _buildStatusChip(
                                                account.accountStatus),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Center(
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                size: 18,
                                                color:
                                                    ColorManager.kPrimaryColor,
                                              ),
                                              onPressed: () async {
                                                // Set the account data for the details screen
                                                debugPrint(
                                                    '=================== NAVIGATING TO ACCOUNT DETAILS ===================');
                                                debugPrint(
                                                    'Account being passed: ${account.name}');
                                                debugPrint(
                                                    'Account transaction count: ${account.accountTransaction?.length ?? 0}');
                                                if (account.accountTransaction !=
                                                        null &&
                                                    account.accountTransaction!
                                                        .isNotEmpty) {
                                                  final firstTx = account
                                                      .accountTransaction![0];
                                                  debugPrint(
                                                      'First transaction: transferFrom=${firstTx.transferFrom}, transferTo=${firstTx.transferTo}, amount=${firstTx.amount}, type=${firstTx.transactionType}, status=${firstTx.status}, date=${firstTx.date}');
                                                }
                                                AccountDetailsScreen
                                                    .accountData = account;

                                                // Navigate to the account details screen using the sidebar controller
                                                sideBarController.index.value =
                                                    61;
                                                debugPrint(
                                                    '=====================================================================');
                                              },
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
          const SizedBox(height: 8),
          Text('No company account data available at this time',
              style: buildCustomStyle(
                  FontWeightManager.regular, FontSize.s14, 0.27, Colors.grey)),
          const SizedBox(height: 15),
          CustomRoundButton(
            title: "Refresh",
            boxColor: ColorManager.kPrimaryColor,
            textColor: Colors.white,
            fct: loadAccountsData,
            height: 35,
            width: 120,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Container(
      alignment: Alignment.center,
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        alignment: Alignment.center,
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

  Widget _buildTypeChip(String type) {
    Color backgroundColor = type.toLowerCase() == 'cash'
        ? Colors.green.withOpacity(0.1)
        : Colors.blue.withOpacity(0.1);
    Color textColor = type.toLowerCase() == 'cash' ? Colors.green : Colors.blue;

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
      case 'credit':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'debit':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'balanced':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
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

  // Removed _showAccountDetails method since we're now using a separate page

  // Section card with title
  Widget _buildSectionCard(
      {required String title, required Widget child, bool showDivider = true}) {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.21,
                Colors.black87,
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  // Small rounded pill chip
  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _amountText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
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
              Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// Removing the old local data model since we're using the API model
// class CompanyAccountData {
//   final String name;
//   final String paymentMethodType;
//   final String type;
//   final double receivedAmount;
//   final double sentAmount;
//   final String status;
//
//   CompanyAccountData({
//     required this.name,
//     required this.paymentMethodType,
//     required this.type,
//     required this.receivedAmount,
//     required this.sentAmount,
//     required this.status,
//   });
// }
