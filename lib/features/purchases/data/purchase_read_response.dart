import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/list_unit.dart';
import 'package:pos_machine/models/master_data.dart';

import '../domain/models/list_purchase.dart';
import '../domain/models/list_purchase_voucher.dart';
import '../domain/models/purchase_order_model.dart';

/// Parsing is lazy so each legacy operation retains its original catch boundary.
/// This object carries response data; it does not own shared or visible state.
class PurchaseReadResponse {
  PurchaseReadResponse(this._response);
  final http.Response _response;
  int get statusCode => _response.statusCode;
  String get body => _response.body;
  String? get reasonPhrase => _response.reasonPhrase;
  dynamic get json => jsonDecode(body);
  GetStoreModel get stores => GetStoreModel.fromJson(json);
  GetSuppliersModel get suppliers => GetSuppliersModel.fromJson(json);
  UnitsResponse get units => UnitsResponse.fromJson(json);
  ListPurchaseModel get purchases => ListPurchaseModel.fromJson(json);
  ListVoucherModel get vouchers => ListVoucherModel.fromJson(json);
  ListPurchaseItemModel get items => ListPurchaseItemModel.fromJson(json);
  ListPurchaseOrderModel get orders => ListPurchaseOrderModel.fromJson(json);
  List<MasterDataValue> get masterDataRows => [
        for (final item in json['data'])
          if (item is Map<String, dynamic>) MasterDataValue.fromJson(item)
      ];
  Map<String, String> get legacyMasterData =>
      Map<String, String>.from(json['data']);
  List<PurchaseItem> get detailItems =>
      List<PurchaseItem>.from((json['data']['purchase_items'] as List)
          .map((item) => PurchaseItem.fromJson(item)));
  VoucherDetail get detailVoucher => VoucherDetail.fromJson(json['data']);
  ListPurchaseModelData get detailHeader =>
      ListPurchaseModelData.fromJson(json['data']);
}
