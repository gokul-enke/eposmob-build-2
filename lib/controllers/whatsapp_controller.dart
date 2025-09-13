import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_bot_flutter/whatsapp_bot_flutter.dart';

class WhatsappController extends GetxController {
  final RxString qrCode = ''.obs;
  final RxBool connected = false.obs;
  final RxInt progress = 0.obs; // heuristic progress
  final RxString error = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxString lastConnected = ''.obs;
  final RxBool chromiumDownloaded = false.obs;

  WhatsappClient? _client;
  Timer? _connectionTimeout;

  // Session persistence keys
  static const String _sessionKey = 'whatsapp_session_active';
  static const String _lastConnectedKey = 'whatsapp_last_connected';
  static const String _chromiumDownloadedKey = 'chromium_downloaded';

  Future<void> connect() async {
    if (isConnecting.value) {
      debugPrint('🔗 WhatsApp: Connection already in progress...');
      return;
    }

    debugPrint('🔗 WhatsApp: Starting connection...');
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
      debugPrint('🔗 WhatsApp: Initializing WhatsApp client...');
      progress.value = 10;

      // Add a small delay to show initial progress
      await Future.delayed(const Duration(milliseconds: 500));
      progress.value = 15;

      debugPrint('🔗 WhatsApp: Calling WhatsappBotFlutter.connect...');
      _client = await WhatsappBotFlutter.connect(
        onConnectionEvent: (ConnectionEvent event) {
          debugPrint('🔗 WhatsApp: Connection event: $event');
          _handleConnectionEvent(event);
        },
        onQrCode: (String qr, Uint8List? imageBytes) {
          debugPrint('🔗 WhatsApp: QR Code received! Length: ${qr.length}');
          debugPrint('🔗 WhatsApp: QR Code data: ${qr.substring(0, 50)}...');

          // Clear any previous errors
          error.value = '';

          // Set the QR code for display
          qrCode.value = qr;
          progress.value = 40;

          debugPrint(
              '🔗 WhatsApp: QR Code set in observable, UI should update');
        },
      );

      debugPrint('🔗 WhatsApp: Connect method completed, client: $_client');

      if (_client != null) {
        progress.value = 60;
        debugPrint(
            '🔗 WhatsApp: Client created successfully, waiting for QR or connection...');
      } else {
        throw Exception('Failed to create WhatsApp client');
      }
    } catch (e) {
      debugPrint('🔗 WhatsApp: Error during connection: $e');
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
        debugPrint('🔗 WhatsApp: Connected/Authenticated!');
        connected.value = true;
        progress.value = 100;
        qrCode.value = '';
        isConnecting.value = false;
        _connectionTimeout?.cancel();
        _saveConnectionState(true);
        break;
      case ConnectionEvent.logout:
        debugPrint('🔗 WhatsApp: Logged out');
        connected.value = false;
        progress.value = 0;
        isConnecting.value = false;
        _saveConnectionState(false);
        break;
      default:
        debugPrint('🔗 WhatsApp: Intermediate state: $event');
        if (event.toString().contains('downloadingChrome')) {
          progress.value = 25;
          error.value = 'Downloading Chromium... This may take a few minutes.';
        } else if (event.toString().contains('initializing')) {
          progress.value = 15;
          error.value = 'Initializing WhatsApp client...';
        } else if (event.toString().contains('ready')) {
          // Chromium successfully downloaded
          _saveChromiumDownloaded(true);
          chromiumDownloaded.value = true;
        }
    }
  }

  Future<void> sendTestMessage(String phone, String message) async {
    debugPrint('📱 WhatsApp: Sending message to $phone');
    try {
      if (_client == null) {
        debugPrint('📱 WhatsApp: Client is null!');
        error.value = 'Client not connected';
        return;
      }
      debugPrint('📱 WhatsApp: Calling sendTextMessage...');
      await _client!.chat.sendTextMessage(phone: phone, message: message);
      debugPrint('📱 WhatsApp: Message sent successfully');
    } catch (e) {
      debugPrint('📱 WhatsApp: Error sending message: $e');
      error.value = e.toString();
    }
  }

  void reset() {
    debugPrint('🔄 WhatsApp: Resetting controller state');
    _connectionTimeout?.cancel();
    qrCode.value = '';
    progress.value = 0;
    error.value = '';
    connected.value = false;
    isConnecting.value = false;
    _client = null;
    _saveConnectionState(false);
    _saveChromiumDownloaded(false);
  }

  /// Clear Chromium cache and try reconnection
  Future<void> clearCacheAndReconnect() async {
    debugPrint('🔄 WhatsApp: Clearing cache and reconnecting...');
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
        final now = DateTime.now();
        await prefs.setInt(_lastConnectedKey, now.millisecondsSinceEpoch);
        lastConnected.value = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';
      }
      debugPrint('💾 WhatsApp: Session state saved: $isConnected');
    } catch (e) {
      debugPrint('💾 WhatsApp: Failed to save session state: $e');
    }
  }

  /// Save Chromium download status to SharedPreferences
  Future<void> _saveChromiumDownloaded(bool isDownloaded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chromiumDownloadedKey, isDownloaded);
      debugPrint('💾 WhatsApp: Chromium download status saved: $isDownloaded');
    } catch (e) {
      debugPrint('💾 WhatsApp: Failed to save Chromium download status: $e');
    }
  }

  /// Check if there's a saved session and try to restore connection
  Future<void> checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool(_sessionKey) ?? false;
      chromiumDownloaded.value = prefs.getBool(_chromiumDownloadedKey) ?? false;

      if (wasConnected) {
        debugPrint(
            '💾 WhatsApp: Found saved session, attempting to restore...');
        await connect();
      } else {
        debugPrint('💾 WhatsApp: No saved session found');
      }
    } catch (e) {
      debugPrint('💾 WhatsApp: Failed to check saved session: $e');
    }
  }

  Future<void> disconnect() async {
    debugPrint('🔌 WhatsApp: Disconnecting...');
    try {
      await _client?.logout();
      reset();
    } catch (e) {
      debugPrint('🔌 WhatsApp: Error during disconnect: $e');
      error.value = 'Disconnect failed: ${e.toString()}';
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Check for saved session on controller initialization
    checkSavedSession().then((_) {
      if (!connected.value) {
        // Auto-show QR if no saved session
        connect();
      }
    });
  }

  @override
  void onClose() {
    _connectionTimeout?.cancel();
    super.onClose();
  }
}
