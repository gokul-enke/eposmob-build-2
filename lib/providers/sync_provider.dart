import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/local_product_provider.dart';
import '../providers/category_providers.dart';
import '../providers/document_config_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/auth_model.dart';

/// Comprehensive sync provider that handles synchronization of all data
/// across the application. Follows the Provider Pattern preference for
/// centralized API calls and state management.
class SyncProvider extends ChangeNotifier {
  bool _isSyncing = false;
  String _syncMessage = '';
  double _syncProgress = 0.0;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastSyncTime;

  // Getters
  bool get isSyncing => _isSyncing;
  String get syncMessage => _syncMessage;
  double get syncProgress => _syncProgress;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Main sync method that coordinates all data synchronization
  Future<void> syncAllData(BuildContext context) async {
    if (_isSyncing) {
      debugPrint("Sync already in progress, skipping...");
      return;
    }

    _startSync();
    
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final accessToken = authModel.token;

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No access token available. Please login again.');
      }

      debugPrint("🔄 Starting comprehensive data sync...");
      debugPrint("Access Token: ${accessToken.substring(0, 20)}...");

      // Step 1: Sync Products (25%)
      _updateProgress(0.1, "Syncing products...");
      await _syncProducts(context, accessToken);

      // Step 2: Sync Categories (35%)
      _updateProgress(0.25, "Syncing categories...");
      await _syncCategories(context);

      // Step 3: Sync Document Configurations (50%)
      _updateProgress(0.35, "Syncing document configurations...");
      await _syncDocumentConfigurations(context, accessToken);

      // Step 4: Sync Invoice Data (70%)
      _updateProgress(0.5, "Syncing invoice data...");
      await _syncInvoiceData(context, accessToken);

      // Step 5: Sync Purchase Data (90%)
      _updateProgress(0.7, "Syncing purchase data...");
      await _syncPurchaseData(context, accessToken);

      // Step 6: Complete (100%)
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

  /// Sync products from API
  Future<void> _syncProducts(BuildContext context, String accessToken) async {
    try {
      debugPrint("📦 Syncing products...");
      final localProductProvider = Provider.of<LocalProductProvider>(context, listen: false);
      await localProductProvider.fetchProductsFromAPI();
      debugPrint("✅ Products synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync products: $e");
      throw Exception('Failed to sync products: $e');
    }
  }

  /// Sync categories from API
  Future<void> _syncCategories(BuildContext context) async {
    try {
      debugPrint("📂 Syncing categories...");
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.listAllCategory();
      debugPrint("✅ Categories synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync categories: $e");
      throw Exception('Failed to sync categories: $e');
    }
  }

  /// Sync document configurations
  Future<void> _syncDocumentConfigurations(BuildContext context, String accessToken) async {
    try {
      debugPrint("📄 Syncing document configurations...");
      final docConfigProvider = Provider.of<DocumentConfigProvider>(context, listen: false);
      await docConfigProvider.fetchDocumentConfigurations(accessToken: accessToken);
      debugPrint("✅ Document configurations synced successfully");
    } catch (e) {
      debugPrint("❌ Failed to sync document configurations: $e");
      // Don't throw error for non-critical data
      debugPrint("⚠️ Warning: Document configuration sync failed, continuing...");
    }
  }

  /// Sync invoice-related data
  Future<void> _syncInvoiceData(BuildContext context, String accessToken) async {
    try {
      debugPrint("🧾 Syncing invoice data...");
      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
      
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
  Future<void> _syncPurchaseData(BuildContext context, String accessToken) async {
    try {
      debugPrint("🛒 Syncing purchase data...");
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
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

  /// Start sync process
  void _startSync() {
    _isSyncing = true;
    _hasError = false;
    _errorMessage = '';
    _syncProgress = 0.0;
    _syncMessage = 'Initializing sync...';
    notifyListeners();
  }

  /// Update sync progress
  void _updateProgress(double progress, String message) {
    _syncProgress = progress;
    _syncMessage = message;
    debugPrint("🔄 Sync Progress: ${(progress * 100).toInt()}% - $message");
    notifyListeners();
  }

  /// Complete sync successfully
  void _completSync() {
    _isSyncing = false;
    _hasError = false;
    _syncProgress = 1.0;
    _syncMessage = 'Sync completed successfully!';
    notifyListeners();
  }

  /// Handle sync error
  void _syncError(String error) {
    _isSyncing = false;
    _hasError = true;
    _errorMessage = error;
    _syncMessage = 'Sync failed';
    _syncProgress = 0.0;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
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