import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/services/preferences_file_guard.dart';

void main() {
  late Directory dir;

  File fileIn(String name) => File('${dir.path}${Platform.pathSeparator}$name');
  File prefsFile() => fileIn(PreferencesFileGuard.fileName);
  File backupFile() => fileIn(PreferencesFileGuard.backupFileName);
  List<File> quarantined() => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('shared_preferences.corrupt-'))
      .toList();

  const good = '{"flutter.api_key":"tenant-key-123","flutter.app_url":"https://a.b"}';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('prefs_guard_');
  });

  tearDown(() => dir.delete(recursive: true));

  test('missing file is left alone', () async {
    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.absent);
    expect(backupFile().existsSync(), isFalse);
  });

  test('healthy file is kept and backed up', () async {
    prefsFile().writeAsStringSync(good);

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.healthy);
    expect(prefsFile().readAsStringSync(), good);
    expect(backupFile().readAsStringSync(), good);
  });

  test('truncated file is replaced by the last good copy', () async {
    backupFile().writeAsStringSync(good);
    prefsFile().writeAsStringSync('{"flutter.api_key":"tenant-k');

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.restoredFromBackup);
    expect(prefsFile().readAsStringSync(), good);
    expect(quarantined().single.readAsStringSync(),
        '{"flutter.api_key":"tenant-k');
  });

  test('truncated file without a backup keeps a legible API key and server',
      () async {
    prefsFile().writeAsStringSync(
        '{"flutter.api_key":"tenant-key-123","flutter.app_url":"https://a.b",'
        '"flutter.stores":"[{\\"id\\":1');

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.salvaged);
    expect(jsonDecode(prefsFile().readAsStringSync()), {
      'flutter.api_key': 'tenant-key-123',
      'flutter.app_url': 'https://a.b',
    });
    expect(quarantined(), hasLength(1));
  });

  test('damaged file with nothing legible starts empty', () async {
    prefsFile().writeAsBytesSync([0, 0, 0, 0]);

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.reset);
    expect(prefsFile().existsSync(), isFalse);
    expect(quarantined(), hasLength(1));
  });

  test('empty file counts as damaged', () async {
    backupFile().writeAsStringSync(good);
    prefsFile().writeAsStringSync('');

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.restoredFromBackup);
    expect(prefsFile().readAsStringSync(), good);
  });

  test('damaged backup is not restored', () async {
    backupFile().writeAsStringSync('not json');
    prefsFile().writeAsStringSync('{"flutter.');

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.reset);
    expect(prefsFile().existsSync(), isFalse);
  });

  // A power cut commits the file size to NTFS but not the data, so both the
  // file and the copy from the last healthy launch come back full of zeros.
  // Seen on a till that was switched off at the mains: 35036 and 34552 bytes,
  // every byte 0x00.
  test('zero-filled file and backup start empty instead of throwing', () async {
    prefsFile().writeAsBytesSync(List.filled(35036, 0));
    backupFile().writeAsBytesSync(List.filled(34552, 0));

    final state = await PreferencesFileGuard.ensureReadable(directory: dir);

    expect(state, PreferencesFileState.reset);
    expect(prefsFile().existsSync(), isFalse);
    expect(quarantined().single.lengthSync(), 35036);
  });

  test('runWithRepair retries once after repairing the file', () async {
    prefsFile().writeAsStringSync('{"flutter.api_key":"ab');
    var calls = 0;

    final result = await PreferencesFileGuard.runWithRepair(() async {
      calls++;
      if (calls == 1) throw const FormatException('Unexpected end of input');
      return 'ok';
    }, directory: dir);

    expect(result, 'ok');
    expect(calls, 2);
  });

  test('runWithRepair rethrows when the file is healthy', () async {
    prefsFile().writeAsStringSync(good);
    var calls = 0;

    await expectLater(
      PreferencesFileGuard.runWithRepair<void>(() async {
        calls++;
        throw StateError('network down');
      }, directory: dir),
      throwsA(isA<StateError>()),
    );
    expect(calls, 1);
  });
}
