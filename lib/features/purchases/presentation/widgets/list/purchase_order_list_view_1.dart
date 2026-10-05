part of 'purchase_order_list_view.dart';

extension _PurchaseOrderListView1 on PurchaseOrderListView {
  bool _canReceiveOrder(PurchaseOrderData item) {
    if (item.itemsReceived == null) return false;
    final parts = item.itemsReceived!.split('/');
    if (parts.length != 2) return false;
    final received = int.tryParse(parts[0].trim()) ?? 0;
    final total = int.tryParse(parts[1].trim()) ?? 0;
    return received < total && total > 0;
  }

  String _itemsReceivedLabel(PurchaseOrderData item) {
    if (item.itemsReceived == null || item.itemsReceived!.isEmpty) {
      return 'purchase_order.items_received_default'.tr;
    }
    return item.itemsReceived!;
  }

  Widget _buildFilterToggleButton() {
    return FilterToggleButton(
      key: const ValueKey('purchase-order-filter-toggle'),
      showFilters: controller.showFilters,
      hasActiveFilters: controller.hasActiveFilters,
      activeFiltersListenable: Listenable.merge([
        supplierController,
        storeController,
        fromDateController,
        toDateController,
      ]),
      activeFiltersBuilder: () => controller.hasActiveFilters,
      onPressed: () => controller
          .update(() => controller.showFilters = !controller.showFilters),
      showTooltip: 'purchase_order.show_filters'.tr,
      hideTooltip: 'purchase_order.hide_filters'.tr,
    );
  }

  Widget _buildView() {
    final provider = controller;
    final currency = this.currency;
    final purchases = provider.purchaseOrdersList;
    final currentPage = provider.listPurchaseOrderCurrentPage <= 0
        ? 1
        : provider.listPurchaseOrderCurrentPage;
    final startSerial = (currentPage - 1) * PurchaseOrderListView._itemsPerPage;
    final totalAmount = purchases.fold<double>(0,
        (sum, item) => sum + (double.tryParse(item.amountTotal ?? '0') ?? 0.0));
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersListShell(
      onRefresh: controller.refreshData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(provider),
          const SizedBox(height: 12),
          if (controller.showFilters) ...[
            ConstrainedBox(
              key: const ValueKey('purchase-order-filters'),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    (isPhone ? 0.42 : 0.55),
              ),
              child: SingleChildScrollView(
                child: _buildFiltersCard(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: PurchaseOrdersContentCard(
              padding: EdgeInsets.zero,
              child: initLoading
                  ? _buildLoadingState()
                  : purchases.isEmpty
                      ? _buildEmptyState()
                      : isPhone
                          ? _buildMobileList(
                              purchases: purchases,
                              startSerial: startSerial,
                              currency: currency,
                            )
                          : _buildDesktopTable(
                              purchases: purchases,
                              startSerial: startSerial,
                              currency: currency,
                            ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryFooter(currency: currency, totalAmount: totalAmount),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
            child: PaginationControl(
              currentPage: provider.listPurchaseOrderCurrentPage,
              totalPages: provider.listPurchaseOrderTotalPages,
              onPageChanged: (page) {
                controller.fetchPurchases(page: page);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PurchaseOrderListController provider) {
    final isPhone = purchaseOrdersIsPhone(context);
    final createButton = SizedBox(
      width: isPhone ? double.infinity : 180,
      child: CustomRoundButton(
        key: const ValueKey('purchase-order-create-action'),
        title: 'purchase_order.create_purchase_order_btn'.tr,
        fct: () {
          onCreate();
        },
        fontSize: 12,
        height: 44,
        width: isPhone ? double.infinity : 180,
      ),
    );

    return PurchaseOrdersPageHeader(
      title: 'purchase_order.title'.tr,
      subtitle: 'purchase_order.subtitle'.tr,
      leading: isPhone ? _buildFilterToggleButton() : null,
      trailing: isPhone
          ? createButton
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterToggleButton(),
                const SizedBox(width: 8),
                createButton,
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
              'purchase_order.supplier'.tr,
              supplierController,
              suppliers,
              supplierSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDropdown(
              'purchase_order.store'.tr,
              storeController,
              stores,
              storeSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDate('purchase_order.from_date'.tr, fromDateController,
                expanded: false),
            const SizedBox(height: 10),
            _buildFilterDate('purchase_order.to_date'.tr, toDateController,
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
                    fct: controller.resetSearch,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.apply'.tr,
                    fct: controller.fetchPurchases,
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
                  'purchase_order.supplier'.tr,
                  supplierController,
                  suppliers,
                  supplierSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDropdown(
                  'purchase_order.store'.tr,
                  storeController,
                  stores,
                  storeSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDate(
                    'purchase_order.from_date'.tr, fromDateController),
                const SizedBox(width: 15),
                _buildFilterDate('purchase_order.to_date'.tr, toDateController),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 15),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: controller.resetSearch,
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

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(40),
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(ColorManager.kPrimaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = controller.hasActiveFilters;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFilters
                        ? 'purchase_order.no_orders_match_filters'.tr
                        : 'purchase_order.no_orders_found'.tr,
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
                      title: 'purchase_order.clear_filters'.tr,
                      fct: controller.resetSearch,
                      fontSize: 12,
                      height: 44,
                      width: 140,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
