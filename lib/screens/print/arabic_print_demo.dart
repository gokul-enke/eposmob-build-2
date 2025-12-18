import 'package:flutter/material.dart' hide TableRow;
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/utils/arabic_printer_helper.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:image/image.dart' as img;

class ArabicPrintDemo {
  static Future<void> printDemoReceipt({
    required BluetoothPrinter selectedPrinter,
    required String paperSize,
  }) async {
    debugPrint("--- Starting Arabic Print Demo ---");
    debugPrint("Printer: ${selectedPrinter.deviceName}, Paper: $paperSize");

    final printerManager = PrinterManager.instance;

    try {
      // 1. Connect to Printer
      debugPrint("Connecting to printer...");
      if (selectedPrinter.typePrinter == PrinterType.usb) {
        await printerManager.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: selectedPrinter.deviceName ?? 'Unknown',
            productId: selectedPrinter.productId,
            vendorId: selectedPrinter.vendorId,
          ),
        );
      } else if (selectedPrinter.typePrinter == PrinterType.bluetooth) {
        if (selectedPrinter.address == null) {
          throw Exception('Bluetooth printer address is null');
        }
        await printerManager.connect(
          type: PrinterType.bluetooth,
          model: BluetoothPrinterInput(
            name: selectedPrinter.deviceName ?? 'Unknown',
            address: selectedPrinter.address!,
            isBle: false,
          ),
        );
      }
      debugPrint("Connected successfully.");

      // Check Language
      final isEnglish = LocalizationService.locale.languageCode == 'en';
      final textDirection = isEnglish ? TextDirection.ltr : TextDirection.rtl;
      debugPrint(
          "Language: ${isEnglish ? 'English' : 'Arabic'} ($textDirection)");

      // 2. Prepare Rows (Parts)
      List<ReceiptRow> part1Rows;
      List<ReceiptRow> part2Rows;

      if (isEnglish) {
        // --- ENGLISH DEMO ---
        part1Rows = [
          // Store Header
          TextRow("EPOS Sample Store", isBold: true, scale: 2.0),
          TextRow("Trade Center, 1st Floor", scale: 0.9),
          TextRow("Medina, Saudi Arabia", scale: 0.9),
          TextRow("Tel: +966500000000 | Email: support@epos.com", scale: 0.8),
          TextRow("VAT Number: 300000000000003", isBold: true, scale: 0.9),
          SpacingRow(10),
          TextRow("SIMPLIFIED TAX INVOICE", isBold: true, scale: 1.2),
          TextRow("Invoice No: #INV-2023-12-001", isBold: true),
          DividerRow(),

          // Customer Details
          ReceiptTableRow([
            ReceiptTableColumn("Customer:",
                weight: 0.35, align: TextAlign.left, isBold: true),
            ReceiptTableColumn("Muhammed Abdullah",
                weight: 0.65, align: TextAlign.left),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("Phone:",
                weight: 0.35, align: TextAlign.left, isBold: true),
            ReceiptTableColumn("0501234567",
                weight: 0.65, align: TextAlign.left),
          ]),
          DividerRow(),

          // Table Header - Adjusted weights to prevent wrapping
          ReceiptTableRow([
            ReceiptTableColumn("Item",
                weight: 0.40, align: TextAlign.left, isBold: true),
            ReceiptTableColumn("MRP",
                weight: 0.15, align: TextAlign.center, isBold: true),
            ReceiptTableColumn("Qty",
                weight: 0.10, align: TextAlign.center, isBold: true),
            ReceiptTableColumn("Rate",
                weight: 0.15, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("Total",
                weight: 0.20, align: TextAlign.right, isBold: true),
          ]),
          DividerRow(),

          // Item 1
          ReceiptTableRow([
            ReceiptTableColumn("1. Premium Arabic Coffee - Special Blend",
                weight: 1.0, align: TextAlign.left),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("", weight: 0.40),
            ReceiptTableColumn("60.00", weight: 0.15, align: TextAlign.center),
            ReceiptTableColumn("2", weight: 0.10, align: TextAlign.center),
            ReceiptTableColumn("50.00", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("100.00", weight: 0.20, align: TextAlign.right),
          ]),

          // Item 2
          ReceiptTableRow([
            ReceiptTableColumn("2. Sukari Dates Premium - 1Kg",
                weight: 1.0, align: TextAlign.left),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("", weight: 0.40),
            ReceiptTableColumn("20.00", weight: 0.15, align: TextAlign.center),
            ReceiptTableColumn("3", weight: 0.10, align: TextAlign.center),
            ReceiptTableColumn("15.00", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("45.00", weight: 0.20, align: TextAlign.right),
          ]),
          SpacingRow(5),
          DividerRow(),

          // Summary Section
          ReceiptTableRow([
            ReceiptTableColumn("Items:", weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn("2", weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.05),
            ReceiptTableColumn("Discount:",
                weight: 0.25, align: TextAlign.right),
            ReceiptTableColumn("0.00", weight: 0.20, align: TextAlign.right),
          ]),

          ReceiptTableRow([
            ReceiptTableColumn("Total Qty:",
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn("5", weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.50),
          ]),

          ReceiptTableRow([
            ReceiptTableColumn("Total MRP:",
                weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn("160.00", weight: 0.25, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.50),
          ]),
          SpacingRow(5),

          // Net Total
          ReceiptTableRow([
            ReceiptTableColumn("Net Total:",
                weight: 0.5, align: TextAlign.center, isBold: true),
            ReceiptTableColumn("145.00",
                weight: 0.5, align: TextAlign.center, isBold: true),
          ]),
          SpacingRow(5),

          TextRow("You Saved: 15.00 SAR", isBold: true, scale: 0.9),
          DividerRow(),

          TextRow("One Hundred Forty Five Riyals Only",
              scale: 0.9, isBold: true),
          DividerRow(),

          // Customer Balance
          ReceiptTableRow([
            ReceiptTableColumn("Old Balance:",
                weight: 0.5, align: TextAlign.left),
            ReceiptTableColumn("1000.00", weight: 0.5, align: TextAlign.right),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("Paid Amount:",
                weight: 0.5, align: TextAlign.left),
            ReceiptTableColumn("145.00", weight: 0.5, align: TextAlign.right),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("Current Balance:",
                weight: 0.5, align: TextAlign.left, isBold: true),
            ReceiptTableColumn("1145.00",
                weight: 0.5, align: TextAlign.right, isBold: true),
          ]),
          SpacingRow(10),
        ];

        // Part 2 (Footer)
        part2Rows = [
          SpacingRow(10),
          TextRow("Scan to Pay", isBold: true, scale: 0.9),
          QrRow("https://epos.com/pay/inv/123",
              size: 200), // Render QR as Image
          SpacingRow(15),

          ReceiptTableRow([
            ReceiptTableColumn("Date:", weight: 0.5, align: TextAlign.left),
            ReceiptTableColumn("18-12-2023 02:30 PM",
                weight: 0.5, align: TextAlign.right),
          ]),
          SpacingRow(5),

          // Barcode Placeholder
          TextRow("#INV-2023-12-001", scale: 0.8),
          SpacingRow(5),

          TextRow("Terms & Conditions Apply", scale: 0.8),
          TextRow("Billed by: Admin", scale: 0.8),
          SpacingRow(5),
          TextRow("Thank You! Visit Again", isBold: true),
          SpacingRow(20),
        ];
      } else {
        // --- ARABIC DEMO (Existing) ---
        debugPrint("Preparing Arabic receipt parts...");

        // --- PART 1: Header, Customer, Cart, Totals ---
        part1Rows = [
          // Store Header (Centered)
          TextRow("متجر إي بوز العينة", isBold: true, scale: 2.0),
          TextRow("مركز التجارة، الطابق الأول", scale: 0.9),
          TextRow("المدينة المنورة، المملكة العربية السعودية", scale: 0.9),
          TextRow("هاتف: 966500000000+ | البريد: support@epos.com", scale: 0.8),
          TextRow("الرقم الضريبي: 300000000000003", isBold: true, scale: 0.9),
          SpacingRow(10),
          TextRow("فاتورة ضريبية مبسطة", isBold: true, scale: 1.2),
          TextRow("رقم الفاتورة: #INV-2023-12-001", isBold: true),
          DividerRow(),

          // Customer Details (Left aligned usually, but centered looks good too for simple receipts)
          // Using Table for Label: Value structure for alignment
          ReceiptTableRow([
            ReceiptTableColumn("محمد عبد الله",
                weight: 0.7, align: TextAlign.right),
            ReceiptTableColumn("العميل:",
                weight: 0.3, align: TextAlign.left, isBold: true),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("0501234567",
                weight: 0.7, align: TextAlign.right),
            ReceiptTableColumn("الهاتف:",
                weight: 0.3, align: TextAlign.left, isBold: true),
          ]),
          DividerRow(),

          // Table Header
          ReceiptTableRow([
            ReceiptTableColumn("الإجمالي",
                weight: 0.2, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("السعر",
                weight: 0.2, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("الكمية",
                weight: 0.15, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("MRP",
                weight: 0.15, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("الصنف",
                weight: 0.3, align: TextAlign.right, isBold: true),
          ]),
          DividerRow(),

          // Item 1
          ReceiptTableRow([
            ReceiptTableColumn("1. قهوة عربية فاخرة - خلطة خاصة",
                weight: 1.0, align: TextAlign.right),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("100.00", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("50.00", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("2", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("60.00", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("", weight: 0.3),
          ]),

          // Item 2
          ReceiptTableRow([
            ReceiptTableColumn("2. تمر سكري درجة أولى - 1 كجم",
                weight: 1.0, align: TextAlign.right),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("45.00", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("15.00", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("3", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("20.00", weight: 0.15, align: TextAlign.right),
            ReceiptTableColumn("", weight: 0.3),
          ]),
          SpacingRow(5),
          DividerRow(),

          // Total Amount Summary (Left and Right columns with Gap)

          // Row 1: Items & Discount
          ReceiptTableRow([
            ReceiptTableColumn("0.00", weight: 0.25, align: TextAlign.right),
            ReceiptTableColumn(":الخصم", weight: 0.25, align: TextAlign.left),

            ReceiptTableColumn(" ", weight: 0.05), // Gap

            ReceiptTableColumn("2", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("الأصناف:", weight: 0.25, align: TextAlign.left),
          ]),

          // Row 2: Total Qty
          ReceiptTableRow([
            ReceiptTableColumn(" ", weight: 0.5), // Empty Left

            ReceiptTableColumn(" ", weight: 0.05), // Gap

            ReceiptTableColumn("5", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("إجمالي الكمية:",
                weight: 0.25, align: TextAlign.left),
          ]),

          // Row 3: Total MRP
          ReceiptTableRow([
            ReceiptTableColumn(" ", weight: 0.5), // Empty Left
            ReceiptTableColumn(" ", weight: 0.05), // Gap
            ReceiptTableColumn("160.00", weight: 0.2, align: TextAlign.right),
            ReceiptTableColumn("إجمالي MRP:",
                weight: 0.25, align: TextAlign.left),
          ]),
          SpacingRow(5),

          // Net Total
          ReceiptTableRow([
            ReceiptTableColumn("145.00",
                weight: 0.5, align: TextAlign.center, isBold: true), // Value
            ReceiptTableColumn("الإجمالي الصافي:",
                weight: 0.5, align: TextAlign.center, isBold: true), // Label
          ]),
          SpacingRow(5),

          // You Saved
          TextRow("لقد وفرت: 15.00 ريال", isBold: true, scale: 0.9),
          DividerRow(),

          // Amount in Words
          TextRow("فقط مائة وخمسة وأربعون ريال لا غير",
              scale: 0.9, isBold: true),
          DividerRow(),

          // Customer Balance
          ReceiptTableRow([
            ReceiptTableColumn("1000.00", weight: 0.3, align: TextAlign.right),
            ReceiptTableColumn("الرصيد السابق:",
                weight: 0.3, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.4),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("145.00", weight: 0.3, align: TextAlign.right),
            ReceiptTableColumn("المدفوع:", weight: 0.3, align: TextAlign.left),
            ReceiptTableColumn(" ", weight: 0.4),
          ]),
          ReceiptTableRow([
            ReceiptTableColumn("1145.00",
                weight: 0.3, align: TextAlign.right, isBold: true),
            ReceiptTableColumn("الرصيد الحالي:",
                weight: 0.3, align: TextAlign.left, isBold: true),
            ReceiptTableColumn(" ", weight: 0.4),
          ]),
          SpacingRow(10),
        ];

        // --- PART 2: Footer (After QR Code) ---
        part2Rows = [
          SpacingRow(10),
          TextRow("امسح الرمز للدفع", isBold: true, scale: 0.9),
          QrRow("https://epos.com/pay/inv/123",
              size: 200), // Render QR as Image
          SpacingRow(15), // Space for text reference of QR

          // Date Time
          ReceiptTableRow([
            ReceiptTableColumn("18-12-2023 02:30 PM",
                weight: 0.5, align: TextAlign.right),
            ReceiptTableColumn("التاريخ:", weight: 0.5, align: TextAlign.left),
          ]),
          SpacingRow(5),

          // Barcode Placeholder Text (Barcode will be actual command)
          TextRow("#INV-2023-12-001", scale: 0.8),
          SpacingRow(5),

          // Terms
          TextRow("تطبق الشروط والأحكام", scale: 0.8),
          TextRow("Billed by: Admin", scale: 0.8),
          SpacingRow(5),

          TextRow("شكراً لزيارتكم! نأمل رؤيتكم قريباً", isBold: true),
          SpacingRow(20),
        ];
      }

      // 3. Render Images
      debugPrint("Rendering receipt images...");
      final double printWidth = paperSize == '58mm' ? 384.0 : 576.0;
      final double baseFontSize = 20.0;

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

      // 4. Generate ESC/POS bytes (Interleaved)
      debugPrint("Generating ESC/POS bytes...");
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      // -- Print Part 1 (Image) --
      bytes += generator.image(imagePart1);

      // -- Print Part 2 (Footer Image) --
      bytes += generator.image(imagePart2);

      // -- Print Barcode (Native Command) --
      // Extract invoice number
      // Extract invoice number using Regex for reliability
      String barcodeData = "12345";
      try {
        final invoiceRow = part1Rows.firstWhere(
          (r) => r is TextRow && (r as TextRow).text.contains("INV"),
          orElse: () => TextRow("INV: 12345"),
        ) as TextRow;

        final RegExp regExp = RegExp(r'INV-[0-9-]+');
        final match = regExp.firstMatch(invoiceRow.text);
        if (match != null) {
          barcodeData = match.group(0) ?? "12345";
        }
      } catch (e) {
        debugPrint("Error extracting barcode data: $e");
      }

      // Use CODE39 (Same as print_thermal.dart)
      try {
        // Sanitize for CODE39: '0'–'9', A–Z, SP, $, %, *, +, -, ., /
        String cleanBarcodeData = barcodeData
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9\-\ \$\%\*\+\.\/]'), '');

        if (cleanBarcodeData.isNotEmpty) {
          List<String> code39Data = cleanBarcodeData.split("");

          bytes += generator.barcode(Barcode.code39(code39Data),
              width: 2, // Increased width to 2 for better spacing
              height: 50, // Reduced height as requested
              textPos: BarcodeText.none,
              align: PosAlign.center);
        }
      } catch (e) {
        debugPrint("Error generating barcode: $e. Using text fallback.");
        bytes += generator.text(barcodeData,
            styles: PosStyles(align: PosAlign.center));
      }

      // Feed and Cut
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 5. Send to Printer
      debugPrint("Sending bytes to printer (${bytes.length} bytes)...");
      await printerManager.send(
          type: selectedPrinter.typePrinter, bytes: bytes);
      debugPrint("Print command sent successfully.");

      // 6. Disconnect
      debugPrint("Disconnecting...");
      await printerManager.disconnect(type: selectedPrinter.typePrinter);
      debugPrint("Disconnected.");
      debugPrint("--- Arabic Print Demo Finished ---");
    } catch (e, stacktrace) {
      debugPrint("ERROR in Arabic Print Demo: $e");
      debugPrint("Stacktrace: $stacktrace");
      rethrow;
    }
  }
}
