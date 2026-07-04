import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:provider/provider.dart';

enum OfflineCacheTarget {
  products,
  categories,
  productSyncTimestamp,
  paymentMethods,
  deliveryMethods,
  documentConfigs,
  customers,
  suppliers,
  stores,
  units,
  racks,
  cartItems,
  savedOrders,
  confirmedOrders,
}

/// Clears locally cached offline/billing data without touching login credentials.
class OfflineCacheClearService {
  static String labelFor(OfflineCacheTarget target) {
    return switch (target) {
      OfflineCacheTarget.products => 'products',
      OfflineCacheTarget.categories => 'categories',
      OfflineCacheTarget.productSyncTimestamp => 'product sync timestamp',
      OfflineCacheTarget.paymentMethods => 'payment methods',
      OfflineCacheTarget.deliveryMethods => 'delivery methods',
      OfflineCacheTarget.documentConfigs => 'document configurations',
      OfflineCacheTarget.customers => 'customers',
      OfflineCacheTarget.suppliers => 'suppliers',
      OfflineCacheTarget.stores => 'stores',
      OfflineCacheTarget.units => 'units of measure',
      OfflineCacheTarget.racks => 'rack metadata',
      OfflineCacheTarget.cartItems => 'cart items',
      OfflineCacheTarget.savedOrders => 'saved orders',
      OfflineCacheTarget.confirmedOrders => 'confirmed orders',
    };
  }

  static String confirmTitleFor(OfflineCacheTarget target) {
    return 'Clear ${labelFor(target)}?';
  }

  static String confirmMessageFor(OfflineCacheTarget target) {
    return switch (target) {
      OfflineCacheTarget.products =>
        'This removes locally cached products from this device. Login credentials are not affected. Re-sync to download again.',
      OfflineCacheTarget.categories =>
        'This removes locally cached categories from this device. Login credentials are not affected.',
      OfflineCacheTarget.productSyncTimestamp =>
        'This clears the last product sync timestamp. Cached products are kept.',
      OfflineCacheTarget.paymentMethods =>
        'This removes cached payment methods. Billing may need a sync to load them again.',
      OfflineCacheTarget.deliveryMethods =>
        'This removes cached delivery methods. Billing may need a sync to load them again.',
      OfflineCacheTarget.documentConfigs =>
        'This removes cached invoice and receipt templates from this device.',
      OfflineCacheTarget.customers =>
        'This removes the cached customer directory from this device.',
      OfflineCacheTarget.suppliers =>
        'This removes the cached supplier list from this device.',
      OfflineCacheTarget.stores =>
        'This removes the cached store list from this device. Your active store selection is not changed.',
      OfflineCacheTarget.units =>
        'This removes cached units of measure from this device.',
      OfflineCacheTarget.racks =>
        'This removes cached rack metadata from this device.',
      OfflineCacheTarget.cartItems =>
        'This clears all items in the local cart. Reserved stock will be restored if stock management is enabled.',
      OfflineCacheTarget.savedOrders =>
        'This permanently deletes all saved draft orders on this device.',
      OfflineCacheTarget.confirmedOrders =>
        'This permanently deletes all locally confirmed orders on this device.',
    };
  }

  static Future<void> clearTarget(
    BuildContext context,
    OfflineCacheTarget target,
  ) async {
    debugPrint('🧹 [OfflineCacheClear] Clearing ${target.name}');

    switch (target) {
      case OfflineCacheTarget.products:
        context.read<LocalProductProvider>().resetProducts();
        await SharedPreferenceProvider().clearLastProductSyncIso();
        break;
      case OfflineCacheTarget.categories:
        await context.read<CategoryProvider>().clearAllCategories();
        break;
      case OfflineCacheTarget.productSyncTimestamp:
        await SharedPreferenceProvider().clearLastProductSyncIso();
        break;
      case OfflineCacheTarget.paymentMethods:
        await context.read<InvoiceProvider>().clearPaymentMethodsCache();
        break;
      case OfflineCacheTarget.deliveryMethods:
        await context.read<DeliveryMethodsProvider>().clearCachedDeliveryMethods();
        break;
      case OfflineCacheTarget.documentConfigs:
        await context.read<DocumentConfigProvider>().clearAllCaches();
        break;
      case OfflineCacheTarget.customers:
        await context.read<CustomerProvider>().clearCachedCustomers();
        break;
      case OfflineCacheTarget.suppliers:
        context.read<SupplierProvider>().clearCachedSuppliers();
        context.read<PurchaseProvider>().clearCachedSuppliers();
        break;
      case OfflineCacheTarget.stores:
        context.read<PurchaseProvider>().clearCachedStores();
        break;
      case OfflineCacheTarget.units:
        context.read<PurchaseProvider>().clearCachedUnits();
        break;
      case OfflineCacheTarget.racks:
        context.read<PurchaseProvider>().clearCachedRacks();
        break;
      case OfflineCacheTarget.cartItems:
        context.read<LocalProductProvider>().clearCart();
        break;
      case OfflineCacheTarget.savedOrders:
        await context.read<LocalProductProvider>().clearSavedOrdersCache();
        break;
      case OfflineCacheTarget.confirmedOrders:
        await context.read<LocalProductProvider>().clearConfirmedOrdersCache();
        break;
    }

    debugPrint('✅ [OfflineCacheClear] Cleared ${target.name}');
  }
}
