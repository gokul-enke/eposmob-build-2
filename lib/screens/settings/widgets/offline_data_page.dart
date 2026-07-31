import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/providers/offline_cache_clear_service.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';
import 'package:provider/provider.dart';

class OfflineDataPage extends StatefulWidget {
  const OfflineDataPage({super.key});

  static const int sidebarIndex = 96;

  @override
  State<OfflineDataPage> createState() => _OfflineDataPageState();
}

class _OfflineDataPageState extends State<OfflineDataPage> {
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  void _goBackToSettings() {
    Get.find<SideBarController>().index.value = 62;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubPageHeader(
            backLabel: 'Settings',
            onBack: _goBackToSettings,
            onClose: _goBackToSettings,
            title: 'Offline Data',
            subtitle: 'Cached on this device for billing & offline use',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_refreshKey),
              child: _OfflineDataList(onRefresh: _refresh),
            ),
          ),
          _SyncFooter(onSyncComplete: _refresh),
        ],
      ),
    );
  }
}

class _OfflineDataList extends StatelessWidget {
  final VoidCallback onRefresh;

  const _OfflineDataList({required this.onRefresh});

  Future<void> _runSync(
    BuildContext context, {
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final syncProvider = context.read<SyncProvider>();
    if (syncProvider.hasError) {
      syncProvider.clearError();
    }

    try {
      await action();
      if (!context.mounted) return;
      showScaffold(context: context, message: successMessage);
      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      showScaffoldError(
        context: context,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  Future<void> _runClear(
    BuildContext context, {
    required OfflineCacheTarget target,
  }) async {
    final syncProvider = context.read<SyncProvider>();
    if (syncProvider.isSyncing) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(OfflineCacheClearService.confirmTitleFor(target)),
        content: Text(OfflineCacheClearService.confirmMessageFor(target)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: ColorManager.kButtonRed),
            ),
          ),
        ],
      ),
    );

    if (shouldClear != true || !context.mounted) return;

    try {
      await OfflineCacheClearService.clearTarget(context, target);
      if (!context.mounted) return;
      showScaffold(
        context: context,
        message:
            '${OfflineCacheClearService.labelFor(target)} cleared from this device',
      );
      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      showScaffoldError(
        context: context,
        message: 'Clear failed: ${e.toString()}',
      );
    }
  }

  bool _canSync(BillingProvider billing, SyncProvider sync) {
    return billing.hasInternet && !sync.isSyncing;
  }

  bool _canClear(SyncProvider sync) => !sync.isSyncing;

  int _cartItemsCount() {
    if (!Hive.isBoxOpen('cart_items')) return 0;
    return Hive.box<HiveLocalCartItem>('cart_items').length;
  }

  int _savedOrdersCount() {
    if (!Hive.isBoxOpen('saved_orders')) return 0;
    return Hive.box<HiveSavedOrder>('saved_orders').length;
  }

  int _confirmedOrdersCount() {
    if (!Hive.isBoxOpen('confirmed_orders')) return 0;
    return Hive.box<HiveSavedOrder>('confirmed_orders').length;
  }

  int _documentConfigsCount() {
    if (!Hive.isBoxOpen('document_configs')) return 0;
    return Hive.box<HiveDocumentConfig>('document_configs').length;
  }

  String _countLabel(int count, {String unit = 'items'}) {
    if (count <= 0) return 'Not cached';
    return '$count $unit';
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<LocalProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final deliveryProvider = context.watch<DeliveryMethodsProvider>();
    final invoiceProvider = context.watch<InvoiceProvider>();
    final purchaseProvider = context.watch<PurchaseProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final supplierProvider = context.watch<SupplierProvider>();
    final billingProvider = context.watch<BillingProvider>();
    final roleProvider = context.watch<RoleProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final canSync = _canSync(billingProvider, syncProvider);
    final canClear = _canClear(syncProvider);

    final productCount = productProvider.sellableProducts.length;
    final categoryCount = categoryProvider.sellableCategories.length;
    final deliveryCount = deliveryProvider.deliveryMethods.length;
    final paymentCount = invoiceProvider.getPaymentType?.length ?? 0;
    final customerCount =
        customerProvider.allCustomers?.length ??
        customerProvider.getCustomerList?.length ??
        0;
    final supplierCount =
        supplierProvider.allSuppliers?.length ??
        purchaseProvider.getSupplierList?.length ??
        0;
    final storeCount = purchaseProvider.getStoreList?.length ?? 0;
    final unitCount = purchaseProvider.getUnitList?.length ?? 0;
    final rackCount = purchaseProvider.getMasterDataValues?.length ?? 0;
    final roleCount = roleProvider.roles.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (syncProvider.isSyncing) ...[
          _SyncProgressBanner(syncProvider: syncProvider),
          const SizedBox(height: 12),
        ],
        _StatusBanner(
          billingProvider: billingProvider,
          syncProvider: syncProvider,
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Catalog & inventory',
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            'section:${OfflineSyncSection.catalog.name}',
          ),
          onSyncSection: () => _runSync(
            context,
            action: () => syncProvider.syncSection(
              context,
              OfflineSyncSection.catalog,
            ),
            successMessage: 'Catalog data synced',
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.box,
          iconColor: const Color(0xFF5E35B1),
          backgroundColor: const Color(0xFFEDE7F6),
          title: 'Products',
          subtitle: 'Product catalog for billing & search',
          value: _countLabel(productCount, unit: 'products'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(OfflineSyncTarget.products.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.products,
            ),
            successMessage: 'Products synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.products,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.tags,
          iconColor: const Color(0xFF1565C0),
          backgroundColor: const Color(0xFFE3F2FD),
          title: 'Categories',
          subtitle: 'Product categories and filters',
          value: _countLabel(categoryCount, unit: 'categories'),
          canSync: canSync,
          isSyncing:
              syncProvider.isSyncingKey(OfflineSyncTarget.categories.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.categories,
            ),
            successMessage: 'Categories synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.categories,
          ),
          canClear: canClear,
        ),
        FutureBuilder<String?>(
          future: SharedPreferenceProvider().getLastProductSyncIso(),
          builder: (context, snapshot) {
            final iso = snapshot.data;
            final label = iso == null
                ? 'Never synced'
                : DateHelper.formatISODateToIST(iso);
            return _OfflineDataTile(
              faIcon: FontAwesomeIcons.clockRotateLeft,
              iconColor: const Color(0xFFEF6C00),
              backgroundColor: const Color(0xFFFFF3E0),
              title: 'Last product sync',
              subtitle: 'When products were last downloaded',
              value: label,
              canClear: canClear && iso != null,
              onClear: () => _runClear(
                context,
                target: OfflineCacheTarget.productSyncTimestamp,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _SectionHeader(
          title: 'Billing & checkout',
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            'section:${OfflineSyncSection.billing.name}',
          ),
          onSyncSection: () => _runSync(
            context,
            action: () => syncProvider.syncSection(
              context,
              OfflineSyncSection.billing,
            ),
            successMessage: 'Billing data synced',
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.creditCard,
          iconColor: const Color(0xFF00897B),
          backgroundColor: const Color(0xFFE0F2F1),
          title: 'Payment methods',
          subtitle: 'Cash, card, UPI and other payment types',
          value: _countLabel(paymentCount, unit: 'methods'),
          canSync: canSync,
          isSyncing:
              syncProvider.isSyncingKey(OfflineSyncTarget.paymentMethods.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.paymentMethods,
            ),
            successMessage: 'Payment methods synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.paymentMethods,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.truck,
          iconColor: const Color(0xFF3949AB),
          backgroundColor: const Color(0xFFE8EAF6),
          title: 'Delivery methods',
          subtitle: 'Delivery options at checkout',
          value: _countLabel(deliveryCount, unit: 'methods'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            OfflineSyncTarget.deliveryMethods.name,
          ),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.deliveryMethods,
            ),
            successMessage: 'Delivery methods synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.deliveryMethods,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.fileLines,
          iconColor: const Color(0xFF6A1B9A),
          backgroundColor: const Color(0xFFF3E5F5),
          title: 'Document configurations',
          subtitle: 'Invoice & receipt templates',
          value: _countLabel(_documentConfigsCount(), unit: 'configs'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            OfflineSyncTarget.documentConfigs.name,
          ),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.documentConfigs,
            ),
            successMessage: 'Document configs synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.documentConfigs,
          ),
          canClear: canClear,
        ),
        const SizedBox(height: 8),
        _SectionHeader(
          title: 'Customers & suppliers',
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            'section:${OfflineSyncSection.customersAndSuppliers.name}',
          ),
          onSyncSection: () => _runSync(
            context,
            action: () => syncProvider.syncSection(
              context,
              OfflineSyncSection.customersAndSuppliers,
            ),
            successMessage: 'Customers & suppliers synced',
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.users,
          iconColor: const Color(0xFF0277BD),
          backgroundColor: const Color(0xFFE1F5FE),
          title: 'Customers',
          subtitle: 'Customer directory for billing',
          value: _countLabel(customerCount, unit: 'customers'),
          canSync: canSync,
          isSyncing:
              syncProvider.isSyncingKey(OfflineSyncTarget.customers.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.customers,
            ),
            successMessage: 'Customers synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.customers,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.truckField,
          iconColor: const Color(0xFF558B2F),
          backgroundColor: const Color(0xFFF1F8E9),
          title: 'Suppliers',
          subtitle: 'Supplier list for purchases',
          value: _countLabel(supplierCount, unit: 'suppliers'),
          canSync: canSync,
          isSyncing:
              syncProvider.isSyncingKey(OfflineSyncTarget.suppliers.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.suppliers,
            ),
            successMessage: 'Suppliers synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.suppliers,
          ),
          canClear: canClear,
        ),
        const SizedBox(height: 8),
        _SectionHeader(
          title: 'Store reference data',
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(
            'section:${OfflineSyncSection.storeReference.name}',
          ),
          onSyncSection: () => _runSync(
            context,
            action: () => syncProvider.syncSection(
              context,
              OfflineSyncSection.storeReference,
            ),
            successMessage: 'Store reference data synced',
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.store,
          iconColor: const Color(0xFF2E7D32),
          backgroundColor: const Color(0xFFE8F5E9),
          title: 'Stores',
          subtitle: 'Store locations linked to your account',
          value: _countLabel(storeCount, unit: 'stores'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(OfflineSyncTarget.stores.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.stores,
            ),
            successMessage: 'Stores synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.stores,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.ruler,
          iconColor: const Color(0xFF455A64),
          backgroundColor: const Color(0xFFECEFF1),
          title: 'Units of measure',
          subtitle: 'Kg, pcs, box and other units',
          value: _countLabel(unitCount, unit: 'units'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(OfflineSyncTarget.units.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.units,
            ),
            successMessage: 'Units synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.units,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.warehouse,
          iconColor: const Color(0xFF5D4037),
          backgroundColor: const Color(0xFFEFEBE9),
          title: 'Rack / master data',
          subtitle: 'Warehouse rack metadata',
          value: _countLabel(rackCount, unit: 'entries'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(OfflineSyncTarget.racks.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.racks,
            ),
            successMessage: 'Rack data synced',
          ),
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.racks,
          ),
          canClear: canClear,
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.userShield,
          iconColor: const Color(0xFF6A1B9A),
          backgroundColor: const Color(0xFFF3E5F5),
          title: 'Roles & permissions',
          subtitle: 'Current user access rules and permissions',
          value: _countLabel(roleCount, unit: 'roles'),
          canSync: canSync,
          isSyncing: syncProvider.isSyncingKey(OfflineSyncTarget.roles.name),
          onSync: () => _runSync(
            context,
            action: () => syncProvider.syncTarget(
              context,
              OfflineSyncTarget.roles,
            ),
            successMessage: 'Roles and permissions synced',
          ),
        ),
        FutureBuilder<Map<String, dynamic>?>(
          future: SharedPreferenceProvider().getActiveStoreDetails(),
          builder: (context, snapshot) {
            final store = snapshot.data;
            final name = store?['store_name']?.toString();
            final id = store?['store_id']?.toString();
            final value = name != null && name.isNotEmpty
                ? name
                : (id != null ? 'Store #$id' : 'Not selected');
            return _OfflineDataTile(
              faIcon: FontAwesomeIcons.locationDot,
              iconColor: const Color(0xFFC62828),
              backgroundColor: const Color(0xFFFFEBEE),
              title: 'Active store',
              subtitle: 'Currently selected store session',
              value: value,
            );
          },
        ),
        const SizedBox(height: 8),
        _SectionHeader(title: 'Local drafts (on device)'),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.cartShopping,
          iconColor: const Color(0xFF1565C0),
          backgroundColor: const Color(0xFFE3F2FD),
          title: 'Cart items',
          subtitle: 'Items held in the local cart',
          value: _countLabel(_cartItemsCount(), unit: 'items'),
          canClear: canClear && _cartItemsCount() > 0,
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.cartItems,
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.bookmark,
          iconColor: const Color(0xFFEF6C00),
          backgroundColor: const Color(0xFFFFF3E0),
          title: 'Saved orders',
          subtitle: 'Draft orders not yet confirmed',
          value: _countLabel(_savedOrdersCount(), unit: 'orders'),
          canClear: canClear && _savedOrdersCount() > 0,
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.savedOrders,
          ),
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.circleCheck,
          iconColor: const Color(0xFF2E7D32),
          backgroundColor: const Color(0xFFE8F5E9),
          title: 'Confirmed orders',
          subtitle: 'Orders confirmed locally',
          value: _countLabel(_confirmedOrdersCount(), unit: 'orders'),
          canClear: canClear && _confirmedOrdersCount() > 0,
          onClear: () => _runClear(
            context,
            target: OfflineCacheTarget.confirmedOrders,
          ),
        ),
        const SizedBox(height: 8),
        _SectionHeader(title: 'Connection'),
        _OfflineDataTile(
          materialIcon:
              billingProvider.hasInternet ? Icons.wifi : Icons.wifi_off,
          iconColor: billingProvider.hasInternet
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          backgroundColor: billingProvider.hasInternet
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFEBEE),
          title: 'Internet',
          subtitle: billingProvider.isManualOfflineMode
              ? 'Offline mode is manually enabled'
              : 'Live connection status',
          value: billingProvider.hasInternet ? 'Online' : 'Offline',
        ),
        _OfflineDataTile(
          faIcon: FontAwesomeIcons.arrowsRotate,
          iconColor: const Color(0xFF5E35B1),
          backgroundColor: const Color(0xFFEDE7F6),
          title: 'Last full sync',
          subtitle: 'Most recent sync from this session',
          value: syncProvider.lastSyncTime == null
              ? 'Not synced yet'
              : syncProvider.getFormattedLastSyncTime(),
        ),
      ],
    );
  }
}

class _SyncProgressBanner extends StatelessWidget {
  final SyncProvider syncProvider;

  const _SyncProgressBanner({required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: syncProvider.syncProgress > 0
                      ? syncProvider.syncProgress
                      : null,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  syncProvider.syncMessage.isNotEmpty
                      ? syncProvider.syncMessage
                      : 'Syncing offline data...',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.16,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          ),
          if (syncProvider.syncProgress > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: syncProvider.syncProgress,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                color: ColorManager.kPrimaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final BillingProvider billingProvider;
  final SyncProvider syncProvider;

  const _StatusBanner({
    required this.billingProvider,
    required this.syncProvider,
  });

  @override
  Widget build(BuildContext context) {
    final canSync = billingProvider.hasInternet && !syncProvider.isSyncing;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canSync ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            canSync ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: canSync ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              canSync
                  ? 'Use sync or clear on each row, sync a whole section, or Sync All below.'
                  : billingProvider.isManualOfflineMode
                      ? 'Offline mode is on. Disable it in Settings to sync.'
                      : 'No internet connection. Sync is unavailable right now.',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s10,
                0.15,
                ColorManager.textColor.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncFooter extends StatelessWidget {
  final VoidCallback onSyncComplete;

  const _SyncFooter({required this.onSyncComplete});

  Future<void> _handleSyncAll(BuildContext context) async {
    final syncProvider = context.read<SyncProvider>();
    if (syncProvider.hasError) {
      syncProvider.clearError();
    }

    try {
      await syncProvider.syncAllData(context);
      if (!context.mounted) return;
      showScaffold(
        context: context,
        message: 'Offline data synced successfully',
      );
      onSyncComplete();
    } catch (e) {
      if (!context.mounted) return;
      showScaffoldError(
        context: context,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SyncProvider, BillingProvider>(
      builder: (context, syncProvider, billingProvider, _) {
        final canSync = billingProvider.hasInternet && !syncProvider.isSyncing;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: canSync ? () => _handleSyncAll(context) : null,
              icon: syncProvider.isSyncing &&
                      syncProvider.activeSyncKey == 'all'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(
                syncProvider.isSyncing && syncProvider.activeSyncKey == 'all'
                    ? 'Syncing...'
                    : 'Sync All',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool canSync;
  final bool isSyncing;
  final VoidCallback? onSyncSection;

  const _SectionHeader({
    required this.title,
    this.canSync = false,
    this.isSyncing = false,
    this.onSyncSection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s9,
                0.14,
                ColorManager.textColor.withOpacity(0.5),
              ),
            ),
          ),
          if (onSyncSection != null)
            TextButton.icon(
              onPressed: canSync && !isSyncing ? onSyncSection : null,
              icon: isSyncing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColorManager.kPrimaryColor,
                      ),
                    )
                  : Icon(
                      Icons.sync,
                      size: 14,
                      color: canSync
                          ? ColorManager.kPrimaryColor
                          : Colors.grey.shade400,
                    ),
              label: Text(
                isSyncing ? 'Syncing...' : 'Sync section',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s9,
                  0.13,
                  canSync
                      ? ColorManager.kPrimaryColor
                      : Colors.grey.shade400,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _OfflineDataTile extends StatelessWidget {
  final FaIconData? faIcon;
  final IconData? materialIcon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final String value;
  final bool canSync;
  final bool canClear;
  final bool isSyncing;
  final VoidCallback? onSync;
  final VoidCallback? onClear;

  const _OfflineDataTile({
    this.faIcon,
    this.materialIcon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.canSync = false,
    this.canClear = false,
    this.isSyncing = false,
    this.onSync,
    this.onClear,
  }) : assert(
          (faIcon == null) != (materialIcon == null),
          'Provide either faIcon or materialIcon',
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: faIcon != null
                  ? FaIcon(faIcon!, color: iconColor, size: 16)
                  : Icon(materialIcon!, color: iconColor, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s9,
                    0.13,
                    ColorManager.textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                textAlign: TextAlign.right,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.15,
                  value == 'Not cached' || value == 'Never synced'
                      ? Colors.grey.shade600
                      : ColorManager.textColor,
                ),
              ),
              if (onSync != null || onClear != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onSync != null)
                      _TileActionButton(
                        label: isSyncing ? 'Syncing' : 'Sync',
                        icon: Icons.sync,
                        enabled: canSync && !isSyncing,
                        isLoading: isSyncing,
                        color: ColorManager.kPrimaryColor,
                        onTap: onSync!,
                      ),
                    if (onSync != null && onClear != null)
                      const SizedBox(width: 8),
                    if (onClear != null)
                      _TileActionButton(
                        label: 'Clear',
                        icon: Icons.delete_outline,
                        enabled: canClear,
                        color: ColorManager.kButtonRed,
                        onTap: onClear!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TileActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isLoading;
  final Color color;
  final VoidCallback onTap;

  const _TileActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = enabled ? color : Colors.grey.shade400;

    return InkWell(
      onTap: enabled && !isLoading ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 14, color: actionColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s8,
                0.12,
                actionColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
