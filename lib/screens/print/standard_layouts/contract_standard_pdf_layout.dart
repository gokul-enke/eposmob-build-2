import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/screens/print/layouts/receipt_configuration_contract.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/logo_loader.dart';
import 'package:pos_machine/services/development_printer_service.dart';
import 'package:pos_machine/services/common_print_settings.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:provider/provider.dart';

import 'standard_pdf_layout.dart';

/// The one production renderer used by every standard (A4/A5) theme.
///
/// Theme identifiers are intentionally kept at the adapter boundary.  The
/// document contract is not a property of a visual skin: it is a property of
/// the data passed to a PDF renderer.  Keeping this renderer shared means that
/// a newly added theme cannot accidentally re-introduce raw language checks,
/// permissive `visible != false` checks, or a different section order.
class ContractStandardPdfLayout implements StandardPdfLayout {
  final String _layoutId;
  final String _displayName;

  const ContractStandardPdfLayout({
    required String layoutId,
    required String displayName,
  })  : _layoutId = layoutId,
        _displayName = displayName;

  @override
  String get layoutId => _layoutId;

  @override
  String get displayName => _displayName;

  @override
  Future<void> generateAndPrintPdf(ReceiptLayoutParams params) async {
    try {
      final document = await buildPdfDocument(params);
      final bytes = await document.save();

      // Keep the same development-printer contract as the historical PDF
      // layouts.  Development output is saved and never sent to a system
      // printer.
      if (params.selectedPrinter.isDevelopment) {
        final file = await DevelopmentPrinterService.savePdf(
          bytes: bytes,
          orderNumber: params.orderNumber,
          layoutId: layoutId,
        );
        if (params.context.mounted) {
          showScaffold(
            context: params.context,
            message: 'print.pdf_saved'.trParams({'path': file.path}),
          );
        }
        return;
      }

      // A4/A5 is carried both by the PDF page format and by the direct print
      // call.  The direct service uses the selected paper size when creating
      // the OS printing job.
      if (await StandardPdfDirectPrintService.printBytes(
        pdfBytes: bytes,
        selectedPrinter: params.selectedPrinter,
        paperSize: params.selectedPaperSize,
        jobName: 'Receipt ${params.orderNumber}',
      )) {
        return;
      }

      final directory = await _getEposDirectory();
      final safeOrderNumber = params.orderNumber.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final file = File(
        '${directory.path}/Receipt_${safeOrderNumber}_$layoutId.pdf',
      );
      await file.writeAsBytes(bytes);

      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } catch (error) {
          debugPrint('[ContractStandardPdfLayout] Could not open PDF: $error');
        }
      } else {
        try {
          final result = await OpenFile.open(file.path);
          if (result.type != ResultType.done && params.context.mounted) {
            showScaffold(
              context: params.context,
              message: 'print.pdf_saved'.trParams({'path': file.path}),
            );
          }
        } catch (error) {
          debugPrint('[ContractStandardPdfLayout] Could not open PDF: $error');
          if (params.context.mounted) {
            showScaffold(
              context: params.context,
            message: 'print.pdf_saved'.trParams({'path': file.path}),
            );
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[ContractStandardPdfLayout] PDF generation failed: $error');
      debugPrint('$stackTrace');
      if (params.context.mounted) {
        showScaffoldError(
          context: params.context,
          message: 'print.pdf_generation_failed'.trParams(
              {'error': error.toString()}),
        );
      }
      if (params.selectedPrinter.isDevelopment) rethrow;
    }
  }

  @override
  Future<pw.Document> buildPdfDocument(ReceiptLayoutParams params) {
    return ContractStandardPdfRenderer().build(params);
  }

  Future<Directory> _getEposDirectory() async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final epos = Directory('${documents.path}/epos');
      if (!await epos.exists()) await epos.create(recursive: true);
      return epos;
    } catch (_) {
      return getTemporaryDirectory();
    }
  }
}

/// Contract implementation for the standard PDF surface.
///
/// All option resolution intentionally goes through [ReceiptLayoutParams]
/// (which delegates to [ReceiptConfigurationContract]).  In particular, this
/// class never reads `DisplayOption.visible` or the raw language string.
class ContractStandardPdfRenderer {
  // Keep the complete 61-key matrix visible at this production boundary.  The
  // set is also used to normalize the incoming options before sections are
  // built, so every key receives the same strict visibility semantics even if
  // a visual section does not currently need its value.
  static const List<String> contractBillKeys = [
    'showAccountName',
    'showAccountNumber',
    'showAmountInWords',
    'showBankInfo',
    'showBankName',
    'showComment',
    'showCRNumber',
    'showCustomerAddress',
    'showCustomerBalance',
    'showCustomerCrNumber',
    'showCustomerCurrentBalance',
    'showCustomerName',
    'showCustomerNameAndPhone',
    'showCustomerPaidAmount',
    'showCustomerPhone',
    'showCustomerPhoneMasked',
    'showCustomerPrevBalance',
    'showCustomerVatNumber',
    'showDate',
    'showDeliveryMethod',
    'showDeliveryPhone',
    'showDescription',
    'showDiscount',
    'showEmail',
    'showExtraHeading1',
    'showExtraHeading2',
    'showFssaiInfo',
    'showIBAN',
    'showInvoiceNumber',
    'showInvoiceTitle',
    'showInvoiceTitleB2b',
    'showItemsCount',
    'showMRP',
    'showMRPTotal',
    'showNetAmount',
    'showOrderNumberInFooter',
    'showParticulars',
    'showPayment',
    'showPaymentBreaked',
    'showQRCode',
    'showQty',
    'showQuantityCount',
    'showRate',
    'showRateExcTax',
    'showSaved',
    'showSLNumber',
    'showStoreAddress',
    'showStoreName',
    'showSubTotal',
    'showSwiftCode',
    'showTax',
    'showTaxHeader',
    'showTel',
    'showTermsConditions',
    'showThankYouMessage',
    'showTokenNumber',
    'showTotal',
    'showUnit',
    'showVATFooter',
    'showVatNumber',
    'showWarranty',
  ];

  Future<pw.Document> build(ReceiptLayoutParams params) async {
    final pageFormat = _pageFormat(params.selectedPaperSize);
    final mode = params.receiptLanguageMode;
    final fonts = await _loadFonts();
    final currency = _currency(params);
    final accent = _accentColor(params.billDocumentConfig.accentColor);
    final logo = await _loadLogo(params);

    // Resolve all keys once through the contract.  This is deliberately not
    // used as a permissive fallback: a missing key remains false/hidden.
    final visibleKeys = <String>{
      for (final key in contractBillKeys)
        if (params.isVisible(key)) key,
    };
    // Keep the canonical source list and runtime contract in lock-step.  The
    // assertion is harmless in release builds and catches accidental matrix
    // drift while developing a new server display option.
    assert(
      visibleKeys.length <=
          ReceiptConfigurationContract.canonicalBillKeys.length,
      'Standard PDF contract key matrix is larger than the canonical matrix',
    );

    final document = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final scale = pageFormat == PdfPageFormat.a5 ? 0.78 : 1.0;
    final body = <pw.Widget>[];

    // Canonical section order: header -> customer -> items -> totals ->
    // returns -> footer.  Keep these calls explicit for reviewability.
    body.addAll(_buildHeaderSection(
      params,
      fonts,
      accent,
      logo,
      scale,
      mode,
      visibleKeys,
    ));
    body.addAll(
        _buildCustomerSection(params, fonts, accent, scale, visibleKeys));
    if (!params.isReturnOnly) {
      body.addAll(_buildCartItemsSection(
        params,
        fonts,
        accent,
        currency,
        scale,
        visibleKeys,
      ));
      body.addAll(_buildWarrantySection(
        params,
        fonts,
        accent,
        scale,
        visibleKeys,
      ));
      body.addAll(_buildTotalsSection(
        params,
        fonts,
        accent,
        currency,
        scale,
        visibleKeys,
      ));
    }
    body.addAll(_buildReturnSection(
      params,
      fonts,
      accent,
      currency,
      scale,
      visibleKeys,
    ));
    body.addAll(_buildFooterSection(
      params,
      fonts,
      accent,
      currency,
      scale,
      visibleKeys,
    ));

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection:
            mode.isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: await CommonPrintSettings.resolvePdfMargins(
          pw.EdgeInsets.all(22 * scale),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: fonts.small,
          ),
        ),
        build: (_) => body,
      ),
    );
    return document;
  }

  List<pw.Widget> _buildHeaderSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    pw.MemoryImage? logo,
    double scale,
    ReceiptLanguageMode mode,
    Set<String> visibleKeys,
  ) {
    final config = params.billDocumentConfig;
    final children = <pw.Widget>[];
    if (logo != null) {
      children.add(
        pw.Center(
          child: pw.Container(
            height: 48 * scale,
            constraints: pw.BoxConstraints(maxWidth: 170 * scale),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final header = params.documentText(config.header);
    final subheader = params.documentText(config.subheader);
    if (header.isNotEmpty) children.add(_centerText(header, fonts.section));
    if (subheader.isNotEmpty) children.add(_centerText(subheader, fonts.small));

    if (_contains(visibleKeys, 'showStoreName')) {
      final store = params.labelFor(
        'showStoreName',
        englishFallback: _nonEmpty(params.storeName, 'STORE NAME'),
        arabicFallback: 'اسم المتجر',
      );
      if (store.isNotEmpty) children.add(_centerText(store, fonts.title));
    }
    if (_contains(visibleKeys, 'showDescription')) {
      final description = params.labelFor(
        'showDescription',
        englishFallback: '',
        arabicFallback: 'وصف المتجر',
      );
      if (description.isNotEmpty) {
        children.add(_centerText(description, fonts.bodyBold));
      }
    }
    if (_contains(visibleKeys, 'showStoreAddress') &&
        _clean(params.storeLocation).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor(
          'showStoreAddress',
          englishFallback: 'Address',
          arabicFallback: 'العنوان',
        ),
        params.documentText(params.storeLocation),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showFssaiInfo')) {
      final fssai = params.labelFor(
        'showFssaiInfo',
        englishFallback: '',
        arabicFallback: '',
      );
      if (fssai.isNotEmpty) children.add(_centerText(fssai, fonts.small));
    }

    // Store tax-registration values are data, not configured labels.  Keep
    // them in the store/header section and leave the VAT footer switch
    // independent below.
    if (_contains(visibleKeys, 'showVatNumber') &&
        _clean(params.zatcaVatNumber).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor(
          'showVatNumber',
          englishFallback: 'VAT No',
          arabicFallback: 'الرقم الضريبي',
        ),
        params.documentText(params.zatcaVatNumber),
        fonts.small,
      ));
    }
    if (_contains(visibleKeys, 'showCRNumber') &&
        _clean(params.zatcaCrNumber).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor(
          'showCRNumber',
          englishFallback: 'CR No',
          arabicFallback: 'السجل التجاري',
        ),
        params.documentText(params.zatcaCrNumber),
        fonts.small,
      ));
    }
    for (final key in const ['showExtraHeading1', 'showExtraHeading2']) {
      if (_contains(visibleKeys, key)) {
        final heading = params.labelFor(
          key,
          englishFallback: '',
          arabicFallback: '',
        );
        if (heading.isNotEmpty) children.add(_centerText(heading, fonts.small));
      }
    }
    if (_contains(visibleKeys, 'showTel') &&
        _clean(params.storePhone ?? params.customerCareNumber).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor('showTel',
            englishFallback: 'Telephone', arabicFallback: 'الهاتف'),
        params.documentText(params.storePhone ?? params.customerCareNumber),
        fonts.small,
      ));
    }
    if (_contains(visibleKeys, 'showEmail') &&
        _clean(params.storeEmail ?? params.customerCareEmail).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor('showEmail',
            englishFallback: 'Email', arabicFallback: 'البريد الإلكتروني'),
        params.documentText(params.storeEmail ?? params.customerCareEmail),
        fonts.small,
      ));
    }

    final invoiceTitleVisible = _contains(visibleKeys, 'showInvoiceTitle');
    final title = invoiceTitleVisible
        ? params.labelFor(
            'showInvoiceTitle',
            englishFallback: 'INVOICE',
            arabicFallback: 'فاتورة',
          )
        : '';
    if (title.isNotEmpty) {
      children.add(pw.SizedBox(height: 5 * scale));
      children.add(
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(vertical: 6 * scale),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: _centerText(
              title, fonts.section.copyWith(color: PdfColors.white)),
        ),
      );
    }

    final meta = <pw.Widget>[];
    if (_contains(visibleKeys, 'showInvoiceNumber')) {
      meta.add(_labelValue(
        params.labelFor('showInvoiceNumber',
            englishFallback: 'Invoice No', arabicFallback: 'رقم الفاتورة'),
        params.documentText(
            '${_clean(config.numberPrefix)}${params.orderNumber}'),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showDate')) {
      meta.add(_labelValue(
        params.labelFor('showDate',
            englishFallback: 'Date', arabicFallback: 'التاريخ'),
        _formatDate(params.orderDate),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showTokenNumber') &&
        _clean(params.tokenNumber).isNotEmpty) {
      meta.add(_labelValue(
        params.labelFor('showTokenNumber',
            englishFallback: 'Token No', arabicFallback: 'رقم الرمز'),
        params.documentText(params.tokenNumber),
        fonts.body,
      ));
    }
    if (meta.isNotEmpty) {
      children.add(pw.SizedBox(height: 6 * scale));
      children.add(pw.Column(children: meta));
    }
    if (children.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(bottom: 8 * scale),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent, width: 1.2)),
        ),
        child: pw.Column(children: children),
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildCustomerSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    double scale,
    Set<String> visibleKeys,
  ) {
    final rows = <pw.Widget>[];
    // `showCustomerNameAndPhone` is the customer-section master switch.  A
    // child option being present must not resurrect the section when the
    // master is disabled; this mirrors the thermal contract semantics.
    final customerMaster = _contains(visibleKeys, 'showCustomerNameAndPhone');
    final showName =
        customerMaster && _contains(visibleKeys, 'showCustomerName');
    final showPhone =
        customerMaster && _contains(visibleKeys, 'showCustomerPhone');
    final name = _clean(params.customerName);
    final phone = _clean(params.customerPhone);
    if (showName && name.isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showCustomerName',
            englishFallback: 'Customer', arabicFallback: 'العميل'),
        params.documentText(name),
        fonts.body,
      ));
    }
    if (showPhone && phone.isNotEmpty) {
      final shownPhone = _contains(visibleKeys, 'showCustomerPhoneMasked')
          ? StringHelper.maskStringShowLast4(phone)
          : phone;
      rows.add(_labelValue(
        params.labelFor('showCustomerPhone',
            englishFallback: 'Phone', arabicFallback: 'الهاتف'),
        params.documentText(shownPhone),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showCustomerAddress') &&
        _clean(params.customerAddress).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showCustomerAddress',
            englishFallback: 'Address', arabicFallback: 'العنوان'),
        params.documentText(params.customerAddress),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showCustomerVatNumber') &&
        _clean(params.customerVatNumber).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showCustomerVatNumber',
            englishFallback: 'Customer VAT',
            arabicFallback: 'الرقم الضريبي للعميل'),
        params.documentText(params.customerVatNumber),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showCustomerCrNumber') &&
        _clean(params.customerCrNumber).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showCustomerCrNumber',
            englishFallback: 'Customer CR',
            arabicFallback: 'السجل التجاري للعميل'),
        params.documentText(params.customerCrNumber),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showDeliveryMethod') &&
        _clean(params.deliveryMethod).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showDeliveryMethod',
            englishFallback: 'Delivery', arabicFallback: 'التوصيل'),
        params.documentText(params.deliveryMethod),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showDeliveryPhone') &&
        _clean(params.deliveryPhone).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showDeliveryPhone',
            englishFallback: 'Delivery Phone', arabicFallback: 'هاتف التوصيل'),
        params.documentText(params.deliveryPhone),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showPayment') &&
        _clean(params.paymentMethod).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showPayment',
            englishFallback: 'Payment', arabicFallback: 'الدفع'),
        params.documentText(params.paymentMethod),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showComment') &&
        _clean(params.orderComment).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showComment',
            englishFallback: 'Comment', arabicFallback: 'تعليق'),
        params.documentText(params.orderComment),
        fonts.body,
      ));
    }
    if (rows.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionBox(
        rows,
        accent,
        scale,
        heading: params.labelFor(
          'showCustomerName',
          englishFallback: 'Customer Details',
          arabicFallback: 'بيانات العميل',
        ),
        fonts: fonts,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildCartItemsSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
    Set<String> visibleKeys,
  ) {
    final columns = <_PdfColumn>[];
    if (_contains(visibleKeys, 'showSLNumber')) {
      columns.add(_PdfColumn(
        key: 'showSLNumber',
        heading: params.labelFor('showSLNumber',
            englishFallback: '#', arabicFallback: 'م'),
        value: (item, index) => '${index + 1}',
      ));
    }
    if (_contains(visibleKeys, 'showParticulars')) {
      final labels = params.billDocumentConfig.resolvedLabels;
      columns.add(_PdfColumn(
        key: 'showParticulars',
        heading: params.labelFor(
          'showParticulars',
          englishFallback: 'PARTICULARS',
          arabicFallback: 'البيان',
          resolvedEnglish: labels?.particularsDefault ?? labels?.itemName,
          resolvedArabic: labels?.particulars,
        ),
        flex: 3,
        value: (item, index) => _itemName(params, item),
      ));
    }
    if (_contains(visibleKeys, 'showMRP')) {
      columns.add(_PdfColumn(
        key: 'showMRP',
        heading: params.labelFor('showMRP',
            englishFallback: 'MRP', arabicFallback: 'سعر التجزئة'),
        value: (item, index) => _money(
            _number(_field(item, const ['mrp', 'maximum_retail_price'])),
            currency),
      ));
    }
    if (_contains(visibleKeys, 'showQty')) {
      final labels = params.billDocumentConfig.resolvedLabels;
      columns.add(_PdfColumn(
        key: 'showQty',
        heading: params.labelFor(
          'showQty',
          englishFallback: 'QTY',
          arabicFallback: 'الكمية',
          resolvedEnglish: labels?.qtyDefault,
          resolvedArabic: labels?.qty,
        ),
        value: (item, index) =>
            _quantity(_field(item, const ['quantity', 'qty'])),
      ));
    }
    if (_contains(visibleKeys, 'showRate')) {
      columns.add(_PdfColumn(
        key: 'showRate',
        heading: params.labelFor('showRate',
            englishFallback: 'RATE', arabicFallback: 'السعر'),
        value: (item, index) => _money(
            _number(_field(item, const ['unitPrice', 'unit_price', 'price'])),
            currency),
      ));
    }
    if (_contains(visibleKeys, 'showRateExcTax')) {
      columns.add(_PdfColumn(
        key: 'showRateExcTax',
        heading: params.labelFor('showRateExcTax',
            englishFallback: 'RATE (EXC TAX)',
            arabicFallback: 'السعر قبل الضريبة'),
        value: (item, index) => _money(_rateExcTax(params, item), currency),
      ));
    }
    if (_contains(visibleKeys, 'showUnit')) {
      final labels = params.billDocumentConfig.resolvedLabels;
      columns.add(_PdfColumn(
        key: 'showUnit',
        heading: params.labelFor(
          'showUnit',
          englishFallback: 'UNIT',
          arabicFallback: 'الوحدة',
          resolvedEnglish: labels?.unitNameDefault ?? labels?.unitName,
          resolvedArabic: labels?.unitName,
        ),
        value: (item, index) => _text(_field(item, const [
          'saleUnitName',
          'sale_unit_name',
          'productUnit',
          'product_unit',
          'unit'
        ])),
      ));
    }
    if (_contains(visibleKeys, 'showTotal')) {
      final labels = params.billDocumentConfig.resolvedLabels;
      columns.add(_PdfColumn(
        key: 'showTotal',
        heading: params.labelFor(
          'showTotal',
          englishFallback: 'TOTAL',
          arabicFallback: 'الإجمالي',
          resolvedEnglish: labels?.totalDefault ?? labels?.total,
          resolvedArabic: labels?.total,
        ),
        value: (item, index) => _money(
            _number(_field(
                item, const ['totalPrice', 'total_price', 'amount', 'total'])),
            currency),
      ));
    }
    if (_contains(visibleKeys, 'showTax')) {
      final labels = params.billDocumentConfig.resolvedLabels;
      columns.add(_PdfColumn(
        key: 'showTax',
        heading: _contains(visibleKeys, 'showTaxHeader')
            ? params.labelFor(
                'showTaxHeader',
                englishFallback: 'VAT',
                arabicFallback: 'الضريبة',
                resolvedEnglish: labels?.taxDefault ?? labels?.taxName,
                resolvedArabic: labels?.tax,
              )
            : '',
        value: (item, index) => _money(
            _number(_field(item, const ['taxAmount', 'tax_amount', 'tax'])),
            currency),
      ));
    }

    if (columns.isEmpty || params.cartItems.isEmpty) {
      return const <pw.Widget>[];
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: accent),
        children: columns
            .map((column) => _cell(column.heading, fonts.tableHeader,
                align: pw.TextAlign.center))
            .toList(),
      ),
      for (var index = 0; index < params.cartItems.length; index++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven
                ? PdfColors.white
                : const PdfColor.fromInt(0xFFF5F7FA),
          ),
          children: columns
              .map((column) => _cell(
                    column.value(params.cartItems[index], index),
                    fonts.small,
                    align: column.key == 'showParticulars'
                        ? pw.TextAlign.left
                        : pw.TextAlign.center,
                  ))
              .toList(),
        ),
    ];

    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < columns.length; i++) {
      widths[i] = pw.FlexColumnWidth(columns[i].flex.toDouble());
    }
    return <pw.Widget>[
      _sectionTitle(
        params.labelFor('showParticulars',
            englishFallback: 'Items', arabicFallback: 'الأصناف'),
        fonts.section,
        accent,
        scale,
      ),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: widths,
        children: tableRows,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildWarrantySection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    double scale,
    Set<String> visibleKeys,
  ) {
    if (!_contains(visibleKeys, 'showWarranty')) {
      return const <pw.Widget>[];
    }
    final warrantyRows = <pw.Widget>[];
    for (final item in params.cartItems) {
      if (!_hasWarranty(item)) continue;
      final name = _itemName(params, item);
      final warranty = _text(
        _field(item, const ['warranty', 'warranty_period', 'warrantyPeriod']),
      );
      warrantyRows.add(_labelValue(
        params.labelFor(
          'showWarranty',
          englishFallback: 'Warranty',
          arabicFallback: 'الضمان',
        ),
        warranty.isEmpty ? name : '$name: $warranty',
        fonts.small,
      ));
    }
    if (warrantyRows.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionBox(
        warrantyRows,
        accent,
        scale,
        heading: params.labelFor(
          'showWarranty',
          englishFallback: 'Warranty',
          arabicFallback: 'الضمان',
        ),
        fonts: fonts,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildTotalsSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
    Set<String> visibleKeys,
  ) {
    final rows = <pw.Widget>[];
    final total = _number(params.formattedTotal);
    final saved = _number(params.savedTotal);
    final discount = _number(params.discountAmount);
    final subtotal = total + discount;
    final totalMrp = params.cartItems.fold<double>(
      0,
      (sum, item) =>
          sum +
          (_number(_field(item, const ['mrp', 'maximum_retail_price'])) *
              _number(_field(item, const ['quantity', 'qty']))),
    );
    final netExcTax =
        _number(params.netExcTax).isFinite && _number(params.netExcTax) != 0
            ? _number(params.netExcTax)
            : total - params.totalTax;

    void add(String key, String label, String value) {
      if (_contains(visibleKeys, key)) {
        rows.add(_labelValue(label, value, fonts.body));
      }
    }

    if (_contains(visibleKeys, 'showItemsCount')) {
      add(
          'showItemsCount',
          params.labelFor('showItemsCount',
              englishFallback: 'Items', arabicFallback: 'العدد'),
          '${params.cartItems.length}');
    }
    if (_contains(visibleKeys, 'showQuantityCount')) {
      add(
          'showQuantityCount',
          params.labelFor('showQuantityCount',
              englishFallback: 'Total Qty', arabicFallback: 'إجمالي الكمية'),
          _quantity(params.totalQuantity));
    }
    if (_contains(visibleKeys, 'showMRPTotal') ||
        _contains(visibleKeys, 'showTotalMRP')) {
      add(
          'showMRPTotal',
          params.labelFor('showMRPTotal',
              englishFallback: 'Total MRP',
              arabicFallback: 'إجمالي سعر التجزئة'),
          _money(totalMrp, currency));
    }
    if (_contains(visibleKeys, 'showSubTotal') ||
        _contains(visibleKeys, 'showTaxableAmount')) {
      add(
          'showSubTotal',
          params.labelFor('showSubTotal',
              englishFallback: 'Subtotal', arabicFallback: 'المجموع الفرعي'),
          _money(subtotal, currency));
    }
    if (_contains(visibleKeys, 'showDiscount')) {
      add(
          'showDiscount',
          params.labelFor('showDiscount',
              englishFallback: 'Discount', arabicFallback: 'الخصم'),
          _money(discount, currency));
    }
    if (_contains(visibleKeys, 'showSaved')) {
      add(
          'showSaved',
          params.labelFor('showSaved',
              englishFallback: 'You Saved', arabicFallback: 'لقد وفرت'),
          _money(saved, currency));
    }
    if (_contains(visibleKeys, 'showTax')) {
      add(
          'showTax',
          params.labelFor('showTax',
              englishFallback: 'VAT', arabicFallback: 'الضريبة'),
          _money(params.totalTax, currency));
    }
    if (_contains(visibleKeys, 'showNetAmount') ||
        _contains(visibleKeys, 'showNetTotal')) {
      add(
          'showNetAmount',
          params.labelFor('showNetAmount',
              englishFallback: 'Net Amount', arabicFallback: 'صافي المبلغ'),
          _money(netExcTax, currency));
    }
    if (_contains(visibleKeys, 'showTotal')) {
      rows.add(
        pw.Container(
          margin: pw.EdgeInsets.only(top: 3 * scale),
          padding: pw.EdgeInsets.symmetric(
              vertical: 5 * scale, horizontal: 7 * scale),
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: _labelValue(
            params.labelFor('showTotal',
                englishFallback: 'Grand Total',
                arabicFallback: 'المبلغ الاجمالي'),
            _money(total, currency),
            fonts.bodyBold.copyWith(color: PdfColors.white),
          ),
        ),
      );
    }
    if (_contains(visibleKeys, 'showAmountInWords')) {
      final words = _amountInWords(params, currency, total);
      if (words.isNotEmpty) {
        rows.add(_labelValue(
          params.labelFor('showAmountInWords',
              englishFallback: 'Amount in Words',
              arabicFallback: 'المبلغ كتابة'),
          words,
          fonts.small,
        ));
      }
    }
    if (_contains(visibleKeys, 'showPayment') &&
        _clean(params.paymentMethod).isNotEmpty) {
      rows.add(_labelValue(
        params.labelFor('showPayment',
            englishFallback: 'Payment', arabicFallback: 'الدفع'),
        params.documentText(params.paymentMethod),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showPaymentBreaked') ||
        _contains(visibleKeys, 'showPaymentBreakdown')) {
      final rawBreakdown = params.paymentBreakdown;
      final nestedAmounts = rawBreakdown?['amounts'];
      final breakdown = nestedAmounts is Map
          ? Map<String, dynamic>.from(nestedAmounts)
          : rawBreakdown;
      if (breakdown != null && breakdown.isNotEmpty) {
        rows.add(_sectionTitle(
          params.labelFor('showPaymentBreaked',
              englishFallback: 'Payment Breakdown',
              arabicFallback: 'تفاصيل الدفع'),
          fonts.bodyBold,
          accent,
          scale,
        ));
        for (final entry in breakdown.entries) {
          rows.add(_labelValue(
            params.textForMode(
                english: entry.key.toString(), arabic: entry.key.toString()),
            _money(_number(entry.value), currency),
            fonts.small,
          ));
        }
      }
    }
    if (_contains(visibleKeys, 'showCustomerPrevBalance') &&
        params.customerOldBalance != null) {
      rows.add(_labelValue(
        params.labelFor('showCustomerPrevBalance',
            englishFallback: 'Previous Balance',
            arabicFallback: 'الرصيد السابق'),
        _money(params.customerOldBalance, currency),
        fonts.body,
      ));
    }
    if ((_contains(visibleKeys, 'showCustomerCurrentBalance') ||
            _contains(visibleKeys, 'showCustomerBalance')) &&
        params.customerCurrentBalance != null) {
      rows.add(_labelValue(
        params.labelFor('showCustomerCurrentBalance',
            englishFallback: 'Current Balance',
            arabicFallback: 'الرصيد الحالي'),
        _money(params.customerCurrentBalance, currency),
        fonts.body,
      ));
    }
    if (_contains(visibleKeys, 'showCustomerPaidAmount') &&
        params.paidAmount != null) {
      rows.add(_labelValue(
        params.labelFor('showCustomerPaidAmount',
            englishFallback: 'Paid Amount', arabicFallback: 'المبلغ المدفوع'),
        _money(params.paidAmount, currency),
        fonts.body,
      ));
    }
    if (rows.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionBox(
        rows,
        accent,
        scale,
        heading: params.labelFor('showTotal',
            englishFallback: 'Summary', arabicFallback: 'الملخص'),
        fonts: fonts,
      ),
      pw.SizedBox(height: 8 * scale),
    ];
  }

  List<pw.Widget> _buildReturnSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
    Set<String> visibleKeys,
  ) {
    final returns = params.orderReturns?.returnItems;
    if (returns == null || returns.isEmpty) return const <pw.Widget>[];
    final showName = _contains(visibleKeys, 'showParticulars');
    final showQty = _contains(visibleKeys, 'showQty');
    final showTotal = _contains(visibleKeys, 'showTotal');
    if (!showName && !showQty && !showTotal) return const <pw.Widget>[];

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: accent),
        children: [
          if (showName)
            _cell(
                params.labelFor('showParticulars',
                    englishFallback: 'PARTICULARS', arabicFallback: 'البيان'),
                fonts.tableHeader,
                align: pw.TextAlign.center),
          if (showQty)
            _cell(
                params.labelFor('showQty',
                    englishFallback: 'QTY', arabicFallback: 'الكمية'),
                fonts.tableHeader,
                align: pw.TextAlign.center),
          if (showTotal)
            _cell(
                params.labelFor('showTotal',
                    englishFallback: 'TOTAL', arabicFallback: 'الإجمالي'),
                fonts.tableHeader,
                align: pw.TextAlign.center),
        ],
      ),
      for (var i = 0; i < returns.length; i++)
        pw.TableRow(children: [
          if (showName) _cell(_returnName(params, returns[i]), fonts.small),
          if (showQty)
            _cell(_quantity(_field(returns[i], const ['quantity', 'qty'])),
                fonts.small,
                align: pw.TextAlign.center),
          if (showTotal) _cell('', fonts.small, align: pw.TextAlign.center),
        ]),
    ];
    final returnTotal = _number(params.orderReturns?.returnTotalAmount);
    final widgets = <pw.Widget>[
      _sectionTitle(params.returnsSectionHeading, fonts.section, accent, scale),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          if (showName) 0: const pw.FlexColumnWidth(3),
          if (showQty) showName ? 1 : 0: const pw.FlexColumnWidth(1),
          if (showTotal)
            (showName ? 1 : 0) + (showQty ? 1 : 0):
                const pw.FlexColumnWidth(1.4),
        },
        children: rows,
      ),
    ];
    if (showTotal && returnTotal != 0) {
      widgets.add(_labelValue(
        params.labelFor('showTotal',
            englishFallback: 'Return Total', arabicFallback: 'إجمالي المرتجع'),
        _money(returnTotal, currency),
        fonts.bodyBold,
      ));
    }
    widgets.add(pw.SizedBox(height: 8 * scale));
    return widgets;
  }

  List<pw.Widget> _buildFooterSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    String currency,
    double scale,
    Set<String> visibleKeys,
  ) {
    final children = <pw.Widget>[];
    // Footer order is bank -> QR -> VAT footer -> terms/thank-you/order
    // metadata.  Comment, payment, balances, and warranty are rendered in
    // their canonical sections earlier in the document.
    children
        .addAll(_buildBankSection(params, fonts, accent, scale, visibleKeys));

    if (_contains(visibleKeys, 'showQRCode')) {
      final qr = _qrData(params);
      if (qr.isNotEmpty) {
        children.add(pw.SizedBox(height: 5 * scale));
        children.add(
          pw.Column(
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qr,
                width: 82 * scale,
                height: 82 * scale,
              ),
              pw.SizedBox(height: 2 * scale),
              _centerText(
                params.labelFor('showQRCode',
                    englishFallback: 'Scan to Pay',
                    arabicFallback: 'امسح للدفع'),
                fonts.small,
              ),
            ],
          ),
        );
      }
    }
    if (_contains(visibleKeys, 'showVATFooter') &&
        _clean(params.zatcaVatNumber).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor('showVATFooter',
            englishFallback: 'VAT No', arabicFallback: 'الرقم الضريبي'),
        params.documentText(params.zatcaVatNumber),
        fonts.small,
      ));
    }
    if (_contains(visibleKeys, 'showTermsConditions') &&
        _clean(params.billDocumentConfig.terms).isNotEmpty) {
      children.add(_labelValue(
        params.labelFor('showTermsConditions',
            englishFallback: 'Terms & Conditions',
            arabicFallback: 'الشروط والأحكام'),
        params.documentText(params.billDocumentConfig.terms),
        fonts.small,
      ));
    }
    if (_contains(visibleKeys, 'showThankYouMessage')) {
      final footerText = params.documentText(params.billDocumentConfig.footer);
      if (footerText.isNotEmpty) {
        children.add(_centerText(footerText, fonts.small));
      }
      final thankYou = params.labelFor('showThankYouMessage',
          englishFallback: 'Thank you', arabicFallback: 'شكراً لكم');
      if (thankYou.isNotEmpty) {
        children.add(_centerText(thankYou, fonts.bodyBold));
      }
    }
    if (_contains(visibleKeys, 'showOrderNumberInFooter')) {
      children.add(_centerText(
        '${params.labelFor('showOrderNumberInFooter', englishFallback: 'Invoice No', arabicFallback: 'رقم الفاتورة')}: ${params.documentText(params.orderNumber)}',
        fonts.small,
      ));
    }
    if (children.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      pw.SizedBox(height: 4 * scale),
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(top: 7 * scale),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: accent, width: 1)),
        ),
        child: pw.Column(children: children),
      ),
    ];
  }

  List<pw.Widget> _buildBankSection(
    ReceiptLayoutParams params,
    _PdfFonts fonts,
    PdfColor accent,
    double scale,
    Set<String> visibleKeys,
  ) {
    if (!_contains(visibleKeys, 'showBankInfo')) return const <pw.Widget>[];
    final bank = params.primaryBank;
    final account = params.primaryBankAccount;
    if (bank == null && account == null) return const <pw.Widget>[];
    final lines = <pw.Widget>[];
    void add(String key, String label, String? value) {
      if (!_contains(visibleKeys, key) || _clean(value).isEmpty) return;
      lines.add(_labelValue(
        params.textForMode(english: label, arabic: _bankArabicLabel(label)),
        params.documentText(value),
        fonts.small,
      ));
    }

    add('showBankName', 'Bank Name', bank?.bankName);
    add('showAccountName', 'Account Name', account?.accountHolderName);
    add('showAccountNumber', 'Account Number', account?.accountNumber);
    add('showIBAN', 'IBAN', account?.iban);
    add('showSwiftCode', 'SWIFT Code', account?.swiftCode);
    if (lines.isEmpty) return const <pw.Widget>[];
    return <pw.Widget>[
      _sectionTitle(
        params.labelFor('showBankInfo',
            englishFallback: 'Bank Details', arabicFallback: 'تفاصيل البنك'),
        fonts.bodyBold,
        accent,
        scale,
      ),
      ...lines,
    ];
  }

  pw.Widget _sectionBox(
    List<pw.Widget> children,
    PdfColor accent,
    double scale, {
    required String heading,
    required _PdfFonts fonts,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(7 * scale),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (heading.isNotEmpty)
            _sectionTitle(heading, fonts.bodyBold, accent, scale),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(
      String title, pw.TextStyle style, PdfColor accent, double scale) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 4 * scale),
      child: pw.Text(
        title,
        style: style.copyWith(color: accent),
        textAlign: pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _labelValue(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.7),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(value, style: style, textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  pw.Widget _centerText(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Text(text, style: style, textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _cell(String value, pw.TextStyle style, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child:
          pw.Text(value, style: style, textAlign: align ?? pw.TextAlign.left),
    );
  }

  bool _contains(Set<String> visibleKeys, String key) {
    // All membership values were produced by ReceiptLayoutParams.isVisible,
    // which resolves canonical aliases and uses strict `visible == true`.
    return visibleKeys.contains(key) ||
        (key == 'showTotalMRP' && visibleKeys.contains('showMRPTotal')) ||
        (key == 'showTaxableAmount' && visibleKeys.contains('showSubTotal')) ||
        (key == 'showNetTotal' && visibleKeys.contains('showNetAmount')) ||
        (key == 'showPaymentBreakdown' &&
            visibleKeys.contains('showPaymentBreaked')) ||
        (key == 'showPaidAmount' &&
            visibleKeys.contains('showCustomerPaidAmount')) ||
        (key == 'showBankDetails' && visibleKeys.contains('showBankInfo')) ||
        (key == 'showBankAccountName' &&
            visibleKeys.contains('showAccountName')) ||
        (key == 'showBankAccountNumber' &&
            visibleKeys.contains('showAccountNumber')) ||
        (key == 'showBankIban' && visibleKeys.contains('showIBAN')) ||
        (key == 'showBankSwiftCode' && visibleKeys.contains('showSwiftCode')) ||
        (key == 'showTerms' && visibleKeys.contains('showTermsConditions')) ||
        (key == 'showInvoiceTitleB2B' &&
            visibleKeys.contains('showInvoiceTitleB2b'));
  }

  PdfPageFormat _pageFormat(String paperSize) {
    return paperSize.trim().toUpperCase() == 'A5'
        ? PdfPageFormat.a5
        : PdfPageFormat.a4;
  }

  Future<_PdfFonts> _loadFonts() async {
    try {
      final regular =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      final bold =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      final font = pw.Font.ttf(regular);
      final fontBold = pw.Font.ttf(bold);
      return _PdfFonts.from(font, fontBold);
    } catch (error) {
      debugPrint(
          '[ContractStandardPdfRenderer] Arabic font unavailable: $error');
      return _PdfFonts.from(pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  Future<pw.MemoryImage?> _loadLogo(ReceiptLayoutParams params) async {
    if (params.billDocumentConfig.showLogo != 1) return null;
    final source = _clean(params.billDocumentConfig.logo);
    if (source.isEmpty) return null;
    try {
      return PrintLogoLoader.loadPdfLogo(
        source,
        tag: '[ContractStandardPdfRenderer]',
      );
    } catch (error) {
      debugPrint('[ContractStandardPdfRenderer] Logo unavailable: $error');
      return null;
    }
  }

  String _currency(ReceiptLayoutParams params) {
    try {
      return Provider.of<AppSettingsProvider>(params.context, listen: false)
              .appSettings
              ?.currency ??
          '';
    } catch (_) {
      return '';
    }
  }

  PdfColor _accentColor(String? raw) {
    final value = _clean(raw).replaceFirst('#', '');
    if (value.isEmpty) return const PdfColor.fromInt(0xFF2563EB);
    final normalized = value.length == 6 ? 'FF$value' : value;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null
        ? const PdfColor.fromInt(0xFF2563EB)
        : PdfColor.fromInt(parsed);
  }

  String _formatDate(String raw) {
    final trimmed = _clean(raw);
    if (trimmed.isEmpty) return '';
    return DateHelper.formatISODate(trimmed);
  }

  String _amountInWords(
      ReceiptLayoutParams params, String currency, double amount) {
    final english = AmountHelper().convertNumberToWords(
      amount,
      currency: currency.isEmpty ? 'INR' : currency,
      language: 'en',
    );
    final arabic = AmountHelper().convertNumberToWords(
      amount,
      currency: currency.isEmpty ? 'INR' : currency,
      language: 'ar',
    );
    return params.textForMode(
        english: '$english Only.', arabic: '$arabic فقط.');
  }

  String _qrData(ReceiptLayoutParams params) {
    final zatca = _zatcaQr(params);
    if (zatca.isNotEmpty) return zatca;

    // Non-ZATCA documents can still use the configured manual/payment QR.
    // Provider lookup is optional so offline PDF generation remains safe.
    try {
      final gateways = Provider.of<PaymentGatewaysProvider>(
        params.context,
        listen: false,
      ).paymentGateways;
      final gateway = gateways.firstWhere(
        (item) => item.code == 'MANUAL_PAYMENT_GATEWAY',
        orElse: () => PaymentGateway(
          id: 0,
          name: '',
          code: '',
          label: '',
          link: '',
          image: '',
          status: '',
          isWebActive: 0,
          isAndroidActive: 0,
          isIosActive: 0,
          contactEmail: '',
          contactPhone: '',
          createdAt: '',
          updatedAt: '',
        ),
      );
      var link = gateway.link.trim();
      if (link.isEmpty) return '';
      link = link
          .replaceAll('{formattedTotal}', params.formattedTotal)
          .replaceAll('{orderNumber}', params.orderNumber);
      if (link.contains('@')) {
        link =
            'upi://pay?pa=$link&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
      }
      return link;
    } catch (_) {
      return '';
    }
  }

  String _zatcaQr(ReceiptLayoutParams params) {
    if (!params.hasZatcaCredentials) return '';
    return ZatcaQrHelper().generateQrForInvoice(
      sellerName: params.zatcaCompanyName,
      vatNumber: params.zatcaVatNumber,
      invoiceDate: params.orderDate,
      totalAmount: params.totalAmountAsDouble,
      vatAmount: params.totalTax,
    );
  }

  String _itemName(ReceiptLayoutParams params, dynamic item) {
    final names = _field(item, const [
      'productNames',
      'product_names',
      'names',
      'translations',
    ]);
    final direct = _text(_field(item, const [
      'displayName',
      'productName',
      'product_name',
      'name',
      'particulars',
    ]));
    final explicitEnglish = _text(_field(item, const [
      'displayNameEn',
      'display_name_en',
      'productNameEn',
      'product_name_en',
      'nameEn',
      'name_en',
    ]));
    final explicitArabic = _text(_field(item, const [
      'displayNameAr',
      'display_name_ar',
      'productNameAr',
      'product_name_ar',
      'nameAr',
      'name_ar',
    ]));
    final english = _firstText([
      explicitEnglish,
      _localizedField(names, const ['en', 'english', 'default']),
      if (!_hasArabic(direct)) direct,
    ]);
    final arabic = _firstText([
      explicitArabic,
      _localizedField(names, const ['ar', 'arabic']),
      if (_hasArabic(direct)) direct,
    ]);
    final localized = switch (params.receiptLanguageMode) {
      ReceiptLanguageMode.english => english,
      ReceiptLanguageMode.arabic => arabic,
      ReceiptLanguageMode.bilingual => params.textForMode(
          english: english.isEmpty ? direct : english,
          arabic: arabic.isEmpty ? direct : arabic,
        ),
    };
    final attrs = _field(item, const ['formattedVariantAttributes']);
    final attrText = _text(attrs);
    if (localized.isEmpty) return attrText;
    return attrText.isEmpty || localized.contains(attrText)
        ? localized
        : '$localized ($attrText)';
  }

  String _returnName(ReceiptLayoutParams params, dynamic item) =>
      _itemName(params, item) +
      (_text(_field(item, const ['reason'])).isEmpty
          ? ''
          : ' (${_text(_field(item, const ['reason']))})');

  bool _hasWarranty(dynamic item) {
    final enabled = _field(item, const ['warrantyEnabled', 'warranty_enabled']);
    final text =
        _field(item, const ['warranty', 'warranty_period', 'warrantyPeriod']);
    return _truthy(enabled) || _text(text).isNotEmpty;
  }

  dynamic _field(dynamic object, Iterable<String> keys) {
    if (object == null) return null;
    if (object is Map) {
      for (final key in keys) {
        if (object.containsKey(key)) return object[key];
        final found = object.keys.cast<dynamic>().firstWhere(
              (candidate) =>
                  candidate.toString().toLowerCase() == key.toLowerCase(),
              orElse: () => null,
            );
        if (found != null) return object[found];
      }
      return null;
    }
    for (final key in keys) {
      try {
        switch (key) {
          case 'displayName':
            final value = object.displayName;
            if (value != null) return value;
            break;
          case 'productName':
            final value = object.productName;
            if (value != null) return value;
            break;
          case 'product_name':
            final value = object.productName;
            if (value != null) return value;
            break;
          case 'quantity':
          case 'qty':
            final value = object.quantity;
            if (value != null) return value;
            break;
          case 'unitPrice':
          case 'unit_price':
          case 'price':
            final value = object.unitPrice;
            if (value != null) return value;
            break;
          case 'mrp':
          case 'maximum_retail_price':
            final value = object.mrp;
            if (value != null) return value;
            break;
          case 'totalPrice':
          case 'total_price':
          case 'amount':
          case 'total':
            final value = object.totalPrice;
            if (value != null) return value;
            break;
          case 'taxAmount':
          case 'tax_amount':
          case 'tax':
            final value = object.taxAmount;
            if (value != null) return value;
            break;
          case 'saleUnitName':
          case 'sale_unit_name':
            final value = object.saleUnitName;
            if (value != null) return value;
            break;
          case 'productUnit':
          case 'product_unit':
          case 'unit':
            final value = object.productUnit;
            if (value != null) return value;
            break;
          case 'formattedVariantAttributes':
            final value = object.formattedVariantAttributes;
            if (value != null) return value;
            break;
          case 'warrantyEnabled':
          case 'warranty_enabled':
            final value = object.warrantyEnabled;
            if (value != null) return value;
            break;
          case 'reason':
            final value = object.reason;
            if (value != null) return value;
            break;
          case 'warranty':
          case 'warranty_period':
          case 'warrantyPeriod':
            // These fields are present on some API map payloads only.
            break;
        }
      } catch (_) {
        // A different cart model is allowed to omit an optional field.
      }
    }
    return null;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    final raw =
        _clean(value).replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(raw) ?? 0;
  }

  double _rateExcTax(ReceiptLayoutParams params, dynamic item) {
    final explicit = _field(item, const [
      'rateExcTax',
      'rate_exc_tax',
      'unit_price_exc_tax',
      'unitPriceExcTax',
      'priceExcludingTax',
      'price_excluding_tax',
    ]);
    if (_clean(explicit).isNotEmpty) return _number(explicit);

    final unitPrice =
        _number(_field(item, const ['unitPrice', 'unit_price', 'price']));
    final tax = _number(_field(item, const ['taxAmount', 'tax_amount', 'tax']));
    if (tax == 0) return unitPrice;

    // LocalCartItem.taxAmount is calculated per unit. API line payloads use a
    // line tax total, so divide only the latter by quantity.
    final isLocal = params.isFromLocalStorage || item is! Map;
    final quantity = _number(_field(item, const ['quantity', 'qty']));
    final taxPerUnit = isLocal || quantity <= 0 ? tax : tax / quantity;
    return unitPrice - taxPerUnit;
  }

  String _money(dynamic value, String currency) {
    final amount = _number(value);
    final formatted = amount.toStringAsFixed(2);
    return currency.trim().isEmpty ? formatted : '$currency $formatted';
  }

  String _quantity(dynamic value) {
    final amount = _number(value);
    return amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _localizedField(dynamic source, Iterable<String> keys) {
    if (source is! Map) return '';
    for (final key in keys) {
      if (source.containsKey(key)) return _text(source[key]);
      final found = source.keys.cast<dynamic>().firstWhere(
            (candidate) =>
                candidate.toString().toLowerCase() == key.toLowerCase(),
            orElse: () => null,
          );
      if (found != null) return _text(source[found]);
    }
    return '';
  }

  String _firstText(Iterable<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  String _nonEmpty(String? value, String fallback) =>
      _clean(value).isEmpty ? fallback : _clean(value);

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = _clean(value).toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  String _bankArabicLabel(String english) =>
      const <String, String>{
        'Bank Name': 'اسم البنك',
        'Account Name': 'اسم الحساب',
        'Account Number': 'رقم الحساب',
        'IBAN': 'الآيبان',
        'SWIFT Code': 'رمز سويفت',
      }[english] ??
      english;
}

class _PdfColumn {
  final String key;
  final String heading;
  final String Function(dynamic item, int index) value;
  final int flex;

  const _PdfColumn({
    required this.key,
    required this.heading,
    required this.value,
    this.flex = 1,
  });
}

class _PdfFonts {
  final pw.TextStyle title;
  final pw.TextStyle section;
  final pw.TextStyle body;
  final pw.TextStyle bodyBold;
  final pw.TextStyle tableHeader;
  final pw.TextStyle small;

  _PdfFonts.from(pw.Font font, pw.Font bold)
      : title = pw.TextStyle(
            font: bold, fontSize: 16, fontWeight: pw.FontWeight.bold),
        section = pw.TextStyle(
            font: bold, fontSize: 11, fontWeight: pw.FontWeight.bold),
        body = pw.TextStyle(font: font, fontBold: bold, fontSize: 8.5),
        bodyBold = pw.TextStyle(
            font: bold, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        tableHeader = pw.TextStyle(
            font: bold,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
        small = pw.TextStyle(font: font, fontBold: bold, fontSize: 7);
}
