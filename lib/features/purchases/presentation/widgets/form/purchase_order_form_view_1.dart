part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations1 on PurchaseOrderFormView {
  ScrollBehavior get _horizontalDragScrollBehavior {
    return const MaterialScrollBehavior().copyWith(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
    );
  }

  Widget _disableInteraction(Widget child, {required bool disabled}) {
    if (!disabled) return child;
    return Opacity(
      opacity: 0.7,
      child: IgnorePointer(ignoring: true, child: child),
    );
  }

  Widget _buildVariantSelector() {
    final product = currentItem.productData;
    if (product == null || !product.hasVariants) {
      return const SizedBox.shrink();
    }
    final variants = product.variants ?? [];
    final selected = variants.firstWhereOrNull(
      (v) => v.id == currentItem.productVariantId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'purchase_order.select_variant_required'.tr,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildDropDownWithSearch<ProductVariant>(
          title: null,
          hintText: 'purchase_order.select_product_variant_hint'.tr,
          value: selected,
          items: variants,
          onChanged: (variant) {
            setState(() {
              currentItem.productVariantId = variant?.id;
              currentItem.variantName =
                  variant != null ? _variantLabel(variant) : null;
              if (currentItem.productData?.saleUnits != null &&
                  currentItem.productData!.saleUnits!.isNotEmpty) {
                _showItemDetails = false;
              }
              if (variant != null) {
                if (variant.barcode != null && variant.barcode!.isNotEmpty) {
                  currentItem.barcode = variant.barcode!;
                  barcodeController.text = variant.barcode!;
                }
                if (variant.purchasePrice != null) {
                  rateController.text = variant.purchasePrice.toString();
                  currentItem.purchaseRate = variant.purchasePrice.toString();
                } else if (variant.price != null) {
                  rateController.text = variant.price.toString();
                  currentItem.purchaseRate = variant.price.toString();
                }
                if (variant.mrp != null) {
                  mrpController.text = variant.mrp.toString();
                  currentItem.mrp = variant.mrp.toString();
                }
              } else {
                currentItem.barcode = currentItem.productData?.barcode ?? '';
                barcodeController.text = currentItem.barcode;
              }
            });
            _triggerTaxRecalculation();
          },
          displayText: _variantLabel,
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildView() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: FocusTraversalGroup(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: onBack,
                    text: 'purchase_order.back_to_purchase_orders'.tr,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isReceiveMode
                        ? 'purchase_order.receive_purchase_order'.tr
                        : 'purchase_order.create_new_purchase_order'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.3,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildProductDetailsTitle(),
                  _buildItemForm(),
                  const SizedBox(height: 20),
                  _buildAddedItemsTable(),
                  const SizedBox(height: 20),
                  _buildItemsToReceivePreview(),
                  const SizedBox(height: 20),
                  _buildPaymentSection(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldColumn(
    String title,
    Widget child, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: title,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.2,
              ColorManager.textColor,
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _buildHeader() {
    final purchaseProvider = controller.ports.purchases;

    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: _buildFieldColumn(
                'purchase_order.purchase_date'.tr,
                _disableInteraction(
                  CalendarPickerTableCell(
                    onDateSelected: (date) {
                      setState(() => selectedDate = date);
                      _saveDraftToHive();
                    },
                    initialDate: selectedDate,
                  ),
                  disabled: _isHeaderLockedForReceive,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                'purchase_order.voucher_number'.tr,
                _buildInlineField(
                  voucherNumberController,
                  "",
                  (v) {},
                  readOnly: _isHeaderLockedForReceive,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                'purchase_order.store'.tr,
                _disableInteraction(
                  BuildDropDownWithSearch<GetStoreModelData>(
                    title: null,
                    showName: false,
                    hintText: 'purchase_order.select_store'.tr,
                    value: selectedStore,
                    items: purchaseProvider.getStoreList ?? [],
                    onChanged: (val) {
                      setState(() => selectedStore = val);
                      _saveDraftToHive();
                    },
                    displayText: (val) => val.name ?? "",
                    searchController: storeSearchController,
                    height: 40,
                  ),
                  disabled: _isHeaderLockedForReceive,
                ),
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldColumn(
                    'purchase_order.supplier'.tr,
                    _disableInteraction(
                      Row(
                        children: [
                          Expanded(
                            child:
                                BuildDropDownWithSearch<GetSuppliersModelData>(
                              title: null,
                              showName: false,
                              hintText: 'purchase_order.select_supplier'.tr,
                              value: selectedSupplier,
                              items: purchaseProvider.getSupplierList ?? [],
                              onChanged: (val) {
                                setState(() => selectedSupplier = val);
                                _saveDraftToHive();
                              },
                              displayText: (val) =>
                                  val.user?.name ?? val.name ?? "",
                              searchController: supplierSearchController,
                              height: 40,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add Supplier Button
                          BuildBoxShadowContainer(
                            height: 40,
                            width: 40,
                            circleRadius: 5,
                            child: InkWell(
                              onTap: _addSupplier,
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 27,
                                  color: ColorManager.kButtonGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      disabled: _isHeaderLockedForReceive,
                    ),
                    isRequired: true,
                  ),
                  if (selectedSupplier != null) ...[
                    const SizedBox(height: 6),
                    _buildSupplierBalanceDisplay(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                'purchase_order.invoice_reference'.tr,
                _buildInlineField(
                  invoiceRefController,
                  "",
                  (v) {},
                  readOnly: _isHeaderLockedForReceive,
                ),
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildProductDetailsTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.30)),
      ),
      child: Text(
        _isReceiveMode
            ? 'purchase_order.pending_item_editor'.tr
            : 'purchase_order.product_details'.tr,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s14,
          0.27,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }
}
