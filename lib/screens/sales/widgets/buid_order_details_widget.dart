import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../../../components/build_container_box.dart';
import '../../../components/build_payment_row.dart';
import '../../../components/build_profile_picture.dart';
import '../../../models/order_details.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

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

  @override
  Widget build(BuildContext context) {
    if (customerDetails == null || cartItem == null || priceSummary == null) {
      return const Center(
        child: Text('Order details are not available.'),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          // Removed Expanded
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original Order Details Section (FIRST)
              BuildBoxShadowContainer(
                circleRadius: 7,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(top: 13.0, left: 8, right: 8),
                offsetValue: const Offset(1, 1),
                child: Column(
                  children: [
                    // Customer Details and Order Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text:
                                '${customerDetails!.name ?? "NA"} - ${customerDetails!.phone ?? ""} \n',
                            style: ResponsiveWidget.isMobile(context)
                                ? buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s12, 0.30, ColorManager.textColor)
                                : buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s24, 0.35, ColorManager.textColor),
                            children: <TextSpan>[
                              TextSpan(
                                text: DateHelper.formatISODate(
                                    orderDetailsModelData!.orderDate.toString()),
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    ColorManager.blackWithOpacity50),
                              ),
                            ],
                          ),
                        ),
                        const BuildProfilePicture(),
                      ],
                    ),
                    // Cart Items List
                    ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: cartItem!.length,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Prevent scrolling
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          minLeadingWidth: 0,
                          minVerticalPadding: 0,
                          contentPadding: EdgeInsets.zero,
                          visualDensity:
                              const VisualDensity(horizontal: 0, vertical: 0),
                          leading: Text(
                            '${index + 1}',
                            style: buildCustomStyle(FontWeightManager.regular,
                                FontSize.s15, 0.23, Colors.black),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 3,
                                child: RichText(
                                  text: TextSpan(
                                    text: '${cartItem![index].productName}\n',
                                    style: buildCustomStyle(FontWeightManager.regular,
                                        FontSize.s13, 0.20, Colors.black),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text:
                                            '${cartItem![index].quantity} * ${cartItem![index].unitPrice}',
                                        style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s9,
                                            0.13,
                                            ColorManager.blackWithOpacity50),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'MRP: ${cartItem![index].currency} ${cartItem![index].mrp}',
                                      style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s11,
                                          0.16,
                                          ColorManager.blackWithOpacity50),
                                    ),
                                    Text(
                                      '${cartItem![index].currency} ${cartItem![index].totalPrice}',
                                      style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s14,
                                          0.21,
                                          Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14.0),
                        child: Column(
                          children: [
                            // Displaying Price Summary
                            BuildPaymentRow(
                              amount: "INR ${_calculateTotalMRP().toStringAsFixed(2)}",
                              title: "Total MRP",
                              color: ColorManager.textColor,
                            ),
                            BuildPaymentRow(
                              amount: priceSummary!.netTotal!.toStringAsFixed(2),
                              title: "Net amount",
                              color: ColorManager.textColor,
                            ),
                            if (priceSummary!.savedTotal != null && priceSummary!.savedTotal! > 0)
                              BuildPaymentRow(
                                amount: "INR ${priceSummary!.savedTotal!.toStringAsFixed(2)}",
                                title: "You saved",
                                color: ColorManager.kButtonGreen,
                                firstRowTextStyle: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.21,
                                  ColorManager.kButtonGreen,
                                ),
                                secondRowTextStyle: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.21,
                                  ColorManager.kButtonGreen,
                                ),
                              ),
                            BuildPaymentRow(
                              amount: "${priceSummary!.discount ?? 0.00}",
                              title: "Discount",
                              color: ColorManager.textColor,
                            ),
                            BuildPaymentRow(
                              amount: "${priceSummary!.totalTax ?? 0}.00",
                              title: "Tax Amount",
                              color: ColorManager.textColor,
                            ),
                            const Divider(thickness: 2),
                            BuildPaymentRow(
                              amount: priceSummary!.netPayable!.toStringAsFixed(2),
                              title: "Payable",
                              secondRowTextStyle: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s15,
                                0.23,
                                ColorManager.textColor,
                              ),
                              firstRowTextStyle: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s15,
                                0.23,
                                ColorManager.textColor,
                              ),
                              color: ColorManager.textColor,
                            ),
                            BuildPaymentRow(
                              amount: "Rs 0.00", // Adjust if necessary
                              title: "Balance amount",
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
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Status',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.24,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusChip(orderDetailsModelData!.orderStatus!),
                          const SizedBox(width: 12),
                          if (orderDetailsModelData?.paymentStatus != null)
                            _buildStatusChip(orderDetailsModelData!.paymentStatus!),
                          if (orderDetailsModelData?.deliveryStatus != null) ...[
                            const SizedBox(width: 12),
                            _buildStatusChip(orderDetailsModelData!.deliveryStatus!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

              // Store & Delivery Info Section
              if (orderDetailsModelData?.storeName != null || orderDetailsModelData?.deliveryMethodName != null)
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store & Delivery',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.24,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (orderDetailsModelData?.storeName != null)
                        _buildInfoRow('Store', orderDetailsModelData!.storeName!),
                      if (orderDetailsModelData?.deliveryMethodName != null)
                        _buildInfoRow('Delivery Method', orderDetailsModelData!.deliveryMethodName!),
                    ],
                  ),
                ),

              // Payment Details Section
              if (orderDetailsModelData?.paymentDetails != null)
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.24,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (orderDetailsModelData?.paymentDetails?.paymentMethod != null)
                        _buildInfoRow('Payment Method', 
                          orderDetailsModelData!.paymentDetails!.paymentMethod is List 
                            ? (orderDetailsModelData!.paymentDetails!.paymentMethod as List).join(', ')
                            : orderDetailsModelData!.paymentDetails!.paymentMethod.toString()
                        ),
                      if (orderDetailsModelData?.paymentDetails?.transactionId != null)
                        _buildInfoRow('Transaction ID', orderDetailsModelData!.paymentDetails!.transactionId.toString()),
                    ],
                  ),
                ),

              // Customer Extended Info Section
              if (customerDetails?.email != null || (customerDetails?.address != null && customerDetails!.address!.isNotEmpty))
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Information',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.24,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (customerDetails?.email != null)
                        _buildInfoRow('Email', customerDetails!.email!),
                      if (customerDetails?.address != null && customerDetails!.address!.isNotEmpty)
                        _buildInfoRow('Address', customerDetails!.address!.join(', ')),
                    ],
                  ),
                ),

              // Order Properties Section (Custom Fields)
              if (orderDetailsModelData?.orderProps != null && orderDetailsModelData!.orderProps!.isNotEmpty)
                BuildBoxShadowContainer(
                  circleRadius: 7,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                  offsetValue: const Offset(1, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Properties',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.24,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...orderDetailsModelData!.orderProps!.map((prop) => 
                        _buildInfoRow(prop.propsCode ?? '', prop.propsValue ?? '')
                      ).toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
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
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            child: Text(
              _formatOrderPropertyValue(label, value),
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.20,
                Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatOrderPropertyValue(String label, String value) {
    // Format specific order properties
    switch (label.toUpperCase()) {
      case 'ORDER_STATUS':
        // Extract date from "confirmed - 2025-08-02 17:24:09" format
        if (value.contains(' - ')) {
          final parts = value.split(' - ');
          if (parts.length == 2) {
            final status = parts[0];
            final dateTime = parts[1];
            try {
              final date = DateTime.parse(dateTime);
              return '$status - ${DateHelper.formatISODate(date.toString())}';
            } catch (e) {
              return value; // Return original if parsing fails
            }
          }
        }
        return value;
      case 'BALANCE':
        // Format balance with proper currency
        final balance = double.tryParse(value) ?? 0.0;
        return 'Rs ${balance.toStringAsFixed(2)}';
      case 'CUSTOMER_PHONE':
      case 'CUSTOMER_EMAIL':
        // Keep as is for contact info
        return value;
      default:
        return value;
    }
  }
}
