import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense layers retain their dependency boundaries and file size budget',
      () {
    final files = Directory('lib/features/expenses')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      final code = file.readAsStringSync();
      expect(code.split('\n').length, lessThanOrEqualTo(400), reason: path);
      final imports = RegExp(r"import '([^']+)'", multiLine: true)
          .allMatches(code)
          .map((m) => m[1]!)
          .toList();
      if (path.contains('/domain/')) {
        expect(
            imports.where((s) =>
                s.startsWith('package:') ||
                s.contains('data/') ||
                s.contains('presentation/')),
            isEmpty,
            reason: path);
      }
      if (path.contains('/data/')) {
        expect(
            imports.where((s) =>
                s.contains('presentation/') ||
                s.contains('providers/') ||
                s.contains('widgets.dart') ||
                s.contains('material.dart')),
            isEmpty,
            reason: path);
        expect(code.contains('SharedPreferences'), isFalse, reason: path);
        expect(code.contains('BuildContext'), isFalse, reason: path);
      }
      if (path.contains('/widgets/')) {
        expect(
            imports.where((s) =>
                s.contains('provider/provider.dart') ||
                s.contains('auth_model.dart') ||
                s.contains('http.dart')),
            isEmpty,
            reason: path);
        expect(code.contains('context.read'), isFalse, reason: path);
      }
      if (!path.contains('/navigation/')) {
        expect(code.contains('index.value ='), isFalse, reason: path);
      }
    }
  });
  test('retired expense paths have no compatibility re-export files', () {
    for (final path in [
      'lib/models/expense.dart',
      'lib/providers/expense_provider.dart',
      'lib/screens/transactions/expense_list_screen.dart',
      'lib/screens/transactions/create_expense_screen.dart',
      'lib/screens/transactions/view_expense_screen.dart',
      'lib/screens/transactions/widgets/expense_list_responsive.dart'
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });
}
