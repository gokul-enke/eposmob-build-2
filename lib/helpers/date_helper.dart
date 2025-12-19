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
    final DateFormat formatter = DateFormat('dd-MM-yyyy');
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

  static String formatISOTimeOnlyToIST(String isoDateString) {
    // Parse the incoming ISO date string
    DateTime utcDate = DateTime.parse(isoDateString);

    // Convert UTC to IST by adding 5 hours 30 minutes
    DateTime istDate = utcDate.add(const Duration(hours: 5, minutes: 30));

    // Format time only
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(istDate);
  }

  // To Print Local to Local Date and Time
  static String formatToISODateFromIST(String isoDateString) {
    final DateTime local = DateTime.parse(isoDateString).toLocal();
    final DateFormat formatter = DateFormat('dd-MM-yyyy hh:mm a');
    return formatter.format(local);
  }

  // To Print Local to Local Date Only
  static String formatToISODateOnlyFromISO(String isoDateString) {
    final DateTime local = DateTime.parse(isoDateString).toLocal();
    final DateFormat formatter = DateFormat('dd-MM-yyyy');
    return formatter.format(local);
  }

  // To Print Local to Local Time Only
  static String formatToISOTimeOnlyFromISO(String isoDateString) {
    final DateTime local = DateTime.parse(isoDateString).toLocal();
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(local);
  }

  // Format duration as "time ago" (e.g., "5m ago", "2h ago", "3d ago")
  static String formatTimeAgo(Duration duration) {
    final minutes = duration.inMinutes;
    final hours = duration.inHours;
    final days = duration.inDays;

    if (days > 0) {
      return '${days}d ago';
    } else if (hours > 0) {
      return '${hours}h ago';
    } else {
      return '${minutes}m ago';
    }
  }
}
