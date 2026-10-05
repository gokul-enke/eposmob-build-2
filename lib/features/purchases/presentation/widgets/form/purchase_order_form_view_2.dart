part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations2 on PurchaseOrderFormView {
  Widget _buildItemForm() {
    final item = currentItem;
    final categoryProvider = controller.ports.categories;
    final localProductProvider = controller.ports.products;

    return BuildBoxShadowContainer(
      circleRadius: 8,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact row like stock page
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${(_editingItemIndex ?? orderItems.length) + 1}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s10,
                    0.2,
                    Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildInlineField(
                  barcodeController,
                  'purchase_order.barcode'.tr,
                  (v) => item.barcode = v,
                  onSubmitted: _autoFillFromBarcode,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddProductModal(
                  barcode: item.barcode.trim().isEmpty ? null : item.barcode,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: BuildDropDownWithSearch<GetProduct>(
                  title: null,
                  showName: false,
                  hintText: 'purchase_order.select_product'.tr,
                  value: item.productData,
                  items: localProductProvider.products
                      .where(
                        (p) =>
                            item.categoryData == null ||
                            p.categoryId == item.categoryData?.categoryId,
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _applyProductToCurrentItem(val);
                    }
                  },
                  displayText: (val) => val.productName ?? "",
                  searchController: productSearchController,
                  height: 40,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: _buildInlineField(
                  quantityController,
                  item.selectedPurchaseUnit != null
                      ? 'purchase_order.p_qty_hint'.tr
                      : '1',
                  (v) {
                    setState(() {
                      if (item.selectedPurchaseUnit != null) {
                        _syncQtyFromPurchaseUnit();
                      } else {
                        item.quantity = v;
                      }
                    });
                  },
                  isNumber: true,
                  focusNode: quantityFocusNode,
                  keyboardType: allowsDecimalQuantityUnit(
                    item.selectedPurchaseUnit?.unitName ?? item.unit,
                  )
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: quantityInputFormattersForUnit(
                    item.selectedPurchaseUnit?.unitName ?? item.unit,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addItem,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _editingItemIndex != null ? Icons.check : Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() => _showItemDetails = !_showItemDetails);
                  _saveDraftToHive();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _showItemDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),
          if (currentItem.productData?.hasVariants == true)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: _buildVariantSelector(),
            ),
          if ((currentItem.productData?.saleUnits?.isNotEmpty ?? false) ||
              currentItem.selectedPurchaseUnit != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: _buildPurchaseUnitSelector(),
            ),

          if (_showItemDetails) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    'purchase_order.category'.tr,
                    BuildDropDownWithSearch<Category>(
                      title: null,
                      showName: false,
                      hintText: 'purchase_order.select_category'.tr,
                      value: item.categoryData,
                      items: categoryProvider.category ?? [],
                      onChanged: (val) {
                        setState(() => item.categoryData = val);
                        _saveDraftToHive();
                      },
                      displayText: (val) =>
                          val.categoryName ??
                          val.categorySlug ??
                          'purchase_order.unknown'.tr,
                      searchController: categorySearchController,
                      height: 40,
                    ),
                    isRequired: true,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    'purchase_order.unit'.tr,
                    _buildUnitDropdownField(item),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    'purchase_order.purchase_rate'.tr,
                    _buildInlineField(
                      rateController,
                      "0",
                      (v) {
                        setState(() => item.purchaseRate = v);
                        _triggerTaxRecalculation();
                      },
                      isNumber: true,
                      prefixText: '$_currency ',
                    ),
                    isRequired: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Row 2: Retail price | Mrp | Manufacturing Date | Expiry Date
            Row(
              children: [
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.retail_price_lower'.tr,
                    _buildInlineField(
                      retailPriceController,
                      'purchase_order.retail_price_lower'.tr,
                      (v) {
                        setState(() {
                          item.retailPrice = v;
                        });
                        _triggerTaxRecalculation();
                      },
                      isNumber: true,
                      prefixText: '$_currency ',
                    ),
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.mrp_label'.tr,
                    _buildInlineField(
                      mrpController,
                      'purchase_order.mrp'.tr,
                      (v) => item.mrp = v,
                      isNumber: true,
                      prefixText: '$_currency ',
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.manufacturing_date'.tr,
                    CalendarPickerTableCell(
                      onDateSelected: (date) {
                        setState(() => item.pkgMfg = date);
                        _saveDraftToHive();
                      },
                      initialDate: item.pkgMfg,
                      lastDate: item.expDate,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.expiry_date'.tr,
                    CalendarPickerTableCell(
                      key: ValueKey(
                        'expiry-${selectedDate.toIso8601String()}-${item.pkgMfg?.toIso8601String()}',
                      ),
                      onDateSelected: (date) {
                        setState(() => item.expDate = date);
                        _saveDraftToHive();
                      },
                      initialDate: item.expDate,
                      firstDate: item.pkgMfg != null &&
                              item.pkgMfg!.isAfter(selectedDate)
                          ? item.pkgMfg
                          : selectedDate,
                      isForExpiry: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Row 3: Wholesale price | Minimum Units for Wholesale | Rack
            Row(
              children: [
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.wholesale_price_lower'.tr,
                    _buildInlineField(
                      wholesalePriceController,
                      'purchase_order.wholesale_price_lower'.tr,
                      (v) {
                        setState(() {
                          item.wholesalePrice = v;
                        });
                        _triggerTaxRecalculation();
                      },
                      isNumber: true,
                      prefixText: '$_currency ',
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.minimum_units_wholesale'.tr,
                    _buildInlineField(
                      wholesaleMinUnitController,
                      'purchase_order.enter_min_wholesale_units'.tr,
                      (v) => item.wholesaleMinUnit = v,
                      isNumber: true,
                      inputFormatters: quantityInputFormattersForUnit(
                        item.unit,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    'purchase_order.rack'.tr,
                    _buildRackDropdownField(item),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaxDetails(),
            _buildUnitPriceOverrides(item),
          ],
        ],
      ),
    );
  }
}
