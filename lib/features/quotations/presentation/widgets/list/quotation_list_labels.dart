import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

String quotationDateLabel(String? date) =>
    date == null || date.isEmpty ? '—' : date.split(' ').first;
String quotationStatusLabel(String status) =>
    switch (status.toLowerCase().replaceAll('_', ' ').trim()) {
      'pending' => 'quotations.status_pending'.tr,
      'confirmed' => 'quotations.status_confirmed'.tr,
      'cancelled' || 'canceled' => 'quotations.status_cancelled'.tr,
      'order created' => 'quotations.status_order_created'.tr,
      'all' => 'quotations.status_all'.tr,
      _ => status,
    };
AppBadgeTone quotationStatusTone(String status) =>
    switch (status.toLowerCase().replaceAll('_', ' ').trim()) {
      'order created' || 'confirmed' => AppBadgeTone.success,
      'cancel' || 'cancelled' || 'canceled' => AppBadgeTone.danger,
      'pending' => AppBadgeTone.warning,
      _ => AppBadgeTone.neutral,
    };
