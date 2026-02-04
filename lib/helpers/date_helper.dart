import 'package:intl/intl.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class DateHelper {
  static String? _timeZone;
  // Default fallback (IST) if timezone is invalid or not set
  static const Duration _defaultOffset = Duration(hours: 5, minutes: 30);
  static int _serverTimeOffset = 0; // Offset in milliseconds (Server Time - Local Time)

  static Future<void> init() async {
    final timeZone = await SharedPreferenceProvider().getTimeZone();
    if (timeZone != null) {
      setTimeZone(timeZone);
    }
    
    final offset = await SharedPreferenceProvider().getServerTimeOffset();
    if (offset != null) {
      _serverTimeOffset = offset;
    }
  }

  static void setServerTime(DateTime serverTime) {
    // Calculate difference: Server Time - Local Time
    // If server is ahead, offset is positive. If behind, negative.
    final now = DateTime.now();
    _serverTimeOffset = serverTime.difference(now).inMilliseconds;
    SharedPreferenceProvider().saveServerTimeOffset(_serverTimeOffset);
    debugPrint("DateHelper: Server time synced. Offset: $_serverTimeOffset ms");
  }

  /// Returns the current time synchronized with the server
  static DateTime now() {
    return DateTime.now().add(Duration(milliseconds: _serverTimeOffset));
  }

  static void setTimeZone(String timeZone) {
    _timeZone = timeZone;
  }

  static DateTime _convertToLocal(DateTime inputDate) {
    // Assume inputDate is in UTC (as per previous logic)
    // Ensure we have a UTC DateTime object
    final utcDate = inputDate.isUtc 
        ? inputDate 
        : DateTime.utc(
            inputDate.year, 
            inputDate.month, 
            inputDate.day, 
            inputDate.hour, 
            inputDate.minute, 
            inputDate.second,
            inputDate.millisecond,
            inputDate.microsecond
          );

    if (_timeZone != null) {
      try {
        final location = tz.getLocation(_timeZone!);
        return tz.TZDateTime.from(utcDate, location);
      } catch (e) {
        debugPrint("DateHelper: Invalid or missing timezone '$_timeZone', falling back to default offset. Error: $e");
      }
    }
    
    // Fallback to manual offset (IST)
    return utcDate.add(_defaultOffset);
  }

  static String formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy MMM dd');
    return formatter.format(date);
  }

  static String formatYearMonthDay(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy MMM dd');
    return formatter.format(date);
  }

  static String formatISODate(String isoDateString) {
    try {
      DateTime utcDate = DateTime.parse(isoDateString);
      DateTime localDate = _convertToLocal(utcDate);
      final DateFormat formatter = DateFormat('dd-MM-yyyy');
      return formatter.format(localDate);
    } catch (e) {
      // Fallback for already formatted dates (e.g. "21-01-2026 11:51:44 AM")
      if (isoDateString.contains(' ')) {
        return isoDateString.split(' ')[0];
      }
      return isoDateString;
    }
  }

  static String formatISODateToIST(String isoDateString) {
    try {
      // Parse the incoming ISO date string
      DateTime utcDate = DateTime.parse(isoDateString);

      // Convert UTC to Local
      DateTime localDate = _convertToLocal(utcDate);

      // Format both date and time together
      final DateFormat formatter = DateFormat('dd-MM-yyyy hh:mm a');
      return formatter.format(localDate);
    } catch (e) {
      // Fallback for already formatted dates
      return isoDateString;
    }
  }

  static String formatISOTimeOnlyToIST(String isoDateString) {
    try {
      // Parse the incoming ISO date string
      DateTime utcDate = DateTime.parse(isoDateString);

      // Convert UTC to Local
      DateTime localDate = _convertToLocal(utcDate);

      // Format time only
      final DateFormat formatter = DateFormat('hh:mm a');
      return formatter.format(localDate);
    } catch (e) {
      // Fallback for already formatted dates (e.g. "21-01-2026 11:51:44 AM")
      if (isoDateString.contains(' ')) {
        // Try to extract time part (assuming "Date Time AM/PM")
        // Example: "21-01-2026 11:51:44 AM" -> parts: [21-01-2026, 11:51:44, AM]
        // We want "11:51 AM"
        if (isoDateString.contains(' AM') || isoDateString.contains(' PM')) {
           // Extract time part logic
           // Simple approach: return everything after the first space?
           // Or just return the string if we can't parse it?
           // ClassicReceiptLayout expects JUST time here.
           
           // Let's try to parse the formatted string to extract time
           try {
             final DateFormat inputFormat = DateFormat('dd-MM-yyyy hh:mm:ss a');
             final DateTime parsed = inputFormat.parse(isoDateString);
             final DateFormat outputFormat = DateFormat('hh:mm a');
             return outputFormat.format(parsed);
           } catch (_) {
             // If strict parse fails, try splitting
             final parts = isoDateString.split(' ');
             if (parts.length >= 3) {
               // 11:51:44 AM -> 11:51 AM
               String timePart = parts[1];
               String amPm = parts[2];
               if (timePart.contains(':')) {
                 final timeParts = timePart.split(':');
                 return "${timeParts[0]}:${timeParts[1]} $amPm";
               }
             }
           }
        }
      }
      return isoDateString;
    }
  }

  static String getCurrentFormattedTime() {
    final now = DateHelper.now();
    final localNow = _convertToLocal(now.toUtc());
    final DateFormat formatter = DateFormat('HH:mm');
    return formatter.format(localNow);
  }

  static String getCurrentFormattedTimeWithAMPM() {
    final now = DateHelper.now();
    final localNow = _convertToLocal(now.toUtc());
    final DateFormat formatter = DateFormat('hh:mm a');
    return formatter.format(localNow);
  }

  static String getCurrentFormattedTimeWithSecondsAMPM() {
    final now = DateHelper.now();
    final localNow = _convertToLocal(now.toUtc());
    final DateFormat formatter = DateFormat('hh:mm:ss a');
    return formatter.format(localNow);
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

  // Format without timezone conversion (for dates already in target timezone)
  static String formatInputToDisplay(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      final DateFormat formatter = DateFormat('dd-MM-yyyy hh:mm:ss a');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Format time only (no timezone conversion)
  static String formatTimeOnly(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      final DateFormat formatter = DateFormat('hh:mm a');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
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
