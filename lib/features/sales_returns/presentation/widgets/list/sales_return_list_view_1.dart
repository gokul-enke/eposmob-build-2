part of 'sales_return_list_view.dart';

extension _ListSection1 on SalesReturnListSections {
  Widget _buildView() {
    final salesProvider = controller;

    return SalesReturnListShell(
      onRefresh: _fetchSalesReturns,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SalesReturnPageHeader(
            title: 'sales_return.title'.tr,
            subtitle: 'sales_return.subtitle'.tr,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SalesReturnContentCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  _isLoading && salesProvider.salesReturnOrders.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: ColorManager.kPrimaryColor,
                          ),
                        )
                      : _buildSalesReturnContent(salesProvider),
                  if (_isLoading && salesProvider.salesReturnOrders.isNotEmpty)
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
          _buildPaginationControls(salesProvider),
        ],
      ),
    );
  }

  Widget _buildSalesReturnContent(SalesReturnListController salesProvider) {
    if (_loadError != null && salesProvider.salesReturnOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade300,
        title: _loadError!,
        titleColor: Colors.red.shade700,
        action: CustomRoundButton(
          title: 'restaurant.retry'.tr,
          fct: _fetchSalesReturns,
          fontSize: 12,
          height: 44,
          width: 140,
        ),
      );
    }

    if (salesProvider.salesReturnOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_return_outlined,
        iconColor: Colors.grey.shade400,
        title: 'sales_return.no_returns_found'.tr,
        titleColor: Colors.grey.shade600,
        subtitle: 'sales_return.start_return_hint'.tr,
        subtitleColor: Colors.grey.shade500,
      );
    }

    if (salesReturnIsPhone(context)) {
      return _buildMobileList(salesProvider);
    }

    return _buildDesktopTable(salesProvider);
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

  Widget _buildMobileList(SalesReturnListController salesProvider) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: salesProvider.salesReturnOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = salesProvider.salesReturnOrders[index];
        return _buildMobileReturnCard(order);
      },
    );
  }

  void _copyNumber(SalesReturnOrder order) => onCopy(order);

  Widget _buildMobileReturnCard(SalesReturnOrder order) {
    final totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );
    final bool isCompleted =
        order.status.toString() == '1' || order.status.toString() == 'true';
    final orderNumber = order.displayNumber;
    final receiptNumber = order.receiptNumber;

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
                            '#$orderNumber',
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
                        if (orderNumber.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _copyNumber(order),
                            child: const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (receiptNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.originalOrderNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.13,
                          Colors.black54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      DateHelper.formatISODate(order.createdAt.toString()),
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
              SalesReturnStatusBadge(
                label: isCompleted
                    ? 'sales_return.status_completed'.tr
                    : 'sales_return.status_pending'.tr,
                isCompleted: isCompleted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric(
                  'billing.table_qty'.tr,
                  totalQuantity.toString(),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final currency = this.currency;
                    final raw = order.totalAmount;
                    final parsed = double.tryParse(raw);
                    final amount =
                        parsed != null ? parsed.toStringAsFixed(2) : raw;
                    return _buildMobileMetric(
                      'sales_return.return_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SalesReturnIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'billing.view_details'.tr,
                onPressed: () {
                  onView(order);
                },
              ),
              const SizedBox(width: 8),
              SalesReturnIconAction(
                icon: Icons.print,
                backgroundColor: Colors.green.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'sales_return.print_bill_tooltip'.tr,
                onPressed: () {
                  onPrint(order);
                },
              ),
            ],
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
}
