import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/purchase_return_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';
import 'package:pos_machine/screens/purchase_return/widgets/purchase_return_detail_modal.dart';
import 'package:provider/provider.dart';

class PurchaseReturnListScreen extends StatefulWidget {
  const PurchaseReturnListScreen({super.key});

  @override
  State<PurchaseReturnListScreen> createState() =>
      _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  int currentPage = 1;
  bool _isLoading = true;
  String? _loadError;
  bool _showFilters = false;

  final TextEditingController supplierController = TextEditingController();
  final TextEditingController supplierSearchController =
      TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  List<String> suppliers = ["All"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showFilters = !purchaseOrdersIsPhone(context);
        });
      }
    });
    supplierController.text = "All";
    _loadInitData();
  }

  @override
  void dispose() {
    supplierController.dispose();
    supplierSearchController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadInitData() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;
      if (token != null && token.isNotEmpty) {
        await provider.listAllSuppliers(token, null);
        if (mounted) {
          setState(() {
            suppliers = [
              "All",
              ...provider.supplierList
                  .map((e) => e.user?.name ?? e.name ?? "")
            ];
          });
        }
        await provider.listPurchaseReturns(accessToken: token, page: 1);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'purchase_return.err_load'.tr;
        });
        showScaffoldError(context: context, message: _loadError!);
      }
    }
  }

  Future<void> _fetchReturns({int? page}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;

      String? selectedSupplierId;
      if (supplierController.text != "All") {
        final supplier = provider.supplierList.firstWhere(
            (s) => (s.user?.name ?? s.name ?? "") == supplierController.text,
            orElse: () => provider.supplierDemo);
        if ((supplier.id ?? 0) > 0) {
          selectedSupplierId = supplier.id?.toString();
        }
      }

      final String? dateFrom = fromDateController.text.trim().isEmpty
          ? null
          : fromDateController.text.trim();
      final String? dateTo = toDateController.text.trim().isEmpty
          ? null
          : toDateController.text.trim();

      await provider.listPurchaseReturns(
        accessToken: token ?? '',
        page: page ?? currentPage,
        supplierId: selectedSupplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (mounted) {
        setState(() {
          if (page != null) currentPage = page;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'purchase_return.err_load'.tr;
        });
        showScaffoldError(
          context: context,
          message: _loadError!,
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      supplierController.text = "All";
      fromDateController.clear();
      toDateController.clear();
      currentPage = 1;
    });
    _fetchReturns(page: 1);
  }

  bool _hasActiveFilters() {
    return supplierController.text != "All" ||
        fromDateController.text.isNotEmpty ||
        toDateController.text.isNotEmpty;
  }

  Widget _buildFilterToggleButton() {
    final hasFilters = _hasActiveFilters();
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: ColorManager.kPrimaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: _showFilters
                ? 'purchase_order.hide_filters'.tr
                : 'purchase_order.show_filters'.tr,
          ),
          if (hasFilters)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PurchaseProvider>(context);
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersListShell(
      onRefresh: () async => _resetFilters(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PurchaseOrdersPageHeader(
            title: 'purchase_return.title'.tr,
            subtitle: 'purchase_return.subtitle'.tr,
            leading: isPhone ? _buildFilterToggleButton() : null,
            trailing: CustomRoundButton(
              title: 'purchase_return.create_btn'.tr,
              fct: () {
                sideBarController.index.value = 100;
              },
              fontSize: 12,
              height: 44,
              width: isPhone ? double.infinity : 200,
            ),
          ),
          const SizedBox(height: 12),
          if (!isPhone || _showFilters) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(child: _buildFiltersCard()),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: PurchaseOrdersContentCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  _isLoading && provider.purchaseReturnsList.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorManager.kPrimaryColor,
                          ),
                        )
                      : _buildContent(provider),
                  if (_isLoading && provider.purchaseReturnsList.isNotEmpty)
                    Container(
                      color: Colors.white.withOpacity(0.6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PaginationControl(
            currentPage: provider.purchaseReturnCurrentPage,
            totalPages: provider.purchaseReturnTotalPages,
            onPageChanged: (page) => _fetchReturns(page: page),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersContentCard(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PurchaseOrdersSectionTitle(title: 'purchase_order.filters'.tr),
          const SizedBox(height: 12),
          if (isPhone) ...[
            _buildFilterDropdown(
              'purchase_return.supplier'.tr,
              supplierController,
              suppliers,
              supplierSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDate(
                'purchase_return.from_date'.tr, fromDateController,
                expanded: false),
            const SizedBox(height: 10),
            _buildFilterDate(
                'purchase_return.to_date'.tr, toDateController,
                expanded: false),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: _resetFilters,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.apply'.tr,
                    fct: () => _fetchReturns(page: 1),
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFilterDropdown(
                  'purchase_return.supplier'.tr,
                  supplierController,
                  suppliers,
                  supplierSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDate(
                    'purchase_return.from_date'.tr, fromDateController),
                const SizedBox(width: 15),
                _buildFilterDate(
                    'purchase_return.to_date'.tr, toDateController),
                const SizedBox(width: 15),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: _resetFilters,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    TextEditingController controller,
    List<String> items,
    TextEditingController searchController, {
    bool expanded = true,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 5),
        BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: 'purchase_order.hint_all'.tr,
          value: controller.text == "All" ? null : controller.text,
          items: items.where((e) => e != "All").toList(),
          onChanged: (val) {
            setState(() => controller.text = val ?? "All");
            _fetchReturns(page: 1);
          },
          displayText: (val) => val,
          searchController: searchController,
          height: 45,
          margin: EdgeInsets.zero,
        ),
      ],
    );
    return expanded ? Expanded(child: field) : field;
  }

  Widget _buildFilterDate(
    String label,
    TextEditingController controller, {
    bool expanded = true,
  }) {
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            DateTime? picked = await showAutoDismissDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                controller.text =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
              _fetchReturns(page: 1);
            }
          },
          child: AbsorbPointer(
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              alignment: Alignment.centerLeft,
              padding:
                  const EdgeInsetsDirectional.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "yyyy-mm-dd",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        ColorManager.textColor,
                      ),
                      readOnly: true,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return expanded ? Expanded(child: field) : field;
  }

  Widget _buildContent(PurchaseProvider provider) {
    if (_loadError != null && provider.purchaseReturnsList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade300,
        title: _loadError!,
        titleColor: Colors.red.shade700,
        action: CustomRoundButton(
          title: 'restaurant.retry'.tr,
          fct: _fetchReturns,
          fontSize: 12,
          height: 44,
          width: 140,
        ),
      );
    }

    if (provider.purchaseReturnsList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_return_outlined,
        iconColor: Colors.grey.shade400,
        title: 'purchase_return.no_returns_found'.tr,
        titleColor: Colors.grey.shade600,
        subtitle: 'purchase_return.start_return_hint'.tr,
        subtitleColor: Colors.grey.shade500,
      );
    }

    if (purchaseOrdersIsPhone(context)) {
      return _buildMobileList(provider);
    }

    return _buildDesktopTable(provider);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    String? subtitle,
    Color? subtitleColor,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.25,
                titleColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.25,
                  subtitleColor ?? Colors.grey.shade500,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(PurchaseProvider provider) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: provider.purchaseReturnsList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = provider.purchaseReturnsList[index];
        return _buildMobileCard(item);
      },
    );
  }

  Widget _buildMobileCard(PurchaseReturnData item) {
    final isCompleted = item.status == 'completed';

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.reference ?? '#${item.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text: item.reference ?? item.id.toString(),
                            ));
                            showScaffold(
                              context: context,
                              message: 'purchase_return.copy_success'.tr,
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
                    Text(
                      '${item.supplier?.name ?? '-'} • ${item.returnDate ?? ''}',
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
              _buildStatusBadge(isCompleted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric(
                  'purchase_return.voucher_number'.tr,
                  item.voucherNumber ?? '-',
                ),
              ),
              Expanded(
                child: Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final currency = settings.appSettings?.currency ?? 'INR';
                    final amount =
                        item.totalAmount?.toStringAsFixed(2) ?? '0.00';
                    return _buildMobileMetric(
                      'purchase_return.total_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PurchaseOrdersIconAction(
              icon: Icons.visibility,
              backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
              iconColor: Colors.white,
              tooltip: 'billing.view_details'.tr,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      PurchaseReturnDetailModal(returnData: item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetric(String label, String value) {
    return Column(
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
            FontWeightManager.semiBold,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(PurchaseProvider provider) {
    return PurchaseOrdersResponsiveTable(
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
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.3),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(0.8),
              },
              children: [_buildTableHeader()],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.purchaseReturnsList.length,
              itemBuilder: (context, index) {
                final item = provider.purchaseReturnsList[index];
                return Table(
                  border: TableBorder(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.12),
                    ),
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(1.3),
                    5: FlexColumnWidth(1),
                    6: FlexColumnWidth(0.8),
                  },
                  children: [_buildTableRow(item, index)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      children: [
        'purchase_return.reference'.tr,
        'purchase_return.voucher_number'.tr,
        'purchase_return.supplier'.tr,
        'purchase_return.return_date'.tr,
        'purchase_return.total_amount'.tr,
        'purchase_return.status'.tr,
        'sales_return.action'.tr,
      ]
          .map((title) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(14),
                  child: Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  TableRow _buildTableRow(PurchaseReturnData item, int index) {
    final isCompleted = item.status == 'completed';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.withOpacity(0.04),
      ),
      children: [
        _tableCell(item.reference ?? '-'),
        _tableCell(item.voucherNumber ?? '-'),
        _tableCell(item.supplier?.name ?? '-'),
        _tableCell(item.returnDate ?? '-'),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(
              child: Consumer<AppSettingsProvider>(
                builder: (context, settings, _) {
                  final currency = settings.appSettings?.currency ?? 'INR';
                  final amount =
                      item.totalAmount?.toStringAsFixed(2) ?? '0.00';
                  return Text(
                    '$currency $amount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.13,
                      Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(child: _buildStatusBadge(isCompleted)),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Center(
              child: PurchaseOrdersIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'billing.view_details'.tr,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        PurchaseReturnDetailModal(returnData: item),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableCell _tableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCompleted) {
    final color =
        isCompleted ? Colors.green.shade700 : Colors.orange.shade800;
    final bgColor = isCompleted
        ? Colors.green.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1);
    final label = isCompleted
        ? 'purchase_return.status_completed'.tr
        : 'purchase_return.status_pending'.tr;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.13,
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
