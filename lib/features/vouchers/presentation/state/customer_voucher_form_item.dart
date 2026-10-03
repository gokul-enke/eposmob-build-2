import 'package:flutter/material.dart';

class CustomerVoucherFormItem {
  String itemName;
  String unitAmount;
  String tax;
  String quantity;
  String totalAmount;
  bool isExpanded;

  // Focus nodes for keyboard navigation
  final FocusNode itemNameFocus = FocusNode();
  final FocusNode unitAmountFocus = FocusNode();
  final FocusNode taxFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode plusFocus = FocusNode();

  CustomerVoucherFormItem({
    this.itemName = '',
    this.unitAmount = '0',
    this.tax = '0',
    this.quantity = '1',
    this.totalAmount = '0',
    this.isExpanded = false,
  });

  void dispose() {
    itemNameFocus.dispose();
    unitAmountFocus.dispose();
    taxFocus.dispose();
    quantityFocus.dispose();
    plusFocus.dispose();
  }
}
