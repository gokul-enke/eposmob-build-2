import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'voucher domain and data have no UI or provider dependencies, leaf widgets are passive',
      () {
    for (final name in ['domain', 'data', 'presentation/widgets']) {
      for (final file in Directory('lib/features/vouchers/$name')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final s = file.readAsStringSync();
        expect(s, isNot(contains('Provider.of')), reason: file.path);
        if (name == 'data')
          expect(s, isNot(contains('BuildContext')), reason: file.path);
        if (name == 'domain')
          expect(s, isNot(contains('package:flutter/')), reason: file.path);
        if (name == 'presentation/widgets') {
          expect(s, isNot(contains('AuthModel')), reason: file.path);
          expect(s, isNot(contains('package:http/')), reason: file.path);
        }
      }
    }
  });
  test('feature files stay within the architecture size guideline', () {
    for (final file in Directory('lib/features/vouchers')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(file.readAsLinesSync().length, lessThanOrEqualTo(400),
          reason: file.path);
    }
  });
}
