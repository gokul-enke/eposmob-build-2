import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/screens/print/printer_settings.dart';
import 'package:pos_machine/models/get_app_settings.dart';

class PrintPage extends StatefulWidget {
  final List<dynamic> cartItems;
  final String? storeName;
  final String formattedTotal;
  final String? savedTotal;
  final String orderDate;
  final String orderNumber;
  final bool isFromLocalStorage;

  const PrintPage({
    Key? key,
    required this.cartItems,
    required this.formattedTotal,
    this.savedTotal,
    this.storeName,
    required this.orderDate,
    required this.orderNumber,
    this.isFromLocalStorage = false,
  }) : super(key: key);

  @override
  _PrintPageState createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];
  StreamSubscription<PrinterDevice>? _subscription;
  BluetoothPrinter? selectedPrinter;
  bool _isScanning = false;
  bool _isLoading = true;
  ReceiptTemplate? selectedTemplate;

  static const Color primaryColor = Color(0XFF3C92F5);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color textPrimaryColor = Color(0xFF2C3E50);
  static const Color textSecondaryColor = Color(0xFF7F8C8D);
  static const Color backgroundColor = Color(0xFFF5F6FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      Provider.of<PaymentGatewaysProvider>(context, listen: false)
          .fetchPaymentGateways(accessToken: accessToken!);
      _loadDefaultPrinter();
      _loadReceiptTemplate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPermissions();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (await _requestPermissions()) {
      _scan();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'This app needs Bluetooth and Location permissions to scan for printers.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  void _scan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      devices.clear();
    });

    try {
      // Scan for Bluetooth printers
      _subscription = printerManager
          .discovery(type: PrinterType.bluetooth, isBle: false)
          .listen((device) {
        // debugPrint('Found Bluetooth device: ${device.name}');
        final printer = BluetoothPrinter(
          deviceName: device.name,
          address: device.address,
          typePrinter: PrinterType.bluetooth,
        );
        setState(() {
          devices.add(printer);
        });
      });

      // Scan for USB printers
      await printerManager.discovery(type: PrinterType.usb).forEach((device) {
        // debugPrint('Found USB device: ${device.name}');
        final printer = BluetoothPrinter(
          deviceName: device.name,
          vendorId: device.vendorId,
          productId: device.productId,
          typePrinter: PrinterType.usb,
        );
        setState(() {
          devices.add(printer);
        });
      });
    } catch (e) {
      // debugPrint('Error during scanning: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');

    if (defaultPrinterJson != null) {
      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      setState(() {
        selectedPrinter = BluetoothPrinter(
          deviceName: printerData['deviceName'],
          address: printerData['address'],
          vendorId: printerData['vendorId'],
          productId: printerData['productId'],
          typePrinter: PrinterType.values.firstWhere(
            (e) => e.toString() == printerData['typePrinter'],
          ),
        );
        _isLoading = false;
      });

      // If we have a default printer, automatically print
      if (selectedPrinter != null) {
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final appSettings = appSettingsProvider.appSettings;
        printReceipt(
            appSettings!.customerCarePhone, appSettings.customerCareEmail);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDefaultPrinter(BluetoothPrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    final printerData = {
      'deviceName': printer.deviceName,
      'address': printer.address,
      'vendorId': printer.vendorId,
      'productId': printer.productId,
      'typePrinter': printer.typePrinter.toString(),
    };
    await prefs.setString('default_printer', json.encode(printerData));
  }

  void selectPrinter(BluetoothPrinter printer) {
    // debugPrint('Selecting printer:');
    // debugPrint('Device Name: ${printer.deviceName}');
    // debugPrint('Address: ${printer.address}');
    // debugPrint('Type: ${printer.typePrinter}');
    // debugPrint('VendorId: ${printer.vendorId}');
    // debugPrint('ProductId: ${printer.productId}');

    setState(() {
      selectedPrinter = printer;
    });

    // Save the selected printer as default
    _saveDefaultPrinter(printer);

    if (mounted) {
      showScaffold(
        context: context,
        message: "${printer.deviceName.toString()} Printer Selected",
      );
    }
  }

  Future<void> _loadReceiptTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getString('receipt_templates');

    if (templatesJson != null) {
      try {
        final List<dynamic> decodedData = json.decode(templatesJson);
        final List<ReceiptTemplate> loadedTemplates = decodedData
            .map((template) => ReceiptTemplate.fromJson(template))
            .toList();

        // Find default template
        final defaultTemplate = loadedTemplates.firstWhere(
          (template) => template.isDefault,
          orElse: () => loadedTemplates.isNotEmpty
              ? loadedTemplates.first
              : ReceiptTemplate(
                  name: 'Default Template',
                  settings: ReceiptSettings(),
                  isDefault: true,
                ),
        );

        setState(() {
          selectedTemplate = defaultTemplate;
        });
      } catch (e) {
        print('Error decoding templates: $e');
        // Create a default template if none exists
        setState(() {
          selectedTemplate = ReceiptTemplate(
            name: 'Default Template',
            settings: ReceiptSettings(),
            isDefault: true,
          );
        });
      }
    } else {
      // Create a default template if none exists
      setState(() {
        selectedTemplate = ReceiptTemplate(
          name: 'Default Template',
          settings: ReceiptSettings(),
          isDefault: true,
        );
      });
    }
  }

  Future<void> printReceipt(
      String customerCareNumber, String customerCareEmail) async {
    if (selectedPrinter == null) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "No Printer Selected",
        );
      }
      return;
    }

    try {
      // Connect to the printer
      await _connectToPrinter();

      // Generate receipt
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Get settings from template or use defaults
      final settings = selectedTemplate?.settings ?? ReceiptSettings();
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;

      // Header
      bytes += _buildHeader(generator, settings, appSettings!);

      // Item Table Header
      bytes += _buildTableHeader(generator, settings);

      // Cart Items
      bytes += _buildCartItems(generator, widget.cartItems, settings);

      // Total Amount
      bytes += _buildTotalAmount(generator, settings);

      // Thank You Message
      if (settings.showThankYouMessage) {
        bytes += _buildThankYouMessage(generator, settings);
      }

      // QR Code
      if (settings.showQRCode) {
        bytes += _buildQRCode(generator, customerCareNumber, settings);
      }

      // Terms & Conditions
      if (settings.showTermsConditions) {
        bytes += _buildTermsConditions(generator, settings);
      }

      // Cut the receipt
      bytes += generator.cut();

      // Print receipt
      await printerManager.send(
          type: selectedPrinter!.typePrinter, bytes: bytes);

      if (mounted) {
        showScaffold(context: context, message: "Print job sent successfully");
        Navigator.pop(context);
        SideBarController sideBarController = Get.put(SideBarController());
        sideBarController.index.value = 46;
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      await _disconnectPrinter();
    }
  }

  List<int> _buildHeader(
      Generator generator, ReceiptSettings settings, AppSettings appSettings) {
    List<int> bytes = [];

    if (settings.showStoreName) {
      bytes += generator.row([
        PosColumn(
          text:
              settings.storeName.isNotEmpty ? settings.storeName : 'STORE NAME',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2),
        ),
      ]);
    }

    if (settings.showStoreAddress) {
      bytes += generator.row([
        PosColumn(
          text: settings.storeAddress.isNotEmpty
              ? settings.storeAddress
              : 'Shop Address',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, height: PosTextSize.size1),
        ),
      ]);
    }

    if (settings.showFssaiInfo) {
      bytes += generator.row([
        PosColumn(
          text: settings.fssaiInfo.isNotEmpty
              ? settings.fssaiInfo
              : 'Fssai: xxxx',
          width: 12,
          styles: const PosStyles(
              align: PosAlign.center, height: PosTextSize.size1),
        ),
      ]);
    }

    if (settings.showTel) {
      bytes += generator.text(
          settings.telephone.isNotEmpty
              ? settings.telephone
              : 'TEL: ${appSettings.customerCarePhone}',
          styles: const PosStyles(align: PosAlign.center));
    }

    if (settings.showEmail) {
      bytes += generator.text(
          settings.email.isNotEmpty
              ? settings.email
              : 'Email: ${appSettings.customerCareEmail}',
          styles: const PosStyles(align: PosAlign.center));
    }

    if (settings.showInvoiceNumber) {
      bytes += generator.text('INVOICE',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('INV No: ${widget.orderNumber}',
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    if (settings.showDateHeader) {
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(
            text: DateHelper.formatISODate(widget.orderDate),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: DateHelper.formatISODateToIST(widget.orderDate),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
      bytes += generator.hr();
    }

    return bytes;
  }

  List<int> _buildTableHeader(Generator generator, ReceiptSettings settings) {
    List<PosColumn> columns = [];
    int totalWidth = 0;

    // Always add SL# column
    columns.add(PosColumn(
        text: 'SL#',
        width: 1,
        styles: const PosStyles(align: PosAlign.center)));
    totalWidth += 1;

    // Always add PARTICULARS column
    columns.add(PosColumn(text: 'PARTICULARS', width: 3));
    totalWidth += 3;

    // Always add MRP column
    columns.add(PosColumn(
        text: 'MRP', width: 2, styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add QTY column
    columns.add(PosColumn(
        text: 'QTY', width: 2, styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add RATE column
    columns.add(PosColumn(
        text: 'RATE',
        width: 2,
        styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Always add TOTAL column
    columns.add(PosColumn(
        text: 'TOTAL',
        width: 2,
        styles: const PosStyles(align: PosAlign.right)));
    totalWidth += 2;

    // Adjust if total width is not 12
    if (totalWidth < 12 && columns.isNotEmpty) {
      // Add remaining width to the first column
      columns[0] = PosColumn(
        text: columns[0].text,
        width: columns[0].width + (12 - totalWidth),
        styles: columns[0].styles,
      );
    }

    return generator.row(columns) + generator.hr();
  }

  List<int> _buildCartItems(
      Generator generator, List<dynamic> cartItems, ReceiptSettings settings) {
    List<int> bytes = [];

    for (var i = 0; i < cartItems.length; i++) {
      var item = cartItems[i];

      // Handle different models based on data source
      String slNumber = '';
      String productName = '';
      String mrp = '';
      String quantity = '';
      String unitPrice = '';
      String totalPrice = '';

      // Adapt the model based on whether it's from local storage or current cart
      if (widget.isFromLocalStorage) {
        slNumber = (i + 1).toString();
        productName = item['productName'] ?? '';
        mrp = item['mrp'] ?? '0.00';
        quantity = item['quantity'] ?? '0';
        unitPrice = item['unitPrice'] ?? '0.00';
        totalPrice = item['totalPrice'] ?? '0.00';
      } else {
        slNumber = (i + 1).toString();
        productName = item.productName ?? '';
        mrp = item.mrp ?? '0.00';
        quantity = item.quantity?.toString() ?? '0';
        unitPrice = item.unitPrice?.toString() ?? '0.00';
        totalPrice = item.totalPrice?.toString() ?? '0.00';
      }

      List<PosColumn> columns = [];
      int totalWidth = 0;

      // Always add SL# column
      columns.add(PosColumn(
          text: slNumber,
          width: 1,
          styles: const PosStyles(align: PosAlign.center)));
      totalWidth += 1;

      // Always add PARTICULARS column
      columns.add(PosColumn(
          text: productName.length > 15
              ? productName.substring(0, 15)
              : productName,
          width: 3));
      totalWidth += 3;

      // Always add MRP column
      columns.add(PosColumn(
          text: mrp, width: 2, styles: const PosStyles(align: PosAlign.right)));
      totalWidth += 2;

      // Always add QTY column
      columns.add(PosColumn(
          text: quantity,
          width: 2,
          styles: const PosStyles(align: PosAlign.right)));
      totalWidth += 2;

      // Always add RATE column
      columns.add(PosColumn(
          text: unitPrice,
          width: 2,
          styles: const PosStyles(align: PosAlign.right)));
      totalWidth += 2;

      // Always add TOTAL column
      columns.add(PosColumn(
          text: totalPrice,
          width: 2,
          styles: const PosStyles(align: PosAlign.right)));
      totalWidth += 2;

      // Adjust if total width is not 12
      if (totalWidth < 12 && columns.isNotEmpty) {
        // Add remaining width to the first column
        columns[0] = PosColumn(
          text: columns[0].text,
          width: columns[0].width + (12 - totalWidth),
          styles: columns[0].styles,
        );
      }

      bytes += generator.row(columns);

      // If product name is long, add additional lines to show the full name
      if (productName.length > 15) {
        int startIndex = 15;
        while (startIndex < productName.length) {
          int endIndex = startIndex + 24 < productName.length
              ? startIndex + 24
              : productName.length;
          String namePart = productName.substring(startIndex, endIndex);

          // Create a new row with proper column alignment
          List<PosColumn> continuationColumns = [];
          int currentWidth = 0;

          // Always add empty column for SL#
          continuationColumns.add(PosColumn(
              text: '',
              width: 1,
              styles: const PosStyles(align: PosAlign.center)));
          currentWidth += 1;

          // Always add the continuation text in the PARTICULARS column
          continuationColumns.add(PosColumn(
              text: namePart,
              width: 3,
              styles: const PosStyles(align: PosAlign.left)));
          currentWidth += 3;

          // Always add empty columns for the rest of the fields
          continuationColumns.add(PosColumn(text: '', width: 2));
          currentWidth += 2;

          continuationColumns.add(PosColumn(text: '', width: 2));
          currentWidth += 2;

          continuationColumns.add(PosColumn(text: '', width: 2));
          currentWidth += 2;

          continuationColumns.add(PosColumn(text: '', width: 2));
          currentWidth += 2;

          // Adjust if total width is not 12
          if (currentWidth < 12 && continuationColumns.isNotEmpty) {
            // Add remaining width to the product name column (index 1)
            continuationColumns[1] = PosColumn(
              text: continuationColumns[1].text,
              width: continuationColumns[1].width + (12 - currentWidth),
              styles: continuationColumns[1].styles,
            );
          }

          bytes += generator.row(continuationColumns);
          startIndex = endIndex;
        }
      }
    }

    return bytes + generator.hr();
  }

  List<int> _buildTotalAmount(Generator generator, ReceiptSettings settings) {
    List<int> bytes = [];

    // Display item count
    // if (settings.showMRPTotal) {
    //   bytes += generator.row([
    //     PosColumn(
    //         text: 'Discount',
    //         width: 6,
    //         styles: const PosStyles(
    //             align: PosAlign.left, bold: true, height: PosTextSize.size1)),
    //     PosColumn(
    //         text: (double.parse(widget.formattedTotal) -
    //                 double.parse(widget.savedTotal!))
    //             .toString(),
    //         width: 6,
    //         styles: const PosStyles(
    //             align: PosAlign.right, bold: true, height: PosTextSize.size1)),
    //   ]);
    // }

    // Display item count
    if (settings.showMRPTotal) {
      bytes += generator.row([
        PosColumn(
            text: 'Items',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: widget.cartItems.length.toString(),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    if (settings.showNetAmount) {
      bytes += generator.row([
        PosColumn(
            text: 'Net Total',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: widget.formattedTotal,
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    if (settings.showMRPTotal) {
      bytes += generator.row([
        PosColumn(
            text: 'Total MRP',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text:
                "${(double.parse(widget.savedTotal!) + double.parse(widget.formattedTotal))}",
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    if (settings.showSaved) {
      bytes += generator.row([
        PosColumn(
            text: 'You Saved',
            width: 6,
            styles: const PosStyles(
                align: PosAlign.left, bold: true, height: PosTextSize.size1)),
        PosColumn(
            text: widget.savedTotal.toString(),
            width: 6,
            styles: const PosStyles(
                align: PosAlign.right, bold: true, height: PosTextSize.size1)),
      ]);
    }

    // Add a separator line
    bytes += generator.hr();

    if (settings.showAmountInWords) {
      bytes += generator.text(
          '${AmountHelper().convertNumberToWords(double.parse(widget.formattedTotal))} Only.',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
    }

    return bytes;
  }

  List<int> _buildThankYouMessage(
      Generator generator, ReceiptSettings settings) {
    List<int> bytes = [];

    bytes += generator.text(
        settings.thankYouMessage.isNotEmpty
            ? settings.thankYouMessage
            : 'Thank You... Visit Again',
        styles: const PosStyles(bold: true, align: PosAlign.center));

    bytes += generator.hr();
    return bytes;
  }

  List<int> _buildQRCode(Generator generator, String customerCareNumber,
      ReceiptSettings settings) {
    final paymentGatewaysProvider =
        Provider.of<PaymentGatewaysProvider>(context, listen: false);
    final manualPaymentGateway = paymentGatewaysProvider.paymentGateways
        .firstWhere((gateway) => gateway.code == "MANUAL_PAYMENT_GATEWAY");
    List<int> bytes = [];

    bytes += generator.emptyLines(1);

    bytes += generator.qrcode(
      'upi://pay?pa=${manualPaymentGateway.link}&am=${widget.formattedTotal}&tn=${widget.orderNumber}&cu=INR&ds=EPOS&t=c&st=1&se=1&sd=1',
      size: QRSize.Size4,
      align: PosAlign.center,
    );

    bytes += generator.emptyLines(1);

    bytes += generator.text(
        settings.qrCodeMessage.isNotEmpty
            ? settings.qrCodeMessage
            : 'Scan this QR code to Pay',
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.emptyLines(1);
    return bytes;
  }

  List<int> _buildTermsConditions(
      Generator generator, ReceiptSettings settings) {
    List<int> bytes = [];

    bytes += generator.text('Terms & Conditions',
        styles: const PosStyles(bold: true, align: PosAlign.left));

    String terms = settings.termsConditions.isNotEmpty
        ? settings.termsConditions
        : '1. Replace or Return only within 7 Days of Purchase.\n2. Replace only with Bill.';

    List<String> termsList = terms.split('\n');
    for (var term in termsList) {
      bytes +=
          generator.text(term, styles: const PosStyles(align: PosAlign.left));
    }

    bytes += generator.hr();
    return bytes;
  }

  Future<void> _connectToPrinter() async {
    if (selectedPrinter!.typePrinter == PrinterType.usb) {
      await printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: selectedPrinter!.deviceName ?? 'Unknown',
          productId: selectedPrinter!.productId,
          vendorId: selectedPrinter!.vendorId,
        ),
      );
    } else if (selectedPrinter!.typePrinter == PrinterType.bluetooth) {
      if (selectedPrinter!.address == null) {
        throw Exception('Bluetooth printer address is null');
      }
      await printerManager.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: selectedPrinter!.deviceName ?? 'Unknown',
          address: selectedPrinter!.address!,
          isBle: false,
        ),
      );
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      await printerManager.disconnect(type: selectedPrinter!.typePrinter);
    } catch (e) {
      // Handle disconnection error
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    debugPrint("appSettings!.customerCareEmail.toString()");
    debugPrint(appSettings!.customerCareEmail.toString());

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Select Printer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
            SideBarController sideBarController = Get.put(SideBarController());
            sideBarController.index.value = 46;
          },
        ),
        elevation: 0,
        backgroundColor: primaryColor,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Printers',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'Scanning...'
                          : '${devices.length} devices found',
                      style: const TextStyle(
                        color: textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.print_disabled,
                            size: 64,
                            color: textSecondaryColor,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No printers found',
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the refresh button to scan for printers',
                            style: TextStyle(
                              color: textSecondaryColor.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final printer = devices[index];
                        final isSelected = selectedPrinter == printer;

                        return Card(
                          elevation: isSelected ? 2 : 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: primaryColor, width: 2)
                                  : null,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.print,
                                color: isSelected
                                    ? primaryColor
                                    : textSecondaryColor,
                                size: 28,
                              ),
                              title: Text(
                                printer.deviceName ?? 'Unknown device',
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                printer.address ?? '',
                                style: const TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? accentColor
                                      : Colors.grey[200],
                                  foregroundColor: isSelected
                                      ? Colors.white
                                      : textSecondaryColor,
                                  elevation: isSelected ? 2 : 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () => selectPrinter(printer),
                                child: Text(
                                  isSelected ? 'Selected' : 'Select',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => selectedPrinter == null
                  ? null
                  : printReceipt(appSettings.customerCarePhone,
                      appSettings.customerCareEmail),
              icon: const Icon(Icons.receipt_long),
              label: const Text(
                'Print Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: textSecondaryColor.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _checkPermissions,
        tooltip: 'Scan for printers',
        backgroundColor: _isScanning ? textSecondaryColor : primaryColor,
        elevation: 4,
        child: _isScanning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.refresh,
                color: Colors.white,
              ),
      ),
    );
  }
}

class BluetoothPrinter {
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  PrinterType typePrinter;
  bool isConnected;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isConnected = false,
  });

  bool get isUSB => typePrinter == PrinterType.usb;
  bool get isBluetooth => typePrinter == PrinterType.bluetooth;
}
