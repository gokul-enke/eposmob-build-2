import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/delivery_method_display.dart';
import 'package:pos_machine/helpers/payment_method_display.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_payment_row.dart';
import '../../../components/build_profile_picture.dart';
import '../../../models/order_details.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'order_documents_section.dart';

class OrderDetailWidget extends StatelessWidget {
  final OrderDetailsModelData? orderDetailsModelData;
  final OrderDetailsModelDataCustomerDetails? customerDetails;
  final List<OrderDetailsModelDataCartItem>? cartItem;
  final OrderDetailsModelDataPriceSummary? priceSummary;

  const OrderDetailWidget({
    Key? key,
    required this.orderDetailsModelData,
    required this.priceSummary,
    required this.cartItem,
    required this.customerDetails,
  }) : super(key: key);

  /// Localized delivery method for this order — see
  /// [DeliveryMethodDisplay.labelForIdOrName] for why the id leads the name.
  String get _deliveryMethodLabel => DeliveryMethodDisplay.labelForIdOrName(
        orderDetailsModelData?.deliveryMethodId,
        orderDetailsModelData?.deliveryMethodName,
      );

  // Calculate total MRP from all cart items
  double _calculateTotalMRP() {
    if (cartItem == null || cartItem!.isEmpty) {
      return 0.0;
    }

    double totalMRP = 0.0;
    for (var item in cartItem!) {
      final mrp = double.tryParse(item.mrp ?? '0') ?? 0.0;
      final quantity = item.quantity ?? 0;
      totalMRP += mrp * quantity;
    }
    return totalMRP;
  }

  OrderDetailsModelDataPriceSummary? _effectivePriceSummary() {
    return priceSummary ??
        orderDetailsModelData?.priceSummary ??
        orderDetailsModelData?.cart?.priceSummary;
  }

  String? _getOrderPropValue(String code) {
    final prop = orderDetailsModelData?.orderProps?.firstWhere(
      (item) => item.propsCode?.toUpperCase() == code.toUpperCase(),
      orElse: () => OrderDetailsModelDataOrderProp(),
    );
    final value = prop?.propsValue;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  double _balanceAmount(OrderDetailsModelDataPriceSummary? summary) {
    final propBalance = double.tryParse(_getOrderPropValue('BALANCE') ?? '');
    if (propBalance != null) {
      return propBalance;
    }

    final totalPaid =
        _calculateTotalPayments(orderDetailsModelData?.payments ?? {});
    final payable = (summary?.netPayable ?? summary?.netTotal ?? 0).toDouble();
    final balance = payable - totalPaid;
    return balance < 0 ? 0.0 : balance;
  }

  String _formatAmount(num? value) {
    return (value ?? 0).toStringAsFixed(2);
  }

  String _formatCustomerAddressList(List<dynamic>? addressList) {
    if (addressList == null || addressList.isEmpty) return '';

    try {
      // If the first item is a Map (parsed JSON)
      if (addressList[0] is Map) {
        final map = addressList[0];
        List<String> parts = [];

        if (map['address'] != null) parts.add(map['address'].toString());
        if (map['city'] != null) parts.add(map['city'].toString());

        // Handle state
        if (map['state_id'] != null) {
          // If we have state ID but no name, we might just show ID or skip
          // Ideally we'd look up the name, but for now let's skip if no name
        }

        // Handle pincode
        if (map['pincode_id'] != null) {
          // Same for pincode
        }

        return parts.join(', ');
      }

      // If it's a string representation of a map "{id: 6, ...}"
      String raw = addressList[0].toString();
      if (raw.startsWith('{')) {
        String address = "";
        String city = "";

        final addressMatch = RegExp(r'address:\s*([^,]+)').firstMatch(raw);
        if (addressMatch != null) address = addressMatch.group(1)?.trim() ?? "";

        final cityMatch = RegExp(r'city:\s*([^,]+)').firstMatch(raw);
        if (cityMatch != null) city = cityMatch.group(1)?.trim() ?? "";

        List<String> parts = [];
        if (address.isNotEmpty) parts.add(address);
        if (city.isNotEmpty) parts.add(city);

        if (parts.isNotEmpty) return parts.join(', ');
      }

      return addressList.join(', ');
    } catch (e) {
      return addressList.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePriceSummary = _effectivePriceSummary();
    final isMobile = ResponsiveWidget.isMobile(context);

    if (customerDetails == null ||
        cartItem == null ||
        effectivePriceSummary == null) {
      return Center(
        child: Text('sales_order_details.msg_details_unavailable'.tr),
      );
    }

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Order Details Section (FIRST)
            BuildBoxShadowContainer(
              circleRadius: 7,
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              margin: EdgeInsets.only(
                top: isMobile ? 8.0 : 13.0,
                left: isMobile ? 0 : 8,
                right: isMobile ? 0 : 8,
              ),
              offsetValue: const Offset(1, 1),
              child: Column(
                children: [
                  // Customer Details and Order Date
                  _buildCustomerHeader(context),
                  // Cart Items - cards on mobile, table on desktop
                  _buildCartItemsTable(currency, context),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14.0),
                            child: Column(
                              children: [
                                // Displaying Price Summary
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_formatAmount(effectivePriceSummary.netTotal)}",
                                  title: 'sales_order_details.label_net_total_inc_tax'.tr,
                                  color: ColorManager.textColor,
                                  firstRowTextStyle: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s14,
                                    0.21,
                                    ColorManager.textColor,
                                  ),
                                  secondRowTextStyle: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s14,
                                    0.21,
                                    ColorManager.textColor,
                                  ),
                                ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_formatAmount(effectivePriceSummary.netExcTax ?? orderDetailsModelData?.cart?.priceSummary?.netExcTax)}",
                                  title: 'sales_order_details.label_net_total_exc_tax'.tr,
                                  color: ColorManager.textColor,
                                ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_formatAmount(effectivePriceSummary.discount)}",
                                  title: 'sales_order_details.label_discount'.tr,
                                  color: ColorManager.textColor,
                                ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_formatAmount(effectivePriceSummary.totalTax)}",
                                  title: (effectivePriceSummary.discount ?? 0) > 0
                                      ? 'sales_order_details.label_tax_after_discount'.tr
                                      : 'sales_order_details.label_tax_amount'.tr,
                                  color: ColorManager.textColor,
                                ),
                                const Divider(thickness: 2),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_formatAmount(effectivePriceSummary.netPayable)}",
                                  title: 'sales_order_details.label_payable'.tr,
                                  secondRowTextStyle: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s15,
                                    0.23,
                                    ColorManager.kButtonGreen,
                                  ),
                                  firstRowTextStyle: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s15,
                                    0.23,
                                    ColorManager.kButtonGreen,
                                  ),
                                  color: ColorManager.kButtonGreen,
                                ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${_balanceAmount(effectivePriceSummary).toStringAsFixed(2)}",
                                  title: 'sales_order_details.label_balance_amount'.tr,
                                  secondRowTextStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.18,
                                    ColorManager.textColorRed,
                                  ),
                                  firstRowTextStyle: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s15,
                                    0.23,
                                    ColorManager.textColorRed,
                                  ),
                                  color: ColorManager.textColorRed,
                                ),
                                const SizedBox(height: 5),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),

                  // Order Status Section (BELOW the main card)
                  if (orderDetailsModelData?.orderStatus != null)
                    _buildSectionCard(
                      context: context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sales_order_details.title_order_status'.tr,
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusChips(context),
                        ],
                      ),
                    ),

                  // Store & Delivery Info Section
                  if (orderDetailsModelData?.storeName != null ||
                      orderDetailsModelData?.deliveryMethodName != null)
                    _buildSectionCard(
                      context: context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sales_order_details.title_store_delivery'.tr,
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 8),
                          if (orderDetailsModelData?.storeName != null)
                            _buildInfoRow(context, 'sales_order_details.label_store'.tr,
                                orderDetailsModelData?.storeName ?? ''),
                          if (orderDetailsModelData?.deliveryMethodName != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_delivery_method'.tr,
                                _deliveryMethodLabel),
                          if (orderDetailsModelData?.deliveryDate != null &&
                              orderDetailsModelData!.deliveryDate!.isNotEmpty)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_delivery_date_value'
                                    .tr,
                                // Formatted here rather than left to
                                // _formatOrderPropertyValue, which dispatches on
                                // the English label and so would pass the raw
                                // ISO date straight through in Arabic.
                                DateHelper.formatISODate(
                                    orderDetailsModelData?.deliveryDate ?? '')),
                          if (orderDetailsModelData?.deliveryTime != null &&
                              orderDetailsModelData!.deliveryTime!.isNotEmpty)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_delivery_time_value'.tr,
                                orderDetailsModelData?.deliveryTime ?? ''),
                          if (orderDetailsModelData?.deliveryCharge != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_delivery_charge'.tr,
                                '$currency ${_formatAmount(orderDetailsModelData?.deliveryCharge)}'),
                        ],
                      ),
                    ),

                  // Payment Details Section
                  if (orderDetailsModelData?.paymentDetails != null)
                    _buildSectionCard(
                      context: context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sales_order_details.title_payment_details'.tr,
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 8),
                          if (orderDetailsModelData
                                  ?.paymentDetails?.paymentMethod !=
                              null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_payment_method'.tr,
                                PaymentMethodDisplay.labelForCodeList(
                                    orderDetailsModelData
                                        ?.paymentDetails?.paymentMethod)),
                          if (orderDetailsModelData
                                  ?.paymentDetails?.transactionId !=
                              null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_transaction_id'.tr,
                                orderDetailsModelData
                                        ?.paymentDetails?.transactionId
                                        ?.toString() ??
                                    ''),
                          if (orderDetailsModelData
                                  ?.paymentDetails?.paymentId !=
                              null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_payment_id'.tr,
                                orderDetailsModelData
                                        ?.paymentDetails?.paymentId ??
                                    ''),

                          // Add payment breakdown
                          if (orderDetailsModelData?.payments != null &&
                              (orderDetailsModelData?.payments?.isNotEmpty ??
                                  false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              "${'sales_order_details.label_payment_breakdown'.tr}:",
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.18,
                                ColorManager.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...(orderDetailsModelData?.payments?.entries
                                    .map(
                                      (entry) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                // The map key is the stable
                                                // payment code, kept as-is in
                                                // the data and localized only
                                                // for display.
                                                PaymentMethodDisplay.labelFor(
                                                    entry.key),
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s11,
                                                  0.16,
                                                  ColorManager.textColor,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$currency ${entry.value}',
                                              style: buildCustomStyle(
                                                FontWeightManager.semiBold,
                                                FontSize.s11,
                                                0.16,
                                                ColorManager.kPrimaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    ?.toList() ??
                                []),

                            // Add total payment amount
                            if ((orderDetailsModelData?.payments?.isNotEmpty ??
                                false)) ...[
                              const Divider(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${'sales_order_details.label_total_paid'.tr}:",
                                    style: buildCustomStyle(
                                      FontWeightManager.semiBold,
                                      FontSize.s12,
                                      0.18,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  Text(
                                    '$currency ${_calculateTotalPayments(orderDetailsModelData?.payments ?? {})}',
                                    style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s12,
                                      0.18,
                                      ColorManager.kPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                  // Customer Extended Info Section
                  if (customerDetails?.email != null ||
                      customerDetails?.alternatePhone != null ||
                      (orderDetailsModelData?.getCustomerAddressFromProps() ??
                              '')
                          .isNotEmpty ||
                      (customerDetails?.address != null &&
                          (customerDetails?.address?.isNotEmpty ?? false)))
                    _buildSectionCard(
                      context: context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sales_order_details.title_customer_information'.tr,
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 8),
                          if (customerDetails?.email != null)
                            _buildInfoRow(
                                context, 'sales_order_details.label_email'.tr, customerDetails?.email ?? ''),
                          if (customerDetails?.alternatePhone != null &&
                              customerDetails!.alternatePhone!.isNotEmpty)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_alternate_phone'.tr,
                                customerDetails?.alternatePhone ?? ''),
                          if ((orderDetailsModelData
                                      ?.getCustomerAddressFromProps() ??
                                  '')
                              .isNotEmpty)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_address'.tr,
                                orderDetailsModelData
                                        ?.getCustomerAddressFromProps() ??
                                    ''),
                          if (customerDetails?.address != null &&
                              (customerDetails?.address?.isNotEmpty ?? false) &&
                              (orderDetailsModelData
                                          ?.getCustomerAddressFromProps() ??
                                      '')
                                  .isEmpty)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_address'.tr,
                                _formatCustomerAddressList(
                                    customerDetails?.address)),
                        ],
                      ),
                    ),

                  if (orderDetailsModelData?.kycInfo?.crNumber != null ||
                      orderDetailsModelData?.kycInfo?.vatNumber != null)
                    _buildSectionCard(
                      context: context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'sales_order_details.title_kyc_information'.tr,
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 8),
                          if (orderDetailsModelData?.kycInfo?.crNumber != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_cr_number'.tr,
                                orderDetailsModelData?.kycInfo?.crNumber ?? ''),
                          if (orderDetailsModelData?.kycInfo?.vatNumber != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_vat_number'.tr,
                                orderDetailsModelData?.kycInfo?.vatNumber ??
                                    ''),
                        ],
                      ),
                    ),

                  // Packing Section — hidden when the order has no packing
                  // record, matching every other section on this screen.
                  if (orderDetailsModelData?.packing?.hasDetails ?? false)
                    _buildPackingSection(
                        context, orderDetailsModelData!.packing!),

                  // Shipping Details Section — hidden when there is no
                  // shipping address. Delivery Method alone doesn't justify
                  // the card; it is already shown under Store & Delivery.
                  if (orderDetailsModelData?.deliveryAddress?.hasDetails ??
                      false)
                    _buildShippingSection(
                        context, orderDetailsModelData!.deliveryAddress!),

                  // Order Documents Section
                  if ((orderDetailsModelData?.orderNumber ?? '').isNotEmpty)
                    OrderDocumentsSection(
                      orderNumber: orderDetailsModelData!.orderNumber!,
                    ),

                  if (orderDetailsModelData?.tokenNumber != null ||
                      orderDetailsModelData?.invoiceHash != null)
                    _ExpandableSection(
                      title: 'sales_order_details.title_order_metadata'.tr,
                      titleStyle: _sectionTitleStyle(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (orderDetailsModelData?.tokenNumber != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_token_number'.tr,
                                orderDetailsModelData?.tokenNumber ?? ''),
                          if (orderDetailsModelData?.invoiceHash != null)
                            _buildInfoRow(
                                context,
                                'sales_order_details.label_invoice_hash'.tr,
                                orderDetailsModelData?.invoiceHash ?? ''),
                        ],
                      ),
                    ),

                  // Order Properties Section (Custom Fields)
                  if (orderDetailsModelData?.orderProps != null &&
                      (orderDetailsModelData?.orderProps?.isNotEmpty ?? false))
                    _ExpandableSection(
                      title: 'sales_order_details.title_order_properties'.tr,
                      titleStyle: _sectionTitleStyle(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...(orderDetailsModelData?.orderProps
                                  ?.map((prop) => _buildInfoRow(
                                      context,
                                      StringHelper.formatPropCode(
                                          prop.propsCode ?? ''),
                                      prop.propsValue ?? ''))
                                  ?.toList() ??
                              []),
                        ],
                      ),
                    ),
                ],
              );
      },
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    return buildCustomStyle(
      FontWeightManager.semiBold,
      isMobile ? FontSize.s14 : FontSize.s16,
      isMobile ? 0.21 : 0.24,
      ColorManager.textColor,
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required Widget child,
  }) {
    final isMobile = ResponsiveWidget.isMobile(context);
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.only(
        top: 8.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: child,
    );
  }

  Widget _buildCustomerHeader(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final nameStyle = isMobile
        ? buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.30,
            ColorManager.textColor)
        : buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s24,
            0.35,
            ColorManager.textColor);
    final dateStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s11 : FontSize.s13,
      0.20,
      ColorManager.blackWithOpacity50,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerDetails?.name ?? 'NA',
            style: nameStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((customerDetails?.phone ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              customerDetails?.phone ?? '',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                ColorManager.blackWithOpacity50,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            DateHelper.formatInputToDisplay(
              orderDetailsModelData?.orderDate?.toString() ?? '',
            ),
            style: dateStyle,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              text:
                  '${customerDetails?.name ?? "NA"} - ${customerDetails?.phone ?? ""} \n',
              style: nameStyle,
              children: <TextSpan>[
                TextSpan(
                  text: DateHelper.formatInputToDisplay(
                    orderDetailsModelData?.orderDate?.toString() ?? '',
                  ),
                  style: dateStyle,
                ),
              ],
            ),
          ),
        ),
        const BuildProfilePicture(),
      ],
    );
  }

  Widget _buildStatusChips(BuildContext context) {
    final chips = <Widget>[
      _buildStatusChip(orderDetailsModelData?.orderStatus ?? ''),
      if (orderDetailsModelData?.paymentStatus != null)
        _buildStatusChip(orderDetailsModelData?.paymentStatus ?? ''),
      if (orderDetailsModelData?.deliveryStatus != null)
        _buildStatusChip(orderDetailsModelData?.deliveryStatus ?? ''),
    ];

    if (ResponsiveWidget.isMobile(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );
    }

    return Row(
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          chips[i],
        ],
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'confirmed':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case 'paid':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        UiCodeLabels.status(status),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isMobile = ResponsiveWidget.isMobile(context);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.18,
                ColorManager.blackWithOpacity50,
              ),
            ),
            const SizedBox(height: 2),
            Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                final currency =
                    appSettingsProvider.appSettings?.currency ?? 'INR';
                return SelectableText(
                  _formatOrderPropertyValue(label, value, currency),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.18,
                    Colors.black,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Increased from 120 to prevent truncation
            child: Text(
              '$label:',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.20,
                ColorManager.blackWithOpacity50,
              ),
            ),
          ),
          Expanded(
            child: Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                final currency =
                    appSettingsProvider.appSettings?.currency ?? 'INR';
                return SelectableText(
                  _formatOrderPropertyValue(label, value, currency),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s13,
                    0.20,
                    Colors.black,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder shown for empty packing fields, matching the web Order View.
  static const String _emptyValue = '—';

  Widget _buildPackingSection(
      BuildContext context, OrderDetailsModelDataPacking? packing) {
    final photos = packing?.photosForDisplay ?? const <String>[];
    final video = packing?.packingVideo ?? '';
    final packedAt = packing?.packedAt ?? '';
    // The web view keeps these two apart: `packed_by` is the resolved staff
    // user, `packed_by_name` is the free-text name typed by whoever packed.
    final packedByStaff = packing?.packedByUserName ?? '';
    final packedByOther = packing?.packedByName ?? '';

    return _buildSectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sales_order_details.title_packing'.tr,
            style: _sectionTitleStyle(context),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            'sales_order_details.label_packing_status'.tr,
            (packing?.isPackedResolved ?? false) ? 'sales_order_details.value_packed'.tr
                : 'sales_order_details.value_not_packed'.tr,
          ),
          _buildInfoRow(
            context,
            'sales_order_details.label_packed_at'.tr,
            // packed_at arrives as UTC ("...Z"), so it must go through the
            // timezone-aware formatter, not formatInputToDisplay.
            packedAt.isEmpty
                ? _emptyValue
                : DateHelper.formatISODateToIST(packedAt),
          ),
          _buildInfoRow(
            context,
            'sales_order_details.label_packed_by_staff'.tr,
            packedByStaff.isEmpty ? _emptyValue : packedByStaff,
          ),
          _buildInfoRow(
            context,
            'sales_order_details.label_packed_by_other'.tr,
            packedByOther.isEmpty ? _emptyValue : packedByOther,
          ),
          if (photos.isEmpty)
            _buildInfoRow(context, 'sales_order_details.label_packing_photos'.tr, _emptyValue)
          else
            _buildTappableRow(
              context,
              'sales_order_details.label_packing_photos'.tr,
              photos.length == 1
                  ? 'sales_order_details.value_photo_one'.tr
                  : "${photos.length} ${'sales_order_details.value_photo_many'.tr}",
              () => _showPhotoViewer(context, photos),
            ),
          if (video.isEmpty)
            _buildInfoRow(context, 'sales_order_details.label_packing_video'.tr, _emptyValue)
          else
            _buildTappableRow(
              context,
              'sales_order_details.label_packing_video'.tr,
              'sales_order_details.btn_play_video'.tr,
              () => _openExternal(context, video),
            ),
        ],
      ),
    );
  }

  /// Mirrors the Shipping Details tab of the web Order View. Every row is
  /// always rendered, with [_emptyValue] where the backend sent nothing.
  Widget _buildShippingSection(BuildContext context,
      OrderDetailsModelDataDeliveryAddress deliveryAddress) {
    String orEmpty(String? value) =>
        (value == null || value.isEmpty) ? _emptyValue : value;

    return _buildSectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sales_order_details.title_shipping_details'.tr,
            style: _sectionTitleStyle(context),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(context, 'sales_order_details.label_delivery_method'.tr,
              orEmpty(_deliveryMethodLabel)),
          _buildInfoRow(
              context, 'sales_order_details.label_address_type'.tr, orEmpty(deliveryAddress.addressType)),
          _buildInfoRow(context, 'sales_order_details.label_shipping_address'.tr,
              orEmpty(deliveryAddress.address)),
          _buildInfoRow(context, 'sales_order_details.label_pincode'.tr, orEmpty(deliveryAddress.pincode)),
          _buildInfoRow(
              context, 'sales_order_details.label_district'.tr, orEmpty(deliveryAddress.district)),
          _buildInfoRow(context, 'sales_order_details.label_state'.tr, orEmpty(deliveryAddress.state)),
          _buildInfoRow(context, 'sales_order_details.label_city'.tr, orEmpty(deliveryAddress.city)),
          _buildInfoRow(
              context, 'sales_order_details.label_landmark'.tr, orEmpty(deliveryAddress.landmark)),
        ],
      ),
    );
  }

  /// Same shape as [_buildInfoRow] but the value is a tappable link.
  Widget _buildTappableRow(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final labelStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s12 : FontSize.s13,
      isMobile ? 0.18 : 0.20,
      ColorManager.blackWithOpacity50,
    );
    final linkStyle = buildCustomStyle(
      FontWeightManager.medium,
      isMobile ? FontSize.s12 : FontSize.s13,
      isMobile ? 0.18 : 0.20,
      ColorManager.kPrimaryColor,
    );

    final link = InkWell(
      onTap: onTap,
      child: Text(
        value,
        style: linkStyle.copyWith(decoration: TextDecoration.underline),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label:', style: labelStyle),
            const SizedBox(height: 2),
            link,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: labelStyle),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: link)),
        ],
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, List<String> photos) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _PackingPhotoViewer(photos: photos),
    );
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    bool launched = false;
    if (uri != null) {
      // launchUrl throws (not just returns false) when no handler is
      // registered for the scheme, so both paths must be covered.
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error opening packing video: $e');
      }
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sales_order_details.msg_video_open_failed'.tr)),
      );
    }
  }

  String _formatOrderPropertyValue(
      String label, String value, String currency) {
    // Format specific order properties
    switch (label.toUpperCase()) {
      case 'ORDER STATUS':
      case 'ORDER_STATUS':
        // Extract date from "confirmed - 2025-08-02 17:24:09" format
        if (value.contains(' - ')) {
          final parts = value.split(' - ');
          if (parts.length == 2) {
            final status = parts[0];
            final dateTime = parts[1];
            try {
              final date = DateTime.parse(dateTime);
              return '$status - ${DateHelper.formatTimeOnly(date.toString())}';
            } catch (e) {
              return value; // Return original if parsing fails
            }
          }
        }
        return value;
      case 'TOKEN NUMBER':
      case 'ORDER TOKEN NUMBER':
      case 'ORDER_TOKEN_NUMBER':
        return value;
      case 'BALANCE':
        // Format balance with proper currency
        final balance = double.tryParse(value) ?? 0.0;
        return '$currency ${balance.toStringAsFixed(2)}';
      case 'DELIVERY DATE':
        try {
          return DateHelper.formatISODate(value);
        } catch (e) {
          return value;
        }
      case 'CUSTOMER_PHONE':
      case 'CUSTOMER PHONE':
      case 'CUSTOMER_EMAIL':
      case 'CUSTOMER EMAIL':
        // Keep as is for contact info
        return value;
      default:
        return value;
    }
  }

  double _calculateTotalPayments(Map<String, dynamic> payments) {
    return payments.values.fold(
        0.0, (sum, value) => sum + (double.tryParse(value.toString()) ?? 0.0));
  }

  String _fmt(dynamic val) {
    if (val == null) return '0.00';
    if (val is num) return val.toStringAsFixed(2);
    if (val is String) {
      final parsed = double.tryParse(val);
      return parsed != null ? parsed.toStringAsFixed(2) : val;
    }
    return val.toString();
  }

  Widget _buildCartItemsTable(String currency, BuildContext context) {
    if (ResponsiveWidget.isMobile(context)) {
      return _buildMobileCartItemsList(currency);
    }

    final table = _buildDesktopCartItemsTable(currency);
    if (ResponsiveWidget.isTablet(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: table,
    );
  }

  Widget _buildMobileCartItemsList(String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          for (int index = 0; index < (cartItem?.length ?? 0); index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _buildMobileCartItemCard(index, cartItem![index], currency),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCartItemCard(
    int index,
    OrderDetailsModelDataCartItem item,
    String currency,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s11,
                    0.16,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'sales_order_details.value_na'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.textColor,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.formattedVariantAttributes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.formattedVariantAttributes,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s10,
                          0.16,
                          Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currency ${_fmt(item.totalPrice)}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s12,
                  0.18,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMobileDetailChip('sales_order_details.th_qty'.tr, _fmtQty(item.quantity)),
          const SizedBox(height: 6),
          _buildMobileDetailChip('sales_order_details.th_unit'.tr, _unitText(item)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMobileDetailChip('sales_order_details.th_mrp'.tr, '$currency ${_fmt(item.mrp)}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileDetailChip(
                    'sales_order_details.th_rate'.tr, '$currency ${_fmt(item.unitPrice)}'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildMobileDetailChip('sales_order_details.th_tax'.tr, '$currency ${_fmt(item.taxAmount)}'),
        ],
      ),
    );
  }

  Widget _buildMobileDetailChip(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.16,
            ColorManager.blackWithOpacity50,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.16,
              Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopCartItemsTable(String currency) {
    return Table(
        columnWidths: const {
          0: FlexColumnWidth(0.5),
          1: FlexColumnWidth(2.7),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(0.6),
          4: FlexColumnWidth(0.8),
          5: FlexColumnWidth(1.1),
          6: FlexColumnWidth(1.0),
          7: FlexColumnWidth(1.2),
        },
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
            ),
            children: [
              _buildTableCell('Sl#', isHeader: true),
              _buildTableCell('DESCRIPTION', isHeader: true),
              _buildTableCell('sales_order_details.th_mrp'.tr, isHeader: true, align: TextAlign.right),
              _buildTableCell('sales_order_details.th_qty'.tr, isHeader: true, align: TextAlign.center),
              _buildTableCell('sales_order_details.th_unit'.tr, isHeader: true, align: TextAlign.center),
              _buildTableCell('sales_order_details.th_rate'.tr, isHeader: true, align: TextAlign.right),
              _buildTableCell('sales_order_details.th_tax'.tr, isHeader: true, align: TextAlign.right),
              _buildTableCell('sales_order_details.th_amount'.tr, isHeader: true, align: TextAlign.right),
            ],
          ),
          // Data Rows
          ...List.generate(
            cartItem?.length ?? 0,
            (index) {
              final item = cartItem![index];
              return TableRow(
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : Colors.grey.shade50,
                ),
                children: [
                  _buildTableCell('${index + 1}', align: TextAlign.center),
                  _buildTableCell(item.formattedVariantAttributes.isEmpty
                      ? (item.productName ?? 'sales_order_details.value_na'.tr)
                      : '${item.productName ?? 'sales_order_details.value_na'.tr}\n${item.formattedVariantAttributes}'),
                  _buildTableCell('$currency ${_fmt(item.mrp)}',
                      align: TextAlign.right),
                  _buildTableCell('${_fmtQty(item.quantity)}',
                      align: TextAlign.center),
                  _buildTableCell(_unitText(item), align: TextAlign.center),
                  _buildTableCell('$currency ${_fmt(item.unitPrice)}',
                      align: TextAlign.right),
                  _buildTableCell('$currency ${_fmt(item.taxAmount)}',
                      align: TextAlign.right),
                  _buildTableCell('$currency ${_fmt(item.totalPrice)}',
                      align: TextAlign.right),
                ],
              );
            },
          ),
        ],
    );
  }

  String _unitText(OrderDetailsModelDataCartItem item) {
    final saleUnitName = item.saleUnitName?.trim();
    if (saleUnitName != null && saleUnitName.isNotEmpty) {
      return saleUnitName;
    }

    final productUnit = item.productUnit?.trim();
    if (productUnit != null && productUnit.isNotEmpty) {
      return productUnit;
    }

    return '-';
  }

  String _fmtQty(dynamic val) {
    if (val == null) return '0';
    if (val is num) {
      return val == val.truncate() ? val.truncate().toString() : val.toString();
    }
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) {
        return parsed == parsed.truncate()
            ? parsed.truncate().toString()
            : parsed.toString();
      }
      return val;
    }
    return val.toString();
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: isHeader ? 12.0 : 10.0,
      ),
      child: Text(
        text,
        textAlign: align,
        style: buildCustomStyle(
          isHeader ? FontWeightManager.semiBold : FontWeightManager.regular,
          isHeader ? FontSize.s12 : FontSize.s11,
          0.18,
          isHeader ? ColorManager.textColor : Colors.black87,
        ),
      ),
    );
  }
}

/// Full-screen-ish viewer for the packing photos, with swipe between
/// images and a counter. Uses the URLs returned by the API directly.
class _PackingPhotoViewer extends StatefulWidget {
  final List<String> photos;

  const _PackingPhotoViewer({required this.photos});

  @override
  State<_PackingPhotoViewer> createState() => _PackingPhotoViewerState();
}

class _PackingPhotoViewerState extends State<_PackingPhotoViewer> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${'sales_order_details.label_packing_photos'.tr}  ${_index + 1}/${widget.photos.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    widget.photos[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'sales_order_details.msg_photo_load_failed'.tr,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible section card used for low-frequency sections
/// (Order Metadata, Order Properties). Keeps the same look as
/// [_buildSectionCard] with a tappable header and a chevron.
class _ExpandableSection extends StatefulWidget {
  final String title;
  final TextStyle titleStyle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.titleStyle,
    required this.child,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.only(
        top: 8.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.title, style: widget.titleStyle),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ColorManager.kPrimaryColor,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            widget.child,
          ],
        ],
      ),
    );
  }
}
