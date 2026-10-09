import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

const List<String> proformaStatusOptions = [
  'All',
  'pending',
  'paid',
  'overdue',
  'order created',
];

String proformaStatusLabel(String value) {
  switch (value) {
    case 'All':
      return 'proforma_invoice.status_all'.tr;
    case 'pending':
      return 'proforma_invoice.status_pending'.tr;
    case 'paid':
      return 'proforma_invoice.status_paid'.tr;
    case 'overdue':
      return 'proforma_invoice.status_overdue'.tr;
    case 'order created':
      return 'proforma_invoice.status_order_created'.tr;
    default:
      return UiCodeLabels.status(value);
  }
}
