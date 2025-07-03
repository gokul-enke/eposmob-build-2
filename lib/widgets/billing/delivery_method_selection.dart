import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class DeliveryMethodSelection extends StatelessWidget {
  final String deliveryMethod;
  final Function(String, String) onDeliveryMethodSelected;
  final TextEditingController carNumberController;
  final TextEditingController commentController;

  const DeliveryMethodSelection({
    Key? key,
    required this.deliveryMethod,
    required this.onDeliveryMethodSelected,
    required this.carNumberController,
    required this.commentController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Consumer<DeliveryMethodsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Container();
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildPaymentRow(
              amount: "",
              title: "Delivery Method",
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.21,
                ColorManager.kPrimaryColor,
              ),
              color: ColorManager.kPrimaryColor,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: provider.deliveryMethods.map((DeliveryMethod method) {
                return GestureDetector(
                  onTap: () {
                    onDeliveryMethodSelected(method.name, method.id);
                  },
                  child: BuildBoxShadowContainer(
                    border: deliveryMethod == method.name
                        ? Border.all(color: ColorManager.kPrimaryColor)
                        : null,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    blurRadius: 4,
                    circleRadius: 5,
                    child: Column(
                      children: [
                        Icon(
                          method.name == "Store Takeaway"
                              ? Icons.store
                              : method.name == "Car Delivery"
                                  ? Icons.car_rental
                                  : method.name == "Door Delivery"
                                      ? Icons.doorbell_outlined
                                      : Icons
                                          .local_shipping, // Default icon for other methods
                          size: 16,
                          color: Colors.black,
                        ),
                        Text(
                          method.name,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s10,
                            0.12,
                            Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            if (deliveryMethod == "Car Delivery")
              SizedBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildColumnWidgetForTextFields(
                      controller: carNumberController,
                      size: size,
                      margin: const EdgeInsets.all(0),
                      height: size.height * .06,
                      hintText: 'Car Number:',
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            buildColumnWidgetForTextFields(
              controller: commentController,
              margin: const EdgeInsets.all(0),
              size: size,
              height: size.height * .06,
              hintText: 'Comment:',
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
} 