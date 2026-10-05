part of 'purchase_provider.dart';

class _PurchaseState extends ChangeNotifier {
  bool isLoading = false;
  ListPurchaseOrderModel? listPurchaseOrderModel;
  List<PurchaseOrderData> purchaseOrdersList = [];
  int listPurchaseOrderCurrentPage = 1;
  int listPurchaseOrderTotalPages = 1;

  List<GetStoreModelData> storeList = [];
  List<GetSuppliersModelData> supplierList = [];
  List<PurchaseItem> purchaseItems = [];
  List<PurchaseItem> _purchaseItemListAllPurchase = [];

  // Getter with safe null handling
  List<PurchaseItem> get purchaseItemListAllPurchase =>
      _purchaseItemListAllPurchase;

  // Setter that ensures the list is never null
  set purchaseItemListAllPurchase(List<PurchaseItem>? value) {
    _purchaseItemListAllPurchase = value ?? [];
  }

  List<PurchaseItem> listPurchaseItemView = [];
  List<GetStoreModelData>? get getStoreList => storeList;
  List<VoucherDetail> voucherDetailsList = [];
  List<VoucherModelData> voucherDetailsListData = [];
  VoucherDetail? voucherDetails;
  List<PurchaseItem>? get getlistPurchaseItemView => listPurchaseItemView;
  VoucherDetail? get getVoucherDetails => voucherDetails;
  int currentPage = 1;
  int totalPages = 1;
  int purchaseVoucherCurrentPage = 1;
  int purchaseVoucherTotalPages = 1;

  ListPurchaseModelData? ListPurchaseModelDataDetails;
  // List<PurchaseItem>? get getlistPurchaseItemView => listPurchaseItemView;
  ListPurchaseModelData? get getListPurchaseModelDataDetails =>
      ListPurchaseModelDataDetails;
  // UnitList? unitList;
  // UnitList? get getUnitList => unitList;
  /// Machine unit values keyed by unit id (`{"6953": "PCS"}`). Identical in
  /// every locale — stored units are matched against these.
  Map<String, String>? unitList;
  Map<String, String>? get getUnitList => unitList;

  /// Locale-resolved unit display text keyed by unit id. Falls back to the
  /// machine value per-entry until the backend ships the `labels` map, so it is
  /// always safe to render.
  Map<String, String>? unitLabels;
  Map<String, String>? get getUnitLabels => unitLabels ?? unitList;

  /// Display text for a unit id, falling back to the machine value.
  String? unitLabelFor(String? unitId) {
    if (unitId == null || unitId.isEmpty) return null;
    return unitLabels?[unitId] ?? unitList?[unitId];
  }

  Map<String, String>? masterDataValues;
  Map<String, dynamic>? activePurchaseOrderDetails;

  final PurchaseRepository repository;
  final PurchaseReturnProvider purchaseReturnProvider;
  _PurchaseState(
      {PurchaseRepository? repository,
      PurchaseReturnRepository? purchaseReturnRepository})
      : repository = repository ?? PurchaseRepository(),
        purchaseReturnProvider =
            PurchaseReturnProvider(repository: purchaseReturnRepository) {
    purchaseReturnProvider.addListener(notifyListeners);
    _initializePurchaseState();
  }
  @override
  void dispose() {
    purchaseReturnProvider.removeListener(notifyListeners);
    purchaseReturnProvider.dispose();
    super.dispose();
  }

  List<PurchaseReturnData> get purchaseReturnsList =>
      purchaseReturnProvider.purchaseReturnsList;
  set purchaseReturnsList(List<PurchaseReturnData> value) =>
      purchaseReturnProvider.purchaseReturnsList = value;
  int get purchaseReturnCurrentPage =>
      purchaseReturnProvider.purchaseReturnCurrentPage;
  set purchaseReturnCurrentPage(int value) =>
      purchaseReturnProvider.purchaseReturnCurrentPage = value;
  int get purchaseReturnTotalPages =>
      purchaseReturnProvider.purchaseReturnTotalPages;
  set purchaseReturnTotalPages(int value) =>
      purchaseReturnProvider.purchaseReturnTotalPages = value;
  List<ReturnableItem> get returnableItemsList =>
      purchaseReturnProvider.returnableItemsList;
  set returnableItemsList(List<ReturnableItem> value) =>
      purchaseReturnProvider.returnableItemsList = value;
  ReturnableItemsData? get activeReturnableItemsData =>
      purchaseReturnProvider.activeReturnableItemsData;
  set activeReturnableItemsData(ReturnableItemsData? value) =>
      purchaseReturnProvider.activeReturnableItemsData = value;

  Map<String, String>? get getMasterDataValues => masterDataValues;
  List<VoucherDetail>? get getVoucherDetailsList => voucherDetailsList;
  List<PurchaseItem> get getPurchaseDetailsList {
    debugPrint("getPurchaseDetailsList called");
    try {
      // Our class getter already ensures non-null list
      var list = purchaseItemListAllPurchase;
      debugPrint("purchaseItemListAllPurchase type: ${list.runtimeType}");
      debugPrint("purchaseItemListAllPurchase length: ${list.length}");
      return list;
    } catch (e) {
      debugPrint("Error in getPurchaseDetailsList: $e");
      return [];
    }
  }

  List<VoucherModelData>? get getVoucherModelDataList => voucherDetailsListData;
  List<GetSuppliersModelData>? get getSupplierList => supplierList;
  GetStoreModelData storeDemo = GetStoreModelData(
    id: 0,
    name: "Select Store",
    code: "Select Store",
    status: "Y",
  );

  void clearCachedStores() {
    storeList = [];
    notifyListeners();
    debugPrint('Cleared cached stores');
  }

  void clearCachedSuppliers() {
    supplierList = [];
    notifyListeners();
    debugPrint('Cleared cached purchase suppliers');
  }

  void clearCachedUnits() {
    unitList = {};
    notifyListeners();
    debugPrint('Cleared cached units');
  }

  void clearCachedRacks() {
    masterDataValues = {};
    notifyListeners();
    debugPrint('Cleared cached rack metadata');
  }

  String getStoreNameFromId(int storeId) {
    if (storeList == null || storeList!.isEmpty) {
      return "Unknown";
    }

    var store = storeList!.firstWhere(
      (e) => e.id == storeId,
      orElse: () => GetStoreModelData(id: 0, name: "Unknown"),
    );

    return store.name ?? "Unknown";
  }

  void callVoucherDetails({required int voucherId, required int purchaseId}) {
    debugPrint(
        "callVoucherDetails called with voucherId: $voucherId, purchaseId: $purchaseId");
    debugPrint(
        "purchaseItemListAllPurchase before assignment: $purchaseItemListAllPurchase");
    debugPrint(
        "purchaseItemListAllPurchase type: ${purchaseItemListAllPurchase.runtimeType}");
    debugPrint(
        "purchaseItemListAllPurchase null?: ${purchaseItemListAllPurchase == null}");

    List<PurchaseItem> purchaseItemList = purchaseItemListAllPurchase;
    // .firstWhere((element) =>
    //     element.any((element) => element.purchaseId == purchaseId));
    listPurchaseItemView = purchaseItemList;

    debugPrint("voucherDetailsList before assignment: $voucherDetailsList");
    debugPrint("voucherDetailsList type: ${voucherDetailsList.runtimeType}");
    debugPrint("voucherDetailsList null?: ${voucherDetailsList == null}");

    try {
      VoucherDetail? voucher = voucherDetailsList.firstWhere(
        (element) => element.id == voucherId,
      );
      voucherDetails = voucher;
    } catch (e) {
      debugPrint("Error in callVoucherDetails: $e");
      voucherDetails = null;
    }

    notifyListeners();
  }

  String? storeName(int value) {
    var store = storeList.firstWhere((e) => e.id == value,
        orElse: () => GetStoreModelData(id: 0, name: "Unknown"));
    return store.name;
  }

  String? supplierName(int value) {
    var supplier = supplierList.firstWhere((e) => e.id == value,
        orElse: () => GetSuppliersModelData(
            id: 0, user: User(name: "Unknown") // Now correctly nested
            ));
    return supplier.user?.name;
  }

  void _initializePurchaseState() {
    debugPrint("PurchaseProvider constructor called");
    // Ensure lists are initialized to prevent null issues
    storeList = [];
    supplierList = [];
    purchaseItems = [];
    purchaseItemListAllPurchase = [];
    listPurchaseItemView = [];
    voucherDetailsList = [];
    voucherDetailsListData = [];

    debugPrint(
        "Initial purchaseItemListAllPurchase type: ${purchaseItemListAllPurchase.runtimeType}");
    debugPrint(
        "Initial purchaseItemListAllPurchase length: ${purchaseItemListAllPurchase.length}");
  }

  GetSuppliersModelData supplierDemo = GetSuppliersModelData(
    id: 0,
    user: User(name: "Select Supplier"), // Name now properly nested
    phone: "",
    email: "",
  );

  //          *********************** LIST ALL STORES  API ***************************************************
}
