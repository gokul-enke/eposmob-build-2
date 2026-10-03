import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_list_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'reset cancels pending search; export flushes only changed reference',
      (tester) async {
    final applied = <String>[];
    var resets = 0;
    var refreshes = 0;
    final c = ExpenseListController(
        reference: 'old',
        applyReference: applied.add,
        resetFilters: () => resets++,
        fetch: () async {
          refreshes++;
        });
    c.referenceController.text = 'new';
    c.scheduleSearch();
    c.reset();
    await tester.pump(const Duration(seconds: 1));
    expect(applied, isEmpty);
    expect(resets, 1);
    expect(c.referenceController.text, '');
    c.referenceController.text = 'latest';
    c.scheduleSearch();
    c.prepareExport('');
    expect(applied, ['latest']);
    await tester.pump(const Duration(seconds: 1));
    expect(applied, ['latest']);
    c.prepareExport('latest');
    expect(applied, ['latest']);
    c.toggleFilters();
    expect(c.filtersVisible, isFalse);
    await c.refresh();
    expect(refreshes, 1);
    c.dispose();
  });
  testWidgets('dispose cancels pending work and retains borrowed export',
      (tester) async {
    final export = ExportController();
    final applied = <String>[];
    final c = ExpenseListController(
        reference: '',
        applyReference: applied.add,
        resetFilters: () {},
        fetch: () async {},
        export: export);
    c.scheduleSearch();
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(applied, isEmpty);
    void listener() {}
    export.addListener(listener);
    export.removeListener(listener);
    export.dispose();
  });
}
