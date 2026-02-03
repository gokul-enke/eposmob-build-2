import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:whatsapp_bot_flutter/whatsapp_bot_flutter.dart';
import '../controllers/whatsapp_controller.dart';
import '../helpers/date_helper.dart';

class WhatsappProvider extends ChangeNotifier {
  final WhatsappController _whatsappController = Get.put(WhatsappController(), permanent: true);
  
  bool _isSending = false;
  String _lastError = '';
  String _lastSuccess = '';

  // Getters
  bool get isSending => _isSending;
  String get lastError => _lastError;
  String get lastSuccess => _lastSuccess;
  bool get isConnected => _whatsappController.connected.value;
  bool get isConnecting => _whatsappController.isConnecting.value;
  String get connectionStatus => _whatsappController.connectionStatus.value;
  WhatsappController get controller => _whatsappController;
  
  /// Get direct access to WhatsApp client for advanced operations
  WhatsappClient? get whatsappClient => _whatsappController.client;

  /// Send a simple text message via WhatsApp
  Future<bool> sendTextMessage({
    required String phoneNumber,
    required String message,
    bool showSuccessMessage = true,
  }) async {
    try {
      _setLoading(true);
      _clearMessages();

      debugPrint('🔍 WhatsApp Provider: Starting text message send process');
      debugPrint('📱 Target phone: $phoneNumber');
      debugPrint('📝 Message length: ${message.length} characters');

      // Validate phone number
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      if (cleanPhone.isEmpty) {
        debugPrint('❌ WhatsApp Provider: Invalid phone number format');
        _setError('Invalid phone number format');
        return false;
      }
      debugPrint('✅ Phone number validated: $cleanPhone');

      // Check if WhatsApp is connected
      if (!_whatsappController.connected.value) {
        debugPrint('❌ WhatsApp Provider: WhatsApp not connected');
        debugPrint('🔄 Connection status: ${_whatsappController.connectionStatus.value}');
        _setError('WhatsApp is not connected. Please connect first.');
        return false;
      }
      debugPrint('✅ WhatsApp connection verified');
      debugPrint('🔗 Connection status: ${_whatsappController.connectionStatus.value}');

      // Send message
      debugPrint('🚀 Sending message via WhatsApp bot...');
      debugPrint('📝 Message preview: ${message.substring(0, message.length > 100 ? 100 : message.length)}${message.length > 100 ? '...' : ''}');
      
      await _whatsappController.sendTestMessage(cleanPhone, message);
      
      debugPrint('✅ Message sent successfully via WhatsApp bot');
      
      if (showSuccessMessage) {
        _setSuccess('Message sent successfully to $phoneNumber');
        debugPrint('📢 Success message set');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ WhatsApp Provider Error in sendTextMessage: $e');
      _setError('Failed to send message: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
      debugPrint('🏁 WhatsApp Provider: Text message process completed');
    }
  }

  /// Send actual PDF file via WhatsApp (NEW - uses sendFileMessage)
  Future<bool> sendPDFFile({
    required String phoneNumber,
    required File pdfFile,
    String? caption,
    bool showSuccessMessage = true,
  }) async {
    try {
      _setLoading(true);
      _clearMessages();

      debugPrint('🔍 WhatsApp Provider: Starting PDF file send process');
      debugPrint('📱 Target phone: $phoneNumber');
      debugPrint('📄 PDF file path: ${pdfFile.path}');
      
      // Run comprehensive PDF diagnosis
      await printPDFDiagnosis(pdfFile);

      // Validate file exists and check file integrity
      if (!await pdfFile.exists()) {
        debugPrint('❌ PDF file does not exist: ${pdfFile.path}');
        _setError('PDF file not found');
        return false;
      }
      
      final fileSize = await pdfFile.length();
      debugPrint('📄 PDF file exists: true');
      debugPrint('📄 PDF file size: $fileSize bytes');
      
      // Validate PDF file size (warn if too small)
      if (fileSize < 1000) {
        debugPrint('⚠️  WARNING: PDF file size is very small ($fileSize bytes)');
        debugPrint('⚠️  This might indicate a corrupted or incomplete PDF');
        debugPrint('⚠️  Consider checking PDF generation process');
      } else if (fileSize < 5000) {
        debugPrint('⚠️  NOTICE: PDF file size is small ($fileSize bytes)');
        debugPrint('⚠️  This might be a minimal invoice, but verify content is complete');
      } else if (fileSize > 25000000) { // 25MB limit for WhatsApp
        debugPrint('❌ PDF file is too large ($fileSize bytes > 25MB)');
        _setError('PDF file is too large for WhatsApp (max 25MB)');
        return false;
      } else {
        debugPrint('✅ PDF file size is acceptable ($fileSize bytes)');
      }
      
      // Try to read a small portion to validate file integrity
      try {
        final testBytes = await pdfFile.readAsBytes();
        if (testBytes.isEmpty) {
          debugPrint('❌ PDF file appears to be empty');
          _setError('PDF file is empty');
          return false;
        }
        
        // Check if it's actually a PDF file (should start with %PDF)
        final fileHeader = String.fromCharCodes(testBytes.take(4));
        if (!fileHeader.startsWith('%PDF')) {
          debugPrint('⚠️  WARNING: File does not appear to be a valid PDF (header: $fileHeader)');
          debugPrint('⚠️  Proceeding anyway, but this might cause issues');
        } else {
          debugPrint('✅ PDF file header validation passed');
        }
      } catch (readError) {
        debugPrint('❌ Error reading PDF file for validation: $readError');
        _setError('Cannot read PDF file: $readError');
        return false;
      }

      // Validate phone number
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      if (cleanPhone.isEmpty) {
        debugPrint('❌ WhatsApp Provider: Invalid phone number format');
        _setError('Invalid phone number format');
        return false;
      }
      debugPrint('✅ Phone number validated: $cleanPhone');

      // Check if WhatsApp is connected
      if (!_whatsappController.connected.value) {
        debugPrint('❌ WhatsApp Provider: WhatsApp not connected');
        _setError('WhatsApp is not connected. Please connect first.');
        return false;
      }
      debugPrint('✅ WhatsApp connection verified');

      // Get WhatsApp client
      final client = whatsappClient;
      if (client == null) {
        debugPrint('❌ WhatsApp client is null');
        _setError('WhatsApp client not available');
        return false;
      }
      debugPrint('✅ WhatsApp client obtained');

      // Read file bytes
      debugPrint('📖 Reading PDF file bytes...');
      final fileBytes = await pdfFile.readAsBytes();
      debugPrint('✅ File bytes loaded: ${fileBytes.length} bytes');

      // Prepare caption and filename
      final finalCaption = caption ?? 'Invoice PDF from CloudPOS';
      
      // CRITICAL FIX: Use enhanced filename cleaning to prevent .doc extension
      final fileName = _cleanFileNameForWhatsApp(pdfFile.path);
      
      debugPrint('📝 Caption: $finalCaption');
      debugPrint('📄 Original file path: ${pdfFile.path}');
      debugPrint('📄 Cleaned filename to send: $fileName');
      debugPrint('📄 File extension: ${fileName.split('.').last}');
      debugPrint('📄 Filename length: ${fileName.length}');

      // Send the PDF file
      debugPrint('🚀 Sending PDF file via WhatsApp bot sendFileMessage...');
      debugPrint('📄 Final filename being sent: $fileName');
      
      await client.chat.sendFileMessage(
        phone: cleanPhone,
        fileBytes: fileBytes,
        caption: finalCaption,
        fileType: WhatsappFileType.pdf,
        fileName: fileName, // Use the filename variable
      );

      debugPrint('🎉 PDF file sent successfully via WhatsApp bot!');
      
      if (showSuccessMessage) {
        _setSuccess('PDF file sent successfully to $phoneNumber');
        debugPrint('📢 Success message set');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ WhatsApp Provider Error in sendPDFFile: $e');
      _setError('Failed to send PDF file: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
      debugPrint('🏁 WhatsApp Provider: PDF file send process completed');
    }
  }

  /// Send message with PDF attachment (currently not supported by whatsapp_bot_flutter)
  /// This will send the PDF link or text with PDF info
  Future<bool> sendMessageWithPDF({
    required String phoneNumber,
    required String message,
    File? pdfFile,
    String? pdfUrl,
    bool showSuccessMessage = true,
  }) async {
    try {
      _setLoading(true);
      _clearMessages();

      debugPrint('🔍 WhatsApp Provider: Starting PDF message send process');
      debugPrint('📱 Target phone: $phoneNumber');
      debugPrint('📄 PDF file provided: ${pdfFile != null}');
      debugPrint('🔗 PDF URL provided: ${pdfUrl != null}');
      
      if (pdfFile != null) {
        debugPrint('📄 PDF file path: ${pdfFile.path}');
        debugPrint('📄 PDF file exists: ${await pdfFile.exists()}');
        debugPrint('📄 PDF file size: ${await pdfFile.length()} bytes');
      }

      // Validate phone number
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      if (cleanPhone.isEmpty) {
        debugPrint('❌ WhatsApp Provider: Invalid phone number format');
        _setError('Invalid phone number format');
        return false;
      }
      debugPrint('✅ Phone number validated: $cleanPhone');

      // Check if WhatsApp is connected
      if (!_whatsappController.connected.value) {
        debugPrint('❌ WhatsApp Provider: WhatsApp not connected');
        _setError('WhatsApp is not connected. Please connect first.');
        return false;
      }
      debugPrint('✅ WhatsApp connection verified');

      // Try to send actual PDF file if available
      if (pdfFile != null && await pdfFile.exists()) {
        debugPrint('🚀 Attempting to send actual PDF file via WhatsApp bot...');
        
        try {
          // Try using the new sendPDFFile method
          final pdfSuccess = await sendPDFFile(
            phoneNumber: phoneNumber,
            pdfFile: pdfFile,
            caption: message.isNotEmpty ? message : 'Invoice PDF from CloudPOS',
            showSuccessMessage: false, // We'll handle success message here
          );
          
          if (pdfSuccess) {
            debugPrint('🎉 PDF file sent successfully!');
            if (showSuccessMessage) {
              _setSuccess('PDF file sent successfully to $phoneNumber');
            }
            return true;
          }
        } catch (fileError) {
          debugPrint('❌ Error sending PDF file: $fileError');
          debugPrint('🔄 Falling back to message with PDF info...');
        }
      }
      
      // Fallback: Send text message with PDF info
      debugPrint('📝 Falling back to text message with PDF information...');
      
      String fullMessage = message;
      
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        fullMessage += '\n\n🔗 PDF Download Link: $pdfUrl';
        debugPrint('📎 Added PDF URL to message');
      } else if (pdfFile != null) {
        fullMessage += '\n\n📄 PDF File Generated: ${pdfFile.path.split('/').last}';
        fullMessage += '\n📂 Location: ${pdfFile.parent.path}';
        fullMessage += '\n📊 Size: ${await pdfFile.length()} bytes';
        fullMessage += '\n\n💡 Note: The PDF has been saved to your device. You can manually share it from the file location above.';
        debugPrint('📎 Added PDF file info to message');
      }
      
      fullMessage += '\n\n🤖 Sent via WhatsApp Bot Integration';
      debugPrint('📝 Final message length: ${fullMessage.length} characters');
      debugPrint('📝 Message preview: ${fullMessage.substring(0, fullMessage.length > 100 ? 100 : fullMessage.length)}...');

      // Send message
      debugPrint('🚀 Sending message via WhatsApp bot...');
      await _whatsappController.sendTestMessage(cleanPhone, fullMessage);
      debugPrint('✅ Message sent successfully via WhatsApp bot');
      
      if (showSuccessMessage) {
        final successMsg = pdfFile != null 
            ? 'Message with PDF info sent successfully to $phoneNumber\n\nPDF saved to: ${pdfFile.path}'
            : 'Message with PDF info sent successfully to $phoneNumber';
        _setSuccess(successMsg);
        debugPrint('📢 Success message set: $successMsg');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ WhatsApp Provider Error in sendMessageWithPDF: $e');
      _setError('Failed to send message with PDF: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
      debugPrint('🏁 WhatsApp Provider: PDF message process completed');
    }
  }

  /// Send invoice message with formatted content
  Future<bool> sendInvoiceMessage({
    required String phoneNumber,
    required String orderNumber,
    required String customerName,
    required String totalAmount,
    String? invoiceUrl,
    File? pdfFile,
    bool showSuccessMessage = true,
  }) async {
    try {
      _setLoading(true);
      _clearMessages();

      debugPrint('🔍 WhatsApp Provider: Starting invoice message send process');
      debugPrint('📱 Target phone: $phoneNumber');
      debugPrint('📋 Order: $orderNumber');
      debugPrint('👤 Customer: $customerName');
      debugPrint('💰 Amount: $totalAmount');
      debugPrint('🔗 Invoice URL: ${invoiceUrl ?? 'Not provided'}');
      debugPrint('📄 PDF file: ${pdfFile != null ? pdfFile.path : 'Not provided'}');

      // Create formatted invoice message
      final message = _createInvoiceMessage(
        orderNumber: orderNumber,
        customerName: customerName,
        totalAmount: totalAmount,
        invoiceUrl: invoiceUrl,
      );
      
      debugPrint('📝 Invoice message created (${message.length} chars)');
      debugPrint('📝 Message preview: ${message.substring(0, message.length > 150 ? 150 : message.length)}...');

      // If we have a PDF file, try sending it directly first
      if (pdfFile != null && await pdfFile.exists()) {
        debugPrint('🚀 Attempting to send invoice as PDF file...');
        
        final pdfSuccess = await sendPDFFile(
          phoneNumber: phoneNumber,
          pdfFile: pdfFile,
          caption: message,
          showSuccessMessage: showSuccessMessage,
        );
        
        if (pdfSuccess) {
          debugPrint('🎉 Invoice PDF sent successfully!');
          return true;
        } else {
          debugPrint('🔄 PDF sending failed, falling back to text with PDF info...');
        }
      }

      // Fallback to text message with PDF info
      return await sendMessageWithPDF(
        phoneNumber: phoneNumber,
        message: message,
        pdfFile: pdfFile,
        pdfUrl: invoiceUrl,
        showSuccessMessage: showSuccessMessage,
      );
    } catch (e) {
      debugPrint('❌ WhatsApp Provider Error in sendInvoiceMessage: $e');
      _setError('Failed to send invoice message: ${e.toString()}');
      return false;
    }
  }

  /// Create formatted invoice message
  String _createInvoiceMessage({
    required String orderNumber,
    required String customerName,
    required String totalAmount,
    String? invoiceUrl,
  }) {
    String message = '''
🧾 *Invoice for Order #$orderNumber*

Dear $customerName,

Thank you for your purchase! Here are your order details:

📋 Order Number: #$orderNumber
💰 Total Amount: $totalAmount
📅 Date: ${DateHelper.formatDate(DateHelper.now())}

We appreciate your business!
''';

    if (invoiceUrl != null && invoiceUrl.isNotEmpty) {
      message += '\n🔗 Download Invoice: $invoiceUrl';
      debugPrint('✅ Invoice URL added to message');
    } else {
      message += '\n📄 Invoice PDF has been generated and saved to your device.';
      message += '\n💾 You can find it in your Documents/epos folder.';
      debugPrint('⚠️  No invoice URL provided, added local file info');
    }

    message += '\n\n📧 For any questions, please contact our support team.';
    message += '\n\n---';
    message += '\n🏢 Powered by CloudPOS';
    message += '\n🤖 Sent via WhatsApp Bot Integration';

    return message;
  }

  /// Clean and validate phone number
  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Ensure it has country code
    if (cleaned.length >= 10) {
      // If no country code, assume Indian number and add +91
      if (cleaned.length == 10) {
        cleaned = '91$cleaned';
      }
      // Add + if not present
      if (!phone.startsWith('+')) {
        cleaned = '+$cleaned';
      } else {
        cleaned = '+${cleaned}';
      }
      return cleaned;
    }
    
    return '';
  }

  /// Clean filename for WhatsApp sharing to prevent extension issues
  String _cleanFileNameForWhatsApp(String originalPath) {
    // Extract just the filename without path
    String fileName = originalPath.split('/').last;
    
    debugPrint('🔧 Original filename: $fileName');
    
    // Remove any potential double extensions (e.g., .pdf.doc -> .pdf)
    if (fileName.contains('.pdf.')) {
      fileName = fileName.split('.pdf')[0] + '.pdf';
      debugPrint('🔧 Removed double extension: $fileName');
    }
    
    // Ensure the filename always ends with .pdf (no other extensions)
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      if (fileName.contains('.')) {
        // Replace any existing extension with .pdf
        fileName = fileName.split('.')[0] + '.pdf';
        debugPrint('🔧 Replaced extension with .pdf: $fileName');
      } else {
        // Add .pdf extension if none exists
        fileName = fileName + '.pdf';
        debugPrint('🔧 Added .pdf extension: $fileName');
      }
    }
    
    // Remove any invalid characters for WhatsApp
    fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    // Ensure filename isn't too long (WhatsApp limit)
    if (fileName.length > 100) {
      final extension = '.pdf';
      final nameWithoutExt = fileName.substring(0, fileName.length - extension.length);
      fileName = nameWithoutExt.substring(0, 95) + extension;
      debugPrint('🔧 Truncated long filename: $fileName');
    }
    
    debugPrint('🔧 Final cleaned filename: $fileName');
    return fileName;
  }

  /// Check if WhatsApp is available and connected
  bool isWhatsAppAvailable() {
    return _whatsappController.connected.value;
  }

  /// Get connection status message
  String getConnectionStatusMessage() {
    if (_whatsappController.connected.value) {
      return 'WhatsApp is connected and ready to send messages';
    } else if (_whatsappController.isConnecting.value) {
      return 'WhatsApp is connecting...';
    } else {
      return 'WhatsApp is not connected. Please connect first.';
    }
  }

  /// Connect WhatsApp if not already connected
  Future<bool> ensureWhatsAppConnection() async {
    if (_whatsappController.connected.value) {
      return true;
    }

    try {
      await _whatsappController.connect();
      // Wait a bit for connection to establish
      await Future.delayed(const Duration(seconds: 2));
      return _whatsappController.connected.value;
    } catch (e) {
      _setError('Failed to connect WhatsApp: ${e.toString()}');
      return false;
    }
  }

  /// Show WhatsApp status dialog
  void showWhatsAppStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _whatsappController.connected.value 
                  ? Icons.check_circle 
                  : Icons.warning,
              color: _whatsappController.connected.value 
                  ? Colors.green 
                  : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('WhatsApp Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${_whatsappController.connectionStatus.value}'),
            const SizedBox(height: 8),
            Text(getConnectionStatusMessage()),
            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Last Error: $_lastError',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          if (!_whatsappController.connected.value)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _whatsappController.connect();
              },
              child: const Text('Connect'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isSending = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _lastError = error;
    _lastSuccess = '';
    debugPrint('WhatsApp Provider Error: $error');
    notifyListeners();
  }

  void _setSuccess(String success) {
    _lastSuccess = success;
    _lastError = '';
    debugPrint('WhatsApp Provider Success: $success');
    notifyListeners();
  }

  void _clearMessages() {
    _lastError = '';
    _lastSuccess = '';
    notifyListeners();
  }

  /// Diagnose PDF file issues
  Future<Map<String, dynamic>> diagnosePDFFile(File pdfFile) async {
    final diagnosis = <String, dynamic>{};
    
    try {
      // Basic file checks
      diagnosis['exists'] = await pdfFile.exists();
      diagnosis['path'] = pdfFile.path;
      diagnosis['name'] = pdfFile.path.split('/').last;
      
      // ENHANCED: Check for filename issues that could cause .doc extension
      final originalName = pdfFile.path.split('/').last;
      diagnosis['originalName'] = originalName;
      diagnosis['hasDoubleExtension'] = originalName.contains('.pdf.');
      diagnosis['endsWithPdf'] = originalName.toLowerCase().endsWith('.pdf');
      diagnosis['extensionCount'] = originalName.split('.').length - 1;
      
      if (!diagnosis['exists']) {
        diagnosis['error'] = 'File does not exist';
        return diagnosis;
      }
      
      // File size check
      final fileSize = await pdfFile.length();
      diagnosis['size'] = fileSize;
      diagnosis['sizeHuman'] = _formatFileSize(fileSize);
      
      if (fileSize == 0) {
        diagnosis['warning'] = 'File is empty (0 bytes)';
      } else if (fileSize < 1000) {
        diagnosis['warning'] = 'File is very small (${fileSize} bytes) - might be corrupted';
      } else if (fileSize > 25000000) {
        diagnosis['error'] = 'File is too large (${_formatFileSize(fileSize)}) - WhatsApp limit is 25MB';
      }
      
      // Content validation
      final bytes = await pdfFile.readAsBytes();
      diagnosis['actualSize'] = bytes.length;
      
      if (bytes.isNotEmpty) {
        final header = String.fromCharCodes(bytes.take(10));
        diagnosis['header'] = header;
        diagnosis['isPDF'] = header.startsWith('%PDF');
        
        if (!header.startsWith('%PDF')) {
          diagnosis['warning'] = 'File does not appear to be a valid PDF (header: $header)';
        }
      }
      
      // File timestamp
      final stat = await pdfFile.stat();
      diagnosis['created'] = stat.modified.toString();
      diagnosis['accessible'] = stat.mode != 0;
      
    } catch (e) {
      diagnosis['error'] = 'Error diagnosing file: $e';
    }
    
    return diagnosis;
  }
  
  /// Format file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  /// Print detailed PDF diagnosis
  Future<void> printPDFDiagnosis(File pdfFile) async {
    debugPrint('🔍 ===== PDF FILE DIAGNOSIS =====');
    final diagnosis = await diagnosePDFFile(pdfFile);
    
    diagnosis.forEach((key, value) {
      debugPrint('🔍 $key: $value');
    });
    debugPrint('🔍 ===== END DIAGNOSIS =====');
  }

  @override
  void dispose() {
    // Don't dispose the controller here as it's managed by GetX
    super.dispose();
  }

  /// Show PDF limitation explanation dialog
  void showPDFLimitationDialog(BuildContext context, {File? pdfFile}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('WhatsApp Bot Limitation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhatsApp Bot Integration Info:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('⚠️  PDF files cannot be sent directly through the WhatsApp bot.'),
            const SizedBox(height: 8),
            const Text('✅ What we do instead:'),
            const SizedBox(height: 4),
            const Text('  • Send message with PDF information'),
            const Text('  • Include download link (if available)'),
            const Text('  • Provide file location details'),
            if (pdfFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PDF Generated:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('File: ${pdfFile.path.split('/').last}'),
                    Text('Location: ${pdfFile.parent.path}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '💡 To share the actual PDF file, use the "Share as PDF" option which opens your device\'s sharing menu.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
          if (pdfFile != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You can add logic here to open file location
              },
              child: const Text('Open File Location'),
            ),
        ],
      ),
    );
  }
}