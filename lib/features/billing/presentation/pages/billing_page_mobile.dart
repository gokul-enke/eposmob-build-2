import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/barcode_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/orders_tab.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/cart_tab.dart';

class BillingPageMobile extends StatefulWidget {
  const BillingPageMobile({super.key});

  @override
  State<BillingPageMobile> createState() => BillingPageMobileState();
}

class BillingPageMobileState extends State<BillingPageMobile>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
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
  bool _isConfirmingOrder = false;

  /// Business logic (restore/rehydration, etc.) lives here; the page keeps only
  /// UI orchestration.
  final BillingMobileController _controller = BillingMobileController();

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    // Initialize providers and listeners (same as original)
    _initializeProviders();
    _setupListeners();
  }

  void _initializeProviders() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');

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

    // Initialize delivery method
    billingProvider.initializeDeliveryMethod();
    billingProvider.fetchCustomers(accessToken: accessToken!);

    // Rehydrate UI from saved order/discounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rehydrateFromProvider();
    });
  }

  void _setupListeners() {
    // Barcode listener
    final barcodeProvider =
        Provider.of<BarcodeProvider>(context, listen: false);
    _barcodeSubscription = barcodeProvider.barcodeStream.listen((barcode) {
      if (mounted) {
        final billingProvider =
            Provider.of<BillingProvider>(context, listen: false);
        billingProvider.processBarcodeWithDebounce(barcode, () {
          processBarcode(barcode);
        });
      }
    });

    // Sales executive and auth listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);

      salesExecutiveProvider
          .addListener(billingProvider.onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(billingProvider.onUserSwitched);

      // App settings listener
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      appSettingsProvider.addListener(() {
        debugPrint('🎫 APP SETTINGS CHANGED:');
        debugPrint('  - New appSettings: ${appSettingsProvider.appSettings}');
      });
    });

    // Mobile number controller listener
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.mobileNumberTextController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    _focusNode.dispose();
    _tabController.dispose();

    // Remove listeners
    try {
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider
          .removeListener(billingProvider.onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.removeListener(billingProvider.onUserSwitched);
    } catch (e) {
      debugPrint("Error removing listeners: $e");
    }

    super.dispose();
  }

  // Rehydrate UI state from provider. Business restore logic lives in
  // [BillingMobileController]; the page only handles the surrounding setState
  // and autocomplete-key regeneration.
  void _rehydrateFromProvider() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final SavedOrder? currentOrder = localProductProvider.currentOrder;

    if (currentOrder != null) {
      _lastRehydratedOrderId = currentOrder.id;
    }

    try {
      if (currentOrder == null) {
        // No saved order to restore; trigger a rebuild so any cleared coupon
        // state is reflected.
        setState(() {});
        return;
      }

      setState(() {
        _controller.restoreOrderState(context);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _autocompletePhoneKey = GlobalKey();
          });
        }
      });
    } catch (e) {
      debugPrint("Error during rehydration: $e");
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
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.setLoadingClearCart(true);

    try {
      setState(() {
        _controller.clearCartData(context);
        _autocompleteProductKey = GlobalKey();
        _autocompletePhoneKey = GlobalKey();
      });

      showScaffold(context: context, message: "Cart Cleared Successfully");
      _focusTextField();
    } catch (e) {
      debugPrint("Error clearing cart: $e");
      showScaffoldError(
          context: context, message: "Failed to clear cart. Please try again.");
    } finally {
      billingProvider.setLoadingClearCart(false);
    }
  }

  void saveOrder() async {
    await _controller.saveOrder(context);
    // Original behaviour: clear the cart whether or not the save reported a
    // change.
    clearCart();
  }

  void confirmOrder() async {
    if (!_controller.hasSelectedPayment(context)) {
      showScaffoldError(
          context: context, message: "Please select a payment method");
      // Switch to billing tab to show payment options
      setState(() {
        _currentTabIndex = 1;
        _tabController.animateTo(1);
      });
      return;
    }

    setState(() {
      _isConfirmingOrder = true;
    });

    try {
      await _controller.confirmOrder(context);
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingOrder = false;
        });
      }
    }
    _focusTextField();
  }

  void createOrderAndPrint() async {
    await _controller.createOrderAndPrint(context);
  }

  void loadSavedOrderForEditing(String orderId) {
    try {
      _controller.loadOrderForEditing(context, orderId);
      _rehydrateFromProvider();

      // Switch to cart tab to show loaded cart
      setState(() {
        _currentTabIndex = 3;
        _tabController.animateTo(3);
      });

      showScaffold(context: context, message: "Order loaded for editing");
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "Failed to load order. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Check for order rehydration
    final currentOrder =
        Provider.of<LocalProductProvider>(context, listen: true).currentOrder;
    if (currentOrder != null && currentOrder.id != _lastRehydratedOrderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rehydrateFromProvider();
        }
      });
    }

    return SafeArea(
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                // Home Tab
                MobileHomeTab(
                  autocompleteProductKey: _autocompleteProductKey,
                  onProcessBarcode: processBarcode,
                  onClearProductFields: () {
                    setState(() {
                      _autocompleteProductKey = GlobalKey();
                      final billingProvider =
                          Provider.of<BillingProvider>(context, listen: false);
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
                  autocompletePhoneKey: _autocompletePhoneKey,
                  onConfirmOrder: confirmOrder,
                  onSaveOrder: saveOrder,
                  onCreateOrderAndPrint: createOrderAndPrint,
                  isConfirmingOrder: _isConfirmingOrder,
                  onBack: () {
                    setState(() {
                      _currentTabIndex = 3;
                      _tabController.animateTo(3);
                    });
                  },
                ),
                // Orders Tab
                MobileOrdersTab(
                  onOrderSelected: loadSavedOrderForEditing,
                ),
                // Cart Tab
                MobileCartTab(
                  onBackToMarket: () {
                    setState(() {
                      _currentTabIndex = 0;
                      _tabController.animateTo(0);
                    });
                  },
                  onProceedToPayment: () {
                    setState(() {
                      _currentTabIndex = 1;
                      _tabController.animateTo(1);
                    });
                  },
                  onSaveOrder: saveOrder,
                  onClearCart: clearCart,
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (index) {
                setState(() {
                  _currentTabIndex = index;
                  _tabController.animateTo(index);
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: ColorManager.kPrimaryColor,
              unselectedItemColor: Colors.grey.shade600,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  activeIcon: Icon(Icons.storefront),
                  label: 'Market',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.payment_outlined),
                  activeIcon: Icon(Icons.payment),
                  label: 'Billing',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Order',
                ),
                BottomNavigationBarItem(
                  icon: Consumer<LocalProductProvider>(
                    builder: (context, provider, _) {
                      final count = provider.cartItems.length;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        backgroundColor: ColorManager.kBadgeColor,
                        child: const Icon(Icons.shopping_cart_outlined),
                      );
                    },
                  ),
                  activeIcon: Consumer<LocalProductProvider>(
                    builder: (context, provider, _) {
                      final count = provider.cartItems.length;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        backgroundColor: ColorManager.kBadgeColor,
                        child: const Icon(Icons.shopping_cart),
                      );
                    },
                  ),
                  label: 'Cart',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
