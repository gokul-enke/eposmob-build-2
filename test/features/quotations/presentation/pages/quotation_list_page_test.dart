import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' show Excel;
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'package:pos_machine/features/quotations/data/quotation_list_repository.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/quotations/presentation/pages/quotation_list_page.dart';
import '../../../../test_support/export_capture.dart';
import '../../../../test_support/header_actions.dart';
import '../../support/fake_quotation_list_source.dart';

class Customers extends CustomerProvider {
  @override
  List<CustomerListModelData>? get allCustomers =>
      [CustomerListModelData(id: 8, name: 'Buyer', phone: '00123')];
}

class Stores extends StoreSessionProvider {
  @override
  List<Store> get availableStores => [
        Store(storeId: 4, storeName: 'Main'),
        Store(storeId: 5, storeName: 'Secondary')
      ];
}

class Localized extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final result = <String, Map<String, String>>{};
    for (final locale in ['en', 'ar', 'ml']) {
      final flat = <String, String>{};
      void flatten(Map<String, dynamic> map, String prefix) {
        map.forEach((key, value) {
          final path = prefix.isEmpty ? key : '$prefix.$key';
          if (value is Map<String, dynamic>) {
            flatten(value, path);
          } else {
            flat[path] = '$value';
          }
        });
      }

      flatten(
          jsonDecode(
              File('lib/resources/i18n/$locale.json').readAsStringSync()),
          '');
      result[locale] = flat;
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('current-page translation preserves the existing standalone page label',
      () {
    final translations = Localized().keys;
    for (final entry in {'en': 'Page', 'ar': 'صفحة', 'ml': 'പേജ്'}.entries) {
      expect(translations[entry.key]!['pagination.page'], entry.value);
      expect(translations[entry.key]!['pagination.current_page'],
          contains('@current'));
    }
  });
  setUpAll(() async {
    final fonts = FontLoader('Poppins');
    for (final suffix in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Poppins-$suffix.ttf'));
    }
    await fonts.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(configFile.readAsStringSync());
    final flutter =
        (config['packages'] as List).firstWhere((p) => p['name'] == 'flutter');
    final root = configFile.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(File.fromUri(root.resolve(entry.value))
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
  });
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() => Get.reset());
  Future<void> mount(
      WidgetTester tester, double width, FakeQuotationListSource source,
      {ExportController? export,
      String locale = 'en',
      ValueChanged<Quotation>? action}) async {
    tester.view.physicalSize = Size(width, width == 375 ? 812 : 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider(create: (_) => QuotationsProvider()),
          ChangeNotifierProvider<CustomerProvider>(create: (_) => Customers()),
          ChangeNotifierProvider<StoreSessionProvider>(create: (_) => Stores()),
        ],
        child: GetMaterialApp(
            translations: Localized(),
            locale: Locale(locale),
            home: Scaffold(
                body: RepaintBoundary(
                    key: const ValueKey('quotation-preview'),
                    child: QuotationsListScreen(
                        source: source,
                        exportController: export,
                        onView: action ?? (_) {},
                        onConvert: action ?? (_) {},
                        onPrint: action ?? (_) {},
                        onAdd: () {}))))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'full filter, pagination, export, Reset, failure and Retry sequence',
      (tester) async {
    await useTempExportDirectory(tester, 'quotation-list-');
    final source = FakeQuotationListSource();
    final export = CapturingExport();
    addTearDown(export.dispose);
    await mount(tester, 1440, source, export: export);
    expect(find.byType(ListPageScaffold<Quotation>), findsOneWidget);
    expect(find.text('Select Date'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'QTN');
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pumpAndSettle();
    expect(source.requests.last.query.number, 'QTN');
    expect(export.runs, 1);
    final firstFile = await tester.runAsync(export.createFile!);
    final book =
        Excel.decodeBytes(firstFile!.readAsBytesSync()).tables.values.single;
    expect(book.rows, hasLength(7));
    expect(book.rows[1][0]?.value.toString(), 'QTN-00001');
    expect(book.rows.last[0]?.value.toString(), 'QTN-00006');
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(source.requests.last.page, 2);
    expect(source.requests.last.query.number, 'QTN');
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pumpAndSettle();
    final frozen = export.createFile!;
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(source.requests.last.query.active, isFalse);
    expect(source.requests.last.page, 1);
    final file = await tester.runAsync(frozen);
    expect(file, isNotNull);
    expect(source.snapshots.last.number, 'QTN');
    source.fail = true;
    await tester.tap(find.byKey(QuotationsListScreen.refreshKey));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    final runs = export.runs;
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pump();
    expect(export.runs, runs);
    source.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
  });
  testWidgets(
      'searchable dropdown dismissal preserves selection; Reset clears search and exact dates',
      (tester) async {
    final source = FakeQuotationListSource();
    await mount(tester, 1440, source);
    final picker = find.byKey(const ValueKey('quotation-store-picker'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Secondary').last);
    await tester.pumpAndSettle();
    expect(source.requests.last.query.storeId, 5);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'unselected');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1420, 120));
    await tester.pumpAndSettle();
    expect(source.requests.last.query.storeId, 5);
    expect(find.text('Secondary'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quotation-quotation-date')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 28));
    await tester.pumpAndSettle();
    expect(source.requests.last.query.quotationDate, DateTime(2026, 9, 28));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(source.requests.last.query.active, isFalse);
    expect(find.text('Select Date'), findsNWidgets(2));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty);
    await tester.tapAt(const Offset(1420, 120));
    await tester.pumpAndSettle();
  });
  testWidgets(
      'all row actions carry the original quotation and wide table scrolls',
      (tester) async {
    final source = FakeQuotationListSource();
    final calls = <Quotation>[];
    await mount(tester, 1280, source, action: calls.add);
    final table = tester
        .widget<AppDataTable<Quotation>>(find.byType(AppDataTable<Quotation>));
    expect(table.horizontalController, isNotNull);
    for (final name in ['view', 'convert', 'print']) {
      final button = find.byKey(ValueKey('quotation-$name-1'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
    expect(calls, hasLength(3));
    expect(calls.every((q) => identical(q, table.items.first)), isTrue);
  });
  testWidgets(
      'phone overflow menu exposes Export and Filters; export owner survives disposal',
      (tester) async {
    final source = FakeQuotationListSource();
    final export = CapturingExport();
    addTearDown(export.dispose);
    await mount(tester, 375, source, export: export);
    expect(find.byType(AppListCard), findsWidgets);
    expect(find.text('New'), findsOneWidget);
    await tapFilterToggle(tester, key: QuotationsListScreen.filterToggleKey);
    await tester.pumpAndSettle();
    expect(find.byType(FilterPanel), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    export.setStage('caller');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'changing the active store cancels an old export and reloads page one',
      (tester) async {
    final source = FakeQuotationListSource();
    final export = CapturingExport();
    addTearDown(export.dispose);
    await mount(tester, 1280, source, export: export);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pumpAndSettle();
    final oldExport = export.createFile!;
    final context = tester.element(find.byType(QuotationsListScreen));
    context.read<StoreSessionProvider>().initializeStores([
      Store(storeId: 4, storeName: 'Main'),
      Store(storeId: 5, storeName: 'Secondary'),
    ], activeStoreId: 5);
    await tester.pumpAndSettle();
    expect(source.requests.last.page, 1);
    Object? failure;
    await tester.runAsync(() async {
      try {
        await oldExport();
      } catch (error) {
        failure = error;
      }
    });
    expect(failure, isA<StateError>());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'snapshot failure shows a shared error toast and never delivers a partial file',
      (tester) async {
    final source = FakeQuotationListSource();
    var delivered = false;
    final export = ExportController(deliver: (context, file,
        {required mimeType, shareText, shareOrigin, onStage}) async {
      delivered = true;
    });
    addTearDown(export.dispose);
    await mount(tester, 1280, source, export: export);
    source.fail = true;
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pumpAndSettle();
    expect(delivered, isFalse);
    expect(export.busy, isFalse);
    expect(find.text('Unable to export quotations. Refresh and try again.'),
        findsOneWidget);
    expect(find.text('QTN-00001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final change in [
    'none',
    'store',
    'store round trip',
    'authentication'
  ]) {
    testWidgets('workbook generation respects $change session change',
        (tester) async {
      final source = FakeQuotationListSource();
      final export = CapturingExport();
      addTearDown(export.dispose);
      var deliveries = 0;
      final delivery = ExportController(deliver: (context, file,
          {required mimeType, shareText, shareOrigin, onStage}) async {
        deliveries++;
        expect(file.existsSync(), isTrue);
      });
      addTearDown(delivery.dispose);
      await useTempExportDirectory(tester, 'quotation-session-');
      await mount(tester, 1280, source, export: export);
      final context = tester.element(find.byType(QuotationsListScreen));
      final stores = context.read<StoreSessionProvider>();
      final auth = context.read<AuthModel>();
      var changed = false;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      // Resolve the test's existing temp directory before replacing its handler.
      final directory = await tester.runAsync(
          () => channel.invokeMethod<String>('getTemporaryDirectory'));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (_) async {
        if (!changed) {
          changed = true;
          // This runs after snapshot completion and isolate encoding, during
          // workbook creation, before ExportController receives the file.
          if (change == 'store' || change == 'store round trip') {
            stores.initializeStores([
              Store(storeId: 4, storeName: 'Main'),
              Store(storeId: 5, storeName: 'Secondary'),
            ], activeStoreId: 5);
            if (change == 'store round trip') {
              stores.resetSession();
            }
          } else if (change == 'authentication') {
            auth.login('replacement-token', 2);
          }
        }
        return directory;
      });
      await tester.tap(find.byKey(QuotationsListScreen.exportKey));
      await tester.pumpAndSettle();
      final ok = await tester.runAsync(
          () => delivery.run(context, createFile: export.createFile!));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(ok, change == 'none');
      expect(deliveries, change == 'none' ? 1 : 0);
      expect(delivery.busy, isFalse);
      // Cancellation must not prevent a fresh export in the current session.
      await tester.tap(find.byKey(QuotationsListScreen.exportKey));
      await tester.pumpAndSettle();
      expect(
          await tester.runAsync(
              () => delivery.run(context, createFile: export.createFile!)),
          isTrue);
      expect(deliveries, change == 'none' ? 2 : 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unknown total allows paging without claiming a final page count',
      (tester) async {
    final source = FakeQuotationListSource();
    source.handler = (_, page) async => QuotationListPageData(
        rows: [quotation(page)],
        current: page,
        last: page < 3 ? page + 1 : page,
        from: page,
        perPage: 1,
        totalPagesKnown: false);
    await mount(tester, 1280, source);
    expect(find.text('Page 1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('QTN-00002'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Page 3'), findsOneWidget);
    final requests = source.requests.length;
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(source.requests.length, requests);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(find.text('QTN-00002'), findsOneWidget);
  });
  testWidgets(
      'empty filtered success removes previous rows and shows no-match state without Retry',
      (tester) async {
    final source = FakeQuotationListSource();
    final export = CapturingExport();
    addTearDown(export.dispose);
    await mount(tester, 1280, source, export: export);
    source.handler = (_, __) async =>
        QuotationListPageData(rows: [], current: 1, last: 1, from: 1, total: 0);
    await tester.tap(find.byKey(const ValueKey('quotation-store-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Secondary').last);
    await tester.pumpAndSettle();
    expect(find.text('No quotations match your filters'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('QTN-00001'), findsNothing);
    expect(find.text('0 quotations on this page'), findsOneWidget);
    await tester.tap(find.byKey(QuotationsListScreen.exportKey));
    await tester.pump();
    expect(export.runs, 0);
  });
  for (final locale in ['en', 'ar', 'ml']) {
    for (final width in [375.0, 768.0, 1280.0]) {
      testWidgets('populated $locale layout at $width', (tester) async {
        await mount(tester, width, FakeQuotationListSource(), locale: locale);
        expect(tester.takeException(), isNull);
        final tag = Platform.environment['QUOTATION_CAPTURE_TAG'];
        if (tag != null && locale == 'en') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('quotation-preview')));
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await picture.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                'docs/screenshots/quotation-list/$tag-${width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
      });
    }
  }
}
