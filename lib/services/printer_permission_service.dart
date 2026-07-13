import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the Android permissions required by the current printer driver.
///
/// Android 12+ exposes Bluetooth scan/connect as "Nearby devices". Older
/// Android versions use location for Bluetooth discovery. The bundled printer
/// driver still checks fine location on every Android version, so location is
/// retained here until that driver is upgraded or patched.
class PrinterPermissionService {
  const PrinterPermissionService._();

  static Future<bool> requestRequiredPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    statuses.forEach((permission, status) {
      debugPrint('[PrinterPermissions] $permission => $status');
    });

    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.locationWhenInUse]?.isGranted == true;
  }
}
