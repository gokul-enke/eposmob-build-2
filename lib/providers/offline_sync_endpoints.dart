import 'package:flutter/foundation.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncEndpointCall {
  final String method;
  final String url;
  final String label;

  const SyncEndpointCall({
    required this.method,
    required this.url,
    required this.label,
  });
}

/// Resolves GET/POST URLs used when syncing offline data (for debug logging).
class OfflineSyncEndpoints {
  static Future<int?> _activeStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('active_store_id');
  }

  static String _withStoreId(String baseUrl, int? storeId) {
    if (storeId == null) return baseUrl;
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['store_id'] = storeId.toString();
    return uri.replace(queryParameters: params).toString();
  }

  static String _categoryListUrl(int? storeId) {
    final uri = Uri.parse(APPUrl.getSellableCategoryListUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['page'] = '1';
    if (storeId != null) {
      params['store_id'] = storeId.toString();
    }
    return uri.replace(queryParameters: params).toString();
  }

  static Future<List<SyncEndpointCall>> forTarget(OfflineSyncTarget target) async {
    final storeId = await _activeStoreId();

    return switch (target) {
      OfflineSyncTarget.products => [
          SyncEndpointCall(
            method: 'GET',
            url: '${APPUrl.getSellableProductUrl}?type=sellable',
            label: 'Sellable products',
          ),
        ],
      OfflineSyncTarget.categories => [
          SyncEndpointCall(
            method: 'GET',
            url: _categoryListUrl(storeId),
            label: 'Sellable categories',
          ),
        ],
      OfflineSyncTarget.stock => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.listStock,
            label: 'Stock quantities',
          ),
        ],
      OfflineSyncTarget.paymentMethods => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.listTransactionType,
            label: 'Payment methods',
          ),
        ],
      OfflineSyncTarget.deliveryMethods => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.getDeliveryMethods,
            label: 'Delivery methods',
          ),
        ],
      OfflineSyncTarget.documentConfigs => [
          SyncEndpointCall(
            method: 'GET',
            url: _withStoreId(APPUrl.documentConfigs, storeId),
            label: 'Document configurations',
          ),
        ],
      OfflineSyncTarget.customers => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.customerListUrl,
            label: 'Customers',
          ),
        ],
      OfflineSyncTarget.suppliers => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.getSuppliers,
            label: 'Suppliers',
          ),
        ],
      OfflineSyncTarget.stores => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.getStores,
            label: 'Stores',
          ),
        ],
      OfflineSyncTarget.units => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.listUnits,
            label: 'Product units',
          ),
        ],
      OfflineSyncTarget.racks => [
          SyncEndpointCall(
            method: 'GET',
            url: '${APPUrl.getMasterDataValues}?code=RACKS',
            label: 'Rack master data',
          ),
        ],
      OfflineSyncTarget.settings => [
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.getGeneralSettings,
            label: 'General settings',
          ),
          SyncEndpointCall(
            method: 'GET',
            url: APPUrl.getAppSettings,
            label: 'App / website settings',
          ),
        ],
      OfflineSyncTarget.roles => [
          SyncEndpointCall(
            method: 'GET',
            url: _withStoreId(APPUrl.listRoles, storeId),
            label: 'Roles and permissions',
          ),
        ],
    };
  }

  static Future<List<SyncEndpointCall>> forSection(
    OfflineSyncSection section,
  ) async {
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

    final calls = <SyncEndpointCall>[];
    for (final target in targets) {
      calls.addAll(await forTarget(target));
    }
    return calls;
  }

  static Future<List<SyncEndpointCall>> forSyncAll() async {
    final calls = <SyncEndpointCall>[];

    calls.addAll(await forTarget(OfflineSyncTarget.settings));
    calls.addAll(await forTarget(OfflineSyncTarget.roles));
    calls.addAll(await forTarget(OfflineSyncTarget.products));
    calls.addAll(await forTarget(OfflineSyncTarget.stock));
    calls.addAll(await forTarget(OfflineSyncTarget.categories));
    calls.addAll(await forTarget(OfflineSyncTarget.documentConfigs));

    calls.addAll([
      SyncEndpointCall(
        method: 'GET',
        url: APPUrl.listInvoiceAccountType,
        label: 'Invoice account types',
      ),
      SyncEndpointCall(
        method: 'GET',
        url: APPUrl.listTransactionType,
        label: 'Payment methods',
      ),
      SyncEndpointCall(
        method: 'GET',
        url: APPUrl.listVoucherAccountType,
        label: 'Voucher account types',
      ),
      SyncEndpointCall(
        method: 'GET',
        url: APPUrl.listUser,
        label: 'Users list',
      ),
    ]);

    calls.addAll(await forTarget(OfflineSyncTarget.stores));
    calls.addAll([
      SyncEndpointCall(
        method: 'GET',
        url: APPUrl.getSuppliers,
        label: 'Purchase suppliers',
      ),
    ]);
    calls.addAll(await forTarget(OfflineSyncTarget.units));
    calls.addAll(await forTarget(OfflineSyncTarget.racks));
    calls.addAll(await forTarget(OfflineSyncTarget.deliveryMethods));
    calls.addAll(await forTarget(OfflineSyncTarget.suppliers));

    return calls;
  }

  static void logPlan(String trigger, List<SyncEndpointCall> calls) {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔄 [OfflineDataSync] $trigger');
    debugPrint('   Base: ${APPUrl.baseURL}');
    debugPrint('   Calls: ${calls.length} (offline sync is read-only — all GET)');
    for (final call in calls) {
      debugPrint('   ${call.method.padRight(4)} ${call.url}');
      debugPrint('        └─ ${call.label}');
    }
    debugPrint('═══════════════════════════════════════════');
  }

  static Future<void> logTarget(String trigger, OfflineSyncTarget target) async {
    logPlan(trigger, await forTarget(target));
  }

  static Future<void> logSection(String trigger, OfflineSyncSection section) async {
    logPlan(trigger, await forSection(section));
  }

  static Future<void> logSyncAll(String trigger) async {
    logPlan(trigger, await forSyncAll());
  }
}
