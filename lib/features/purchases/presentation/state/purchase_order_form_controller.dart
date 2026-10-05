import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart'
    show DynamicPaymentData;
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';

import '../../data/purchase_order_draft_cache.dart';
import '../../domain/purchase_order_error_helpers.dart';
import '../../domain/purchase_order_item_helpers.dart';
import '../../domain/purchase_order_totals.dart';
import 'purchase_order_editable_item.dart';
import 'purchase_order_form_ports.dart';
part 'purchase_order_form_controller_1.dart';
part 'purchase_order_form_controller_2.dart';
part 'purchase_order_form_controller_3.dart';
part 'purchase_order_form_controller_4.dart';
part 'purchase_order_form_controller_5.dart';
part 'purchase_order_form_controller_6.dart';

class PurchaseOrderFormController extends ChangeNotifier {
  PurchaseOrderFormController(
      {required this.ports, PurchaseOrderDraftCache? cache})
      : cache = cache ?? PurchaseOrderDraftCache();
  final PurchaseOrderFormPorts ports;
  final PurchaseOrderDraftCache cache;
  bool _disposed = false;
  bool get mounted => !_disposed;
  void setState(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void initialize() {
    initDraftBox();
    loadInitialData();
  }

  PurchaseOrderDraftCache? draftBox;
  Timer? draftSaveDebouncer;
  bool isHydratingDraft = false;
  static const Duration draftSaveDelay = Duration(milliseconds: 500);

  // Header controllers
  final TextEditingController supplierSearchController =
      TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController voucherNumberController = TextEditingController();
  final TextEditingController invoiceRefController = TextEditingController();
  final TextEditingController discountController = TextEditingController(
    text: '0',
  );

  // Settings

  // Row controllers maps
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController productSearchController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
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
  final TextEditingController purchaseUnitSearchController =
      TextEditingController();
  final TextEditingController rackSearchController = TextEditingController();
  final ScrollController itemsTableScrollController = ScrollController();

  final Set<PurchaseOrderItem> ownedItems = {};
  List<PurchaseOrderItem> orderItems = [];
  PurchaseOrderItem currentItem = PurchaseOrderItem();
  bool includeTax = true;
  bool includeTaxPurchase = true;
  bool showItemDetails = false;
  int? editingItemIndex;

  // Dynamic payment methods (same as add stock page)
  DynamicPaymentData paymentData = DynamicPaymentData();
  List<MasterDataValue> paymentMethods = [];
  bool isLoadingPaymentMethods = false;
  bool isSubmitting = false;
  double? lastKnownNetPayable;
  // Payment disabled flag: true when the PO is already fully paid.
  // When true, payment inputs are hidden and omitted from the payload.
  bool isPaymentDisabled = false;

  GetStoreModelData? selectedStore;
  GetSuppliersModelData? selectedSupplier;
  DateTime selectedDate = DateTime.now();
  int?
      purchaseOrderId; // NEW! Track if we are editing/receiving an existing order

  Timer? taxCalcDebounceTimer;
  @override
  void dispose() {
    _disposed = true;
    draftSaveDebouncer?.cancel();
    taxCalcDebounceTimer?.cancel();
    itemsTableScrollController.dispose();
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
    supplierSearchController.dispose();
    storeSearchController.dispose();
    ownedItems.addAll(orderItems);
    ownedItems.add(currentItem);
    for (final item in ownedItems) {
      item.dispose();
    }
    super.dispose();
  }
}
