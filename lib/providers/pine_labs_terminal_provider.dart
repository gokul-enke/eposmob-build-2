import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/pine_labs_terminal_service.dart';
import '../config/pine_labs_config.dart';

class PineLabsTerminalProvider with ChangeNotifier {
  final List<String> statusMessages = [];
  bool _isBindingInitiated = false;
  bool _isBound = false;
  bool _isProcessing = false;
  String _bindingStatus = 'Not Bound';
  Map<String, dynamic> _transactionHeader =
      PineLabsConfig.getTransactionHeader();
  int _transactionType = 4001;

  bool get isBound => _isBound;
  bool get isProcessing => _isProcessing;
  String get bindingStatus => _bindingStatus;
  Map<String, dynamic> get transactionHeader => _transactionHeader;
  int get transactionType => _transactionType;

  void setTransactionHeader(Map<String, dynamic> header) {
    _transactionHeader = Map<String, dynamic>.from(header);
    notifyListeners();
  }

  void setTransactionType(int value) {
    _transactionType = value;
    notifyListeners();
  }

  Future<void> ensureBinding() async {
    if (_isBound || _isBindingInitiated) {
      return;
    }
    _isBindingInitiated = true;
    _bindingStatus = 'Binding...';
    addStatusMessage('BINDING STARTED.');
    print('🔵 [PineLabs] Binding to service...');
    notifyListeners();
    final result = await PineLabsTerminalService.bindToService();
    print('🔵 [PineLabs] Binding result: $result');
    final normalized = result.toUpperCase();
    if (normalized.contains('SUCCESS')) {
      _bindingStatus = 'BINDING SUCCESS.';
      _isBound = true;
      addStatusMessage('BINDING SUCCESS.');
      print('✅ [PineLabs] Binding SUCCESS');
    } else {
      _bindingStatus = 'BINDING FAILED.';
      _isBound = false;
      addStatusMessage('BINDING FAILED. $result');
      print(' [PineLabs] Binding FAILED: $result');
    }
    _isBindingInitiated = false;
    notifyListeners();
  }

  Future<String> processSale(
      {required double amount, required String billingRefNo}) async {
    // Validate Pine Labs credentials are configured
    if (!PineLabsConfig.areCredentialsConfigured()) {
      final errorMsg =
          'Pine Labs credentials not configured. Please update ApplicationId and UserId in pine_labs_config.dart';
      print(' [PineLabs] $errorMsg');
      addStatusMessage('CONFIG ERROR: $errorMsg');
      return 'CONFIG_ERROR';
    }

    await ensureBinding();
    if (!_isBound) {
      print(' [PineLabs] Cannot process sale - service not bound');
      return 'BINDING FAILED';
    }
    // Pine Labs expects amount in minor units (paise). Convert ₹ to paise.
    final int paymentAmount = (amount * 100).round();
    print(' [PineLabs] Processing sale: ₹${amount.toStringAsFixed(2)} (paise: $paymentAmount), Ref: $billingRefNo');
    final payload = {
      "Detail": {
        "BillingRefNo": billingRefNo,
        "PaymentAmount": paymentAmount,
        "TransactionType": _transactionType
      },
      "Header": _transactionHeader
    };
    return _startTransaction(payload);
  }

  Future<String> startCustomTransaction(Map<String, dynamic> payload) async {
    await ensureBinding();
    if (!_isBound) {
      return 'BINDING FAILED';
    }
    return _startTransaction(payload);
  }

  Future<String> startPrintJob(Map<String, dynamic> payload) async {
    await ensureBinding();
    if (!_isBound) {
      return 'BINDING FAILED';
    }
    _setProcessing(true);
    addStatusMessage('PRINT JOB STARTED.');
    try {
      final jsonPayload = jsonEncode(payload);
      final result = await PineLabsTerminalService.startPrintJob(jsonPayload);
      addStatusMessage('PRINT JOB RESULT: $result');
      return result;
    } catch (e) {
      final message = 'PRINT JOB ERROR: $e';
      addStatusMessage(message);
      return message;
    } finally {
      _setProcessing(false);
    }
  }

  void addStatusMessage(String message) {
    statusMessages.add(message);
    notifyListeners();
  }

  void clearStatusMessages() {
    statusMessages.clear();
    notifyListeners();
  }

  Future<String> _startTransaction(Map<String, dynamic> payload) async {
    _setProcessing(true);
    addStatusMessage('TRANSACTION STARTED.');
    print('🔄 [PineLabs] Transaction started');
    try {
      final jsonPayload = jsonEncode(payload);
      print('📤 [PineLabs] Sending payload: $jsonPayload');
      final result =
          await PineLabsTerminalService.startTransaction(jsonPayload);
      addStatusMessage('TRANSACTION RESULT: $result');
      print('📥 [PineLabs] Transaction result: $result');
      return result;
    } catch (e) {
      final message = 'TRANSACTION ERROR: $e';
      addStatusMessage(message);
      print('⚠️ [PineLabs] Transaction error: $e');
      return message;
    } finally {
      _setProcessing(false);
    }
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}