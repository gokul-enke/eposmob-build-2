import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

/// Kitchen Order Ticket (KOT) Standard Printer
/// Generates A4/A5 PDF for KOT printing using Document Configuration
class KotStandardPrinter {
  final BuildContext context;

  KotStandardPrinter(this.context);

  // Cache for fonts
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  // Load font (with caching)
  Future<pw.Font> _loadRegularFont() async {
    if (_regularFont != null) return _regularFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _regularFont = pw.Font.ttf(fontData);
      return _regularFont!;
    } catch (e) {
      debugPrint('Error loading font: $e');
      rethrow;
    }
  }

  Future<pw.Font> _loadBoldFont() async {
    if (_boldFont != null) return _boldFont!;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _boldFont = pw.Font.ttf(fontData);
      return _boldFont!;
    } catch (e) {
      debugPrint('Error loading bold font: $e');
      rethrow;
    }
  }

  // Get the epos directory for saving PDFs
  Future<Directory> _getEposDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final eposDir = Directory('${documentsDir.path}/epos');
      if (!await eposDir.exists()) {
        await eposDir.create(recursive: true);
      }
      return eposDir;
    } catch (e) {
      debugPrint('Could not access Documents/epos directory, using temp: $e');
      return await getTemporaryDirectory();
    }
  }

  String _resolveKotHeader(String fallbackHeader, String kotType) {
    switch (kotType.trim().toLowerCase()) {
      case 'cancel':
        return 'CANCEL KOT';
      case 'add_on':
        return 'ADD-ON KOT';
      default:
        return fallbackHeader;
    }
  }

  /// Generate and print/open KOT PDF using document configuration
  Future<void> generateAndPrintKotPDF({
    required String orderNumber,
    String? tokenNumber,
    required String tableName,
    bool showTableLabel = true,
    required String orderTime,
    required List<Map<String, dynamic>> items,
    String? comment,
    String kotType = 'standard',
    required String selectedPaperSize,
    DocumentConfig? kotDocumentConfig,
  }) async {
    try {
      debugPrint("===== KOT STANDARD PDF GENERATION =====");
      debugPrint("Paper size: $selectedPaperSize");
      debugPrint("Order: $orderNumber, Table: $tableName");
      debugPrint(
          "Document Config: ${kotDocumentConfig != null ? 'Loaded' : 'Not loaded'}");

      if (context.mounted) {
        showScaffold(
          context: context,
          message: "Generating KOT PDF...",
        );
      }

      // Get display configuration and labels
      final displayConfig = kotDocumentConfig?.displayConfiguration?.options;
      final resolvedLabels = kotDocumentConfig?.resolvedLabels;

      // Load fonts
      final regularFont = await _loadRegularFont();
      final boldFont = await _loadBoldFont();

      // Create PDF document
      final pdf = pw.Document();

      // Page format
      final pageFormat =
          selectedPaperSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.a5;
      final isA5 = selectedPaperSize == 'A5';

      // Styles
      final headerStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 16.0 : 20.0,
        fontWeight: pw.FontWeight.bold,
      );
      final subheaderStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 10.0 : 12.0,
        fontWeight: pw.FontWeight.bold,
      );
      final bodyStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 9.0 : 10.0,
      );
      final itemStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 9.0 : 10.0,
      );
      final tableHeaderStyle = pw.TextStyle(
        font: boldFont,
        fontSize: isA5 ? 9.0 : 10.0,
        fontWeight: pw.FontWeight.bold,
      );
      final commentStyle = pw.TextStyle(
        font: regularFont,
        fontSize: isA5 ? 9.0 : 10.0,
        fontStyle: pw.FontStyle.italic,
      );

      // Get visibility flags from config
      final showStoreName = displayConfig?['showStoreName']?.visible ?? true;
      final showOrderNumber =
          displayConfig?['showOrderNumber']?.visible ?? true;
      final showTableNumber =
          displayConfig?['showTableNumber']?.visible ?? true;
      final showDateTime = displayConfig?['showDateTime']?.visible ?? true;
      final showSLNumber = displayConfig?['showSLNumber']?.visible ?? true;
      final showParticulars =
          displayConfig?['showParticulars']?.visible ?? true;
      final showQty = displayConfig?['showQty']?.visible ?? true;
      final showTotal = displayConfig?['showTotal']?.visible ?? true;
      final showComment = displayConfig?['showComment']?.visible ?? true;
      final showMRP = displayConfig?['showMRP']?.visible ?? false;
      final showRate = displayConfig?['showRate']?.visible ?? false;

      // Get labels with priority: displayConfig value > resolvedLabels > default
      final headerText =
          (displayConfig?['showStoreName']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showStoreName']!.value as String
              : (kotDocumentConfig?.header?.isNotEmpty == true
                  ? kotDocumentConfig!.header!
                  : 'KITCHEN ORDER');
        final resolvedHeaderText = _resolveKotHeader(headerText, kotType);

      final orderLabel =
          (displayConfig?['showOrderNumber']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showOrderNumber']!.value as String
              : (resolvedLabels?.orderNumber?.isNotEmpty == true
                  ? resolvedLabels!.orderNumber!
                  : 'Order');

      final tableLabel =
          (displayConfig?['showTableNumber']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showTableNumber']!.value as String
              : 'Table';

      final timeLabel =
          (displayConfig?['showDateTime']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showDateTime']!.value as String
              : 'Time';
      final tokenLabel = 'Token';
      final hasToken = tokenNumber != null && tokenNumber.trim().isNotEmpty;

      final slLabel =
          (displayConfig?['showSLNumber']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showSLNumber']!.value as String
              : (resolvedLabels?.slNumber?.isNotEmpty == true
                  ? resolvedLabels!.slNumber!
                  : 'Si#');

      final particularsLabel =
          (displayConfig?['showParticulars']?.value as String?)?.isNotEmpty ==
                  true
              ? displayConfig!['showParticulars']!.value as String
              : (resolvedLabels?.particulars?.isNotEmpty == true
                  ? resolvedLabels!.particulars!
                  : 'PARTICULARS');

      final qtyLabel =
          (displayConfig?['showQty']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showQty']!.value as String
              : (resolvedLabels?.qty?.isNotEmpty == true
                  ? resolvedLabels!.qty!
                  : 'QTY');

      final mrpLabel =
          (displayConfig?['showMRP']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showMRP']!.value as String
              : (resolvedLabels?.mrp?.isNotEmpty == true
                  ? resolvedLabels!.mrp!
                  : 'MRP');

      final rateLabel =
          (displayConfig?['showRate']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showRate']!.value as String
              : (resolvedLabels?.rate?.isNotEmpty == true
                  ? resolvedLabels!.rate!
                  : 'RATE');

      final totalLabel =
          (displayConfig?['showTotal']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showTotal']!.value as String
              : (resolvedLabels?.total?.isNotEmpty == true
                  ? resolvedLabels!.total!
                  : 'Total');

      final commentLabel =
          (displayConfig?['showComment']?.value as String?)?.isNotEmpty == true
              ? displayConfig!['showComment']!.value as String
              : 'Note';

      // Build table columns dynamically based on visibility
      List<pw.FlexColumnWidth> columnWidths = [];
      List<String> headerLabels = [];

      if (showSLNumber) {
        columnWidths.add(const pw.FlexColumnWidth(0.5));
        headerLabels.add(slLabel);
      }
      if (showParticulars) {
        columnWidths.add(const pw.FlexColumnWidth(4));
        headerLabels.add(particularsLabel);
      }
      if (showQty) {
        columnWidths.add(const pw.FlexColumnWidth(1));
        headerLabels.add(qtyLabel);
      }
      if (showMRP) {
        columnWidths.add(const pw.FlexColumnWidth(1));
        headerLabels.add(mrpLabel);
      }
      if (showRate) {
        columnWidths.add(const pw.FlexColumnWidth(1));
        headerLabels.add(rateLabel);
      }

      // Add page
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(isA5 ? 15 : 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - dynamic from config
                if (showStoreName)
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 2),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(resolvedHeaderText, style: headerStyle),
                    ),
                  ),
                pw.SizedBox(height: isA5 ? 10 : 15),

                // Order details box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (showOrderNumber && hasToken)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('$orderLabel: $orderNumber',
                                style: subheaderStyle),
                            pw.Text('$tokenLabel: ${tokenNumber!.trim()}',
                                style: subheaderStyle),
                          ],
                        )
                      else
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            if (showOrderNumber)
                              pw.Text('$orderLabel: $orderNumber',
                                  style: subheaderStyle),
                          ],
                        ),
                      if (showDateTime) ...[
                        pw.SizedBox(height: 2),
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text('$timeLabel: $orderTime',
                              style: bodyStyle),
                        ),
                      ],
                      if (showTableNumber && tableName.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                            showTableLabel
                                ? '$tableLabel: $tableName'
                                : tableName,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: isA5 ? 14.0 : 18.0,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: isA5 ? 10 : 15),

                // Items section header
                pw.Text('ORDER ITEMS', style: subheaderStyle),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 1),

                // Items table with dynamic columns
                pw.Table(
                  border: null,
                  columnWidths: Map.fromIterables(
                    List.generate(columnWidths.length, (i) => i),
                    columnWidths,
                  ),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(width: 1),
                        ),
                      ),
                      children: headerLabels
                          .map(
                            (label) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets.symmetric(vertical: 4),
                              child: pw.Text(label,
                                  style: tableHeaderStyle,
                                  textAlign:
                                      (label == qtyLabel || label == slLabel)
                                          ? pw.TextAlign.center
                                          : (label == mrpLabel ||
                                                  label == rateLabel)
                                              ? pw.TextAlign.right
                                              : pw.TextAlign.left),
                            ),
                          )
                          .toList(),
                    ),
                    // Item rows
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final qty = item['quantity']?.toString() ?? '1';
                      final name = item['productName']?.toString() ?? 'Unknown';
                      final mrp = item['mrp']?.toString() ?? '';
                      final rate = item['unitPrice']?.toString() ??
                          item['rate']?.toString() ??
                          '';

                      List<pw.Widget> rowCells = [];

                      if (showSLNumber) {
                        rowCells.add(pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text('${index + 1}',
                              style: itemStyle, textAlign: pw.TextAlign.center),
                        ));
                      }
                      if (showParticulars) {
                        final itemNotes = item['notes']?.toString() ??
                            item['comment']?.toString();
                        rowCells.add(pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(name, style: itemStyle, textDirection: pw.TextDirection.ltr),
                              if (itemNotes != null && itemNotes.isNotEmpty)
                                pw.Text('  Note: $itemNotes',
                                    style: commentStyle),
                            ],
                          ),
                        ));
                      }
                      if (showQty) {
                        rowCells.add(pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(qty,
                              style: itemStyle, textAlign: pw.TextAlign.center),
                        ));
                      }
                      if (showMRP) {
                        rowCells.add(pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(mrp,
                              style: itemStyle, textAlign: pw.TextAlign.right),
                        ));
                      }
                      if (showRate) {
                        rowCells.add(pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(rate,
                              style: itemStyle, textAlign: pw.TextAlign.right),
                        ));
                      }

                      return pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                                width: 0.5, color: PdfColors.grey400),
                          ),
                        ),
                        children: rowCells,
                      );
                    }),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 5),

                // Total items count
                if (showTotal)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('$totalLabel Items: ${items.length}',
                          style: bodyStyle),
                    ],
                  ),

                // Comment section (if present and visible)
                if (showComment && comment != null && comment.isNotEmpty) ...[
                  pw.SizedBox(height: isA5 ? 10 : 15),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$commentLabel:', style: tableHeaderStyle),
                        pw.SizedBox(height: 2),
                        pw.Text(comment, style: commentStyle),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );

      // Save PDF
      final output = await _getEposDirectory();
      String sanitizedOrderNumber =
          orderNumber.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${output.path}/KOT_$sanitizedOrderNumber.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint("KOT PDF saved to: ${file.path}");

      // Open the PDF
      final bool isWindows = Platform.isWindows;

      if (isWindows) {
        await _handleWindowsPdf(file);
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != 'done') {
            await _sharePdfFallback(file);
          } else {
            if (context.mounted) {
              showScaffold(context: context, message: "KOT PDF opened");
            }
          }
        } catch (e) {
          await _sharePdfFallback(file);
        }
      }

      debugPrint("KOT PDF generation complete!");
    } catch (e, stackTrace) {
      debugPrint("ERROR generating KOT PDF: $e");
      debugPrint("Stack trace: $stackTrace");
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: "Error generating KOT PDF: $e",
        );
      }
    }
  }

  // Handle Windows PDF opening
  Future<void> _handleWindowsPdf(File file) async {
    try {
      final result = await Process.run('cmd', ['/c', 'start', '', file.path]);
      if (result.exitCode == 0) {
        if (context.mounted) {
          showScaffold(context: context, message: "KOT PDF opened");
        }
      } else {
        if (context.mounted) {
          showScaffold(
            context: context,
            message: "PDF saved: ${file.path}",
          );
        }
      }
    } catch (e) {
      debugPrint("Error opening PDF on Windows: $e");
      if (context.mounted) {
        showScaffold(
          context: context,
          message: "PDF saved: ${file.path}",
        );
      }
    }
  }

  // Fallback to sharing PDF
  Future<void> _sharePdfFallback(File file) async {
    try {
      debugPrint("Attempting to share KOT PDF as fallback...");
      // Only try to share on non-Windows platforms
      if (!Platform.isWindows) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject:
              'KOT - ${file.path.split('/').last.replaceAll('.pdf', '').replaceAll('KOT_', '')}',
          text: 'Kitchen Order Ticket',
        );

        if (context.mounted) {
          showScaffold(context: context, message: "KOT PDF shared");
        }
      } else {
        if (context.mounted) {
          showScaffold(context: context, message: "PDF saved: ${file.path}");
        }
      }
    } catch (e) {
      debugPrint("Error sharing KOT PDF: $e");
      if (context.mounted) {
        showScaffold(
          context: context,
          message: "PDF saved: ${file.path}",
        );
      }
    }
  }
}
