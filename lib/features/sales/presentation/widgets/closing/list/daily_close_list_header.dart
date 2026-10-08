import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class DailyCloseListHeader extends StatelessWidget {
  const DailyCloseListHeader(
      {super.key,
      required this.isMobile,
      required this.canOpenShift,
      required this.onOpenShift,
      required this.onDayClose,
      required this.filterToggle});
  final bool isMobile;
  final bool canOpenShift;
  final VoidCallback onOpenShift;
  final VoidCallback onDayClose;
  final Widget filterToggle;
  @override
  Widget build(BuildContext context) => isMobile
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'daily_sales_close.title'.tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Open Shift Button
                      ElevatedButton.icon(
                        onPressed: canOpenShift == true ? onOpenShift : null,
                        icon: const Icon(
                          Icons.lock_open,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'daily_sales_close.btn_open_shift'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.18,
                            Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF2196F3,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                      ),
                      // Day Close Button
                      ElevatedButton.icon(
                        onPressed: onDayClose,
                        icon: const Icon(
                          Icons.access_time,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'daily_sales_close.btn_day_close'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.18,
                            Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.kSuccessColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                filterToggle,
              ],
            ),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'daily_sales_close.title'.tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s20,
                0.30,
                ColorManager.textColor,
              ),
            ),
            Row(
              children: [
                // Open Shift Button
                ElevatedButton.icon(
                  onPressed: canOpenShift == true ? onOpenShift : null,
                  icon: const Icon(
                    Icons.lock_open,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'daily_sales_close.btn_open_shift'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.18,
                      Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Day Close Button
                ElevatedButton.icon(
                  onPressed: onDayClose,
                  icon: const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'daily_sales_close.btn_day_close'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.18,
                      Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.kSuccessColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                filterToggle,
              ],
            ),
          ],
        );
}
