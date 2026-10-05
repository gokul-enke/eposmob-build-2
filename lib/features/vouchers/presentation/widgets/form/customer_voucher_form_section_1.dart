part of 'customer_voucher_form_view.dart';

extension _CustomerVoucherFormSection1 on CustomerVoucherFormView {
  List<Widget> _buildItemRows() {
    return form.voucherItems.asMap().entries.map((entry) {
      int index = entry.key;
      CustomerVoucherFormItem item = entry.value;

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
                      initialValue: item.itemName,
                      focusNode: item.itemNameFocus,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) =>
                          form.update(() => item.itemName = value),
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(item.unitAmountFocus);
                      },
                      onTap: () {
                        // Select all text when focused
                        final controller =
                            TextEditingController(text: item.itemName);
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: item.itemName.length,
                        );
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'customer_voucher.item_name_hint'.tr,
                        contentPadding: const EdgeInsets.only(left: 15),
                      ),
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
                      initialValue: item.unitAmount,
                      focusNode: item.unitAmountFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        form.update(() => item.unitAmount = value);
                        form.calculateTotal();
                      },
                      onFieldSubmitted: (_) {
                        // Skip tax if commented out and request quantity directly
                        FocusScope.of(context).requestFocus(item.quantityFocus);
                      },
                      onTap: () {
                        // Select all text when focused
                        final controller =
                            TextEditingController(text: item.unitAmount);
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: item.unitAmount.length,
                        );
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
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
                      initialValue: item.quantity,
                      focusNode: item.quantityFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        form.update(() => item.quantity = value);
                        form.calculateTotal();
                      },
                      onFieldSubmitted: (_) {
                        // Add new item row and focus on its name field
                        form.update(() {
                          form.voucherItems.add(CustomerVoucherFormItem());
                        });
                        // Focus on new item's name field after a short delay
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (!form.alive || !context.mounted) return;
                          if (form.voucherItems.length > index + 1) {
                            FocusScope.of(context).requestFocus(
                                form.voucherItems[index + 1].itemNameFocus);
                          }
                        });
                      },
                      onTap: () {
                        // Select all text when focused
                        final controller =
                            TextEditingController(text: item.quantity);
                        controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: item.quantity.length,
                        );
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '1',
                        contentPadding: EdgeInsets.only(left: 15),
                      ),
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
                    item.totalAmount,
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
                            form.voucherItems.add(CustomerVoucherFormItem());
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
