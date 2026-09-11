import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/components/virtual_keyboard_widget.dart';
import 'package:pos_machine/components/startup_gate.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';
import 'package:pos_machine/services/startup_work_tracker.dart';
import 'package:pos_machine/components/order_submission_status.dart';
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
import 'package:pos_machine/providers/printer_settings_provider.dart';
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
import 'package:pos_machine/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ---------------------------------------------------------------------------
// Startup
//
// The native runner shows a splash before engine creation. StartupGate paints
// the first Flutter frame before initialization, then mounts providers once
// their required storage and product hydration are ready.
// ---------------------------------------------------------------------------

/// Longest any single startup step may take before we give up on it.
const Duration _defaultStepTimeout = Duration(seconds: 10);

/// Base wait for one Hive box. Large boxes get more, see [_boxOpenBudget].
///
/// Note that a lock held by another process does *not* make the open wait:
/// Hive calls `RandomAccessFile.lock()` in non-blocking mode, which on Windows
/// throws `PathAccessException ... lock failed ... errno = 33` immediately.
/// Lock conflicts are therefore handled by [_openBoxWithRecovery]'s retry
/// loop, not by this timeout; the timeout only bounds the file read itself.
const Duration _boxOpenTimeout = Duration(seconds: 8);

/// How long to keep retrying a box whose lock is held by another process.
/// Covers a previous copy of the app that is still shutting down. Past this
/// the only explanation is a second running copy, which needs the user.
const Duration _lockConflictRetryWindow = Duration(seconds: 6);
const Duration _lockConflictRetryDelay = Duration(milliseconds: 500);

/// Hive reads a non-lazy box completely into memory before `openBox` returns,
/// so open time grows with file size. A 30k-product catalog is easily a few
/// hundred MB on disk; on a spinning disk or behind an antivirus scan that is
/// far more than 8 s. Every 10 MB buys one more second, up to this ceiling.
const int _boxOpenBytesPerExtraSecond = 10 * 1024 * 1024;
const Duration _maxBoxOpenTimeout = Duration(seconds: 90);

/// Hard ceiling for the whole sequence. Past this we show the failure screen
/// rather than leave the user staring at an empty desktop. Sized so the
/// worst-case product box wait (three tries at [_maxBoxOpenTimeout]) still
/// reports its own, more specific error first.
const Duration _startupBudget = Duration(seconds: 300);

/// Boxes the till cannot run without. `LocalProductProvider` grabs these with
/// `Hive.box()` in its field initializers, so a box that silently failed to
/// open here would surface later as a dead billing screen with no message.
/// A failure on one of these goes to the failure screen instead.
const List<String> _requiredBoxNames = <String>[
  'products',
  'cart_items',
  'saved_orders',
  'confirmed_orders',
];

/// Boxes whose absence only degrades the app. They are re-synced from the
/// server, so an unreadable file is deleted and recreated.
const List<String> _optionalBoxNames = <String>[
  'categories',
  'categories_all',
  'categories_purchasable',
  'document_configs',
];

/// Where Hive keeps its files on this machine. Set by [_initializeHiveStorage].
String? _hiveDirectoryPath;

/// Non-fatal problems collected during startup, surfaced on the failure screen.
final List<String> _startupWarnings = <String>[];
ValueChanged<String>? _reportStartupStage;
final _startupWork = StartupWorkTracker();
LocalProductProvider? _startupProducts;
bool _appReady = false;
Future<void>? _restartPreparation;
const _lifecycleChannel = MethodChannel('cloudpos/lifecycle');

Future<void> _prepareForRestart() => _restartPreparation ??= () async {
      // The startup screen owns these tasks. A ready till can have independent
      // network/printer operations: never pretend closing Hive alone drains those.
      if (_appReady) {
        throw StateError(
            'This CloudPOS copy is active. Close it normally first.');
      }
      await _startupWork.stopAndDrain();
      await _startupProducts?.flushPersistence();
      await Hive.close();
    }()
        .onError<Object>((error, stack) {
      // A transient close failure must not poison every subsequent attempt.
      _restartPreparation = null;
      Error.throwWithStackTrace(error, stack);
    });

void main() {
  _initializeBinding();
  _lifecycleChannel.setMethodCallHandler((call) async {
    if (call.method != 'prepareRestart') throw MissingPluginException();
    await _prepareForRestart();
  });
  runApp(StartupGate(
      initialize: _bootstrap,
      onClose: () => exit(1),
      onRestart: !kIsWeb && Platform.isWindows
          ? () => const MethodChannel('cloudpos/lifecycle')
              .invokeMethod<void>('restart')
          : null));
}

Future<Widget> _bootstrap(ValueChanged<String> reportStage) async {
  _reportStartupStage = reportStage;
  final clock = Stopwatch()..start();
  reportStage('Preparing CloudPOS…');
  try {
    await SentryConfig.init().timeout(_defaultStepTimeout);
  } catch (e, stackTrace) {
    debugPrint('Sentry init failed: $e\n$stackTrace');
  }

  try {
    await _startupWork.run(_initializeApp).timeout(_startupBudget);
    await _startupWork.run(OrderSubmissionCoordinator.instance.hydrate);
    reportStage('Loading products and saved orders…');
    _startupWork.checkRunning();
    final localProducts = _startupProducts = LocalProductProvider();
    try {
      await _startupWork
          .run(() => localProducts.hydrated)
          .timeout(_maxBoxOpenTimeout);
    } catch (_) {
      // timeout does not cancel hydration. Dispose only after its source has
      // stopped notifying, without mounting this failed startup attempt.
      unawaited(localProducts.hydrated.then((_) => localProducts.dispose(),
          onError: (Object _, StackTrace __) => localProducts.dispose()));
      rethrow;
    }
    debugPrint('[Startup] ready elapsed_ms=${clock.elapsedMilliseconds}');
    _startupWork.checkRunning();
    _appReady = true;
    return SentryWidget(child: MyApp(localProducts: localProducts));
  } catch (error, stackTrace) {
    debugPrint('[Startup] failed elapsed_ms=${clock.elapsedMilliseconds}');
    unawaited(_reportStartupFailure(error, stackTrace));
    rethrow;
  } finally {
    _reportStartupStage = null;
  }
}

void _initializeBinding() {
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
    SentryWidgetsFlutterBinding.ensureInitialized();
  }
}

Future<void> _initializeApp() async {
  await _startupStep(
      'read saved server URL', _initializeBaseUrlFromPreferences);
  await _startupStep(
      'read notification position', _initializeNotificationPosition);
  _startupStepSync(
      'tag Sentry with app URL', () => SentryConfig.setAppUrl(APPUrl.baseURL));

  // Local storage is not optional for a till — without it there is nothing to
  // sell from — so a failure here is fatal and reported on screen instead of
  // letting the app limp on and break somewhere deeper.
  await _requiredStartupStep(
    'open the local storage folder',
    _initializeHiveStorage,
    timeout: const Duration(seconds: 20),
  );
  _startupStepSync('register storage adapters', _registerHiveAdapters);
  await _initializeHiveBoxes();
  await openOrderRecoveryStorage();

  _startupStepSync('load time zones', tz.initializeTimeZones);
  await _startupStep('load translations', LocalizationService.init);
  await _startupStep('load date settings', DateHelper.init);

  _startupStepSync('start controllers', () {
    Get.put(SideBarController());

    if (!kIsWeb && Platform.isMacOS) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }

    Get.put(CategoryProvider());
    HttpOverrides.global = MyHttpOverrides();
  });

  await _startupStep(
    'load .env configuration',
    () => dotenv.load(fileName: '.env'),
  );
}

/// Exercises the production durable recovery open path in disk regression tests.
@visibleForTesting
Future<void> openOrderRecoveryStorage() async {
  const recoveryBox = 'order_submissions';
  final recoveryBudget = await _boxOpenBudget(recoveryBox);
  await _requiredStartupStep(
    'open order recovery storage',
    () => _openBoxWithRecovery(recoveryBox,
        budget: recoveryBudget,
        // Contains uncertain sales and the cart identity, not disposable cache.
        recreateIfUnreadable: false),
    timeout: recoveryBudget * 3 +
        _lockConflictRetryWindow +
        const Duration(seconds: 5),
  );
}

/// Runs one optional startup step. A failure is recorded and startup carries
/// on — the app is more useful degraded than invisible.
Future<void> _startupStep(
  String stage,
  Future<void> Function() step, {
  Duration timeout = _defaultStepTimeout,
}) async {
  _reportStartupStage?.call(_startupStageText(stage));
  final clock = Stopwatch()..start();
  try {
    await _startupWork.run(step).timeout(timeout);
  } catch (error, stackTrace) {
    _recordStartupWarning(stage, error, stackTrace);
  } finally {
    debugPrint(
        '[Startup] stage=$stage elapsed_ms=${clock.elapsedMilliseconds}');
  }
}

String _startupStageText(String stage) {
  if (stage.contains('storage') || stage.contains('cache')) {
    return 'Opening your saved data…';
  }
  if (stage.contains('translation')) return 'Loading language settings…';
  return 'Loading your settings…';
}

void _startupStepSync(String stage, void Function() step) {
  _startupWork.checkRunning();
  try {
    step();
  } catch (error, stackTrace) {
    _recordStartupWarning(stage, error, stackTrace);
  }
}

/// Runs a step the app genuinely cannot start without. Failures are rethrown
/// with the stage attached so the failure screen can name what broke.
Future<void> _requiredStartupStep(
  String stage,
  Future<void> Function() step, {
  Duration timeout = _defaultStepTimeout,
}) async {
  _reportStartupStage?.call(_startupStageText(stage));
  final clock = Stopwatch()..start();
  try {
    await _startupWork.run(step).timeout(timeout);
  } catch (error, stackTrace) {
    debugPrint('💥 Required startup step "$stage" failed: $error\n$stackTrace');
    Error.throwWithStackTrace(StartupStepException(stage, error), stackTrace);
  } finally {
    debugPrint(
        '[Startup] stage=$stage elapsed_ms=${clock.elapsedMilliseconds}');
  }
}

void _recordStartupWarning(String stage, Object error, StackTrace stackTrace) {
  _startupWarnings.add('$stage — $error');
  debugPrint('⚠️ Startup step "$stage" failed: $error\n$stackTrace');
  unawaited(
    _reportStartupFailure(StartupStepException(stage, error), stackTrace),
  );
}

Future<void> _reportStartupFailure(Object error, StackTrace? stackTrace) async {
  try {
    await Sentry.captureException(error, stackTrace: stackTrace);
  } catch (_) {
    // Sentry may not have initialized; the on-screen report is the fallback.
  }
}

class StartupStepException implements Exception {
  StartupStepException(this.stage, this.cause);

  final String stage;
  final Object cause;

  @override
  String toString() => 'Could not $stage: $cause';
}

Future<void> _initializeNotificationPosition() async {
  final prefs = SharedPreferenceProvider();
  final position = await prefs.getNotificationPosition();
  dialog_box.setNotificationPosition(position);
  custom_dialog_box.setNotificationPosition(position);
}

Future<void> _initializeBaseUrlFromPreferences() async {
  final prefs = await sp.SharedPreferences.getInstance();
  final savedAppUrl = prefs.getString('app_url');
  if (savedAppUrl != null && savedAppUrl.trim().isNotEmpty) {
    APPUrl.updateBaseURL(savedAppUrl);
  }
}

Future<void> _initializeHiveStorage() async {
  if (kIsWeb) {
    // Browsers do not provide a native application-support directory.
    // Hive's web adapter stores boxes in browser storage instead.
    await Hive.initFlutter();
    return;
  }

  // Initialize Hive in a dedicated ApplicationSupport/epos/hive_data folder
  // Safer than Documents (less likely to be deleted by user)
  final supportDir = await getApplicationSupportDirectory();
  final hiveBaseDir = Directory('${supportDir.path}/epos/hive_data');
  if (!await hiveBaseDir.exists()) {
    await hiveBaseDir.create(recursive: true);
  }

  Hive.init(hiveBaseDir.path);
  _hiveDirectoryPath = hiveBaseDir.path;
  debugPrint('📁 Hive directory: ${hiveBaseDir.path}');
}

File? _hiveBoxFile(String boxName) {
  final dir = _hiveDirectoryPath;
  if (kIsWeb || dir == null) return null;
  return File('$dir/${boxName.toLowerCase()}.hive');
}

Future<int> _hiveBoxSizeBytes(String boxName) async {
  try {
    final file = _hiveBoxFile(boxName);
    if (file == null || !await file.exists()) return 0;
    return await file.length();
  } catch (_) {
    return 0;
  }
}

/// [_boxOpenTimeout] plus one second per 10 MB on disk, capped at
/// [_maxBoxOpenTimeout].
Future<Duration> _boxOpenBudget(String boxName) async {
  final bytes = await _hiveBoxSizeBytes(boxName);
  final extraSeconds = (bytes / _boxOpenBytesPerExtraSecond).ceil();
  final budget = _boxOpenTimeout + Duration(seconds: extraSeconds);
  return budget > _maxBoxOpenTimeout ? _maxBoxOpenTimeout : budget;
}

void _registerHiveAdapters() {
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
}

Future<void> _initializeHiveBoxes() async {
  const boxesToResetBeforeInit = ['categories'];

  for (final boxName in boxesToResetBeforeInit) {
    await _startupStep(
      'reset the "$boxName" cache',
      () => _resetBoxOnDisk(boxName),
      timeout: _boxOpenTimeout,
    );
  }

  for (final boxName in _requiredBoxNames) {
    final budget = await _boxOpenBudget(boxName);
    await _requiredStartupStep(
      'open "$boxName" storage',
      () => _openBoxWithRecovery(
        boxName,
        budget: budget,
        // The product catalog is a cache and is re-synced from the server, so
        // an unreadable file is replaced. Carts and orders are unsynced sales
        // and must never be thrown away silently.
        recreateIfUnreadable: boxName == 'products',
      ),
      // Three opens plus the retry pauses and the lock-conflict window.
      timeout:
          budget * 3 + _lockConflictRetryWindow + const Duration(seconds: 5),
    );
  }

  for (final boxName in _optionalBoxNames) {
    final budget = await _boxOpenBudget(boxName);
    await _startupStep(
      'open "$boxName" storage',
      () => _openBoxWithRecovery(
        boxName,
        budget: budget,
        recreateIfUnreadable: true,
      ),
      timeout:
          budget * 3 + _lockConflictRetryWindow + const Duration(seconds: 5),
    );
  }
}

/// True when [error] means another process holds the box (or its lock file).
///
/// Seen in production as `lock failed ... errno = 33` (lock violation) on
/// `<box>.lock`, and as `Cannot delete file ... errno = 32` (sharing
/// violation) when Hive tears down a failed open and cannot remove the lock
/// file the other process still holds.
bool _isLockConflict(Object error) {
  if (error is! FileSystemException) return false;
  final code = error.osError?.errorCode;
  if (code == 32 || code == 33) return true;
  final text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
  return text.contains('lock') ||
      text.contains('being used by another process') ||
      (error.path?.toLowerCase().endsWith('.lock') ?? false);
}

/// Thrown when another copy of the app keeps a box locked. Carries the
/// message the failure screen shows to the user.
class StorageLockedException implements Exception {
  StorageLockedException(this.boxName, this.cause);

  final String boxName;
  final Object cause;

  @override
  String toString() =>
      'Another copy of CLOUDPOS still has the "$boxName" storage open. '
      'Close it, or end every cloudpos.exe task in Task Manager, then open '
      'CLOUDPOS again. ($cause)';
}

/// Opens [boxName] with three kinds of recovery:
///
///  * **Lock held by another process.** Retried for
///    [_lockConflictRetryWindow] so a previous copy that is still shutting
///    down can release it. After that a [StorageLockedException] is thrown.
///    The box is never deleted or recreated on a lock conflict, and the lock
///    file is never touched: the other process owns it.
///  * **Other transient error.** Retried once, then once more after clearing
///    a stale lock file.
///  * **Unreadable file** (a row whose adapter cast fails, which Hive's
///    CRC-based crash recovery does not catch). If [recreateIfUnreadable] is
///    set the box is deleted and recreated so the app can re-sync instead of
///    failing on every launch.
///
/// A timeout is never retried: the underlying open keeps running and a second
/// call would only queue behind it.
Future<void> _openBoxWithRecovery(
  String boxName, {
  required Duration budget,
  required bool recreateIfUnreadable,
}) async {
  const retryDelay = Duration(milliseconds: 400);

  if (Hive.isBoxOpen(boxName)) {
    debugPrint('✅ Box $boxName is already open');
    return;
  }

  Future<void> attemptOpen() async {
    try {
      await _startupWork.run(() => _openTypedBox(boxName)).timeout(budget);
    } on TimeoutException {
      final sizeMb = (await _hiveBoxSizeBytes(boxName)) / (1024 * 1024);
      throw TimeoutException(
        'The "$boxName" storage did not open within ${budget.inSeconds}s '
        '(${sizeMb.toStringAsFixed(1)} MB on disk). Either the disk is very '
        'slow or an antivirus scan is holding the file.',
      );
    }
  }

  Object? lastError;
  StackTrace? lastStackTrace;
  final lockConflictsSince = Stopwatch()..start();
  var lockConflicts = 0;
  var otherFailures = 0;
  var clearedLockFile = false;

  while (true) {
    _startupWork.checkRunning();
    debugPrint('🔄 Opening $boxName box (budget ${budget.inSeconds}s, '
        'lock conflicts $lockConflicts, other failures $otherFailures)');
    try {
      await attemptOpen();
      debugPrint('✅ Successfully opened $boxName box');
      return;
    } on TimeoutException {
      rethrow;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      if (_isLockConflict(error)) {
        lockConflicts++;
        if (lockConflictsSince.elapsed >= _lockConflictRetryWindow) {
          debugPrint('🔒 $boxName box is still locked by another process '
              'after ${lockConflictsSince.elapsed.inSeconds}s: $error');
          Error.throwWithStackTrace(
            StorageLockedException(boxName, error),
            stackTrace,
          );
        }
        debugPrint('🔒 $boxName box is locked by another process; '
            'waiting for it to be released');
        await Future<void>.delayed(_lockConflictRetryDelay);
        continue;
      }

      otherFailures++;
      debugPrint(
          '❌ Failed to open $boxName box (failure $otherFailures): $error');
      if (otherFailures == 1) {
        await Future<void>.delayed(retryDelay);
        continue;
      }
      if (!clearedLockFile) {
        clearedLockFile = true;
        debugPrint(
            '🧹 Clearing a possible stale lock for $boxName and retrying');
        await _cleanupLockFiles(boxName);
        continue;
      }
      break;
    }
  }

  if (!recreateIfUnreadable) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  // The file is unreadable. Report it, then start over with an empty box.
  debugPrint('🚨 "$boxName" storage is unreadable; deleting and recreating: '
      '$lastError');
  _startupWarnings.add(
      'the "$boxName" cache was unreadable and has been reset — $lastError');
  unawaited(_reportStartupFailure(
    StartupStepException('read "$boxName" storage (reset)', lastError),
    lastStackTrace,
  ));
  await Hive.deleteBoxFromDisk(boxName);
  await attemptOpen();
  debugPrint('✅ Recreated $boxName box');
}

Future<void> _resetBoxOnDisk(String boxName) async {
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
}

/// Single source of truth for a box's element type. The retry-after-cleanup
/// path used to carry its own copy of this switch and had silently dropped
/// `categories_all`, `categories_purchasable` and `document_configs`, so those
/// boxes were never reopened after a cleanup.
Future<void> _openTypedBox(String boxName) async {
  switch (boxName) {
    case 'order_submissions':
      await Hive.openBox(boxName);
      break;
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
    default:
      throw ArgumentError('No Hive box type registered for "$boxName"');
  }
}

Future<void> _cleanupLockFiles(String boxName) async {
  if (kIsWeb) {
    return;
  }

  try {
    final dir = _hiveDirectoryPath;
    if (dir == null) {
      return;
    }
    final lockFile = File('$dir/${boxName.toLowerCase()}.lock');

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

/// Shown instead of a hidden window when startup cannot complete, so the user
/// gets something they can read and send to support.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.error,
    required this.warnings,
  });

  final Object error;
  final List<String> warnings;

  String get _details {
    final buffer = StringBuffer()
      ..writeln('CLOUDPOS failed to start.')
      ..writeln()
      ..writeln('Error: $error');
    if (warnings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Other problems during startup:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CLOUDPOS',
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'CLOUDPOS could not start',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If CLOUDPOS is already running, close it — or end the '
                    'cloudpos.exe task — and open it again. If the local '
                    'storage is large or the disk is slow, wait a minute '
                    'before retrying. If this keeps happening, send the '
                    'details below to support.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _details,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _details)),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy details'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => exit(1),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
  const MyApp({super.key, this.localProducts});
  final LocalProductProvider? localProducts;

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
        ChangeNotifierProvider(
            create: (_) => localProducts ?? LocalProductProvider()),
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
        ChangeNotifierProvider(create: (_) => PrinterSettingsProvider()),
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
                    navigatorObservers: [
                      SentryNavigatorObserver(),
                    ],
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
                      final content = OrderSubmissionStatus(
                          child: child ?? const SizedBox.shrink());
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
                            Expanded(child: content),
                            const GlobalVirtualKeyboard(),
                          ],
                        );
                      }

                      return Stack(
                        children: [
                          content,
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
