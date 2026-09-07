import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import '../../components/add_customer_form.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddCustomersScreen extends StatefulWidget {
  const AddCustomersScreen({super.key});

  @override
  State<AddCustomersScreen> createState() => _AddCustomersScreenState();
}

class _AddCustomersScreenState extends State<AddCustomersScreen> {
  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());

    return SafeArea(
      child: Scaffold(
        body: Container(
          margin: const EdgeInsets.all(10),
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
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBackButton(
                          onPressed: () {
                            sideBarController.index.value = 5;
                          },
                          text: 'add_customer.back_to_customers'.tr,
                        ),
                        Text(
                          'add_customer.title'.tr,
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s20, 0.30, ColorManager.textColor),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Use the unified form
                  const AddCustomerForm(
                    isModal: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

