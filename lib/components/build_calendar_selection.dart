import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';

class CalendarPickerTableCell extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime? initialDate;

  const CalendarPickerTableCell(
      {Key? key, required this.onDateSelected, this.initialDate})
      : super(key: key);

  @override
  _CalendarPickerTableCellState createState() =>
      _CalendarPickerTableCellState();
}

class _CalendarPickerTableCellState extends State<CalendarPickerTableCell> {
  DateTime? selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.initialDate ?? selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      widget.onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          border: InputBorder.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              selectedDate != null
                  ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                  : widget.initialDate != null
                      ? DateFormat('yyyy-MM-dd').format(widget.initialDate!)
                      : 'Select Date',
              style: TextStyle(
                fontWeight: FontWeightManager.medium,
                fontSize: FontSize.s12,
                color: ColorManager.textColor.withOpacity(.5),
              ),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}

class TimePickerTableCell extends StatefulWidget {
  final Function(TimeOfDay) onTimeSelected;
  final TimeOfDay? initialTime;

  const TimePickerTableCell({
    Key? key,
    required this.onTimeSelected,
    this.initialTime,
  }) : super(key: key);

  @override
  _TimePickerTableCellState createState() => _TimePickerTableCellState();
}

class _TimePickerTableCellState extends State<TimePickerTableCell> {
  TimeOfDay? selectedTime;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: widget.initialTime ?? selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
      widget.onTimeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectTime(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          border: InputBorder.none,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              selectedTime != null
                  ? selectedTime!.format(context)
                  : widget.initialTime != null
                      ? widget.initialTime!.format(context)
                      : 'Select Time',
              style: TextStyle(
                fontWeight: FontWeightManager.medium,
                fontSize: FontSize.s12,
                color: ColorManager.textColor.withOpacity(.5),
              ),
            ),
            const Icon(Icons.access_time, size: 18),
          ],
        ),
      ),
    );
  }
}
