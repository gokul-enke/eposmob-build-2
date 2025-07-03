import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/screens/homenew/category_list_item_new.dart';
import 'package:pos_machine/screens/homenew/order_list_new.dart';

class HomeNew extends StatelessWidget {
  const HomeNew({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 10, right: 10),
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
        child: ResponsiveWidget.isMobile(context)
            ? const Column(
                children: [
                  Expanded(
                    flex: 2500,
                    child: OrderListNew(),
                  ),
                  Expanded(
                    flex: 7500,
                    child: CategoryListItemNew(),
                  ),
                ],
              )
            : const Row(
                children: [
                  Expanded(
                    flex: 6000,
                    child: OrderListNew(),
                  ),
                  Expanded(
                    flex: 4000,
                    child: CategoryListItemNew(),
                  ),
                ],
              ),
      ),
    );
  }
}
