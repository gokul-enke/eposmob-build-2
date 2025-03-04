import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_details_widget.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_return_details_widget.dart';
import 'package:provider/provider.dart';
import '../../../components/build_container_box.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../providers/auth_model.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

class SalesOrderDetailsScreen extends StatefulWidget {
  const SalesOrderDetailsScreen({Key? key}) : super(key: key);

  @override
  State<SalesOrderDetailsScreen> createState() =>
      _SalesOrderDetailsScreenState();
}

class _SalesOrderDetailsScreenState extends State<SalesOrderDetailsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  OrderDetailsModelDataCustomerDetails? customerDetails;
  OrderDetailsModelDataCart? cart;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  OrderDetailsModelDataPriceSummary? priceSummary;

  @override
  void initState() {
    super.initState();
    getOrderDetails();
  }

  Future<void> getOrderDetails() async {
    setState(() {
      isInitLoading = true;
    });

    try {
      String ordersId =
          Provider.of<SalesProvider>(context, listen: false).getOrderNumber;
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      final response = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");
      if (response["status"] == "success") {
        setState(() {
          OrderDetailsModel? orderDetails;
          try {
            orderDetails = OrderDetailsModel.fromJson(response);
          } catch (e) {
            debugPrint("Error parsing JSON data: $e");
          }
          orderDetailsModelData = orderDetails!.data;
          cart = orderDetailsModelData?.cart;
          priceSummary = cart?.priceSummary;
          customerDetails = orderDetailsModelData?.customerDetails;
          cartItems = cart?.cartItems;
          orderNumber = orderDetailsModelData?.orderNumber ?? "";
        });
      } else {
        setState(() {
          orderNumber = "Order Details Not found";
        });
      }
    } catch (error) {
      // debugPrint(error.toString());
      setState(() {
        orderNumber = "Error fetching order details";
      });
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
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(10.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: isInitLoading
                ? SizedBox(
                    height: size.height,
                    child: const Center(
                        child: CircularProgressIndicator.adaptive()))
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align items to start
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 10),
                      Text(
                        'Order Details - # $orderNumber',
                        style: ResponsiveWidget.isMobile(context)
                            ? buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s12, 0.30, ColorManager.textColor)
                            : buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s20, 0.30, ColorManager.textColor),
                        overflow: TextOverflow.ellipsis, // Handle overflow
                      ),
                      const SizedBox(height: 10),
                      _buildOrderDetails(),
                      const SizedBox(height: 10),
                      _buildOrderReturns(),
                      const SizedBox(height: 10),
                      _buildPrintButton(size),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            sideBarController.index.value = 2;
          },
          text: 'All Orders',
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
            icon:
                const Icon(Icons.close_rounded, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    if (orderDetailsModelData == null) {
      return const Text("No order details available.");
    }
    return OrderDetailWidget(
      orderDetailsModelData: orderDetailsModelData,
      priceSummary: priceSummary,
      cartItem: cartItems,
      customerDetails: customerDetails,
    );
  }

  Widget _buildOrderReturns() {
    // Check if orderReturns is null or has no return items
    if (orderDetailsModelData?.orderReturns == null ||
        (orderDetailsModelData!.orderReturns!.returnItems?.isEmpty ?? true)) {
      return const SizedBox(); // Return an empty SizedBox to hide the widget
    }

    // If there are return items, show the OrderReturnsWidget
    return OrderReturnsWidget(
      orderReturns: orderDetailsModelData!.orderReturns,
    );
  }

  Widget _buildPrintButton(Size size) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: CustomRoundButton(
        title: "Print",
        boxColor: Colors.white,
        textColor: ColorManager.kPrimaryColor,
        fct: () async {
          String formattedTotal = AmountHelper.formatAmount(
            orderDetailsModelData?.cart?.priceSummary?.netTotal ?? 0.00,
          );
          String savedTotal = AmountHelper.formatAmount(
            orderDetailsModelData?.cart?.priceSummary?.savedTotal ?? 0.00,
          );
          String storeName = orderDetailsModelData!.cart!.storeName ?? "";
          String orderDate = orderDetailsModelData!.orderDate ?? "";

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrintPage(
                storeName: storeName,
                cartItems: cartItems!,
                formattedTotal: formattedTotal,
                savedTotal: savedTotal,
                orderDate: orderDate,
                orderNumber: orderNumber,
              ),
            ),
          );
        },
        height: 50,
        width: size.width * 0.19,
        fontSize: FontSize.s12,
      ),
    );
  }
}
