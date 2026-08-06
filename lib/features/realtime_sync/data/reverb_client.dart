import 'dart:async';
import 'dart:convert';

import 'package:pos_machine/features/realtime_sync/data/realtime_sync_api.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_config.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

class ReverbClient {
  ReverbClient({
    required RealtimeSyncConfig config,
    required RealtimeSyncApi api,
    WebSocketChannelFactory? channelFactory,
  })  : _config = config,
        _api = api,
        _channelFactory =
            channelFactory ?? ((uri) => WebSocketChannel.connect(uri));

  final RealtimeSyncConfig _config;
  final RealtimeSyncApi _api;
  final WebSocketChannelFactory _channelFactory;

  final _events = StreamController<RealtimeDataChanged>.broadcast();
  final _subscriptions = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  RealtimeSyncSession? _session;
  bool _closedByClient = false;
  bool _connecting = false;
  bool _subscribed = false;

  Stream<RealtimeDataChanged> get events => _events.stream;
  Stream<void> get subscriptionSucceeded => _subscriptions.stream;
  Stream<Object> get errors => _errors.stream;
  bool get isSubscribed => _subscribed;

  Future<void> connect(RealtimeSyncSession session) async {
    if (_connecting) return;
    if (_subscribed && _isSameSession(_session, session)) return;

    await disconnect();
    _session = session;
    _closedByClient = false;
    _connecting = true;

    try {
      final channel = _channelFactory(
        _config.websocketUri(session.backendBaseUrl),
      );
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 15));
      if (_closedByClient || _channel != channel) return;

      _subscription = channel.stream.listen(
        _handleFrame,
        onError: (Object error, StackTrace stackTrace) {
          _subscribed = false;
          if (!_closedByClient) _errors.add(error);
        },
        onDone: () {
          _subscribed = false;
          if (!_closedByClient) {
            _errors.add(
              RealtimeSyncException(
                'Realtime socket closed (${channel.closeCode ?? 'unknown'}).',
              ),
            );
          }
        },
        cancelOnError: false,
      );
    } finally {
      _connecting = false;
    }
  }

  Future<void> _handleFrame(dynamic frame) async {
    try {
      final raw = frame is String ? frame : utf8.decode(frame as List<int>);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final message = Map<String, dynamic>.from(decoded);
      final event = message['event']?.toString();

      switch (event) {
        case 'pusher:connection_established':
          final data = _decodeObject(message['data']);
          final socketId = data?['socket_id']?.toString().trim() ?? '';
          final session = _session;
          if (socketId.isEmpty || session == null) {
            throw const RealtimeSyncException(
              'Realtime handshake returned no socket ID.',
            );
          }
          final auth = await _api.authorizeChannel(
            session: session,
            socketId: socketId,
          );
          _send({
            'event': 'pusher:subscribe',
            'data': {
              'auth': auth,
              'channel': session.channelName,
            },
          });
          break;
        case 'pusher_internal:subscription_succeeded':
          _subscribed = true;
          _subscriptions.add(null);
          break;
        case 'pusher:ping':
          _send({'event': 'pusher:pong'});
          break;
        case 'pusher:error':
        case 'pusher_internal:subscription_error':
          throw RealtimeSyncException(
            'Realtime subscription error: ${message['data']}',
          );
        case 'data.changed':
          final data = _decodeObject(message['data']);
          if (data != null) {
            _events.add(RealtimeDataChanged.fromJson(data));
          }
          break;
      }
    } catch (error) {
      if (!_closedByClient) _errors.add(error);
    }
  }

  Map<String, dynamic>? _decodeObject(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  void _send(Map<String, dynamic> frame) {
    _channel?.sink.add(jsonEncode(frame));
  }

  Future<void> disconnect() async {
    _closedByClient = true;
    _subscribed = false;
    _connecting = false;
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    try {
      await Future.wait<void>([
        if (subscription != null) subscription.cancel(),
        if (channel != null) channel.sink.close(),
      ]).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Local state is already detached. A stuck platform socket must not
      // block store switching, logout, or application lifecycle changes.
    } catch (_) {
      // Socket cleanup is best-effort because the remote endpoint may be
      // absent, already closed, or unreachable.
    }
  }

  bool _isSameSession(
    RealtimeSyncSession? first,
    RealtimeSyncSession second,
  ) =>
      first != null &&
      first.companyId == second.companyId &&
      first.storeId == second.storeId &&
      first.backendBaseUrl == second.backendBaseUrl &&
      first.tenantApiKey == second.tenantApiKey &&
      first.accessToken == second.accessToken;

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _subscriptions.close();
    await _errors.close();
  }
}
