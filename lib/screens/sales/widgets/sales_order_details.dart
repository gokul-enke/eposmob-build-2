import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';

import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_details_widget.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';

import '../../../controllers/sidebar_controller.dart';
import '../../../providers/auth_model.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

class SalesOrderDetailsScreen extends StatefulWidget {
  const SalesOrderDetailsScreen({
    super.key,
  });

  @override
  State<SalesOrderDetailsScreen> createState() =>
      _SalesOrderDetailsScreenState();
}

class _SalesOrderDetailsScreenState extends State<SalesOrderDetailsScreen> {
  SideBarController sideBarController = Get.put(SideBarController());
  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  OrderDetailsModelDataCustomerDetails? customerDetails;
  OrderDetailsModelDataCart? cart;
  OrderDetailsModelDataCartItem? cartItem;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  OrderDetailsModelDataPriceSummary? priceSummary;

  @override
  void initState() {
    super.initState();
    getOrderDetails();
  }

  void getOrderDetails() async {
    try {
      setState(() {
        isInitLoading = true;
      });

      String ordersId =
          Provider.of<SalesProvider>(context, listen: false).getOrderId;
      debugPrint(ordersId);
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "")
          .then((resposne) {
        if (resposne["status"] == "success") {
          setState(() {
            OrderDetailsModel orderDetails =
                OrderDetailsModel.fromJson(resposne);
            orderDetailsModelData = orderDetails.data;
            priceSummary = orderDetailsModelData!.priceSummary;
            cart = orderDetailsModelData!.cart;
            customerDetails = orderDetailsModelData!.customerDetails;
            cartItems = cart!.cartItems;
            orderNumber = orderDetailsModelData!.orderNumber ?? "";
          });
        } else {
          orderNumber = "Order Details Not found";
        }
      });
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
              color: Colors.white),
          child: Padding(
            padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
            child: isInitLoading
                ?
                // ? Platform.isIOS
                //     ? SizedBox(
                //         height: size.height,
                //         child: const CircularProgressIndicator.adaptive())
                //     :
                const Center(child: CircularProgressIndicator.adaptive())
                : orderDetailsModelData == null
                    ? ListView(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  CustomBackButton(
                                    onPressed: () {
                                      sideBarController.index.value = 2;
                                    },
                                    text: 'All Orders',
                                    // Optionally, you can customize the color and size
                                    // color: ColorManager.customColor,
                                    // size: 20.0,
                                  ),
                                  Text(
                                    'Order Details - # $orderNumber',
                                    style: ResponsiveWidget.isMobile(context)
                                        ? buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s12,
                                            0.30,
                                            ColorManager.textColor)
                                        : buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s20,
                                            0.30,
                                            ColorManager.textColor),
                                  ),
                                ],
                              ),
                              BuildBoxShadowContainer(
                                width: 15,
                                height: 15,
                                circleRadius: 10,
                                color: ColorManager.kPrimaryColor,
                                child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      sideBarController.index.value = 2;
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    )),
                              )
                            ],
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          CustomBackButton(
                            onPressed: () {
                              sideBarController.index.value = 2;
                            },
                            text: 'All Orders',
                            // Optionally, you can customize the color and size
                            // color: ColorManager.customColor,
                            // size: 20.0,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order Details - # $orderNumber', //(${orderDetailsModelData!.orderStatus ?? ""})
                                style: ResponsiveWidget.isMobile(context)
                                    ? buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s12,
                                        0.30,
                                        ColorManager.textColor)
                                    : buildCustomStyle(
                                        FontWeightManager.semiBold,
                                        FontSize.s20,
                                        0.30,
                                        ColorManager.textColor),
                              ),
                              BuildBoxShadowContainer(
                                width: 15,
                                height: 15,
                                circleRadius: 10,
                                color: ColorManager.kPrimaryColor,
                                child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      sideBarController.index.value = 2;
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    )),
                              )
                            ],
                          ),
                          Row(
                            children: [
                              OrderDetailWidget(
                                orderDetailsModelData: orderDetailsModelData,
                                priceSummary: priceSummary,
                                cartItem: cartItems,
                                customerDetails: customerDetails,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 10.0, top: 10),
                                child: CustomRoundButton(
                                  title: "Print",
                                  boxColor: Colors.white,
                                  textColor: ColorManager.kPrimaryColor,
                                  fct: () async {
                                    String formattedTotal =
                                        AmountHelper.formatAmount(
                                            Provider.of<CartProvider>(context,
                                                    listen: false)
                                                .priceSummary!
                                                .netTotal);

                                    debugPrint(Provider.of<PurchaseProvider>(
                                            context,
                                            listen: false)
                                        .getStoreNameFromId(
                                            orderDetailsModelData!.storeId ??
                                                0));
                                    // debugPrint(formattedTotal
                                    //     .toString());

                                    // for (var item in cartItems!) {
                                    //   debugPrint(item.productName.toString());
                                    //   debugPrint(
                                    //       "aaa aaa ${item.productName.toString()}");
                                    // }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PrintPage(
                                          storeName:
                                              Provider.of<PurchaseProvider>(
                                                      context,
                                                      listen: false)
                                                  .getStoreNameFromId(
                                                      orderDetailsModelData!
                                                              .storeId ??
                                                          0),
                                          cartItems: cartItems!,
                                          formattedTotal: formattedTotal,
                                          orderDate: DateHelper.formatDate(
                                              DateTime.now()),
                                          orderNumber: orderNumber,
                                        ),
                                      ),
                                    );
                                  },
                                  height: 50,
                                  width: size.width * 0.19,
                                  fontSize: FontSize.s12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          )),
    );
  }
}
