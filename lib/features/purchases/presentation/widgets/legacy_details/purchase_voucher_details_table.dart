part of 'purchase_voucher_details_view.dart';

extension LegacyVoucherDetailsTable on LegacyPurchaseVoucherDetailsView {
  Widget _buildItemsTable(List<PurchaseItem>? filteredItems) => Table(
        columnWidths: const {
          0: FractionColumnWidth(0.08),
          1: FractionColumnWidth(0.01),
          2: FractionColumnWidth(0.02),
          3: FractionColumnWidth(0.06),
          4: FractionColumnWidth(0.06),
          5: FractionColumnWidth(0.05),
        },
        border: const TableBorder.symmetric(
            outside:
                BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
            inside:
                BorderSide(color: ColorManager.tableBOrderColor, width: 0.8)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
              decoration: const BoxDecoration(color: ColorManager.tableBGColor),
              children: [
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                          child: Text(
                        'view_voucher.col_product_name'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                          child: Text(
                        'view_voucher.col_quantity'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                          child: Text(
                        'view_voucher.col_unit'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                          child: Text(
                        'view_voucher.col_unit_price'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                          child: Text(
                        'view_voucher.col_action'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
              ]),

          // Map your order data to table rows here
          ...filteredItems!.map((products) {
            String itemName = productName(products.productId ?? 0) ?? "";
            return TableRow(
              children: [
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                        child: Text(
                          itemName,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s9,
                            0.13,
                            Colors.black,
                          ),
                        ),
                      ),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                        child: Text(
                          "${products.quantity}",
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s9,
                            0.13,
                            Colors.black,
                          ),
                        ),
                      ),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                        child: Text(
                          "${products.unit}",
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s9,
                            0.13,
                            Colors.black,
                          ),
                        ),
                      ),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                        child: Text(
                          "${products.unitPrice}",
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s9,
                            0.13,
                            Colors.black,
                          ),
                        ),
                      ),
                    )),
                TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Center(
                        child: Row(
                          children: [
                            BuildBoxShadowContainer(
                                margin:
                                    const EdgeInsets.only(left: 5, right: 5),
                                circleRadius: 5,
                                color:
                                    ColorManager.kPrimaryColor.withOpacity(0.9),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {},
                                )),
                          ],
                        ),
                      ),
                    )),
              ],
            );
          }).toList(),
        ],
      );
}
