import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPurchaseOrderDraftBoxName = 'purchase_order_draft_box';

class PurchaseOrderItem {
  int? id; // NEW! Track the existing purchase item ID
  String barcode;

  Category? categoryData;
  GetProduct? productData;
  String unit;
  String quantity;
  String purchaseRate;

  String retailPrice;
  String mrp;
  DateTime? expDate;

  String wholesalePrice;
  String wholesaleMinUnit;
  String rack;
  String? selectedUnit;
  String? selectedRack;
  bool taxInclude;

  bool receive;
  TextEditingController qtyCtrl;
  TextEditingController purchasePriceCtrl;
  TextEditingController retailPriceCtrl;
  TextEditingController mrpCtrl;
  TextEditingController wholesalePriceCtrl;

  PurchaseOrderItem({
    this.barcode = '',
    this.categoryData,
    this.productData,
    this.unit = '',
    this.quantity = '1',
    this.purchaseRate = '',
    this.retailPrice = '',
    this.mrp = '',
    this.expDate,
    this.wholesalePrice = '',
    this.wholesaleMinUnit = '',
    this.rack = '',
    this.selectedUnit,
    this.selectedRack,
    this.taxInclude = false,
    this.receive = false,
    this.id,
  })  : qtyCtrl = TextEditingController(text: quantity),
        purchasePriceCtrl = TextEditingController(text: purchaseRate),
        retailPriceCtrl = TextEditingController(text: retailPrice),
        mrpCtrl = TextEditingController(text: mrp),
        wholesalePriceCtrl = TextEditingController(text: wholesalePrice);

  void syncControllers() {
    qtyCtrl.text = quantity;
    purchasePriceCtrl.text = purchaseRate;
    retailPriceCtrl.text = retailPrice;
    mrpCtrl.text = mrp;
    wholesalePriceCtrl.text = wholesalePrice;
  }
}

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key});

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final SideBarController sideBarController = Get.find();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Box? _draftBox;
  Timer? _draftSaveDebouncer;
  bool _isHydratingDraft = false;
  static const Duration _draftSaveDelay = Duration(milliseconds: 500);

  // Header controllers
  final TextEditingController supplierSearchController =
      TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController voucherNumberController = TextEditingController();
  final TextEditingController invoiceRefController = TextEditingController();

  // Settings

  // Row controllers maps
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController productSearchController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  final FocusNode quantityFocusNode = FocusNode();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  final TextEditingController mrpController = TextEditingController();
  final TextEditingController wholesalePriceController =
      TextEditingController();
  final TextEditingController wholesaleMinUnitController =
      TextEditingController();
  final TextEditingController rackController = TextEditingController();
  final TextEditingController unitSearchController = TextEditingController();
  final TextEditingController rackSearchController = TextEditingController();

  List<PurchaseOrderItem> orderItems = [];
  PurchaseOrderItem currentItem = PurchaseOrderItem();
  bool includeTax = false;
  bool _showItemDetails = true;
  int? _editingItemIndex;

  // Dynamic payment methods (same as add stock page)
  DynamicPaymentData paymentData = DynamicPaymentData();
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  bool _isSubmitting = false;

  GetStoreModelData? selectedStore;
  GetSuppliersModelData? selectedSupplier;
  DateTime selectedDate = DateTime.now();
  int?
      purchaseOrderId; // NEW! Track if we are editing/receiving an existing order

  // Keep a minimum table width so smaller devices can scroll horizontally.
  // 1620 columns + 16 row padding + 16 row horizontal margin.
  static const double _purchaseTableMinWidth = 1652;

  ScrollBehavior get _horizontalDragScrollBehavior {
    return const MaterialScrollBehavior().copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initDraftBox();
    _loadInitialData();
  }

  Future<void> _initDraftBox() async {
    try {
      if (!Hive.isBoxOpen(_kPurchaseOrderDraftBoxName)) {
        _draftBox = await Hive.openBox(_kPurchaseOrderDraftBoxName);
      } else {
        _draftBox = Hive.box(_kPurchaseOrderDraftBoxName);
      }
      debugPrint('✅ Purchase order draft Hive box initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize purchase order draft box: $e');
    }
  }

  bool get _canPersistDraft => purchaseOrderId == null;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> _purchaseOrderItemToMap(PurchaseOrderItem item) {
    return {
      'id': item.id,
      'barcode': item.barcode,
      'productId': item.productData?.productId,
      'productName': item.productData?.productName,
      'categoryId': item.categoryData?.categoryId,
      'categoryName': item.categoryData?.categoryName,
      'unit': item.unit,
      'quantity': item.quantity,
      'purchaseRate': item.purchaseRate,
      'retailPrice': item.retailPrice,
      'mrp': item.mrp,
      'expDate': item.expDate?.toIso8601String(),
      'wholesalePrice': item.wholesalePrice,
      'wholesaleMinUnit': item.wholesaleMinUnit,
      'rack': item.rack,
      'selectedUnit': item.selectedUnit,
      'selectedRack': item.selectedRack,
      'taxInclude': item.taxInclude,
      'receive': item.receive,
    };
  }

  PurchaseOrderItem _mapToPurchaseOrderItem(Map<dynamic, dynamic> map) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final int? productId = _toInt(map['productId']);
    final String? productName = map['productName']?.toString();
    final int? categoryId = _toInt(map['categoryId']);
    final String? categoryName = map['categoryName']?.toString();

    GetProduct? productData;
    if (productId != null) {
      try {
        productData = localProductProvider.products.firstWhere(
          (p) => p.productId == productId,
        );
      } catch (_) {}
    }

    productData ??= (productId != null || (productName?.isNotEmpty ?? false))
        ? GetProduct(
            productId: productId,
            productName: productName,
            barcode: map['barcode']?.toString(),
          )
        : null;

    Category? categoryData;
    final categories = categoryProvider.category ?? [];
    if (categoryId != null && categories.isNotEmpty) {
      try {
        categoryData = categories.firstWhere((c) => c.categoryId == categoryId);
      } catch (_) {}
    }

    categoryData ??= (categoryId != null || (categoryName?.isNotEmpty ?? false))
        ? Category(categoryId: categoryId, categoryName: categoryName)
        : null;

    return PurchaseOrderItem(
      id: _toInt(map['id']),
      barcode: map['barcode']?.toString() ?? '',
      categoryData: categoryData,
      productData: productData,
      unit: map['unit']?.toString() ?? '',
      quantity: map['quantity']?.toString() ?? '1',
      purchaseRate: map['purchaseRate']?.toString() ?? '',
      retailPrice: map['retailPrice']?.toString() ?? '',
      mrp: map['mrp']?.toString() ?? '',
      expDate: map['expDate'] != null
          ? DateTime.tryParse(map['expDate'].toString())
          : null,
      wholesalePrice: map['wholesalePrice']?.toString() ?? '',
      wholesaleMinUnit: map['wholesaleMinUnit']?.toString() ?? '',
      rack: map['rack']?.toString() ?? '',
      selectedUnit: map['selectedUnit']?.toString(),
      selectedRack: map['selectedRack']?.toString(),
      taxInclude: map['taxInclude'] == true,
      receive: map['receive'] == true,
    )..syncControllers();
  }

  Map<String, dynamic> _paymentDataToMap(DynamicPaymentData data) {
    return {
      'primaryMethodId': data.primaryMethod?.id,
      'secondaryMethodId': data.secondaryMethod?.id,
      'primaryAmount': data.primaryAmount,
      'secondaryAmount': data.secondaryAmount,
    };
  }

  DynamicPaymentData _mapToPaymentData(dynamic paymentMapRaw) {
    if (paymentMapRaw is! Map) return DynamicPaymentData();

    final paymentMap = paymentMapRaw.cast<dynamic, dynamic>();
    final int? primaryMethodId = _toInt(paymentMap['primaryMethodId']);
    final int? secondaryMethodId = _toInt(paymentMap['secondaryMethodId']);

    MasterDataValue? primaryMethod;
    MasterDataValue? secondaryMethod;

    if (primaryMethodId != null) {
      try {
        primaryMethod = _paymentMethods
            .firstWhere((method) => method.id == primaryMethodId);
      } catch (_) {}
    }

    if (secondaryMethodId != null) {
      try {
        secondaryMethod = _paymentMethods
            .firstWhere((method) => method.id == secondaryMethodId);
      } catch (_) {}
    }

    return DynamicPaymentData(
      primaryMethod: primaryMethod,
      secondaryMethod: secondaryMethod,
      primaryAmount: paymentMap['primaryAmount']?.toString() ?? '',
      secondaryAmount: paymentMap['secondaryAmount']?.toString() ?? '',
    );
  }

  void _saveDraftToHive() {
    if (_isHydratingDraft || !_canPersistDraft) return;

    _draftSaveDebouncer?.cancel();
    _draftSaveDebouncer = Timer(_draftSaveDelay, () async {
      if (_draftBox == null || !_draftBox!.isOpen || !_canPersistDraft) return;

      try {
        final draftData = <String, dynamic>{
          'selectedDate': selectedDate.toIso8601String(),
          'selectedStoreId': selectedStore?.id,
          'selectedSupplierId': selectedSupplier?.id,
          'voucherNumber': voucherNumberController.text,
          'invoiceRef': invoiceRefController.text,
          'includeTax': includeTax,
          'showItemDetails': _showItemDetails,
          'editingItemIndex': _editingItemIndex,
          'orderItems': orderItems.map(_purchaseOrderItemToMap).toList(),
          'currentItem': _purchaseOrderItemToMap(currentItem),
          'paymentData': _paymentDataToMap(paymentData),
        };

        await _draftBox!.put('draft', draftData);
      } catch (e) {
        debugPrint('❌ Failed to save purchase order draft: $e');
      }
    });
  }

  Future<void> _loadDraftFromHive() async {
    if (!_canPersistDraft) return;

    if (_draftBox == null || !_draftBox!.isOpen) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_draftBox == null || !_draftBox!.isOpen) {
        return;
      }
    }

    try {
      final draftRaw = _draftBox!.get('draft');
      if (draftRaw is! Map) return;

      final draft = draftRaw.cast<dynamic, dynamic>();
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);

      final dynamic orderItemsRaw = draft['orderItems'];
      final List<PurchaseOrderItem> restoredItems = [];
      if (orderItemsRaw is List) {
        for (final rawItem in orderItemsRaw) {
          if (rawItem is Map) {
            restoredItems.add(_mapToPurchaseOrderItem(rawItem));
          }
        }
      }

      final currentItemRaw = draft['currentItem'];
      final PurchaseOrderItem restoredCurrentItem = (currentItemRaw is Map)
          ? _mapToPurchaseOrderItem(currentItemRaw)
          : PurchaseOrderItem();

      GetStoreModelData? restoredStore;
      final int? restoredStoreId = _toInt(draft['selectedStoreId']);
      if (restoredStoreId != null &&
          purchaseProvider.getStoreList != null &&
          purchaseProvider.getStoreList!.isNotEmpty) {
        try {
          restoredStore = purchaseProvider.getStoreList!
              .firstWhere((store) => store.id == restoredStoreId);
        } catch (_) {}
      }

      GetSuppliersModelData? restoredSupplier;
      final int? restoredSupplierId = _toInt(draft['selectedSupplierId']);
      if (restoredSupplierId != null &&
          purchaseProvider.getSupplierList != null &&
          purchaseProvider.getSupplierList!.isNotEmpty) {
        try {
          restoredSupplier = purchaseProvider.getSupplierList!
              .firstWhere((supplier) => supplier.id == restoredSupplierId);
        } catch (_) {}
      }

      _isHydratingDraft = true;
      if (!mounted) return;

      setState(() {
        selectedDate = draft['selectedDate'] != null
            ? DateTime.tryParse(draft['selectedDate'].toString()) ??
                DateTime.now()
            : DateTime.now();
        selectedStore = restoredStore ?? selectedStore;
        selectedSupplier = restoredSupplier;
        includeTax = draft['includeTax'] == true;
        _showItemDetails = draft['showItemDetails'] != false;
        _editingItemIndex = _toInt(draft['editingItemIndex']);
        orderItems = restoredItems;
        currentItem = restoredCurrentItem;
        paymentData = _mapToPaymentData(draft['paymentData']);

        currentItem.syncControllers();
      });

      voucherNumberController.text = draft['voucherNumber']?.toString() ?? '';
      invoiceRefController.text = draft['invoiceRef']?.toString() ?? '';
      barcodeController.text = currentItem.barcode;
      unitController.text = currentItem.unit;
      quantityController.text = currentItem.quantity;
      rateController.text = currentItem.purchaseRate;
      retailPriceController.text = currentItem.retailPrice;
      mrpController.text = currentItem.mrp;
      wholesalePriceController.text = currentItem.wholesalePrice;
      wholesaleMinUnitController.text = currentItem.wholesaleMinUnit;
      rackController.text = currentItem.rack;

      if (selectedStore != null) {
        storeSearchController.text = selectedStore?.name ?? '';
      }
      if (selectedSupplier != null) {
        supplierSearchController.text =
            selectedSupplier?.user?.name ?? selectedSupplier?.name ?? '';
      }

      _syncPaidAmount();
      debugPrint('✅ Purchase order draft restored successfully');
    } catch (e) {
      debugPrint('❌ Failed to load purchase order draft: $e');
    } finally {
      _isHydratingDraft = false;
    }
  }

  Future<void> _clearDraftFromHive() async {
    _draftSaveDebouncer?.cancel();
    if (_draftBox == null || !_draftBox!.isOpen) return;
    try {
      await _draftBox!.delete('draft');
    } catch (e) {
      debugPrint('❌ Failed to clear purchase order draft: $e');
    }
  }

  Future<void> _loadInitialData() async {
    String? token = Provider.of<AuthModel>(context, listen: false).token;
    if (token != null) {
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      await purchaseProvider.listAllStores(token, null);
      await purchaseProvider.listAllSuppliers(token, null);
      await _loadActiveStore();
      await _loadPaymentMethods();

      // Handle pre-population if activePurchaseOrderDetails is set
      if (purchaseProvider.activePurchaseOrderDetails != null) {
        final data = purchaseProvider.activePurchaseOrderDetails!;
        setState(() {
          // Header
          purchaseOrderId = data['id']; // NEW! Capture the ID
          voucherNumberController.text =
              data['voucher_number']?.toString() ?? "";
          invoiceRefController.text = data['invoice_ref']?.toString() ?? "";
          if (data['purchase_date'] != null) {
            selectedDate =
                DateTime.tryParse(data['purchase_date']) ?? DateTime.now();
          }

          // Store
          if (data['store'] != null) {
            selectedStore = GetStoreModelData.fromJson(data['store']);
            storeSearchController.text = selectedStore?.name ?? "";
          }

          // Supplier
          if (data['supplier'] != null) {
            selectedSupplier = GetSuppliersModelData.fromJson(data['supplier']);
            supplierSearchController.text = selectedSupplier?.name ?? "";
          }

          // Items - Support both 'items' (new list API) and 'purchase_items' (old/detail API)
          final itemsList = data['items'] ?? data['purchase_items'];
          if (itemsList != null) {
            orderItems = (itemsList as List).map((item) {
              return PurchaseOrderItem(
                id: item['id'], // NEW! SET THE ITEM ID
                barcode: (item['bar_code'] ?? item['barcode'] ?? "").toString(),

                quantity: item['quantity']?.toString() ?? "1",
                purchaseRate:
                    (item['unit_price'] ?? item['purchase_rate'] ?? "")
                        .toString(),
                unit: (item['unit'] ?? "").toString(),
                productData: (item['product'] != null)
                    ? GetProduct.fromJson(item['product'])
                    : (item['product_name'] != null || item['name'] != null
                        ? GetProduct(
                            productId: int.tryParse(
                                (item['product_id'] ?? item['id'] ?? "")
                                    .toString()),
                            productName: item['product_name'] ?? item['name'])
                        : null),

                // Map additional fields if present in the response
                retailPrice: item['retail_price']?.toString() ?? "",
                mrp: item['mrp']?.toString() ?? "",
                wholesalePrice: item['wholesale_price']?.toString() ?? "",
                wholesaleMinUnit: item['wholesale_min_unit']?.toString() ?? "",
                rack: item['rack']?.toString() ?? "",
              )
                ..receive = (item['status'] == 'Y')
                ..syncControllers();
            }).toList();
            _syncPaidAmount();
          }
        });
        return;
      }

      await _loadDraftFromHive();
    }
  }

  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);

    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final cachedMethods = masterDataProvider.paymentMethods;
      final methods = (cachedMethods != null && cachedMethods.isNotEmpty)
          ? cachedMethods
          : (await masterDataProvider.fetchPaymentMethods() ??
              <MasterDataValue>[]);

      if (!mounted) return;

      setState(() {
        _paymentMethods = methods;
        _isLoadingPaymentMethods = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  Future<void> _loadActiveStore() async {
    // Keep behavior same as add stock page: session first, prefs fallback.
    try {
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      if (storeSession.activeStore != null) {
        final activeStore = storeSession.activeStore!;
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);

        GetStoreModelData? fullStoreData;
        if (purchaseProvider.getStoreList != null) {
          try {
            fullStoreData = purchaseProvider.getStoreList!.firstWhere(
              (s) => s.id == activeStore.storeId,
            );
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            selectedStore = fullStoreData ??
                GetStoreModelData(
                  id: activeStore.storeId,
                  name: activeStore.storeName,
                );
          });
        }
        return;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (activeStoreId != null) {
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);

        if (purchaseProvider.getStoreList != null &&
            purchaseProvider.getStoreList!.isNotEmpty) {
          final store = purchaseProvider.getStoreList!.firstWhere(
            (s) => s.id == activeStoreId,
            orElse: () => purchaseProvider.getStoreList!.first,
          );

          if (mounted) {
            setState(() {
              selectedStore = store;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _addItem() {
    if (currentItem.productData == null) {
      _showErrorMessage("Please select a product to add");
      return;
    }

    setState(() {
      currentItem.taxInclude = includeTax;
      currentItem.syncControllers();

      if (_editingItemIndex != null && _editingItemIndex! < orderItems.length) {
        orderItems[_editingItemIndex!] = currentItem;
      } else {
        orderItems.add(currentItem);
      }

      _clearCurrentItemForm();
      _syncPaidAmount();
    });
    _saveDraftToHive();
  }

  void _clearCurrentItemForm() {
    currentItem = PurchaseOrderItem();
    _editingItemIndex = null;
    barcodeController.clear();
    unitController.clear();
    quantityController.text = '1';
    rateController.clear();
    retailPriceController.clear();
    mrpController.clear();
    wholesalePriceController.clear();
    wholesaleMinUnitController.clear();
    rackController.clear();
    categorySearchController.clear();
    productSearchController.clear();
    includeTax = false;
  }

  void _editItem(int index) {
    if (index < 0 || index >= orderItems.length) return;
    final item = orderItems[index];

    setState(() {
      _editingItemIndex = index;
      currentItem = PurchaseOrderItem(
        id: item.id,
        barcode: item.barcode,
        categoryData: item.categoryData,
        productData: item.productData,
        unit: item.unit,
        selectedUnit: item.selectedUnit,
        quantity: item.quantity,
        purchaseRate: item.purchaseRate,
        retailPrice: item.retailPrice,
        mrp: item.mrp,
        expDate: item.expDate,
        wholesalePrice: item.wholesalePrice,
        wholesaleMinUnit: item.wholesaleMinUnit,
        rack: item.rack,
        selectedRack: item.selectedRack,
        taxInclude: item.taxInclude,
        receive: item.receive,
      )..syncControllers();

      barcodeController.text = currentItem.barcode;
      unitController.text = currentItem.unit;
      quantityController.text = currentItem.quantity;
      rateController.text = currentItem.purchaseRate;
      retailPriceController.text = currentItem.retailPrice;
      mrpController.text = currentItem.mrp;
      wholesalePriceController.text = currentItem.wholesalePrice;
      wholesaleMinUnitController.text = currentItem.wholesaleMinUnit;
      rackController.text = currentItem.rack;
      includeTax = currentItem.taxInclude;
      _showItemDetails = true;
    });
    _saveDraftToHive();
  }

  void _removeItem(int index) {
    if (orderItems.length > index) {
      setState(() {
        orderItems.removeAt(index);
        if (_editingItemIndex == index) {
          _clearCurrentItemForm();
        } else if (_editingItemIndex != null && _editingItemIndex! > index) {
          _editingItemIndex = _editingItemIndex! - 1;
        }
        _syncPaidAmount();
      });
      _saveDraftToHive();
    }
  }

  double get totalAmount {
    double total = 0;
    for (var item in orderItems) {
      double qty = double.tryParse(item.quantity) ?? 0;
      double rate = double.tryParse(item.purchaseRate) ?? 0;
      total += (qty * rate);
    }
    return total;
  }

  double get totalReceivedAmount {
    double total = 0;
    for (var item in orderItems) {
      if (item.receive) {
        double qty = double.tryParse(item.quantity) ?? 0;
        double rate = double.tryParse(item.purchaseRate) ?? 0;
        total += (qty * rate);
      }
    }
    return total;
  }

  void _syncPaidAmount() {
    // Payment amounts are controlled by BuildDynamicPaymentSelector state.
  }

  Map<String, dynamic> _convertPaymentDataToPurchaseApiFormat(
      DynamicPaymentData paymentData) {
    final List<String> paymentMethods = [];
    final Map<String, double> paidAmounts = {};

    if (paymentData.primaryMethod != null &&
        paymentData.primaryAmount.isNotEmpty) {
      final double amount = double.tryParse(paymentData.primaryAmount) ?? 0.0;
      if (amount > 0) {
        final methodValue = paymentData.primaryMethod!.value;
        paymentMethods.add(methodValue);
        paidAmounts[methodValue] = amount;
      }
    }

    if (paymentData.secondaryMethod != null &&
        paymentData.secondaryAmount.isNotEmpty) {
      final double amount = double.tryParse(paymentData.secondaryAmount) ?? 0.0;
      if (amount > 0) {
        final methodValue = paymentData.secondaryMethod!.value;
        paymentMethods.add(methodValue);
        paidAmounts[methodValue] = amount;
      }
    }

    return {
      'payment_methods': paymentMethods,
      'paid_amounts': paidAmounts,
    };
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String get _currency {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final currency = appSettings?.currency.trim();
    if (currency == null || currency.isEmpty) {
      return 'SAR';
    }
    return currency;
  }

  String? _validateReceiveItemFields(PurchaseOrderItem item) {
    final itemName = item.productData?.productName ?? 'Selected item';

    if ((double.tryParse(item.retailPrice) ?? 0) <= 0) {
      return "$itemName: retail price is required";
    }
    return null;
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    showScaffoldError(context: context, message: message);
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showScaffold(context: context, message: message);
  }

  void _focusQuantityAndSelectAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      quantityFocusNode.requestFocus();
      quantityController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: quantityController.text.length,
      );
    });
  }

  String? _resolveUnitKey(String? productUnitValue) {
    final normalized = productUnitValue?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    final unitList =
        Provider.of<PurchaseProvider>(context, listen: false).getUnitList;
    if (unitList == null || unitList.isEmpty) return normalized;

    if (unitList.containsKey(normalized)) return normalized;

    final needle = normalized.toLowerCase();
    for (final entry in unitList.entries) {
      if (entry.key.toLowerCase() == needle ||
          entry.value.toLowerCase() == needle) {
        return entry.key;
      }
    }

    return normalized;
  }

  Category? _resolveCategoryForProduct(GetProduct product) {
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).category ??
            const <Category>[];

    if (product.categoryId != null) {
      for (final category in categories) {
        if (category.categoryId == product.categoryId) {
          return category;
        }
      }
    }

    final productCategoryName = product.category?.name?.trim().toLowerCase();
    if (productCategoryName != null && productCategoryName.isNotEmpty) {
      for (final category in categories) {
        final categoryName = category.categoryName?.trim().toLowerCase();
        if (categoryName == productCategoryName) {
          return category;
        }
      }
    }

    return null;
  }

  void _applyProductToCurrentItem(GetProduct product,
      {String? initialQuantity}) {
    final resolvedCategory = _resolveCategoryForProduct(product);
    final resolvedUnitKey = _resolveUnitKey(product.unit);
    final unitList =
        Provider.of<PurchaseProvider>(context, listen: false).getUnitList;
    final resolvedUnitName = resolvedUnitKey != null
        ? (unitList?[resolvedUnitKey] ?? product.unit ?? '')
        : '';
    final effectiveQuantity = (initialQuantity ?? '').trim().isNotEmpty
        ? initialQuantity!.trim()
        : (currentItem.quantity.trim().isNotEmpty ? currentItem.quantity : '1');

    setState(() {
      currentItem.productData = product;
      currentItem.categoryData = resolvedCategory ?? currentItem.categoryData;
      currentItem.barcode = product.barcode ?? '';
      currentItem.selectedUnit = resolvedUnitKey;
      currentItem.unit = resolvedUnitName;
      currentItem.purchaseRate = product.purchasePrice ?? '';
      currentItem.retailPrice = product.price?.price?.toString() ?? '';
      currentItem.mrp = product.mrp?.toString() ?? '';
      currentItem.wholesalePrice = product.price?.price?.toString() ?? '';
      currentItem.quantity = effectiveQuantity;
    });

    barcodeController.text = currentItem.barcode;
    unitController.text = currentItem.unit;
    rateController.text = currentItem.purchaseRate;
    retailPriceController.text = currentItem.retailPrice;
    mrpController.text = currentItem.mrp;
    wholesalePriceController.text = currentItem.wholesalePrice;
    quantityController.text = currentItem.quantity;

    _saveDraftToHive();
    _focusQuantityAndSelectAll();
  }

  Future<void> _showAddProductModal({String? barcode}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductWithBarcodeModal(barcode: barcode),
    );

    if (result == null || result['product'] == null || !mounted) {
      return;
    }

    final product = result['product'];
    final initialQuantity = result['initialQuantity']?.toString();

    if (product is GetProduct) {
      _applyProductToCurrentItem(product, initialQuantity: initialQuantity);
      return;
    }

    if (product is Map<String, dynamic>) {
      try {
        final parsedProduct = GetProduct.fromJson(product);
        _applyProductToCurrentItem(parsedProduct,
            initialQuantity: initialQuantity);
      } catch (_) {}
    }
  }

  Future<void> _performBarcodeAutoFill(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return;
    }

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final products =
        localProductProvider.filterProductByBarcode(barCode: normalizedBarcode);

    if (products.isNotEmpty) {
      _applyProductToCurrentItem(products.first);
      return;
    }

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AddProductWithBarcodeModal(barcode: normalizedBarcode),
    );

    if (created != null && created['product'] != null) {
      final createdProduct = created['product'];
      final initialQuantity = created['initialQuantity']?.toString();

      if (createdProduct is GetProduct) {
        _applyProductToCurrentItem(createdProduct,
            initialQuantity: initialQuantity);
      } else if (createdProduct is Map<String, dynamic>) {
        try {
          _applyProductToCurrentItem(GetProduct.fromJson(createdProduct),
              initialQuantity: initialQuantity);
        } catch (_) {}
      }
    }
  }

  Future<void> _autoFillFromBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return;

    currentItem.barcode = normalizedBarcode;
    await _performBarcodeAutoFill(normalizedBarcode);
  }

  Future<void> _submitPurchaseOrder() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (selectedSupplier == null) {
      _showErrorMessage("Please select Supplier");
      return;
    }

    if (selectedStore == null) {
      _showErrorMessage("Please select Store");
      return;
    }

    if (orderItems.isEmpty) {
      _showErrorMessage("Please add at least one item from the form above");
      return;
    }

    final apiPaymentData = _convertPaymentDataToPurchaseApiFormat(paymentData);
    final List<String> paymentMethods =
        (apiPaymentData['payment_methods'] as List<String>);
    final Map<String, double> paidAmountsMap =
        (apiPaymentData['paid_amounts'] as Map<String, double>);

    final bool hasPayment = paymentMethods.isNotEmpty;
    final List<Map<String, dynamic>> apiItems = [];

    for (final i in orderItems) {
      if (i.productData?.productId == null) {
        _showErrorMessage("Each item must have a valid product");
        return;
      }

      if (i.receive) {
        final receiveValidationError = _validateReceiveItemFields(i);
        if (receiveValidationError != null) {
          _showErrorMessage(receiveValidationError);
          return;
        }
      }

      final baseItem = <String, dynamic>{
        "product_id": i.productData?.productId,
        "quantity": double.tryParse(i.quantity) ?? 1,
        "unit_price": double.tryParse(i.purchaseRate) ?? 0,
        "receive": i.receive,
        if (i.expDate != null) "expiry_date": _formatDate(i.expDate!),
        if (i.barcode.isNotEmpty) "batch_number": i.barcode,
      };

      if (i.receive) {
        baseItem.addAll({
          "retail_price": double.tryParse(i.retailPrice) ?? 0,
          "wholesale_price": double.tryParse(i.wholesalePrice) ?? 0,
          "mrp": double.tryParse(i.mrp) ?? 0,
          "tax_include": i.taxInclude,
          "wholesale_min_unit": double.tryParse(i.wholesaleMinUnit) ?? 1,
          "unit": (i.selectedUnit != null && i.selectedUnit!.isNotEmpty)
              ? i.selectedUnit
              : i.unit,
          "rack": (i.selectedRack != null && i.selectedRack!.isNotEmpty)
              ? i.selectedRack
              : i.rack,
        });
      }

      apiItems.add(baseItem);
    }

    final token = Provider.of<AuthModel>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      _showErrorMessage("Session expired. Please login again.");
      return;
    }

    final provider = Provider.of<PurchaseProvider>(context, listen: false);

    try {
      if (mounted) {
        setState(() {
          _isSubmitting = true;
        });
      }

      final result = await provider.createPurchaseOrder(
        accessToken: token,
        purchaseDate: _formatDate(selectedDate),
        supplierId: selectedSupplier!.id.toString(),
        storeId: selectedStore!.id.toString(),
        voucherNumber: voucherNumberController.text,
        invoiceRef: invoiceRefController.text,
        paymentMethods: hasPayment ? paymentMethods : null,
        paidAmounts: hasPayment ? paidAmountsMap : null,
        items: apiItems,
      );

      if (result != null &&
          (result['status'] == 'success' ||
              result['status'] == true ||
              (result['message']
                      ?.toString()
                      .toLowerCase()
                      .contains('success') ??
                  false))) {
        await _clearDraftFromHive();
        _showSuccessMessage(result['message'] ?? "Purchase order created");

        await provider.listPurchaseOrders(
          accessToken: token,
          storeId: "all",
        );

        sideBarController.index.value = 81;
      } else {
        _showErrorMessage(result?['message'] ?? "Failed to create");
      }
    } catch (e) {
      _showErrorMessage("Failed to submit purchase order: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1))
          ],
        ),
        child: FocusTraversalGroup(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () => sideBarController.index.value = 81,
                    text: "Back to Purchase Orders",
                  ),
                  const SizedBox(height: 10),
                  Text("Create New Purchase Order",
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s20, 0.3, ColorManager.textColor)),
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildProductDetailsTitle(),
                  _buildItemForm(),
                  const SizedBox(height: 20),
                  _buildAddedItemsTable(),
                  const SizedBox(height: 20),
                  _buildItemsToReceivePreview(),
                  const SizedBox(height: 20),
                  _buildPaymentSection(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldColumn(String title, Widget child,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: title,
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s13,
                0.2, ColorManager.textColor),
            children: isRequired
                ? [
                    const TextSpan(
                        text: ' *', style: TextStyle(color: Colors.red))
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _buildHeader() {
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    return Column(
      children: [
        // Row 1
        Row(
          children: [
            Expanded(
              child: _buildFieldColumn(
                "Purchase Date",
                CalendarPickerTableCell(
                  onDateSelected: (date) {
                    setState(() => selectedDate = date);
                    _saveDraftToHive();
                  },
                  initialDate: selectedDate,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Voucher Number",
                _buildInlineField(voucherNumberController, "", (v) {}),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Store",
                BuildDropDownWithSearch<GetStoreModelData>(
                  title: null,
                  showName: false,
                  hintText: "Select Store",
                  value: selectedStore,
                  items: purchaseProvider.getStoreList ?? [],
                  onChanged: (val) {
                    setState(() => selectedStore = val);
                    _saveDraftToHive();
                  },
                  displayText: (val) => val.name ?? "",
                  searchController: storeSearchController,
                  height: 40,
                ),
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldColumn(
                    "Supplier",
                    BuildDropDownWithSearch<GetSuppliersModelData>(
                      title: null,
                      showName: false,
                      hintText: "Select Supplier",
                      value: selectedSupplier,
                      items: purchaseProvider.getSupplierList ?? [],
                      onChanged: (val) {
                        setState(() => selectedSupplier = val);
                        _saveDraftToHive();
                      },
                      displayText: (val) => val.user?.name ?? val.name ?? "",
                      searchController: supplierSearchController,
                      height: 40,
                    ),
                    isRequired: true,
                  ),
                  if (selectedSupplier != null) ...[
                    const SizedBox(height: 6),
                    _buildSupplierBalanceDisplay(),
                  ]
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Invoice Reference",
                _buildInlineField(invoiceRefController, "", (v) {}),
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildProductDetailsTitle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.30)),
      ),
      child: Text(
        "Product Details",
        style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14, 0.27,
            ColorManager.kPrimaryColor),
      ),
    );
  }

  Widget _buildItemForm() {
    final item = currentItem;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);

    return BuildBoxShadowContainer(
      circleRadius: 8,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact row like stock page
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${(_editingItemIndex ?? orderItems.length) + 1}',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s10, 0.2, Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildInlineField(
                  barcodeController,
                  "Barcode",
                  (v) => item.barcode = v,
                  onSubmitted: _autoFillFromBarcode,
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showAddProductModal(
                  barcode: item.barcode.trim().isEmpty ? null : item.barcode,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: BuildDropDownWithSearch<GetProduct>(
                  title: null,
                  showName: false,
                  hintText: "Select product",
                  value: item.productData,
                  items: localProductProvider.products
                      .where((p) =>
                          item.categoryData == null ||
                          p.categoryId == item.categoryData?.categoryId)
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _applyProductToCurrentItem(val);
                    }
                  },
                  displayText: (val) => val.productName ?? "",
                  searchController: productSearchController,
                  height: 40,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: _buildInlineField(quantityController, "1",
                    (v) => setState(() => item.quantity = v),
                    isNumber: true, focusNode: quantityFocusNode),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addItem,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _editingItemIndex != null ? Icons.check : Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() => _showItemDetails = !_showItemDetails);
                  _saveDraftToHive();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _showItemDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),

          if (_showItemDetails) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    "Category",
                    BuildDropDownWithSearch<Category>(
                      title: null,
                      showName: false,
                      hintText: "Select category",
                      value: item.categoryData,
                      items: categoryProvider.category ?? [],
                      onChanged: (val) {
                        setState(() => item.categoryData = val);
                        _saveDraftToHive();
                      },
                      displayText: (val) =>
                          val.categoryName ?? val.categorySlug ?? "Unknown",
                      searchController: categorySearchController,
                      height: 40,
                    ),
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child:
                      _buildFieldColumn("Unit", _buildUnitDropdownField(item)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    "Purchase Rate",
                    _buildInlineField(rateController, "0",
                        (v) => setState(() => item.purchaseRate = v),
                        isNumber: true, prefixText: '$_currency '),
                    isRequired: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Row 2: Retail price | Mrp | Expiry Date
            Row(
              children: [
                Expanded(
                  child: _buildFieldColumn(
                    "Retail price",
                    _buildInlineField(retailPriceController, "Retail price",
                        (v) {
                      setState(() {
                        item.retailPrice = v;
                      });
                    }, isNumber: true, prefixText: '$_currency '),
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    "Mrp",
                    _buildInlineField(mrpController, "MRP", (v) => item.mrp = v,
                        isNumber: true, prefixText: '$_currency '),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    "Expiry Date",
                    CalendarPickerTableCell(
                      onDateSelected: (date) {
                        setState(() => item.expDate = date);
                        _saveDraftToHive();
                      },
                      initialDate: item.expDate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Row 3: Wholesale price | Minimum Units for Wholesale | Rack
            Row(
              children: [
                Expanded(
                  child: _buildFieldColumn(
                    "Wholesale price",
                    _buildInlineField(
                        wholesalePriceController, "Wholesale price", (v) {
                      setState(() {
                        item.wholesalePrice = v;
                      });
                    }, isNumber: true, prefixText: '$_currency '),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    "Minimum Units for Wholesale",
                    _buildInlineField(
                        wholesaleMinUnitController,
                        "Enter minimum wholesale units",
                        (v) => item.wholesaleMinUnit = v,
                        isNumber: true),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildFieldColumn(
                    "Rack",
                    _buildRackDropdownField(item),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTaxDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineField(
      TextEditingController controller, String hint, Function(String) onChanged,
      {bool isNumber = false,
      String? prefixText,
      ValueChanged<String>? onSubmitted,
      TextInputAction textInputAction = TextInputAction.next,
      FocusNode? focusNode}) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(
        // Wrap with Center
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            onChanged(value);
            _saveDraftToHive();
          },
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: buildCustomStyle(
                FontWeightManager.medium, FontSize.s12, 0.2, Colors.grey),
            border: InputBorder.none,
            isCollapsed: true, // Replaces isDense and zero padding
          ),
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2,
              ColorManager.textColor),
        ),
      ),
    );
  }

  Widget _buildUnitDropdownField(PurchaseOrderItem item) {
    return Selector<PurchaseProvider, Map<String, String>?>(
      selector: (context, provider) => provider.getUnitList,
      shouldRebuild: (previous, current) => previous?.length != current?.length,
      builder: (context, unitList, child) {
        final unitKeys = unitList?.keys.toList() ?? <String>[];
        final selectedValue = item.selectedUnit ?? _resolveUnitKey(item.unit);

        return BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: "Select unit",
          value: unitKeys.contains(selectedValue) ? selectedValue : null,
          items: unitKeys,
          onChanged: (val) {
            setState(() {
              item.selectedUnit = val;
              item.unit = (val != null) ? (unitList?[val] ?? '') : '';
            });
            unitController.text = item.unit;
            _saveDraftToHive();
          },
          displayText: (val) => unitList?[val] ?? val,
          searchController: unitSearchController,
          height: 40,
        );
      },
    );
  }

  Widget _buildRackDropdownField(PurchaseOrderItem item) {
    return Selector<PurchaseProvider, Map<String, String>?>(
      selector: (context, provider) => provider.getMasterDataValues,
      shouldRebuild: (previous, current) => previous?.length != current?.length,
      builder: (context, rackList, child) {
        final rackKeys = rackList?.keys.toList() ?? <String>[];
        final selectedValue = item.selectedRack ??
            (rackKeys.contains(item.rack) ? item.rack : null);

        return BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: "Select rack",
          value: selectedValue,
          items: rackKeys,
          onChanged: (val) {
            setState(() {
              item.selectedRack = val;
              item.rack = (val != null) ? (rackList?[val] ?? val) : '';
            });
            rackController.text = item.rack;
            _saveDraftToHive();
          },
          displayText: (val) => rackList?[val] ?? val,
          searchController: rackSearchController,
          height: 40,
        );
      },
    );
  }

  Widget _buildTaxDetails() {
    double purchaseOrig = double.tryParse(currentItem.purchaseRate) ?? 0;
    double retailOrig = double.tryParse(currentItem.retailPrice) ?? 0;
    double wholeOrig = double.tryParse(currentItem.wholesalePrice) ?? 0;

    double pTax = 0;
    double rBase = retailOrig;
    double rTax = 0;
    double wBase = wholeOrig;
    double wTax = 0;

    if (includeTax) {
      final pBase = purchaseOrig / 1.15;
      pTax = purchaseOrig - pBase;
      rBase = retailOrig / 1.15;
      rTax = retailOrig - rBase;
      wBase = wholeOrig / 1.15;
      wTax = wholeOrig - wBase;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text("Tax Details",
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s14,
                    0.2, ColorManager.textColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: includeTax,
                        onChanged: (v) {
                          setState(() => includeTax = v);
                          _saveDraftToHive();
                        },
                        activeColor: Colors.blueAccent,
                      ),
                      Text("Including Tax",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Purchase Price + Tax",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                      const SizedBox(height: 5),
                      Text(
                          "${purchaseOrig.toStringAsFixed(2)} (Tax: ${pTax.toStringAsFixed(2)})",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey.shade700)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Retail Price + Tax",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                      const SizedBox(height: 5),
                      Text(
                          "${retailOrig.toStringAsFixed(2)} (Tax: ${rTax.toStringAsFixed(2)})",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey.shade700)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Wholesale Price + Tax",
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.2, ColorManager.textColor)),
                      const SizedBox(height: 5),
                      Text(
                          "${wholeOrig.toStringAsFixed(2)} (Tax: ${wTax.toStringAsFixed(2)})",
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s12, 0.2, Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTableTextField(
      TextEditingController controller, Function(String) onChanged,
      {double width = 80}) {
    return Container(
      width: width,
      height: 40, // Changed from 35 to 40 for consistency
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),

      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            onChanged(value);
            _saveDraftToHive();
          },
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.2,
              ColorManager.textColor),
        ),
      ),
    );
  }

  Widget _buildQtyField(PurchaseOrderItem item) {
    return Row(children: [
      InkWell(
        onTap: () {
          double current = double.tryParse(item.qtyCtrl.text) ?? 1;
          if (current > 1) {
            setState(() {
              item.qtyCtrl.text = (current - 1).toString();
              item.quantity = item.qtyCtrl.text;
              _syncPaidAmount();
            });
            _saveDraftToHive();
          }
        },
        child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: const Icon(Icons.remove, size: 14)),
      ),
      const SizedBox(width: 5),
      _buildTableTextField(item.qtyCtrl, (v) {
        setState(() {
          item.quantity = v;
          _syncPaidAmount();
        });
      }, width: 60),
      const SizedBox(width: 5),
      InkWell(
        onTap: () {
          double current = double.tryParse(item.qtyCtrl.text) ?? 1;
          setState(() {
            item.qtyCtrl.text = (current + 1).toString();
            item.quantity = item.qtyCtrl.text;
            _syncPaidAmount();
          });
          _saveDraftToHive();
        },
        child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: const Icon(Icons.add, size: 14)),
      ),
    ]);
  }

  Widget _buildAddedItemsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.30)),
          ),
          child: Text("Items Added",
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.27, ColorManager.kPrimaryColor)),
        ),
        const SizedBox(height: 8),
        if (orderItems.isEmpty)
          BuildBoxShadowContainer(
            circleRadius: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 50, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("No items added yet",
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.2, Colors.grey)),
                  ],
                ),
              ),
            ),
          )
        else
          BuildBoxShadowContainer(
            circleRadius: 8,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth > _purchaseTableMinWidth
                    ? constraints.maxWidth
                    : _purchaseTableMinWidth;

                return ScrollConfiguration(
                  behavior: _horizontalDragScrollBehavior,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          _buildPurchaseListHeader(),
                          const SizedBox(height: 4),
                          ...orderItems.asMap().entries.toList().reversed.map(
                                (e) => _buildPurchaseListRow(e.key, e.value),
                              ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPurchaseListHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildPurchaseListCell("Receive", width: 100, isHeader: true),
          _buildPurchaseListCell("Product", width: 220, isHeader: true),
          _buildPurchaseListCell("Unit", width: 120, isHeader: true),
          _buildPurchaseListCell("QTY", width: 100, isHeader: true),
          _buildPurchaseListCell("Purchase Price", width: 170, isHeader: true),
          _buildPurchaseListCell("Retail Price", width: 170, isHeader: true),
          _buildPurchaseListCell("MRP", width: 130, isHeader: true),
          _buildPurchaseListCell("Wholesale Price", width: 190, isHeader: true),
          _buildPurchaseListCell("Rack", width: 120, isHeader: true),
          _buildPurchaseListCell("Total", width: 130, isHeader: true),
          _buildPurchaseListCell("Actions", width: 170, isHeader: true),
        ],
      ),
    );
  }

  Widget _buildPurchaseListRow(int index, PurchaseOrderItem item) {
    final qty = double.tryParse(item.quantity) ?? 0;
    final purchaseRate = double.tryParse(item.purchaseRate) ?? 0;
    final retailPrice = double.tryParse(item.retailPrice) ?? 0;
    final mrp = double.tryParse(item.mrp) ?? 0;
    final wholesalePrice = double.tryParse(item.wholesalePrice) ?? 0;
    final total = qty * purchaseRate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildPurchaseListCell(
            "",
            width: 100,
            child: Checkbox(
              value: item.receive,
              onChanged: (value) {
                setState(() {
                  item.receive = value ?? false;
                  _syncPaidAmount();
                });
                _saveDraftToHive();
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productData?.productName ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s12, 0.2, ColorManager.textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  item.productData?.barcode ?? item.barcode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s10, 0.2, Colors.grey.shade600),
                ),
              ],
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 120,
            child: Text(item.unit,
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                    0.2, ColorManager.textColor)),
          ),
          _buildPurchaseListCell(
            "",
            width: 100,
            child: Text(
              qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Text(
              purchaseRate.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Text(
              retailPrice.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 130,
            child: Text(
              mrp.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 190,
            child: Text(
              wholesalePrice.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 120,
            child: Text(
              item.rack.isEmpty ? '-' : item.rack,
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 130,
            child: Text(
              total.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0.2, ColorManager.textColor),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.blueAccent, size: 18),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: () => _editItem(index),
                  tooltip: 'Edit item',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: () => _removeItem(index),
                  tooltip: 'Delete item',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseListCell(
    String title, {
    required double width,
    bool isHeader = false,
    Widget? child,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(
          child: child ??
              Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  isHeader
                      ? FontWeightManager.semiBold
                      : FontWeightManager.medium,
                  FontSize.s12,
                  0.2,
                  isHeader
                      ? ColorManager.kPrimaryColor
                      : ColorManager.textColor,
                ),
              ),
        ),
      ),
    );
  }

  double _getSupplierBalance() {
    return selectedSupplier?.currentBalance ?? 0.0;
  }

  Widget _buildSupplierBalanceDisplay() {
    final balance = _getSupplierBalance();
    final isToPay = balance > 0;
    final isToReceive = balance < 0;

    final textColor = isToPay
        ? Colors.red
        : isToReceive
            ? Colors.green
            : Colors.grey;

    final label = isToPay
        ? 'Amount to Pay'
        : isToReceive
            ? 'Amount to Receive'
            : 'No Balance';

    final icon = isToPay
        ? Icons.arrow_upward
        : isToReceive
            ? Icons.arrow_downward
            : Icons.balance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          '$label ${balance.abs().toStringAsFixed(2)}',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsToReceivePreview() {
    final receivedItems =
        orderItems.where((i) => i.receive).toList().reversed.toList();
    if (receivedItems.isEmpty) return const SizedBox.shrink();

    double totalAmt = 0;
    double totalQty = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.30)),
          ),
          child: Text("Items to Receive - Preview",
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.27, ColorManager.kPrimaryColor)),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          circleRadius: 8,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const baseRowWidth = 1300.0;
              const rowOuterInset = 32.0; // 8 margin + 8 padding on both sides
              final minTableWidth = baseRowWidth + rowOuterInset;
              final tableWidth = constraints.maxWidth > minTableWidth
                  ? constraints.maxWidth
                  : minTableWidth;
              final scale = (tableWidth - rowOuterInset) / baseRowWidth;

              double colWidth(double baseWidth) => baseWidth * scale;

              return ScrollConfiguration(
                behavior: _horizontalDragScrollBehavior,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _buildPurchaseListCell("Product",
                                  width: colWidth(230), isHeader: true),
                              _buildPurchaseListCell("Unit",
                                  width: colWidth(100), isHeader: true),
                              _buildPurchaseListCell("QTY",
                                  width: colWidth(100), isHeader: true),
                              _buildPurchaseListCell("Purchase Price",
                                  width: colWidth(170), isHeader: true),
                              _buildPurchaseListCell("Retail Price",
                                  width: colWidth(170), isHeader: true),
                              _buildPurchaseListCell("MRP",
                                  width: colWidth(130), isHeader: true),
                              _buildPurchaseListCell("Wholesale Price",
                                  width: colWidth(190), isHeader: true),
                              _buildPurchaseListCell("Rack",
                                  width: colWidth(100), isHeader: true),
                              _buildPurchaseListCell("Total",
                                  width: colWidth(110), isHeader: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...receivedItems.asMap().entries.map((entry) {
                          final item = entry.value;
                          final qty = double.tryParse(item.quantity) ?? 0;
                          final purchaseRate =
                              double.tryParse(item.purchaseRate) ?? 0;
                          final retailPrice =
                              double.tryParse(item.retailPrice) ?? 0;
                          final mrp = double.tryParse(item.mrp) ?? 0;
                          final wholesalePrice =
                              double.tryParse(item.wholesalePrice) ?? 0;
                          final rowTotal = qty * purchaseRate;

                          totalQty += qty;
                          totalAmt += rowTotal;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: entry.key.isEven
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(230),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productData?.productName ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s12,
                                            0.2,
                                            ColorManager.textColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.productData?.barcode ??
                                            item.barcode,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.2,
                                            Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(100),
                                  child: Text(item.unit,
                                      textAlign: TextAlign.center,
                                      style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.2,
                                          ColorManager.textColor)),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(100),
                                  child: Text(
                                    qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(170),
                                  child: Text(
                                    purchaseRate.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(170),
                                  child: Text(
                                    retailPrice.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(130),
                                  child: Text(
                                    mrp.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(190),
                                  child: Text(
                                    wholesalePrice.toStringAsFixed(3),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(100),
                                  child: Text(
                                    item.rack.isEmpty ? '-' : item.rack,
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(110),
                                  child: Text(
                                    rowTotal.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.2,
                                        ColorManager.textColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(230),
                                child: Text("Preview Total",
                                    style: buildCustomStyle(
                                        FontWeightManager.bold,
                                        FontSize.s13,
                                        0.2,
                                        ColorManager.textColor)),
                              ),
                              _buildPurchaseListCell("", width: colWidth(100)),
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(100),
                                child: Text(
                                  totalQty.toStringAsFixed(
                                      totalQty % 1 == 0 ? 0 : 2),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s13,
                                      0.2,
                                      ColorManager.textColor),
                                ),
                              ),
                              _buildPurchaseListCell("", width: colWidth(170)),
                              _buildPurchaseListCell("", width: colWidth(170)),
                              _buildPurchaseListCell("", width: colWidth(130)),
                              _buildPurchaseListCell("", width: colWidth(190)),
                              _buildPurchaseListCell("", width: colWidth(100)),
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(110),
                                child: Text(
                                  totalAmt.toStringAsFixed(2),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      FontSize.s13,
                                      0.2,
                                      ColorManager.textColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return BuildDynamicPaymentSelector(
      title: "Select Payment Method",
      paymentMethods: _paymentMethods,
      isLoading: _isLoadingPaymentMethods,
      initialData: paymentData,
      onPaymentChanged: (data) {
        setState(() {
          paymentData = data;
        });
        _saveDraftToHive();
      },
      showTotalAmount: true,
      maxMethods: 2,
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Total Amount",
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s12, 0.2, Colors.grey)),
            Text(
                "Order: $_currency ${totalAmount.toStringAsFixed(2)}\nReceive: $_currency ${totalReceivedAmount.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s15,
                    0.2, ColorManager.textColor)),
          ],
        ),
        const SizedBox(width: 30),
        Expanded(
          child: CustomRoundButton(
            title: "Finish",
            fct: _submitPurchaseOrder,
            width: 200,
            height: 45,
            fontSize: 12,
            isLoading: _isSubmitting,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _draftSaveDebouncer?.cancel();
    voucherNumberController.dispose();
    invoiceRefController.dispose();
    categorySearchController.dispose();
    productSearchController.dispose();
    barcodeController.dispose();
    quantityFocusNode.dispose();
    unitController.dispose();
    quantityController.dispose();
    rateController.dispose();
    retailPriceController.dispose();
    mrpController.dispose();
    wholesalePriceController.dispose();
    wholesaleMinUnitController.dispose();
    rackController.dispose();
    unitSearchController.dispose();
    rackSearchController.dispose();
    super.dispose();
  }
}
