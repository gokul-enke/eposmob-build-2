import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';

import '../order_fulfillment_actions.dart';
import 'order_detail_actions.dart';
import 'order_detail_fulfillment_section_header.dart';
import 'order_detail_info_row.dart';
import 'order_detail_inputs.dart';
import 'order_detail_packing_photo_row.dart';
import 'order_detail_section_card.dart';
import 'order_detail_tappable_row.dart';

class OrderDetailPackingSection extends StatelessWidget {
  const OrderDetailPackingSection(this.packing,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final OrderDetailsModelDataPacking? packing;
  @override
  Widget build(BuildContext context) {
    final photos = packing?.photosForDisplay ?? const <String>[];
    final video = packing?.packingVideo ?? '';
    final packedAt = packing?.packedAt ?? '';
    final packingStatus =
        (packing?.hasDetails ?? false) ? packing!.isPackedResolved : null;
    // The web view keeps these two apart: `packed_by` is the resolved staff
    // user, `packed_by_name` is the free-text name typed by whoever packed.
    final packedByStaff = packing?.packedByUserName ?? '';
    final packedByOther = packing?.packedByName ?? '';

    return OrderDetailSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderDetailFulfillmentSectionHeader(
                title: 'sales_order_details.title_packing'.tr,
                action: OrderFulfillmentActionButton(
                  action: OrderFulfillmentAction.packing,
                  orderNumber:
                      inputs.data.orderDetailsModelData?.orderNumber ?? '',
                  orderStatus: inputs.data.orderDetailsModelData?.orderStatus,
                  packing: packing,
                  onSaved: inputs.data.onFulfillmentUpdated,
                ),
                inputs: inputs),
            const SizedBox(height: 8),
            OrderDetailInfoRow(
                'sales_order_details.label_packing_status'.tr,
                packingStatus == null
                    ? '—'
                    : packingStatus
                        ? 'sales_order_details.value_packed'.tr
                        : 'sales_order_details.value_not_packed'.tr,
                inputs: inputs),
            OrderDetailInfoRow(
                'sales_order_details.label_packed_at'.tr,
                // packed_at arrives as UTC ("...Z"), so it must go through the
                // timezone-aware formatter, not formatInputToDisplay.
                packedAt.isEmpty
                    ? '—'
                    : DateHelper.formatISODateToIST(packedAt),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_packed_by_staff'.tr,
                packedByStaff.isEmpty ? '—' : packedByStaff,
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_packed_by_other'.tr,
                packedByOther.isEmpty ? '—' : packedByOther,
                inputs: inputs),
            if (photos.isEmpty)
              OrderDetailInfoRow(
                  'sales_order_details.label_packing_photos'.tr, '—',
                  inputs: inputs)
            else
              OrderDetailPackingPhotoRow(photos, inputs: inputs),
            if (video.isEmpty)
              OrderDetailInfoRow(
                  'sales_order_details.label_packing_video'.tr, '—',
                  inputs: inputs)
            else
              OrderDetailTappableRow(
                  'sales_order_details.label_packing_video'.tr,
                  'sales_order_details.btn_play_video'.tr,
                  () => openOrderDetailExternal(context, video),
                  inputs: inputs),
          ],
        ),
        inputs: inputs);
  }
}
