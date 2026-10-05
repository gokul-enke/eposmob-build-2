part of 'purchase_view.dart';

extension LegacyPurchaseListSection2 on LegacyPurchaseListView {
  Widget _buildPurchaseList(
      Size size, LegacyPurchaseListActions purchaseProvider) {
    debugPrint("_buildPurchaseList called");

    try {
      return BuildBoxShadowContainer(
        margin: const EdgeInsets.only(top: 20),
        circleRadius: 7,
        child: initLoading
            ? _buildLoadingTable()
            : _buildDataTable(size, purchaseProvider),
      );
    } catch (e) {
      debugPrint("Error in _buildPurchaseList: $e");
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text('purchase.error_loading_list'.tr),
        ),
      );
    }
  }

  // Loading table placeholder
  Widget _buildLoadingTable() {
    // Similar loading structure can be added here
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30.0),
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }

  // Data Table building logic
  Widget _buildDataTable(
      Size size, LegacyPurchaseListActions purchaseProvider) {
    debugPrint("Building data table");
    debugPrint("PURCHASE DETAILS LIST before access: $purchaseDetailsList");
    debugPrint("purchaseProvider: $purchaseProvider");

    try {
      debugPrint("purchaseDetailsList length: ${purchaseDetailsList.length}");
      debugPrint(
          "purchaseDetailsList type: ${purchaseDetailsList.runtimeType}");

      return Table(
        columnWidths: const {
          0: FractionColumnWidth(0.01),
          1: FractionColumnWidth(0.06),
          2: FractionColumnWidth(0.06),
          3: FractionColumnWidth(0.06),
        },
        border: const TableBorder.symmetric(
          outside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.3),
          inside: BorderSide(color: ColorManager.tableBOrderColor, width: 0.8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildTableHeader(),
          if (purchaseDetailsList.isNotEmpty)
            ...purchaseDetailsList.asMap().entries.map((entry) {
              return _buildTableRow(entry.key, entry.value, purchaseProvider);
            }).toList()
          else
            TableRow(children: [
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Center(
                    child: Text(
                      'purchase.no_data'.tr,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.18, ColorManager.textColor),
                    ),
                  ),
                ),
              ),
              TableCell(child: Container()),
              TableCell(child: Container()),
              TableCell(child: Container()),
            ]),
        ],
      );
    } catch (e) {
      debugPrint("Error in _buildDataTable: $e");
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            'purchase.error_building_table'.trParams({'error': '$e'}),
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.18, ColorManager.textColor),
          ),
        ),
      );
    }
  }

  // Table Header
  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: [
        _buildTableCell('purchase.col_no'.tr),
        _buildTableCell('purchase.col_purchaser_name'.tr),
        _buildTableCell('purchase.col_amount'.tr),
        _buildTableCell('purchase.col_action'.tr),
      ],
    );
  }

  // Build individual table cell for headers & rows
  TableCell _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.18, ColorManager.textColor),
          ),
        ),
      ),
    );
  }

  // Building rows of the data table
  TableRow _buildTableRow(int index, PurchaseItem purchase,
      LegacyPurchaseListActions purchaseProvider) {
    // Handle possible null values in the purchase item
    final unitPrice = purchase.unitPrice ?? 0;
    final quantity = purchase.quantity?.toInt() ?? 0;

    return TableRow(
      children: [
        _buildTableCell((index + 1).toString()),
        _buildTableCell('purchase.sales_executive'.tr),
        _buildTableCell("${unitPrice * quantity}"),
        _buildActionCell(purchase, purchaseProvider)
      ],
    );
  }

  // Action cell with icons
  TableCell _buildActionCell(
      PurchaseItem purchase, LegacyPurchaseListActions purchaseProvider) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Row(
            children: [
              BuildBoxShadowContainer(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                circleRadius: 5,
                child: IconButton(
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                  ),
                  onPressed: () {
                    // debugPrint("purchase.voucherId ${purchase.voucherId}");
                    // debugPrint("purchase.purchaseId ${purchase.purchaseId}");
                    purchaseProvider.callVoucherDetails(
                        voucherId: purchase.voucherId ?? 0,
                        purchaseId: purchase.purchaseId ?? 0);
                    PurchaseNavigation.openDetails();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pagination
  Widget _buildPagination(BuildContext context) {
    debugPrint("_buildPagination called");
    try {
      debugPrint("Setting up pagination control");
      final currentPage = controller.currentPage;
      final totalPages = controller.totalPages;

      debugPrint(
          "Pagination: currentPage=$currentPage, totalPages=$totalPages");

      return PaginationControl(
        currentPage: currentPage,
        totalPages: totalPages,
        onPageChanged: (int page) {
          debugPrint("Page changed to: $page");
          controller.load(page);
        },
      );
    } catch (e) {
      debugPrint("Error setting up pagination: $e");
      return const SizedBox.shrink(); // Empty widget if pagination fails
    }
  }
}
