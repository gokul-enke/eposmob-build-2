import 'package:flutter/widgets.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';

class SalesReturnItemDialogController {
  SalesReturnItemDialogController(
      {required String quantity,
      required String unitPrice,
      required String productUnit,
      required double returnedQuantity}) {
    quantityController = TextEditingController();
    reasonController = TextEditingController();
    returnTotalController = TextEditingController();
    soldQuantity = double.tryParse(quantity) ?? 0;
    maxQuantity = (soldQuantity - returnedQuantity).clamp(0, soldQuantity);
    unitPriceValue = double.parse(unitPrice);
    maxTotal = maxQuantity * unitPriceValue;
    hasProductUnit = productUnit.trim().isNotEmpty;
    allowsDecimals = hasProductUnit
        ? allowsDecimalQuantityUnit(productUnit)
        : soldQuantity != soldQuantity.roundToDouble();

    bool _updatingFromQuantity = false;
    bool _updatingFromTotal = false;

    quantityController.addListener(() {
      if (_updatingFromTotal) return;
      if (quantityController.text.isEmpty) return;

      final enteredQuantity = double.tryParse(quantityController.text) ?? 0;

      if (enteredQuantity > maxQuantity) {
        quantityController.text = allowsDecimals
            ? maxQuantity.toStringAsFixed(3)
            : maxQuantity.toInt().toString();
        quantityController.selection = TextSelection.fromPosition(
          TextPosition(offset: quantityController.text.length),
        );
      }

      _updatingFromQuantity = true;
      final total = enteredQuantity * unitPriceValue;
      returnTotalController.text = total.toStringAsFixed(2);
      _updatingFromQuantity = false;
    });

    returnTotalController.addListener(() {
      if (_updatingFromQuantity) return;
      if (returnTotalController.text.isEmpty) return;

      final enteredTotal = double.tryParse(returnTotalController.text) ?? 0.0;

      if (enteredTotal > maxTotal) {
        returnTotalController.text = maxTotal.toStringAsFixed(2);
        returnTotalController.selection = TextSelection.fromPosition(
          TextPosition(offset: returnTotalController.text.length),
        );
      }

      _updatingFromTotal = true;
      final calculatedQuantity = enteredTotal / unitPriceValue;
      if (calculatedQuantity <= maxQuantity) {
        quantityController.text = allowsDecimals
            ? calculatedQuantity.toStringAsFixed(3)
            : calculatedQuantity.floor().toString();
      }
      _updatingFromTotal = false;
    });
  }
  late final TextEditingController quantityController,
      reasonController,
      returnTotalController;
  late final double soldQuantity, maxQuantity, unitPriceValue, maxTotal;
  late final bool hasProductUnit, allowsDecimals;
  void dispose() {
    quantityController.dispose();
    reasonController.dispose();
    returnTotalController.dispose();
  }
}
