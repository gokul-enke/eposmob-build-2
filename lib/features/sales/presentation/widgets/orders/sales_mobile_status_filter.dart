import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/sales_list_controller.dart';
import 'sales_filter_field.dart';
import 'sales_status_labels.dart';

class SalesMobileStatusFilter extends StatelessWidget {
  const SalesMobileStatusFilter({super.key, required this.controller});
  final SalesListController controller;
  @override
  Widget build(BuildContext context) {
    return SalesFilterField(
      label: 'sales.status'.tr,
      child: SizedBox(
        height: 45,
        child: BuildBoxShadowContainer(
          circleRadius: 10,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.only(left: 15),
          color: Colors.white,
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            value: controller.selectedStatus,
            isExpanded: true,
            dropdownColor: Colors.white,
            hint: Text(
              'sales.select_status'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s10,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'common.all'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
              ),
              ...salesStatusOptions.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    salesStatusLabel(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.27,
                      ColorManager.textColor.withOpacity(.5),
                    ),
                  ),
                );
              }),
            ],
            onChanged: (String? status) {
              controller.update(() {
                controller.selectedStatus = status;
                if (status != null) {
                  controller.statusController.text = status;
                } else {
                  controller.statusController.clear();
                }
              });
              controller.searchOrders(1);
            },
          ),
        ),
      ),
    );
  }
}
