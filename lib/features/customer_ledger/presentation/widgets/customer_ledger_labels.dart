import 'package:get/get.dart';

String ledgerTypeLabel(String? raw) => switch (raw?.toLowerCase()) {
      'credit' => 'transaction_status_labels.credit'.tr,
      'debit' => 'transaction_status_labels.debit'.tr,
      _ => raw ?? '—'
    };
String ledgerStatusLabel(String? raw) => switch (raw?.toUpperCase()) {
      'SUCC' || 'SUCCESS' => 'transaction_status_labels.succ'.tr,
      'INIT' || 'INITIATED' => 'transaction_status_labels.init'.tr,
      'FAIL' || 'FAILED' => 'transaction_status_labels.fail'.tr,
      _ => raw ?? '—'
    };
