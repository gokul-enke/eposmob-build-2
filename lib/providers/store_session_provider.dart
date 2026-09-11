import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:pos_machine/providers/printer_settings_provider.dart';
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

  /// In-memory store first; fill missing contact fields from the persisted
  /// `active_store` snapshot so print still works if this process never
  /// re-ran store selection.
  Future<Store?> resolveActiveStore() async {
    final persistedJson =
        await SharedPreferenceProvider().getActiveStoreDetails();
    final saved =
        persistedJson != null ? Store.fromJson(persistedJson) : null;
    final current = _activeStore;

    if (current == null && saved == null) return null;
    if (saved == null) return current;

    if (current == null) {
      _activeStore = saved;
      notifyListeners();
      return saved;
    }

    final merged = Store(
      storeId: current.storeId ?? saved.storeId,
      storeName: _nonEmpty(current.storeName) ?? saved.storeName,
      code: current.code ?? saved.code,
      location: _nonEmpty(current.location) ?? saved.location,
      email: _nonEmpty(current.email) ?? saved.email,
      phone: _nonEmpty(current.phone) ?? saved.phone,
      stateId: current.stateId ?? saved.stateId,
      districtId: current.districtId ?? saved.districtId,
      pincodeId: current.pincodeId ?? saved.pincodeId,
      localLocationId: current.localLocationId ?? saved.localLocationId,
      storeOpenTime: current.storeOpenTime ?? saved.storeOpenTime,
    );

    final filledMissingContact =
        (!_hasText(current.location) && _hasText(merged.location)) ||
            (!_hasText(current.phone) && _hasText(merged.phone)) ||
            (!_hasText(current.email) && _hasText(merged.email));
    if (filledMissingContact) {
      _activeStore = merged;
      notifyListeners();
    }
    return merged;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static bool _hasText(String? value) => _nonEmpty(value) != null;

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
    final printerSettingsProvider = context.read<PrinterSettingsProvider>();
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
          await _updateStatus('store_bootstrap.clearing_cache'.tr);
        }

        // Always clear local data
        await localProductProvider.clearAllLocalData();
        await categoryProvider.clearAllCategories();
        await docConfigProvider.clearAllCaches();

        // Show UI status only in debug mode
        if (kDebugMode) {
          await _updateStatus('store_bootstrap.cache_cleared'.tr);
        }
        debugPrint('✅ [Store] Local data cleared for store: $selectedStoreId');
      }

      await _updateStatus('store_bootstrap.loading_permissions'.tr);
      try {
        await roleProvider.fetchRoles(context);
        await _updateStatus('store_bootstrap.permissions_loaded'.tr);
      } catch (e) {
        debugPrint('Warning: Failed to load user permissions: $e');
        await _updateStatus('store_bootstrap.permissions_warning'.tr);
      }

      await _updateStatus('store_bootstrap.syncing_delivery'.tr);
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

      await _updateStatus('store_bootstrap.loading_general'.tr);
      await generalSettingsProvider.fetchGeneralSettings();

      await _updateStatus('store_bootstrap.applying_prefs'.tr);
      await appSettingsProvider.fetchAppSettings();

      await _updateStatus('store_bootstrap.syncing_customers'.tr);
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

      await _updateStatus('store_bootstrap.loading_branding'.tr);
      await adminSettingsProvider.fetchAdminSettings();

      await _updateStatus('store_bootstrap.syncing_banks'.tr);
      try {
        await bankProvider.fetchBanks(accessToken: accessToken);
      } catch (e) {
        debugPrint('Warning: Failed to load banks after store selection: $e');
      }

      await _updateStatus('store_bootstrap.preparing_invoices'.tr);
      await invoiceProvider.listAllInvoiceAccountTypes(accessToken);

      await _updateStatus('store_bootstrap.syncing_payments'.tr);
      await invoiceProvider.listAllPaymentList(
        accessToken,
        forceRefresh: true,
      );

      await _updateStatus('store_bootstrap.refreshing_checkout_payments'.tr);
      try {
        await masterDataProvider.fetchPaymentMethods(forceRefresh: true);
      } catch (e) {
        debugPrint('Warning: Failed to refresh checkout payment methods: $e');
      }

      await _updateStatus('store_bootstrap.loading_stock_grouping'.tr);
      try {
        await masterDataProvider.fetchStockGroupingFields(forceRefresh: true);
      } catch (e) {
        debugPrint('Warning: Failed to load stock grouping fields: $e');
      }

      await _updateStatus('store_bootstrap.fetching_vouchers'.tr);
      await invoiceProvider.listVoucherAccountType(accessToken);

      await _updateStatus('store_bootstrap.updating_users'.tr);
      await invoiceProvider.listUsersList(accessToken);

      await _updateStatus('store_bootstrap.retrieving_store'.tr);
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

      await _updateStatus('store_bootstrap.loading_suppliers'.tr);
      await purchaseProvider.listAllSuppliers(accessToken, null);
      final supplierLength = purchaseProvider.getSupplierList?.length ?? 0;
      await _updateStatus(
        'store_bootstrap.suppliers_synced'
            .trParams({'count': '$supplierLength'}),
      );

      await _updateStatus('store_bootstrap.syncing_units'.tr);
      await purchaseProvider.listAllUnits(accessToken);

      await _updateStatus('store_bootstrap.fetching_racks'.tr);
      await purchaseProvider.listMasterDataValues(accessToken, 'RACKS');

      await _updateStatus('store_bootstrap.downloading_docs'.tr);
      try {
        await docConfigProvider.fetchDocumentConfigurations(
          accessToken: accessToken,
        );
      } catch (e) {
        debugPrint(
            'Warning: Failed to load document configurations after store selection: $e');
      }

      try {
        await printerSettingsProvider.fetchAndApplyDefaults(
          accessToken: accessToken,
        );
      } catch (e) {
        debugPrint('Warning: Failed to load printer settings defaults: $e');
      }

      await _updateStatus('store_bootstrap.refreshing_categories'.tr);
      try {
        await categoryProvider.prefetchAllScopesForStore(force: true);
        final categoryCount = categoryProvider.sellableCategories.length;
        await _updateStatus(
          'store_bootstrap.categories_ready'.trParams({
            'sellable': '$categoryCount',
            'total': '${categoryProvider.allCategories.length}',
          }),
        );
      } catch (e) {
        debugPrint(
            'Warning: Failed to load categories after store selection: $e');
      }

      await _updateStatus('store_bootstrap.fetching_products'.tr);
      await localProductProvider.fetchProductsFromAPI(
        onProgress: (loaded, batch) async {
          await _updateStatus(
            'store_bootstrap.loading_products'.trParams({
              'loaded': '$loaded',
              'batch': '$batch',
            }),
          );
        },
      );
      final productCount = localProductProvider.products.length;
      await _updateStatus(
        'store_bootstrap.products_ready'.trParams({'count': '$productCount'}),
      );

      final prefs = await SharedPreferenceProvider().getApiKey();
      final companyId = await SharedPreferenceProvider().getCompanyId();
      if (accessToken.isNotEmpty &&
          prefs != null &&
          prefs.isNotEmpty &&
          companyId != null &&
          selectedStoreId != null) {
        await _updateStatus('store_bootstrap.starting_realtime'.tr);
        final realtimeSyncProvider = context.read<RealtimeSyncProvider>();
        final realtimeSession = RealtimeSyncSession(
          backendBaseUrl: APPUrl.baseURL,
          companyId: companyId,
          storeId: selectedStoreId,
          tenantApiKey: prefs,
          accessToken: accessToken,
        );

        // Realtime is an enhancement. Do not hold the store-selection screen
        // while catch-up and the WebSocket handshake are in progress.
        unawaited(
          realtimeSyncProvider.start(realtimeSession).catchError((error) {
            debugPrint('Realtime sync start deferred: $error');
          }),
        );
      }

      await _updateStatus('store_bootstrap.finishing'.tr);
    } finally {
      _isBootstrapping = false;
      _statusMessage = null;
      notifyListeners();
    }
  }

  Future<void> _updateStatus(String message) async {
    _setStatus(message);
    // Yield once so Flutter can paint the new status without adding an
    // artificial delay to every bootstrap step.
    await Future<void>.delayed(Duration.zero);
  }

  void resetSession() {
    _activeStore = null;
    _isBootstrapping = false;
    _statusMessage = null;
    _availableStores = [];
    notifyListeners();
  }
}
