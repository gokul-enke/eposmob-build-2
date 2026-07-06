import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/sales/widgets/quotations_responsive.dart';
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
  bool _showFilters = false;
  bool _isPrintingQuotation = false;
  bool _isConvertingQuotation = false;

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Confirmed',
    'Cancelled',
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
      case 'confirmed':
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

  Future<void> _convertQuotationToOrder(Quotation quotation) async {
    final quotationId = quotation.id;
    if (quotationId == null) {
      showScaffoldError(
        context: context,
        message: 'Quotation id not found',
      );
      return;
    }
    if (_isConvertingQuotation) return;

    setState(() => _isConvertingQuotation = true);
    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final quotationsProvider =
          Provider.of<QuotationsProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      final details = await quotationsProvider.fetchQuotationDetails(
        accessToken: authProvider.token ?? '',
        quotationId: quotationId,
      );
      if (!context.mounted) return;

      if (details == null || (details.items ?? const []).isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Quotation details not found',
        );
        return;
      }

      debugPrint(
          '🧾 [QuotationConvert] Loading quotation #$quotationId (${details.quotationNumber ?? quotation.quotationNumber}) into billing draft');
      debugPrint(
          '🧾 [QuotationConvert] Customer id=${details.customer?.id}, inline=${details.customer?.isInline}, name="${details.customer?.name}", phone="${details.customer?.phone}"');
      debugPrint(
          '🧾 [QuotationConvert] Delivery id=${details.deliveryMethodId}, method="${details.deliveryMethod}", charge=${details.deliveryCharge}, items=${details.items?.length ?? 0}');

      final draftItems = <LocalCartItem>[];
      for (final quotationItem in details.items!) {
        final productId = quotationItem.productId;
        if (productId == null) continue;

        final product = localProductProvider.getProductById(productId) ??
            GetProduct(
              productId: productId,
              productName: quotationItem.productName,
              categoryId: quotationItem.categoryId,
              unit: quotationItem.unit,
              sellable: true,
            );
        final quantity = _parseQuotationNumber(quotationItem.quantity) ?? 0;
        if (quantity <= 0) continue;

        final saleUnitId = quotationItem.productSaleUnitId;
        final saleUnit = _findQuotationSaleUnit(product, saleUnitId);
        final saleUnitName = quotationItem.saleUnitName ?? saleUnit?.unitName;
        final saleUnitConversionRate =
            _parseQuotationNumber(quotationItem.saleUnitConversionRate)
                    ?.toDouble() ??
                double.tryParse(saleUnit?.conversionRate ?? '');
        final effectiveSaleUnitRate = saleUnitId != null &&
                saleUnitConversionRate != null &&
                saleUnitConversionRate > 0
            ? saleUnitConversionRate
            : null;
        final hasSaleUnit = effectiveSaleUnitRate != null;
        final baseQuantity =
            hasSaleUnit ? quantity * effectiveSaleUnitRate : quantity;

        final selectedStock = _findQuotationStock(
              product,
              quotationItem.productStockId,
            ) ??
            localProductProvider.selectStockForQuantity(product, baseQuantity);
        final quotationUnitPrice =
            _parseQuotationNumber(quotationItem.unitPrice);
        final price = quotationUnitPrice != null && hasSaleUnit
            ? quotationUnitPrice / effectiveSaleUnitRate
            : quotationUnitPrice ??
                (double.tryParse(product.price?.price?.toString() ?? '') ??
                    0.0);
        final productMrp = double.tryParse(product.mrp?.toString() ?? '');
        final mrp = productMrp != null && hasSaleUnit
            ? productMrp / effectiveSaleUnitRate
            : productMrp ?? price.toDouble();

        draftItems.add(
          LocalCartItem(
            product: product,
            price: price.toDouble(),
            mrp: mrp.toDouble(),
            taxRate: _parseQuotationNumber(quotationItem.taxRate)?.toDouble() ??
                product.totalTaxRate,
            taxAmount:
                _parseQuotationNumber(quotationItem.taxAmount)?.toDouble(),
            quantity: baseQuantity,
            selectedStock: selectedStock,
            stockGroupIds: quotationItem.productStockId == null
                ? null
                : <int>[quotationItem.productStockId!],
            comment: quotationItem.comment,
            isManualPriceOverride: true,
            saleUnitId: saleUnitId,
            saleUnitName: saleUnitName,
            saleUnitConversionRate: effectiveSaleUnitRate,
          ),
        );
        debugPrint(
            '🧾 [QuotationConvert] Item product=$productId qty=${quotationItem.quantity} baseQty=$baseQuantity price=$price stock=${quotationItem.productStockId} saleUnit=$saleUnitId rate=$effectiveSaleUnitRate');
      }

      if (draftItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'No valid quotation items found',
        );
        return;
      }

      final customer = details.customer;
      final quotationCustomerPhone =
          (customer?.phone?.trim().isNotEmpty ?? false)
              ? customer!.phone
              : quotation.customerPhone;
      final deliveryCharge =
          _parseQuotationNumber(details.deliveryCharge)?.toDouble();
      localProductProvider.loadQuotationDraftForEditing(
        SavedOrder(
          id: 'quotation-$quotationId',
          orderNumber: details.quotationNumber ??
              quotation.quotationNumber ??
              'QT-$quotationId',
          items: draftItems,
          customerId: customer?.isInline == true ? null : customer?.id,
          customerName: customer?.name ?? quotation.customer,
          customerPhone: quotationCustomerPhone,
          createdAt: DateTime.now().toIso8601String(),
          total: _parseQuotationNumber(details.grandTotal)?.toDouble() ??
              _parseQuotationNumber(quotation.grandTotal)?.toDouble() ??
              0.0,
          deliveryMethod: details.deliveryMethod,
          deliveryMethodId: details.deliveryMethodId,
          deliveryCharge: deliveryCharge,
          comment: details.comment,
          address: _stringifyQuotationAddress(details.address),
          flatDiscount: _parseQuotationNumber(details.discount)?.toDouble(),
          customerType: customer?.isInline == true ? 'new' : 'existing',
          quotationId: quotationId,
          quotationNumber: details.quotationNumber ?? quotation.quotationNumber,
        ),
      );
      debugPrint(
          '🧾 [QuotationConvert] Draft loaded. quotationId=$quotationId, cartItems=${draftItems.length}, route=90');

      Get.find<SideBarController>().index.value = 90;
      showScaffold(
        context: context,
        message: 'Quotation loaded in billing. Confirm the order when ready.',
      );
    } catch (e) {
      debugPrint('Error converting quotation: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Failed to load quotation in billing',
        );
      }
    } finally {
      if (mounted) setState(() => _isConvertingQuotation = false);
    }
  }

  Stock? _findQuotationStock(GetProduct product, int? stockId) {
    if (stockId == null) return null;
    for (final stock in product.stock ?? const <Stock>[]) {
      if (stock.id == stockId) return stock;
    }
    return Stock(id: stockId, productId: product.productId);
  }

  SaleUnit? _findQuotationSaleUnit(GetProduct product, int? saleUnitId) {
    if (saleUnitId == null) return null;
    for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
      if (saleUnit.id == saleUnitId) return saleUnit;
    }
    return null;
  }

  String? _stringifyQuotationAddress(dynamic address) {
    if (address == null) return null;
    if (address is String) {
      final trimmed = address.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (address is Map) {
      final parts = <String>[];
      for (final key in [
        'address',
        'address_line',
        'address_line_1',
        'address_line_2',
        'street',
        'city',
        'state',
        'country',
        'postal_code',
        'pincode',
      ]) {
        final value = address[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          parts.add(value.toString().trim());
        }
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final fallback = address.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  num? _parseQuotationNumber(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
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
    final isPhone = quotationsIsPhone(context);
    return Consumer<QuotationsProvider>(
      builder: (context, provider, child) {
        return QuotationsListShell(
          onRefresh: _fetchQuotations,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (!isPhone || _showFilters) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: _buildFiltersCard(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: QuotationsContentCard(
                  padding: EdgeInsets.zero,
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  ColorManager.kPrimaryColor),
                            ),
                          ),
                        )
                      : provider.quotations.isEmpty
                          ? _buildEmptyState(provider)
                          : _buildQuotationsContent(provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final isPhone = quotationsIsPhone(context);

    return QuotationsPageHeader(
      title: 'Quotation List',
      subtitle: 'Search, view and convert quotations to orders',
      leading: isPhone
          ? IconButton(
              icon: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: ColorManager.kPrimaryColor,
              ),
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
            )
          : null,
      trailing: SizedBox(
        width: isPhone ? double.infinity : 160,
        child: CustomRoundButton(
          title: 'New Quotation',
          fct: () {
            Get.find<SideBarController>().index.value = 86;
          },
          fontSize: 12,
          height: 44,
          width: isPhone ? double.infinity : 160,
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    final size = MediaQuery.of(context).size;
    final isPhone = quotationsIsPhone(context);

    return QuotationsContentCard(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuotationsSectionTitle(title: 'Filters'),
          const SizedBox(height: 12),
          if (isPhone) ...[
            buildColumnWidgetForTextFields(
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
            const SizedBox(height: 10),
            _buildCustomerDropdown(),
            const SizedBox(height: 10),
            _buildStoreDropdown(),
            const SizedBox(height: 10),
            BuildDropDownStatic(
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
            const SizedBox(height: 10),
            Column(
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
                  circleRadius: 10,
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
            const SizedBox(height: 10),
            Column(
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
                  circleRadius: 10,
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
            const SizedBox(height: 12),
            CustomRoundButton(
              title: "Reset",
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: _resetFilters,
              height: 44,
              width: double.infinity,
              fontSize: FontSize.s12,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                Expanded(child: _buildCustomerDropdown()),
                const SizedBox(width: 10),
                Expanded(child: _buildStoreDropdown()),
                const SizedBox(width: 10),
                Expanded(
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
                        circleRadius: 10,
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
                        circleRadius: 10,
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
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ],
      ),
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
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.request_quote_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              provider.quotations.isEmpty && !hasFilters
                  ? "No quotations available"
                  : "No quotations match your filters",
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                Colors.grey.shade600,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              CustomRoundButton(
                title: 'Clear filters',
                fct: _resetFilters,
                fontSize: 12,
                height: 44,
                width: 140,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationsContent(QuotationsProvider provider) {
    if (quotationsIsPhone(context)) {
      return _buildMobileList(provider);
    }
    return _buildDesktopTable(provider);
  }

  Widget _buildMobileList(QuotationsProvider provider) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: provider.quotations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMobileQuotationCard(provider.quotations[index]);
      },
    );
  }

  Widget _buildMobileQuotationCard(Quotation q) {
    final status = q.status ?? '';
    final quotationDate = q.quotationDate != null
        ? q.quotationDate!.split(' ').first
        : '—';
    final expiryDate =
        q.expiryDate != null ? q.expiryDate!.split(' ').first : '—';

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.quotationNumber ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.customer ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              QuotationsStatusBadge(
                label: status,
                color: _statusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          QuotationsTwoColumnLayout(
            start: QuotationsInfoChip(
              label: 'Store',
              value: q.store ?? '—',
            ),
            end: QuotationsInfoChip(
              label: 'Quotation Date',
              value: quotationDate,
            ),
          ),
          const SizedBox(height: 10),
          QuotationsInfoChip(
            label: 'Expiry Date',
            value: expiryDate,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              QuotationsIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'View details',
                onPressed: () {
                  Get.find<SideBarController>().index.value = 88;
                  context
                      .read<QuotationsProvider>()
                      .setSelectedQuotationId(q.id);
                },
              ),
              const SizedBox(width: 8),
              QuotationsIconAction(
                icon: Icons.shopping_cart_checkout,
                backgroundColor: Colors.orange.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'Convert to order',
                onPressed: _isConvertingQuotation
                    ? null
                    : () => _convertQuotationToOrder(q),
              ),
              const SizedBox(width: 8),
              QuotationsIconAction(
                icon: Icons.print,
                backgroundColor: Colors.green.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'Print quotation',
                onPressed: _isPrintingQuotation
                    ? null
                    : () => _printQuotation(q),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(QuotationsProvider provider) {
    return QuotationsResponsiveTable(
      minWidth: 900,
      table: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorManager.tableBGColor.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
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
                children: provider.quotations.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Quotation q = entry.value;
                  return _buildTableRow(q, idx);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
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
              child: QuotationsStatusBadge(
                label: status,
                color: _statusColor(status),
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuotationsIconAction(
                    icon: Icons.visibility,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'View details',
                    onPressed: () {
                      Get.find<SideBarController>().index.value = 88;
                      context
                          .read<QuotationsProvider>()
                          .setSelectedQuotationId(q.id);
                    },
                  ),
                  const SizedBox(width: 6),
                  QuotationsIconAction(
                    icon: Icons.shopping_cart_checkout,
                    backgroundColor: Colors.orange.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'Convert to order',
                    onPressed: _isConvertingQuotation
                        ? null
                        : () => _convertQuotationToOrder(q),
                  ),
                  const SizedBox(width: 6),
                  QuotationsIconAction(
                    icon: Icons.print,
                    backgroundColor: Colors.green.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'Print quotation',
                    onPressed: _isPrintingQuotation
                        ? null
                        : () => _printQuotation(q),
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
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s10,
          0.18,
          Colors.black,
        ),
      ),
    );
  }
}
