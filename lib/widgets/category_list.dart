import 'package:flutter/material.dart';
import 'package:pos_machine/widgets/category_list_item.dart';
import 'package:pos_machine/widgets/order_list.dart';

import '../resources/color_manager.dart';
import '../responsive.dart';

class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

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
                    flex: 7500,
                    child: CategoryListItem(),
                  ),
                  Expanded(
                    flex: 2500,
                    child: OrderList(),
                  ),
                ],
              )
            : const Row(
                children: [
                  Expanded(
                    flex: 5500,
                    child: CategoryListItem(),
                  ),
                  Expanded(
                    flex: 4500,
                    child: OrderList(),
                  ),
                ],
              ),
      ),
    );
  }
}
