part of 'purchase_return_list_view.dart';

extension _Section0 on PurchaseReturnListView {
  Widget _buildFilterToggleButton() {
    return FilterToggleButton(
      key: const ValueKey('purchase-return-filter-toggle'),
      showFilters: controller.showFilters,
      hasActiveFilters: controller.hasActiveFilters(),
      activeFiltersListenable: Listenable.merge([
        controller.supplierController,
        controller.fromDateController,
        controller.toDateController,
      ]),
      activeFiltersBuilder: controller.hasActiveFilters,
      onPressed: () => controller
          .update(() => controller.showFilters = !controller.showFilters),
      showTooltip: 'purchase_order.show_filters'.tr,
      hideTooltip: 'purchase_order.hide_filters'.tr,
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
              controller.supplierController,
              controller.suppliers,
              controller.supplierSearchController,
              expanded: false,
            ),
            const SizedBox(height: 10),
            _buildFilterDate(
                'purchase_return.from_date'.tr, controller.fromDateController,
                expanded: false),
            const SizedBox(height: 10),
            _buildFilterDate(
                'purchase_return.to_date'.tr, controller.toDateController,
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
                    fct: controller.resetFilters,
                    height: 44,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.apply'.tr,
                    fct: () => this.controller.fetchReturns(page: 1),
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
                  controller.supplierController,
                  controller.suppliers,
                  controller.supplierSearchController,
                ),
                const SizedBox(width: 15),
                _buildFilterDate('purchase_return.from_date'.tr,
                    controller.fromDateController),
                const SizedBox(width: 15),
                _buildFilterDate(
                    'purchase_return.to_date'.tr, controller.toDateController),
                const SizedBox(width: 15),
                Expanded(
                  child: CustomRoundButton(
                    title: 'purchase_order.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: controller.resetFilters,
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
            this.controller.update(() => controller.text = val ?? "All");
            this.controller.fetchReturns(page: 1);
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
              this.controller.update(() {
                controller.text =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
              this.controller.fetchReturns(page: 1);
            }
          },
          child: AbsorbPointer(
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              height: 45,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'purchase_return.date_hint'.tr,
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

  Widget _buildContent(PurchaseReturnListController provider) {
    if (controller.loadError != null && provider.purchaseReturnsList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        iconColor: Colors.red.shade300,
        title: controller.loadError!,
        titleColor: Colors.red.shade700,
        action: CustomRoundButton(
          title: 'restaurant.retry'.tr,
          fct: controller.fetchReturns,
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

  Widget _buildMobileList(PurchaseReturnListController provider) {
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
}
