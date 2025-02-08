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
}
