import 'package:flutter/material.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
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

    final sharedPrefProvider =
        context.read<SharedPreferenceProvider>();
    await sharedPrefProvider.saveActiveStoreId(store.storeId ?? 0);
    _activeStore = store;
    _setStatus('Preparing environment for ${store.storeName ?? "store"}...');

    final authModel = context.read<AuthModel>();
    final String accessToken = authModel.token ?? '';

    final generalSettingsProvider = context.read<GeneralSettingsProvider>();
    final appSettingsProvider = context.read<AppSettingsProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();
    final purchaseProvider = context.read<PurchaseProvider>();
    final docConfigProvider = context.read<DocumentConfigProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final localProductProvider = context.read<LocalProductProvider>();

    try {
      await _updateStatus('Loading general settings...');
      await generalSettingsProvider.fetchGeneralSettings();

      await _updateStatus('Applying app preferences...');
      await appSettingsProvider.fetchAppSettings();

      await _updateStatus('Preparing invoices...');
      await invoiceProvider.listAllInvoiceAccountTypes(accessToken);

      await _updateStatus('Syncing payment methods...');
      await invoiceProvider.listAllPaymentList(accessToken);

      await _updateStatus('Fetching voucher types...');
      await invoiceProvider.listVoucherAccountType(accessToken);

      await _updateStatus('Updating user directory...');
      await invoiceProvider.listUsersList(accessToken);

      await _updateStatus('Retrieving store details...');
      await purchaseProvider.listAllStores(accessToken, null);

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
        await categoryProvider.listAllCategory();
        final categoryCount = categoryProvider.categoryList?.length ?? 0;
        await _updateStatus('Categories ready: $categoryCount found.');
      } catch (e) {
        debugPrint(
            'Warning: Failed to load categories after store selection: $e');
      }

      await _updateStatus('Fetching product catalog (this may take a moment)...');
      await localProductProvider.fetchProductsFromAPI(
        onProgress: (loaded, batch) async {
          await _updateStatus(
              'Loading products... $loaded loaded (latest batch: $batch)');
        },
      );
      final productCount = localProductProvider.products.length;
      await _updateStatus('Products ready: $productCount loaded.');

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
}
