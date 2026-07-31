import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import 'package:pos_machine/screens/suppliers/add_supplier_modal.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/screens/purchase/helpers/purchase_order_totals.dart';
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
  bool alreadyReceived;
  Map<String, dynamic>? calculatedTaxData;

  bool receive;
  int? productVariantId;
  String? variantName;
  TextEditingController qtyCtrl;
  TextEditingController purchasePriceCtrl;
  TextEditingController retailPriceCtrl;
  TextEditingController mrpCtrl;
  TextEditingController wholesalePriceCtrl;

  SaleUnit? selectedPurchaseUnit;
  String? purchaseQty;
  String? purchaseConversionRate;

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
    this.taxInclude = true,
    this.calculatedTaxData,
    this.receive = false,
    this.alreadyReceived = false,
    this.id,
    this.productVariantId,
    this.variantName,
    this.selectedPurchaseUnit,
    this.purchaseQty,
    this.purchaseConversionRate,
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
  final TextEditingController discountController =
      TextEditingController(text: '0');

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
  final TextEditingController purchaseUnitSearchController = TextEditingController();
  final TextEditingController rackSearchController = TextEditingController();
  final ScrollController _itemsTableScrollController = ScrollController();

  List<PurchaseOrderItem> orderItems = [];
  PurchaseOrderItem currentItem = PurchaseOrderItem();
  bool includeTax = true;
  bool _showItemDetails = false;
  int? _editingItemIndex;

  // Dynamic payment methods (same as add stock page)
  DynamicPaymentData paymentData = DynamicPaymentData();
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  bool _isSubmitting = false;
  double? _lastKnownNetPayable;

  GetStoreModelData? selectedStore;
  GetSuppliersModelData? selectedSupplier;
  DateTime selectedDate = DateTime.now();
  int?
      purchaseOrderId; // NEW! Track if we are editing/receiving an existing order

  bool get _isReceiveMode => purchaseOrderId != null;
  bool get _isHeaderLockedForReceive => _isReceiveMode;

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
      'calculatedTaxData': item.calculatedTaxData,
      'receive': item.receive,
      'alreadyReceived': item.alreadyReceived,
      'selectedPurchaseUnit': item.selectedPurchaseUnit?.toJson(),
      'purchaseQty': item.purchaseQty,
      'purchaseConversionRate': item.purchaseConversionRate,
      'productVariantId': item.productVariantId,
      'variantName': item.variantName,
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

    final item = PurchaseOrderItem(
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
      alreadyReceived: map['alreadyReceived'] == true,
    );

    item.productVariantId = _toInt(map['productVariantId']);
    item.variantName = map['variantName']?.toString();

    if (map['selectedPurchaseUnit'] != null) {
      try {
        item.selectedPurchaseUnit = SaleUnit.fromJson(
            Map<String, dynamic>.from(map['selectedPurchaseUnit'] as Map));
      } catch (_) {}
    }
    item.purchaseQty = map['purchaseQty']?.toString();
    item.purchaseConversionRate = map['purchaseConversionRate']?.toString();

    return item
      ..calculatedTaxData = map['calculatedTaxData'] != null
          ? Map<String, dynamic>.from(map['calculatedTaxData'] as Map)
          : null
      ..syncControllers();
  }

  Widget _disableInteraction(Widget child, {required bool disabled}) {
    if (!disabled) return child;
    return Opacity(
      opacity: 0.7,
      child: IgnorePointer(
        ignoring: true,
        child: child,
      ),
    );
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
          'discount': discountController.text,
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
      discountController.text = draft['discount']?.toString() ?? '0';
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
          purchaseOrderId = _toInt(data['id']); // NEW! Capture the ID
          voucherNumberController.text =
              data['voucher_number']?.toString() ?? "";
          invoiceRefController.text = data['invoice_ref']?.toString() ?? "";
          discountController.text =
              data['discount']?.toString() ?? "0";
          if (data['purchase_date'] != null) {
            selectedDate =
                DateTime.tryParse(data['purchase_date'].toString()) ??
                    DateTime.now();
          }

          // Store
          if (data['store'] != null) {
            selectedStore = GetStoreModelData.fromJson(data['store']);
            storeSearchController.text = selectedStore?.name ?? "";
          }

          // Supplier
          if (data['supplier'] != null) {
            final supplierFromPayload =
                GetSuppliersModelData.fromJson(data['supplier']);
            final supplierId = supplierFromPayload.id;
            if (supplierId != null &&
                purchaseProvider.getSupplierList != null &&
                purchaseProvider.getSupplierList!.isNotEmpty) {
              try {
                selectedSupplier = purchaseProvider.getSupplierList!
                    .firstWhere((s) => s.id == supplierId);
              } catch (_) {
                selectedSupplier = supplierFromPayload;
              }
            } else {
              selectedSupplier = supplierFromPayload;
            }
            supplierSearchController.text = selectedSupplier?.name ?? "";
          }

          // Items - Support both 'items' (new list API) and 'purchase_items' (old/detail API)
          final itemsList = data['items'] ?? data['purchase_items'];
          if (itemsList != null) {
            orderItems = (itemsList as List).map((item) {
              final itemStatus =
                  (item['status'] ?? '').toString().trim().toUpperCase();
              final isAlreadyReceived = itemStatus == 'Y' ||
                  itemStatus == 'RECEIVED' ||
                  itemStatus == 'FULLY_RECEIVED';
              final unitPrice =
                  (item['unit_price'] ?? item['purchase_rate'] ?? '')
                      .toString();

              return PurchaseOrderItem(
                id: item['id'], // NEW! SET THE ITEM ID
                barcode: (item['bar_code'] ??
                        item['barcode'] ??
                        item['batch_number'] ??
                        '')
                    .toString(),

                quantity: item['quantity']?.toString() ?? "1",
                purchaseRate: unitPrice,
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
                retailPrice:
                    (item['retail_price'] ?? item['selling_price'] ?? unitPrice)
                        .toString(),
                mrp: (item['mrp'] ?? unitPrice).toString(),
                wholesalePrice:
                    (item['wholesale_price'] ?? unitPrice).toString(),
                wholesaleMinUnit: item['wholesale_min_unit']?.toString() ?? "",
                rack: item['rack']?.toString() ?? "",
                expDate: item['expiry_date'] != null
                    ? DateTime.tryParse(item['expiry_date'].toString())
                    : null,
                alreadyReceived: isAlreadyReceived,
                productVariantId: _toInt(item['product_variant_id']),
                variantName: item['variant_name']?.toString(),
              )
                ..receive = false
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
    includeTax = true;
  }

  void _editItem(int index) {
    if (index < 0 || index >= orderItems.length) return;
    final item = orderItems[index];

    if (_isReceiveMode && item.alreadyReceived) {
      _showErrorMessage("This item is already received and cannot be edited");
      return;
    }

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
        calculatedTaxData: item.calculatedTaxData != null
            ? Map<String, dynamic>.from(item.calculatedTaxData!)
            : null,
        receive: item.receive,
        alreadyReceived: item.alreadyReceived,
        productVariantId: item.productVariantId,
        variantName: item.variantName,
        selectedPurchaseUnit: item.selectedPurchaseUnit,
        purchaseQty: item.purchaseQty,
        purchaseConversionRate: item.purchaseConversionRate,
      )..syncControllers();

      barcodeController.text = currentItem.barcode;
      unitController.text = currentItem.unit;
      quantityController.text = currentItem.purchaseQty ?? currentItem.quantity;
      rateController.text = currentItem.purchaseRate;
      retailPriceController.text = currentItem.retailPrice;
      mrpController.text = currentItem.mrp;
      wholesalePriceController.text = currentItem.wholesalePrice;
      wholesaleMinUnitController.text = currentItem.wholesaleMinUnit;
      rackController.text = currentItem.rack;
      includeTax = currentItem.taxInclude;
      _showItemDetails = !(item.productData?.saleUnits != null &&
          item.productData!.saleUnits!.isNotEmpty);
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
      if (item.receive && !item.alreadyReceived) {
        double qty = double.tryParse(item.quantity) ?? 0;
        double rate = double.tryParse(item.purchaseRate) ?? 0;
        total += (qty * rate);
      }
    }
    return total;
  }

  double get _applicableGrossAmount =>
      _isReceiveMode ? totalReceivedAmount : totalAmount;

  double get _discountAmount => parsePurchaseAmount(discountController.text);

  PurchaseOrderTotals get _purchaseTotals => PurchaseOrderTotals(
        grossAmount: _applicableGrossAmount,
        discountAmount: _discountAmount,
      );

  PurchaseOrderTotals get _discountValidationTotals => PurchaseOrderTotals(
        grossAmount: totalAmount,
        discountAmount: _discountAmount,
      );

  void _syncPaidAmount() {
    final nextNetPayable = _purchaseTotals.netPayable;
    final previousNetPayable = _lastKnownNetPayable;
    _lastKnownNetPayable = nextNetPayable;

    final primaryMethod = paymentData.primaryMethod;
    if (primaryMethod == null ||
        paymentData.secondaryMethod != null ||
        previousNetPayable == null) {
      return;
    }

    final currentAmount = parsePurchaseAmount(paymentData.primaryAmount);
    final wasAutoFilled = (currentAmount - previousNetPayable).abs() <= 0.005;
    if (!wasAutoFilled) return;

    paymentData = DynamicPaymentData(
      primaryMethod: primaryMethod,
      primaryAmount: nextNetPayable.toStringAsFixed(2),
    );
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

  Widget _buildVariantSelector() {
    final product = currentItem.productData;
    if (product == null || !product.hasVariants) {
      return const SizedBox.shrink();
    }
    final variants = product.variants ?? [];
    final selected = variants.firstWhereOrNull(
        (v) => v.id == currentItem.productVariantId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Select Variant *',
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildDropDownWithSearch<ProductVariant>(
          title: null,
          hintText: 'Select product variant',
          value: selected,
          items: variants,
          onChanged: (variant) {
            setState(() {
              currentItem.productVariantId = variant?.id;
              currentItem.variantName = variant != null
                  ? _variantLabel(variant)
                  : null;
              if (currentItem.productData?.saleUnits != null &&
                  currentItem.productData!.saleUnits!.isNotEmpty) {
                _showItemDetails = false;
              }
              if (variant != null) {
                if (variant.barcode != null && variant.barcode!.isNotEmpty) {
                  currentItem.barcode = variant.barcode!;
                  barcodeController.text = variant.barcode!;
                }
                if (variant.purchasePrice != null) {
                  rateController.text = variant.purchasePrice.toString();
                  currentItem.purchaseRate = variant.purchasePrice.toString();
                } else if (variant.price != null) {
                  rateController.text = variant.price.toString();
                  currentItem.purchaseRate = variant.price.toString();
                }
                if (variant.mrp != null) {
                  mrpController.text = variant.mrp.toString();
                  currentItem.mrp = variant.mrp.toString();
                }
              } else {
                currentItem.barcode = currentItem.productData?.barcode ?? '';
                barcodeController.text = currentItem.barcode;
              }
            });
            _triggerTaxRecalculation();
          },
          displayText: _variantLabel,
          isRequired: true,
        ),
      ],
    );
  }

  String _variantLabel(ProductVariant v) {
    final parts = <String>[];
    if (v.attributes != null) {
      v.attributes!.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          parts.add(value.toString());
        }
      });
    }
    return parts.isNotEmpty ? parts.join(' | ') : 'Variant ${v.id}';
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
    // final itemName = item.productData?.productName ?? 'Selected item';

    // if ((double.tryParse(item.retailPrice) ?? 0) <= 0) {
    //   return "$itemName: retail price is required";
    // }
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

  void _selectPurchaseUnit(SaleUnit? unit) {
    setState(() {
      currentItem.selectedPurchaseUnit = unit;
      currentItem.purchaseConversionRate =
          unit?.conversionRate?.toString();
      _syncQtyFromPurchaseUnit();
      if (unit != null) {
        _showItemDetails = false;
      }
    });
  }

  void _syncQtyFromPurchaseUnit() {
    final unit = currentItem.selectedPurchaseUnit;
    final qtyText = quantityController.text.trim();
    if (unit == null) {
      currentItem.purchaseQty = null;
      currentItem.quantity = qtyText;
      return;
    }
    currentItem.purchaseQty = qtyText;
    final purchaseQty = double.tryParse(qtyText) ?? 1.0;
    final conversionRate = double.tryParse(
        unit.conversionRate ?? '1') ?? 1.0;
    final baseQty = purchaseQty * conversionRate;
    final qtyStr = baseQty.toStringAsFixed(baseQty.truncateToDouble() == baseQty ? 0 : 3);
    setState(() {
      currentItem.quantity = qtyStr;
    });
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
      currentItem.productVariantId = null;
      currentItem.variantName = null;
      currentItem.selectedPurchaseUnit = null;
      currentItem.purchaseQty = null;
      currentItem.purchaseConversionRate = null;
      if (product.saleUnits != null && product.saleUnits!.isNotEmpty) {
        _showItemDetails = false;
      }
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
    _triggerTaxRecalculation();
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

    final isReceiveMode = _isReceiveMode;

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

    final purchaseTotals = _purchaseTotals;

    final apiPaymentData = _convertPaymentDataToPurchaseApiFormat(paymentData);
    final List<String> paymentMethods =
        (apiPaymentData['payment_methods'] as List<String>);
    final Map<String, double> paidAmountsMap =
        (apiPaymentData['paid_amounts'] as Map<String, double>);

    final bool hasPayment = paymentMethods.isNotEmpty;
    final paidAmount =
        paidAmountsMap.values.fold<double>(0, (sum, amount) => sum + amount);
    final List<Map<String, dynamic>> apiItems = [];

    for (final i in orderItems) {
      if (isReceiveMode && i.alreadyReceived) {
        continue;
      }

      if (isReceiveMode && !i.receive) {
        continue;
      }

      if (!isReceiveMode && i.productData?.productId == null) {
        _showErrorMessage("Each item must have a valid product");
        return;
      }

      if (i.receive || isReceiveMode) {
        final receiveValidationError = _validateReceiveItemFields(i);
        if (receiveValidationError != null) {
          _showErrorMessage(receiveValidationError);
          return;
        }
      }

      if (isReceiveMode) {
        final receiveItem = <String, dynamic>{
          "purchase_item_id": i.id,
          "quantity": double.tryParse(i.quantity) ?? 1,
          "unit_price": double.tryParse(i.purchaseRate) ?? 0,
          "retail_price": double.tryParse(i.retailPrice) ?? 0,
          "wholesale_price": double.tryParse(i.wholesalePrice) ?? 0,
          "mrp": double.tryParse(i.mrp) ?? 0,
          "tax_include": i.taxInclude,
          "wholesale_min_unit": double.tryParse(i.wholesaleMinUnit) ?? 1,
          "tax_amount_retail": i.calculatedTaxData?['retailTaxAmount'],
          "tax_amount_wholesale": i.calculatedTaxData?['wholesaleTaxAmount'],
          "tax_amount_purchase": i.calculatedTaxData?['purchaseTaxAmount'],
          "retail_price_tax":
              i.calculatedTaxData?['price_including_tax_retail'],
          "wholesale_price_tax":
              i.calculatedTaxData?['price_including_tax_wholesale'],
          "purchase_price_tax":
              i.calculatedTaxData?['price_including_tax_purchase'],
        };

        final selectedRack =
            (i.selectedRack != null && i.selectedRack!.isNotEmpty)
                ? i.selectedRack!
                : i.rack;
        if (selectedRack.isNotEmpty) {
          receiveItem["rack"] = selectedRack;
        }

        if (i.expDate != null) {
          receiveItem["expiry_date"] = _formatDate(i.expDate!);
        }

        if (i.barcode.isNotEmpty) {
          receiveItem["batch_number"] = i.barcode;
        }

        apiItems.add(receiveItem);
        continue;
      }

      final variantId = i.productVariantId ?? i.productData?.matchedVariantId;
      final baseItem = <String, dynamic>{
        "product_id": i.productData?.productId,
        if (variantId != null) "product_variant_id": variantId,
        "quantity": double.tryParse(i.quantity) ?? 1,
        "unit_price": double.tryParse(i.purchaseRate) ?? 0,
        "receive": i.receive,
        if (i.expDate != null) "expiry_date": _formatDate(i.expDate!),
        if (i.barcode.isNotEmpty) "batch_number": i.barcode,
        if (i.selectedPurchaseUnit != null) ...{
          "purchase_unit_id": i.selectedPurchaseUnit!.id,
          "purchase_qty": double.tryParse(i.purchaseQty ?? '1') ?? 1.0,
        },
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
          "tax_amount_retail": i.calculatedTaxData?['retailTaxAmount'],
          "tax_amount_wholesale": i.calculatedTaxData?['wholesaleTaxAmount'],
          "tax_amount_purchase": i.calculatedTaxData?['purchaseTaxAmount'],
          "retail_price_tax":
              i.calculatedTaxData?['price_including_tax_retail'],
          "wholesale_price_tax":
              i.calculatedTaxData?['price_including_tax_wholesale'],
          "purchase_price_tax":
              i.calculatedTaxData?['price_including_tax_purchase'],
        });
      }

      apiItems.add(baseItem);
    }

    if (isReceiveMode && apiItems.isEmpty) {
      _showErrorMessage("Please select at least one pending item to receive");
      return;
    }

    final discountValidationMessage = _discountValidationTotals.discountValidationMessage;
    if (discountValidationMessage != null) {
      _showErrorMessage(discountValidationMessage);
      return;
    }

    final paymentValidationMessage =
        purchaseTotals.validatePaymentAmount(paidAmount);
    if (hasPayment && paymentValidationMessage != null) {
      _showErrorMessage(paymentValidationMessage);
      return;
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

      final result = isReceiveMode
          ? await provider.receivePurchaseOrder(
              accessToken: token,
              purchaseId: purchaseOrderId.toString(),
              invoiceRef: invoiceRefController.text.trim().isEmpty
                  ? null
                  : invoiceRefController.text.trim(),
              discount: purchaseTotals.discountAmount,
              paymentMethods: hasPayment ? paymentMethods : null,
              paidAmounts: hasPayment ? paidAmountsMap : null,
              items: apiItems,
            )
          : await provider.createPurchaseOrder(
              accessToken: token,
              purchaseDate: _formatDate(selectedDate),
              supplierId: selectedSupplier!.id.toString(),
              storeId: selectedStore!.id.toString(),
              voucherNumber: voucherNumberController.text,
              invoiceRef: invoiceRefController.text,
              discount: purchaseTotals.discountAmount,
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
        _showSuccessMessage(result['message'] ??
            (isReceiveMode
                ? "Purchase order received"
                : "Purchase order created"));

        await provider.listPurchaseOrders(
          accessToken: token,
          storeId: "all",
        );

        provider.activePurchaseOrderDetails = null;

        sideBarController.index.value = 81;
      } else {
        _showErrorMessage(result?['message'] ??
            (isReceiveMode ? "Failed to receive items" : "Failed to create"));
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
                  Text(
                      _isReceiveMode
                          ? "Receive Purchase Order"
                          : "Create New Purchase Order",
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
                _disableInteraction(
                  CalendarPickerTableCell(
                    onDateSelected: (date) {
                      setState(() => selectedDate = date);
                      _saveDraftToHive();
                    },
                    initialDate: selectedDate,
                  ),
                  disabled: _isHeaderLockedForReceive,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Voucher Number",
                _buildInlineField(voucherNumberController, "", (v) {},
                    readOnly: _isHeaderLockedForReceive),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildFieldColumn(
                "Store",
                _disableInteraction(
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
                  disabled: _isHeaderLockedForReceive,
                ),
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Row 2
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldColumn(
                    "Supplier",
                    _disableInteraction(
                      Row(
                        children: [
                          Expanded(
                            child:
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
                              displayText: (val) =>
                                  val.user?.name ?? val.name ?? "",
                              searchController: supplierSearchController,
                              height: 40,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add Supplier Button
                          BuildBoxShadowContainer(
                            height: 40,
                            width: 40,
                            circleRadius: 5,
                            child: InkWell(
                              onTap: () async {
                                final size = MediaQuery.of(context).size;
                                final result = await showAddSupplierModal(
                                    context, size,
                                    showCreateAnother: false);
                                if (result != null &&
                                    result is Map &&
                                    result['status'] == 'success') {
                                  final createdPhone =
                                      (result['phone'] ?? '').toString();
                                  try {
                                    final String? accessToken =
                                        Provider.of<AuthModel>(context,
                                                listen: false)
                                            .token;
                                    if (accessToken != null) {
                                      await purchaseProvider.listAllSuppliers(
                                          accessToken, null);
                                      final updatedList =
                                          purchaseProvider.getSupplierList ??
                                              [];
                                      if (updatedList.isNotEmpty) {
                                        try {
                                          final newSupplier =
                                              updatedList.firstWhere(
                                            (s) =>
                                                s.phone == createdPhone ||
                                                (s.user?.phone == createdPhone),
                                          );
                                          setState(() {
                                            selectedSupplier = newSupplier;
                                          });
                                          _saveDraftToHive();
                                        } catch (_) {
                                          debugPrint(
                                              'New supplier not found by phone in refreshed list');
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint(
                                        'Error auto-selecting new supplier: $e');
                                  }
                                }
                              },
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 27,
                                  color: ColorManager.kButtonGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      disabled: _isHeaderLockedForReceive,
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
                _buildInlineField(invoiceRefController, "", (v) {},
                    readOnly: _isHeaderLockedForReceive),
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
        _isReceiveMode ? "Pending Item Editor" : "Product Details",
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
                child: _buildInlineField(quantityController,
                    item.selectedPurchaseUnit != null ? "P. Qty" : "1",
                    (v) {
                      setState(() {
                        if (item.selectedPurchaseUnit != null) {
                          _syncQtyFromPurchaseUnit();
                        } else {
                          item.quantity = v;
                        }
                      });
                    },
                    isNumber: true,
                    focusNode: quantityFocusNode,
                    inputFormatters: quantityInputFormattersForUnit(item.unit)),
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
          if (currentItem.productData?.hasVariants == true)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: _buildVariantSelector(),
            ),
          if (currentItem.productData?.saleUnits != null &&
              currentItem.productData!.saleUnits!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: _buildPurchaseUnitSelector(),
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
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    "Unit",
                    _buildUnitDropdownField(item),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: _buildFieldColumn(
                    "Purchase Rate",
                    _buildInlineField(rateController, "0", (v) {
                      setState(() => item.purchaseRate = v);
                      _triggerTaxRecalculation();
                    }, isNumber: true, prefixText: '$_currency '),
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
                      _triggerTaxRecalculation();
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
                      _triggerTaxRecalculation();
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
                        isNumber: true,
                        inputFormatters:
                            quantityInputFormattersForUnit(item.unit)),
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
      FocusNode? focusNode,
      List<TextInputFormatter>? inputFormatters,
      bool readOnly = false}) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Center(
        // Wrap with Center
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onChanged: (value) {
            onChanged(value);
            _saveDraftToHive();
          },
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: inputFormatters,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
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
    final baseUnitName = item.productData?.unit ?? item.unit;
    return BuildBoxShadowContainer(
      circleRadius: 7,
      height: 40,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        baseUnitName.isNotEmpty ? baseUnitName : "-",
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.27,
          Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPurchaseUnitSelector() {
    final saleUnits = currentItem.productData?.saleUnits ?? <SaleUnit>[];
    final selectedUnit = currentItem.selectedPurchaseUnit;

    // Auto-calculate stock qty:
    final purchaseQty = double.tryParse(quantityController.text.trim()) ?? 1.0;
    final conversionRate = double.tryParse(selectedUnit?.conversionRate ?? '1') ?? 1.0;
    final calculatedStockQty = purchaseQty * conversionRate;
    final stockQtyStr = calculatedStockQty.toStringAsFixed(calculatedStockQty.truncateToDouble() == calculatedStockQty ? 0 : 3);
    final baseUnitName = currentItem.productData?.unit ?? currentItem.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Select Purchase Unit',
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        BuildDropDownWithSearch<SaleUnit>(
          title: null,
          hintText: 'Select purchase unit',
          value: selectedUnit,
          items: saleUnits,
          onChanged: (val) {
            _selectPurchaseUnit(val);
          },
          displayText: (val) => "${val.unitName} (x${val.conversionRate})",
          searchController: purchaseUnitSearchController,
          height: 40,
        ),
        if (selectedUnit != null) ...[
          const SizedBox(height: 4),
          Text(
            "Stock Qty: $stockQtyStr ${baseUnitName.isNotEmpty ? baseUnitName : 'PC'}",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.2,
              Colors.grey.shade600,
            ),
          ),
        ],
      ],
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

  /// Debounce timer for tax calculation
  Timer? _taxCalcDebounceTimer;

  /// Calculate tax for the current item using the server API (same as stock page)
  Future<void> _calculateTaxForCurrentItem(
      {bool isRetail = true, bool isPurchase = false}) async {
    final item = currentItem;
    final String calculationType =
        isPurchase ? 'Purchase' : (isRetail ? 'Retail' : 'Wholesale');

    if (item.productData == null ||
        item.categoryData == null ||
        item.productData!.productId == null ||
        item.categoryData!.categoryId == null) {
      debugPrint(
          '⚠️ [PurchaseTax] Cannot calculate: product/category missing | type=$calculationType');
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isPurchase) {
            item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
            item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
          } else if (isRetail) {
            item.calculatedTaxData!['retailTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_retail'] = 0.0;
            item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
          } else {
            item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
            item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
          }
        });
      }
      return;
    }

    final double priceToCalculate = isPurchase
        ? (double.tryParse(item.purchaseRate) ?? 0.0)
        : (isRetail
            ? (double.tryParse(item.retailPrice) ?? 0.0)
            : (double.tryParse(item.wholesalePrice) ?? 0.0));

    debugPrint(
        '🧮 [PurchaseTax] Payload | type=$calculationType | productId=${item.productData!.productId} | categoryId=${item.categoryData!.categoryId} | price=$priceToCalculate | taxInclude=$includeTax');

    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null) {
      debugPrint('❌ [PurchaseTax] No access token');
      return;
    }

    try {
      final taxData = await Provider.of<StockProvider>(context, listen: false)
          .calculateTaxAPI(
        accessToken: accessToken,
        price: priceToCalculate,
        productId: item.productData!.productId!,
        categoryId: item.categoryData!.categoryId!,
        taxInclude: includeTax,
      );

      if (taxData != null && mounted) {
        debugPrint(
            '✅ [PurchaseTax] API success | type=$calculationType | response=$taxData');
        setState(() {
          if (isPurchase) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'purchaseTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_purchase':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_purchase':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_purchase':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else if (isRetail) {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'retailTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_retail':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_retail':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_retail':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          } else {
            item.calculatedTaxData = {
              ...?item.calculatedTaxData,
              'wholesaleTaxAmount':
                  (taxData['tax_amount'] as num?)?.toDouble() ?? 0.0,
              'tax_rate_wholesale':
                  (taxData['tax_rate'] as num?)?.toDouble() ?? 0.0,
              'price_including_tax_wholesale':
                  (taxData['price_including_tax'] as num?)?.toDouble() ?? 0.0,
              'price_excluding_tax_wholesale':
                  (taxData['price_excluding_tax'] as num?)?.toDouble() ?? 0.0,
            };
          }
        });
      } else {
        debugPrint('❌ [PurchaseTax] API returned null | type=$calculationType');
        if (mounted) {
          setState(() {
            item.calculatedTaxData ??= {};
            if (isPurchase) {
              item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
              item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
            } else if (isRetail) {
              item.calculatedTaxData!['retailTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_retail'] = 0.0;
              item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
            } else {
              item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
              item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
              item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
              item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
            }
          });
        }
      }
    } catch (e) {
      debugPrint(
          '💥 [PurchaseTax] Exception | type=$calculationType | error=$e');
      if (mounted) {
        setState(() {
          item.calculatedTaxData ??= {};
          if (isPurchase) {
            item.calculatedTaxData!['purchaseTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_purchase'] = 0.0;
            item.calculatedTaxData!['price_including_tax_purchase'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_purchase'] = 0.0;
          } else if (isRetail) {
            item.calculatedTaxData!['retailTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_retail'] = 0.0;
            item.calculatedTaxData!['price_including_tax_retail'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_retail'] = 0.0;
          } else {
            item.calculatedTaxData!['wholesaleTaxAmount'] = 0.0;
            item.calculatedTaxData!['tax_rate_wholesale'] = 0.0;
            item.calculatedTaxData!['price_including_tax_wholesale'] = 0.0;
            item.calculatedTaxData!['price_excluding_tax_wholesale'] = 0.0;
          }
        });
      }
    }
  }

  /// Trigger all three tax calculations for the current item (debounced)
  void _triggerTaxRecalculation() {
    _taxCalcDebounceTimer?.cancel();
    _taxCalcDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _calculateTaxForCurrentItem(isRetail: true);
      _calculateTaxForCurrentItem(isRetail: false);
      _calculateTaxForCurrentItem(isPurchase: true);
    });
  }

  Widget _buildTaxDetails() {
    final item = currentItem;
    final retailInclusive =
        (item.calculatedTaxData?['price_including_tax_retail'] as num?)
                ?.toDouble() ??
            0.0;
    final retailExclusive =
        (item.calculatedTaxData?['price_excluding_tax_retail'] as num?)
                ?.toDouble() ??
            0.0;
    final retailTax =
        (item.calculatedTaxData?['retailTaxAmount'] as num?)?.toDouble() ?? 0.0;
    final wholesaleInclusive =
        (item.calculatedTaxData?['price_including_tax_wholesale'] as num?)
                ?.toDouble() ??
            0.0;
    final wholesaleExclusive =
        (item.calculatedTaxData?['price_excluding_tax_wholesale'] as num?)
                ?.toDouble() ??
            0.0;
    final wholesaleTax =
        (item.calculatedTaxData?['wholesaleTaxAmount'] as num?)?.toDouble() ??
            0.0;
    final purchaseInclusive =
        (item.calculatedTaxData?['price_including_tax_purchase'] as num?)
                ?.toDouble() ??
            0.0;
    final purchaseExclusive =
        (item.calculatedTaxData?['price_excluding_tax_purchase'] as num?)
                ?.toDouble() ??
            0.0;
    final purchaseTax =
        (item.calculatedTaxData?['purchaseTaxAmount'] as num?)?.toDouble() ??
            0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Tax toggle
            Expanded(
              flex: 1,
              child: Container(
                height: 80,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        "Including Tax",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s12,
                          0.27,
                          Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: includeTax,
                        onChanged: (bool value) {
                          setState(() {
                            includeTax = value;
                          });
                          _triggerTaxRecalculation();
                          _saveDraftToHive();
                        },
                        activeThumbColor: ColorManager.kPrimaryColor,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                "Retail Price",
                "1",
                includeTax
                    ? retailInclusive.toStringAsFixed(2)
                    : retailExclusive.toStringAsFixed(2),
                'Tax: ${(item.calculatedTaxData?['tax_rate_retail'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}%',
                'Base: ${retailExclusive.toStringAsFixed(2)} + Tax: ${retailTax.toStringAsFixed(2)}',
                retailTax,
                Colors.blue,
                includeTax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                "Wholesale Price",
                "2",
                includeTax
                    ? wholesaleInclusive.toStringAsFixed(2)
                    : wholesaleExclusive.toStringAsFixed(2),
                'Tax: ${(item.calculatedTaxData?['tax_rate_wholesale'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}%',
                'Base: ${wholesaleExclusive.toStringAsFixed(2)} + Tax: ${wholesaleTax.toStringAsFixed(2)}',
                wholesaleTax,
                Colors.orange,
                includeTax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                "Purchase Rate",
                "3",
                includeTax
                    ? purchaseInclusive.toStringAsFixed(2)
                    : purchaseExclusive.toStringAsFixed(2),
                'Tax: ${(item.calculatedTaxData?['tax_rate_purchase'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"}%',
                'Base: ${purchaseExclusive.toStringAsFixed(2)} + Tax: ${purchaseTax.toStringAsFixed(2)}',
                purchaseTax,
                Colors.green,
                includeTax,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxCard(
    String title,
    String badgeText,
    String priceText,
    String taxText,
    String breakdownText,
    double taxAmount,
    Color color,
    bool isIncluding,
  ) {
    // When tax is NOT included, show price + tax amount in big font
    final displayPrice = !isIncluding
        ? '${priceText} + ${taxAmount.toStringAsFixed(2)}'
        : priceText;

    return Container(
      height: 80,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge + Title + Tax%
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badgeText,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s10,
                      0.27,
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.27,
                    color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                taxText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.2,
                  color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Main Price + Breakdown in same line
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  displayPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.27,
                    Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isIncluding ? '($breakdownText)' : '(${taxText})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.2,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTextField(
      TextEditingController controller, Function(String) onChanged,
      {double width = 80, List<TextInputFormatter>? inputFormatters}) {
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
          inputFormatters: inputFormatters,
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
      }, width: 60, inputFormatters: quantityInputFormattersForUnit(item.unit)),
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
    final visibleItems = _isReceiveMode
        ? orderItems.where((i) => !i.alreadyReceived).toList()
        : orderItems;

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
        if (visibleItems.isEmpty)
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
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    controller: _itemsTableScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _itemsTableScrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          children: [
                            _buildPurchaseListHeader(),
                            const SizedBox(height: 4),
                            ...visibleItems.asMap().entries.toList().reversed.map(
                                  (e) => _buildPurchaseListRow(e.key, e.value),
                                ),
                          ],
                        ),
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
    final canEdit = !_isReceiveMode || !item.alreadyReceived;
    final canDelete = !_isReceiveMode && !item.alreadyReceived;

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
            child: item.alreadyReceived
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8EC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF43A95D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(
                          "Received",
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s11,
                            0.2,
                            const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  )
                : Checkbox(
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
                if (item.variantName != null && item.variantName!.isNotEmpty)
                  Text(
                    item.variantName!.contains(' - ')
                        ? item.variantName!.split(' - ').last
                        : item.variantName!,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s10,
                      0.15,
                      Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  item.barcode.isNotEmpty ? item.barcode : (item.productData?.barcode ?? ''),
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
                  icon: Icon(Icons.edit_outlined,
                      color: canEdit ? Colors.blueAccent : Colors.grey,
                      size: 18),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: canEdit ? () => _editItem(index) : null,
                  tooltip: canEdit ? 'Edit item' : 'Already received item',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: canDelete ? Colors.red : Colors.grey, size: 20),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: canDelete ? () => _removeItem(index) : null,
                  tooltip: canDelete
                      ? 'Delete item'
                      : (_isReceiveMode
                          ? 'Delete is disabled in receive mode'
                          : 'Already received item'),
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
    final receivedItems = orderItems
        .where((i) => i.receive && !i.alreadyReceived)
        .toList()
        .reversed
        .toList();
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
                                      if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.variantName!.contains(' - ')
                                              ? item.variantName!.split(' - ').last
                                              : item.variantName!,
                                          style: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s10,
                                            0.15,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        item.barcode.isNotEmpty ? item.barcode : (item.productData?.barcode ?? ''),
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
          _lastKnownNetPayable = _purchaseTotals.netPayable;
        });
        _saveDraftToHive();
      },
      showTotalAmount: true,
      expectedAmount: _purchaseTotals.netPayable,
      allowPartialPayment: true,
      maxMethods: 2,
    );
  }

  Widget _buildFooter() {
    final totals = _purchaseTotals;
    final discountValidationMessage = _discountValidationTotals.discountValidationMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuildBoxShadowContainer(
          circleRadius: 8,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildTotalSummaryRow("Gross Total", totals.grossAmount),
              const SizedBox(height: 8),
              _buildDiscountSummaryRow(),
              const Divider(height: 20),
              _buildTotalSummaryRow(
                "Net Payable",
                totals.netPayable,
                valueColor: ColorManager.kPrimaryColor,
                emphasize: true,
              ),
              if (discountValidationMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    discountValidationMessage,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s11,
                      0.2,
                      Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomRoundButton(
          title: _isReceiveMode ? "Receive Items" : "Finish",
          fct: _submitPurchaseOrder,
          width: double.infinity,
          height: 45,
          fontSize: 12,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildDiscountSummaryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Overall Discount",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.2,
            Colors.grey.shade700,
          ),
        ),
        SizedBox(
          width: 180,
          child: _buildInlineField(
            discountController,
            "0.00",
            (value) => setState(_syncPaidAmount),
            isNumber: true,
            prefixText: '$_currency ',
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,2}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummaryRow(
    String label,
    double amount, {
    Color? valueColor,
    bool emphasize = false,
    String prefix = '',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.medium,
            emphasize ? FontSize.s15 : FontSize.s12,
            0.2,
            emphasize ? ColorManager.textColor : Colors.grey.shade700,
          ),
        ),
        Text(
          '$prefix$_currency ${amount.toStringAsFixed(2)}',
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.semiBold,
            emphasize ? FontSize.s18 : FontSize.s13,
            0.2,
            valueColor ?? ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _draftSaveDebouncer?.cancel();
    _taxCalcDebounceTimer?.cancel();
    _itemsTableScrollController.dispose();
    voucherNumberController.dispose();
    invoiceRefController.dispose();
    discountController.dispose();
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
    purchaseUnitSearchController.dispose();
    rackSearchController.dispose();
    super.dispose();
  }
}
