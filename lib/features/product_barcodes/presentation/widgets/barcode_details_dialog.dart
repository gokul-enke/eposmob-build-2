import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/product/widgets/product_barcode_responsive.dart';
import '../models/barcode_row.dart';

void showBarcodeDetails(BuildContext context, BarcodeRow row) {
  final isPhone = productBarcodeIsPhone(context);
  final screenContext = context;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 16 : 40,
        vertical: isPhone ? 24 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isPhone
              ? MediaQuery.of(context).size.width
              : MediaQuery.of(context).size.width / 2,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'product_barcode.stock_details'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      isPhone ? FontSize.s18 : FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.product_name'.tr,
                    row.displayName,
                  ),
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.category'.tr,
                    row.product.category?.name ?? 'product_barcode.na'.tr,
                  ),
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.unit'.tr,
                    row.product.unit ?? 'product_barcode.na'.tr,
                  ),
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.retail_price'.tr,
                    row.priceDisplay,
                  ),
                  _buildDetailRow(
                      screenContext, 'product_barcode.mrp'.tr, row.mrpDisplay),
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.quantity'.tr,
                    row.quantity,
                  ),
                  _buildDetailRow(
                    screenContext,
                    'product_barcode.barcode'.tr,
                    row.barcode ?? 'product_barcode.na'.tr,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CustomRoundButton(
                title: 'product_barcode.close'.tr,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                fct: () => Navigator.pop(context),
                height: 45,
                width: isPhone ? double.infinity : 120,
                fontSize: FontSize.s12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDetailRow(BuildContext context, String label, String value) {
  final isPhone = productBarcodeIsPhone(context);

  if (isPhone) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: ProductBarcodeInfoChip(label: label, value: value),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            '$label: ',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.20,
              ColorManager.textColor,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    ),
  );
}
