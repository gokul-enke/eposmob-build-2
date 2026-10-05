import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class DailyCloseListFilters extends StatelessWidget {
  const DailyCloseListFilters(
      {super.key,
      required this.calendarPickerKey,
      required this.dateLabel,
      required this.onDateSelected,
      required this.onReset,
      this.executiveField});
  final Key calendarPickerKey;
  final String dateLabel;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onReset;
  final Widget? executiveField;
  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('day-close-filters'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row of filters
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Filter
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        dateLabel,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s14,
                          0.27,
                          Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      height: 45,
                      child: Center(
                        child: CalendarPickerTableCell(
                          key: calendarPickerKey,
                          hintText: 'daily_sales_close.select_date'.tr,
                          onDateSelected: onDateSelected,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),

              if (executiveField != null) ...[
                Expanded(flex: 1, child: executiveField!),
                const SizedBox(width: 15)
              ],
              // Reset button
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 35.0),
                  child: CustomRoundButton(
                    title: 'general.reset'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    fct: onReset,
                    height: 45,
                    width: double.infinity,
                    fontSize: FontSize.s12,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
