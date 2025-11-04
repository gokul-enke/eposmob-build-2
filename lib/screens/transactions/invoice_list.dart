import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dropdown_with_search.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/auth_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitialized = false;
  final TextEditingController searchTextController = TextEditingController();
  final TextEditingController invoiceNumberController = TextEditingController();
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dateFromController = TextEditingController();
  final TextEditingController dateToController = TextEditingController();
  String? selectedStatus; // For the status dropdown

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadInvoices();
    });
  }

  Future<void> _performZatcaPhase2SendWithPdf(Invoice invoice) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Send With PDF] Start for invoice '+invoice.invoiceNumber+' (ID: '+invoice.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send With PDF] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Processing ZATCA Phase 2...');
      showLoadingOverlay(context, message: 'Processing...');

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send With PDF] Response: '+result.toString());
      if (result is Map && ((result['status'] == 'success') || (result['success'] == true) || (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String invoiceNumber = (data['invoice_number']?.toString() ?? invoice.invoiceNumber);
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        }
        showScaffold(
          context: context,
          message: 'Invoice '+invoiceNumber+' processed under ZATCA Phase 2.',
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

  Future<void> _performZatcaPhase2Resync(Invoice invoice) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Resync] Start for invoice '+invoice.invoiceNumber+' (ID: '+invoice.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Resync] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Resyncing invoice with ZATCA...');
      showLoadingOverlay(context, message: 'Resyncing...');

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoiceResync(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Resync] Response: '+result.toString());
      if (result is Map) {
        final bool ok = (result['status'] == 'success') || (result['success'] == true) || (result['status'] == true);
        final data = (result['data'] is Map) ? result['data'] as Map : null;
        final String invoiceNumber = data?['invoice_number']?.toString() ?? invoice.invoiceNumber;
        final String resyncStatus = data?['resync_status']?.toString() ?? (ok ? 'success' : 'failed');
        final String? rawError = data?['error']?.toString();
        if (ok) {
          showScaffold(
            context: context,
            message: 'Invoice '+invoiceNumber+' resynced with status: '+resyncStatus,
          );
        } else {
          String detail = rawError != null
              ? rawError.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
              : (result['message']?.toString() ?? 'Failed to resync invoice');
          if (detail.length > 220) detail = detail.substring(0, 220)+'...';
          final errMsg = 'Resync failed for '+invoiceNumber+' (status: '+resyncStatus+'). '+detail;
          debugPrint('[ZATCA][Phase2 Resync] ERROR: '+errMsg);
          showScaffoldError(context: context, message: errMsg);
        }
      } else {
        showScaffoldError(context: context, message: 'Failed to resync invoice');
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase2 Resync] EXCEPTION: '+e.toString());
      showScaffoldError(context: context, message: 'Error: '+e.toString());
    } finally {
      hideLoadingOverlay();
    }
  }

  Future<void> _showInvoiceActionsSheet(Invoice invoice) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final appSettings = Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
        final bool phase1 = appSettings?.zatcaPhase1Enabled ?? false;
        final bool phase2 = appSettings?.zatcaPhase2Enabled ?? false;
        final bool isZatcaSuccess = (invoice.zatcaStatus?.toLowerCase() == 'success');

        final List<Widget> dynamicItems = [];
        // If ZATCA is already success for this invoice, only show Phase 2 button
        if (isZatcaSuccess) {
          if (phase2) {
            dynamicItems.add(
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange.withOpacity(0.12),
                  child: const Icon(Icons.description, color: Colors.orange),
                ),
                title: const Text('ZATCA Phase 2'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2SendWithPdf(invoice);
                },
              ),
            );
          }
        } else {
          // When not success, keep existing behavior: show Print and Send when any phase is enabled
          if (phase1 || phase2) {
            dynamicItems.addAll([
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(Icons.qr_code, color: Colors.green),
                ),
                title: const Text('ZATCA Print'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase1Print(invoice);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                  child: Icon(Icons.send, color: ColorManager.kPrimaryColor),
                ),
                title: const Text('Send to ZATCA'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performZatcaPhase2Send(invoice);
                },
              ),
            ]);
          }
        }

        // Show Resync only when Phase 2 is enabled AND not already success
        if (phase2 && !isZatcaSuccess) {
          dynamicItems.add(
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.purple.withOpacity(0.12),
                child: const Icon(Icons.sync, color: Colors.purple),
              ),
              title: const Text('Resync Invoice'),
              onTap: () async {
                Navigator.pop(ctx);
                await _performZatcaPhase2Resync(invoice);
              },
            ),
          );
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
                const Text(
                  'More Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Future<void> _performZatcaPhase2Send(Invoice invoice) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase2 Send] Start for invoice '+invoice.invoiceNumber+' (ID: '+invoice.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase2 Send] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Sending to ZATCA...');
      showLoadingOverlay(context, message: 'Sending...');

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase2InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase2 Send] Response: '+result.toString());
      if (result is Map && ((result['status'] == 'success') || (result['success'] == true) || (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String invoiceNumber = (data['invoice_number']?.toString() ?? invoice.invoiceNumber);
        // Do NOT open PDF here per requirement. Just inform the user.
        showScaffold(
          context: context,
          message: 'Invoice '+invoiceNumber+' submitted to ZATCA successfully.',
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

  

  Future<void> loadInvoices() async {
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

      await Provider.of<InvoiceProvider>(context, listen: false)
          .listAllInvoices(accessToken: accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading invoices: $error")),
      );
    }
  }

  void searchInvoices() {
    debugPrint("Searching with filters");
    InvoiceProvider provider =
        Provider.of<InvoiceProvider>(context, listen: false);
    provider.applyFilters(
      name: searchTextController.text,
      invoiceNumber: invoiceNumberController.text,
      // orderNumber: orderNumberController.text,
      phone: phoneController.text,
      email: emailController.text,
      fromDate: dateFromController.text,
      toDate: dateToController.text,
      status: selectedStatus,
    );
  }

  void resetSearch() {
    debugPrint("Resetting all filters");
    setState(() {
      searchTextController.clear();
      invoiceNumberController.clear();
      orderNumberController.clear();
      phoneController.clear();
      emailController.clear();
      dateFromController.clear();
      dateToController.clear();
      selectedStatus = null;
    });

    Provider.of<InvoiceProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    debugPrint("Refreshing data");
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    // Reset search field when refreshing
    setState(() {
      searchTextController.clear();
    });

    await Provider.of<InvoiceProvider>(context, listen: false)
        .listAllInvoices(accessToken: accessToken);
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
              primary: ColorManager.kPrimaryColor, // Header background color
              onPrimary: Colors.white, // Header text color
              surface: Colors.white, // Calendar background
              onSurface: Colors.black, // Calendar text color
            ),
            dialogBackgroundColor: Colors.white, // Dialog background
            cardColor: Colors.white, // Card background
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      if (isFromDate) {
        dateFromController.text = formattedDate;
      } else {
        dateToController.text = formattedDate;
      }
      searchInvoices();
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
                _buildInvoiceTable(),
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
          "Invoice List",
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        // CustomRoundButton(
        //   title: "Create New Invoice",
        //   fct: () {
        //     sideBarController.index.value = 24;
        //   },
        //   fontSize: 12,
        //   height: 45,
        //   width: 200,
        // ),
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
            children: [
              Expanded(
                flex: 1,
                child: _buildInvoiceNumberSearch(),
              ),
              // Name Search Field
              Expanded(
                flex: 1,
                child: _buildSearchTextField(),
              ),

              // Invoice Number Search Field

              // // Order Number Search Field
              // Expanded(
              //   flex: 1,
              //   child: _buildOrderNumberSearch(),
              // ),

              // Phone Search Field
              Expanded(
                flex: 1,
                child: _buildPhoneSearch(),
              ),

              // Email Search Field
              Expanded(
                flex: 1,
                child: _buildEmailSearch(),
              ),
            ],
          ),
        ),
        // Second row of search fields
        SizedBox(
          height: 90,
          child: Row(
            children: [
              // Status Filter
              Expanded(
                flex: 1,
                child: _buildStatusFilter(),
              ),

              // Date Range Search
              Expanded(
                flex: 2,
                child: _buildDateRangeSearch(),
              ),

              //SizedBox(width: 10),

              // Reset Button
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 42, left: 10),
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

  Widget _buildInvoiceNumberSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Invoice No",
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
              controller: invoiceNumberController,
              onChanged: (value) => searchInvoices(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Invoice No",
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
          const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: phoneController,
              onChanged: (value) => searchInvoices(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              keyboardType: TextInputType.phone,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Phone",
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
          const SizedBox(height: 8),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: emailController,
              onChanged: (value) => searchInvoices(),
              cursorColor: ColorManager.kPrimaryColor,
              cursorHeight: 13,
              keyboardType: TextInputType.emailAddress,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                  0.18, ColorManager.textColor),
              decoration: decoration.copyWith(
                hintText: "Email",
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

  Widget _buildDateRangeSearch() {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "From Date",
                    style: buildCustomStyle(FontWeightManager.regular,
                        FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                  ),
                ),
                const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  height: 45,
                  width: double.infinity,
                  circleRadius: 7,
                  child: TextFormField(
                    controller: dateFromController,
                    onTap: () => _selectDate(context, isFromDate: true),
                    readOnly: true,
                    cursorColor: ColorManager.kPrimaryColor,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "To Date",
                    style: buildCustomStyle(FontWeightManager.regular,
                        FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
                  ),
                ),
                const SizedBox(height: 8),
                BuildBoxShadowContainer(
                  height: 45,
                  width: double.infinity,
                  circleRadius: 7,
                  child: TextFormField(
                    controller: dateToController,
                    onTap: () => _selectDate(context, isFromDate: false),
                    readOnly: true,
                    cursorColor: ColorManager.kPrimaryColor,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s10, 0.18, ColorManager.textColor),
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
              List<String> statusOptions = invoiceProvider.getStatusOptions();

              // Find the display text for the currently selected status
              String? selectedStatusDisplay;
              if (selectedStatus != null) {
                selectedStatusDisplay = statusOptions.contains(selectedStatus)
                    ? selectedStatus
                    : "All Status";
              }

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
                  searchInvoices();
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

  //   Widget _buildOrderNumberSearch() {
  //   return Padding(
  //     padding: const EdgeInsets.only(left: 10.0),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Text(
  //             "Order No",
  //             style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
  //                 0.27, Colors.black.withOpacity(0.6)),
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         BuildBoxShadowContainer(
  //           height: 45,
  //           width: double.infinity,
  //           circleRadius: 7,
  //           child: TextFormField(
  //             controller: orderNumberController,
  //             onChanged: (value) => searchInvoices(),
  //             cursorColor: ColorManager.kPrimaryColor,
  //             cursorHeight: 13,
  //             style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
  //                 0.18, ColorManager.textColor),
  //             decoration: decoration.copyWith(
  //               hintText: "Order No",
  //               hintStyle: buildCustomStyle(FontWeightManager.medium,
  //                   FontSize.s10, 0.18, ColorManager.textColor),
  //               prefixIconColor: Colors.black,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showInvoiceDetails(Invoice invoice) {
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
                  children: [
                    Text(
                      'Invoice Details',
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
                      children: [
                        _buildDetailRow(
                            'Invoice Number', invoice.invoiceNumber),
                        _buildDetailRow(
                            'Customer Name', invoice.customer.user.name),
                        _buildDetailRow(
                            'Customer Phone', invoice.customer.user.phone),
                        _buildDetailRow('Order Number', ""), //no order number

                        _buildDetailRow('Type', invoice.type),
                        _buildDetailRow('Invoice Date', invoice.invoiceDate),
                        _buildDetailRow('Due Date', invoice.dueDate),
                        _buildDetailRow('Amount', invoice.amount.toString()),
                        _buildDetailRow('Status', invoice.status),
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

//------------------------------------------------------debug-------------------------------------------
//
//
//
// void _showInvoiceDetails(Invoice invoice) async {
//   debugPrint('\n--- DEBUG START ---');
//   debugPrint('Attempting to fetch details for invoice ID: ${invoice.id}');

//   // 1. Verify token exists
//   final token = Provider.of<AuthModel>(context, listen: false).token;
//   if (token == null) {
//     debugPrint('❌ ERROR: No authentication token found');
//     return;
//   }
//   debugPrint('✅ Token exists: ${token.substring(0, 10)}...');

//   // 2. Verify API endpoint and parameters
//   final apiUrl = 'YOUR_API_ENDPOINT/invoices/${invoice.id}';
//   debugPrint('🔍 API Endpoint: $apiUrl');

//   try {
//     // 3. Make the API call directly for debugging
//     debugPrint('🌐 Making API call...');
//     final response = await http.get(
//       Uri.parse(apiUrl),
//       headers: {'Authorization': 'Bearer $token'},
//     );

//     debugPrint('🔄 Response Status: ${response.statusCode}');
//     debugPrint('📦 Response Body: ${response.body}');

//     if (response.statusCode == 200) {
//       final jsonData = jsonDecode(response.body);
//       debugPrint('✅ API Response Data:');
//       debugPrint(jsonData.toString());

//       // 4. Verify the response structure matches your model
//       if (jsonData['data'] != null) { // or whatever your response structure is
//         debugPrint('🔍 Data exists in response');
//         final invoiceDetails = InvoiceDetails.fromJson(jsonData['data']);
//         debugPrint('📊 Parsed Invoice:');
//         debugPrint('- Number: ${invoiceDetails.invoiceNumber}');
//         debugPrint('- Customer: ${invoiceDetails.customer?.name}');
//         // ... print other fields
//       } else {
//         debugPrint('❌ No data field in API response');
//       }
//     } else {
//       debugPrint('❌ API Error: ${response.statusCode}');
//     }
//   } catch (e) {
//     debugPrint('❌ Exception during API call: $e');
//   }
// }

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
          const SizedBox(
            height: 8,
          ),
          BuildBoxShadowContainer(
            height: 45,
            width: double.infinity,
            circleRadius: 7,
            child: TextFormField(
              controller: searchTextController,
              onChanged: (value) {
                searchInvoices();
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

  Widget _buildInvoiceTable() {
    return Expanded(
      child:
          Consumer<InvoiceProvider>(builder: (context, invoiceProvider, child) {
        final isLoading = invoiceProvider.isLoading;
        final invoiceList = invoiceProvider.invoiceListDetails;

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
                                0: const FlexColumnWidth(1.4), // Invoice Number
                                1: const FlexColumnWidth(0.9), // Amount
                                2: const FlexColumnWidth(1.6), // Name (reduced)
                                3: const FlexColumnWidth(1.3), // Invoice Date (reduced)
                                4: const FlexColumnWidth(0.9), // Type
                                5: const FlexColumnWidth(1.3), // Due Date (reduced)
                                6: const FlexColumnWidth(0.9), // Status
                                // Make action column wider on small screens
                                7: FlexColumnWidth(MediaQuery.of(context).size.width < 900 ? 2.2 : 1.5),
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildTableHeader("Invoice Number"),
                                    _buildTableHeader("Amount"),
                                    _buildTableHeader("Name"),
                                    _buildTableHeader("Invoice Date"),
                                    _buildTableHeader("Type"),
                                    _buildTableHeader("Due Date"),
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
                                child: invoiceList == null ||
                                        invoiceList.isEmpty
                                    ? _buildNoInvoicesFoundUI()
                                    : SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        scrollDirection: Axis.vertical,
                                        child: Table(
                                          columnWidths: {
                                            0: const FlexColumnWidth(1.4), // Invoice Number
                                            1: const FlexColumnWidth(0.9), // Amount
                                            2: const FlexColumnWidth(1.6), // Name (reduced)
                                            3: const FlexColumnWidth(1.3), // Invoice Date (reduced)
                                            4: const FlexColumnWidth(0.9), // Type
                                            5: const FlexColumnWidth(1.3), // Due Date (reduced)
                                            6: const FlexColumnWidth(0.9), // Status
                                            7: FlexColumnWidth(MediaQuery.of(context).size.width < 900 ? 2.2 : 1.5),
                                          },
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: invoiceList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final int index = entry.key;
                                            final invoice = entry.value;
                                            return TableRow(
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0
                                                    ? Colors.white
                                                    : Colors.grey
                                                        .withOpacity(0.1),
                                              ),
                                              children: [
                                                _buildTableCell(
                                                    invoice.invoiceNumber),
                                                _buildTableCell(
                                                    invoice.amount.toString()),
                                                _buildTableCell(invoice
                                                    .customer.user.name
                                                    .toString()),
                                                _buildTableCell(
                                                    invoice.invoiceDate),
                                                _buildTableCell(invoice.type),
                                                _buildTableCell(
                                                    invoice.dueDate),
                                                Center(
                                                    child: _buildStatusChip(
                                                        invoice.status)),
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(width: 8),
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
                                                                _showInvoiceDetails(
                                                                    invoice),
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
                                                        Builder(
                                                          builder: (context) {
                                                            final appSettings = Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
                                                            final bool phase1 = appSettings?.zatcaPhase1Enabled ?? false;
                                                            final bool phase2 = appSettings?.zatcaPhase2Enabled ?? false;
                                                            final bool showZatcaMenu = phase1 || phase2;
                                                            if (!showZatcaMenu) {
                                                              return const SizedBox.shrink();
                                                            }
                                                            return BuildBoxShadowContainer(
                                                              margin: const EdgeInsets.only(left: 5, right: 5),
                                                              circleRadius: 5,
                                                              child: IconButton(
                                                                icon: Icon(
                                                                  Icons.more_vert,
                                                                  size: 18,
                                                                  color: ColorManager.kPrimaryColor.withOpacity(0.9),
                                                                ),
                                                                onPressed: () => _showInvoiceActionsSheet(invoice),
                                                                constraints: const BoxConstraints(
                                                                  minWidth: 36,
                                                                  minHeight: 36,
                                                                ),
                                                                padding: EdgeInsets.zero,
                                                              ),
                                                            );
                                                          },
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
      }),
    );
  }

  

  Future<void> _performZatcaPhase1Print(Invoice invoice) async {
    try {
      final String? token = Provider.of<AuthModel>(context, listen: false).token;
      debugPrint('[ZATCA][Phase1 Print] Start for invoice '+invoice.invoiceNumber+' (ID: '+invoice.id.toString()+')');
      if (token == null || token.isEmpty) {
        debugPrint('[ZATCA][Phase1 Print] ERROR: Missing authentication token');
        showScaffoldError(context: context, message: 'Missing authentication token');
        return;
      }

      showScaffold(context: context, message: 'Processing ZATCA Print...');
      showLoadingOverlay(context, message: 'Processing...');

      final provider = Provider.of<InvoiceProvider>(context, listen: false);
      final result = await provider.zatcaPhase1InvoicePrint(
        id: invoice.id,
        accessToken: token,
      );

      debugPrint('[ZATCA][Phase1 Print] Response: '+result.toString());
      if (result is Map && ((result['status'] == 'success') || (result['success'] == true) || (result['status'] == true))) {
        final data = result['data'] ?? {};
        final String? downloadUrl = data['download_url']?.toString();
        final String? fileName = data['filename']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          await _downloadAndOpenPdf(downloadUrl, suggestedFileName: fileName);
        } else {
          showScaffold(
            context: context,
            message: (result['message']?.toString() ?? 'ZATCA Print completed'),
          );
        }
      } else {
        final msg = (result is Map ? result['message'] : null) ?? 'Failed to trigger ZATCA Print';
        debugPrint('[ZATCA][Phase1 Print] ERROR: '+msg.toString());
        showScaffoldError(context: context, message: msg.toString());
      }
    } catch (e) {
      debugPrint('[ZATCA][Phase1 Print] EXCEPTION: '+e.toString());
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
          : 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

  Widget _buildNoInvoicesFoundUI() {
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
            'No invoices found',
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

  List<TableRow> _buildTableRows(List<Invoice>? invoices) {
    return invoices?.asMap().entries.map((entry) {
          final int index = entry.key;
          final invoice = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color:
                  index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
            ),
            children: [
              _buildTableCell(invoice.customer.user.name.toString()),
              _buildTableCell(invoice.invoiceNumber),
              _buildTableCell(invoice.type),
              _buildTableCell(invoice.invoiceDate),
              _buildTableCell(invoice.dueDate),
              _buildTableCell(invoice.amount.toString()),
              _buildTableCell(invoice.status),
              _buildActionCell(invoice.id),
            ],
          );
        }).toList() ??
        [];
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

  TableCell _buildActionCell(int transactionId) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BuildBoxShadowContainer(
            margin: const EdgeInsets.only(left: 5, right: 5),
            circleRadius: 5,
            child: IconButton(
              icon: Icon(
                Icons.visibility,
                size: 18,
                color: ColorManager.kPrimaryColor.withOpacity(0.9),
              ),
              onPressed: () {
                String? token =
                    Provider.of<AuthModel>(context, listen: false).token;
                InvoiceProvider invoiceProvider =
                    Provider.of<InvoiceProvider>(context, listen: false);
                invoiceProvider.callDetailsOfInvoice(
                    id: transactionId, accessToken: token ?? "");
                sideBarController.index.value = 31;
              },
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Consumer<InvoiceProvider>(
        builder: (context, invoiceProvider, child) {
      debugPrint(
          "Building pagination controls: currentPage=${invoiceProvider.currentPage}, totalPages=${invoiceProvider.totalPages}");
      return PaginationControl(
        currentPage: invoiceProvider.currentPage,
        totalPages: invoiceProvider.totalPages,
        onPageChanged: (int page) {
          debugPrint("Page changed to: $page");
          invoiceProvider.goToPage(page);
        },
      );
    });
  }
}
