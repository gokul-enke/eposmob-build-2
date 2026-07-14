import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_dialog_box.dart' hide showScaffold, showScaffoldError, showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import '../../components/build_round_button.dart';
import '../../components/build_text_fields.dart';
import '../../providers/auth_model.dart';
import '../../providers/quotations_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'widgets/common_details_dialog.dart';

class ProformaInvoiceListScreen extends StatefulWidget {
  const ProformaInvoiceListScreen({super.key});

  @override
  State<ProformaInvoiceListScreen> createState() =>
      _ProformaInvoiceListScreenState();
}

class _ProformaInvoiceListScreenState extends State<ProformaInvoiceListScreen> {
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  String _selectedStatus = 'All';
  bool _isLoading = false;
  bool _showFilters = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _lastPage = 1;
  List<Map<String, dynamic>> _invoices = [];

  final List<String> _statusOptions = const [
    'All',
    'pending',
    'paid',
    'overdue',
    'order created',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInvoices());
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final filters = <String, String>{
        'page': page.toString(),
        'per_page': '20',
      };
      final invoiceNumber = _invoiceNumberController.text.trim();
      final customerSearch = _customerSearchController.text.trim();

      if (invoiceNumber.isNotEmpty) {
        filters['invoice_number'] = invoiceNumber;
      }
      if (customerSearch.isNotEmpty) {
        filters['customer_search'] = customerSearch;
      }
      if (_selectedStatus.toLowerCase() != 'all') {
        filters['status'] = _selectedStatus;
      }

      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final response = await Provider.of<QuotationsProvider>(
        context,
        listen: false,
      ).fetchProformaInvoices(
        accessToken: authProvider.token ?? '',
        filters: filters,
      );

      final data = response['data'];
      final rows = data is Map ? data['data'] : null;
      if (!mounted) return;
      setState(() {
        _invoices = rows is List
            ? rows
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        _currentPage =
            _parseInt(data is Map ? data['current_page'] : null) ?? 1;
        _lastPage = _parseInt(data is Map ? data['last_page'] : null) ?? 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _invoices = [];
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _invoiceNumberController.clear();
      _customerSearchController.clear();
      _selectedStatus = 'All';
      _currentPage = 1;
    });
    _fetchInvoices();
  }

  Future<void> _showDetails(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'];
    if (invoiceId == null) {
      showScaffoldError(context: context, message: 'Invoice id not found');
      return;
    }

    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final response = await Provider.of<QuotationsProvider>(
        context,
        listen: false,
      ).fetchProformaInvoiceDetails(
        accessToken: authProvider.token ?? '',
        invoiceId: invoiceId,
      );
      if (!mounted) return;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _openDetailsDialog(data);
      } else if (data is Map) {
        _openDetailsDialog(Map<String, dynamic>.from(data));
      } else {
        showScaffoldError(context: context, message: 'Details not found');
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(context: context, message: 'Failed to load details');
      }
    }
  }

  void _openDetailsDialog(Map<String, dynamic> data) {
    final customer = _mapValue(data['customer']);
    final quotation = _mapValue(data['quotation']);
    final items = data['items'] is List ? data['items'] as List : const [];

    showDialog(
      context: context,
      builder: (context) => CommonDetailsDialog(
        title: 'Proforma Invoice Details',
        gridColumns: [
          [
            CommonDetailsDialog.buildKeyValueRow('Invoice #', _text(data['invoice_number']), copyable: true),
            CommonDetailsDialog.buildKeyValueRow('Status', _text(data['status'])),
            CommonDetailsDialog.buildKeyValueRow('Amount', _text(data['amount'])),
            CommonDetailsDialog.buildKeyValueRow('Invoice Date', _text(data['invoice_date'])),
          ],
          [
            CommonDetailsDialog.buildKeyValueRow('Due Date', _text(data['due_date'])),
            CommonDetailsDialog.buildKeyValueRow('Customer', _text(customer['name'])),
            CommonDetailsDialog.buildKeyValueRow('Phone', _text(customer['phone']), copyable: true),
            CommonDetailsDialog.buildKeyValueRow('Quotation #', _text(quotation['quotation_number'])),
          ],
        ],
        sectionTitle: 'Items',
        tableContent: items.isEmpty
            ? const Center(child: Text('No items found'))
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.4),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  _detailsHeaderRow(),
                  ...items.map((item) {
                    final row = _mapValue(item);
                    return TableRow(
                      children: [
                        _dialogCell(_text(row['item_name'])),
                        _dialogCell(_text(row['quantity'])),
                        _dialogCell(_text(row['unit_amount'])),
                        _dialogCell(_text(row['total_amount'])),
                      ],
                    );
                  }),
                ],
              ),
      ),
    );
  }


  TableRow _detailsHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _StaticTableCell('Item'),
        _StaticTableCell('Qty'),
        _StaticTableCell('Unit Amount'),
        _StaticTableCell('Total'),
      ],
    );
  }

  Widget _dialogCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  Widget _buildMobileFilters() {
    if (!_showFilters) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildColumnWidgetForTextFields(
            title: 'Invoice #',
            height: 45,
            width: double.infinity,
            controller: _invoiceNumberController,
            size: size,
            hintText: 'Search invoice number',
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onchanged: (_) => _fetchInvoices(),
          ),
          const SizedBox(height: 10),
          buildColumnWidgetForTextFields(
            title: 'Customer',
            height: 45,
            width: double.infinity,
            controller: _customerSearchController,
            size: size,
            hintText: 'Name or phone',
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onchanged: (_) => _fetchInvoices(),
          ),
          const SizedBox(height: 10),
          BuildDropDownStatic(
            title: 'Status',
            size: size,
            items: _statusOptions,
            selectedItem: _selectedStatus,
            hintText: 'All',
            height: 45,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onChanged: (value) {
              setState(() => _selectedStatus = value ?? 'All');
              _fetchInvoices();
            },
          ),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: 'Reset Filters',
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            borderColor: ColorManager.kPrimaryColor,
            fct: _resetFilters,
            height: 44,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMobileCard(_invoices[index]);
      },
    );
  }

  Widget _buildCompactFieldBox({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> invoice) {
    final customer = _mapValue(invoice['customer']);
    final quotation = _mapValue(invoice['quotation']);
    final status = _text(invoice['status']);
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _text(invoice['invoice_number']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.bold,
                              FontSize.s14,
                              0.20,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: _text(invoice['invoice_number'])));
                            showScaffold(
                              context: context,
                              message: 'Invoice number copied to clipboard',
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SelectableText(
                                  _text(customer['name']),
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s11,
                                    0.15,
                                    Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Text(
                                ' · ${_text(quotation['quotation_number'])}',
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s11,
                                  0.15,
                                  Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_text(quotation['quotation_number']) != '-') ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: _text(quotation['quotation_number'])));
                              showScaffold(
                                context: context,
                                message: 'Quotation number copied to clipboard',
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'View Details',
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: BuildBoxShadowContainer(
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                    circleRadius: 6,
                    child: IconButton(
                      icon: const Icon(Icons.visibility,
                          size: 14, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDetails(invoice),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Amount',
                  value: _text(invoice['amount']),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'Due Date',
                  value: _text(invoice['due_date']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status == '-' ? status : status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _fetchInvoices(page: _currentPage),
        child: isMobile
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  margin: const EdgeInsets.only(left: 8, top: 10, bottom: 8, right: 8),
                  padding: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(true),
                        const SizedBox(height: 16),
                        _buildMobileFilters(),
                        const SizedBox(height: 10),
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ColorManager.kPrimaryColor,
                                    ),
                                  ),
                                ),
                              )
                            : _errorMessage != null
                                ? Center(
                                    child: Text(
                                      'Failed to load proforma invoices',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s14,
                                        0,
                                        ColorManager.kButtonRed,
                                      ),
                                    ),
                                  )
                                : _invoices.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: Text('No proforma invoices found'),
                                        ),
                                      )
                                    : _buildMobileList(),
                        const SizedBox(height: 12),
                        _buildPagination(),
                      ],
                    ),
                  ),
                ),
              )
            : BuildBoxShadowContainer(
                circleRadius: 7,
                margin:
                    const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
                padding: const EdgeInsets.all(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(false),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BuildBoxShadowContainer(
                          circleRadius: 7,
                          offsetValue: const Offset(1, 1),
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ColorManager.kPrimaryColor,
                                    ),
                                  ),
                                )
                              : _buildBody(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPagination(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Proforma Invoices',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s18,
              0.30,
              ColorManager.textColor,
            ),
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
          ),
        ],
      );
    }
    return Text(
      'Proforma Invoices',
      style: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s20,
        0.30,
        ColorManager.textColor,
      ),
    );
  }

  Widget _buildFilters() {
    final size = MediaQuery.of(context).size;
    if (size.width < 900) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: buildColumnWidgetForTextFields(
            title: 'Invoice #',
            height: 45,
            width: double.infinity,
            controller: _invoiceNumberController,
            size: size,
            hintText: 'Search invoice number',
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onchanged: (_) => _fetchInvoices(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: buildColumnWidgetForTextFields(
            title: 'Customer',
            height: 45,
            width: double.infinity,
            controller: _customerSearchController,
            size: size,
            hintText: 'Name or phone',
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onchanged: (_) => _fetchInvoices(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BuildDropDownStatic(
            title: 'Status',
            size: size,
            items: _statusOptions,
            selectedItem: _selectedStatus,
            hintText: 'All',
            height: 45,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            onChanged: (value) {
              setState(() => _selectedStatus = value ?? 'All');
              _fetchInvoices();
            },
          ),
        ),
        const SizedBox(width: 10),
        CustomRoundButton(
          title: 'Reset',
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          fct: _resetFilters,
          height: 45,
          width: 120,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Failed to load proforma invoices',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0,
            ColorManager.kButtonRed,
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return const Center(child: Text('No proforma invoices found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 980.0;
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.6),
                    1: FlexColumnWidth(1.7),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(1.2),
                    5: FlexColumnWidth(1.2),
                    6: FlexColumnWidth(1.3),
                    7: FlexColumnWidth(0.9),
                  },
                  children: [_buildTableHeader()],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.6),
                        1: FlexColumnWidth(1.7),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.2),
                        6: FlexColumnWidth(1.3),
                        7: FlexColumnWidth(0.9),
                      },
                      children: _invoices.asMap().entries.map((entry) {
                        return _buildTableRow(entry.value, entry.key);
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
    return const TableRow(
      decoration: BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _StaticTableCell('Invoice #'),
        _StaticTableCell('Customer'),
        _StaticTableCell('Quotation #'),
        _StaticTableCell('Invoice Date'),
        _StaticTableCell('Due Date'),
        _StaticTableCell('Amount'),
        _StaticTableCell('Status'),
        _StaticTableCell('Actions'),
      ],
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> invoice, int index) {
    final customer = _mapValue(invoice['customer']);
    final quotation = _mapValue(invoice['quotation']);
    final status = _text(invoice['status']);

    return TableRow(
      decoration: BoxDecoration(
        color:
            index % 2 == 0 ? Colors.white : Colors.grey.withValues(alpha: 0.1),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 22.0, horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _text(invoice['invoice_number']),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s9,
                      0.18,
                      Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: _text(invoice['invoice_number'])));
                    showScaffold(
                      context: context,
                      message: 'Invoice number copied to clipboard',
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
            padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 10.0),
            child: Center(
              child: SelectableText(
                _text(customer['name']),
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.18,
                  Colors.black,
                ),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 22.0, horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _text(quotation['quotation_number']),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s9,
                      0.18,
                      Colors.black,
                    ),
                  ),
                ),
                if (_text(quotation['quotation_number']) != '-') ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: _text(quotation['quotation_number'])));
                      showScaffold(
                        context: context,
                        message: 'Quotation number copied to clipboard',
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
        _tableCell(_text(invoice['invoice_date'])),
        _tableCell(_text(invoice['due_date'])),
        _tableCell(_text(invoice['amount'])),
        _statusCell(status),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: BuildBoxShadowContainer(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: ColorManager.kPrimaryColor.withValues(alpha: 0.9),
              circleRadius: 5,
              child: IconButton(
                icon:
                    const Icon(Icons.visibility, size: 16, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _showDetails(invoice),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCell(String status) {
    final color = _statusColor(status);
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status == '-' ? status : status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'order created':
        return Colors.green;
      case 'overdue':
        return ColorManager.kButtonRed;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 10.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: _currentPage > 1
              ? () => _fetchInvoices(page: _currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $_currentPage of $_lastPage'),
        IconButton(
          onPressed: _currentPage < _lastPage
              ? () => _fetchInvoices(page: _currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? '-' : text;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _StaticTableCell extends StatelessWidget {
  final String text;

  const _StaticTableCell(this.text);

  @override
  Widget build(BuildContext context) {
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
}
