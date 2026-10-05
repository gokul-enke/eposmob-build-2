import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/resources/color_manager.dart';

Future<String?> pickSalesDateTime(BuildContext context,
    {required bool isFromDate}) async {
  final DateTime? pickedDate = await showAutoDismissDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (!context.mounted) return null;
  if (pickedDate != null) {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorManager.kPrimaryColor,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (!context.mounted) return null;
    // Time is optional — use picked time or default
    final TimeOfDay resolvedTime = pickedTime ??
        (isFromDate
            ? const TimeOfDay(hour: 0, minute: 0)
            : const TimeOfDay(hour: 23, minute: 59));

    final DateTime fullDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      resolvedTime.hour,
      resolvedTime.minute,
    );
    final formattedDateTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
    return formattedDateTime;
  }
  return null;
}
