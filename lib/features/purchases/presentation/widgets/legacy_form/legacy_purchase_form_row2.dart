part of 'legacy_purchase_form_view.dart';

extension LegacyFormrow2 on LegacyPurchaseFormView {
  TableRow _row2(BuildContext context, int index, PurchaseItem products) {
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
                  "${products.name}",
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
                child: Text(
                  "${products.unitPrice! * products.quantity!}",
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
                        margin: const EdgeInsets.only(left: 5, right: 5),
                        circleRadius: 5,
                        color: Colors.red.withOpacity(0.9),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () =>
                              controller.deleteItem('${products.id}'),
                        )),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
