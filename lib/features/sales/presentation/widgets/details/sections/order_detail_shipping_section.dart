import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';

import '../order_fulfillment_actions.dart';
import 'order_detail_actions.dart';
import 'order_detail_fulfillment_section_header.dart';
import 'order_detail_info_row.dart';
import 'order_detail_inputs.dart';
import 'order_detail_section_card.dart';
import 'order_detail_tappable_row.dart';

class OrderDetailShippingSection extends StatelessWidget {
  const OrderDetailShippingSection(this.deliveryAddress,
      {super.key, required this.inputs});
  final OrderDetailInputs inputs;
  final OrderDetailsModelDataDeliveryAddress deliveryAddress;
  @override
  Widget build(BuildContext context) {
    String orEmpty(String? value) =>
        (value == null || value.isEmpty) ? '—' : value;
    final externalDelivery =
        inputs.data.orderDetailsModelData?.externalDeliveryJob;

    return OrderDetailSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderDetailFulfillmentSectionHeader(
                title: 'sales_order_details.title_shipping_details'.tr,
                action: externalDelivery?.hasDetails == true
                    ? null
                    : OrderFulfillmentActionButton(
                        action: OrderFulfillmentAction.externalDelivery,
                        orderNumber:
                            inputs.data.orderDetailsModelData?.orderNumber ??
                                '',
                        orderStatus:
                            inputs.data.orderDetailsModelData?.orderStatus,
                        onSaved: inputs.data.onFulfillmentUpdated,
                      ),
                inputs: inputs),
            const SizedBox(height: 8),
            OrderDetailInfoRow('sales_order_details.label_delivery_method'.tr,
                orEmpty(inputs.data.deliveryMethodLabel),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_address_type'.tr,
                orEmpty(deliveryAddress.addressType),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_shipping_address'.tr,
                orEmpty(deliveryAddress.address),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_pincode'.tr,
                orEmpty(deliveryAddress.pincode),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_district'.tr,
                orEmpty(deliveryAddress.district),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_state'.tr,
                orEmpty(deliveryAddress.state),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_city'.tr,
                orEmpty(deliveryAddress.city),
                inputs: inputs),
            OrderDetailInfoRow('sales_order_details.label_landmark'.tr,
                orEmpty(deliveryAddress.landmark),
                inputs: inputs),
            if (externalDelivery?.hasDetails == true) ...[
              const Divider(height: 24),
              OrderDetailInfoRow(
                  'sales_order_details.label_shipping_partner'.tr,
                  orEmpty(externalDelivery?.externalLogisticName),
                  inputs: inputs),
              OrderDetailInfoRow('sales_order_details.label_shipping_method'.tr,
                  orEmpty(externalDelivery?.shippingService),
                  inputs: inputs),
              OrderDetailInfoRow('sales_order_details.label_transport_mode'.tr,
                  orEmpty(externalDelivery?.transportMode),
                  inputs: inputs),
              OrderDetailInfoRow(
                  'sales_order_details.label_pickup_warehouse'.tr,
                  orEmpty(externalDelivery?.warehouseName),
                  inputs: inputs),
              OrderDetailInfoRow(
                  'sales_order_details.label_delivery_job_status'.tr,
                  orEmpty(externalDelivery?.status),
                  inputs: inputs),
              OrderDetailInfoRow('sales_order_details.label_payment_mode'.tr,
                  orEmpty(externalDelivery?.paymentMode),
                  inputs: inputs),
              if ((externalDelivery?.codAmount ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_cod_amount'.tr,
                    externalDelivery!.codAmount!,
                    inputs: inputs),
              if ((externalDelivery?.packageCount ?? 0) > 0)
                OrderDetailInfoRow('sales_order_details.label_package_count'.tr,
                    externalDelivery!.packageCount.toString(),
                    inputs: inputs),
              if ((externalDelivery?.weight ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_weight_kg'.tr,
                    externalDelivery!.weight!,
                    inputs: inputs),
              if ((externalDelivery?.length ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_length_cm'.tr,
                    externalDelivery!.length!,
                    inputs: inputs),
              if ((externalDelivery?.breadth ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_breadth_cm'.tr,
                    externalDelivery!.breadth!,
                    inputs: inputs),
              if ((externalDelivery?.height ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_height_cm'.tr,
                    externalDelivery!.height!,
                    inputs: inputs),
              if ((externalDelivery?.shippingCharge ?? '').isNotEmpty)
                OrderDetailInfoRow(
                    'sales_order_details.label_shipping_charge'.tr,
                    externalDelivery!.shippingCharge!,
                    inputs: inputs),
              if ((externalDelivery?.externalShipmentId ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_awb_number'.tr,
                    externalDelivery!.externalShipmentId!,
                    inputs: inputs),
              if ((externalDelivery?.trackingUrl ?? '').isNotEmpty)
                OrderDetailTappableRow(
                    'sales_order_details.label_tracking_url'.tr,
                    externalDelivery!.trackingUrl!,
                    () => openOrderDetailExternal(
                          context,
                          externalDelivery.trackingUrl!,
                          failureMessageKey:
                              'sales_order_details.msg_tracking_open_failed',
                        ),
                    inputs: inputs),
              if ((externalDelivery?.dispatchDate ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_dispatch_date'.tr,
                    DateHelper.formatISODate(externalDelivery!.dispatchDate!),
                    inputs: inputs),
              if ((externalDelivery?.expectedDeliveryAt ?? '').isNotEmpty)
                OrderDetailInfoRow(
                    'sales_order_details.label_expected_delivery'.tr,
                    DateHelper.formatISODateToIST(
                        externalDelivery!.expectedDeliveryAt!),
                    inputs: inputs),
              if ((externalDelivery?.remarks ?? '').isNotEmpty)
                OrderDetailInfoRow('sales_order_details.label_remarks'.tr,
                    externalDelivery!.remarks!,
                    inputs: inputs),
            ],
          ],
        ),
        inputs: inputs);
  }
}
