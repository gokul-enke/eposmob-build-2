import 'package:flutter/material.dart';

import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/features/billing/presentation/widgets/orders_tab.dart';
import 'package:pos_machine/components/build_round_button.dart';

class SidebarWidget extends StatelessWidget {
  final int selectedTab; // 0 = Products, 1 = Orders
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleSidebar;
  final void Function(String orderId) onOrderSelected;

  const SidebarWidget({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
    required this.onToggleSidebar,
    required this.onOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
      child: Stack(
        children: [
          Column(
            children: [
              // Tabs header
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectTab(0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: selectedTab == 0 ? ColorManager.kPrimaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Products',
                                style: TextStyle(
                                  color: selectedTab == 0 ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelectTab(1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: selectedTab == 1 ? ColorManager.kPrimaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Orders',
                                style: TextStyle(
                                  color: selectedTab == 1 ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
              ),
              // Tab body
              Expanded(
                child: Container(
                  child: selectedTab == 0
                      ? const SideBarProductList()
                      : OrdersTab(
                          onOrderSelected: onOrderSelected,
                        ),
                ),
              ),
            ],
          ),
          // Toggle button
          Positioned(
            top: 10,
            right: 8,
            child: CustomRoundButton(
              title: "×",
              fct: onToggleSidebar,
              fontSize: 18,
              height: 35,
              width: 35,
              boxColor: ColorManager.kPrimaryColor,
              borderColor: ColorManager.kPrimaryColor,
              textColor: Colors.white,
              radius: 8,
            ),
          ),
        ],
      ),
    );
  }
}
