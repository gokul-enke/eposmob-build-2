import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/virtual_keyboard_widget.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
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
import 'package:pos_machine/providers/keyboard_focus_highlight_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
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
import 'package:pos_machine/providers/expense_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/pine_labs_terminal_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart' as dialog_box;
import 'package:pos_machine/newcomponents/custom_dialog_box.dart'
    as custom_dialog_box;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart' as sp;
import 'controllers/sidebar_controller.dart';
import 'providers/cart.dart';
import 'providers/carousel_provider.dart';
import 'providers/purchase_provider.dart';
import 'resources/app_url.dart';
import 'screens/login/login.dart';
import 'screens/login/base_url_wrapper.dart';
import 'screens/login/api_key_screen.dart';
import 'helpers/keyboard_dispatcher.dart';
import 'helpers/date_helper.dart';
import 'helpers/orientation_helper.dart';
import 'resources/localization_service.dart';
import 'resources/app_translations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_repository.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_lifecycle.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_lifecycle.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';

void main() async {
  if (kDebugMode) {
    final logCollector = PrintLogCollector();

    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(logCollector: logCollector),
    );

    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        logCollector.addLog(message);
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await _initializeBaseUrlFromPreferences();
  await _initializeNotificationPosition();

  if (kIsWeb) {
    // Browsers do not provide a native application-support directory.
    // Hive's web adapter stores boxes in browser storage instead.
    await Hive.initFlutter();
  } else {
    // Initialize Hive in a dedicated ApplicationSupport/epos/hive_data folder
    // Safer than Documents (less likely to be deleted by user)
    final supportDir = await getApplicationSupportDirectory();
    final hiveBaseDir = Directory('${supportDir.path}/epos/hive_data');
    if (!await hiveBaseDir.exists()) {
      await hiveBaseDir.create(recursive: true);
    }

    Hive.init(hiveBaseDir.path);
    debugPrint('📁 Hive directory: ${hiveBaseDir.path}');
  }

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
  // Register product tax adapter
  Hive.registerAdapter(HiveProductTaxAdapter());
  // Register document config adapter
  Hive.registerAdapter(HiveDocumentConfigAdapter());

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
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
        "main: .env not found or failed to load, continuing without it: $e");
  }
  runApp(const MyApp());
}

Future<void> _initializeNotificationPosition() async {
  final prefs = SharedPreferenceProvider();
  final position = await prefs.getNotificationPosition();
  dialog_box.setNotificationPosition(position);
  custom_dialog_box.setNotificationPosition(position);
}

Future<void> _initializeBaseUrlFromPreferences() async {
  try {
    final prefs = await sp.SharedPreferences.getInstance();
    final savedAppUrl = prefs.getString('app_url');
    if (savedAppUrl != null && savedAppUrl.trim().isNotEmpty) {
      APPUrl.updateBaseURL(savedAppUrl);
    }
  } catch (_) {}
}

Future<void> _initializeHiveBoxes() async {
  const maxRetries = 3;
  const retryDelay = Duration(seconds: 2);

  const boxesToResetBeforeInit = ['categories'];

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
    'categories',
    'categories_all',
    'categories_purchasable',
    'document_configs'
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
          case 'categories_all':
          case 'categories_purchasable':
            await Hive.openBox<HiveCategory>(boxName);
            break;
          case 'document_configs':
            await Hive.openBox<HiveDocumentConfig>(boxName);
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
  if (kIsWeb) {
    return;
  }

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
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CustomerSelectionProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => GeneralSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AdminSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryMethodsProvider()),
        ChangeNotifierProvider(create: (_) => LocalProductProvider()),
        ChangeNotifierProvider(create: (_) => PaymentGatewaysProvider()),
        ChangeNotifierProvider(create: (_) => BankProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => SalesExecutiveProvider()),
        ChangeNotifierProvider(create: (_) => CompanyAccountProvider()),
        ChangeNotifierProvider(create: (_) => DocumentConfigProvider()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(),
        ),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
        ChangeNotifierProvider(create: (_) => KeyboardFocusHighlightProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
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
        ChangeNotifierProvider(create: (_) => QuotationsProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProxyProvider6<
            LocalProductProvider,
            CustomerProvider,
            CustomerSelectionProvider,
            StockProvider,
            SalesProvider,
            SyncProvider,
            RealtimeSyncProvider>(
          create: (context) => RealtimeSyncProvider(
            repository: RealtimeSyncRepository(
              entityApi: RealtimeEntityApi(),
              localProducts: context.read<LocalProductProvider>(),
              customers: context.read<CustomerProvider>(),
              customerSelection: context.read<CustomerSelectionProvider>(),
              stocks: context.read<StockProvider>(),
              sales: context.read<SalesProvider>(),
            ),
            manualSync: context.read<SyncProvider>(),
          ),
          update: (
            _,
            localProducts,
            customers,
            customerSelection,
            stocks,
            sales,
            manualSync,
            realtime,
          ) =>
              realtime ??
              RealtimeSyncProvider(
                repository: RealtimeSyncRepository(
                  entityApi: RealtimeEntityApi(),
                  localProducts: localProducts,
                  customers: customers,
                  customerSelection: customerSelection,
                  stocks: stocks,
                  sales: sales,
                ),
                manualSync: manualSync,
              ),
        ),
      ],
      child: SubscriptionLifecycle(
        child: RealtimeSyncLifecycle(
          child: OrientationLock(
            child: KeyboardDispatcher(
              child: Consumer<KeyboardFocusHighlightProvider>(
                builder: (context, focusHighlightProvider, child) {
                  return GetMaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'CLOUDPOS',
                    theme: _buildAppTheme(focusHighlightProvider.enabled),
                    translations:
                        AppTranslations(LocalizationService.translations),
                    locale: LocalizationService.locale,
                    fallbackLocale: LocalizationService.fallbackLocale,
                    supportedLocales: LocalizationService.supportedLocales,
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder: (context, child) {
                      final screenSize = MediaQuery.of(context).size;
                      final platform = Theme.of(context).platform;

                      // Phone only: Column layout so keyboard pushes content up.
                      // Tablets + Desktop: Stack overlay for floating draggable keyboard.
                      final isPhone = (platform == TargetPlatform.android ||
                              platform == TargetPlatform.iOS) &&
                          screenSize.width < 600; // Phone threshold

                      if (isPhone) {
                        return Column(
                          children: [
                            Expanded(child: child ?? const SizedBox.shrink()),
                            const GlobalVirtualKeyboard(),
                          ],
                        );
                      }

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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App-wide theme with strong, visible focus indicators.
//
// Every Tab-stop on the billing flow needs a clearly-visible focus ring so
// keyboard users can always tell where the cursor is. We do this at the
// theme level so standard widgets (TextField, ElevatedButton, OutlinedButton,
// TextButton, IconButton, FilledButton, InkWell-based ListTile, etc.) all
// pick it up automatically — no per-widget wiring required.
// ---------------------------------------------------------------------------
ThemeData _buildAppTheme(bool focusHighlightEnabled) {
  // Resolves the overlay colour for the four interactive states a Material
  // button can be in. Focus uses the primary halo; press/hover stay light.
  WidgetStateProperty<Color?> overlayForButtons() {
    return WidgetStateProperty.resolveWith<Color?>((states) {
      if (focusHighlightEnabled && states.contains(WidgetState.focused)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.hovered)) {
        return ColorManager.kPrimaryColor.withOpacity(0.08);
      }
      if (states.contains(WidgetState.pressed)) {
        return ColorManager.kPrimaryColor.withOpacity(0.16);
      }
      return null;
    });
  }

  return ThemeData(
    // `focusColor` is what InkWell / InkResponse splash uses when its host
    // FocusNode has primary focus.
    focusColor: Colors.transparent,
    // Standard Material splashes pick up the primary tint as well.
    splashColor: ColorManager.kPrimaryColor.withOpacity(0.12),
    highlightColor: ColorManager.kPrimaryColor.withOpacity(0.08),

    // ---- Buttons ----
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(overlayColor: overlayForButtons()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(overlayColor: overlayForButtons()),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(overlayColor: overlayForButtons()),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(overlayColor: overlayForButtons()),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(overlayColor: overlayForButtons()),
    ),

    // ---- Dialogs ----
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),

    // ---- Text fields ----
    // Bold the focused border so the active TextField is unmistakable.
    inputDecorationTheme: focusHighlightEnabled
        ? InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: ColorManager.kPrimaryColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : null,
  );
}
