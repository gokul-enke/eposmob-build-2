import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'standard_pdf_layout.dart';

/// Classic standard PDF layout - the default A4/A5 PDF design.
///
/// This layout delegates to the existing [StandardPrinter] for PDF generation,
/// ensuring zero visual regressions. Future themes can implement their own
/// PDF building logic independently.
class ClassicStandardPdfLayout implements StandardPdfLayout {
  @override
  String get layoutId => 'classic';

  @override
  String get displayName => 'Classic';

  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    debugPrint('[ClassicStandardPdfLayout] Generating PDF via StandardPrinter');

    final standardPrinter = StandardPrinter(params.context);

    await standardPrinter.generateAndPrintPDF(
      selectedPrinter: params.selectedPrinter,
      cartItems: params.cartItems,
      formattedTotal: params.formattedTotal,
      savedTotal: params.savedTotal,
      discountAmount: params.discountAmount,
      orderDate: params.orderDate,
      orderNumber: params.orderNumber,
      tokenNumber: params.tokenNumber,
      isFromLocalStorage: params.isFromLocalStorage,
      selectedPaperSize: params.selectedPaperSize,
      billDocumentConfig: params.billDocumentConfig,
      customerCareNumber: params.customerCareNumber,
      customerCareEmail: params.customerCareEmail,
      customerName: params.customerName,
      customerPhone: params.customerPhone,
      customerEmail: params.customerEmail,
      customerAddress: params.customerAddress,
      orderReturns: params.orderReturns,
      customerOldBalance: params.customerOldBalance,
      customerCurrentBalance: params.customerCurrentBalance,
      paidAmount: params.paidAmount,
      orderComment: params.orderComment,
      deliveryMethod: params.deliveryMethod,
      customerAlternatePhone: params.customerAlternatePhone,
      paymentMethod: params.paymentMethod,
      zatcaVatNumber: params.zatcaVatNumber,
      zatcaCompanyName: params.zatcaCompanyName,
      isDefaultCustomer: params.isDefaultCustomer,
      hideDefaultCustomerPhone: params.hideDefaultCustomerPhone,
      customerVatNumber: params.customerVatNumber,
      customerCrNumber: params.customerCrNumber,
      storeLocation: params.storeLocation,
      storePhone: params.storePhone,
      storeEmail: params.storeEmail,
    );
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) async {
    debugPrint(
        '[ClassicStandardPdfLayout] buildPdfDocument - delegating to StandardPrinter');
    // For now, return an empty document.
    // The full PDF building logic lives in StandardPrinter.generateAndPrintPDF
    // which handles both building AND saving/opening. When we need standalone
    // PDF building (e.g. for sharing), this can be migrated.
    return pw.Document();
  }
}
