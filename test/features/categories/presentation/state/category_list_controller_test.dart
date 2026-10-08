import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/categories/data/category_list_source.dart';
import 'package:pos_machine/features/categories/domain/category_list_entry.dart';
import 'package:pos_machine/features/categories/presentation/state/category_list_controller.dart';

class DirectoryFake extends ChangeNotifier {
  List<CategoryListEntry> entries = List.generate(
      45,
      (i) => CategoryListEntry(
          id: i + 1,
          name: 'Category $i',
          slug: 'category-$i',
          translations: {'ar': 'قسم $i'}));
  bool busy = false;
  int loads = 0;
  Future<void> Function()? onLoad;
  CategoryListSource get port => CategoryListSource(
      readEntries: () => entries,
      ensureLoaded: () async {
        loads++;
        await onLoad?.call();
      },
      isBusy: () => busy,
      addListener: addListener,
      removeListener: removeListener);
  void signal() => notifyListeners();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DirectoryFake directory;
  late CategoryListController controller;
  setUp(() {
    directory = DirectoryFake();
    controller = CategoryListController(directory.port);
  });
  tearDown(() {
    controller.dispose();
    directory.dispose();
  });
  test('multilingual substring rule matches the legacy management semantics',
      () async {
    await controller.load();
    controller.search.text = 'قسم 4';
    controller.flushSearch();
    expect(controller.rows.map((entry) => entry.id), [5, 41, 42, 43, 44, 45]);
    controller.search.text = 'CATEGORY 4';
    controller.flushSearch();
    expect(controller.rows.length, 6);
    controller.search.text = ' category';
    controller.flushSearch();
    expect(controller.rows, isEmpty); // No new trimming behavior.
    controller.reset();
    expect(controller.rows.length, 45);
  });
  testWidgets(
      'pending edits, Reset, page changes and Export see one applied query',
      (tester) async {
    await controller.load();
    controller.goToPage(2);
    controller.search.text = 'Category 4';
    controller.scheduleSearch();
    controller.reset();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.rows.length, 45);
    expect(controller.page, 1);
    controller.goToPage(3);
    controller.search.text = 'Category 4';
    controller.scheduleSearch();
    controller.goToPage(2);
    expect(controller.page, 1);
    expect(controller.rows.length, 6);
    controller.reset();
    controller.goToPage(2);
    controller.search.text = 'temp';
    controller.scheduleSearch();
    controller.search.clear();
    controller.goToPage(3);
    expect(controller.page, 3);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, 3);
  });
  test('case-only edit and unrelated provider notifications preserve page',
      () async {
    await controller.load();
    controller.search.text = 'Category';
    controller.flushSearch();
    controller.goToPage(2);
    controller.search.text = 'CATEGORY';
    expect(controller.flushSearch(), isFalse);
    directory.signal();
    expect(controller.page, 2);
  });
  test('catalogue sync hides partial entries, preserves filter and clamps page',
      () async {
    await controller.load();
    controller.search.text = 'Category';
    controller.flushSearch();
    controller.goToPage(3);
    directory.busy = true;
    directory.signal();
    expect(controller.loading, isTrue);
    controller.goToPage(1);
    expect(controller.page, 3);
    directory.entries = [
      CategoryListEntry(id: 9, name: 'Category fresh'),
      CategoryListEntry(id: 10, name: 'Other')
    ];
    directory.signal();
    expect(controller.rows.length, 45);
    directory.busy = false;
    directory.signal();
    expect(controller.loading, isFalse);
    expect(controller.rows.single.name, 'Category fresh');
    expect(controller.page, 1);
  });
  test('failure retains rows/page, retry handles an empty success', () async {
    await controller.load();
    controller.goToPage(2);
    directory.onLoad = () => Future.error(StateError('offline'));
    await controller.load();
    expect(controller.error, isNotNull);
    expect(controller.rows.length, 45);
    expect(controller.page, 2);
    directory.onLoad = () async {
      directory.entries = [];
    };
    await controller.load();
    expect(controller.error, isNull);
    expect(controller.loading, isFalse);
    expect(controller.rows, isEmpty);
    expect(controller.page, 1);
  });
  test('initialization failure differs from empty success and shares retries',
      () async {
    final pending = Completer<void>();
    directory.onLoad = () => pending.future;
    final one = controller.load();
    final two = controller.load();
    expect(directory.loads, 1);
    directory.busy = true;
    pending.complete();
    await Future.wait([one, two]);
    expect(controller.loading, isTrue);
    directory.busy = false;
    directory.signal();
    expect(controller.rows.length, 45);
    expect(controller.loading, isFalse);
  });
  test('disposed initialization does not notify or read late cache values',
      () async {
    final lateDirectory = DirectoryFake();
    final pending = Completer<void>();
    lateDirectory.onLoad = () => pending.future;
    final lateController = CategoryListController(lateDirectory.port);
    final load = lateController.load();
    lateController.scheduleSearch();
    lateController.dispose();
    pending.complete();
    await load;
    lateDirectory.signal();
    lateDirectory.dispose();
  });
}
