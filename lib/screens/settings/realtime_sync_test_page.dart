import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Temporary diagnostics page for validating the backend Reverb contract.
///
/// This page intentionally does not update providers, Hive, carts, or the
/// production sync cursor. It is safe to remove after realtime sync is wired
/// into the application lifecycle.
class RealtimeSyncTestPage extends StatefulWidget {
  const RealtimeSyncTestPage({super.key});

  @override
  State<RealtimeSyncTestPage> createState() => _RealtimeSyncTestPageState();
}

class _RealtimeSyncTestPageState extends State<RealtimeSyncTestPage> {
  static const _defaultReverbAppKey = 'suyff1hnmw1pbtpnd48u';
  static const _defaultReverbPort = 443;
  static const _defaultCompanyId = 2;

  final _formKey = GlobalKey<FormState>();
  final _backendController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController =
      TextEditingController(text: _defaultReverbPort.toString());
  final _appKeyController = TextEditingController(text: _defaultReverbAppKey);
  final _companyIdController =
      TextEditingController(text: _defaultCompanyId.toString());
  final _apiKeyController = TextEditingController();
  final _sinceController = TextEditingController();

  final List<_RealtimeLogEntry> _logs = <_RealtimeLogEntry>[];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pullDebounce;

  bool _loadingPreferences = true;
  bool _connecting = false;
  bool _connected = false;
  bool _subscribed = false;
  bool _pulling = false;
  bool _useTls = true;
  bool _autoPull = true;
  bool _obscureApiKey = true;
  String? _socketId;
  String? _lastEvent;
  String? _lastSyncedAt;
  Map<String, dynamic>? _lastChanges;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _pullDebounce?.cancel();
    unawaited(_socketSubscription?.cancel());
    unawaited(_channel?.sink.close());
    _backendController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _appKeyController.dispose();
    _companyIdController.dispose();
    _apiKeyController.dispose();
    _sinceController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backend = APPUrl.normalizeBaseUrl(APPUrl.baseURL);
      final backendUri = Uri.tryParse(backend);

      _backendController.text = backend;
      _hostController.text = backendUri?.host ?? '';
      _portController.text = _defaultReverbPort.toString();
      _appKeyController.text = _defaultReverbAppKey;
      _useTls = true;
      _companyIdController.text = prefs.getInt('company_id')?.toString() ??
          _defaultCompanyId.toString();
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _sinceController.text = prefs.getString('realtime_test_since') ?? '';
      _addLog(
        'Loaded the verified wss/443 Reverb defaults and current tenant session.',
        _RealtimeLogLevel.info,
      );
    } catch (error) {
      _addLog('Could not load defaults: $error', _RealtimeLogLevel.error);
    } finally {
      if (mounted) {
        setState(() => _loadingPreferences = false);
      }
    }
  }

  Future<void> _saveConnectionDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'realtime_test_app_key',
      _appKeyController.text.trim(),
    );
    await prefs.setString(
      'realtime_test_host',
      _hostController.text.trim(),
    );
    await prefs.setInt(
      'realtime_test_port',
      int.tryParse(_portController.text.trim()) ?? _defaultReverbPort,
    );
    await prefs.setBool('realtime_test_tls', _useTls);
  }

  Uri _buildWebSocketUri() {
    final host = _hostController.text.trim();
    final appKey = _appKeyController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ?? _defaultReverbPort;
    return Uri(
      scheme: _useTls ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/app/$appKey',
      queryParameters: const {
        'protocol': '7',
        'client': 'flutter',
        'version': '1.0',
      },
    );
  }

  String get _channelName =>
      'private-company.${_companyIdController.text.trim()}.sync';

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _disconnect(logMessage: false);
    if (!mounted) return;

    setState(() {
      _connecting = true;
      _connected = false;
      _subscribed = false;
      _socketId = null;
    });

    try {
      await _saveConnectionDefaults();
      final uri = _buildWebSocketUri();
      _addLog('Opening $uri', _RealtimeLogLevel.info);

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 15));
      if (!mounted || _channel != channel) return;

      setState(() {
        _connecting = false;
        _connected = true;
      });
      _addLog('WebSocket connected', _RealtimeLogLevel.success);

      _socketSubscription = channel.stream.listen(
        _handleSocketFrame,
        onError: (Object error, StackTrace stackTrace) {
          _addLog('WebSocket error: $error', _RealtimeLogLevel.error);
          _markDisconnected();
        },
        onDone: () {
          _addLog(
            'WebSocket closed (code ${channel.closeCode ?? '-'}'
            '${channel.closeReason == null ? '' : ', ${channel.closeReason}'})',
            _RealtimeLogLevel.warning,
          );
          _markDisconnected();
        },
        cancelOnError: false,
      );
    } catch (error) {
      _addLog('Connection failed: $error', _RealtimeLogLevel.error);
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = false;
          _subscribed = false;
        });
      }
      await _channel?.sink.close();
      _channel = null;
    }
  }

  Future<void> _disconnect({bool logMessage = true}) async {
    _pullDebounce?.cancel();
    _pullDebounce = null;

    final subscription = _socketSubscription;
    final channel = _channel;
    _socketSubscription = null;
    _channel = null;

    await subscription?.cancel();
    await channel?.sink.close();

    if (mounted) {
      setState(() {
        _connecting = false;
        _connected = false;
        _subscribed = false;
        _socketId = null;
      });
    }
    if (logMessage && (subscription != null || channel != null)) {
      _addLog('Disconnected by tester', _RealtimeLogLevel.info);
    }
  }

  void _markDisconnected() {
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connected = false;
      _subscribed = false;
      _socketId = null;
    });
  }

  Future<void> _handleSocketFrame(dynamic frame) async {
    final raw = frame is String ? frame : utf8.decode(frame as List<int>);
    _addLog('RECV $raw', _RealtimeLogLevel.incoming);

    Map<String, dynamic> message;
    try {
      message = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (error) {
      _addLog('Invalid socket JSON: $error', _RealtimeLogLevel.error);
      return;
    }

    final event = message['event']?.toString();
    switch (event) {
      case 'pusher:connection_established':
        final data = _decodeObject(message['data']);
        final socketId = data?['socket_id']?.toString();
        if (socketId == null || socketId.isEmpty) {
          _addLog(
            'Connection frame did not contain socket_id',
            _RealtimeLogLevel.error,
          );
          return;
        }
        if (mounted) setState(() => _socketId = socketId);
        await _authorizeAndSubscribe(socketId);
        break;
      case 'pusher_internal:subscription_succeeded':
        if (mounted) setState(() => _subscribed = true);
        _addLog(
          'Subscribed to $_channelName',
          _RealtimeLogLevel.success,
        );
        break;
      case 'pusher:ping':
        _sendFrame({'event': 'pusher:pong'});
        break;
      case 'pusher:error':
      case 'pusher_internal:subscription_error':
        _addLog(
          'Pusher reported an error: ${message['data']}',
          _RealtimeLogLevel.error,
        );
        break;
      case 'data.changed':
        final eventData = _decodeObject(message['data']);
        if (mounted) {
          setState(() => _lastEvent = eventData == null
              ? message['data']?.toString()
              : const JsonEncoder.withIndent('  ').convert(eventData));
        }
        _addLog('Received data.changed', _RealtimeLogLevel.success);
        if (_autoPull) {
          _pullDebounce?.cancel();
          _pullDebounce = Timer(
            const Duration(milliseconds: 500),
            () => unawaited(_pullChanges()),
          );
        }
        break;
    }
  }

  Map<String, dynamic>? _decodeObject(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _authorizeAndSubscribe(String socketId) async {
    try {
      final backend = APPUrl.normalizeBaseUrl(_backendController.text);
      final uri = Uri.parse('$backend/api/broadcasting/auth');
      _addLog(
        'POST $uri for $_channelName',
        _RealtimeLogLevel.outgoing,
      );

      final response = await http
          .post(
            uri,
            headers: {
              'X-Tenant': _apiKeyController.text.trim(),
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'socket_id': socketId,
              'channel_name': _channelName,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _addLog(
          'Broadcast auth failed (${response.statusCode}): ${response.body}',
          _RealtimeLogLevel.error,
        );
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['auth'] == null) {
        _addLog(
          'Broadcast auth response has no auth token',
          _RealtimeLogLevel.error,
        );
        return;
      }

      _sendFrame({
        'event': 'pusher:subscribe',
        'data': {
          'auth': payload['auth'].toString(),
          'channel': _channelName,
        },
      });
    } catch (error) {
      _addLog('Broadcast auth error: $error', _RealtimeLogLevel.error);
    }
  }

  void _sendFrame(Map<String, dynamic> frame) {
    final encoded = jsonEncode(frame);
    _channel?.sink.add(encoded);
    final event = frame['event'];
    _addLog(
      event == 'pusher:subscribe'
          ? 'SEND pusher:subscribe for $_channelName'
          : 'SEND $encoded',
      _RealtimeLogLevel.outgoing,
    );
  }

  Future<void> _pullChanges() async {
    if (_pulling) {
      _addLog('Pull already in progress; skipped', _RealtimeLogLevel.warning);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _pulling = true);
    try {
      final backend = APPUrl.normalizeBaseUrl(_backendController.text);
      final uri = Uri.parse('$backend/api/v1/sync/changes').replace(
        queryParameters: {'since': _sinceController.text.trim()},
      );
      _addLog('GET $uri', _RealtimeLogLevel.outgoing);

      final response = await http.get(
        uri,
        headers: {
          'X-Tenant': _apiKeyController.text.trim(),
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _addLog(
          'Pull failed (${response.statusCode}): ${response.body}',
          _RealtimeLogLevel.error,
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Response is not a JSON object');
      }
      final payload = Map<String, dynamic>.from(decoded);
      final syncedAt = payload['synced_at']?.toString();
      final changes = payload['changes'];

      if (mounted) {
        setState(() {
          _lastSyncedAt = syncedAt;
          _lastChanges = changes is Map
              ? Map<String, dynamic>.from(changes)
              : <String, dynamic>{};
          if (syncedAt != null && syncedAt.isNotEmpty) {
            _sinceController.text = syncedAt;
          }
        });
      }

      if (syncedAt != null && syncedAt.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('realtime_test_since', syncedAt);
      }

      _addLog(
        'Pull succeeded; synced_at=${syncedAt ?? '-'}',
        _RealtimeLogLevel.success,
      );
    } catch (error) {
      _addLog('Pull error: $error', _RealtimeLogLevel.error);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _clearTestCursor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('realtime_test_since');
    if (!mounted) return;
    setState(() {
      _sinceController.clear();
      _lastSyncedAt = null;
      _lastChanges = null;
    });
    _addLog('Cleared temporary test cursor', _RealtimeLogLevel.info);
  }

  void _addLog(String message, _RealtimeLogLevel level) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        _RealtimeLogEntry(
          time: DateTime.now(),
          message: message,
          level: level,
        ),
      );
      if (_logs.length > 200) {
        _logs.removeRange(200, _logs.length);
      }
    });
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'realtime_sync.validator_required'.tr;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPreferences) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SettingsPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubPageHeader(
            backLabel: 'realtime_sync.back_label'.tr,
            onBack: () => Navigator.of(context).pop(),
            onClose: () => Navigator.of(context).pop(),
            title: 'realtime_sync.title'.tr,
            subtitle: 'realtime_sync.subtitle'.tr,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 14),
                  _buildConnectionCard(),
                  const SizedBox(height: 14),
                  _buildResultCard(),
                  const SizedBox(height: 14),
                  _buildLogsCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _subscribed
        ? 'realtime_sync.status_subscribed'.tr
        : _connected
            ? 'realtime_sync.status_connected'.tr
            : _connecting
                ? 'realtime_sync.status_connecting'.tr
                : 'realtime_sync.status_disconnected'.tr;
    final positive = _subscribed || _connected;

    return SettingsContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'realtime_sync.status_title'.tr,
            subtitle: _subscribed
                ? '${'realtime_sync.status_sub_listening'.tr} $_channelName'
                : 'realtime_sync.status_sub_connect'.tr,
            trailing: SettingsStatusBadge(
              label: status,
              isPositive: positive,
              icon: positive ? Icons.wifi : Icons.wifi_off,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _StatusValue(label: 'realtime_sync.label_socket_id'.tr, value: _socketId ?? '-'),
              _StatusValue(label: 'realtime_sync.label_channel'.tr, value: _channelName),
              _StatusValue(
                label: 'realtime_sync.label_last_synced'.tr,
                value: _lastSyncedAt ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Text(
              'realtime_sync.warning_text'.tr,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6D4C41)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return SettingsContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'realtime_sync.connection_title'.tr,
            subtitle: 'realtime_sync.connection_sub'.tr,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final fieldWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(
                    width: fieldWidth,
                    controller: _backendController,
                    label: 'realtime_sync.field_backend_url'.tr,
                    hint: 'https://tenant.example.com',
                    validator: _required,
                  ),
                  _field(
                    width: fieldWidth,
                    controller: _hostController,
                    label: 'realtime_sync.field_reverb_host'.tr,
                    hint: 'tenant.example.com',
                    validator: _required,
                  ),
                  _field(
                    width: fieldWidth,
                    controller: _portController,
                    label: 'realtime_sync.field_reverb_port'.tr,
                    hint: '443',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final port = int.tryParse(value?.trim() ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return 'realtime_sync.validator_port'.tr;
                      }
                      return null;
                    },
                  ),
                  _field(
                    width: fieldWidth,
                    controller: _appKeyController,
                    label: 'realtime_sync.field_app_key'.tr,
                    hint: 'REVERB_APP_KEY',
                    validator: _required,
                  ),
                  _field(
                    width: fieldWidth,
                    controller: _companyIdController,
                    label: 'realtime_sync.field_company_id'.tr,
                    hint: '1',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final id = int.tryParse(value?.trim() ?? '');
                      return id == null || id <= 0
                          ? 'realtime_sync.validator_company_id'.tr
                          : null;
                    },
                  ),
                  _field(
                    width: fieldWidth,
                    controller: _apiKeyController,
                    label: 'realtime_sync.field_api_key'.tr,
                    hint: 'Current company API key',
                    obscureText: _obscureApiKey,
                    validator: _required,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureApiKey = !_obscureApiKey,
                      ),
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  _field(
                    width: constraints.maxWidth,
                    controller: _sinceController,
                    label: 'realtime_sync.field_since_cursor'.tr,
                    hint: 'Empty for first pull',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _useTls,
                    activeThumbColor: ColorManager.kPrimaryColor,
                    onChanged: _connected || _connecting
                        ? null
                        : (value) => setState(() => _useTls = value),
                  ),
                  Text(_useTls ? 'realtime_sync.toggle_secure_ws'.tr : 'realtime_sync.toggle_plain_ws'.tr),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _autoPull,
                    activeThumbColor: ColorManager.kPrimaryColor,
                    onChanged: (value) => setState(() => _autoPull = value),
                  ),
                  Text('realtime_sync.toggle_auto_pull'.tr),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _connecting ? null : (_connected ? null : _connect),
                icon: _connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cable),
                label: Text(_connecting ? 'realtime_sync.btn_connecting'.tr : 'realtime_sync.btn_connect'.tr),
              ),
              OutlinedButton.icon(
                onPressed: _connected || _connecting ? _disconnect : null,
                icon: const Icon(Icons.link_off),
                label: Text('realtime_sync.btn_disconnect'.tr),
              ),
              OutlinedButton.icon(
                onPressed: _pulling ? null : _pullChanges,
                icon: _pulling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_pulling ? 'realtime_sync.btn_pulling'.tr : 'realtime_sync.btn_pull'.tr),
              ),
              TextButton.icon(
                onPressed: _clearTestCursor,
                icon: const Icon(Icons.restart_alt),
                label: Text('realtime_sync.btn_clear_cursor'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SizedBox _field({
    required double width,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final prettyChanges = _lastChanges == null
        ? 'realtime_sync.result_no_response'.tr
        : const JsonEncoder.withIndent('  ').convert(_lastChanges);

    return SettingsContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'realtime_sync.result_title'.tr,
            subtitle: 'realtime_sync.result_sub'.tr,
          ),
          const SizedBox(height: 12),
          Text(
            'realtime_sync.result_last_event'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _CodePanel(text: _lastEvent ?? 'realtime_sync.result_no_event'.tr),
          const SizedBox(height: 12),
          Text(
            'realtime_sync.result_last_payload'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _CodePanel(text: prettyChanges),
        ],
      ),
    );
  }

  Widget _buildLogsCard() {
    return SettingsContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'realtime_sync.log_title'.tr,
            subtitle: 'realtime_sync.log_sub'.tr,
            trailing: TextButton.icon(
              onPressed:
                  _logs.isEmpty ? null : () => setState(() => _logs.clear()),
              icon: const Icon(Icons.clear_all),
              label: Text('realtime_sync.log_btn_clear'.tr),
            ),
          ),
          const SizedBox(height: 10),
          if (_logs.isEmpty)
            Text('realtime_sync.log_empty'.tr)
          else
            ..._logs.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(entry.level.icon, size: 16, color: entry.level.color),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text(
                        entry.time.toIso8601String().substring(11, 19),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        entry.message,
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 70, maxHeight: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E5EB)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _RealtimeLogEntry {
  const _RealtimeLogEntry({
    required this.time,
    required this.message,
    required this.level,
  });

  final DateTime time;
  final String message;
  final _RealtimeLogLevel level;
}

enum _RealtimeLogLevel {
  info(Icons.info_outline, Color(0xFF1565C0)),
  success(Icons.check_circle_outline, Color(0xFF2E7D32)),
  warning(Icons.warning_amber_outlined, Color(0xFFEF6C00)),
  error(Icons.error_outline, Color(0xFFC62828)),
  incoming(Icons.south_west, Color(0xFF00838F)),
  outgoing(Icons.north_east, Color(0xFF6A1B9A));

  const _RealtimeLogLevel(this.icon, this.color);

  final IconData icon;
  final Color color;
}
