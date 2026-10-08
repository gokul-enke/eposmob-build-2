import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import 'order_documents_section.dart';
import 'sections/order_detail_actions.dart';
import 'sections/order_detail_info_row.dart';
import 'sections/order_detail_inputs.dart';
import 'sections/order_detail_overview.dart';
import 'sections/order_detail_packing_section.dart';
import 'sections/order_detail_payment_section.dart';
import 'sections/order_detail_presentation_data.dart';
import 'sections/order_detail_section_card.dart';
import 'sections/order_detail_shipping_section.dart';
import 'sections/order_detail_status_chips.dart';
import 'sections/order_expandable_section.dart';

class OrderDetailWidget extends StatelessWidget {
  final OrderDetailsModelData? orderDetailsModelData;
  final OrderDetailsModelDataCustomerDetails? customerDetails;
  final List<OrderDetailsModelDataCartItem>? cartItem;
  final OrderDetailsModelDataPriceSummary? priceSummary;
  final Future<void> Function()? onFulfillmentUpdated;

  const OrderDetailWidget({
    Key? key,
    required this.orderDetailsModelData,
    required this.priceSummary,
    required this.cartItem,
    required this.customerDetails,
    this.onFulfillmentUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = OrderDetailPresentationData(
        orderDetailsModelData: orderDetailsModelData,
        priceSummary: priceSummary,
        cartItem: cartItem,
        customerDetails: customerDetails,
        onFulfillmentUpdated: onFulfillmentUpdated);
    final effectivePriceSummary = data.effectivePriceSummary();

    if (data.customerDetails == null ||
        data.cartItem == null ||
        effectivePriceSummary == null) {
      return Center(
        child: Text('sales_order_details.msg_details_unavailable'.tr),
      );
    }

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, child) {
        final inputs = OrderDetailInputs(
            data: data, currency: settings.appSettings?.currency);
        final currency = inputs.currency ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Order Details Section (FIRST)
            OrderDetailOverview(inputs: inputs),

            // Order Status Section (BELOW the main card)
            if (inputs.data.orderDetailsModelData?.orderStatus != null)
              OrderDetailSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_order_details.title_order_status'.tr,
                        style: orderDetailSectionTitleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      OrderDetailStatusChips(inputs: inputs),
                    ],
                  ),
                  inputs: inputs),

            // Store & Delivery Info Section
            if (inputs.data.orderDetailsModelData?.storeName != null ||
                inputs.data.orderDetailsModelData?.deliveryMethodName != null)
              OrderDetailSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_order_details.title_store_delivery'.tr,
                        style: orderDetailSectionTitleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      if (inputs.data.orderDetailsModelData?.storeName != null)
                        OrderDetailInfoRow('sales_order_details.label_store'.tr,
                            inputs.data.orderDetailsModelData?.storeName ?? '',
                            inputs: inputs),
                      if (inputs
                              .data.orderDetailsModelData?.deliveryMethodName !=
                          null)
                        OrderDetailInfoRow(
                            'sales_order_details.label_delivery_method'.tr,
                            inputs.data.deliveryMethodLabel,
                            inputs: inputs),
                      if (inputs.data.orderDetailsModelData?.deliveryDate !=
                              null &&
                          inputs.data.orderDetailsModelData!.deliveryDate!
                              .isNotEmpty)
                        OrderDetailInfoRow(
                            'sales_order_details.label_delivery_date_value'.tr,
                            // Formatted here rather than left to
                            // inputs.data.formatOrderPropertyValue, which dispatches on
                            // the English label and so would pass the raw
                            // ISO date straight through in Arabic.
                            DateHelper.formatISODate(inputs
                                    .data.orderDetailsModelData?.deliveryDate ??
                                ''),
                            inputs: inputs),
                      if (inputs.data.orderDetailsModelData?.deliveryTime !=
                              null &&
                          inputs.data.orderDetailsModelData!.deliveryTime!
                              .isNotEmpty)
                        OrderDetailInfoRow(
                            'sales_order_details.label_delivery_time_value'.tr,
                            inputs.data.orderDetailsModelData?.deliveryTime ??
                                '',
                            inputs: inputs),
                      if (inputs.data.orderDetailsModelData?.deliveryCharge !=
                          null)
                        OrderDetailInfoRow(
                            'sales_order_details.label_delivery_charge'.tr,
                            '$currency ${inputs.data.formatAmount(inputs.data.orderDetailsModelData?.deliveryCharge)}',
                            inputs: inputs),
                    ],
                  ),
                  inputs: inputs),

            // Payment Details Section
            if (inputs.data.orderDetailsModelData?.paymentDetails != null)
              OrderDetailPaymentSection(inputs: inputs),

            // Customer Extended Info Section
            if (inputs.data.customerDetails?.email != null ||
                inputs.data.customerDetails?.alternatePhone != null ||
                (inputs.data.orderDetailsModelData
                            ?.getCustomerAddressFromProps() ??
                        '')
                    .isNotEmpty ||
                (inputs.data.customerDetails?.address != null &&
                    (inputs.data.customerDetails?.address?.isNotEmpty ??
                        false)))
              OrderDetailSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_order_details.title_customer_information'.tr,
                        style: orderDetailSectionTitleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      if (inputs.data.customerDetails?.email != null)
                        OrderDetailInfoRow('sales_order_details.label_email'.tr,
                            inputs.data.customerDetails?.email ?? '',
                            inputs: inputs),
                      if (inputs.data.customerDetails?.alternatePhone != null &&
                          inputs
                              .data.customerDetails!.alternatePhone!.isNotEmpty)
                        OrderDetailInfoRow(
                            'sales_order_details.label_alternate_phone'.tr,
                            inputs.data.customerDetails?.alternatePhone ?? '',
                            inputs: inputs),
                      if ((inputs.data.orderDetailsModelData
                                  ?.getCustomerAddressFromProps() ??
                              '')
                          .isNotEmpty)
                        OrderDetailInfoRow(
                            'sales_order_details.label_address'.tr,
                            inputs.data.orderDetailsModelData
                                    ?.getCustomerAddressFromProps() ??
                                '',
                            inputs: inputs),
                      if (inputs.data.customerDetails?.address != null &&
                          (inputs.data.customerDetails?.address?.isNotEmpty ??
                              false) &&
                          (inputs.data.orderDetailsModelData
                                      ?.getCustomerAddressFromProps() ??
                                  '')
                              .isEmpty)
                        OrderDetailInfoRow(
                            'sales_order_details.label_address'.tr,
                            inputs.data.formatCustomerAddressList(
                                inputs.data.customerDetails?.address),
                            inputs: inputs),
                    ],
                  ),
                  inputs: inputs),

            if (inputs.data.orderDetailsModelData?.kycInfo?.crNumber != null ||
                inputs.data.orderDetailsModelData?.kycInfo?.vatNumber != null)
              OrderDetailSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'sales_order_details.title_kyc_information'.tr,
                        style: orderDetailSectionTitleStyle(context),
                      ),
                      const SizedBox(height: 8),
                      if (inputs
                              .data.orderDetailsModelData?.kycInfo?.crNumber !=
                          null)
                        OrderDetailInfoRow(
                            'sales_order_details.label_cr_number'.tr,
                            inputs.data.orderDetailsModelData?.kycInfo
                                    ?.crNumber ??
                                '',
                            inputs: inputs),
                      if (inputs
                              .data.orderDetailsModelData?.kycInfo?.vatNumber !=
                          null)
                        OrderDetailInfoRow(
                            'sales_order_details.label_vat_number'.tr,
                            inputs.data.orderDetailsModelData?.kycInfo
                                    ?.vatNumber ??
                                '',
                            inputs: inputs),
                    ],
                  ),
                  inputs: inputs),

            // Always show Shipping Details and Packing. An empty model
            // lets their existing row placeholders render when the API
            // has not supplied either record yet.
            OrderDetailShippingSection(
                inputs.data.orderDetailsModelData?.deliveryAddress ??
                    OrderDetailsModelDataDeliveryAddress(),
                inputs: inputs),

            OrderDetailPackingSection(
                inputs.data.orderDetailsModelData?.packing ??
                    OrderDetailsModelDataPacking(),
                inputs: inputs),

            // Order Documents Section
            if ((inputs.data.orderDetailsModelData?.orderNumber ?? '')
                .isNotEmpty)
              OrderDocumentsSection(
                orderNumber: inputs.data.orderDetailsModelData!.orderNumber!,
              ),

            if (inputs.data.orderDetailsModelData?.tokenNumber != null ||
                inputs.data.orderDetailsModelData?.invoiceHash != null)
              OrderExpandableSection(
                title: 'sales_order_details.title_order_metadata'.tr,
                titleStyle: orderDetailSectionTitleStyle(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (inputs.data.orderDetailsModelData?.tokenNumber != null)
                      OrderDetailInfoRow(
                          'sales_order_details.label_token_number'.tr,
                          inputs.data.orderDetailsModelData?.tokenNumber ?? '',
                          inputs: inputs),
                    if (inputs.data.orderDetailsModelData?.invoiceHash != null)
                      OrderDetailInfoRow(
                          'sales_order_details.label_invoice_hash'.tr,
                          inputs.data.orderDetailsModelData?.invoiceHash ?? '',
                          inputs: inputs),
                  ],
                ),
              ),

            // Order Properties Section (Custom Fields)
            if (inputs.data.orderDetailsModelData?.orderProps != null &&
                (inputs.data.orderDetailsModelData?.orderProps?.isNotEmpty ??
                    false))
              OrderExpandableSection(
                title: 'sales_order_details.title_order_properties'.tr,
                titleStyle: orderDetailSectionTitleStyle(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...(inputs.data.orderDetailsModelData?.orderProps
                            ?.map((prop) => OrderDetailInfoRow(
                                StringHelper.formatPropCode(
                                    prop.propsCode ?? ''),
                                prop.propsValue ?? '',
                                inputs: inputs))
                            .toList() ??
                        []),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
