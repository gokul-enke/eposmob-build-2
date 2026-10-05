part of 'legacy_purchase_form_view.dart';

extension LegacyFormrow1 on LegacyPurchaseFormView {
  TableRow _row1(BuildContext context) {
    return TableRow(
        decoration: const BoxDecoration(color: ColorManager.tableBGColor),
        children: [
          TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Center(
                    child: Text(
                  'add_purchase.col_no'.tr,
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
                  'add_purchase.col_product_name'.tr,
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
                  'add_purchase.col_quantity'.tr,
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
                  'add_purchase.col_supplier_name'.tr,
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
                  'add_purchase.col_store_name'.tr,
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
                  'add_purchase.col_price'.tr,
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
                  'add_purchase.col_total_price'.tr,
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
                  'add_purchase.col_action'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    ColorManager.kPrimaryColor,
                  ),
                )),
              )),
        ]);
  }
}
