import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import '../providers/local_product_provider.dart';
import '../providers/category_providers.dart';
import '../providers/category_list_scope.dart';
import '../providers/document_config_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/auth_model.dart';
import '../providers/supplier_provider.dart';
import 'general_settings_provider.dart';
import 'app_settings_provider.dart';
import '../providers/delivery_methods_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/role_provider.dart';
import 'offline_sync_endpoints.dart';
import 'package:pos_machine/features/realtime_sync/domain/sync_operation_gate.dart';

enum OfflineSyncTarget {
  products,
  categories,
  stock,
  paymentMethods,
  deliveryMethods,
  documentConfigs,
  customers,
  suppliers,
  stores,
  units,
  racks,
  settings,
  roles,
}

enum OfflineSyncSection {
  catalog,
  billing,
  customersAndSuppliers,
  storeReference,
}

/// Comprehensive sync provider that handles synchronization of all data
/// across the application. Follows the Provider Pattern preference for
/// centralized API calls and state management.
class SyncProvider extends ChangeNotifier {
  final Object _syncGateOwner = Object();
  bool _isSyncing = false;
  bool _cancelRequested = false;
  String _syncMessage = '';
  double _syncProgress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastSyncTime;
  String? _activeSyncKey;

  // Getters
  bool get isSyncing => _isSyncing;
  String get syncMessage => _syncMessage;
  double get syncProgress => _syncProgress;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get activeSyncKey => _activeSyncKey;

  bool isSyncingKey(String key) => _isSyncing && _activeSyncKey == key;

  Future<String> _requireAccessToken(BuildContext context) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final accessToken = authModel.token;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('No access token available. Please login again.');
    }
    return accessToken;
  }

  void _ensureCanSync(BuildContext context) {
    if (_isSyncing) {
      throw Exception('Another sync is already in progress.');
    }

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (!billingProvider.hasInternet) {
      final message = billingProvider.isManualOfflineMode
          ? 'Sync is unavailable while Offline Mode is enabled.'
          : 'No internet connection. Sync is unavailable.';
      _syncError(message);
      throw Exception(message);
    }
    if (!SyncOperationGate.instance.tryAcquire(_syncGateOwner)) {
      throw Exception('Realtime synchronization is currently in progress.');
    }
  }

  /// Sync a single offline data type.
  Future<void> syncTarget(
    BuildContext context,
    OfflineSyncTarget target,
  ) async {
    await OfflineSyncEndpoints.logTarget(
      'Row sync → ${_labelForTarget(target)}',
      target,
    );
    try {
      final accessToken = await _requireAccessToken(context);
      _ensureCanSync(context);

      _startSync();
      _activeSyncKey = target.name;

      switch (target) {
        case OfflineSyncTarget.products:
          _updateProgress(0.5, 'Syncing products...');
          await _syncProducts(context, accessToken);
          break;
        case OfflineSyncTarget.categories:
          _updateProgress(0.5, 'Syncing categories...');
          await _syncCategories(context);
          break;
        case OfflineSyncTarget.stock:
          _updateProgress(0.5, 'Syncing stock quantities...');
          await _syncStockData(context, accessToken);
          break;
        case OfflineSyncTarget.paymentMethods:
          _updateProgress(0.5, 'Syncing payment methods...');
          await Provider.of<InvoiceProvider>(context, listen: false)
              .listAllPaymentList(accessToken, forceRefresh: true);
          break;
        case OfflineSyncTarget.deliveryMethods:
          _updateProgress(0.5, 'Syncing delivery methods...');
          await _syncDeliveryMethods(context);
          break;
        case OfflineSyncTarget.documentConfigs:
          _updateProgress(0.5, 'Syncing document configurations...');
          await _syncDocumentConfigurations(context, accessToken);
          break;
        case OfflineSyncTarget.customers:
          _updateProgress(0.5, 'Syncing customers...');
          await Provider.of<CustomerProvider>(context, listen: false)
              .fetchCustomers(accessToken: accessToken, listAll: true);
          break;
        case OfflineSyncTarget.suppliers:
          _updateProgress(0.5, 'Syncing suppliers...');
          await _syncSuppliers(context, accessToken);
          break;
        case OfflineSyncTarget.stores:
          _updateProgress(0.5, 'Syncing stores...');
          await Provider.of<PurchaseProvider>(context, listen: false)
              .listAllStores(accessToken, null);
          break;
        case OfflineSyncTarget.units:
          _updateProgress(0.5, 'Syncing units...');
          await Provider.of<PurchaseProvider>(context, listen: false)
              .listAllUnits(accessToken);
          break;
        case OfflineSyncTarget.racks:
          _updateProgress(0.5, 'Syncing rack metadata...');
          await Provider.of<PurchaseProvider>(context, listen: false)
              .listMasterDataValues(accessToken, 'RACKS');
          break;
        case OfflineSyncTarget.settings:
          _updateProgress(0.5, 'Syncing settings...');
          await Provider.of<GeneralSettingsProvider>(context, listen: false)
              .fetchGeneralSettings();
          await Provider.of<AppSettingsProvider>(context, listen: false)
              .fetchAppSettings();
          break;
        case OfflineSyncTarget.roles:
          _updateProgress(0.5, 'Syncing roles and permissions...');
          await _syncRoles(context);
          break;
      }

      _updateProgress(1.0, 'Sync completed!');
      _lastSyncTime = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 400));
      _completSync();
    } catch (e) {
      debugPrint('❌ Target sync failed ($target): $e');
      _syncError(e.toString());
      rethrow;
    }
  }

  /// Sync all targets in a section (e.g. catalog, billing).
  Future<void> syncSection(
    BuildContext context,
    OfflineSyncSection section,
  ) async {
    await OfflineSyncEndpoints.logSection(
      'Section sync → ${section.name}',
      section,
    );

    final targets = switch (section) {
      OfflineSyncSection.catalog => [
          OfflineSyncTarget.products,
          OfflineSyncTarget.categories,
          OfflineSyncTarget.stock,
        ],
      OfflineSyncSection.billing => [
          OfflineSyncTarget.paymentMethods,
          OfflineSyncTarget.deliveryMethods,
          OfflineSyncTarget.documentConfigs,
        ],
      OfflineSyncSection.customersAndSuppliers => [
          OfflineSyncTarget.customers,
          OfflineSyncTarget.suppliers,
        ],
      OfflineSyncSection.storeReference => [
          OfflineSyncTarget.stores,
          OfflineSyncTarget.units,
          OfflineSyncTarget.racks,
        ],
    };

    try {
      final accessToken = await _requireAccessToken(context);
      _ensureCanSync(context);
      _startSync();
      _activeSyncKey = 'section:${section.name}';
      final total = targets.length;

      for (var i = 0; i < targets.length; i++) {
        final target = targets[i];
        final progress = (i + 1) / total;
        _updateProgress(progress, 'Syncing ${_labelForTarget(target)}...');

        switch (target) {
          case OfflineSyncTarget.products:
            await _syncProducts(context, accessToken);
            break;
          case OfflineSyncTarget.categories:
            await _syncCategories(context);
            break;
          case OfflineSyncTarget.stock:
            await _syncStockData(context, accessToken);
            break;
          case OfflineSyncTarget.paymentMethods:
            await Provider.of<InvoiceProvider>(context, listen: false)
                .listAllPaymentList(accessToken, forceRefresh: true);
            break;
          case OfflineSyncTarget.deliveryMethods:
            await _syncDeliveryMethods(context);
            break;
          case OfflineSyncTarget.documentConfigs:
            await _syncDocumentConfigurations(context, accessToken);
            break;
          case OfflineSyncTarget.customers:
            await Provider.of<CustomerProvider>(context, listen: false)
                .fetchCustomers(accessToken: accessToken, listAll: true);
            break;
          case OfflineSyncTarget.suppliers:
            await _syncSuppliers(context, accessToken);
            break;
          case OfflineSyncTarget.stores:
            await Provider.of<PurchaseProvider>(context, listen: false)
                .listAllStores(accessToken, null);
            break;
          case OfflineSyncTarget.units:
            await Provider.of<PurchaseProvider>(context, listen: false)
                .listAllUnits(accessToken);
            break;
          case OfflineSyncTarget.racks:
            await Provider.of<PurchaseProvider>(context, listen: false)
                .listMasterDataValues(accessToken, 'RACKS');
            break;
          case OfflineSyncTarget.settings:
            await Provider.of<GeneralSettingsProvider>(context, listen: false)
                .fetchGeneralSettings();
            await Provider.of<AppSettingsProvider>(context, listen: false)
                .fetchAppSettings();
            break;
          case OfflineSyncTarget.roles:
            await _syncRoles(context);
            break;
        }
      }

      _updateProgress(1.0, 'Section sync completed!');
      _lastSyncTime = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 400));
      _completSync();
    } catch (e) {
      debugPrint('❌ Section sync failed ($section): $e');
      _syncError(e.toString());
      rethrow;
    }
  }

  String _labelForTarget(OfflineSyncTarget target) {
    return switch (target) {
      OfflineSyncTarget.products => 'products',
      OfflineSyncTarget.categories => 'categories',
      OfflineSyncTarget.stock => 'stock',
      OfflineSyncTarget.paymentMethods => 'payment methods',
      OfflineSyncTarget.deliveryMethods => 'delivery methods',
      OfflineSyncTarget.documentConfigs => 'document configs',
      OfflineSyncTarget.customers => 'customers',
      OfflineSyncTarget.suppliers => 'suppliers',
      OfflineSyncTarget.stores => 'stores',
      OfflineSyncTarget.units => 'units',
      OfflineSyncTarget.racks => 'rack data',
      OfflineSyncTarget.settings => 'settings',
      OfflineSyncTarget.roles => 'roles and permissions',
    };
  }

  /// Main sync method that coordinates all data synchronization
  Future<void> syncAllData(BuildContext context) async {
    if (_isSyncing) {
      debugPrint("Sync already in progress, skipping...");
      return;
    }

    await OfflineSyncEndpoints.logSyncAll('Sync All (footer button)');

    try {
      final accessToken = await _requireAccessToken(context);
      _ensureCanSync(context);
      _startSync();
      _activeSyncKey = 'all';

      debugPrint("🔄 Starting comprehensive data sync...");
      debugPrint("Access Token: ${accessToken.substring(0, 20)}...");

      // Pre-Step: Refresh settings (general and app)
      _updateProgress(0.05, "Refreshing settings...");
      try {
        await Provider.of<GeneralSettingsProvider>(context, listen: false)
            .fetchGeneralSettings();
        debugPrint("✅ General settings refreshed");
        await Provider.of<AppSettingsProvider>(context, listen: false)
            .fetchAppSettings();
        debugPrint("✅ App settings refreshed");
      } catch (e) {
        debugPrint("⚠️ Failed to refresh settings during sync: $e");
        // Continue sync even if general settings refresh fails
      }

      // Step 1: Sync Products (20%)
      _updateProgress(0.08, "Syncing roles and permissions...");
      await _syncRoles(context);

      _updateProgress(0.1, "Syncing products...");
      await _syncProducts(context, accessToken);

      // Step 2: Sync Stock Data (30%)
      _updateProgress(0.2, "Syncing stock quantities...");
      await _syncStockData(context, accessToken);

      // Step 3: Sync Categories (40%)
      _updateProgress(0.3, "Syncing categories...");
      await _syncCategories(context);

      // Step 4: Sync Document Configurations (55%)
      _updateProgress(0.4, "Syncing document configurations...");
      await _syncDocumentConfigurations(context, accessToken);

      // Step 5: Sync Invoice Data (75%)
      _updateProgress(0.55, "Syncing invoice data...");
      await _syncInvoiceData(context, accessToken);

      // Step 6: Sync Purchase Data (90%)
      _updateProgress(0.75, "Syncing purchase data...");
      await _syncPurchaseData(context, accessToken);

      // Step 6.5: Sync Delivery Methods (92%)
      _updateProgress(0.92, "Syncing delivery methods...");
      await _syncDeliveryMethods(context);

      // Step 7: Sync Suppliers (95%)
      _updateProgress(0.95, "Syncing suppliers...");
      await _syncSuppliers(context, accessToken);

      // Step 8: Complete (100%)
      _updateProgress(1.0, "Sync completed successfully!");
      _lastSyncTime = DateTime.now();

      debugPrint("✅ Sync completed successfully at ${_lastSyncTime}");

      await Future.delayed(const Duration(seconds: 1));
      _completSync();
    } catch (e) {
      debugPrint("❌ Sync failed with error: $e");
      _syncError(e.toString());
    }
  }

  Future<void> _syncRoles(BuildContext context) async {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    await roleProvider.refreshRoles(context);
    if (roleProvider.error != null) {
      throw Exception(roleProvider.error);
    }
  }

  /// Sync products from API
  Future<void> _syncProducts(BuildContext context, String accessToken) async {
    try {
      debugPrint("📦 Syncing products...");
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      await localProductProvider.fetchProductsFromAPI();
      debugPrint("✅ Products synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync products: $e");
      throw Exception('Failed to sync products: $e');
    }
  }

  /// Sync dedicated stock data from API for inventory management
  /// Note: Product quantities are already synced via _syncProducts() -> fetchProductsFromAPI()
  /// This sync provides additional stock data for inventory reports and stock management screens
  Future<void> _syncStockData(BuildContext context, String accessToken) async {
    try {
      debugPrint("📦 Syncing stock data for inventory management...");
      final stockProvider = Provider.of<StockProvider>(context, listen: false);

      // Get stock data from StockProvider (for stock management/reporting screens)
      final result = await stockProvider.syncStockData(accessToken);

      if (result['status'] == 'success') {
        debugPrint("✅ Stock inventory data synced successfully");
        debugPrint("   - Synced ${result['synced_count']} stock entries");
        debugPrint(
            "   - Stock data available for inventory management screens");
      } else {
        debugPrint(
            "⚠️ Stock sync completed with warnings: ${result['message']}");
        // Don't throw error for stock sync failures - continue with other syncs
      }
    } catch (e) {
      debugPrint("❌ Failed to sync stock data: $e");
      // Don't throw error for stock sync failures - continue with other syncs
      debugPrint("⚠️ Continuing sync process despite stock sync failure");
    }
  }

  /// Sync categories from API
  Future<void> _syncCategories(BuildContext context) async {
    try {
      debugPrint("📂 Syncing categories...");
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      // Use the same loader as Category screen to keep lists consistent
      await categoryProvider.ensureCategories(
        CategoryListScope.sellable,
        force: true,
      );
      debugPrint("✅ Categories synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync categories: $e");
      throw Exception('Failed to sync categories: $e');
    }
  }

  /// Sync document configurations
  Future<void> _syncDocumentConfigurations(
      BuildContext context, String accessToken) async {
    try {
      debugPrint("📄 Syncing document configurations...");
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);
      await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken);
      debugPrint("✅ Document configurations synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync document configurations: $e");
      // Don't throw error for non-critical data
      debugPrint(
          "⚠️ Warning: Document configuration sync failed, continuing...");
    }
  }

  /// Sync invoice-related data
  Future<void> _syncInvoiceData(
      BuildContext context, String accessToken) async {
    try {
      debugPrint("🧾 Syncing invoice data...");
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      // Update progress as we load different invoice data
      _updateProgress(0.52, "Loading invoice account types...");
      await invoiceProvider.listAllInvoiceAccountTypes(accessToken);

      _updateProgress(0.55, "Loading payment methods...");
      await invoiceProvider.listAllPaymentList(accessToken);

      _updateProgress(0.60, "Loading voucher account types...");
      await invoiceProvider.listVoucherAccountType(accessToken);

      _updateProgress(0.65, "Loading users list...");
      await invoiceProvider.listUsersList(accessToken);

      debugPrint("✅ Invoice data synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync invoice data: $e");
      throw Exception('Failed to sync invoice data: $e');
    }
  }

  /// Sync purchase-related data
  Future<void> _syncPurchaseData(
      BuildContext context, String accessToken) async {
    try {
      debugPrint("🛒 Syncing purchase data...");
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);

      _updateProgress(0.75, "Loading stores...");
      await purchaseProvider.listAllStores(accessToken, null);

      _updateProgress(0.80, "Loading suppliers...");
      await purchaseProvider.listAllSuppliers(accessToken, null);

      _updateProgress(0.85, "Loading units...");
      await purchaseProvider.listAllUnits(accessToken);

      _updateProgress(0.90, "Loading master data...");
      await purchaseProvider.listMasterDataValues(accessToken, 'RACKS');

      debugPrint("✅ Purchase data synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync purchase data: $e");
      throw Exception('Failed to sync purchase data: $e');
    }
  }

  /// Sync suppliers from API
  Future<void> _syncSuppliers(BuildContext context, String accessToken) async {
    try {
      debugPrint("🚚 Syncing suppliers...");
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);
      await supplierProvider.fetchSuppliers(accessToken: accessToken);
      debugPrint("✅ Suppliers synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync suppliers: $e");
      throw Exception('Failed to sync suppliers: $e');
    }
  }

  /// Sync delivery methods
  Future<void> _syncDeliveryMethods(BuildContext context) async {
    try {
      debugPrint("🚚 Syncing delivery methods...");
      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      await deliveryMethodsProvider.fetchDeliveryMethods();
      debugPrint("✅ Delivery methods synced successfully");
    } catch (e) {
      debugPrint("⚠️ Failed to sync delivery methods: $e");
      // Do not throw; non-critical for completing overall sync
    }
  }

  /// Start sync process
  void _startSync() {
    _cancelRequested = false;
    _isSyncing = true;
    _hasError = false;
    _errorMessage = '';
    _syncProgress = 0.0;
    _syncMessage = 'Initializing sync...';
    notifyListeners();
  }

  void _clearActiveSyncKey() {
    _activeSyncKey = null;
  }

  /// Update sync progress
  void _updateProgress(double progress, String message) {
    if (_cancelRequested) return;
    _syncProgress = progress;
    _syncMessage = message;
    debugPrint("🔄 Sync Progress: ${(progress * 100).toInt()}% - $message");
    notifyListeners();
  }

  /// Complete sync successfully
  void _completSync() {
    SyncOperationGate.instance.release(_syncGateOwner);
    if (_cancelRequested) {
      _isSyncing = false;
      _hasError = false;
      _syncProgress = 0.0;
      _syncMessage = 'Sync cancelled';
      _clearActiveSyncKey();
      notifyListeners();
      return;
    }
    _isSyncing = false;
    _hasError = false;
    _syncProgress = 1.0;
    _syncMessage = 'Sync completed successfully!';
    _clearActiveSyncKey();
    notifyListeners();
  }

  /// Handle sync error
  void _syncError(String error) {
    SyncOperationGate.instance.release(_syncGateOwner);
    if (_cancelRequested) {
      _isSyncing = false;
      _hasError = false;
      _errorMessage = '';
      _syncMessage = 'Sync cancelled';
      _syncProgress = 0.0;
      _clearActiveSyncKey();
      notifyListeners();
      return;
    }
    _isSyncing = false;
    _hasError = true;
    _errorMessage = error;
    _syncMessage = 'Sync failed';
    _syncProgress = 0.0;
    _clearActiveSyncKey();
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }

  void forceResetSyncState() {
    SyncOperationGate.instance.release(_syncGateOwner);
    _cancelRequested = true;
    _isSyncing = false;
    _hasError = false;
    _errorMessage = '';
    _syncProgress = 0.0;
    _syncMessage = '';
    _lastSyncTime = null;
    _clearActiveSyncKey();
    notifyListeners();
  }

  /// Sync only stock-related data after successful stock operations
  /// This is a lightweight sync focused on stock data only
  Future<bool> syncStockDataOnly(BuildContext context) async {
    if (_isSyncing) {
      debugPrint("Sync already in progress, skipping stock-only sync...");
      return false;
    }
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final accessToken = authModel.token;

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No access token available. Please login again.');
      }
      _ensureCanSync(context);
      _startSync();

      debugPrint(
          "🔄 Starting stock-only sync after successful stock operations...");
      debugPrint("Access Token: ${accessToken.substring(0, 20)}...");

      // Step 1: Sync Suppliers (20%)
      _updateProgress(0.2, "Syncing supplier data...");
      await _syncSuppliers(context, accessToken);

      // Step 2: Sync Products (50%) - Updates stock quantities in LocalProductProvider
      _updateProgress(0.5, "Updating product stock quantities...");
      await _syncProducts(context, accessToken);

      // Step 3: Sync Stock Data (80%) - Updates StockProvider for inventory screens
      _updateProgress(0.8, "Syncing stock inventory data...");
      await _syncStockData(context, accessToken);

      // Complete
      _updateProgress(1.0, "Stock sync completed successfully!");
      _lastSyncTime = DateTime.now();

      debugPrint(
          "✅ Stock-only sync completed successfully at ${_lastSyncTime}");

      await Future.delayed(const Duration(milliseconds: 500));
      _completSync();

      return true;
    } catch (e) {
      debugPrint("❌ Stock-only sync failed with error: $e");
      _syncError(e.toString());
      return false;
    }
  }

  /// Get formatted last sync time
  String getFormattedLastSyncTime() {
    if (_lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
