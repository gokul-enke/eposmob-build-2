import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';

/// Callback-only boundaries supplied by the page. No providers or contexts.
class PurchaseFormPurchasePort {
  PurchaseFormPurchasePort(
      {required this.readStores,
      required this.readSuppliers,
      required this.readUnits,
      required this.readRacks,
      required this.readDetails,
      required this.writeDetails,
      required this.listAllStores,
      required this.listAllSuppliers,
      required this.createPurchaseOrder,
      required this.receivePurchaseOrder,
      required this.listPurchaseOrders});
  final List<GetStoreModelData>? Function() readStores;
  final List<GetSuppliersModelData>? Function() readSuppliers;
  final Map<String, String>? Function() readUnits;
  final Map<String, String>? Function() readRacks;
  final Map<String, dynamic>? Function() readDetails;
  final void Function(Map<String, dynamic>?) writeDetails;
  List<GetStoreModelData>? get getStoreList => readStores();
  List<GetSuppliersModelData>? get getSupplierList => readSuppliers();
  Map<String, String>? get getUnitList => readUnits();
  Map<String, String>? get getMasterDataValues => readRacks();
  Map<String, dynamic>? get activePurchaseOrderDetails => readDetails();
  set activePurchaseOrderDetails(Map<String, dynamic>? value) =>
      writeDetails(value);
  final Future<void> Function(String, String?) listAllStores;
  final Future<void> Function(String, String?) listAllSuppliers;
  final Future<dynamic> Function({
    required String accessToken,
    required String purchaseDate,
    required String supplierId,
    required String storeId,
    String? voucherNumber,
    String? invoiceRef,
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
    required List<Map<String, dynamic>> items,
  }) createPurchaseOrder;
  final Future<dynamic> Function({
    required String accessToken,
    required String purchaseId,
    required List<Map<String, dynamic>> items,
    String? invoiceRef, // NEW!
    required double discount,
    List<String>? paymentMethods,
    Map<String, dynamic>? paidAmounts,
  }) receivePurchaseOrder;
  final Future<void> Function({
    required String accessToken,
    String? storeId,
    String? supplierId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) listPurchaseOrders;
}

class PurchaseFormProductsPort {
  PurchaseFormProductsPort(
      {required this.read, required this.filterProductByBarcode});
  final List<GetProduct> Function() read;
  List<GetProduct> get products => read();
  final List<GetProduct> Function({required String barCode})
      filterProductByBarcode;
}

class PurchaseFormCategoryPort {
  PurchaseFormCategoryPort(this.read);
  final List<Category>? Function() read;
  List<Category>? get category => read();
}

class PurchaseFormMasterDataPort {
  PurchaseFormMasterDataPort(
      {required this.read, required this.fetchPaymentMethods});
  final List<MasterDataValue>? Function() read;
  List<MasterDataValue>? get paymentMethods => read();
  final Future<List<MasterDataValue>?> Function() fetchPaymentMethods;
}

class PurchaseFormStorePort {
  PurchaseFormStorePort(this.read);
  final GetStoreModelData? Function() read;
  GetStoreModelData? get activeStore => read();
}

class PurchaseFormAuthPort {
  PurchaseFormAuthPort(this.read);
  final String? Function() read;
  String? get token => read();
}

class PurchaseFormStockPort {
  PurchaseFormStockPort(this.calculateTaxAPI);
  final Future<Map<String, dynamic>?> Function(
      {required String accessToken,
      required double price,
      required int productId,
      required int categoryId,
      required bool taxInclude}) calculateTaxAPI;
}

class PurchaseOrderFormPorts {
  PurchaseOrderFormPorts(
      {required this.purchases,
      required this.products,
      required this.categories,
      required this.masterData,
      required this.stores,
      required this.auth,
      required this.stock,
      required this.currency,
      required this.pickProduct,
      required this.pickSupplier,
      required this.validate,
      required this.onError,
      required this.onSuccess,
      required this.onComplete,
      this.session = const TenantSession()});
  final PurchaseFormPurchasePort purchases;
  final PurchaseFormProductsPort products;
  final PurchaseFormCategoryPort categories;
  final PurchaseFormMasterDataPort masterData;
  final PurchaseFormStorePort stores;
  final PurchaseFormAuthPort auth;
  final PurchaseFormStockPort stock;
  final String Function() currency;
  final Future<Map<String, dynamic>?> Function(String?) pickProduct;
  final Future<dynamic> Function() pickSupplier;
  final bool Function() validate;
  final void Function(String) onError;
  final void Function(String) onSuccess;
  final void Function() onComplete;
  final TenantSession session;
}
