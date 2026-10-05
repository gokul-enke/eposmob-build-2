part of 'purchase_order_list_view.dart';

extension _PurchaseOrderListView3 on PurchaseOrderListView {
  Widget _buildSummaryFooter({
    required String currency,
    required double totalAmount,
  }) {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersContentCard(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isPhone ? 14 : 20,
        vertical: isPhone ? 14 : 16,
      ),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'purchase_order.summary'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s14,
                    0.2,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'purchase_order.total_price'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        Colors.grey,
                      ),
                    ),
                    Text(
                      "$currency ${totalAmount.toStringAsFixed(2)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  'purchase_order.summary'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s14,
                    0.2,
                    ColorManager.textColor,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'purchase_order.total_price'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        Colors.grey,
                      ),
                    ),
                    Text(
                      "$currency ${totalAmount.toStringAsFixed(2)}",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.textColor,
                      ),
                    ),
                  ],
                ),
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
            this.controller.fetchPurchases();
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
              this.controller.fetchPurchases();
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
                        hintText: 'purchase_order.date_format_hint'.tr,
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

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 16.0,
          horizontal: 8.0,
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(15.0),
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

  Widget _buildActionCell({
    required PurchaseOrderData item,
    required bool canReceive,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PurchaseOrdersIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'purchase_order.view_order_tooltip'.tr,
                onPressed: () => onOpen(item, 36),
              ),
              if (canReceive) ...[
                const SizedBox(width: 4),
                PurchaseOrdersIconAction(
                  icon: Icons.add,
                  backgroundColor: const Color(0xFFE7F8EC),
                  iconColor: Colors.green,
                  tooltip: 'purchase_order.receive_items_tooltip'.tr,
                  onPressed: () => onOpen(item, 82),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
