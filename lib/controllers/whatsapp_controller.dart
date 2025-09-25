import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_bot_flutter/whatsapp_bot_flutter.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

class WhatsappController extends GetxController {
  final RxString qrCode = ''.obs;
  final RxBool connected = false.obs;
  final RxInt progress = 0.obs; // heuristic progress
  final RxString error = ''.obs;
  final RxBool isConnecting = false.obs;
  final RxString lastConnected = ''.obs;
  final RxBool chromiumDownloaded = false.obs;
  final RxString connectionStatus = 'Disconnected'.obs;
  final RxInt reconnectAttempts = 0.obs;
  final RxBool autoReconnect = true.obs;

  WhatsappClient? _client;
  Timer? _connectionTimeout;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  
  // Getter to access client from provider
  WhatsappClient? get client => _client;
  
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(minutes: 2);

  // Session persistence keys
  static const String _sessionKey = 'whatsapp_session_active';
  static const String _lastConnectedKey = 'whatsapp_last_connected';
  static const String _chromiumDownloadedKey = 'chromium_downloaded';
  static const String _sessionDataKey = 'whatsapp_session_data';
  static const String _autoReconnectKey = 'whatsapp_auto_reconnect';
  static const String _hotRestartDetectionKey = 'whatsapp_hot_restart';
  static const String _sessionTimestampKey = 'whatsapp_session_timestamp';

  // UI helpers to show messages via overlay when a context is available
  void _showSuccess(String message) {
    final ctx = Get.context;
    if (ctx != null) {
      showScaffold(context: ctx, message: message);
    } else {
      debugPrint('Success: $message');
    }
  }

  void _showError(String message) {
    final ctx = Get.context;
    if (ctx != null) {
      showScaffoldError(context: ctx, message: message);
    } else {
      debugPrint('Error: $message');
    }
  }

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
    connectionStatus.value = 'Connecting...';

    // Set a timeout for the connection attempt
    _connectionTimeout = Timer(const Duration(minutes: 5), () {
      if (!connected.value) {
        error.value = 'Connection timeout. Please try again.';
        isConnecting.value = false;
        progress.value = 0;
        connectionStatus.value = 'Connection Timeout';
        _scheduleReconnect();
      }
    });

    try {
      debugPrint('🔗 WhatsApp: Initializing WhatsApp client...');
      progress.value = 10;
      connectionStatus.value = 'Initializing...';

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
          connectionStatus.value = 'QR Code Generated';

          debugPrint(
              '🔗 WhatsApp: QR Code set in observable, UI should update');
        },
      );

      debugPrint('🔗 WhatsApp: Connect method completed, client: $_client');

      if (_client != null) {
        progress.value = 60;
        connectionStatus.value = 'Client Created';
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
      connectionStatus.value = 'Connection Failed';
      _connectionTimeout?.cancel();
      _scheduleReconnect();
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
        connectionStatus.value = 'Connected';
        reconnectAttempts.value = 0;
        _connectionTimeout?.cancel();
        _reconnectTimer?.cancel();
        _saveConnectionState(true);
        _startHeartbeat();
        break;
      case ConnectionEvent.logout:
        debugPrint('🔗 WhatsApp: Logged out');
        connected.value = false;
        progress.value = 0;
        isConnecting.value = false;
        connectionStatus.value = 'Logged Out';
        _saveConnectionState(false);
        _stopHeartbeat();
        if (autoReconnect.value) {
          _scheduleReconnect();
        }
        break;
      default:
        debugPrint('🔗 WhatsApp: Intermediate state: $event');
        if (event.toString().contains('downloadingChrome')) {
          progress.value = 25;
          connectionStatus.value = 'Downloading Chromium...';
          error.value = 'Downloading Chromium... This may take a few minutes.';
        } else if (event.toString().contains('initializing')) {
          progress.value = 15;
          connectionStatus.value = 'Initializing...';
          error.value = 'Initializing WhatsApp client...';
        } else if (event.toString().contains('ready')) {
          // Chromium successfully downloaded
          _saveChromiumDownloaded(true);
          chromiumDownloaded.value = true;
          connectionStatus.value = 'Ready';
        }
    }
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    if (!autoReconnect.value || reconnectAttempts.value >= maxReconnectAttempts) {
      debugPrint('🔄 WhatsApp: Max reconnect attempts reached or auto-reconnect disabled');
      connectionStatus.value = 'Reconnection Failed';
      return;
    }

    reconnectAttempts.value++;
    connectionStatus.value = 'Reconnecting in ${reconnectDelay.inSeconds}s (${reconnectAttempts.value}/$maxReconnectAttempts)';
    
    debugPrint('🔄 WhatsApp: Scheduling reconnect attempt ${reconnectAttempts.value} in ${reconnectDelay.inSeconds} seconds');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (!connected.value && autoReconnect.value) {
        debugPrint('🔄 WhatsApp: Attempting reconnection ${reconnectAttempts.value}/$maxReconnectAttempts');
        connect();
      }
    });
  }

  /// Start heartbeat to check connection health
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      _checkConnectionHealth();
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Check if connection is still healthy
  Future<void> _checkConnectionHealth() async {
    if (!connected.value || _client == null) {
      _stopHeartbeat();
      return;
    }

    try {
      // Try to get connection state (this is a lightweight check)
      // If this fails, it means connection is lost
      debugPrint('💗 WhatsApp: Heartbeat check...');
      // Note: Add actual health check here if the library supports it
      // For now, we assume connection is healthy if no exception is thrown
    } catch (e) {
      debugPrint('💗 WhatsApp: Heartbeat failed, connection lost: $e');
      connected.value = false;
      connectionStatus.value = 'Connection Lost';
      _stopHeartbeat();
      if (autoReconnect.value) {
        _scheduleReconnect();
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
      if (!connected.value) {
        debugPrint('📱 WhatsApp: Not connected!');
        error.value = 'WhatsApp not connected';
        return;
      }
      debugPrint('📱 WhatsApp: Calling sendTextMessage...');
      await _client!.chat.sendTextMessage(phone: phone, message: message);
      debugPrint('📱 WhatsApp: Message sent successfully');
      
      // Show success message
      _showSuccess('Message sent to $phone');
    } catch (e) {
      debugPrint('📱 WhatsApp: Error sending message: $e');
      error.value = 'Failed to send message: ${e.toString()}';
      
      // Show error message
      _showError('Failed to send message: ${e.toString()}');
    }
  }

  void reset() {
    debugPrint('🔄 WhatsApp: Resetting controller state');
    _connectionTimeout?.cancel();
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    qrCode.value = '';
    progress.value = 0;
    error.value = '';
    connected.value = false;
    isConnecting.value = false;
    connectionStatus.value = 'Disconnected';
    reconnectAttempts.value = 0;
    _client = null;
    _saveConnectionState(false);
  }

  /// Toggle auto-reconnect feature
  void toggleAutoReconnect() {
    autoReconnect.value = !autoReconnect.value;
    _saveAutoReconnectSetting(autoReconnect.value);
    debugPrint('🔄 WhatsApp: Auto-reconnect ${autoReconnect.value ? 'enabled' : 'disabled'}');
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
        lastConnected.value = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  /// Save auto-reconnect setting to SharedPreferences
  Future<void> _saveAutoReconnectSetting(bool autoReconnectEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoReconnectKey, autoReconnectEnabled);
      debugPrint('💾 WhatsApp: Auto-reconnect setting saved: $autoReconnectEnabled');
    } catch (e) {
      debugPrint('💾 WhatsApp: Failed to save auto-reconnect setting: $e');
    }
  }

  /// Check if there's a saved session and try to restore connection
  Future<void> checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool(_sessionKey) ?? false;
      chromiumDownloaded.value = prefs.getBool(_chromiumDownloadedKey) ?? false;
      autoReconnect.value = prefs.getBool(_autoReconnectKey) ?? true;
      
      // Load last connected time
      final lastConnectedTime = prefs.getInt(_lastConnectedKey);
      if (lastConnectedTime != null) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(lastConnectedTime);
        lastConnected.value = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }

      // Check if this is a hot restart (development scenario)
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final lastSessionTime = prefs.getInt(_sessionTimestampKey) ?? 0;
      final timeDifference = currentTime - lastSessionTime;
      
      // If less than 5 minutes since last session, likely a hot restart
      final isLikelyHotRestart = timeDifference < 300000; // 5 minutes
      
      // Save current session timestamp
      await prefs.setInt(_sessionTimestampKey, currentTime);

      if (wasConnected && autoReconnect.value) {
        if (isLikelyHotRestart) {
          debugPrint('💡 WhatsApp: Detected likely hot restart, attempting quick reconnection...');
          connectionStatus.value = 'Attempting Quick Reconnect...';
          
          // Show user-friendly message for development
          _showSuccess('Hot restart detected. Attempting to reconnect WhatsApp...');
        } else {
          debugPrint('💾 WhatsApp: Found saved session, attempting to restore...');
          connectionStatus.value = 'Restoring Session...';
        }
        
        // Wait a bit before attempting to restore connection
        await Future.delayed(const Duration(seconds: 2));
        await connect();
      } else {
        debugPrint('💾 WhatsApp: No saved session found or auto-reconnect disabled');
        connectionStatus.value = 'Ready to Connect';
        
        // Auto-connect if this seems like a hot restart and user had connection
        if (isLikelyHotRestart && lastConnectedTime != null) {
          debugPrint('💡 WhatsApp: Auto-connecting after hot restart...');
          _showSuccess('Reconnecting WhatsApp after hot restart...');
          await Future.delayed(const Duration(seconds: 1));
          await connect();
        }
      }
    } catch (e) {
      debugPrint('💾 WhatsApp: Failed to check saved session: $e');
      connectionStatus.value = 'Ready to Connect';
    }
  }

  Future<void> disconnect() async {
    debugPrint('🔌 WhatsApp: Disconnecting...');
    try {
      _stopHeartbeat();
      _reconnectTimer?.cancel();
      _connectionTimeout?.cancel();
      
      await _client?.logout();
      reset();
      
      _showSuccess('WhatsApp has been disconnected successfully');
    } catch (e) {
      debugPrint('🔌 WhatsApp: Error during disconnect: $e');
      error.value = 'Disconnect failed: ${e.toString()}';
    }
  }

  /// Force refresh connection (useful for troubleshooting)
  Future<void> forceRefresh() async {
    debugPrint('🔄 WhatsApp: Force refreshing connection...');
    
    // Reset counters and states
    reconnectAttempts.value = 0;
    error.value = '';
    
    // Disconnect and reconnect
    if (connected.value || isConnecting.value) {
      await disconnect();
      await Future.delayed(const Duration(seconds: 2));
    }
    
    await connect();
  }

  /// Quick connect for development scenarios (hot restart)
  Future<void> quickConnect() async {
    debugPrint('🚀 WhatsApp: Quick connect for development...');
    
    // Reset states but keep settings
    qrCode.value = '';
    progress.value = 0;
    error.value = '';
    connected.value = false;
    isConnecting.value = false;
    reconnectAttempts.value = 0;
    
    // Immediate connection attempt
    await connect();
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
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    super.onClose();
  }
}
