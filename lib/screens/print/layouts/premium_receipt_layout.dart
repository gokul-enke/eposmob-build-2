import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/models/payment_gateway.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:pos_machine/utils/zatca_qr_helper.dart';
import 'package:pos_machine/helpers/string_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import '../thermal/printer_utils.dart';

/// Premium receipt layout - Modern & Clean design.
///
/// This layout features:
/// - Generous whitespace between sections
/// - Thin solid line dividers
/// - Clean, centered header with balanced typography
/// - Bilingual support (English/Arabic) like the reference
/// - Streamlined totals section with clear hierarchy
/// - Minimal, elegant footer
class PremiumReceiptLayout implements ReceiptLayout {
  final ThermalPrinterUtils _printerUtils = ThermalPrinterUtils();

  // Premium theme spacing constants
  static const double _sectionGap = 20.0;
  static const double _itemGap = 8.0;
  static const double _headerGap = 15.0;

  @override
  String get layoutId => 'premium';

  @override
  String get displayName => 'Premium';

  @override
  Future<void> printThermal(ReceiptLayoutParams params) async {
    debugPrint("===== PREMIUM LAYOUT: THERMAL PRINTING ====");

    final context = params.context;
    final selectedPrinter = params.selectedPrinter;
    final billDocumentConfig = params.billDocumentConfig;
    final displayConfig = params.displayConfig;

    debugPrint(
        "Printer: ${selectedPrinter.deviceName}, Paper: ${params.selectedPaperSize}");

    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    try {
      debugPrint("Connecting to printer...");
      await _printerUtils.connectToPrinter(selectedPrinter);
      debugPrint("Connected successfully.");

      // Determine language direction
      final isEnglish = params.isEnglish;
      final isBilingual = params.isBilingual;
      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : (isBilingual ? 'Bilingual' : 'Arabic')} ($textDirection)");

      // Setup print parameters
      final double printWidth = params.printWidth;
      final double baseFontSize = params.baseFontSize;

      // Build receipt rows
      List<ReceiptRow> part1Rows = [];
      List<ReceiptRow> part2Rows = [];

      // ========== LOGO SECTION ==========
      if (billDocumentConfig.showLogo == 1) {
        try {
          ui.Image? logo;
          if (billDocumentConfig.logo != null &&
              billDocumentConfig.logo.toString().isNotEmpty) {
            logo =
                await _fetchNetworkUiImage(billDocumentConfig.logo.toString());
          }

          if (logo != null) {
            debugPrint(
                "[PREMIUM] Logo loaded: ${logo.width}x${logo.height}");
            part1Rows.add(ImageRow(logo, width: printWidth * 0.6));
            part1Rows.add(SpacingRow(_headerGap));
          }
        } catch (e) {
          debugPrint("[PREMIUM] Error loading logo: $e");
        }
      }

      // ========== HEADER SECTION (Modern & Clean) ==========
      _buildHeaderSection(part1Rows, params, displayConfig, appSettings);

      // ========== CUSTOMER SECTION ==========
      _buildCustomerSection(part1Rows, params, displayConfig, isEnglish);

      // ========== CART ITEMS SECTION ==========
      _buildCartItemsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== TOTALS SECTION (Bilingual Style) ==========
      _buildTotalsSection(part1Rows, params, displayConfig, isEnglish);

      // ========== FOOTER SECTION (Part 2) ==========
      _buildFooterSection(part2Rows, params, displayConfig, isEnglish, context);

      // ========== RENDER IMAGES ==========
      debugPrint("Rendering premium receipt images...");

      final img.Image imagePart1 =
          await ArabicPrinterHelper.renderReceiptToImage(
        rows: part1Rows,
        width: printWidth,
        fontSize: baseFontSize,
        textDirection: textDirection,
      );

      final img.Image imagePart2 =
          await ArabicPrinterHelper.renderReceiptToImage(
        rows: part2Rows,
        width: printWidth,
        fontSize: baseFontSize,
        textDirection: textDirection,
      );

      // ========== GENERATE ESC/POS BYTES ==========
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          params.is58mm ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.image(imagePart1);
      bytes += generator.image(imagePart2);

      // Native barcode
      String cleanOrderNumber =
          params.orderNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
      if (cleanOrderNumber.isNotEmpty) {
        try {
          List<String> code39Data = cleanOrderNumber.split("");
          bytes += generator.barcode(
            Barcode.code39(code39Data),
            width: 2,
            height: 50,
            textPos: BarcodeText.none,
            align: PosAlign.center,
          );
        } catch (e) {
          debugPrint("Barcode error: $e");
        }
      }

      bytes += generator.feed(2);
      bytes += generator.drawer();
      bytes += generator.cut();

      // ========== SEND TO PRINTER ==========
      debugPrint("Sending ${bytes.length} bytes to printer...");
      final printerManager = PrinterManager.instance;
      await printerManager.send(type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print job sent successfully.");

      if (context.mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR in Premium Layout Print: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (context.mounted) {
        showScaffoldError(
            context: context, message: "Error printing: ${e.toString()}");
      }
    } finally {
      debugPrint("Disconnecting from printer...");
      await _printerUtils.disconnectPrinter(selectedPrinter);
      debugPrint("===== END PREMIUM LAYOUT PRINTING =====");
    }
  }

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) async {
    debugPrint("[PremiumReceiptLayout] buildPdf - delegating to StandardPrinter");
    return pw.Document();
  }

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) async {
    await printThermal(params);
  }

  // ==================== HEADER SECTION (Modern & Clean) ====================

  void _buildHeaderSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    dynamic appSettings,
  ) {
    final billDocumentConfig = params.billDocumentConfig;

    // Store Name - Large, centered, clean
    if (displayConfig?['showStoreName']?.visible == true) {
      final storeName = displayConfig?['showStoreName']?.value as String? ??
          billDocumentConfig.header ??
          'STORE NAME';

      // Dynamic scaling based on name length
      double storeNameScale = 1.8;
      if (storeName.length > 20) {
        storeNameScale = 1.3;
      } else if (storeName.length > 14) {
        storeNameScale = 1.5;
      }

      rows.add(TextRow(storeName.toUpperCase(),
          isBold: true, scale: storeNameScale));
    }

    // Description/Subheader - Arabic subtitle style
    if (displayConfig?['showDescription']?.visible == true) {
      final description =
          displayConfig?['showDescription']?.value as String? ??
              billDocumentConfig.subheader ??
              '';
      if (description.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(description, scale: 1.0));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Address - Clean, smaller text
    if (displayConfig?['showStoreAddress']?.visible == true) {
      final storeAddress =
          displayConfig?['showStoreAddress']?.value as String?;
      if (storeAddress != null && storeAddress.isNotEmpty) {
        rows.add(TextRow(storeAddress, scale: 0.85));
      }
    }

    // Location info (like "Al Qasim, Saudi Arabia" in reference)
    if (displayConfig?['showFssaiInfo']?.visible == true) {
      final fssaiInfo = displayConfig?['showFssaiInfo']?.value as String?;
      if (fssaiInfo != null && fssaiInfo.isNotEmpty) {
        rows.add(TextRow(fssaiInfo, scale: 0.85));
      }
    }

    // Contact info
    if (displayConfig?['showTel']?.visible == true) {
      final telephone = displayConfig?['showTel']?.value as String? ??
          appSettings?.customerCarePhone ??
          '';
      if (telephone.isNotEmpty) {
        rows.add(SpacingRow(5));
        rows.add(TextRow(telephone, scale: 0.8));
      }
    }

    if (displayConfig?['showEmail']?.visible == true) {
      final email = displayConfig?['showEmail']?.value as String? ??
          appSettings?.customerCareEmail ??
          '';
      if (email.isNotEmpty) {
        rows.add(TextRow(email, scale: 0.8));
      }
    }

    rows.add(SpacingRow(_sectionGap));

    // Thin divider line
    rows.add(ThinDividerRow());

    rows.add(SpacingRow(_itemGap));

    // Invoice Title
    if (displayConfig?['showInvoiceTitle']?.visible == true) {
      final invoiceTitle =
          displayConfig?['showInvoiceTitle']?.value as String? ??
              billDocumentConfig.header ??
              appSettings?.printTitle ??
              'INVOICE';
      rows.add(TextRow(invoiceTitle.toUpperCase(), isBold: true, scale: 1.1));
    }

    // Invoice Number - Clean format
    if (displayConfig?['showInvoiceNumber']?.visible == true) {
      final invoiceNumberText = billDocumentConfig.numberPrefix != null &&
              billDocumentConfig.numberPrefix!.isNotEmpty
          ? '${billDocumentConfig.numberPrefix}${params.orderNumber}'
          : '#${params.orderNumber}';
      rows.add(TextRow(invoiceNumberText, scale: 0.9));
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
  }

  // ==================== CUSTOMER SECTION ====================

  void _buildCustomerSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    if (params.customerName == null && params.customerPhone == null) {
      return;
    }

    final customerLabel = isEnglish ? "Customer" : "العميل";
    final phoneLabel = isEnglish ? "Phone" : "الهاتف";
    final paymentLabel = isEnglish ? "Payment" : "الدفع";

    // Clean two-column layout
    if (params.customerName != null && params.customerName!.isNotEmpty) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(customerLabel,
            weight: 0.35, align: TextAlign.left, isBold: true),
        ReceiptTableColumn(params.customerName!,
            weight: 0.65, align: TextAlign.right),
      ]));
    }

    if (params.customerPhone != null && params.customerPhone!.isNotEmpty) {
      final bool maskPhone =
          displayConfig?['maskCustomerPhone']?.visible ?? false;
      final String displayedPhone = maskPhone
          ? StringHelper.maskStringShowLast4(params.customerPhone!)
          : params.customerPhone!;

      rows.add(ReceiptTableRow([
        ReceiptTableColumn(phoneLabel,
            weight: 0.35, align: TextAlign.left, isBold: true),
        ReceiptTableColumn(displayedPhone,
            weight: 0.65, align: TextAlign.right),
      ]));
    }

    if (params.paymentMethod != null && params.paymentMethod!.isNotEmpty) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(paymentLabel,
            weight: 0.35, align: TextAlign.left, isBold: true),
        ReceiptTableColumn(params.paymentMethod!,
            weight: 0.65, align: TextAlign.right),
      ]));
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));
  }

  // ==================== CART ITEMS SECTION ====================

  void _buildCartItemsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    final resolvedLabels = params.billDocumentConfig.resolvedLabels;

    // Build items with clean layout
    for (var i = 0; i < params.cartItems.length; i++) {
      _buildCartItemRow(rows, params.cartItems[i], i, params.isFromLocalStorage,
          displayConfig, isEnglish);
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
  }

  void _buildCartItemRow(
    List<ReceiptRow> rows,
    dynamic item,
    int index,
    bool isFromLocalStorage,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    String productName = '';
    String quantity = '';
    String unitPrice = '';
    String totalPrice = '';

    if (isFromLocalStorage) {
      productName = item['productName'] ?? '';
      quantity = item['quantity'] ?? '0';
      unitPrice =
          (double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      totalPrice =
          (double.tryParse(item['totalPrice']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    } else {
      productName = item.productName ?? '';
      quantity = item.quantity?.toString() ?? '0';
      unitPrice =
          (double.tryParse(item.unitPrice?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      totalPrice =
          (double.tryParse(item.totalPrice?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
    }

    // Premium style: Product name with quantity x price = total
    String slNumber = (index + 1).toString();
    
    // Item name row
    rows.add(ReceiptTableRow([
      ReceiptTableColumn('$slNumber. $productName',
          weight: 1.0, align: TextAlign.left),
    ]));

    // Quantity x Price = Total row (indented)
    rows.add(ReceiptTableRow([
      ReceiptTableColumn('   $quantity x $unitPrice',
          weight: 0.6, align: TextAlign.left),
      ReceiptTableColumn(totalPrice,
          weight: 0.4, align: TextAlign.right, isBold: true),
    ]));

    rows.add(SpacingRow(4));
  }

  // ==================== TOTALS SECTION (Bilingual Style) ====================

  void _buildTotalsSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    rows.add(SpacingRow(_itemGap));

    double saved = double.tryParse(params.savedTotal ?? '0.0') ?? 0.0;
    double total = double.tryParse(params.formattedTotal) ?? 0.0;
    double discountAmountValue =
        double.tryParse(params.discountAmount ?? '0.0') ?? 0.0;
    double taxAmount = params.totalTax;

    // Calculate subtotal (total + discount - already included in total logic)
    double subtotal = total + discountAmountValue;

    // Bilingual labels like the reference image
    // "SUBTOTAL المجموع"
    final subtotalLabel = isEnglish ? "SUBTOTAL" : "SUBTOTAL المجموع";
    final discountLabel = isEnglish ? "DISCOUNTS" : "DISCOUNTS الخصم";
    final vatLabel = "15.0% VAT 15%"; // Or use actual tax rate
    final taxLabelBilingual = isEnglish ? "TAX" : "الضريبة";
    final grandTotalLabel = isEnglish ? "GRAND TOTAL" : "GRAND TOTAL المبلغ الاجمالي";

    // Get actual tax percentage from config if available
    String taxPercentageLabel = taxLabelBilingual;
    
    // Subtotal row
    rows.add(ReceiptTableRow([
      ReceiptTableColumn(subtotalLabel,
          weight: 0.65, align: TextAlign.right),
      ReceiptTableColumn(subtotal.toStringAsFixed(2),
          weight: 0.35, align: TextAlign.left),
    ]));

    // Discounts row (if any)
    if (discountAmountValue > 0) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(discountLabel,
            weight: 0.65, align: TextAlign.right),
        ReceiptTableColumn(discountAmountValue.toStringAsFixed(2),
            weight: 0.35, align: TextAlign.left),
      ]));
    }

    // VAT/Tax row
    rows.add(ReceiptTableRow([
      ReceiptTableColumn(taxPercentageLabel,
          weight: 0.65, align: TextAlign.right),
      ReceiptTableColumn(taxAmount.toStringAsFixed(2),
          weight: 0.35, align: TextAlign.left),
    ]));

    rows.add(SpacingRow(5));
    rows.add(DottedDividerRow());
    rows.add(SpacingRow(5));

    // Grand Total - Prominent
    rows.add(ReceiptTableRow([
      ReceiptTableColumn(grandTotalLabel,
          weight: 0.65, align: TextAlign.right, isBold: true),
      ReceiptTableColumn(total.toStringAsFixed(2),
          weight: 0.35, align: TextAlign.left, isBold: true),
    ]));

    rows.add(SpacingRow(5));
    rows.add(DottedDividerRow());

    // Payment details (Cash, Change) like reference
    if (params.paidAmount != null) {
      rows.add(SpacingRow(_itemGap));
      rows.add(ReceiptTableRow([
        ReceiptTableColumn("Cash",
            weight: 0.65, align: TextAlign.right),
        ReceiptTableColumn(params.paidAmount!.toStringAsFixed(2),
            weight: 0.35, align: TextAlign.left),
      ]));

      // Calculate change
      double change = params.paidAmount! - total;
      if (change >= 0) {
        final changeLabel = isEnglish ? "CHANGE" : "CHANGE متبقي";
        rows.add(ReceiptTableRow([
          ReceiptTableColumn(changeLabel,
              weight: 0.65, align: TextAlign.right),
          ReceiptTableColumn(change.toStringAsFixed(2),
              weight: 0.35, align: TextAlign.left),
        ]));
      }
    }

    // Amount in Words
    if (displayConfig?['showAmountInWords']?.visible == true) {
      rows.add(SpacingRow(_itemGap));
      final amountInWords =
          '${AmountHelper().convertNumberToWords(total)} Only.';
      rows.add(TextRow(amountInWords, scale: 0.85, isBold: true));
    }

    // Customer Balance
    _buildCustomerBalance(rows, params, displayConfig, isEnglish);

    rows.add(SpacingRow(_sectionGap));
  }

  void _buildCustomerBalance(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
  ) {
    if (params.customerOldBalance == null &&
        params.customerCurrentBalance == null) {
      return;
    }

    rows.add(SpacingRow(_itemGap));
    rows.add(ThinDividerRow());
    rows.add(SpacingRow(_itemGap));

    final prevBalanceLabel = isEnglish ? "Previous Balance" : "الرصيد السابق";
    final currentBalanceLabel = isEnglish ? "Current Balance" : "الرصيد الحالي";

    if (params.customerOldBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(prevBalanceLabel,
            weight: 0.6, align: TextAlign.right),
        ReceiptTableColumn(params.customerOldBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.left),
      ]));
    }

    if (params.customerCurrentBalance != null) {
      rows.add(ReceiptTableRow([
        ReceiptTableColumn(currentBalanceLabel,
            weight: 0.6, align: TextAlign.right, isBold: true),
        ReceiptTableColumn(params.customerCurrentBalance!.toStringAsFixed(2),
            weight: 0.4, align: TextAlign.left, isBold: true),
      ]));
    }
  }

  // ==================== FOOTER SECTION ====================

  void _buildFooterSection(
    List<ReceiptRow> rows,
    ReceiptLayoutParams params,
    Map<String, DisplayOption>? displayConfig,
    bool isEnglish,
    BuildContext context,
  ) {
    rows.add(SpacingRow(_sectionGap));

    // QR Code - Use ZATCA QR if credentials available, otherwise fallback to payment QR
    if (displayConfig?['showQRCode']?.visible == true) {
      String qrData = '';
      String qrMessage = '';

      // Check if ZATCA credentials are available for Saudi Arabia e-invoicing
      if (params.hasZatcaCredentials) {
        debugPrint('[PremiumLayout] ZATCA credentials found, generating ZATCA QR');
        
        // Generate ZATCA Phase 1 compliant QR code
        final zatcaHelper = ZatcaQrHelper();
        qrData = zatcaHelper.generateQrForInvoice(
          sellerName: params.zatcaCompanyName,
          vatNumber: params.zatcaVatNumber,
          invoiceDate: params.orderDate,
          totalAmount: params.totalAmountAsDouble,
          vatAmount: params.totalTax,
        );
        
        qrMessage = isEnglish 
            ? 'ZATCA E-Invoice QR' 
            : 'فاتورة الكترونية';
        
        debugPrint('[PremiumLayout] ZATCA QR generated: ${qrData.isNotEmpty}');
      } else {
        debugPrint('[PremiumLayout] No ZATCA credentials, using payment QR');
        
        // Fallback to payment gateway QR
        final paymentGatewaysProvider =
            Provider.of<PaymentGatewaysProvider>(context, listen: false);
        final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
            .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY",
                orElse: () => PaymentGateway(
                      id: 0,
                      name: "",
                      code: "",
                      label: "",
                      link: "",
                      image: "",
                      status: "",
                      isWebActive: 0,
                      isAndroidActive: 0,
                      isIosActive: 0,
                      contactEmail: "",
                      contactPhone: "",
                      createdAt: "",
                      updatedAt: "",
                    ));

        qrData = manualPaymentGateway.link;
        if (qrData.isNotEmpty) {
          if (qrData.contains('{formattedTotal}') ||
              qrData.contains('{orderNumber}')) {
            qrData = qrData
                .replaceAll('{formattedTotal}', params.formattedTotal)
                .replaceAll('{orderNumber}', params.orderNumber);
          } else if (qrData.contains('@')) {
            qrData =
                'upi://pay?pa=$qrData&am=${params.formattedTotal}&tn=${params.orderNumber}&cu=INR';
          }
        }

        qrMessage = displayConfig?['showQRCode']?.value as String? ??
            (isEnglish ? 'Scan to Pay' : 'امسح للدفع');
      }

      // Display QR code if data is available
      if (qrData.isNotEmpty) {
        rows.add(TextRow(qrMessage, scale: 0.9));
        rows.add(SpacingRow(5));
        rows.add(QrRow(qrData, size: 220));
        
        // Show VAT number below QR for ZATCA receipts
        if (params.hasZatcaCredentials && params.zatcaVatNumber != null) {
          rows.add(SpacingRow(5));
          final vatLabel = isEnglish ? 'VAT No:' : 'الرقم الضريبي:';
          rows.add(TextRow('$vatLabel ${params.zatcaVatNumber}', scale: 0.8));
        }
      }
    }

    rows.add(SpacingRow(_headerGap));

    // Date and Time - Clean format
    String formattedDate = params.isFromLocalStorage
        ? DateHelper.formatToISODateOnlyFromISO(params.orderDate)
        : DateHelper.formatISODate(params.orderDate);
    String formattedTime = params.isFromLocalStorage
        ? DateHelper.formatToISOTimeOnlyFromISO(params.orderDate)
        : DateHelper.formatISOTimeOnlyToIST(params.orderDate);

    rows.add(TextRow("$formattedDate  $formattedTime", scale: 0.85));
    rows.add(SpacingRow(3));
    rows.add(TextRow('#${params.orderNumber}', scale: 0.8));

    rows.add(SpacingRow(_itemGap));

    // Terms & Conditions
    if (displayConfig?['showTermsConditions']?.visible == true) {
      String? terms = displayConfig?['showTermsConditions']?.value as String?;
      if (terms == null || terms.trim().isEmpty) {
        terms = params.billDocumentConfig.terms;
      }
      if (terms != null && terms.trim().isNotEmpty) {
        rows.add(TextRow(terms.trim(), scale: 0.75));
      }
    }

    rows.add(SpacingRow(_itemGap));

    // Thank You Message - Elegant
    if (displayConfig?['showThankYouMessage']?.visible == true) {
      final String defaultThankYou =
          isEnglish ? 'Thank You for Your Visit!' : 'شكراً لزيارتكم!';
      final message =
          (displayConfig?['showThankYouMessage']?.value as String?)
                      ?.isNotEmpty ==
                  true
              ? displayConfig!['showThankYouMessage']!.value as String
              : (params.billDocumentConfig.footer?.isNotEmpty == true
                  ? params.billDocumentConfig.footer!
                  : defaultThankYou);
      rows.add(TextRow(message, isBold: true, scale: 0.95));
    }

    rows.add(SpacingRow(_sectionGap));
  }

  // ==================== UTILITY METHODS ====================

  Future<ui.Image?> _fetchNetworkUiImage(String? url) async {
    if (url == null || url.isEmpty) return null;

    String fullUrl;
    if (url.startsWith('http')) {
      fullUrl = url;
    } else if (url.startsWith('logos/')) {
      fullUrl = '${APPUrl.baseURL}/storage/$url';
    } else {
      fullUrl = url.startsWith('/')
          ? '${APPUrl.baseURL}$url'
          : '${APPUrl.baseURL}/$url';
    }

    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final fi = await codec.getNextFrame();
        return fi.image;
      }
    } catch (e) {
      debugPrint("[PremiumReceiptLayout] Error fetching image: $e");
    }
    return null;
  }
}

/// Thin solid line divider for Premium theme
class ThinDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y + 3), Offset(width, y + 3), paint);
  }
}

/// Dotted divider for emphasis sections
class DottedDividerRow extends ReceiptRow {
  @override
  double calculateHeight(
          double width, double fontSize, TextDirection textDirection) =>
      6;

  @override
  void render(Canvas canvas, double y, double width, double fontSize,
      TextDirection textDirection) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    
    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double currentX = 0;
    
    while (currentX < width) {
      canvas.drawLine(
        Offset(currentX, y + 3),
        Offset(currentX + dashWidth, y + 3),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }
}
