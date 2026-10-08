import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';

import 'order_detail_actions.dart';
import 'order_detail_inputs.dart';

class OrderDetailPackingPhotoRow extends StatelessWidget {
  const OrderDetailPackingPhotoRow(this.photos,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final List<String> photos;
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final label = 'sales_order_details.label_packing_photos'.tr;
    final labelStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s12 : FontSize.s13,
      isMobile ? 0.18 : 0.20,
      ColorManager.blackWithOpacity50,
    );
    const previewLimit = 4;
    final previews = <Widget>[
      ...photos.take(previewLimit).map<Widget>(
            (photo) => Tooltip(
              message: 'sales_order_details.tooltip_view_packing_photos'.tr,
              child: InkWell(
                onTap: () => showOrderPackingPhotoViewer(context, photos),
                borderRadius: BorderRadius.circular(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 48,
                    width: 48,
                    child: Image.network(
                      photo,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    ];

    if (photos.length > previewLimit) {
      previews.add(
        InkWell(
          onTap: () => showOrderPackingPhotoViewer(context, photos),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 48,
            width: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${photos.length - previewLimit}',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.18,
                ColorManager.kPrimaryColor,
              ),
            ),
          ),
        ),
      );
    }

    final previewGrid = Wrap(spacing: 8, runSpacing: 8, children: previews);
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: labelStyle),
            const SizedBox(height: 6),
            previewGrid,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text('$label:', style: labelStyle)),
          Expanded(child: previewGrid),
        ],
      ),
    );
  }
}
