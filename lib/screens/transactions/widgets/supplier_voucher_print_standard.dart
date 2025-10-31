import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class SupplierVoucherStandardPrinter {
  final BuildContext context;

  SupplierVoucherStandardPrinter(this.context);

  // Helper method to get or create the epos directory
  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
        debugPrint('Created epos directory: ${eposDir.path}');
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  Future<void> generateAndPrintSupplierVoucherPDF({
    required BluetoothPrinter? selectedPrinter,
    required SupplierVoucher voucher,
    required String selectedPaperSize,
    required DocumentConfig? voucherDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
  }) async {
    debugPrint("===== STANDARD PRINTER - SUPPLIER VOUCHER PDF DEBUG INFO =====");
    debugPrint("Voucher Number: ${voucher.voucherNumber}");
    debugPrint("Supplier: ${voucher.supplier.name}");
    debugPrint("Paper Size: $selectedPaperSize");
    debugPrint("===== END STANDARD PRINTER DEBUG INFO =====");

    try {
      debugPrint("PDF generation for supplier voucher started");
      debugPrint("Document Config Header: ${voucherDocumentConfig?.header}");
      debugPrint("Document Config Subheader: ${voucherDocumentConfig?.subheader}");
      debugPrint("Document Config Terms: ${voucherDocumentConfig?.terms}");
      debugPrint("Document Config Footer: ${voucherDocumentConfig?.footer}");

      // Generate PDF
      final pdf = await _generatePDF(voucher, voucherDocumentConfig, selectedPaperSize);

      // Save and print
      await _printPDF(pdf, voucher.voucherNumber);

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Supplier Voucher PDF printed successfully',
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error generating PDF: $e',
        );
      }
    }
  }

  Future<pw.Document> _generatePDF(
    SupplierVoucher voucher,
    DocumentConfig? voucherDocumentConfig,
    String selectedPaperSize,
  ) async {
    final pdf = pw.Document();

    // Determine page format
    final pageFormat = selectedPaperSize == 'A5' ? PdfPageFormat.a5 : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  voucherDocumentConfig?.header ?? 'Supplier Voucher',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),

              // Subheader
              pw.Center(
                child: pw.Text(
                  voucherDocumentConfig?.subheader ?? 'Payment Voucher',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Voucher Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Voucher #: ${voucher.voucherNumber}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Date: ${voucher.voucherDate}'),
                      pw.Text('Due Date: ${voucher.dueDate}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Status: ${voucher.status.toUpperCase()}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Payment: ${voucher.paymentMethod}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Supplier Information
              pw.Text(
                'Supplier Details',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Name: ${voucher.supplier.name}'),
              pw.Text('Phone: ${voucher.supplier.phone}'),
              pw.SizedBox(height: 15),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE0E0E0),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Item rows
                  ...voucher.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.itemName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            item.quantity,
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            item.totalAmount,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    voucher.amount,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Terms
              if (voucherDocumentConfig?.terms != null &&
                  voucherDocumentConfig!.terms!.isNotEmpty)
                pw.Text(
                  voucherDocumentConfig.terms!,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),

              pw.SizedBox(height: 10),

              // Footer
              if (voucherDocumentConfig?.footer != null &&
                  voucherDocumentConfig!.footer!.isNotEmpty)
                pw.Text(
                  voucherDocumentConfig.footer!,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          );
        },
      ),
    );

    debugPrint("PDF document generated successfully");
    return pdf;
  }

  Future<void> _printPDF(pw.Document pdf, String voucherNumber) async {
    try {
      debugPrint("Generating PDF for voucher: $voucherNumber");

      // Save PDF to epos directory for better organization
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedVoucherNumber =
          voucherNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file =
          File('${output.path}/SupplierVoucher_$sanitizedVoucherNumber.pdf');
      
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      debugPrint("PDF saved to: ${file.path}");
      debugPrint("PDF file size: ${bytes.length} bytes");

      // Determine if running on Windows
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        // Try to open the PDF directly for non-Windows platforms
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            if (!isWindows) {
              await _sharePdfFallback(file);
            } else {
              if (context.mounted) {
                showScaffold(
                    context: context, message: "PDF created successfully");
              }
            }
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF opened for printing");
            }
          }
        } catch (e) {
          debugPrint("Error opening PDF: ${e.toString()}");
          if (!isWindows) {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(
                  context: context, message: "PDF created successfully");
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _printPDF: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error generating PDF: $e',
        );
      }
    }
  }

  // Windows-specific handling for PDF
  Future<void> _handleWindowsPdf(File file) async {
    try {
      // First try to open with the default Windows PDF viewer
      final result = await OpenFile.open(file.path);

      // Always show success message on Windows, regardless of result
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
      }
    } catch (e) {
      debugPrint("Windows PDF handling error: $e");
      // Still show success message on error
      if (context.mounted) {
        showScaffold(context: context, message: "PDF created successfully");
      }
    }
  }

  // Fallback method to share PDF if direct opening fails (for mobile platforms)
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject:
              'Supplier Voucher #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('SupplierVoucher_', '')}',
          text: 'Your supplier voucher',
        );

        if (context.mounted) {
          showScaffold(
              context: context, message: "PDF shared. Please open it to print");
        }
      }
    } catch (e) {
      debugPrint("Error sharing PDF fallback: ${e.toString()}");
      if (context.mounted) {
        if (Platform.isWindows) {
          showScaffold(
              context: context, message: "PDF created successfully");
        } else {
          showScaffoldError(
            context: context,
            message:
                "Unable to open or share PDF: ${e.toString()}. Please check app permissions.",
          );
        }
      }
    }
  }
}
