import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The two identifiers allocated before a local-first sale is persisted.
///
/// [clientSaleId] is the immutable machine identity used for idempotency.
/// [receiptNumber] is deliberately short enough for a cashier or customer to
/// read, type and search. It is never replaced by the server order number.
class ReceiptIdentity {
  const ReceiptIdentity({
    required this.clientSaleId,
    required this.receiptNumber,
    required this.issuedAt,
    required this.deviceId,
    required this.counterNumber,
  });

  final String clientSaleId;
  final String receiptNumber;

  /// UTC ISO-8601 instant captured once at confirmation time.
  final String issuedAt;
  final String deviceId;
  final int counterNumber;
}

class ReceiptCounterConfiguration {
  const ReceiptCounterConfiguration({
    required this.storeId,
    required this.counterNumber,
    required this.deviceId,
    required this.isConfigured,
  });

  final int storeId;
  final int counterNumber;
  final String deviceId;
  final bool isConfigured;

  String get counterCode => counterNumber.toString().padLeft(2, '0');
  String get shortDeviceId =>
      deviceId.length <= 8 ? deviceId : deviceId.substring(0, 8).toUpperCase();
}

/// Device-scoped receipt identity allocator shared by every billing surface.
///
/// The human receipt format is:
///
///     store-counter-YYMMDD-dailySequence
///     2-03-260916-0001
///
/// A UUIDv7 is allocated alongside it because a short receipt number alone is
/// not a safe distributed idempotency key. Counter numbers are configured per
/// store and must be unique within that store.
class ReceiptIdentityService {
  ReceiptIdentityService._();

  static final ReceiptIdentityService instance = ReceiptIdentityService._();

  static const String deviceIdPreferenceKey = 'pos_device_id';
  static const String counterMapPreferenceKey = 'pos_counter_numbers_by_store';
  static const String sequenceMapPreferenceKey = 'pos_receipt_sequences';

  static const int minimumCounterNumber = 1;
  static const int maximumCounterNumber = 999;
  static const int defaultCounterNumber = 1;

  /// Highest daily sequence an operator may enter as the last bill sold.
  static const int maximumSequence = 99999;

  static const Uuid _uuid = Uuid();
  static Future<void> _allocationTail = Future<void>.value();

  Future<ReceiptCounterConfiguration> configurationForStore(int storeId) async {
    _validateStoreId(storeId);
    final prefs = await SharedPreferences.getInstance();
    final counterMap = _readIntMap(prefs.getString(counterMapPreferenceKey));
    final configuredCounter = counterMap['$storeId'];
    final deviceId = await _deviceId(prefs);

    return ReceiptCounterConfiguration(
      storeId: storeId,
      counterNumber: configuredCounter ?? defaultCounterNumber,
      deviceId: deviceId,
      isConfigured: configuredCounter != null,
    );
  }

  Future<ReceiptCounterConfiguration> setCounterNumber({
    required int storeId,
    required int counterNumber,
  }) async {
    _validateStoreId(storeId);
    if (counterNumber < minimumCounterNumber ||
        counterNumber > maximumCounterNumber) {
      throw ArgumentError.value(
        counterNumber,
        'counterNumber',
        'Counter number must be between $minimumCounterNumber and '
            '$maximumCounterNumber.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final counterMap = _readIntMap(prefs.getString(counterMapPreferenceKey));
    counterMap['$storeId'] = counterNumber;
    await prefs.setString(counterMapPreferenceKey, jsonEncode(counterMap));
    return configurationForStore(storeId);
  }

  Future<ReceiptIdentity> issue({required int storeId}) {
    _validateStoreId(storeId);
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final configuration = await configurationForStore(storeId);
      final dateCode = todayDateCode();
      final sequenceKey =
          _sequenceKey(storeId, configuration.counterNumber, dateCode);
      final sequences = _readIntMap(prefs.getString(sequenceMapPreferenceKey));
      final nextSequence = (sequences[sequenceKey] ?? 0) + 1;
      sequences[sequenceKey] = nextSequence;

      // Persist before returning so a crash can create a harmless gap but
      // cannot cause the same receipt reference to be issued again.
      await prefs.setString(sequenceMapPreferenceKey, jsonEncode(sequences));

      return ReceiptIdentity(
        clientSaleId: _uuid.v7(),
        receiptNumber: formatReceiptNumber(
          storeId: storeId,
          counterNumber: configuration.counterNumber,
          dateCode: dateCode,
          sequence: nextSequence,
        ),
        issuedAt: DateHelper.now().toUtc().toIso8601String(),
        deviceId: configuration.deviceId,
        counterNumber: configuration.counterNumber,
      );
    });
  }

  /// Today's date part of a bill number, in the business timezone.
  static String todayDateCode() =>
      DateFormat('yyMMdd').format(DateHelper.nowInConfiguredTimeZone());

  static String _sequenceKey(int storeId, int counterNumber, String dateCode) =>
      '$storeId:$counterNumber:$dateCode';

  /// The last daily sequence this device issued today for [counterNumber] in
  /// [storeId], or 0 when it has issued none.
  Future<int> lastIssuedSequenceToday({
    required int storeId,
    required int counterNumber,
  }) async {
    _validateStoreId(storeId);
    final prefs = await SharedPreferences.getInstance();
    final sequences = _readIntMap(prefs.getString(sequenceMapPreferenceKey));
    return sequences[_sequenceKey(storeId, counterNumber, todayDateCode())] ??
        0;
  }

  /// Today's last issued sequence for every counter of [storeId] on this
  /// device, keyed by counter number. Counters with no bills today are absent.
  Future<Map<int, int>> lastIssuedSequencesToday({required int storeId}) async {
    _validateStoreId(storeId);
    final prefs = await SharedPreferences.getInstance();
    final sequences = _readIntMap(prefs.getString(sequenceMapPreferenceKey));
    final prefix = '$storeId:';
    final suffix = ':${todayDateCode()}';
    final result = <int, int>{};
    sequences.forEach((key, value) {
      if (!key.startsWith(prefix) || !key.endsWith(suffix)) return;
      final counter = int.tryParse(
        key.substring(prefix.length, key.length - suffix.length),
      );
      if (counter != null) result[counter] = value;
    });
    return result;
  }

  /// Makes the next bill for [counterNumber] follow [lastSoldSequence], for
  /// example after a reinstall restarted the count at 0001. The sequence can
  /// only move forward, so this can never make a number be issued twice.
  Future<int> raiseLastIssuedSequenceToday({
    required int storeId,
    required int counterNumber,
    required int lastSoldSequence,
  }) {
    _validateStoreId(storeId);
    if (lastSoldSequence < 1 || lastSoldSequence > maximumSequence) {
      throw ArgumentError.value(
        lastSoldSequence,
        'lastSoldSequence',
        'The last bill number must be between 1 and $maximumSequence.',
      );
    }
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final key = _sequenceKey(storeId, counterNumber, todayDateCode());
      final sequences = _readIntMap(prefs.getString(sequenceMapPreferenceKey));
      final current = sequences[key] ?? 0;
      if (lastSoldSequence < current) {
        throw StateError(
          'Bill numbers can only move forward. This counter already issued '
          '$current today.',
        );
      }
      sequences[key] = lastSoldSequence;
      await prefs.setString(sequenceMapPreferenceKey, jsonEncode(sequences));
      return lastSoldSequence;
    });
  }

  /// The bill number the next sale on this counter will get.
  Future<String> nextReceiptNumber(
    ReceiptCounterConfiguration configuration,
  ) async {
    final last = await lastIssuedSequenceToday(
      storeId: configuration.storeId,
      counterNumber: configuration.counterNumber,
    );
    return formatReceiptNumber(
      storeId: configuration.storeId,
      counterNumber: configuration.counterNumber,
      dateCode: todayDateCode(),
      sequence: last + 1,
    );
  }

  String previewReceiptNumber(ReceiptCounterConfiguration configuration) {
    final dateCode =
        DateFormat('yyMMdd').format(DateHelper.nowInConfiguredTimeZone());
    return formatReceiptNumber(
      storeId: configuration.storeId,
      counterNumber: configuration.counterNumber,
      dateCode: dateCode,
      sequence: 1,
    );
  }

  static String formatReceiptNumber({
    required int storeId,
    required int counterNumber,
    required String dateCode,
    required int sequence,
  }) {
    return '$storeId-${counterNumber.toString().padLeft(2, '0')}-$dateCode-'
        '${sequence.toString().padLeft(4, '0')}';
  }

  static bool isStableReceiptNumber(String value) =>
      RegExp(r'^\d+-\d{2,3}-\d{6}-\d{4,}$').hasMatch(value.trim());

  /// Keeps the new stable reference intact while preserving the old PDF
  /// behaviour for legacy local `CONF-n` values and server `ORD-n` values.
  static String printableInvoiceNumberComponent(String value) {
    final trimmed = value.trim();
    if (isStableReceiptNumber(trimmed)) return trimmed;
    return RegExp(r'[1-9]\d*').firstMatch(trimmed)?.group(0) ?? trimmed;
  }

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _allocationTail;
    final completed = Completer<void>();
    _allocationTail = previous.then((_) => completed.future);
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        completed.complete();
      }
    });
  }

  static Future<String> _deviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(deviceIdPreferenceKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _uuid.v4();
    await prefs.setString(deviceIdPreferenceKey, generated);
    return generated;
  }

  static Map<String, int> _readIntMap(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, int>{};
      return decoded.map<String, int>((key, value) {
        final number = value is num ? value.toInt() : int.tryParse('$value');
        return MapEntry('$key', number ?? 0);
      });
    } catch (_) {
      return <String, int>{};
    }
  }

  static void _validateStoreId(int storeId) {
    if (storeId <= 0) {
      throw ArgumentError.value(
          storeId, 'storeId', 'A valid store is required.');
    }
  }
}
