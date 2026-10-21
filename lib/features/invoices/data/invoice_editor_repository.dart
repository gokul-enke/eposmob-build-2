import 'package:pos_machine/providers/invoice_provider.dart';

/// Preserves the existing create endpoint, subscription checks and payload.
class InvoiceEditorRepository {
  const InvoiceEditorRepository(this.provider);
  final InvoiceProvider provider;

  Future<dynamic> createInvoice({
    required int customerId,
    required String type,
    required String dueDate,
    required String invoiceDate,
    required double amount,
    required String status,
    required int paymentMethod,
    required List<Map<String, dynamic>> invoiceItems,
    required String accessToken,
    // Discount fields
    String? couponId,
    double? flatDiscount,
    double? percentageDiscount,
    double? discountAmount,
  }) =>
      provider.createInvoice(
        customerId: customerId,
        type: type,
        dueDate: dueDate,
        invoiceDate: invoiceDate,
        amount: amount,
        status: status,
        paymentMethod: paymentMethod,
        invoiceItems: invoiceItems,
        accessToken: accessToken,
        couponId: couponId,
        flatDiscount: flatDiscount,
        percentageDiscount: percentageDiscount,
        discountAmount: discountAmount,
      );
}
