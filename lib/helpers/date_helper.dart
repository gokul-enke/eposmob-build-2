import 'package:intl/intl.dart';

class DateHelper {
  static String formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy MMM dd');
    return formatter.format(date);
  }

  static String formatYearMonthDay(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy MMM dd');
    return formatter.format(date);
  }

  static String formatISODate(String isoDateString) {
    DateTime date = DateTime.parse(isoDateString);
    final DateFormat formatter = DateFormat('yyyy MMM dd');
    return formatter.format(date);
  }

  static String formatISODateToIST(String isoDateString) {
    DateTime utcDate = DateTime.parse(isoDateString);
    DateTime istDate = utcDate
        .add(const Duration(hours: 5, minutes: 30)); // Convert UTC to IST
    final DateFormat formatter =
        DateFormat('hh:mm a'); // 12-hour format with AM/PM
    return formatter.format(istDate);
  }
}
