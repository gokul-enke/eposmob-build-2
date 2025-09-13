import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_bot_flutter/whatsapp_bot_flutter.dart';

class WhatsappController extends GetxController {
  final RxString qrCode = ''.obs;
  final RxBool connected = false.obs;
  final RxInt progress = 0.obs; // heuristic progress
  final RxString error = ''.obs;
  final RxBool isConnecting = false.obs;

  WhatsappClient? _client;
  Timer? _connectionTimeout;
  
  // Session persistence keys
  static const String _sessionKey = 'whatsapp_session_active';
  static const String _lastConnectedKey = 'whatsapp_last_connected';

  Future<void> connect() async {
    if (isConnecting.value) {
      print('🔗 WhatsApp: Connection already in progress...');
      return;
    }

    print('🔗 WhatsApp: Starting connection...');
    isConnecting.value = true;
    error.value = '';
    progress.value = 5;
    connected.value = false;
    qrCode.value = '';

    // Set a timeout for the connection attempt
    _connectionTimeout = Timer(const Duration(minutes: 5), () {
      if (!connected.value) {
        error.value = 'Connection timeout. Please try again.';
        isConnecting.value = false;
        progress.value = 0;
      }
    });

    try {
      print('🔗 WhatsApp: Initializing WhatsApp client...');
      progress.value = 10;
      
      // Add a small delay to show initial progress
      await Future.delayed(const Duration(milliseconds: 500));
      progress.value = 15;

      print('🔗 WhatsApp: Calling WhatsappBotFlutter.connect...');
      _client = await WhatsappBotFlutter.connect(
        onConnectionEvent: (ConnectionEvent event) {
          print('🔗 WhatsApp: Connection event: $event');
          _handleConnectionEvent(event);
        },
        onQrCode: (String qr, Uint8List? imageBytes) {
          print('🔗 WhatsApp: QR Code received! Length: ${qr.length}');
          print('🔗 WhatsApp: QR Code data: ${qr.substring(0, 50)}...');
          
          // Clear any previous errors
          error.value = '';
          
          // Set the QR code for display
          qrCode.value = qr;
          progress.value = 40;
          
          print('🔗 WhatsApp: QR Code set in observable, UI should update');
        },
      );
      
      print('🔗 WhatsApp: Connect method completed, client: $_client');
      
      if (_client != null) {
        progress.value = 60;
        print('🔗 WhatsApp: Client created successfully, waiting for QR or connection...');
      } else {
        throw Exception('Failed to create WhatsApp client');
      }
      
    } catch (e) {
      print('🔗 WhatsApp: Error during connection: $e');
      error.value = 'Connection failed: ${e.toString()}';
      connected.value = false;
      progress.value = 0;
      isConnecting.value = false;
      _connectionTimeout?.cancel();
    }
  }

  void _handleConnectionEvent(ConnectionEvent event) {
    switch (event) {
      case ConnectionEvent.connected:
      case ConnectionEvent.authenticated:
        print('🔗 WhatsApp: Connected/Authenticated!');
        connected.value = true;
        progress.value = 100;
        qrCode.value = '';
        isConnecting.value = false;
        _connectionTimeout?.cancel();
        _saveConnectionState(true);
        break;
      case ConnectionEvent.logout:
        print('🔗 WhatsApp: Logged out');
        connected.value = false;
        progress.value = 0;
        isConnecting.value = false;
        _saveConnectionState(false);
        break;
      default:
        print('🔗 WhatsApp: Intermediate state: $event');
        // Handle specific events for better user feedback
        if (event.toString().contains('downloadingChrome')) {
          progress.value = 25;
          error.value = 'Downloading Chromium... This may take a few minutes.';
        } else if (event.toString().contains('initializing')) {
          progress.value = 15;
          error.value = 'Initializing WhatsApp client...';
        } else {
          progress.value = 50;
        }
    }
  }

  Future<void> sendTestMessage(String phone, String message) async {
    print('📱 WhatsApp: Sending message to $phone');
    try {
      if (_client == null) {
        print('📱 WhatsApp: Client is null!');
        error.value = 'Client not connected';
        return;
      }
      print('📱 WhatsApp: Calling sendTextMessage...');
      await _client!.chat.sendTextMessage(phone: phone, message: message);
      print('📱 WhatsApp: Message sent successfully');
    } catch (e) {
      print('📱 WhatsApp: Error sending message: $e');
      error.value = e.toString();
    }
  }

  void reset() {
    print('🔄 WhatsApp: Resetting controller state');
    _connectionTimeout?.cancel();
    qrCode.value = '';
    progress.value = 0;
    error.value = '';
    connected.value = false;
    isConnecting.value = false;
    _client = null;
    _saveConnectionState(false);
  }

  /// Clear Chromium cache and try reconnection
  Future<void> clearCacheAndReconnect() async {
    print('🔄 WhatsApp: Clearing cache and reconnecting...');
    reset();
    
    // Add delay to ensure cleanup
    await Future.delayed(const Duration(seconds: 2));
    
    // Try connection again
    await connect();
  }

  /// Save connection state to SharedPreferences
  Future<void> _saveConnectionState(bool isConnected) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, isConnected);
      if (isConnected) {
        await prefs.setInt(_lastConnectedKey, DateTime.now().millisecondsSinceEpoch);
      }
      print('💾 WhatsApp: Session state saved: $isConnected');
    } catch (e) {
      print('💾 WhatsApp: Failed to save session state: $e');
    }
  }

  /// Check if there's a saved session and try to restore connection
  Future<void> checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool(_sessionKey) ?? false;
      final lastConnected = prefs.getInt(_lastConnectedKey) ?? 0;
      
      if (wasConnected && lastConnected > 0) {
        final lastConnectedTime = DateTime.fromMillisecondsSinceEpoch(lastConnected);
        final timeDiff = DateTime.now().difference(lastConnectedTime);
        
        // If last connection was within 24 hours, try to restore
        if (timeDiff.inHours < 24) {
          print('💾 WhatsApp: Found recent session, attempting to restore...');
          await connect();
        } else {
          print('💾 WhatsApp: Session expired (${timeDiff.inHours} hours old)');
          await _saveConnectionState(false);
        }
      } else {
        print('💾 WhatsApp: No saved session found');
      }
    } catch (e) {
      print('💾 WhatsApp: Failed to check saved session: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Check for saved session on controller initialization
    checkSavedSession();
  }

  @override
  void onClose() {
    _connectionTimeout?.cancel();
    super.onClose();
  }
}
