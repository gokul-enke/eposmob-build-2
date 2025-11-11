import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:get/get.dart';

class DeliveryMethodModal extends StatefulWidget {
  final String initialDeliveryMethod;
  final String initialDeliveryMethodId;
  final String initialCarNumber;
  final String initialComment;
  final String? initialDeliveryDate;
  final String? initialDeliveryTime;
  final Function(String, String, String, String, String?, String?)
      onDeliveryMethodSelected;

  const DeliveryMethodModal({
    super.key,
    required this.initialDeliveryMethod,
    required this.initialDeliveryMethodId,
    required this.initialCarNumber,
    required this.initialComment,
    this.initialDeliveryDate,
    this.initialDeliveryTime,
    required this.onDeliveryMethodSelected,
  });

  @override
  State<DeliveryMethodModal> createState() => _DeliveryMethodModalState();
}

class _DeliveryMethodModalState extends State<DeliveryMethodModal> {
  late String deliveryMethod;
  late String deliveryMethodId;
  late TextEditingController carNumberController;
  late TextEditingController commentController;
  DateTime? selectedDeliveryDate;
  TimeOfDay? selectedDeliveryTime;

  @override
  void initState() {
    super.initState();
    deliveryMethod = widget.initialDeliveryMethod;
    deliveryMethodId = widget.initialDeliveryMethodId;
    carNumberController = TextEditingController(text: widget.initialCarNumber);
    commentController = TextEditingController(text: widget.initialComment);
    if (widget.initialDeliveryDate != null &&
        widget.initialDeliveryDate!.isNotEmpty) {
      selectedDeliveryDate = DateTime.tryParse(widget.initialDeliveryDate!);
    }
    if (widget.initialDeliveryTime != null &&
        widget.initialDeliveryTime!.isNotEmpty) {
      final parts = widget.initialDeliveryTime!.split(":");
      if (parts.length >= 2) {
        selectedDeliveryTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    carNumberController.dispose();
    commentController.dispose();
    super.dispose();
  }

  String _getDeliveryMethodTranslation(String methodName) {
    switch (methodName) {
      case "Store Takeaway":
        return 'common.store_takeaway'.tr;
      case "Car Delivery":
        return 'common.car_delivery'.tr;
      case "Door Delivery":
        return 'common.door_delivery'.tr;
      case "Third Party Logistics":
        return 'common.third_party_logistics'.tr;
      default:
        return methodName.tr;
    }
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
                      'delivery.delivery_methods'.tr,
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
                              _getDeliveryMethodTranslation(method.name),
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
                if (Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings!
                    .askDeliveryDate) ...[
                  const SizedBox(height: 20),
                  // Delivery Date (optional)
                  Text('billing.enter_car_number'.tr,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.12, Colors.black)),
                  CalendarPickerTableCell(
                    initialDate: selectedDeliveryDate,
                    onDateSelected: (date) {
                      setState(() {
                        selectedDeliveryDate = date;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  // Delivery Time (optional)
                  Text('common.select'.tr,
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.12, Colors.black)),
                  TimePickerTableCell(
                    initialTime: selectedDeliveryTime,
                    onTimeSelected: (time) {
                      setState(() {
                        selectedDeliveryTime = time;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),
                if (deliveryMethod == "Car Delivery") ...[
                  buildColumnWidgetForTextFields(
                    controller: carNumberController,
                    size: size,
                    height: size.height * .06,
                    hintText: 'Car Number:',
                    width: 600,
                    onTap: () {
                      Provider.of<KeyboardProvider>(context, listen: false)
                          .show('text', carNumberController,
                              replaceOnFirstInput: true);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                buildColumnWidgetForTextFields(
                  controller: commentController,
                  size: size,
                  height: size.height * .06,
                  hintText: 'Comment:',
                  width: 600,
                  onTap: () {
                    Provider.of<KeyboardProvider>(context, listen: false).show(
                        'text', commentController,
                        replaceOnFirstInput: true);
                  },
                ),
                const SizedBox(height: 20),
                CustomRoundButton(
                  title: 'common.select'.tr,
                  fct: () {
                    widget.onDeliveryMethodSelected(
                      deliveryMethod,
                      deliveryMethodId,
                      carNumberController.text,
                      commentController.text,
                      selectedDeliveryDate != null
                          ? selectedDeliveryDate!.toIso8601String()
                          : '',
                      selectedDeliveryTime != null
                          ? selectedDeliveryTime!.format(context)
                          : '',
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
