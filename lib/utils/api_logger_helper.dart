import 'dart:io';
import 'package:url_launcher/url_launcher_string.dart';
import 'api_response_logger.dart';

class ApiLoggerHelper {
  /// Open the API response log file in default browser
  static Future<void> openApiLogs() async {
    try {
      final filePath = await ApiResponseLogger().getLogFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('❌ API log file not found at: $filePath');
        return;
      }
      
      final fileUri = Uri.file(filePath);
      if (await canLaunchUrlString(fileUri.toString())) {
        await launchUrlString(fileUri.toString());
        print('✅ Opened API logs in browser');
      } else {
        print('❌ Could not open file: $fileUri');
      }
    } catch (e) {
      print('❌ Error opening API logs: $e');
    }
  }

  /// Get the log file path
  static Future<String> getLogFilePath() async {
    return await ApiResponseLogger().getLogFilePath();
  }

  /// Print log file path to console
  static Future<void> printLogFilePath() async {
    final path = await getLogFilePath();
    print('📁 API Log File Path: $path');
  }

  /// Clear all API logs
  static Future<void> clearApiLogs() async {
    await ApiResponseLogger().clearLogs();
    print('✅ API logs cleared');
  }

  /// Get log file size
  static Future<String> getLogFileSize() async {
    try {
      final filePath = await getLogFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return 'File not found';
      }
      
      final bytes = await file.length();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Print log file info
  static Future<void> printLogFileInfo() async {
    final path = await getLogFilePath();
    final size = await getLogFileSize();
    print('📊 API Log File Info:');
    print('   Path: $path');
    print('   Size: $size');
  }
}
