import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/quotation_print_service.dart';
import 'package:provider/provider.dart';

class QuotationsListScreen extends StatefulWidget {
  const QuotationsListScreen({super.key});

  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen> {
  // ── Filter state ──────────────────────────────────────────────────────────
  final TextEditingController _quotationNumberController =
      TextEditingController();
  final TextEditingController _storeSearchController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();

  String? _selectedCustomerId;
  int? _selectedStoreId;
  String _selectedStatus = 'All';
  DateTime? _selectedQuotationDate;
  DateTime? _selectedExpiryDate;

  Key _quotationDateKey = UniqueKey();
  Key _expiryDateKey = UniqueKey();

  bool _isLoading = false;
  bool _isPrintingQuotation = false;

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Order Created',
    'Cancel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchQuotations();
    });
  }

  @override
  void dispose() {
    _quotationNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final quotationProvider =
          Provider.of<QuotationsProvider>(context, listen: false);

      String? startDate;
      if (_selectedQuotationDate != null) {
        startDate =
            "${_selectedQuotationDate!.year}-${_selectedQuotationDate!.month.toString().padLeft(2, '0')}-${_selectedQuotationDate!.day.toString().padLeft(2, '0')}";
      }

      String? endDate;
      if (_selectedExpiryDate != null) {
        endDate =
            "${_selectedExpiryDate!.year}-${_selectedExpiryDate!.month.toString().padLeft(2, '0')}-${_selectedExpiryDate!.day.toString().padLeft(2, '0')}";
      }

      await quotationProvider.fetchQuotations(
        accessToken: authProvider.token ?? '',
        quotationNumber: _quotationNumberController.text,
        startDate: startDate,
        endDate: endDate,
        filterStatus: _selectedStatus,
        customerId: _selectedCustomerId,
        storeId: _selectedStoreId,
      );
    } catch (e) {
      debugPrint("Error fetching quotations: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _quotationNumberController.clear();
      _selectedCustomerId = null;
      _selectedStoreId = null;
      _selectedStatus = 'All';
      _selectedQuotationDate = null;
      _selectedExpiryDate = null;
      _quotationDateKey = UniqueKey();
      _expiryDateKey = UniqueKey();
    });
    _fetchQuotations();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'order created':
        return Colors.green;
      case 'cancel':
      case 'cancelled':
        return ColorManager.kButtonRed;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _printQuotation(Quotation quotation) async {
    final quotationId = quotation.id;
    if (quotationId == null) {
      showScaffoldError(
        context: context,
        message: 'Quotation id not found',
      );
      return;
    }
    if (_isPrintingQuotation) return;

    setState(() => _isPrintingQuotation = true);
    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final quotationsProvider =
          Provider.of<QuotationsProvider>(context, listen: false);

      final details = await quotationsProvider.fetchQuotationDetails(
        accessToken: authProvider.token ?? '',
        quotationId: quotationId,
      );
      if (!mounted) return;

      if (details == null) {
        showScaffoldError(
          context: context,
          message: 'Quotation details not found for printing',
        );
        return;
      }

      await const QuotationPrintService().printQuotationDetails(
        context,
        details,
      );
    } catch (e) {
      debugPrint('Error printing quotation: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Failed to print quotation',
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingQuotation = false);
    }
  }

  Widget _buildStoreDropdown() {
    return Consumer<StoreSessionProvider>(builder: (context, prov, _) {
      final List<Store> list = prov.availableStores;
      final Store? sel =
          list.firstWhereOrNull((s) => s.storeId == _selectedStoreId);
      return BuildDropDownWithSearch<Store>(
        title: "Store",
        showName: true,
        hintText: "Select Store",
        value: sel,
        items: list,
        onChanged: (v) {
          setState(() {
            _selectedStoreId = v?.storeId;
          });
          _fetchQuotations();
        },
        displayText: (v) => v.storeName ?? "",
        searchController: _storeSearchController,
        height: 45,
      );
    });
  }

  Widget _buildCustomerDropdown() {
    return Consumer<CustomerProvider>(builder: (context, prov, _) {
      final CustomerListModelData? sel = prov.allCustomers
          ?.firstWhereOrNull((s) => s.id.toString() == _selectedCustomerId);
      return BuildDropDownWithSearch<CustomerListModelData>(
        title: "Customer",
        showName: true,
        hintText: "Select Customer",
        value: sel,
        items: prov.allCustomers ?? [],
        onChanged: (v) {
          setState(() {
            _selectedCustomerId = v?.id?.toString();
          });
          _fetchQuotations();
        },
        displayText: (v) => "${v.name} (${v.phone})",
        searchController: _customerSearchController,
        height: 45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuotationsProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchQuotations,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              margin: const EdgeInsets.only(
                  left: 10, top: 20, bottom: 0, right: 10),
              padding: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildFiltersCard(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: BuildBoxShadowContainer(
                        circleRadius: 7,
                        offsetValue: const Offset(1, 1),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        ColorManager.kPrimaryColor),
                                  ),
                                ),
                              )
                            : provider.quotations.isEmpty
                                ? _buildEmptyState(provider)
                                : _buildQuotationsTable(provider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Quotation List',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        CustomRoundButton(
          title: 'New Quotation',
          fct: () {
            Get.find<SideBarController>().index.value = 86;
          },
          fontSize: 12,
          height: 42,
          width: 160,
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    if (isMobile) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: buildColumnWidgetForTextFields(
                title: "Quotation #",
                height: 45,
                width: double.infinity,
                onchanged: (value) {
                  if (value != null && value.length > 2) _fetchQuotations();
                },
                controller: _quotationNumberController,
                size: size,
                hintText: 'Search quotation number',
                margin: const EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: _buildCustomerDropdown(),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: _buildStoreDropdown(),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: BuildDropDownStatic(
                title: "Quotation Status",
                size: size,
                items: _statusOptions,
                selectedItem: _selectedStatus,
                hintText: "All",
                onChanged: (v) {
                  setState(() => _selectedStatus = v ?? 'All');
                  _fetchQuotations();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuildTextTile(
                    title: "Quotation Date",
                    textStyle: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s14,
                      0.27,
                      Colors.black.withOpacity(0.6),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    height: 45,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: Center(
                      child: CalendarPickerTableCell(
                        key: _quotationDateKey,
                        onDateSelected: (DateTime date) {
                          setState(() => _selectedQuotationDate = date);
                          _fetchQuotations();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BuildTextTile(
                    title: "Expiry Date",
                    textStyle: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s14,
                      0.27,
                      Colors.black.withOpacity(0.6),
                    ),
                  ),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    height: 45,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: Center(
                      child: CalendarPickerTableCell(
                        key: _expiryDateKey,
                        onDateSelected: (DateTime date) {
                          setState(() => _selectedExpiryDate = date);
                          _fetchQuotations();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Opacity(
                    opacity: 0.0,
                    child: BuildTextTile(
                      title: "Reset",
                      textStyle: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s14,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ),
                  CustomRoundButton(
                    title: "Reset",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: _resetFilters,
                    height: 45,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(QuotationsProvider provider) {
    final hasFilters = _quotationNumberController.text.isNotEmpty ||
        _selectedCustomerId != null ||
        _selectedStoreId != null ||
        _selectedStatus != 'All' ||
        _selectedQuotationDate != null ||
        _selectedExpiryDate != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            provider.quotations.isEmpty && !hasFilters
                ? "No quotations available"
                : "No quotations match your filters",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsTable(QuotationsProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minWidth = 900.0;
        final double tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
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
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(1.8),
                      1: FlexColumnWidth(2.0),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(1.2),
                      5: FlexColumnWidth(1.4),
                      6: FlexColumnWidth(1.2),
                    },
                    children: [_buildTableHeader()],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    child: Table(
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(1.8),
                        1: FlexColumnWidth(2.0),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.4),
                        6: FlexColumnWidth(1.2),
                      },
                      children:
                          provider.quotations.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Quotation q = entry.value;
                        return _buildTableRow(q, idx);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      children: [
        'Quotation #',
        'Customer',
        'Store',
        'Quotation Date',
        'Expiry Date',
        'Status',
        'Actions',
      ]
          .map(
            (title) => Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
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
            ),
          )
          .toList(),
    );
  }

  TableRow _buildTableRow(Quotation q, int index) {
    final status = q.status ?? '';

    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.1),
      ),
      children: [
        _textCell(q.quotationNumber ?? '—'),
        _textCell(q.customer ?? '—'),
        _textCell(q.store ?? '—'),
        _textCell(
            q.quotationDate != null ? q.quotationDate!.split(' ').first : '—'),
        _textCell(q.expiryDate != null ? q.expiryDate!.split(' ').first : '—'),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.isEmpty ? '—' : status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                    circleRadius: 5,
                    child: IconButton(
                      icon: const Icon(Icons.visibility,
                          size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        Get.find<SideBarController>().index.value = 88;
                        context
                            .read<QuotationsProvider>()
                            .setSelectedQuotationId(q.id);
                      },
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    color: Colors.orange.withOpacity(0.9),
                    circleRadius: 5,
                    child: IconButton(
                      icon: const Icon(Icons.shopping_cart_checkout,
                          size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        // TODO: Implement navigation to Convert Quotation to Order screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Convert to Order screen coming next')),
                        );
                      },
                    ),
                  ),
                  BuildBoxShadowContainer(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    color: Colors.green.withOpacity(0.9),
                    circleRadius: 5,
                    child: IconButton(
                      icon: const Icon(Icons.print,
                          size: 16, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _isPrintingQuotation
                          ? null
                          : () => _printQuotation(q),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _textCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.18,
          Colors.black,
        ),
      ),
    );
  }
}
