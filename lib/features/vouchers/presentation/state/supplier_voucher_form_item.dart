import 'package:flutter/material.dart';

class SupplierVoucherFormItem {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController unitAmountController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

  final FocusNode itemNameFocus = FocusNode();
  final FocusNode unitAmountFocus = FocusNode();
  final FocusNode taxFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode totalFocus = FocusNode();
  final FocusNode plusFocus = FocusNode();

  SupplierVoucherFormItem() {
    unitAmountController.text = "0";
    taxController.text = "0";
    quantityController.text = "1";
    totalController.text = "0";
  }

  void dispose() {
    itemNameController.dispose();
    unitAmountController.dispose();
    taxController.dispose();
    quantityController.dispose();
    totalController.dispose();

    itemNameFocus.dispose();
    unitAmountFocus.dispose();
    taxFocus.dispose();
    quantityFocus.dispose();
    totalFocus.dispose();
    plusFocus.dispose();
  }
}
