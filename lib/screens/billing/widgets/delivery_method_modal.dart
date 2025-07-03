import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

class DeliveryMethodModal extends StatefulWidget {
  final String initialDeliveryMethod;
  final String initialDeliveryMethodId;
  final String initialCarNumber;
  final String initialComment;
  final Function(String, String, String, String) onDeliveryMethodSelected;

  const DeliveryMethodModal({
    Key? key,
    required this.initialDeliveryMethod,
    required this.initialDeliveryMethodId,
    required this.initialCarNumber,
    required this.initialComment,
    required this.onDeliveryMethodSelected,
  }) : super(key: key);

  @override
  State<DeliveryMethodModal> createState() => _DeliveryMethodModalState();
}

class _DeliveryMethodModalState extends State<DeliveryMethodModal> {
  late String deliveryMethod;
  late String deliveryMethodId;
  late TextEditingController carNumberController;
  late TextEditingController commentController;

  @override
  void initState() {
    super.initState();
    deliveryMethod = widget.initialDeliveryMethod;
    deliveryMethodId = widget.initialDeliveryMethodId;
    carNumberController = TextEditingController(text: widget.initialCarNumber);
    commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    carNumberController.dispose();
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Consumer<DeliveryMethodsProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Method',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.21,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: provider.deliveryMethods.map((method) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          deliveryMethod = method.name;
                          deliveryMethodId = method.id;
                        });
                      },
                      child: BuildBoxShadowContainer(
                        border: deliveryMethod == method.name
                            ? Border.all(color: ColorManager.kPrimaryColor)
                            : null,
                        padding: const EdgeInsets.all(12),
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
                                          : Icons.local_shipping,
                              size: 20,
                              color: Colors.black,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              method.name,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
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
                const SizedBox(height: 20),
                if (deliveryMethod == "Car Delivery") ...[
                  buildColumnWidgetForTextFields(
                    controller: carNumberController,
                    size: size,
                    height: size.height * .06,
                    hintText: 'Car Number:',
                    width: 600,
                  ),
                  const SizedBox(height: 10),
                ],
                buildColumnWidgetForTextFields(
                  controller: commentController,
                  size: size,
                  height: size.height * .06,
                  hintText: 'Comment:',
                  width: 600,
                ),
                const SizedBox(height: 20),
                CustomRoundButton(
                  title: "Apply",
                  fct: () {
                    widget.onDeliveryMethodSelected(
                      deliveryMethod,
                      deliveryMethodId,
                      carNumberController.text,
                      commentController.text,
                    );
                    Navigator.of(context).pop();
                  },
                  fontSize: FontSize.s14,
                  height: 45,
                  width: double.infinity,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 