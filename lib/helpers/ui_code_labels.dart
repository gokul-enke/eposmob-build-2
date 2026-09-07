import 'package:get/get.dart';

/// Maps known API/code values to GetX display labels.
/// Keep branching on the raw code; never send translated text back to the API.
class UiCodeLabels {
  static String status(String? raw) {
    final key = (raw ?? '').toLowerCase().replaceAll('_', ' ').trim();
    switch (key) {
      case '':
      case '-':
        return raw ?? '';
      case 'all':
      case 'all status':
      case 'all statuses':
        return 'ui_codes.status_all'.tr;
      case 'pending':
        return 'ui_codes.status_pending'.tr;
      case 'paid':
      case 'succ':
      case 'success':
        return 'ui_codes.status_paid'.tr;
      case 'cancelled':
      case 'canceled':
        return 'ui_codes.status_cancelled'.tr;
      case 'overdue':
        return 'ui_codes.status_overdue'.tr;
      case 'order created':
        return 'ui_codes.status_order_created'.tr;
      case 'fail':
      case 'failed':
        return 'transaction_status_labels.fail'.tr;
      case 'init':
      case 'initiated':
        return 'transaction_status_labels.init'.tr;
      case 'new':
        return 'sales.status_new'.tr;
      case 'confirmed':
        return 'sales.status_confirmed'.tr;
      case 'start':
      case 'preparing':
        return 'ui_codes.status_preparing'.tr;
      case 'ready':
        return 'ui_codes.status_ready'.tr;
      case 'served':
        return 'ui_codes.status_served'.tr;
      default:
        return raw!.trim();
    }
  }

  static String zatca(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case '':
        return '';
      case 'ALL ZATCA STATUS':
        return 'invoice.all_zatca_status'.tr;
      case 'SENT':
        return 'invoice.zatca_status_sent'.tr;
      case 'NOT SENT':
        return 'invoice.zatca_status_not_sent'.tr;
      case 'FAILED':
        return 'invoice.zatca_status_failed'.tr;
      case 'PENDING':
        return 'invoice.zatca_status_pending'.tr;
      default:
        return status(raw);
    }
  }

  static String payment(String? raw) {
    switch ((raw ?? '').toUpperCase().trim()) {
      case '':
        return '';
      case 'CASH':
        return 'transaction_status_labels.cash'.tr;
      case 'CARD':
        return 'transaction_status_labels.card'.tr;
      case 'BANK_TRANSFER':
      case 'BANK TRANSFER':
        return 'transaction_status_labels.bank_transfer'.tr;
      case 'CHEQUE':
        return 'transaction_status_labels.cheque'.tr;
      case 'UPI':
        return 'transaction_status_labels.upi'.tr;
      case 'COD':
        return 'ui_codes.payment_cod'.tr;
      default:
        return raw!.trim();
    }
  }

  static String voucherType(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case '':
        return '';
      case 'sales_return':
      case 'sales return':
        return 'customer_voucher.type_sales_return'.tr;
      case 'order':
        return 'customer_voucher.type_order'.tr;
      case 'discount':
        return 'customer_voucher.type_discount'.tr;
      case 'other':
        return 'customer_voucher.type_other'.tr;
      default:
        return raw!.trim();
    }
  }

  static String documentKind(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case '':
        return '';
      case 'all':
        return 'ui_codes.status_all'.tr;
      case 'all types':
        return 'company_accounts.all_types'.tr;
      case 'invoice':
        return 'ui_codes.kind_invoice'.tr;
      case 'voucher':
        return 'ui_codes.kind_voucher'.tr;
      case 'receipt':
        return 'ui_codes.kind_receipt'.tr;
      case 'purchase return':
      case 'purchase_return':
        return 'ui_codes.kind_purchase_return'.tr;
      case 'credit':
        return 'transaction_status_labels.credit'.tr;
      case 'debit':
        return 'transaction_status_labels.debit'.tr;
      default:
        return status(raw);
    }
  }

  static String stockStatus(String? raw) {
    final key = (raw ?? '').toLowerCase();
    if (key.contains('out of stock')) {
      return 'stock.status_out_of_stock'.tr;
    }
    if (key.contains('low stock')) {
      return 'stock.status_low_stock'.tr;
    }
    if (key.contains('reorder')) {
      return 'stock.status_at_reorder_level'.tr;
    }
    if (key.contains('available') || key == 'in') {
      return 'stock.status_available'.tr;
    }
    return (raw ?? '').trim();
  }

  static String userRole(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case '':
        return 'company_info.loading'.tr;
      case 'sales_executive':
        return 'company_info.role_sales_executive'.tr;
      case 'company_admin':
        return 'company_info.role_company_admin'.tr;
      case 'store_admin':
        return 'company_info.role_store_admin'.tr;
      case 'attender':
        return 'company_info.role_attender'.tr;
      case 'kitchen_master':
        return 'company_info.role_kitchen_master'.tr;
      default:
        return raw!.trim();
    }
  }
}
