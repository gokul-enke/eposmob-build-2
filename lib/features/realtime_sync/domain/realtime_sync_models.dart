enum RealtimeSyncEntity {
  customers,
  products,
  stocks,
  orders,
}

class EntityChangeSet {
  const EntityChangeSet({
    this.upserted = const <int>[],
    this.deleted = const <int>[],
  });

  final List<int> upserted;
  final List<int> deleted;

  bool get hasChanges => upserted.isNotEmpty || deleted.isNotEmpty;

  factory EntityChangeSet.fromJson(dynamic value) {
    if (value is! Map) return const EntityChangeSet();
    return EntityChangeSet(
      upserted: _parseIds(value['upserted']),
      deleted: _parseIds(value['deleted']),
    );
  }

  static List<int> _parseIds(dynamic value) {
    if (value is! List) return const <int>[];
    return value
        .map((item) => item is int ? item : int.tryParse(item.toString()))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }
}

class RealtimeChangeSet {
  const RealtimeChangeSet({
    this.customers = const EntityChangeSet(),
    this.products = const EntityChangeSet(),
    this.stocks = const EntityChangeSet(),
    this.orders = const EntityChangeSet(),
  });

  final EntityChangeSet customers;
  final EntityChangeSet products;
  final EntityChangeSet stocks;
  final EntityChangeSet orders;

  bool get hasChanges =>
      customers.hasChanges ||
      products.hasChanges ||
      stocks.hasChanges ||
      orders.hasChanges;

  bool get hasCatalogChanges => products.hasChanges || stocks.hasChanges;

  factory RealtimeChangeSet.fromJson(dynamic value) {
    if (value is! Map) return const RealtimeChangeSet();
    return RealtimeChangeSet(
      customers: EntityChangeSet.fromJson(value['customers']),
      products: EntityChangeSet.fromJson(value['products']),
      stocks: EntityChangeSet.fromJson(value['stocks']),
      orders: EntityChangeSet.fromJson(value['orders']),
    );
  }
}

class SyncChangesResponse {
  const SyncChangesResponse({
    required this.syncedAt,
    required this.changes,
  });

  final String syncedAt;
  final RealtimeChangeSet changes;

  factory SyncChangesResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) {
      throw const FormatException('Sync response did not report success.');
    }
    final syncedAt = json['synced_at']?.toString().trim() ?? '';
    if (syncedAt.isEmpty || DateTime.tryParse(syncedAt) == null) {
      throw const FormatException('Sync response has an invalid synced_at.');
    }
    if (json['changes'] is! Map) {
      throw const FormatException('Sync response has no changes object.');
    }
    return SyncChangesResponse(
      syncedAt: syncedAt,
      changes: RealtimeChangeSet.fromJson(json['changes']),
    );
  }
}

class RealtimeDataChanged {
  const RealtimeDataChanged({
    required this.entity,
    required this.action,
    required this.id,
    required this.companyId,
    this.storeId,
    this.changedAt,
  });

  final String entity;
  final String action;
  final int id;
  final int companyId;
  final int? storeId;
  final String? changedAt;

  factory RealtimeDataChanged.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final companyId = _parseInt(json['company_id']);
    final entity = json['entity']?.toString().trim() ?? '';
    final action = json['action']?.toString().trim() ?? '';
    if (id == null || companyId == null || entity.isEmpty || action.isEmpty) {
      throw const FormatException('Invalid data.changed payload.');
    }
    return RealtimeDataChanged(
      entity: entity,
      action: action,
      id: id,
      companyId: companyId,
      storeId: _parseInt(json['store_id']),
      changedAt: json['changed_at']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}

enum RealtimeSyncStatus {
  disabled,
  stopped,
  offline,
  connecting,
  authorizing,
  subscribed,
  syncing,
  waitingForManualSync,
  waitingForCart,
  retrying,
  authenticationError,
  configurationError,
  error,
}

class RealtimeSyncSession {
  const RealtimeSyncSession({
    required this.backendBaseUrl,
    required this.companyId,
    required this.storeId,
    required this.tenantApiKey,
    required this.accessToken,
  });

  final String backendBaseUrl;
  final int companyId;
  final int storeId;
  final String tenantApiKey;
  final String accessToken;

  String get channelName => 'private-company.$companyId.sync';
}

class RealtimeSyncException implements Exception {
  const RealtimeSyncException(this.message, {this.terminal = false});

  final String message;
  final bool terminal;

  @override
  String toString() => message;
}

class RealtimeSyncDeferredException extends RealtimeSyncException {
  const RealtimeSyncDeferredException(super.message);
}
