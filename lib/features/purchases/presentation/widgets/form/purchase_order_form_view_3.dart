part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations3 on PurchaseOrderFormView {
  Widget _buildUnitPriceOverrides(PurchaseOrderItem item) {
    final saleUnits = item.productData?.saleUnits ?? const <SaleUnit>[];
    final unitIds = <int>{
      ...saleUnits.map((unit) => unit.id).whereType<int>(),
      ...item.unitPriceOverrides.keys,
    }.toList();
    if (unitIds.isEmpty) return const SizedBox.shrink();

    String unitLabel(int id) {
      for (final unit in saleUnits) {
        if (unit.id == id) {
          final name = unit.unitName?.trim();
          return (name == null || name.isEmpty) ? 'Sale unit #$id' : name;
        }
      }

      return 'Sale unit #$id';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'purchase_order.label_sale_unit_overrides'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.2,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: unitIds.map((id) {
              final existing = item.unitPriceOverrides[id];
              return SizedBox(
                width: 230,
                child: TextFormField(
                  key: ValueKey('unit-price-$id-$existing'),
                  initialValue: existing?.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: unitLabel(id),
                    hintText: 'purchase_order.hint_use_default_price'.tr,
                    prefixText: '$_currency ',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final price = double.tryParse(text);
                    return price == null || price < 0
                        ? 'purchase_order.error_invalid_price'.tr
                        : null;
                  },
                  onChanged: (value) {
                    final price = double.tryParse(value.trim());
                    if (price == null) {
                      item.unitPriceOverrides.remove(id);
                    } else {
                      item.unitPriceOverrides[id] = price;
                    }
                    _saveDraftToHive();
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineField(
    TextEditingController controller,
    String hint,
    Function(String) onChanged, {
    bool isNumber = false,
    String? prefixText,
    ValueChanged<String>? onSubmitted,
    TextInputAction textInputAction = TextInputAction.next,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(
        // Wrap with Center
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onChanged: (value) {
            onChanged(value);
            _saveDraftToHive();
          },
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType: keyboardType ??
              (isNumber ? TextInputType.number : TextInputType.text),
          inputFormatters: inputFormatters,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
            prefixText: prefixText,
            prefixStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.2,
              Colors.grey,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            isCollapsed: true, // Replaces isDense and zero padding
          ),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdownField(PurchaseOrderItem item) {
    final baseUnitName = item.productData?.unit ?? item.unit;
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        baseUnitName.isNotEmpty ? baseUnitName : "-",
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPurchaseUnitSelector() {
    final selectedUnit = currentItem.selectedPurchaseUnit;
    final saleUnits = <SaleUnit>[
      ...?currentItem.productData?.saleUnits,
      if (selectedUnit != null &&
          !(currentItem.productData?.saleUnits ?? const <SaleUnit>[]).any(
            (unit) => unit.id == selectedUnit.id,
          ))
        selectedUnit,
    ];

    // Auto-calculate stock qty:
    final purchaseQty = double.tryParse(quantityController.text.trim()) ?? 1.0;
    final conversionRate =
        double.tryParse(selectedUnit?.conversionRate ?? '1') ?? 1.0;
    final calculatedStockQty = purchaseQty * conversionRate;
    final stockQtyStr = calculatedStockQty.toStringAsFixed(
      calculatedStockQty.truncateToDouble() == calculatedStockQty ? 0 : 3,
    );
    final baseUnitName = currentItem.productData?.unit ?? currentItem.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'purchase_order.select_purchase_unit_label'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildDropDownWithSearch<SaleUnit>(
          title: null,
          hintText: 'purchase_order.select_purchase_unit_hint'.tr,
          value: selectedUnit,
          items: saleUnits,
          onChanged: (val) {
            _selectPurchaseUnit(val);
          },
          displayText: (val) => "${val.unitName} (x${val.conversionRate})",
          searchController: purchaseUnitSearchController,
          height: 40,
        ),
        if (selectedUnit != null) ...[
          const SizedBox(height: 4),
          Text(
            'purchase_order.stock_qty_prefix'
                .tr
                .replaceAll('@qty', stockQtyStr)
                .replaceAll(
                  '@unit',
                  baseUnitName.isNotEmpty
                      ? baseUnitName
                      : 'purchase_order.pc_fallback'.tr,
                ),
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.2,
              Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRackDropdownField(PurchaseOrderItem item) {
    return Builder(
      builder: (context) {
        final rackList = controller.ports.purchases.getMasterDataValues;
        final rackKeys = rackList?.keys.toList() ?? <String>[];
        final selectedValue = item.selectedRack ??
            (rackKeys.contains(item.rack) ? item.rack : null);

        return BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: 'purchase_order.select_rack'.tr,
          value: selectedValue,
          items: rackKeys,
          onChanged: (val) {
            setState(() {
              item.selectedRack = val;
              item.rack = (val != null) ? (rackList?[val] ?? val) : '';
            });
            rackController.text = item.rack;
            _saveDraftToHive();
          },
          displayText: (val) => rackList?[val] ?? val,
          searchController: rackSearchController,
          height: 40,
        );
      },
    );
  }

  /// Calculate tax for the current item using the server API (same as stock page)
}
