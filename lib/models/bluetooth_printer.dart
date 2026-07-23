import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class BluetoothPrinter {
  static const String developmentPrinterName =
      'Development Printer (Save to Folder)';
  static const String developmentPrinterAddress =
      'epos-development://local-output';

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

  factory BluetoothPrinter.development() {
    return BluetoothPrinter(
      deviceName: developmentPrinterName,
      address: developmentPrinterAddress,
      typePrinter: PrinterType.usb,
    );
  }

  bool get isUSB => typePrinter == PrinterType.usb;
  bool get isBluetooth => typePrinter == PrinterType.bluetooth;
  bool get isDevelopment => address == developmentPrinterAddress;
}
