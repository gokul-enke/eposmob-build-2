import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

String quotationDateLabel(String? date) =>
    date == null || date.isEmpty ? '—' : date.split(' ').first;
/// Shared by label and tone so both recognise the same API spellings.
String _normalizedStatus(String status) =>
    switch (status.toLowerCase().replaceAll('_', ' ').trim()) {
      'cancel' || 'canceled' => 'cancelled',
      final normalized => normalized,
    };
String quotationStatusLabel(String status) =>
    switch (_normalizedStatus(status)) {
      'pending' => 'quotations.status_pending'.tr,
      'confirmed' => 'quotations.status_confirmed'.tr,
      'cancelled' => 'quotations.status_cancelled'.tr,
      'order created' => 'quotations.status_order_created'.tr,
      'all' => 'quotations.status_all'.tr,
      _ => status,
    };
AppBadgeTone quotationStatusTone(String status) =>
    switch (_normalizedStatus(status)) {
      'order created' || 'confirmed' => AppBadgeTone.success,
      'cancelled' => AppBadgeTone.danger,
      'pending' => AppBadgeTone.warning,
      _ => AppBadgeTone.neutral,
    };
