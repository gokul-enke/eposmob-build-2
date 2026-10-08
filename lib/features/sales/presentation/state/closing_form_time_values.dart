import 'package:flutter/material.dart';

class ClosingFormTimeValues {
  DateTime? parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String? extractWorkingStartTime(String workingTime) {
    final match = RegExp(
      r'(\d{2}:\d{2})(?::\d{2})?\s*-\s*\d{2}:\d{2}',
    ).firstMatch(workingTime);
    return match?.group(1);
  }

  TimeOfDay? parseTimeOfDay(String timeValue) {
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(timeValue);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool isTimeBefore(TimeOfDay a, String b) {
    final parsedB = parseTimeOfDay(b);
    if (parsedB == null) return false;
    return a.hour < parsedB.hour ||
        (a.hour == parsedB.hour && a.minute < parsedB.minute);
  }
}
