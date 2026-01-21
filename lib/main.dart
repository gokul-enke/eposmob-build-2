import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/virtual_keyboard_widget.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/discount_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/restaurant/menu_provider.dart';
import 'package:pos_machine/providers/restaurant/order_provider.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/payment_gateways_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/company_account_provider.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';
import 'package:pos_machine/providers/transaction_provider.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:provider/provider.dart';
import 'controllers/sidebar_controller.dart';
import 'providers/cart.dart';
import 'providers/carousel_provider.dart';
import 'providers/purchase_provider.dart';
import 'screens/login/login.dart';
import 'screens/login/base_url_wrapper.dart';
import 'screens/login/api_key_screen.dart';
import 'helpers/keyboard_dispatcher.dart';
import 'helpers/date_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'resources/localization_service.dart';
import 'resources/app_translations.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await _requestPermissions();
  }

  // Initialize Hive in a dedicated ApplicationSupport/epos/hive_data folder
  // Safer than Documents (less likely to be deleted by user)
  final supportDir = await getApplicationSupportDirectory();
  final hiveBaseDir = Directory('${supportDir.path}/epos/hive_data');
  if (!await hiveBaseDir.exists()) {
    await hiveBaseDir.create(recursive: true);
  }

  Hive.init(hiveBaseDir.path);
  debugPrint('📁 Hive directory: ${hiveBaseDir.path}');

  // Register adapters
  Hive.registerAdapter(HiveStringValueAdapter());
  Hive.registerAdapter(HiveLocalCartItemAdapter());
  Hive.registerAdapter(HiveSavedOrderAdapter());
  Hive.registerAdapter(HiveProductAdapter());
  // Add missing adapter registrations
  Hive.registerAdapter(HiveGetProductAdapter());
  Hive.registerAdapter(HiveProductCategoryAdapter());
  Hive.registerAdapter(HiveProductPriceAdapter());
  Hive.registerAdapter(HiveAttachmentAdapter());
  // Register category adapters
  Hive.registerAdapter(HiveCategoryAdapter());
  Hive.registerAdapter(HiveParentCategoryAdapter());

  // Open boxes with error handling and retry logic
  await _initializeHiveBoxes();

  tz.initializeTimeZones();
  await LocalizationService.init();
  await DateHelper.init();

  Get.put(SideBarController());

  if (!kIsWeb) {
    if (Platform.isMacOS) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
  }

  Get.put(CategoryProvider());
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  final statuses = await [
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.locationWhenInUse,
    Permission.location,
  ].request();

  statuses.forEach((permission, status) {
    if (status.isGranted) {
      debugPrint('$permission permission granted.');
    } else if (status.isDenied) {
      debugPrint('$permission permission denied.');
    } else if (status.isPermanentlyDenied) {
      debugPrint('$permission permission permanently denied.');
      openAppSettings();
    }
  });
}

Future<void> _initializeHiveBoxes() async {
  const maxRetries = 3;
  const retryDelay = Duration(seconds: 2);

  const boxesToResetBeforeInit = ['products', 'categories'];

  for (final boxName in boxesToResetBeforeInit) {
    try {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        debugPrint(
            '⚠️ Box $boxName was open during initialization. Clearing and closing before reset.');
        await box.clear();
        await box.close();
      }

      final exists = await Hive.boxExists(boxName);

      if (exists) {
        debugPrint(
            '🧹 Clearing existing data for $boxName box before initialization');
        await Hive.deleteBoxFromDisk(boxName);
        debugPrint('✅ Cleared $boxName box from disk');
      } else {
        debugPrint('ℹ️ No existing data found for $boxName box to clear');
      }
    } catch (e) {
      debugPrint('⚠️ Unable to clear $boxName box before initialization: $e');
    }
  }

  final boxNames = [
    'products',
    'cart_items',
    'saved_orders',
    'confirmed_orders',
    'categories'
  ];

  for (String boxName in boxNames) {
    int attempts = 0;
    bool success = false;

    while (attempts < maxRetries && !success) {
      try {
        attempts++;
        debugPrint(
            '🔄 Attempting to open $boxName box (attempt $attempts/$maxRetries)');

        // Check if box is already open
        if (Hive.isBoxOpen(boxName)) {
          debugPrint('✅ Box $boxName is already open');
          success = true;
          continue;
        }

        // Try to open the box based on its type
        switch (boxName) {
          case 'products':
            await Hive.openBox<HiveProduct>(boxName);
            break;
          case 'cart_items':
            await Hive.openBox<HiveLocalCartItem>(boxName);
            break;
          case 'saved_orders':
          case 'confirmed_orders':
            await Hive.openBox<HiveSavedOrder>(boxName);
            break;
          case 'categories':
            await Hive.openBox<HiveCategory>(boxName);
            break;
        }

        debugPrint('✅ Successfully opened $boxName box');
        success = true;
      } catch (e) {
        debugPrint('❌ Failed to open $boxName box (attempt $attempts): $e');

        if (attempts >= maxRetries) {
          debugPrint(
              '🚨 Max retries reached for $boxName box. Attempting cleanup...');
          await _cleanupLockFiles(boxName);

          // Final attempt after cleanup
          try {
            switch (boxName) {
              case 'products':
                await Hive.openBox<HiveProduct>(boxName);
                break;
              case 'cart_items':
                await Hive.openBox<HiveLocalCartItem>(boxName);
                break;
              case 'saved_orders':
              case 'confirmed_orders':
                await Hive.openBox<HiveSavedOrder>(boxName);
                break;
              case 'categories':
                await Hive.openBox<HiveCategory>(boxName);
                break;
            }
            debugPrint('✅ Successfully opened $boxName box after cleanup');
            success = true;
          } catch (finalError) {
            debugPrint(
                '💥 Critical error: Cannot open $boxName box even after cleanup: $finalError');
            // Continue with other boxes instead of crashing the app
          }
        } else {
          // Wait before retrying
          await Future.delayed(retryDelay);
        }
      }
    }
  }
}

Future<void> _cleanupLockFiles(String boxName) async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final hiveBaseDir = Directory('${supportDir.path}/epos/hive_data');
    final lockFile = File('${hiveBaseDir.path}/$boxName.lock');

    if (await lockFile.exists()) {
      debugPrint('🧹 Attempting to remove stale lock file: ${lockFile.path}');
      await lockFile.delete();
      debugPrint('✅ Successfully removed lock file');
    } else {
      debugPrint('ℹ️ No lock file found for $boxName');
    }
  } catch (e) {
    debugPrint('⚠️ Could not cleanup lock file for $boxName: $e');
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => GridSelectionProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => Cart()),
        ChangeNotifierProvider(create: (_) => CarouselProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CustomerSelectionProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => GeneralSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryMethodsProvider()),
        ChangeNotifierProvider(create: (_) => LocalProductProvider()),
        ChangeNotifierProvider(create: (_) => PaymentGatewaysProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => SalesExecutiveProvider()),
        ChangeNotifierProvider(create: (_) => CompanyAccountProvider()),
        ChangeNotifierProvider(create: (_) => DocumentConfigProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(),
        ),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
        ChangeNotifierProvider(create: (_) => BarcodeProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => SharedPreferenceProvider()),
        ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
        ChangeNotifierProvider(create: (_) => TableProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => WhatsappProvider()),
        ChangeNotifierProvider(create: (_) => PineLabsTerminalProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => CustomerVoucherProvider()),
        ChangeNotifierProvider(create: (_) => SupplierVoucherProvider()),
        ChangeNotifierProvider(create: (_) => AppFontProvider()),
      ],
      child: KeyboardDispatcher(
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CLOUD POS',
          theme: ThemeData(),
          translations: AppTranslations(LocalizationService.translations),
          locale: LocalizationService.locale,
          fallbackLocale: LocalizationService.fallbackLocale,
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const GlobalVirtualKeyboard(),
              ],
            );
          },
          home: const BaseUrlWrapper(),
          routes: {
            '/login': (context) => const SignInScreen(),
            '/api-key': (context) => const ApiKeyScreen(),
          },
        ),
      ),
    );
  }
}
