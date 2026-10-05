part of 'purchase_voucher_view.dart';

extension LegacyVoucherTable2 on LegacyPurchaseVoucherListView {
  Widget _buildVoucherTable2() => Table(
        columnWidths: const {
          0: FractionColumnWidth(0.01),
          1: FractionColumnWidth(0.06),
          2: FractionColumnWidth(0.06),
          3: FractionColumnWidth(0.06),
          4: FractionColumnWidth(0.06),
          5: FractionColumnWidth(0.06),
          6: FractionColumnWidth(0.05),
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
                        'purchase_voucher.col_no'.tr,
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
                        'purchase_voucher.col_purchase_date'.tr,
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
                        'purchase_voucher.col_store'.tr,
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
                        'purchase_voucher.col_supplier'.tr,
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
                        'purchase_voucher.col_amount'.tr,
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
                        'purchase_voucher.col_action'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.18,
                          ColorManager.kPrimaryColor,
                        ),
                      )),
                    )),
              ]),
          ...voucherModelListData!
              .where((transaction) {
                return transaction.purchaseDate!
                        .contains(searchTextController.text) ||
                    transaction.amountTotal
                        .toString()
                        .contains(searchTextController.text);
              })
              .toList()
              .asMap()
              .entries
              .map((entry) {
                int index = entry.key;
                var voucher = entry.value;
                String store = actions.storeName(voucher.storeId ?? 1) ?? '';
                String supplier =
                    actions.supplierName(voucher.supplierId ?? 1) ?? '';
                return TableRow(
                  children: [
                    TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Center(
                            child: Text(
                              (index + 1).toString(),
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
                              voucher.purchaseDate ?? "",
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
                              store,
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
                              supplier,
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
                              "${voucher.amountTotal}",
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
                                    margin: const EdgeInsets.only(
                                        left: 5, right: 5),
                                    circleRadius: 5,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.visibility,
                                        size: 18,
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.9),
                                      ),
                                      onPressed: () {
                                        actions.callVoucherDetails(
                                            voucherId: voucher.id ?? 0,
                                            purchaseId:
                                                voucher.purchaseId ?? 0);
                                        PurchaseNavigation
                                            .openLegacyVoucherDetails();
                                      },
                                    )),
                                BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        left: 5, right: 5),
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.9),
                                    circleRadius: 5,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        actions.callVoucherDetails(
                                            voucherId: voucher.id ?? 0,
                                            purchaseId:
                                                voucher.purchaseId ?? 0);
                                        onAddVoucher();
                                      },
                                    )),
                              ],
                            ),
                          ),
                        )),
                  ],
                );
              })
              .toList(),
        ],
      );
}
