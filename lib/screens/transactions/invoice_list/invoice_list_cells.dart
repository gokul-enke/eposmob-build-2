import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_invoice.dart';

/// Labels and badges shown in the invoice list's table, cards and export.
abstract final class InvoiceListLabels {
  /// '—' for blank values.
  static String orDash(String value) => value.trim().isEmpty ? '—' : value;

  static String type(String type) => switch (type.toLowerCase()) {
        'order' => 'invoice.type_order'.tr,
        'other' => 'invoice.type_other'.tr,
        _ => type,
      };

  /// Payment status badge (Paid / Pending / Failed, other values as sent).
  static Widget statusBadge(String status) {
    final code = status.toUpperCase();
    return AppBadge(
      label: switch (code) {
        'PAID' => 'invoice.status_paid'.tr,
        'PENDING' => 'invoice.status_pending'.tr,
        'FAIL' || 'FAILED' => 'invoice.status_failed'.tr,
        _ => status,
      },
      tone: switch (code) {
        'PAID' => AppBadgeTone.success,
        'PENDING' => AppBadgeTone.warning,
        'FAIL' || 'FAILED' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      },
    );
  }

  /// ZATCA badge: Sent, Failed, Pending or Not sent.
  static Widget zatcaBadge(Invoice invoice) {
    final status = invoice.zatcaStatus?.toLowerCase();
    final requestStatus = invoice.zatcaRequestStatus?.toLowerCase();
    if (status == 'pass' || status == 'success' || status == 'sent') {
      return AppBadge(
          label: 'invoice.zatca_status_sent'.tr, tone: AppBadgeTone.success);
    }
    if (requestStatus == 'failed') {
      return AppBadge(
          label: 'invoice.zatca_status_failed'.tr, tone: AppBadgeTone.danger);
    }
    if (requestStatus == 'pending' || requestStatus == 'processing') {
      return AppBadge(
          label: 'invoice.zatca_status_pending'.tr, tone: AppBadgeTone.info);
    }
    return AppBadge(
        label: 'invoice.zatca_status_not_sent'.tr, tone: AppBadgeTone.warning);
  }
}
