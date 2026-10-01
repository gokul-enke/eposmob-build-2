import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every on-screen message goes through AppToast (lib/core/ui/feedback).
/// These checks stop raw Material snackbars and private copies of the
/// message helpers from coming back.
void main() {
  Iterable<(String path, int line, String text)> liveLines() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final text = lines[i];
        if (text.trimLeft().startsWith('//')) continue;
        yield (entity.path.replaceAll('\\', '/'), i + 1, text);
      }
    }
  }

  test('no raw ScaffoldMessenger snackbars', () {
    final offenders = [
      for (final (path, line, text) in liveLines())
        if (text.contains('showSnackBar(')) '$path:$line',
    ];
    expect(offenders, isEmpty,
        reason: 'Use AppToast.success / error / warning / info instead.');
  });

  test('the legacy message helpers are defined only in the shim', () {
    final definition = RegExp(
      r'^\s*(ScaffoldMessengerState|void)\s+(showScaffold|showScaffoldError|showLoadingOverlay|hideLoadingOverlay)\s*\(',
    );
    final definitions = [
      for (final (path, line, text) in liveLines())
        if (definition.hasMatch(text)) '$path:$line',
    ];
    expect(
      definitions.every(
        (location) =>
            location.startsWith('lib/newcomponents/custom_dialog_box.dart:'),
      ),
      isTrue,
      reason: 'Found private copies: $definitions',
    );
  });
}
