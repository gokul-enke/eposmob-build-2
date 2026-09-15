import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../helpers/atomic_file.dart';

/// What [PreferencesFileGuard.ensureReadable] found on disk.
enum PreferencesFileState {
  /// Not a file-backed platform, or nothing has been saved yet.
  absent,

  /// The file parsed; the backup copy was refreshed from it.
  healthy,

  /// The file was damaged and the copy from the last healthy launch was put
  /// back.
  restoredFromBackup,

  /// The file was damaged with no usable copy, but the API key and server were
  /// still legible in it; only those were kept.
  salvaged,

  /// The file was damaged and nothing could be recovered; settings start empty.
  reset;

  bool get wasRepaired => this != absent && this != healthy;
}

/// Keeps SharedPreferences readable on Windows and Linux.
///
/// There the plugin stores every preference in one JSON file and rewrites it
/// in place. A power cut, forced close or restart that kills the process
/// mid-write leaves the file truncated, and from then on every
/// `SharedPreferences.getInstance()` throws, stranding the till on the API key
/// screen. The damaged file is moved aside (kept for support) and replaced by
/// the copy saved at the last healthy launch.
class PreferencesFileGuard {
  const PreferencesFileGuard._();

  static const String fileName = 'shared_preferences.json';
  static const String backupFileName = 'shared_preferences.json.bak';
  static const String _quarantinePrefix = 'shared_preferences.corrupt-';

  /// Keys a till cannot start without, as the plugin stores them.
  static const List<String> _tenantKeys = [
    'flutter.api_key',
    'flutter.app_url',
  ];

  static bool get _isFileBacked =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// Checks the preferences file and repairs it if it cannot be parsed.
  ///
  /// Run before the first `SharedPreferences.getInstance()`. Read failures
  /// (e.g. the file is locked by antivirus) are rethrown untouched: only a
  /// file that was read and is not a JSON object counts as damaged.
  static Future<PreferencesFileState> ensureReadable({
    Directory? directory,
  }) async {
    if (directory == null) {
      if (!_isFileBacked) return PreferencesFileState.absent;
      directory = await getApplicationSupportDirectory();
    }
    final file = File(_pathIn(directory, fileName));
    if (!await file.exists()) return PreferencesFileState.absent;

    final bytes = await file.readAsBytes();
    final backup = File(_pathIn(directory, backupFileName));
    if (_isValid(bytes)) {
      try {
        await writeFileAtomically(backup, bytes);
      } catch (error) {
        // A missing backup only matters if the file is damaged later.
        debugPrint('⚠️ Could not back up preferences: $error');
      }
      return PreferencesFileState.healthy;
    }

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final quarantineName = '$_quarantinePrefix$stamp.json';
    await file.rename(_pathIn(directory, quarantineName));

    List<int>? backupBytes;
    try {
      if (await backup.exists()) backupBytes = await backup.readAsBytes();
    } catch (error) {
      debugPrint('⚠️ Could not read preferences backup: $error');
    }

    final PreferencesFileState state;
    if (backupBytes != null && _isValid(backupBytes)) {
      await writeFileAtomically(file, backupBytes);
      state = PreferencesFileState.restoredFromBackup;
    } else {
      final salvaged = _salvageTenantKeys(bytes);
      if (salvaged.isEmpty) {
        state = PreferencesFileState.reset;
      } else {
        await writeFileAtomically(file, utf8.encode(json.encode(salvaged)));
        state = PreferencesFileState.salvaged;
      }
    }

    final message = 'Damaged preferences file (${bytes.length} bytes) moved to '
        '$quarantineName; ${state.name}';
    debugPrint('⚠️ $message');
    unawaited(Sentry.captureMessage(message, level: SentryLevel.warning));
    return state;
  }

  /// Runs [action]; if it throws and the preferences file turns out to be
  /// damaged, repairs the file and runs [action] once more. Any other failure
  /// is rethrown as it was.
  static Future<T> runWithRepair<T>(
    Future<T> Function() action, {
    Directory? directory,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      final PreferencesFileState state;
      try {
        state = await ensureReadable(directory: directory);
      } catch (_) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (!state.wasRepaired) Error.throwWithStackTrace(error, stackTrace);
      return action();
    }
  }

  static bool _isValid(List<int> bytes) {
    try {
      return json.decode(utf8.decode(bytes)) is Map;
    } on FormatException {
      return false;
    }
  }

  /// A truncated file often still holds complete tenant entries; keeping them
  /// spares the user from re-entering the API key.
  static Map<String, String> _salvageTenantKeys(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final salvaged = <String, String>{};
    for (final key in _tenantKeys) {
      final match = RegExp('"${RegExp.escape(key)}"' r'\s*:\s*"((?:[^"\\]|\\.)*)"')
          .firstMatch(text);
      if (match == null) continue;
      try {
        final value = json.decode('"${match.group(1)}"');
        if (value is String && value.trim().isNotEmpty) salvaged[key] = value;
      } on FormatException {
        // Leave the key out rather than guess.
      }
    }
    return salvaged;
  }

  static String _pathIn(Directory directory, String name) =>
      '${directory.path}${Platform.pathSeparator}$name';
}
