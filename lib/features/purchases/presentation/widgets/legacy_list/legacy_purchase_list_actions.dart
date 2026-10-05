import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

class LegacyPurchaseListActions {
  LegacyPurchaseListActions(
      {required this.getStoreList,
      required this.getSupplierList,
      required this.storeName,
      required this.supplierName,
      required this.callVoucherDetails});
  final List<GetStoreModelData>? getStoreList;
  final List<GetSuppliersModelData>? getSupplierList;
  final String? Function(int) storeName;
  final String? Function(int) supplierName;
  final void Function({required int voucherId, required int purchaseId})
      callVoucherDetails;
}
