import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import '../../models/list_sales_order.dart';
import '../../providers/sales_provider.dart';

class HorizontalSalesView extends StatelessWidget {
  const HorizontalSalesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    return Consumer<SalesProvider>(
      builder: (context, orderProvider, child) {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        orderProvider.fetchOrders(
          accessToken: accessToken ?? '',
          storeId: 1,
        );
        // Filter orders to only include those with status "new"
        List<ListOrderModelData> orders = orderProvider.orders
            .where((order) => order.status == "new")
            .take(5)
            .toList();
            
        if (orders.isEmpty) {
          return Container();
        }

        return SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: orders.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, index) {
              ListOrderModelData order = orders[index];
              return GestureDetector(
                onTap: () async {
                  Provider.of<CartProvider>(context, listen: false)
                      .setCartIDForOrder(int.parse(order.cartId.toString()));
                  orderProvider.setOrderNumber(order.orderNumber.toString());
                  orderProvider.setOrderId(order.id.toString());
                  sideBarController.index.value = 51;
                },
                child: BuildBoxShadowContainer(
                  margin: const EdgeInsets.only(right: 8),
                  width: 140,
                  circleRadius: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "#${order.orderNumber}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rs ${order.priceSummary?.grandTotal} (  ${order.cartItems?.length} )",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
