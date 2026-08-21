import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/customer_voucher.dart';
import 'package:pos_machine/services/standard_pdf_direct_print_service.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class CustomerVoucherStandardPrinter {
  final BuildContext context;

  CustomerVoucherStandardPrinter(this.context);

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

  Future<void> generateAndPrintCustomerVoucherPDF({
    required BluetoothPrinter? selectedPrinter,
    required CustomerVoucher voucher,
    required String selectedPaperSize,
    required DocumentConfig? voucherDocumentConfig,
    required String customerCareNumber,
    required String customerCareEmail,
  }) async {
    debugPrint("===== PDF GENERATION - CUSTOMER VOUCHER DEBUG INFO =====");
    debugPrint("Voucher Number: ${voucher.voucherNumber}");
    debugPrint("Customer: ${voucher.customer.user.name}");
    debugPrint("Paper Size: $selectedPaperSize");
    debugPrint("===== END PDF GENERATION DEBUG INFO =====");

    try {
      if (voucherDocumentConfig == null) {
        debugPrint("ERROR: Voucher document configuration not loaded yet.");
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: "Document configurations not loaded. Please wait.",
          );
        }
        return;
      }

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Preparing $selectedPaperSize document for printing...",
        );
      }

      // Generate PDF
      final pdf = await _generatePDF(voucher, voucherDocumentConfig, selectedPaperSize);

      // Save and print
      await _printPDF(
        pdf,
        voucher.voucherNumber,
        selectedPrinter: selectedPrinter,
        selectedPaperSize: selectedPaperSize,
      );
    } catch (e) {
      debugPrint("Error generating PDF: ${e.toString()}");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating PDF: ${e.toString()}",
        );
      }
    }
  }

  Future<pw.Document> _generatePDF(
    CustomerVoucher voucher,
    DocumentConfig? voucherDocumentConfig,
    String selectedPaperSize,
  ) async {
    final pdf = pw.Document();

    // Determine page format
    final pageFormat = selectedPaperSize == 'A5' ? PdfPageFormat.a5 : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          // Define styles matching print_standard.dart
          final headerStyle = pw.TextStyle(
            fontSize: selectedPaperSize == 'A5' ? 16.0 : 18.0,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          );
          final subheaderStyle = pw.TextStyle(
            fontSize: selectedPaperSize == 'A5' ? 9.0 : 11.0,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          );
          final bodyStyle = pw.TextStyle(
            fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
            color: PdfColors.black,
          );
          final tableHeaderStyle = pw.TextStyle(
            fontSize: selectedPaperSize == 'A5' ? 6.0 : 8.0,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          );
          final summaryStyle = pw.TextStyle(
            fontSize: selectedPaperSize == 'A5' ? 8.0 : 10.0,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  voucherDocumentConfig?.header ?? 'Voucher',
                  style: headerStyle,
                ),
              ),
              pw.SizedBox(height: 5),

              // Subheader
              pw.Center(
                child: pw.Text(
                  voucherDocumentConfig?.subheader ?? 'Payment Voucher',
                  style: subheaderStyle,
                ),
              ),
              pw.SizedBox(height: 8),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Voucher Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Voucher #: ${voucher.voucherNumber}',
                        style: summaryStyle,
                      ),
                      pw.Text('Date: ${voucher.voucherDate}', style: bodyStyle),
                      pw.Text('Due Date: ${voucher.dueDate}', style: bodyStyle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Status: ${voucher.status.toUpperCase()}',
                        style: summaryStyle,
                      ),
                      pw.Text('Payment: ${voucher.paymentMethod}', style: bodyStyle),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Customer Information
              pw.Text(
                'Customer Details',
                style: summaryStyle,
              ),
              pw.Text('Name: ${voucher.customer.user.name}', style: bodyStyle),
              pw.Text('Phone: ${voucher.customer.user.phone}', style: bodyStyle),
              if (voucher.customer.user.email != null &&
                  voucher.customer.user.email!.isNotEmpty)
                pw.Text('Email: ${voucher.customer.user.email}', style: bodyStyle),
              pw.SizedBox(height: 10),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 8),

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
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Item',
                          style: tableHeaderStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Qty',
                          style: tableHeaderStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Amount',
                          style: tableHeaderStyle,
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
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item.itemName, style: bodyStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            item.quantity,
                            style: bodyStyle,
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            item.totalAmount,
                            style: bodyStyle,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 8),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'TOTAL: ',
                    style: summaryStyle,
                  ),
                  pw.Text(
                    voucher.amount,
                    style: summaryStyle,
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Divider
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Terms
              if (voucherDocumentConfig?.terms != null &&
                  voucherDocumentConfig!.terms!.isNotEmpty)
                pw.Text(
                  voucherDocumentConfig.terms!,
                  textAlign: pw.TextAlign.center,
                  style: bodyStyle,
                ),

              pw.SizedBox(height: 8),

              // Footer
              if (voucherDocumentConfig?.footer != null &&
                  voucherDocumentConfig!.footer!.isNotEmpty)
                pw.Text(
                  voucherDocumentConfig.footer!,
                  textAlign: pw.TextAlign.center,
                  style: bodyStyle,
                ),
            ],
          );
        },
      ),
    );

    debugPrint("PDF document generated successfully");
    return pdf;
  }

  Future<void> _printPDF(
    pw.Document pdf,
    String voucherNumber, {
    required BluetoothPrinter? selectedPrinter,
    required String selectedPaperSize,
  }) async {
    try {
      debugPrint("Generating PDF for voucher: $voucherNumber");

      // Save PDF to epos directory for better organization
      final output = await _getEposDirectory();

      // Sanitize filename for Windows compatibility
      String sanitizedVoucherNumber =
          voucherNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file =
          File('${output.path}/CustomerVoucher_$sanitizedVoucherNumber.pdf');

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      debugPrint("PDF saved to: ${file.path}");
      debugPrint("PDF file size: ${bytes.length} bytes");

      if (selectedPrinter != null) {
        final printed = await StandardPdfDirectPrintService.printBytes(
          pdfBytes: bytes,
          selectedPrinter: selectedPrinter,
          paperSize: selectedPaperSize,
          jobName: 'Customer Voucher $sanitizedVoucherNumber',
        );
        if (printed) {
          if (context.mounted) {
            showScaffold(
              context: context,
              message: 'Voucher sent to ${selectedPrinter.deviceName}',
            );
          }
          return;
        }
      }

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
      await OpenFile.open(file.path);

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
              'Customer Voucher #${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('CustomerVoucher_', '')}',
          text: 'Your customer voucher',
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
