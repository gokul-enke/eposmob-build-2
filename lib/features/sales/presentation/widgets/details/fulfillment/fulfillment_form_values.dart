import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';

void putFulfillmentString(
    Map<String, dynamic> payload, String key, String? value) {
  final text = value?.trim();
  if (text != null && text.isNotEmpty) payload[key] = text;
}

void putFulfillmentNumber(
    Map<String, dynamic> payload, String key, String value) {
  final parsed = num.tryParse(value.trim());
  if (parsed != null) payload[key] = parsed;
}

void putFulfillmentInt(Map<String, dynamic> payload, String key, String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed != null) payload[key] = parsed;
}

String fulfillmentDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String fulfillmentDateTimeDisplay(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  return DateHelper.formatISODateTimeForInput(value);
}

String fulfillmentDateTimeInput(DateTime date) =>
    '${fulfillmentDateOnly(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

DateTime? parseFulfillmentPackedAt(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String fulfillmentFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

void showFulfillmentMessage(BuildContext context, String message,
    {bool isError = false}) {
  if (isError) {
    showScaffoldError(context: context, message: message);
  } else {
    showScaffold(context: context, message: message);
  }
}
