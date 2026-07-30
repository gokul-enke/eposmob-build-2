import 'package:pos_machine/resources/app_url.dart';

class RealtimeSyncConfig {
  const RealtimeSyncConfig({
    required this.appKey,
    this.enabled = true,
    this.hostOverride = '',
    this.port = 443,
    this.useTls = true,
    this.eventDebounce = const Duration(milliseconds: 500),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });

  static const String defaultAppKey = 'suyff1hnmw1pbtpnd48u';

  final String appKey;
  final bool enabled;
  final String hostOverride;
  final int port;
  final bool useTls;
  final Duration eventDebounce;
  final Duration maxReconnectDelay;

  factory RealtimeSyncConfig.production() {
    return const RealtimeSyncConfig(
      appKey: String.fromEnvironment(
        'REVERB_APP_KEY',
        defaultValue: defaultAppKey,
      ),
      enabled: bool.fromEnvironment(
        'REALTIME_SYNC_ENABLED',
        defaultValue: true,
      ),
      hostOverride: String.fromEnvironment('REVERB_HOST'),
      port: int.fromEnvironment('REVERB_PORT', defaultValue: 443),
      useTls: bool.fromEnvironment('REVERB_USE_TLS', defaultValue: true),
    );
  }

  Uri websocketUri(String backendBaseUrl) {
    final backend = Uri.tryParse(APPUrl.normalizeBaseUrl(backendBaseUrl));
    final host =
        hostOverride.trim().isNotEmpty ? hostOverride.trim() : backend?.host;
    if (host == null || host.isEmpty) {
      throw const FormatException('Realtime sync host is not configured.');
    }
    if (appKey.trim().isEmpty) {
      throw const FormatException('Realtime sync app key is not configured.');
    }
    return Uri(
      scheme: useTls ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/app/${appKey.trim()}',
      queryParameters: const {
        'protocol': '7',
        'client': 'flutter',
        'version': '1.0',
      },
    );
  }
}
