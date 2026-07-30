import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:provider/provider.dart';

class StoreSessionProvider extends ChangeNotifier {
  Store? _activeStore;
  bool _isBootstrapping = false;
  String? _statusMessage;
  List<Store> _availableStores = [];

  Store? get activeStore => _activeStore;
  bool get isBootstrapping => _isBootstrapping;
  String? get statusMessage => _statusMessage;
  List<Store> get availableStores => List.unmodifiable(_availableStores);

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void initializeStores(List<Store> stores, {int? activeStoreId}) {
    _availableStores = stores;
    if (stores.isEmpty) {
      _activeStore = null;
    } else if (activeStoreId != null) {
      _activeStore = stores.firstWhere(
        (store) => store.storeId == activeStoreId,
        orElse: () => stores.first,
      );
    } else {
      _activeStore = stores.first;
    }
    notifyListeners();
  }

  Future<void> bootstrapStore({
    required BuildContext context,
    required Store store,
  }) async {
    if (_isBootstrapping) return;

    _isBootstrapping = true;
    _setStatus('Saving your selection...');

    final sharedPrefProvider = context.read<SharedPreferenceProvider>();
    final previousActiveStoreId = await sharedPrefProvider.getActiveStoreId();
    final selectedStoreId = store.storeId;
    final didStoreChange = previousActiveStoreId != null &&
        selectedStoreId != null &&
        previousActiveStoreId != selectedStoreId;

    if (didStoreChange) {
      await context.read<RealtimeSyncProvider>().stop();
    }

    await sharedPrefProvider.saveActiveStoreId(store.storeId ?? 0);
    await sharedPrefProvider.saveActiveStoreDetails(store.toJson());
    _activeStore = store;
    _setStatus('Preparing environment for ${store.storeName ?? "store"}...');

    final authModel = context.read<AuthModel>();
    final String accessToken = authModel.token ?? '';

    final generalSettingsProvider = context.read<GeneralSettingsProvider>();
    final appSettingsProvider = context.read<AppSettingsProvider>();
    final adminSettingsProvider = context.read<AdminSettingsProvider>();
    final bankProvider = context.read<BankProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();
    final purchaseProvider = context.read<PurchaseProvider>();
    final docConfigProvider = context.read<DocumentConfigProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final localProductProvider = context.read<LocalProductProvider>();
    final masterDataProvider = context.read<MasterDataProvider>();
    final roleProvider = context.read<RoleProvider>();
    final deliveryMethodsProvider = context.read<DeliveryMethodsProvider>();
    final customerProvider = context.read<CustomerProvider>();

    try {
      if (didStoreChange) {
        // Log store change (always)
        debugPrint(
          '🔄 [Store] Store changed: $previousActiveStoreId → $selectedStoreId. Clearing local data...',
        );

        // Show UI status only in debug mode
        if (kDebugMode) {
          await _updateStatus('Store changed. Clearing local data cache...');
        }

        // Always clear local data
        await localProductProvider.clearAllLocalData();
        await categoryProvider.clearAllCategories();
        await docConfigProvider.clearAllCaches();

        // Show UI status only in debug mode
        if (kDebugMode) {
          await _updateStatus('Local cache cleared for new store sync.');
        }
        debugPrint('✅ [Store] Local data cleared for store: $selectedStoreId');
      }

      await _updateStatus('Loading user permissions...');
      try {
        await roleProvider.fetchRoles(context);
        await _updateStatus('User permissions loaded successfully');
      } catch (e) {
        debugPrint('Warning: Failed to load user permissions: $e');
        await _updateStatus('Warning: Could not load permissions');
      }

      await _updateStatus('Syncing delivery methods...');
      try {
        debugPrint(
            '🚚 [StoreBootstrap] Fetching delivery methods during store selection...');
        await deliveryMethodsProvider.fetchDeliveryMethods(forceRefresh: true);
        debugPrint(
            '🚚 [StoreBootstrap] ✅ Delivery methods loaded: ${deliveryMethodsProvider.deliveryMethods.length} methods in provider memory');
      } catch (e) {
        debugPrint(
            '🚚 [StoreBootstrap] ⚠️ Failed to load delivery methods: $e');
      }

      await _updateStatus('Loading general settings...');
      await generalSettingsProvider.fetchGeneralSettings();

      await _updateStatus('Applying app preferences...');
      await appSettingsProvider.fetchAppSettings();

      await _updateStatus('Syncing customer directory...');
      if (accessToken.isNotEmpty) {
        try {
          await customerProvider.fetchCustomers(
            accessToken: accessToken,
            listAll: true,
          );
        } catch (e) {
          debugPrint(
              'Warning: Failed to load customers after store selection: $e');
        }
      }

      await _updateStatus('Loading branding assets...');
      await adminSettingsProvider.fetchAdminSettings();

      await _updateStatus('Syncing bank accounts...');
      try {
        await bankProvider.fetchBanks(accessToken: accessToken);
      } catch (e) {
        debugPrint('Warning: Failed to load banks after store selection: $e');
      }

      await _updateStatus('Preparing invoices...');
      await invoiceProvider.listAllInvoiceAccountTypes(accessToken);

      await _updateStatus('Syncing payment methods...');
      await invoiceProvider.listAllPaymentList(
        accessToken,
        forceRefresh: true,
      );

      await _updateStatus('Refreshing checkout payment methods...');
      try {
        await masterDataProvider.fetchPaymentMethods(forceRefresh: true);
      } catch (e) {
        debugPrint('Warning: Failed to refresh checkout payment methods: $e');
      }

      await _updateStatus('Loading stock grouping configuration...');
      try {
        await masterDataProvider.fetchStockGroupingFields(forceRefresh: true);
      } catch (e) {
        debugPrint('Warning: Failed to load stock grouping fields: $e');
      }

      await _updateStatus('Fetching voucher types...');
      await invoiceProvider.listVoucherAccountType(accessToken);

      await _updateStatus('Updating user directory...');
      await invoiceProvider.listUsersList(accessToken);

      await _updateStatus('Retrieving store details...');
      await purchaseProvider.listAllStores(accessToken, null);

      try {
        final fetchedStore = purchaseProvider.storeList.firstWhere(
          (s) => s.id == _activeStore?.storeId,
        );
        if (fetchedStore.storeOpenTime != null) {
          final updatedStore = Store(
            storeId: _activeStore?.storeId,
            storeName: _activeStore?.storeName,
            code: _activeStore?.code ?? fetchedStore.code,
            location: _activeStore?.location ??
                fetchedStore.localLocationId?.toString(),
            email: _activeStore?.email ?? fetchedStore.email,
            phone: _activeStore?.phone ?? fetchedStore.phone,
            stateId: _activeStore?.stateId ?? fetchedStore.stateId,
            districtId: _activeStore?.districtId ?? fetchedStore.districtId,
            pincodeId: _activeStore?.pincodeId ?? fetchedStore.pincodeId,
            localLocationId:
                _activeStore?.localLocationId ?? fetchedStore.localLocationId,
            storeOpenTime: fetchedStore.storeOpenTime,
          );
          _activeStore = updatedStore;
          await sharedPrefProvider
              .saveActiveStoreDetails(updatedStore.toJson());
        }
      } catch (e) {
        debugPrint('Warning: Could not find/map store_open_time details: $e');
      }

      await _updateStatus('Loading supplier catalog...');
      await purchaseProvider.listAllSuppliers(accessToken, null);
      final supplierLength = purchaseProvider.getSupplierList?.length ?? 0;
      await _updateStatus('Suppliers synced: $supplierLength available.');

      await _updateStatus('Syncing measurement units...');
      await purchaseProvider.listAllUnits(accessToken);

      await _updateStatus('Fetching rack metadata...');
      await purchaseProvider.listMasterDataValues(accessToken, 'RACKS');

      await _updateStatus('Downloading document configurations...');
      try {
        await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken,
        );
      } catch (e) {
        debugPrint(
            'Warning: Failed to load document configurations after store selection: $e');
      }

      await _updateStatus('Refreshing product categories...');
      try {
        await categoryProvider.prefetchAllScopesForStore(force: true);
        final categoryCount = categoryProvider.sellableCategories.length;
        await _updateStatus(
          'Categories ready: $categoryCount sellable, '
          '${categoryProvider.allCategories.length} total.',
        );
      } catch (e) {
        debugPrint(
            'Warning: Failed to load categories after store selection: $e');
      }

      await _updateStatus(
          'Fetching product catalog (this may take a moment)...');
      await localProductProvider.fetchProductsFromAPI(
        onProgress: (loaded, batch) async {
          await _updateStatus(
              'Loading products... $loaded loaded (latest batch: $batch)');
        },
      );
      final productCount = localProductProvider.products.length;
      await _updateStatus('Products ready: $productCount loaded.');

      final prefs = await SharedPreferenceProvider().getApiKey();
      final companyId = await SharedPreferenceProvider().getCompanyId();
      if (accessToken.isNotEmpty &&
          prefs != null &&
          prefs.isNotEmpty &&
          companyId != null &&
          selectedStoreId != null) {
        await _updateStatus('Starting realtime synchronization...');
        try {
          await context.read<RealtimeSyncProvider>().start(
                RealtimeSyncSession(
                  backendBaseUrl: APPUrl.baseURL,
                  companyId: companyId,
                  storeId: selectedStoreId,
                  tenantApiKey: prefs,
                  accessToken: accessToken,
                ),
              );
        } catch (error) {
          // Realtime is an enhancement: a temporary Reverb outage must not
          // prevent the user from entering an otherwise healthy POS session.
          debugPrint('Realtime sync start deferred: $error');
        }
      }

      await _updateStatus('Finishing touches...');
    } finally {
      _isBootstrapping = false;
      _statusMessage = null;
      notifyListeners();
    }
  }

  Future<void> _updateStatus(String message) async {
    _setStatus(message);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  void resetSession() {
    _activeStore = null;
    _isBootstrapping = false;
    _statusMessage = null;
    _availableStores = [];
    notifyListeners();
  }
}
