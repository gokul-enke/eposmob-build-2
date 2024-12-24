import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (customerDetails == null || cartItem == null || priceSummary == null) {
      return const Center(
        child: Text('Order details are not available.'),
      );
    }

    return SingleChildScrollView( // Removed Expanded
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        text: '${customerDetails!.name ?? "No Name"}\n',
                        style: ResponsiveWidget.isMobile(context)
                            ? buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s12, 0.30, ColorManager.textColor)
                            : buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s24, 0.35, ColorManager.textColor),
                        children: <TextSpan>[
                          TextSpan(
                            text: '${orderDetailsModelData!.orderDate}',
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
                  physics: const NeverScrollableScrollPhysics(), // Prevent scrolling
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      minLeadingWidth: 0,
                      minVerticalPadding: 0,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(horizontal: 0, vertical: 0),
                      leading: Text(
                        '${index + 1}',
                        style: buildCustomStyle(FontWeightManager.regular,
                            FontSize.s15, 0.23, Colors.black),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: '${cartItem![index].productName}\n',
                              style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s13,
                                  0.20,
                                  Colors.black),
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
                          Text(
                            '${cartItem![index].currency} ${cartItem![index].unitPrice}',
                            style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.21,
                                ColorManager.blackWithOpacity50),
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
                          amount: priceSummary!.netTotal!.toStringAsFixed(2),
                          title: "Net amount",
                          color: ColorManager.textColor,
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
        ],
      ),
    );
  }
}
