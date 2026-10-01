import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/screens/transactions/invoice_list.dart';

/// Records the file factory the screen hands to the export instead of
/// creating and delivering the file, so tests can run it directly.
class _CapturingExport extends ExportController {
  Future<File> Function()? createFile;

  @override
  Future<bool> run(BuildContext context,
      {required Future<File> Function() createFile,
      String mimeType = FileExportService.xlsxMimeType,
      String? shareText,
      Rect? shareOrigin}) async {
    this.createFile = createFile;
    return true;
  }
}

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

Map<String, dynamic> row(int id) => {
      'id': id,
      'invoice_number': '000$id',
      'amount': '12.125',
      'status': 'paid',
      'invoice_date': '2026-10-01',
      'due_date': '2026-11-01',
      'type': 'order',
      'customer': {
        'user': {'name': 'Test Customer', 'phone': '0012345'}
      }
    };
Map<String, dynamic> response(int page, {int last = 2, int total = 2}) => {
      'status': 'success',
      'data': {
        'current_page': page,
        'last_page': last,
        'total': total,
        'data': [row(page)]
      }
    };

class _Settings extends AppSettingsProvider {
  bool enabled;
  bool ready = true;
  bool refreshing = false;
  _Settings(this.enabled);
  void update({required bool verified, required bool loading, bool? phase2}) {
    ready = verified;
    refreshing = loading;
    if (phase2 != null) enabled = phase2;
    notifyListeners();
  }

  @override
  bool get isReady => ready && !refreshing;
  @override
  bool get loading => refreshing;
  @override
  AppSettings get appSettings => AppSettings.fromJson({
        'data': [
          {'code': 'ZATCA_PHASE_2', 'status': enabled, 'value': enabled},
          {'code': 'CURRENCY', 'status': true, 'value': 'SAR'}
        ]
      });
}

class _Provider extends InvoiceProvider {
  int page = 1;
  final filters = <Map<String, Object?>>[];
  Map<String, Object?>? exportFilters;
  @override
  bool get isLoading => false;
  @override
  int get currentPage => page;
  @override
  int get totalPages => 2;
  @override
  List<Invoice> get invoiceListDetails => [Invoice.fromJson(row(page))];
  @override
  List<String> getStatusOptions() => ['All Status', 'paid'];
  @override
  Future<dynamic> listAllInvoices(
      {required String accessToken,
      String? name,
      String? invoiceNumber,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      String? phone,
      String? email,
      String? orderNumber,
      int? page,
      int? perPage,
      bool loadAll = false,
      http.Client? client}) async {
    this.page = page ?? 1;
    notifyListeners();
    return response(this.page);
  }

  @override
  void applyFilters(
      {String? name,
      String? invoiceNumber,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      String? phone,
      String? email,
      String? orderNumber,
      int page = 1}) {
    filters.add({
      'name': name,
      'invoiceNumber': invoiceNumber,
      'phone': phone,
      'status': status,
      'zatcaStatus': zatcaStatus
    });
    this.page = page;
    notifyListeners();
  }

  @override
  void goToPage(int value) {
    page = value;
    notifyListeners();
  }

  @override
  void resetFilters({bool reload = true, bool notify = true}) {
    page = 1;
    if (notify) notifyListeners();
  }

  @override
  Future<List<Invoice>> fetchInvoicesForExport(
      {required String accessToken,
      String? name,
      String? invoiceNumber,
      String? phone,
      String? fromDate,
      String? toDate,
      String? status,
      String? zatcaStatus,
      void Function(int, int)? onProgress,
      http.Client? client,
      Duration requestTimeout = const Duration(seconds: 30)}) async {
    exportFilters = {
      'name': name,
      'invoiceNumber': invoiceNumber,
      'phone': phone,
      'status': status,
      'zatcaStatus': zatcaStatus
    };
    onProgress?.call(2, 2);
    return [Invoice.fromJson(row(1)), Invoice.fromJson(row(2))];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(
        {'api_key': 'tenant', 'active_store_id': 7});
  });
  tearDown(() => Get.reset());
  test('export fetches every filtered page without changing list or notifying',
      () async {
    final provider = InvoiceProvider();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode(response(int.parse(request.url.queryParameters['page']!))),
          200);
    });
    await provider.listAllInvoices(
        accessToken: 'token', page: 2, client: client);
    requests.clear();
    int notifications = 0;
    provider.addListener(() => notifications++);
    final progress = <String>[];
    final exported = await provider.fetchInvoicesForExport(
        accessToken: 'token',
        name: 'Test',
        invoiceNumber: '000',
        phone: '0012345',
        status: 'paid',
        zatcaStatus: 'NOT SENT',
        fromDate: '01/10/2026',
        toDate: '2026-10-31 23:59:00',
        onProgress: (page, total) => progress.add('$page/$total'),
        client: client);
    expect(exported.map((v) => v.id), [1, 2]);
    expect(progress, ['1/2', '2/2']);
    expect(provider.currentPage, 2);
    expect(provider.invoiceListDetails!.single.id, 2);
    expect(notifications, 0);
    for (final request in requests) {
      expect(request.headers['X-Tenant'], 'tenant');
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.url.queryParameters, containsPair('store_id', '7'));
      expect(request.url.queryParameters, containsPair('name', 'Test'));
      expect(
          request.url.queryParameters, containsPair('invoice_number', '000'));
      expect(request.url.queryParameters, containsPair('phone', '0012345'));
      expect(request.url.queryParameters, containsPair('status', 'paid'));
      expect(request.url.queryParameters,
          containsPair('zatca_status', 'not_sent'));
      expect(
          request.url.queryParameters, containsPair('date_from', '2026-10-01'));
      expect(request.url.queryParameters,
          containsPair('date_to', '2026-10-31 23:59:00'));
    }
  });
  test(
      'stalled export page times out without changing the visible list and can retry',
      () async {
    final provider = InvoiceProvider();
    final goodClient = MockClient((request) async => http.Response(
        jsonEncode(response(int.parse(request.url.queryParameters['page']!))),
        200));
    await provider.listAllInvoices(
        accessToken: 'token', page: 2, client: goodClient);
    final stalled = Completer<http.Response>();
    final stuckClient = MockClient((request) async {
      if (request.url.queryParameters['page'] == '2') return stalled.future;
      return http.Response(jsonEncode(response(1)), 200);
    });
    await expectLater(
        provider.fetchInvoicesForExport(
            accessToken: 'token',
            client: stuckClient,
            requestTimeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()));
    expect(provider.currentPage, 2);
    expect(provider.invoiceListDetails!.single.id, 2);
    final retry = await provider.fetchInvoicesForExport(
        accessToken: 'token', client: goodClient);
    expect(retry.map((v) => v.id), [1, 2]);
    stalled.complete(http.Response(jsonEncode(response(2)), 200));
  });

  for (final fault in [
    'http',
    'failed',
    'empty',
    'metadata',
    'count',
    'duplicate'
  ]) {
    test('export rejects $fault rather than creating partial data', () async {
      final client = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        final data = response(page);
        if (page == 2) {
          if (fault == 'http') return http.Response('error', 500);
          if (fault == 'failed') data['status'] = 'failed';
          if (fault == 'empty') data['data']['data'] = [];
          if (fault == 'metadata') data['data']['current_page'] = 1;
          if (fault == 'count') data['data']['total'] = 3;
          if (fault == 'duplicate') data['data']['data'] = [row(1)];
        }
        return http.Response(jsonEncode(data), 200);
      });
      await expectLater(
          InvoiceProvider()
              .fetchInvoicesForExport(accessToken: 'token', client: client),
          throwsA(anyOf(isA<FormatException>(), isA<HttpException>())));
    });
  }
  late _CapturingExport capture;

  Future<_Provider> mount(WidgetTester tester, Size size, bool zatca,
      {_Settings? initialSettings}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _Provider();
    capture = _CapturingExport();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<InvoiceProvider>.value(value: provider),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => initialSettings ?? _Settings(zatca))
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: Scaffold(body: InvoiceListScreen(export: capture)))));
    await tester.pumpAndSettle();
    return provider;
  }

  for (final zatca in [true, false]) {
    for (final size in [
      const Size(1440, 900),
      const Size(800, 900),
      const Size(390, 800),
      const Size(375, 300)
    ]) {
      testWidgets('invoice layout and filters fit $size with ZATCA $zatca',
          (tester) async {
        await mount(tester, size, zatca);
        // Narrow headers fold Filters/Export/Refresh into the more menu.
        final folded = size.width < PageHeader.collapseActionsBelow;
        expect(find.byKey(InvoiceListScreen.exportKey),
            folded ? findsNothing : findsOneWidget);
        expect(find.byKey(PageHeader.moreActionsKey),
            folded ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'View'), findsOneWidget);
        // Status uses the shared badge: success tone for Paid.
        final paid = tester.widget<AppBadge>(find.ancestor(
            of: find.text('Paid'), matching: find.byType(AppBadge)));
        expect(paid.tone, AppBadgeTone.success);
        if (size.width >= 700) {
          final page = tester.widget<ListPageScaffold<Invoice>>(
              find.byType(ListPageScaffold<Invoice>));
          // Not scrolled sideways (the scroll only exists when the table
          // is narrower than its minimum width).
          final scroll = page.tableScrollController!;
          expect(scroll.hasClients ? scroll.offset : 0, 0);
          final badge = find
              .ancestor(of: find.text('Paid'), matching: find.byType(Container))
              .first;
          expect(tester.getSize(badge).width, lessThan(80));
          if (zatca) {
            expect(tester.getTopLeft(find.text('Sync ALL')).dx, lessThan(90));
            final table = find.byType(ListPageScaffold<Invoice>);
            expect(
                tester
                    .getTopRight(find.widgetWithText(TextButton, 'Unselect'))
                    .dx,
                closeTo(tester.getTopRight(table).dx - 18, 1));
          }
        }
        expect(find.byType(Checkbox), zatca ? findsOneWidget : findsNothing);
        if (size.width < 700) {
          await tester.tap(find.byKey(PageHeader.moreActionsKey));
          await tester.pumpAndSettle();
          await tester.tap(find.text('invoice.show_filters'.tr));
          await tester.pumpAndSettle();
        }
        expect(find.byType(TextField), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('first unverified load keeps ZATCA hidden until verification',
      (tester) async {
    final settings = _Settings(true)..ready = false;
    await mount(tester, const Size(1440, 900), true, initialSettings: settings);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sync ALL'), findsNothing);
    settings.update(verified: true, loading: false);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sync ALL'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'settings refresh and failure preserve layout and selection; successful disable removes ZATCA',
      (tester) async {
    await mount(tester, const Size(1440, 900), true);
    final settings = tester
        .element(find.byType(InvoiceListScreen))
        .read<AppSettingsProvider>() as _Settings;
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final originalY = tester.getTopLeft(find.text('Paid')).dy;
    final syncButton = find.widgetWithText(FilledButton, 'Sync ALL');
    expect(tester.widget<FilledButton>(syncButton).onPressed, isNotNull);
    for (final loading in [true, false]) {
      settings.update(verified: false, loading: loading);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Paid')).dy, originalY);
      expect(find.text('1 records selected'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.widget<FilledButton>(syncButton).onPressed, isNull);
    }
    settings.update(verified: true, loading: false);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Paid')).dy, originalY);
    expect(tester.widget<FilledButton>(syncButton).onPressed, isNotNull);
    settings.update(verified: true, loading: false, phase2: false);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(syncButton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified disabled layout stays disabled until successful enable',
      (tester) async {
    await mount(tester, const Size(1440, 900), false);
    final settings = tester
        .element(find.byType(InvoiceListScreen))
        .read<AppSettingsProvider>() as _Settings;
    final originalY = tester.getTopLeft(find.text('Paid')).dy;
    settings.update(verified: false, loading: true, phase2: true);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Paid')).dy, originalY);
    expect(find.byType(Checkbox), findsNothing);
    settings.update(verified: true, loading: false);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'selection survives export; filters and numeric workbook are captured',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900), true);
    await tester.enterText(find.byType(TextField).first, '000');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('1 records selected'), findsOneWidget);
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('invoice-export-test-')))!;
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.tap(find.byKey(InvoiceListScreen.exportKey));
    await tester.pump();
    final file = await tester.runAsync(capture.createFile!);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 3);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[1][1]!.value, const DoubleCellValue(12.125));
    expect(provider.exportFilters!['invoiceNumber'], '000');
    expect(find.text('1 records selected'), findsOneWidget);
    await tester.tap(find.text('Sync Selected'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('1 records selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(provider.currentPage, 2);
    expect(find.text('0 records selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
