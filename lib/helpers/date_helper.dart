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
    DateTime utcDate = DateTime.parse(isoDateString);
    DateTime istDate = utcDate.add(const Duration(hours: 5, minutes: 30));
    final DateFormat formatter = DateFormat('dd-MM-yyyy hh:mm a ');
    return formatter.format(istDate);
  }

  static String formatISODateToIST(String isoDateString) {
    // Parse the incoming ISO date string
    DateTime utcDate = DateTime.parse(isoDateString);

    // Convert UTC to IST by adding 5 hours 30 minutes
    DateTime istDate = utcDate.add(const Duration(hours: 5, minutes: 30));

    // Format both date and time together
    final DateFormat formatter = DateFormat('dd-MM-yyyy hh:mm a');
    return formatter.format(istDate);
  }
}
