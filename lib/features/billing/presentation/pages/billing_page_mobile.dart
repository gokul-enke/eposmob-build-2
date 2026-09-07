import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/features/billing/domain/barcode_scan_queue.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/billing_status_header.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/payment_methods_sheet.dart';
import 'package:pos_machine/services/checkout_service.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/mobile_bottom_nav.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders_tab.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page.dart';
import 'package:pos_machine/features/billing/presentation/widgets/pos_security_key_dialog.dart';

import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart_tab.dart';

class BillingPageMobile extends StatefulWidget {
  final BillingPageMode mode;

  const BillingPageMobile({super.key, this.mode = BillingPageMode.normal});

  @override
  State<BillingPageMobile> createState() => BillingPageMobileState();
}

class BillingPageMobileState extends State<BillingPageMobile>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Bottom navigation
  int _currentTabIndex = 0;
  late TabController _tabController;

  // Keys for autocomplete widgets
  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  final FocusNode _focusNode = FocusNode();
  StreamSubscription<String>? _barcodeSubscription;
  String? _lastRehydratedOrderId;
  bool _isSavingOrder = false;
  bool _isConfirmingOrder = false;
  bool _isConfirmingAndPrinting = false;
  bool _isLoadingOrder = false;
  bool _isClearingCart = false;
  bool _isSavingAndPrinting = false;
  bool _isCreatingNewOrder = false;

  bool get _isQuotationPage => widget.mode == BillingPageMode.quotation;

  bool get _skipCheckoutOnConfirmAndPrint {
    if (_isQuotationPage) return false;
    return Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.skipCheckoutOnConfirmAndPrint ??
        false;
  }

  bool get _showConfirmOrderButton {
    return Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.showConfirmOrderButton ??
        true;
  }

  bool get _showConfirmOrderAndPrintButton {
    return Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.showConfirmOrderAndPrintButton ??
        true;
  }

  DateTime _quotationDate = DateTime.now();
  DateTime _quotationExpiryDate = DateTime.now().add(const Duration(days: 30));
  late final TextEditingController _quotationInlineNameController;
  late final TextEditingController _quotationInlinePhoneController;

  VoidCallback? _cartChangeListener;

  /// Business logic (restore/rehydration, etc.) lives here; the page keeps only
  /// UI orchestration.
  final BillingMobileController _controller = BillingMobileController();
  static const _customerController = BillingMobileCustomerController();
  static const _paymentController = BillingMobilePaymentController();
  static const _settingsController = BillingMobileSettingsController();
  static const _connectivityController = BillingMobileConnectivityController();

  VoidCallback? _generalSettingsListener;
  VoidCallback? _appSettingsSyncListener;
  VoidCallback? _deliveryMethodSyncListener;
  VoidCallback? _localProductOrderListener;
  VoidCallback? _salesExecutiveListener;
  VoidCallback? _authUserListener;

  /// Set when confirm-print succeeds but printer fails; allows retry without re-order.
  String? _pendingPrintOrderNumber;

  /// FIFO queue that serialises barcode processing so burst scans are never
  /// dropped. Instantiated in [_setupListeners] once [processBarcode] is
  /// available; the field is late-initialised so tests can also construct it
  /// directly by providing their own processor.
  late final BarcodeScanQueue _barcodeScanQueue;

  SideBarController? _sideBarController;

  static const _billingMobileAppBarTitles = <int, String?>{
    0: null,
    1: 'Order Summary',
    2: 'Orders',
    3: 'Cart',
  };

  void _syncBillingMobileAppBarTitle(int tabIndex) {
    _sideBarController?.setBillingMobileAppBarTitle(
      _billingMobileAppBarTitles[tabIndex],
    );
  }

  void _switchToTab(int index) {
    setState(() => _currentTabIndex = index);
    _tabController.animateTo(index);
    _syncBillingMobileAppBarTitle(index);
  }

  @override
  void initState() {
    super.initState();
    _quotationInlineNameController = TextEditingController();
    _quotationInlinePhoneController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);

    if (Get.isRegistered<SideBarController>()) {
      _sideBarController = Get.find<SideBarController>();
      // Defer: updating GetX Rx during ancestor build trips markNeedsBuild on
      // MainScreen's Obx app-bar title while BillingPageResponsive is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncBillingMobileAppBarTitle(_currentTabIndex);
      });
    }

    if (_isQuotationPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _sideBarController?.setBillingMobileAppBarTitle('Quotations');
        }
      });
    }

    // Initialize tab controller
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        _syncBillingMobileAppBarTitle(_tabController.index);
      }
    });

    // Initialize providers and listeners (same as original)
    _initializeProviders();
    _setupListeners();
    _setupOrderRehydrationListener();
  }

  void _setupOrderRehydrationListener() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    _localProductOrderListener ??= () {
      if (!mounted) return;
      final currentOrder = localProductProvider.currentOrder;
      if (currentOrder != null && currentOrder.id != _lastRehydratedOrderId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _rehydrateFromProvider();
          }
        });
      }
    };
    localProductProvider.addListener(_localProductOrderListener!);
  }

  void _initializeProviders() {
    final auth = Provider.of<AuthModel>(context, listen: false);
    final accessToken = auth.token;
    final customerId = auth.userId;

    if (customerId != null) {
      _fetchCartDataSafely(customerId: customerId, accessToken: accessToken);
    } else {
      assert(() {
        debugPrint(
          'BillingPageMobile: skipping cart API fetch — auth userId is null',
        );
        return true;
      }());
    }

    // Initialize BillingProvider
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.initConnectivityListener(
      onConnectivityChanged: (message) {
        if (mounted) {
          if (message.contains('No internet')) {
            showScaffoldError(context: context, message: message);
          } else {
            showScaffold(context: context, message: message);
          }
        }
      },
    );

    // Setup focus listeners
    billingProvider.paidAmountFocusNode
        .addListener(billingProvider.handlePaidAmountFocusChange);
    billingProvider.quantityFocusNode
        .addListener(billingProvider.handleQuantityFocusChange);
    billingProvider.unitPriceFocusNode
        .addListener(billingProvider.handleUnitPriceFocusChange);

    billingProvider.registerDefaultKeyboardShortcuts(
      onClearCart: clearCart,
      onSaveOrder: saveOrder,
      onCreateOrderAndPrint: createOrderAndPrint,
      onConfirmOrder: confirmOrder,
      onNewOrder: createNewOrder,
      onSaveOrderAndPrint: saveOrderAndPrint,
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      billingProvider.fetchCustomers(accessToken: accessToken).then((_) {
        if (!mounted) return;
        if (_isQuotationPage) {
          _controller.clearAutomaticDefaultCustomerForQuotation(context);
        } else {
          _applyDefaultCustomerFromCacheIfNeeded();
        }
      });
    } else {
      assert(() {
        debugPrint(
          'BillingPageMobile: skipping customer fetch — auth token is null',
        );
        return true;
      }());
    }

    // Defer provider mutations that notifyListeners — initState runs while
    // BillingPageResponsive is still building this widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      billingProvider.initializeDeliveryMethod();
      _syncAllSettings();
      _setupSettingsSyncListeners();
      if (_isQuotationPage) {
        _controller.clearAutomaticDefaultCustomerForQuotation(context);
      } else if (accessToken == null || accessToken.isEmpty) {
        // With a valid token, the fetch completion above applies the default.
        // Applying it here as well causes duplicate initialization work when
        // the fetch completes before this first-frame callback.
        _applyDefaultCustomerFromCacheIfNeeded();
      }
      _rehydrateFromProvider();
    });
  }

  Future<void> _fetchCartDataSafely({
    required int customerId,
    String? accessToken,
  }) async {
    try {
      await Provider.of<CartProvider>(context, listen: false)
          .fetchCartDataFromApi(
        customerId: customerId,
        accessToken: accessToken ?? '',
      );
    } catch (error, stackTrace) {
      assert(() {
        debugPrint(
          'BillingPageMobile: cart API fetch failed — continuing with local sale: $error',
        );
        debugPrint('$stackTrace');
        return true;
      }());
    }
  }

  void _syncAllSettings() {
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    _settingsController.syncStockEnabled(
      stockEnabled: generalSettingsProvider.generalSettings?.stockEnabled,
      localProductProvider: localProductProvider,
    );

    final appSettings = appSettingsProvider.appSettings;
    _settingsController.syncAllowOverselling(
      appSettings: appSettings,
      localProductProvider: localProductProvider,
    );
    _settingsController.syncAppSettingsFlags(
      appSettings: appSettings,
      billingProvider: billingProvider,
    );
    _settingsController.applyDefaultPaymentMethodIfNeeded(
      billingProvider: billingProvider,
      appSettings: appSettings,
    );
    _settingsController.syncDefaultDeliveryMethod(
      billingProvider: billingProvider,
      deliveryMethodsProvider: deliveryMethodsProvider,
      appSettings: appSettings,
    );
  }

  void _setupSettingsSyncListeners() {
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);

    _generalSettingsListener ??= () {
      if (!mounted) return;
      _settingsController.syncStockEnabled(
        stockEnabled: generalSettingsProvider.generalSettings?.stockEnabled,
        localProductProvider:
            Provider.of<LocalProductProvider>(context, listen: false),
      );
    };
    generalSettingsProvider.addListener(_generalSettingsListener!);
    _generalSettingsListener!();

    _appSettingsSyncListener ??= () {
      if (!mounted) return;
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      final appSettings = appSettingsProvider.appSettings;
      _settingsController.syncAllowOverselling(
        appSettings: appSettings,
        localProductProvider:
            Provider.of<LocalProductProvider>(context, listen: false),
      );
      _settingsController.syncAppSettingsFlags(
        appSettings: appSettings,
        billingProvider: billingProvider,
      );
      _settingsController.applyDefaultPaymentMethodIfNeeded(
        billingProvider: billingProvider,
        appSettings: appSettings,
      );
      _settingsController.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: deliveryMethodsProvider,
        appSettings: appSettings,
      );
      // Customer fetch and app-settings fetch complete independently. Retry
      // automatic default resolution when settings arrive so initialization
      // does not depend on which request wins the race.
      if (_isQuotationPage) {
        _controller.clearAutomaticDefaultCustomerForQuotation(context);
      } else {
        _applyDefaultCustomerFromCacheIfNeeded();
      }
      setState(() {});
    };
    appSettingsProvider.addListener(_appSettingsSyncListener!);

    _deliveryMethodSyncListener ??= () {
      if (!mounted) return;
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      _settingsController.syncDefaultDeliveryMethod(
        billingProvider: billingProvider,
        deliveryMethodsProvider: deliveryMethodsProvider,
        appSettings: appSettingsProvider.appSettings,
      );
    };
    deliveryMethodsProvider.addListener(_deliveryMethodSyncListener!);
    appSettingsProvider.addListener(_deliveryMethodSyncListener!);
    _deliveryMethodSyncListener!();
  }

  void _setupListeners() {
    // FIFO barcode queue: accepts rapid scanner bursts and processes them one
    // at a time in enqueue order without ever dropping a non-empty value.
    _barcodeScanQueue = BarcodeScanQueue(processBarcode);

    // Barcode listener
    final barcodeProvider =
        Provider.of<BarcodeProvider>(context, listen: false);
    _barcodeSubscription = barcodeProvider.barcodeStream.listen((barcode) {
      if (mounted) {
        _barcodeScanQueue.enqueue(barcode);
      }
    });

    // Sales executive and auth listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      final authModel = Provider.of<AuthModel>(context, listen: false);

      _salesExecutiveListener ??= () {
        if (!mounted) return;
        final changed = _customerController.handleSalesExecutiveChanged(
          billingProvider: Provider.of<BillingProvider>(context, listen: false),
          customerSelectionProvider:
              Provider.of<CustomerSelectionProvider>(context, listen: false),
          autoAssignEnabled:
              Provider.of<AppSettingsProvider>(context, listen: false)
                      .appSettings
                      ?.autoAssignDefaultCustomer ??
                  true,
        );
        if (changed) {
          setState(() => _autocompletePhoneKey = GlobalKey());
        }
      };
      salesExecutiveProvider.addListener(_salesExecutiveListener!);

      _authUserListener ??= () {
        if (!mounted) return;
        final changed = _customerController.handleUserSwitched(
          billingProvider: Provider.of<BillingProvider>(context, listen: false),
          customerSelectionProvider:
              Provider.of<CustomerSelectionProvider>(context, listen: false),
          autoAssignEnabled:
              Provider.of<AppSettingsProvider>(context, listen: false)
                      .appSettings
                      ?.autoAssignDefaultCustomer ??
                  true,
        );
        if (changed) {
          setState(() => _autocompletePhoneKey = GlobalKey());
        }
      };
      authModel.addListener(_authUserListener!);
    });

    // Mobile number controller listener
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.mobileNumberTextController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    _cartChangeListener ??= () {
      if (!mounted) return;
      _controller.onCartChanged(context);
    };
    localProductProvider.addListener(_cartChangeListener!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Reset stale in-flight UI flags if the app was backgrounded mid-operation.
      // Cart and provider state are preserved via [AutomaticKeepAliveClientMixin].
      setState(() {
        _isSavingOrder = false;
        _isConfirmingOrder = false;
        _isConfirmingAndPrinting = false;
        _isLoadingOrder = false;
        _isClearingCart = false;
        _isSavingAndPrinting = false;
        _isCreatingNewOrder = false;
      });
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      billingProvider.setLoadingSaveOrder(false);
      billingProvider.setLoadingConfirmOrder(false);
      billingProvider.setLoadingSaveOrderAndPrint(false);
    }
  }

  @override
  void dispose() {
    _sideBarController?.setBillingMobileAppBarTitle(null);
    WidgetsBinding.instance.removeObserver(this);
    _barcodeSubscription?.cancel();
    _focusNode.dispose();
    _tabController.dispose();
    _quotationInlineNameController.dispose();
    _quotationInlinePhoneController.dispose();

    // Remove listeners
    try {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      if (_salesExecutiveListener != null) {
        salesExecutiveProvider.removeListener(_salesExecutiveListener!);
      }

      final authModel = Provider.of<AuthModel>(context, listen: false);
      if (_authUserListener != null) {
        authModel.removeListener(_authUserListener!);
      }

      final generalSettingsProvider =
          Provider.of<GeneralSettingsProvider>(context, listen: false);
      if (_generalSettingsListener != null) {
        generalSettingsProvider.removeListener(_generalSettingsListener!);
      }

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      if (_appSettingsSyncListener != null) {
        appSettingsProvider.removeListener(_appSettingsSyncListener!);
      }

      final deliveryMethodsProvider =
          Provider.of<DeliveryMethodsProvider>(context, listen: false);
      if (_deliveryMethodSyncListener != null) {
        deliveryMethodsProvider.removeListener(_deliveryMethodSyncListener!);
        appSettingsProvider.removeListener(_deliveryMethodSyncListener!);
      }

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      if (_localProductOrderListener != null) {
        localProductProvider.removeListener(_localProductOrderListener!);
      }
      if (_cartChangeListener != null) {
        localProductProvider.removeListener(_cartChangeListener!);
      }
    } catch (e) {
      billingDebugLog('Error removing listeners: $e');
    }

    super.dispose();
  }

  // Rehydrate UI state from provider. Business restore logic lives in
  // [BillingMobileController]; the page only handles the surrounding setState
  // and autocomplete-key regeneration.
  void _applyDefaultCustomerFromCacheIfNeeded() {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final result = _customerController.applyDefaultCustomerFromCacheIfNeeded(
      localProductProvider:
          Provider.of<LocalProductProvider>(context, listen: false),
      billingProvider: Provider.of<BillingProvider>(context, listen: false),
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      appSettings: appSettingsProvider.appSettings,
      customers:
          Provider.of<BillingProvider>(context, listen: false).customerList,
    );
    _customerController.applyDefaultCustomerResult(
      result: result,
      customerSelectionProvider:
          Provider.of<CustomerSelectionProvider>(context, listen: false),
      billingProvider: Provider.of<BillingProvider>(context, listen: false),
      cartProvider: Provider.of<CartProvider>(context, listen: false),
      auth: Provider.of<AuthModel>(context, listen: false),
    );
    if (result.applied && mounted) {
      setState(() {});
    }
  }

  void _rehydrateFromProvider() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final SavedOrder? currentOrder = localProductProvider.currentOrder;

    if (currentOrder != null) {
      _lastRehydratedOrderId = currentOrder.id;
    }

    try {
      if (currentOrder == null) {
        final summary = localProductProvider.priceSummary;
        if (summary != null &&
            (summary.flatDiscount > 0 || summary.percentageDiscount > 0)) {
          billingProvider.setCouponApplied(true);
        } else if (!billingProvider.isCouponApplied) {
          billingProvider.setCouponApplied(false);
        }
        setState(() {});
        return;
      }

      setState(() {
        _controller.restoreOrderState(context);
      });

      _customerController.syncPaymentValidationCustomerContext(
        billingProvider: billingProvider,
        customerSelectionProvider:
            Provider.of<CustomerSelectionProvider>(context, listen: false),
        appSettings: Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _autocompletePhoneKey = GlobalKey();
          });
        }
      });
    } catch (e) {
      billingDebugLog('Error during rehydration: $e');
    }
  }

  void _handleKeyPress(KeyEvent event) =>
      _controller.handleShortcutKey(context, event);

  Future<void> processBarcode(String barcode) async {
    await _controller.processBarcode(
      context,
      barcode,
      onProductKeyRegen: () {
        if (mounted) {
          setState(() => _autocompleteProductKey = GlobalKey());
        }
      },
    );
  }

  void _focusTextField() => _controller.focusTextField(context);

  // Action methods — UI shell only; business logic lives in the controller.
  void clearCart() {
    unawaited(_clearCartWithSecurityKey());
  }

  Future<void> _clearCartWithSecurityKey(
      {bool requireSecurityKey = true}) async {
    if (_isClearingCart) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    setState(() => _isClearingCart = true);
    billingProvider.setLoadingClearCart(true);

    try {
      if (requireSecurityKey &&
          !await PosSecurityKeyDialog.verify(
            context,
            action: 'clear the cart',
          )) {
        return;
      }
      if (!mounted) return;

      setState(() {
        _controller.clearCartData(context);
        _autocompleteProductKey = GlobalKey();
        _autocompletePhoneKey = GlobalKey();
      });

      showScaffold(context: context, message: "Cart Cleared Successfully");
      _focusTextField();
    } catch (e) {
      billingDebugLog('Error clearing cart: $e');
      showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.clearCartFailed);
    } finally {
      billingProvider.setLoadingClearCart(false);
      if (mounted) {
        setState(() => _isClearingCart = false);
      }
    }
  }

  Future<void> saveOrder() async {
    if (_isSavingOrder) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    setState(() => _isSavingOrder = true);
    billingProvider.setLoadingSaveOrder(true);

    try {
      final result = await _controller.saveOrder(context);
      if (!mounted) return;
      // Only clear the workspace after a genuine success.
      // On validationFailed / failed the service has already shown an error
      // snackbar; keeping the cart intact prevents data loss.
      if (result == SaveOrderResult.savedNew ||
          result == SaveOrderResult.updatedExisting) {
        setState(() {
          _controller.clearCartData(context);
          _lastRehydratedOrderId = null;
          _autocompleteProductKey = GlobalKey();
          _autocompletePhoneKey = GlobalKey();
        });
        _focusTextField();
      }
    } finally {
      billingProvider.setLoadingSaveOrder(false);
      if (mounted) {
        setState(() => _isSavingOrder = false);
      }
    }
  }

  bool _isCustomerSatisfiedForCheckout() {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    return _customerController.isCustomerSatisfiedForCheckout(
      billingProvider: billingProvider,
      skipCustomerSelection: false,
    );
  }

  bool _validatePaymentReady({bool switchToBillingTab = true}) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final customerSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final currentOrder = localProductProvider.currentOrder;
    final requireSavedCustomer = currentOrder?.quotationId != null;

    if (_customerController.hasQuoteOnlyCustomerNeedingSave(
      customer: customerSelection.selectedCustomer ??
          billingProvider.selectedCustomer,
      requireSavedCustomer: requireSavedCustomer,
    )) {
      showScaffoldError(
        context: context,
        message: 'billing.quote_customer_save_required'.tr,
      );
      if (switchToBillingTab) {
        _switchToTab(1);
      }
      return false;
    }

    if (!_controller.hasSelectedPayment(context)) {
      showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.selectPaymentMethod);
      if (switchToBillingTab) {
        _switchToTab(1);
      }
      _openPaymentSheetAfterFrame();
      return false;
    }

    final ready = _paymentController.validatePaymentReadyForConfirm(
      billingProvider,
      paymentStepVisited: billingProvider.paymentStepVisited,
    );
    if (!ready.isValid) {
      showScaffoldError(
        context: context,
        message: ready.message ??
            BillingMobileErrorMessages.configurePaymentBeforeConfirm,
      );
      if (switchToBillingTab) {
        _switchToTab(1);
      }
      _openPaymentSheetAfterFrame();
      return false;
    }

    if (!billingProvider.validateCarNumberIfNeeded()) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.enterCarNumber,
      );
      if (switchToBillingTab) {
        _switchToTab(1);
      }
      return false;
    }

    return true;
  }

  /// Opens the payment methods bottom sheet after the current frame (so any
  /// pending tab switch has taken effect) whenever confirm-time validation
  /// rejects the order because payment isn't ready — landing the user
  /// directly in the sheet instead of just showing an error.
  void _openPaymentSheetAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showPaymentMethodsSheet(context);
    });
  }

  void _showPrintRetrySnackBar(String orderNumber) {
    _pendingPrintOrderNumber = orderNumber;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(BillingMobileErrorMessages.printRetryPrompt),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _retryPendingPrint(),
        ),
        duration: const Duration(seconds: 12),
      ),
    );
  }

  Future<void> _retryPendingPrint() async {
    final orderNumber = _pendingPrintOrderNumber;
    if (orderNumber == null || orderNumber.isEmpty) return;

    try {
      await _controller.retryPrintOrder(context, orderNumber);
      if (!mounted) return;
      _pendingPrintOrderNumber = null;
      showScaffold(
          context: context,
          message: BillingMobileErrorMessages.printRetrySuccess);
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.printRetryFailedAgain,
      );
    }
  }

  Future<void> confirmOrder() async {
    if (_isConfirmingOrder || _isConfirmingAndPrinting) return;
    if (!_isQuotationPage && !_showConfirmOrderButton) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (_connectivityController.shouldBlockOnlineCheckout(billingProvider)) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.noInternetConfirm,
      );
      return;
    }

    if (!_isCustomerSatisfiedForCheckout()) {
      showScaffoldError(
          context: context, message: BillingMobileErrorMessages.selectCustomer);
      _switchToTab(1);
      return;
    }

    if (!_validatePaymentReady()) return;

    setState(() => _isConfirmingOrder = true);

    bool confirmed = false;
    try {
      confirmed = await _controller.confirmOrder(context);
    } finally {
      if (mounted) {
        setState(() => _isConfirmingOrder = false);
      }
    }
    if (!mounted) return;
    if (confirmed) {
      _controller.refreshCustomersInBackgroundAfterSale(context);
      // Mirror desktop `_confirmOrder`: reset the workspace and re-apply the
      // default customer (when configured) after a successful confirm.
      setState(() {
        _controller.resetBillingWorkspaceAfterOrder(context);
        _lastRehydratedOrderId = null;
        _autocompleteProductKey = GlobalKey();
        _autocompletePhoneKey = GlobalKey();
      });
    }
    _focusTextField();
  }

  Future<void> createOrderAndPrint() async {
    if (_isConfirmingAndPrinting || _isConfirmingOrder) return;
    if (!_isQuotationPage && !_showConfirmOrderAndPrintButton) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (_connectivityController.shouldBlockOnlineCheckout(billingProvider)) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.noInternetCreateOrder,
      );
      return;
    }

    if (_skipCheckoutOnConfirmAndPrint) {
      billingDebugLog(
        'SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT enabled -> direct confirm & print',
      );
      await _controller.prepareDirectConfirmAndPrint(context);
      if (!mounted) return;
      setState(() {});
    }

    if (!_isCustomerSatisfiedForCheckout()) {
      showScaffoldError(
          context: context, message: BillingMobileErrorMessages.selectCustomer);
      _switchToTab(1);
      return;
    }

    if (!_validatePaymentReady()) return;

    setState(() => _isConfirmingAndPrinting = true);

    try {
      final result = await _controller.createOrderAndPrint(context);
      if (!mounted) return;
      if (result.printFailed && result.orderNumber != null) {
        _showPrintRetrySnackBar(result.orderNumber!);
      } else if (result.orderCreated && result.printSucceeded) {
        _pendingPrintOrderNumber = null;
      }
      if (result.orderCreated) {
        _controller.refreshCustomersInBackgroundAfterSale(context);
        // Mirror desktop `_createOrderAndPrint`: reset the workspace and
        // re-apply the default customer (when configured) once the order has
        // been created, regardless of whether printing succeeded.
        setState(() {
          _controller.resetBillingWorkspaceAfterOrder(context);
          _lastRehydratedOrderId = null;
          _autocompleteProductKey = GlobalKey();
          _autocompletePhoneKey = GlobalKey();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingAndPrinting = false);
      }
    }
  }

  void _handleQuotationInlineCustomerChanged() {
    _controller.handleQuotationInlineCustomerChanged(
      context,
      inlineName: _quotationInlineNameController.text,
      inlinePhone: _quotationInlinePhoneController.text,
    );
    setState(() {});
  }

  void _openQuotationList() {
    if (Get.isRegistered<SideBarController>()) {
      Get.find<SideBarController>().index.value = 87;
    }
  }

  Future<void> createQuotation({required bool shouldPrint}) async {
    if (_isSavingOrder || _isConfirmingAndPrinting) return;

    setState(() {
      if (shouldPrint) {
        _isConfirmingAndPrinting = true;
      } else {
        _isSavingOrder = true;
      }
    });

    try {
      final result = await _controller.createQuotationFromCheckout(
        context,
        shouldPrint: shouldPrint,
        quotationDate: _quotationDate,
        expiryDate: _quotationExpiryDate,
        inlineCustomerName: _quotationInlineNameController.text,
        inlineCustomerPhone: _quotationInlinePhoneController.text,
      );
      if (!mounted) return;

      if (!result.success) {
        showScaffoldError(
          context: context,
          message: result.errorMessage ??
              BillingMobileErrorMessages.quotationCreateFailed,
        );
        return;
      }

      showScaffold(
          context: context, message: 'Quotation created successfully!');
      if (result.printError != null) {
        showScaffoldError(context: context, message: result.printError!);
      }

      final now = DateTime.now();
      setState(() {
        _quotationDate = now;
        _quotationExpiryDate = now.add(const Duration(days: 30));
        _quotationInlineNameController.clear();
        _quotationInlinePhoneController.clear();
      });
      await _clearCartWithSecurityKey(requireSecurityKey: false);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOrder = false;
          _isConfirmingAndPrinting = false;
        });
      }
    }
  }

  Future<void> createQuotationAndPrint() => createQuotation(shouldPrint: true);

  Future<void> saveOrderAndPrint() async {
    if (_isSavingAndPrinting ||
        _isConfirmingOrder ||
        _isConfirmingAndPrinting) {
      return;
    }

    if (_skipCheckoutOnConfirmAndPrint) {
      billingDebugLog(
        'SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT enabled -> direct save & print',
      );
      await _controller.prepareDirectConfirmAndPrint(context);
      if (!mounted) return;
      setState(() {});
    }

    if (!_isCustomerSatisfiedForCheckout()) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.selectCustomer,
      );
      _switchToTab(1);
      return;
    }

    if (!_validatePaymentReady()) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    setState(() => _isSavingAndPrinting = true);
    billingProvider.setLoadingSaveOrderAndPrint(true);

    try {
      final order =
          await CheckoutService(context).saveOrderAndReturnConfirmed();
      if (!mounted || order == null) return;

      try {
        await _controller.printSavedOrder(
          context,
          order,
          offerCustomerCopy: true,
        );
        if (!mounted) return;
        _pendingPrintOrderNumber = null;
      } catch (error) {
        if (!mounted) return;
        _showPrintRetrySnackBar(order.orderNumber);
      }

      if (!mounted) return;
      setState(() {
        _controller.resetBillingWorkspaceAfterOrder(context);
        _lastRehydratedOrderId = null;
        _autocompleteProductKey = GlobalKey();
        _autocompletePhoneKey = GlobalKey();
      });
      _focusTextField();
    } finally {
      billingProvider.setLoadingSaveOrderAndPrint(false);
      if (mounted) {
        setState(() => _isSavingAndPrinting = false);
      }
    }
  }

  Future<void> createNewOrder() async {
    if (_isCreatingNewOrder || _isLoadingOrder) return;

    setState(() => _isCreatingNewOrder = true);
    try {
      await _controller.createNewOrder(context);
      if (!mounted) return;
      setState(() {
        _lastRehydratedOrderId = null;
        _autocompleteProductKey = GlobalKey();
        _autocompletePhoneKey = GlobalKey();
      });
      showScaffold(context: context, message: 'common.create_new_order'.tr);
      _switchToTab(0);
      _focusTextField();
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.saveOrderFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingNewOrder = false);
      }
    }
  }

  Future<void> printSavedOrder(SavedOrder order) async {
    try {
      await _controller.printSavedOrder(context, order);
    } catch (error) {
      if (!mounted) return;
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.printOrderFailed,
      );
    }
  }

  void deleteSavedOrder(SavedOrder order) {
    unawaited(_deleteSavedOrder(order));
  }

  Future<void> _deleteSavedOrder(SavedOrder order) async {
    final orderLabel = order.orderNumber.trim().isNotEmpty
        ? order.orderNumber.trim()
        : order.id;

    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      title: 'Delete Order',
      itemName: orderLabel,
      message: 'This order will be permanently removed from your saved orders.',
      warningIcon: Icons.receipt_long_outlined,
      onDelete: () {},
    );

    if (confirmed != true || !mounted) return;
    if (!await PosSecurityKeyDialog.verify(
      context,
      action: 'delete this saved order',
    )) {
      return;
    }
    if (!mounted) return;

    _controller.deleteSavedOrder(context, order.id);
    showScaffold(
      context: context,
      message: 'Order deleted successfully',
    );
  }

  Future<void> loadSavedOrderForEditing(String orderId) async {
    if (_isLoadingOrder) return;

    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    final isSwitchingOrder = localProductProvider.currentOrder?.id != orderId;
    if (isSwitchingOrder && localProductProvider.cartItems.isNotEmpty) {
      try {
        _controller.saveCurrentCartAsDraft(context);
        showScaffold(context: context, message: 'billing.order_saved'.tr);
      } catch (error) {
        billingDebugLog('Error preserving current order: $error');
      }
    }

    setState(() => _isLoadingOrder = true);
    billingProvider.setLoadingOrder(true);

    try {
      _controller.loadOrderForEditing(context, orderId);
      _rehydrateFromProvider();

      unawaited(
        _controller.refreshPaymentMethodIdsThenRehydrate(context, orderId),
      );

      // Switch to cart tab to show loaded cart
      _switchToTab(3);

      showScaffold(
          context: context, message: 'billing.order_loaded_editing'.tr);
    } catch (error) {
      billingDebugLog('Error loading order: $error');
      showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.loadOrderFailed);
    } finally {
      billingProvider.setLoadingOrder(false);
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              const BillingStatusHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Home Tab
                    MobileHomeTab(
                      autocompleteProductKey: _autocompleteProductKey,
                      onProcessBarcode: _barcodeScanQueue.enqueue,
                      onClearProductFields: () {
                        setState(() {
                          _autocompleteProductKey = GlobalKey();
                          final billingProvider = Provider.of<BillingProvider>(
                              context,
                              listen: false);
                          billingProvider.quantityController.clear();
                          billingProvider.barcodeController.clear();
                          billingProvider.selectedProductIdController.clear();
                          billingProvider.unitPriceController.clear();
                        });
                      },
                      focusTextField: _focusTextField,
                      onClearCart: clearCart,
                    ),
                    // Billing Tab
                    MobileBillingTab(
                      isQuotationMode: _isQuotationPage,
                      autocompletePhoneKey: _autocompletePhoneKey,
                      onConfirmOrder: confirmOrder,
                      onSaveOrder: saveOrder,
                      onCreateOrderAndPrint: createOrderAndPrint,
                      onSaveAndPrint: saveOrderAndPrint,
                      onCreateQuotation: () =>
                          createQuotation(shouldPrint: false),
                      onCreateQuotationAndPrint: createQuotationAndPrint,
                      onOpenQuotationList: _openQuotationList,
                      quotationDate: _quotationDate,
                      quotationExpiryDate: _quotationExpiryDate,
                      onQuotationDateChanged: (date) {
                        setState(() {
                          _quotationDate = date;
                          if (_quotationExpiryDate.isBefore(date)) {
                            _quotationExpiryDate =
                                date.add(const Duration(days: 30));
                          }
                        });
                      },
                      onQuotationExpiryDateChanged: (date) {
                        setState(() => _quotationExpiryDate = date);
                      },
                      quotationInlineNameController:
                          _quotationInlineNameController,
                      quotationInlinePhoneController:
                          _quotationInlinePhoneController,
                      onQuotationInlineCustomerChanged:
                          _handleQuotationInlineCustomerChanged,
                      isSavingOrder: _isSavingOrder,
                      isConfirmingOrder: _isConfirmingOrder,
                      isConfirmingAndPrinting: _isConfirmingAndPrinting,
                      isSavingAndPrinting: _isSavingAndPrinting,
                    ),
                    // Orders Tab
                    MobileOrdersTab(
                      onOrderSelected: loadSavedOrderForEditing,
                      onPrintOrder: printSavedOrder,
                      onDeleteOrder: deleteSavedOrder,
                      onNewOrder: createNewOrder,
                      isLoadingOrder: _isLoadingOrder,
                      isCreatingNewOrder: _isCreatingNewOrder,
                    ),
                    // Cart Tab
                    MobileCartTab(
                      onBackToMarket: () => _switchToTab(0),
                      onProceedToPayment: () => _switchToTab(1),
                      onSaveOrder: saveOrder,
                      onClearCart: clearCart,
                      isSavingOrder: _isSavingOrder,
                      isClearingCart: _isClearingCart,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MobileBottomNav(
          currentIndex: _currentTabIndex,
          onTap: _switchToTab,
        ),
      ),
    );
  }
}
