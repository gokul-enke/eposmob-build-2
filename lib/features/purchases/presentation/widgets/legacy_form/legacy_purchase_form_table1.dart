part of 'legacy_purchase_form_view.dart';

extension LegacyFormtable1 on LegacyPurchaseFormView {
  Widget _table1(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FractionColumnWidth(0.01),
        1: FractionColumnWidth(0.08),
        2: FractionColumnWidth(0.02),
        3: FractionColumnWidth(0.06),
        4: FractionColumnWidth(0.06),
        5: FractionColumnWidth(0.06),
        6: FractionColumnWidth(0.06),
        7: FractionColumnWidth(0.05),
      },
      border: const TableBorder.symmetric(
          outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
          inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row1(context),

        // Map your order data to table rows here
        ...purchaseItemList!.toList().asMap().entries.map((entry) {
          int index = entry.key;
          var products = entry.value;

          return _row2(context, index, products);
        }).toList(),
      ],
    );
  }
}
