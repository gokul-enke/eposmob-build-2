import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';

/// Shared PDF builders for return items and final reconciliation on tax-invoice
/// standard layouts.
class TaxInvoiceReturnsPdfSection {
  TaxInvoiceReturnsPdfSection._();

  static String formatMoney(String currency, num amount) {
    final currencyPrefix =
        currency.trim().toUpperCase() == 'INR' ? 'Rs.' : currency.trim();
    if (currencyPrefix.isEmpty) return amount.toStringAsFixed(2);
    return '$currencyPrefix ${amount.toStringAsFixed(2)}';
  }

  static List<pw.Widget> buildReturnsSection(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5,
  ) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return [];
    }
    double fs(double v) => isA5 ? v * 0.78 : v;
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final headerStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(8), fontWeight: pw.FontWeight.bold);
    final bodyStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(8.5));
    final titleStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);

    bool col(String key) => dc?[key]?.visible == true;
    String lbl(String key, String? resolved, String def) {
      final v = dc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      if (resolved != null && resolved.isNotEmpty) return resolved;
      return def;
    }

    final showSl = col('showReturnSLNumber');
    final showParticulars = col('showReturnParticulars');
    final showMrp = col('showReturnMRP');
    final showQty = col('showReturnQty');
    final showRate = col('showReturnRate');
    final showTotal = col('showReturnTotal');

    final Map<int, pw.TableColumnWidth> colWidths = {};
    int ci = 0;
    if (showSl) colWidths[ci++] = const pw.FlexColumnWidth(0.6);
    if (showParticulars) colWidths[ci++] = const pw.FlexColumnWidth(4.2);
    if (showMrp) colWidths[ci++] = const pw.FlexColumnWidth(1.1);
    if (showQty) colWidths[ci++] = const pw.FlexColumnWidth(0.9);
    if (showRate) colWidths[ci++] = const pw.FlexColumnWidth(1.3);
    if (showTotal) colWidths[ci++] = const pw.FlexColumnWidth(1.5);

    pw.Widget hdrCell(String text) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(text,
              style: headerStyle, textAlign: pw.TextAlign.center),
        );

    final headerCells = <pw.Widget>[];
    if (showSl) {
      headerCells.add(hdrCell(
          lbl('showReturnSLNumber', resolvedLabels?.returnSlNumber, 'SL#')));
    }
    if (showParticulars) {
      headerCells.add(hdrCell(lbl('showReturnParticulars',
          resolvedLabels?.returnParticulars, 'PARTICULARS')));
    }
    if (showMrp) {
      headerCells
          .add(hdrCell(lbl('showReturnMRP', resolvedLabels?.returnMrp, 'MRP')));
    }
    if (showQty) {
      headerCells
          .add(hdrCell(lbl('showReturnQty', resolvedLabels?.returnQty, 'QTY')));
    }
    if (showRate) {
      headerCells.add(
          hdrCell(lbl('showReturnRate', resolvedLabels?.returnRate, 'RATE')));
    }
    if (showTotal) {
      headerCells.add(
          hdrCell(lbl('showReturnTotal', resolvedLabels?.returnTotal, 'TOTAL')));
    }

    pw.Widget cell(String text, {pw.Alignment align = pw.Alignment.center}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Align(
            alignment: align,
            child: pw.Text(text, style: bodyStyle),
          ),
        );

    final tableRows = <pw.TableRow>[];
    if (headerCells.isNotEmpty) {
      tableRows.add(pw.TableRow(children: headerCells));
    }

    for (int i = 0; i < orderReturns.returnItems!.length; i++) {
      final ri = orderReturns.returnItems![i];
      final num qty = ri.quantity ?? 0;
      final String name = ri.productName ?? '';

      double itemRate = 0.0;
      double itemMrp = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        double cartMrp = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName =
              (cartItem['product_name'] ?? cartItem['productName'] ?? '')
                  .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
          cartMrp =
              double.tryParse(cartItem['mrp']?.toString() ?? '0') ?? 0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
            cartMrp =
                double.tryParse(cartItem.mrp?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == name) {
          itemRate = cartRate;
          itemMrp = cartMrp;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalRet =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        num totalQty = 0;
        for (var ri2 in orderReturns.returnItems!) {
          totalQty += ri2.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalRet / totalQty : 0.0;
        itemMrp = itemRate;
      }
      final double itemTotal = qty * itemRate;

      final cells = <pw.Widget>[];
      if (showSl) cells.add(cell('${i + 1}'));
      if (showParticulars) {
        cells.add(cell(name, align: pw.Alignment.centerLeft));
      }
      if (showMrp) {
        cells.add(
            cell(itemMrp.toStringAsFixed(2), align: pw.Alignment.centerRight));
      }
      if (showQty) {
        cells.add(cell(qty.toString(), align: pw.Alignment.centerRight));
      }
      if (showRate) {
        cells.add(cell(itemRate.toStringAsFixed(2),
            align: pw.Alignment.centerRight));
      }
      if (showTotal) {
        cells.add(cell(itemTotal.toStringAsFixed(2),
            align: pw.Alignment.centerRight));
      }
      tableRows.add(pw.TableRow(children: cells));
    }

    final double returnRateTotal =
        double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      pw.Text('RETURNS', style: titleStyle),
      pw.SizedBox(height: 4),
    ];

    if (tableRows.isNotEmpty) {
      widgets.add(pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: colWidths,
        children: tableRows,
      ));
      widgets.add(pw.SizedBox(height: 4));
    }

    if (col('showReturnItemsCount')) {
      final countLabel = lbl('showReturnItemsCount', null, 'Return Items:');
      widgets.add(pw.Text(
          '$countLabel ${orderReturns.returnItems!.length}',
          style: labelStyle));
      widgets.add(pw.SizedBox(height: 2));
    }

    if (col('showReturnTotalAmount')) {
      final label = lbl('showReturnTotalAmount', null, 'Return Total:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label ', style: labelStyle),
          pw.Text(formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    if (col('showReturnNetAmount')) {
      final label = lbl('showReturnNetAmount', null, 'Return Net Amount:');
      widgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('$label ', style: labelStyle),
          pw.Text(formatMoney(currency, returnRateTotal), style: valueStyle),
        ],
      ));
    }

    return widgets;
  }

  static List<pw.Widget> buildFinalSummarySection(
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? dc,
    String currency,
    pw.Font font,
    pw.Font fontBold,
    bool isA5, {
    bool isDualLanguage = false,
    String? configLang,
  }) {
    final orderReturns = params.orderReturns!;
    if (orderReturns.returnItems == null || orderReturns.returnItems!.isEmpty) {
      return [];
    }
    double fs(double v) => isA5 ? v * 0.78 : v;

    bool vis(String key) => dc?[key]?.visible != false;
    bool visExplicit(String key) => dc?[key]?.visible == true;
    String lbl(String key, String def) {
      final v = dc?[key]?.value as String?;
      if (v != null && v.isNotEmpty) return v;
      return def;
    }

    final showFinalPurchase = vis('showFinalPurchase');
    final showFinalReturn = vis('showFinalReturn');
    final showFinalNetAmount = vis('showFinalNetAmount');
    final showFinalAmountInWords = visExplicit('showFinalAmountInWords');

    if (!showFinalPurchase && !showFinalReturn && !showFinalNetAmount) {
      return [];
    }

    final labelStyle = pw.TextStyle(
        font: fontBold, fontSize: fs(9), fontWeight: pw.FontWeight.bold);
    final valueStyle =
        pw.TextStyle(font: font, fontBold: fontBold, fontSize: fs(9));
    final valueBold = pw.TextStyle(
        font: fontBold, fontSize: fs(10), fontWeight: pw.FontWeight.bold);
    final wordsBold = pw.TextStyle(
        font: fontBold, fontSize: fs(8.5), fontWeight: pw.FontWeight.bold);

    double returnTotal = 0.0;
    for (final ri in orderReturns.returnItems!) {
      final num qty = ri.quantity ?? 0;
      double itemRate = 0.0;
      for (var cartItem in params.cartItems) {
        String cartName = '';
        double cartRate = 0.0;
        if (params.isFromLocalStorage || cartItem is Map) {
          cartName =
              (cartItem['product_name'] ?? cartItem['productName'] ?? '')
                  .toString();
          cartRate = double.tryParse(
                  (cartItem['unit_price'] ?? cartItem['unitPrice'])
                          ?.toString() ??
                      '0') ??
              0.0;
        } else {
          try {
            cartName = cartItem.productName?.toString() ?? '';
            cartRate =
                double.tryParse(cartItem.unitPrice?.toString() ?? '0') ?? 0.0;
          } catch (_) {}
        }
        if (cartName == ri.productName) {
          itemRate = cartRate;
          break;
        }
      }
      if (itemRate == 0.0) {
        final totalRet =
            double.tryParse(orderReturns.returnTotalAmount ?? '0') ?? 0.0;
        num totalQty = 0;
        for (var ri2 in orderReturns.returnItems!) {
          totalQty += ri2.quantity ?? 0;
        }
        itemRate = totalQty > 0 ? totalRet / totalQty : 0.0;
      }
      returnTotal += qty * itemRate;
    }

    final orderTotal =
        double.tryParse(params.formattedTotal.replaceAll(',', '')) ?? 0.0;
    final finalTotal = orderTotal - returnTotal;

    pw.TableRow summaryRow(
            String label, String value, pw.TextStyle valStyle) =>
        pw.TableRow(children: [
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value, style: valStyle),
            ),
          ),
        ]);

    final tableRows = <pw.TableRow>[];
    if (showFinalPurchase) {
      tableRows.add(summaryRow(lbl('showFinalPurchase', 'Order Total:'),
          formatMoney(currency, orderTotal), valueStyle));
    }
    if (showFinalReturn) {
      tableRows.add(summaryRow(lbl('showFinalReturn', 'Return Total:'),
          formatMoney(currency, returnTotal), valueStyle));
    }
    if (showFinalNetAmount) {
      tableRows.add(summaryRow(lbl('showFinalNetAmount', 'Final Total:'),
          formatMoney(currency, finalTotal), valueBold));
    }

    final widgets = <pw.Widget>[
      pw.SizedBox(height: 6),
      pw.Divider(height: 0, thickness: 0.8),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: tableRows,
      ),
    ];

    if (showFinalAmountInWords) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.addAll(_amountInWords(
          finalTotal, currency, isDualLanguage, configLang, wordsBold));
    }

    return widgets;
  }

  static List<pw.Widget> _amountInWords(double total, String currency,
      bool isDualLanguage, String? configLang, pw.TextStyle style) {
    if (isDualLanguage) {
      final ar = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'ar');
      final en = AmountHelper()
          .convertNumberToWords(total, currency: currency, language: 'en');
      return [
        pw.Text('$ar فقط.', style: style, textDirection: pw.TextDirection.rtl),
        pw.Text('$en Only.', style: style),
      ];
    }
    final language = (configLang ?? 'en').toLowerCase();
    final words = AmountHelper()
        .convertNumberToWords(total, currency: currency, language: language);
    final suffix = language == 'ar' ? ' فقط.' : ' only.';
    return [pw.Text('$words$suffix', style: style)];
  }
}
