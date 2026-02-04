import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/helpers/date_helper.dart';
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
    if (customerDetails == null || cartItem == null || priceSummary == null) {
      return const Center(
        child: Text('Order details are not available.'),
      );
    }

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? '';

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
                                    '${customerDetails?.name ?? "NA"} - ${customerDetails?.phone ?? ""} \n',
                                style: ResponsiveWidget.isMobile(context)
                                    ? buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.30,
                                        ColorManager.textColor)
                                    : buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s24,
                                        0.35,
                                        ColorManager.textColor),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: DateHelper.formatInputToDisplay(
                                        orderDetailsModelData?.orderDate
                                                ?.toString() ??
                                            ''),
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
                        // Cart Items Table - Same design as Return Order Details
                        _buildCartItemsTable(currency),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14.0),
                            child: Column(
                              children: [
                                // Displaying Price Summary
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${priceSummary?.netTotal?.toStringAsFixed(2) ?? '0.00'}",
                                  title: "Net amount",
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
                                      "$currency ${_calculateTotalMRP().toStringAsFixed(2)}",
                                  title: "Total MRP",
                                  color: ColorManager.textColor,
                                ),
                                if ((priceSummary?.savedTotal ?? 0) > 0)
                                  BuildPaymentRow(
                                    amount:
                                        "$currency ${priceSummary?.savedTotal?.toStringAsFixed(2) ?? '0.00'}",
                                    title: "You saved",
                                    color: ColorManager.textColor,
                                    // firstRowTextStyle: buildCustomStyle(
                                    //   FontWeightManager.semiBold,
                                    //   FontSize.s14,
                                    //   0.21,
                                    //   ColorManager.kButtonGreen,
                                    // ),
                                    // secondRowTextStyle: buildCustomStyle(
                                    //   FontWeightManager.semiBold,
                                    //   FontSize.s14,
                                    //   0.21,
                                    //   ColorManager.kButtonGreen,
                                    // ),
                                  ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${priceSummary?.discount?.toStringAsFixed(2) ?? '0.00'}",
                                  title: "Discount",
                                  color: ColorManager.textColor,
                                ),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${priceSummary?.totalTax?.toStringAsFixed(2) ?? '0.00'}",
                                  title: "Tax Amount",
                                  color: ColorManager.textColor,
                                ),
                                const Divider(thickness: 2),
                                BuildPaymentRow(
                                  amount:
                                      "$currency ${priceSummary?.netPayable?.toStringAsFixed(2) ?? '0.00'}",
                                  title: "Payable",
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
                                      "$currency 0.00", // Adjust if necessary
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
                      margin:
                          const EdgeInsets.only(top: 8.0, left: 8, right: 8),
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
                              _buildStatusChip(
                                  orderDetailsModelData?.orderStatus ?? ''),
                              const SizedBox(width: 12),
                              if (orderDetailsModelData?.paymentStatus != null)
                                _buildStatusChip(
                                    orderDetailsModelData?.paymentStatus ?? ''),
                              if (orderDetailsModelData?.deliveryStatus !=
                                  null) ...[
                                const SizedBox(width: 12),
                                _buildStatusChip(
                                    orderDetailsModelData?.deliveryStatus ??
                                        ''),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Store & Delivery Info Section
                  if (orderDetailsModelData?.storeName != null ||
                      orderDetailsModelData?.deliveryMethodName != null)
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      padding: const EdgeInsets.all(16),
                      margin:
                          const EdgeInsets.only(top: 8.0, left: 8, right: 8),
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
                            _buildInfoRow('Store',
                                orderDetailsModelData?.storeName ?? ''),
                          if (orderDetailsModelData?.deliveryMethodName != null)
                            _buildInfoRow(
                                'Delivery Method',
                                orderDetailsModelData?.deliveryMethodName ??
                                    ''),
                          _buildInfoRow(
                              'Executive Name', 'Sales Executive eposEnke')
                        ],
                      ),
                    ),

                  // Payment Details Section
                  if (orderDetailsModelData?.paymentDetails != null)
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      padding: const EdgeInsets.all(16),
                      margin:
                          const EdgeInsets.only(top: 8.0, left: 8, right: 8),
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
                          if (orderDetailsModelData
                                  ?.paymentDetails?.paymentMethod !=
                              null)
                            _buildInfoRow(
                                'Payment Method',
                                orderDetailsModelData
                                        ?.paymentDetails?.paymentMethod ??
                                    ''),
                          if (orderDetailsModelData
                                  ?.paymentDetails?.transactionId !=
                              null)
                            _buildInfoRow(
                                'Transaction ID',
                                orderDetailsModelData
                                        ?.paymentDetails?.transactionId
                                        ?.toString() ??
                                    ''),

                          // Add payment breakdown
                          if (orderDetailsModelData?.payments != null &&
                              (orderDetailsModelData?.payments?.isNotEmpty ??
                                  false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Payment Breakdown:',
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
                                            Text(
                                              entry.key,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s11,
                                                0.16,
                                                ColorManager.textColor,
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
                                    'Total Paid:',
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
                      (customerDetails?.address != null &&
                          (customerDetails?.address?.isNotEmpty ?? false)))
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      padding: const EdgeInsets.all(16),
                      margin:
                          const EdgeInsets.only(top: 8.0, left: 8, right: 8),
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
                            _buildInfoRow(
                                'Email', customerDetails?.email ?? ''),
                          if (customerDetails?.address != null &&
                              (customerDetails?.address?.isNotEmpty ?? false))
                            _buildInfoRow(
                                'Address',
                                _formatCustomerAddressList(
                                    customerDetails?.address)),
                        ],
                      ),
                    ),

                  // Order Properties Section (Custom Fields)
                  if (orderDetailsModelData?.orderProps != null &&
                      (orderDetailsModelData?.orderProps?.isNotEmpty ?? false))
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      padding: const EdgeInsets.all(16),
                      margin:
                          const EdgeInsets.only(top: 8.0, left: 8, right: 8),
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
                          ...(orderDetailsModelData?.orderProps
                                  ?.map((prop) => _buildInfoRow(
                                      StringHelper.formatPropCode(
                                          prop.propsCode ?? ''),
                                      prop.propsValue ?? ''))
                                  ?.toList() ??
                              []),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
            child: Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                final currency =
                    appSettingsProvider.appSettings?.currency ?? 'INR';
                return Text(
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

  String _formatOrderPropertyValue(
      String label, String value, String currency) {
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
              return '$status - ${DateHelper.formatTimeOnly(date.toString())}';
            } catch (e) {
              return value; // Return original if parsing fails
            }
          }
        }
        return value;
      case 'BALANCE':
        // Format balance with proper currency
        final balance = double.tryParse(value) ?? 0.0;
        return '$currency ${balance.toStringAsFixed(2)}';
      case 'CUSTOMER_PHONE':
      case 'CUSTOMER_EMAIL':
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

  Widget _buildCartItemsTable(String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.5),
          1: FlexColumnWidth(3.0),
          2: FlexColumnWidth(1.1),
          3: FlexColumnWidth(0.6),
          4: FlexColumnWidth(1.1),
          5: FlexColumnWidth(1.0),
          6: FlexColumnWidth(1.2),
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
              _buildTableCell('MRP', isHeader: true, align: TextAlign.right),
              _buildTableCell('QTY', isHeader: true, align: TextAlign.center),
              _buildTableCell('RATE', isHeader: true, align: TextAlign.right),
              _buildTableCell('TAX', isHeader: true, align: TextAlign.right),
              _buildTableCell('AMOUNT', isHeader: true, align: TextAlign.right),
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
                  _buildTableCell(item.productName ?? 'N/A'),
                  _buildTableCell('$currency ${_fmt(item.mrp)}',
                      align: TextAlign.right),
                  _buildTableCell('${_fmtQty(item.quantity)}',
                      align: TextAlign.center),
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
      ),
    );
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
