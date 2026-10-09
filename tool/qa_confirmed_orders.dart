// Isolated Marionette target: memory outbox, temporary Hive data and fake HTTP.
// Run: flutter run -d windows -t tool/qa_confirmed_orders.dart
// Add --dart-entrypoint-args=--allow-multiple-instances if the till is open.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:pos_machine/features/sales/presentation/pages/confirmed_orders_page.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersQaStore implements LocalSaleOutboxStore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> readAll() async => rows.values.toList();
  @override
  Future<void> remove(String id) async => rows.remove(id);
  @override
  Future<void> write(Map<String, dynamic> record) async {
    rows[record['local_order_id'] as String] =
        jsonDecode(jsonEncode(record)) as Map<String, dynamic>;
  }
}

class OrdersQaSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class OrdersQaEnvironment {
  final store = OrdersQaStore();
  final requests = <Map<String, dynamic>>[];
  late final LocalProductProvider products;
  late LocalSaleSyncService sync;
  late final Directory dataDirectory;
  String responseMode = 'mixed';
  Duration delay = const Duration(milliseconds: 400);

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({'api_key': 'orders-qa'});
    dataDirectory =
        await Directory.systemTemp.createTemp('confirmed_orders_qa_');
    Hive.init(dataDirectory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }
    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
    products = LocalProductProvider();
    await products.hydrated;
    products.confirmedOrders.addAll(List.generate(
        4,
        (index) => SavedOrder(
              id: 'qa-${index + 1}',
              orderNumber: '2-11-261009-000${index + 1}',
              items: [],
              createdAt: '2026-10-09T09:15:00',
              total: 18.75 + index * 4.5,
              customerName: 'QA customer ${index + 1}',
              status: 'confirmed',
            )));
    for (var index = 0; index < 3; index++) {
      final id = 'qa-${index + 1}';
      final payload = {
        'items': [
          {'product_id': 7, 'quantity': 2}
        ],
        'order_id': 80 + index,
        'shipped_id': 12,
        'issued_at': '2026-10-09T09:15:00',
        'qa_id': id
      };
      final state = index == 0
          ? LocalSaleSyncState.needsReview
          : index == 1
              ? LocalSaleSyncState.rejected
              : LocalSaleSyncState.queued;
      await store.write(LocalSaleSyncRecord(
              localOrderId: id,
              localOrderNumber: products.confirmedOrders[index].orderNumber,
              sourceCartSessionId: id,
              surface: LocalSaleSurface.mobileBilling,
              operation: LocalSaleOperation.confirmedSale,
              state: state,
              payload: payload,
              createdAt: '2026-10-09T09:15:00',
              message: index == 1
                  ? 'Invalid shipped ID. Correct the JSON before syncing.'
                  : null,
              attempts: index == 2
                  ? []
                  : [
                      LocalSaleSyncAttempt(
                          number: 1,
                          startedAt: '2026-10-09T09:16:00',
                          endpoint: 'https://qa.invalid/order',
                          requestBody: jsonEncode(payload),
                          finishedAt: '2026-10-09T09:16:01',
                          outcome: state.value)
                    ])
          .toJson());
    }
    resetSync();
    await sync.hydrate();
  }

  void resetSync() {
    sync = LocalSaleSyncService(
        store: store,
        sender: (_, __, body) async {
          final payload = jsonDecode(body) as Map<String, dynamic>;
          requests.add(payload);
          await Future<void>.delayed(delay);
          if (responseMode == 'mixed' && payload['qa_id'] == 'qa-2') {
            return http.Response('{"message":"Invalid shipped ID"}', 422);
          }
          if (responseMode == 'mixed' && payload['qa_id'] == 'qa-3') {
            return http.Response('Connection outcome unknown', 500);
          }
          return http.Response(
              '{"order_id":${900 + requests.length},"order_number":"QA-${requests.length}"}',
              201);
        });
  }

  Widget wrap(Widget child) => MultiProvider(providers: [
        ChangeNotifierProvider<LocalProductProvider>.value(value: products),
        ChangeNotifierProvider<LocalSaleSyncService>.value(value: sync),
        ChangeNotifierProvider<AuthModel>(
            create: (_) => AuthModel()..login('qa-token', 1)),
        ChangeNotifierProvider<StoreSessionProvider>(
            create: (_) => StoreSessionProvider()),
        ChangeNotifierProvider<AppSettingsProvider>(
            create: (_) => OrdersQaSettings()),
      ], child: child);

  Future<void> dispose() async {
    products.dispose();
    sync.dispose();
    await LocalProductProvider.flushPendingPersistence();
    await Hive.close();
    // This directory was generated by createTemp and contains QA data only.
    if (dataDirectory.path.startsWith(Directory.systemTemp.path) &&
        dataDirectory.uri.pathSegments
            .where((part) => part.startsWith('confirmed_orders_qa_'))
            .isNotEmpty) {
      await dataDirectory.delete(recursive: true);
    }
  }
}

Future<void> main() async {
  if (!kDebugMode) throw StateError('The orders QA target is debug-only.');
  final collector = PrintLogCollector();
  MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(logCollector: collector));
  final originalDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) collector.addLog(message);
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
  final environment = OrdersQaEnvironment();
  await environment.initialize();
  final viewport = ValueNotifier<Size?>(null);
  registerMarionetteExtension(
      name: 'ordersQa.state',
      callback: (params) async {
        if (params['mode'] != null) environment.responseMode = params['mode']!;
        if (params['width'] != null) {
          viewport.value = Size(double.parse(params['width']!),
              double.parse(params['height'] ?? '740'));
        }
        return MarionetteExtensionResult.success({
          'requests': environment.requests,
          'records':
              environment.sync.records.map((record) => record.toJson()).toList()
        });
      });
  runApp(environment.wrap(ValueListenableBuilder<Size?>(
      valueListenable: viewport,
      builder: (context, size, _) => Center(
          child: SizedBox(
              width: size?.width,
              height: size?.height,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFF3C92F5)),
                    fontFamily: 'Poppins'),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(size: size ?? MediaQuery.sizeOf(context)),
                    child: child!),
                home: const ConfirmedOrdersPage(),
              ))))));
}
