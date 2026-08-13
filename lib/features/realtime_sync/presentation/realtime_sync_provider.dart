import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_api.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_cursor_store.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_repository.dart';
import 'package:pos_machine/features/realtime_sync/data/reverb_client.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_config.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/features/realtime_sync/domain/sync_operation_gate.dart';
import 'package:pos_machine/providers/sync_provider.dart';

class RealtimeSyncProvider extends ChangeNotifier {
  RealtimeSyncProvider({
    required RealtimeSyncRepository repository,
    required SyncProvider manualSync,
    RealtimeSyncConfig? config,
    RealtimeSyncApi? api,
    RealtimeSyncCursorStore cursorStore = const RealtimeSyncCursorStore(),
  })  : _repository = repository,
        _manualSync = manualSync,
        _config = config ?? RealtimeSyncConfig.production(),
        _api = api ?? RealtimeSyncApi(),
        _cursorStore = cursorStore {
    _client = ReverbClient(config: _config, api: _api);
    _eventSubscription = _client.events.listen(_handleEvent);
    _subscribedSubscription =
        _client.subscriptionSucceeded.listen((_) => _handleSubscribed());
    _errorSubscription = _client.errors.listen(_handleSocketError);
    _manualSync.addListener(_handleManualSyncChanged);
    if (!_config.enabled) {
      _status = RealtimeSyncStatus.disabled;
    }
  }

  final RealtimeSyncRepository _repository;
  final SyncProvider _manualSync;
  final RealtimeSyncConfig _config;
  final RealtimeSyncApi _api;
  final RealtimeSyncCursorStore _cursorStore;
  late final ReverbClient _client;

  StreamSubscription<RealtimeDataChanged>? _eventSubscription;
  StreamSubscription<void>? _subscribedSubscription;
  StreamSubscription<Object>? _errorSubscription;
  Timer? _eventDebounce;
  Timer? _reconnectTimer;

  RealtimeSyncSession? _session;
  RealtimeSyncStatus _status = RealtimeSyncStatus.stopped;
  String? _lastError;
  String? _lastSyncedAt;
  DateTime? _lastSuccessfulSync;
  bool _online = true;
  bool _pulling = false;
  bool _pullPending = false;
  bool _paused = false;
  bool _disposed = false;
  int _generation = 0;
  int _reconnectAttempt = 0;
  final Object _syncGateOwner = Object();

  RealtimeSyncStatus get status => _status;
  String? get lastError => _lastError;
  String? get lastSyncedAt => _lastSyncedAt;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  bool get isRunning => _session != null && _config.enabled;
  bool get isSubscribed => _client.isSubscribed;

  Future<void> start(RealtimeSyncSession session) async {
    if (!_config.enabled || _disposed) {
      _setStatus(RealtimeSyncStatus.disabled);
      return;
    }

    final sameSession = _isSameSession(_session, session);
    if (!sameSession) {
      await stop();
      _session = session;
      _generation++;
      _lastSyncedAt = await _cursorStore.read(
        companyId: session.companyId,
        storeId: session.storeId,
      );
    }

    if (!_online || _paused) {
      _setStatus(RealtimeSyncStatus.offline);
      return;
    }

    await catchUp();
    await _connect();
  }

  Future<void> stop() async {
    _generation++;
    SyncOperationGate.instance.release(_syncGateOwner);
    _eventDebounce?.cancel();
    _reconnectTimer?.cancel();
    _pullPending = false;
    _reconnectAttempt = 0;
    _session = null;
    await _client.disconnect();
    if (!_disposed) {
      _setStatus(
        _config.enabled
            ? RealtimeSyncStatus.stopped
            : RealtimeSyncStatus.disabled,
      );
    }
  }

  Future<void> pause() async {
    _paused = true;
    _reconnectTimer?.cancel();
    await _client.disconnect();
    if (_session != null) _setStatus(RealtimeSyncStatus.stopped);
  }

  Future<void> resume() async {
    _paused = false;
    if (_session == null || !_online) return;
    await catchUp();
    await _connect();
  }

  Future<void> setOnline(bool online) async {
    if (_online == online) return;
    _online = online;
    if (!online) {
      _reconnectTimer?.cancel();
      await _client.disconnect();
      if (_session != null) _setStatus(RealtimeSyncStatus.offline);
      return;
    }
    if (_session != null && !_paused) {
      await catchUp();
      await _connect();
    }
  }

  Future<void> catchUp() async {
    final session = _session;
    if (session == null || !_online || _paused || _disposed) return;
    if (_manualSync.isSyncing) {
      _pullPending = true;
      _setStatus(RealtimeSyncStatus.waitingForManualSync);
      return;
    }
    if (_pulling) {
      _pullPending = true;
      return;
    }
    if (!SyncOperationGate.instance.tryAcquire(_syncGateOwner)) {
      _pullPending = true;
      _setStatus(RealtimeSyncStatus.waitingForManualSync);
      _schedulePendingCatchUp();
      return;
    }

    final generation = _generation;
    _pulling = true;
    _pullPending = false;
    _lastError = null;
    _setStatus(RealtimeSyncStatus.syncing);

    try {
      final response = await _api.pullChanges(
        session: session,
        since: _lastSyncedAt,
      );
      if (!_isCurrent(generation, session)) return;

      await _repository.apply(
        session: session,
        changes: response.changes,
        updatedFrom: _lastSyncedAt,
        updatedTo: response.syncedAt,
        isCurrent: () => _isCurrent(generation, session),
      );
      if (!_isCurrent(generation, session)) return;

      await _cursorStore.write(
        companyId: session.companyId,
        storeId: session.storeId,
        syncedAt: response.syncedAt,
      );
      _lastSyncedAt = response.syncedAt;
      _lastSuccessfulSync = DateTime.now();
      _setStatus(
        _client.isSubscribed
            ? RealtimeSyncStatus.subscribed
            : RealtimeSyncStatus.stopped,
      );
    } on RealtimeSyncDeferredException catch (error) {
      _lastError = error.message;
      _pullPending = true;
      _setStatus(RealtimeSyncStatus.waitingForCart);
      _schedulePendingCatchUp();
    } on RealtimeSyncException catch (error) {
      _lastError = error.message;
      _setStatus(
        error.terminal
            ? RealtimeSyncStatus.authenticationError
            : RealtimeSyncStatus.error,
      );
      if (!error.terminal) _scheduleReconnect();
    } catch (error) {
      _lastError = error.toString();
      _setStatus(RealtimeSyncStatus.error);
      _scheduleReconnect();
    } finally {
      _pulling = false;
      SyncOperationGate.instance.release(_syncGateOwner);
      if (_pullPending &&
          _session != null &&
          !_manualSync.isSyncing &&
          _online &&
          !_paused) {
        unawaited(catchUp());
      }
    }
  }

  Future<void> _connect() async {
    final session = _session;
    if (session == null ||
        _client.isSubscribed ||
        !_online ||
        _paused ||
        _disposed) {
      return;
    }
    _setStatus(RealtimeSyncStatus.connecting);
    try {
      await _client.connect(session);
    } on FormatException catch (error) {
      _lastError = error.message;
      _setStatus(RealtimeSyncStatus.configurationError);
    } catch (error) {
      _lastError = error.toString();
      _setStatus(RealtimeSyncStatus.error);
      _scheduleReconnect();
    }
  }

  void _handleEvent(RealtimeDataChanged event) {
    final session = _session;
    if (session == null || event.companyId != session.companyId) return;
    if (event.storeId != null && event.storeId != session.storeId) return;
    _eventDebounce?.cancel();
    _eventDebounce = Timer(
      _config.eventDebounce,
      () => unawaited(catchUp()),
    );
  }

  void _handleSubscribed() {
    _reconnectAttempt = 0;
    _setStatus(RealtimeSyncStatus.subscribed);
    unawaited(catchUp());
  }

  void _handleSocketError(Object error) {
    if (_session == null || _paused || !_online || _disposed) return;
    _lastError = error.toString();
    if (error is RealtimeSyncException && error.terminal) {
      _setStatus(RealtimeSyncStatus.authenticationError);
      return;
    }
    _setStatus(RealtimeSyncStatus.retrying);
    _scheduleReconnect();
  }

  void _handleManualSyncChanged() {
    if (!_manualSync.isSyncing && _pullPending && _session != null) {
      unawaited(catchUp());
    }
  }

  void _schedulePendingCatchUp() {
    if (_reconnectTimer?.isActive == true || _disposed) return;
    final waitingForCart = _status == RealtimeSyncStatus.waitingForCart;
    _reconnectTimer = Timer(Duration(seconds: waitingForCart ? 5 : 1), () {
      if (_pullPending && _session != null && !_manualSync.isSyncing) {
        unawaited(catchUp());
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true ||
        _session == null ||
        !_online ||
        _paused ||
        _disposed) {
      return;
    }
    _setStatus(RealtimeSyncStatus.retrying);
    final seconds = min(
      _config.maxReconnectDelay.inSeconds,
      pow(2, _reconnectAttempt).toInt(),
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: max(1, seconds)), () async {
      await _client.disconnect();
      await catchUp();
      await _connect();
    });
  }

  bool _isCurrent(int generation, RealtimeSyncSession session) =>
      !_disposed &&
      generation == _generation &&
      _isSameSession(_session, session);

  bool _isSameSession(
    RealtimeSyncSession? first,
    RealtimeSyncSession? second,
  ) =>
      first != null &&
      second != null &&
      first.companyId == second.companyId &&
      first.storeId == second.storeId &&
      first.backendBaseUrl == second.backendBaseUrl &&
      first.tenantApiKey == second.tenantApiKey &&
      first.accessToken == second.accessToken;

  void _setStatus(RealtimeSyncStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    SyncOperationGate.instance.release(_syncGateOwner);
    _eventDebounce?.cancel();
    _reconnectTimer?.cancel();
    _manualSync.removeListener(_handleManualSyncChanged);
    unawaited(_eventSubscription?.cancel());
    unawaited(_subscribedSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_client.dispose());
    _api.close();
    super.dispose();
  }
}
