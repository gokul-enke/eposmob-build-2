import 'package:flutter/services.dart';

class PineLabsTerminalService {
  static const MethodChannel _channel = MethodChannel('PLUTUS-API');

  static Future<String> bindToService() async {
    try {
      final result = await _channel.invokeMethod('bindToService');
      return result?.toString() ?? 'UNKNOWN';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String> startTransaction(String transactionData) async {
    try {
      final result = await _channel.invokeMethod('startTransaction', {
        'transactionData': transactionData,
      });
      return result?.toString() ?? 'UNKNOWN';
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String> startPrintJob(String printData) async {
    try {
      final result = await _channel.invokeMethod('startPrintJob', {
        'printData': printData,
      });
      return result?.toString() ?? 'UNKNOWN';
    } catch (e) {
      return e.toString();
    }
  }
}
