part of 'supplier_voucher_form_view.dart';

extension _SupplierVoucherFormSection1 on SupplierVoucherFormView {
  List<Widget> _buildItemRows() {
    return form.voucherItems.asMap().entries.map((entry) {
      int index = entry.key;
      SupplierVoucherFormItem item = entry.value;
      bool isLastItem = index == form.voucherItems.length - 1;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ListenableBuilder(
                listenable: item.itemNameFocus,
                builder: (context, _) {
                  final hasFocus = item.itemNameFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(
                            color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus
                        ? [
                            BoxShadow(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                    child: TextFormField(
                      controller: item.itemNameController,
                      focusNode: item.itemNameFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(item.unitAmountFocus);
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'supplier_voucher.item_name_hint'.tr,
                        contentPadding: const EdgeInsets.only(left: 15),
                      ),
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.27, ColorManager.textColor),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.unitAmountFocus,
                builder: (context, _) {
                  final hasFocus = item.unitAmountFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(
                            color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus
                        ? [
                            BoxShadow(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                    child: TextFormField(
                      controller: item.unitAmountController,
                      focusNode: item.unitAmountFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(item.taxFocus);
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.27, ColorManager.textColor),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.taxFocus,
                builder: (context, _) {
                  final hasFocus = item.taxFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(
                            color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus
                        ? [
                            BoxShadow(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                    child: TextFormField(
                      controller: item.taxController,
                      focusNode: item.taxFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(item.quantityFocus);
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.27, ColorManager.textColor),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.quantityFocus,
                builder: (context, _) {
                  final hasFocus = item.quantityFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(
                            color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus
                        ? [
                            BoxShadow(
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                    child: TextFormField(
                      controller: item.quantityController,
                      focusNode: item.quantityFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        // When Enter is pressed on quantity field, add new item and focus on its name field
                        if (isLastItem &&
                            item.itemNameController.text.isNotEmpty) {
                          form.update(() {
                            var newItem = SupplierVoucherFormItem();
                            form.addItemListeners(newItem);
                            form.voucherItems.add(newItem);
                          });
                          // Focus on the new item's name field after a short delay
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (!form.alive || !context.mounted) return;
                            if (form.voucherItems.length > index + 1) {
                              FocusScope.of(context).requestFocus(
                                  form.voucherItems[index + 1].itemNameFocus);
                            }
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '1',
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.27, ColorManager.textColor),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: Center(
                  child: Text(
                    item.totalController.text,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.27, Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            form.voucherItems.length <= 1 ||
                    form.voucherItems.length == index + 1
                ? ListenableBuilder(
                    listenable: item.plusFocus,
                    builder: (context, _) {
                      final hasFocus = item.plusFocus.hasFocus;
                      return InkWell(
                        focusNode: item.plusFocus,
                        onTap: () {
                          form.update(() {
                            var newItem = SupplierVoucherFormItem();
                            form.addItemListeners(newItem);
                            form.voucherItems.add(newItem);
                          });
                        },
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color:
                                  hasFocus ? Colors.white : Colors.transparent,
                              width: hasFocus ? 2 : 1,
                            ),
                            boxShadow: [
                              if (hasFocus)
                                BoxShadow(
                                  color: ColorManager.kPrimaryColor
                                      .withOpacity(0.55),
                                  blurRadius: 8,
                                  spreadRadius: 2.5,
                                )
                              else
                                const BoxShadow(
                                  color: ColorManager.boxShadowColor,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      form.update(() {
                        // Clean up listeners before removing
                        item.unitAmountController
                            .removeListener(form.calculateTotal);
                        item.taxController.removeListener(form.calculateTotal);
                        item.quantityController
                            .removeListener(form.calculateTotal);
                        item.dispose();
                        form.voucherItems.removeAt(index);
                        form.calculateTotal();
                      });
                    },
                  ),
          ],
        ),
      );
    }).toList();
  }
}
