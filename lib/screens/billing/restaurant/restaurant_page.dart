import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/app_font_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/providers/restaurant/table_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/helpers/date_helper.dart';

import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/cart_provider.dart'; // Import CartProvider
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';

import '../../../components/build_dialog_box.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

// Add button import
import '../../../providers/keyboard_provider.dart'; // Add keyboard provider import
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/screens/print/print_kot.dart';
import 'package:pos_machine/widgets/live_clock.dart';
import 'package:pos_machine/widgets/open_cash_drawer_button.dart';
import 'package:pos_machine/widgets/sync_button.dart';

import 'package:pos_machine/screens/billing/restaurant/utils/restaurant_helpers.dart';
import 'package:pos_machine/screens/billing/restaurant/widgets/tables_panel.dart';
import 'package:pos_machine/screens/billing/restaurant/widgets/menu_panel.dart';
import 'package:pos_machine/screens/billing/restaurant/widgets/order_panel.dart';
import 'package:pos_machine/features/billing/presentation/widgets/keyboard_shortcuts_help_dialog.dart';
import 'package:pos_machine/features/billing/presentation/widgets/dining_selection_modal.dart';
import 'package:pos_machine/services/cash_drawer_service.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';

class RestaurantPage extends StatefulWidget {
  final bool allowCounterBillingFromAttender;
  final bool defaultCounterBillingMode;

  /// Store mode (used by the "Store" sidebar entry): the order panel shows
  /// only the payment summary (no footer action buttons), the Ongoing tab
  /// is hidden, and the delivery method cannot be chosen — the default
  /// delivery method is always applied.
  final bool storeMode;

  const RestaurantPage({
    super.key,
    this.allowCounterBillingFromAttender = true,
    this.defaultCounterBillingMode = false,
    this.storeMode = false,
  });

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

// Mobile view navigation enum
enum MobileView { tables, orders, products }

class _RestaurantPageState extends State<RestaurantPage> {
  String? _activeTableId;
  int? _activeCategoryId;
  dynamic _selectedOrderFromOrderPanel; // New state to hold selected order
  int?
      _refreshCounter; // Counter to trigger refreshes without creating new objects
  final GlobalKey<OrderPanelState> _orderPanelKey =
      GlobalKey<OrderPanelState>(); // Key to access OrderPanel methods
  final GlobalKey<MenuPanelState> _menuPanelKey = GlobalKey<MenuPanelState>();
  bool _isLoadingSendToKitchen =
      false; // Loading state for Send to Kitchen button
  bool _isLoadingPrint = false; // Loading state for Print button
  bool _isLoadingKotBill = false;
  bool _isLoadingCounterConfirmOrder = false;
  bool _isLoadingCounterConfirmAndPrint = false;
  bool _showTablesPanel = true; // Desktop toggle for left tables panel
  bool _isTablesPanelPrefLoaded = false;
  double _leftPanelWidthFraction = 0.22;
  double _rightPanelWidthFraction = 0.30;
  static const double _splitterWidth = 4;
  static const double _leftPanelMinWidth = 220;
  static const double _rightPanelMinWidth = 300;
  static const double _menuPanelMinWidth = 420;
  static const double _denseLeftPanelMinWidth = 190;
  static const double _denseRightPanelMinWidth = 280;
  static const double _denseMenuPanelMinWidth = 360;

  // Mobile navigation state
  MobileView _currentMobileView = MobileView.tables;
  String? _selectedTableName; // Store selected table name for header
  SavedOrder? _editingLocalDraft;
  String? _editingOrderCustomerLabel;
  bool _editingOrderHasCustomer = false;
  String? _editingOrderTableName;
  bool _editingOrderHasTable = false;
  String? _editingOrderDeliveryMethodId;
  String? _editingOrderDeliveryMethodName;

  // Delivery method selection (alternative to table selection)
  String? _selectedDeliveryMethodId;
  String? _selectedDeliveryMethodName;
  bool _isCounterBillingMode = false;
  AppSettingsProvider? _appSettingsProviderForDefaults;
  DeliveryMethodsProvider? _deliveryMethodsProviderForDefaults;
  GeneralSettingsProvider? _generalSettingsProviderForStock;

  String get _menuTitle => widget.storeMode ? 'restaurant.products_tab'.tr : 'restaurant.menu_tab'.tr;

  void _syncStockEnabledSetting() {
    final stockEnabled =
        _generalSettingsProviderForStock?.generalSettings?.stockEnabled ??
            false;
    Provider.of<LocalProductProvider>(context, listen: false)
        .setStockEnabled(stockEnabled);
  }

  @override
  void initState() {
    super.initState();
    _isCounterBillingMode = widget.defaultCounterBillingMode;
    // Store mode on mobile lands directly on the products view — the
    // default delivery method is pre-selected, so billing can start
    // immediately (it stays changeable via the delivery chip rail).
    if (widget.storeMode) {
      _currentMobileView = MobileView.products;
    }
    HardwareKeyboard.instance.addHandler(_onRestaurantHardwareKey);
    _loadTablesPanelPreference();
    _loadPanelWidthPreferences();
    // Initialize data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appSettingsProviderForDefaults =
          Provider.of<AppSettingsProvider>(context, listen: false)
            ..addListener(_applyDefaultCounterDeliveryMethodContext);
      _deliveryMethodsProviderForDefaults =
          Provider.of<DeliveryMethodsProvider>(context, listen: false)
            ..addListener(_applyDefaultCounterDeliveryMethodContext);
      _generalSettingsProviderForStock =
          Provider.of<GeneralSettingsProvider>(context, listen: false)
            ..addListener(_syncStockEnabledSetting);
      _syncStockEnabledSetting();
      _initializeData();
    });
  }

  @override
  void dispose() {
    _appSettingsProviderForDefaults
        ?.removeListener(_applyDefaultCounterDeliveryMethodContext);
    _deliveryMethodsProviderForDefaults
        ?.removeListener(_applyDefaultCounterDeliveryMethodContext);
    _generalSettingsProviderForStock?.removeListener(_syncStockEnabledSetting);
    HardwareKeyboard.instance.removeHandler(_onRestaurantHardwareKey);
    super.dispose();
  }

  bool _isRestaurantShortcutKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f12 ||
        key == LogicalKeyboardKey.escape;
  }

  bool _isRestaurantControlShortcut(LogicalKeyboardKey key) {
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    return key == LogicalKeyboardKey.keyH ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyA;
  }

  bool _onRestaurantHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;

    final route = ModalRoute.of(context);
    final dialogIsOnTop = route != null && !route.isCurrent;
    if (dialogIsOnTop) return false;

    final key = event.logicalKey;
    final isAltCashDrawerShortcut = HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isControlPressed &&
        key == LogicalKeyboardKey.keyD;
    if (!_isRestaurantShortcutKey(key) &&
        !_isRestaurantControlShortcut(key) &&
        !isAltCashDrawerShortcut) {
      return false;
    }

    _handleRestaurantShortcut(event);
    return true;
  }

  void _handleRestaurantShortcut(KeyDownEvent event) {
    final key = event.logicalKey;
    final orderPanelState = _orderPanelKey.currentState;
    final hasInternet =
        Provider.of<BillingProvider>(context, listen: false).hasInternet;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    final showConfirmOrderButton = appSettings?.showConfirmOrderButton ?? true;
    final showConfirmAndPrintButton =
        appSettings?.showConfirmOrderAndPrintButton ?? true;

    try {
      if (key == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        return;
      }

      if (HardwareKeyboard.instance.isControlPressed) {
        if (key == LogicalKeyboardKey.keyH) {
          KeyboardShortcutsHelpDialog.show(
            context,
            mode: KeyboardShortcutsHelpMode.restaurant,
          );
          return;
        }
        if (key == LogicalKeyboardKey.keyK) {
          final keyboardProvider =
              Provider.of<KeyboardProvider>(context, listen: false);
          if (keyboardProvider.showKeyboardFeature) {
            keyboardProvider.featureOff();
            keyboardProvider.clear();
          } else {
            keyboardProvider.featureOn();
          }
          return;
        }
        if (key == LogicalKeyboardKey.keyD) {
          orderPanelState?.focusOrderPanelTabs();
          return;
        }
        if (key == LogicalKeyboardKey.keyS) {
          _menuPanelKey.currentState?.focusSearch();
          return;
        }
        if (key == LogicalKeyboardKey.keyA) {
          _menuPanelKey.currentState?.focusCategories();
          return;
        }
      }

      if (HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed &&
          key == LogicalKeyboardKey.keyD) {
        unawaited(const CashDrawerService().openDrawer(context));
        return;
      }

      if (key == LogicalKeyboardKey.f12) {
        setState(() {
          _showTablesPanel = !_showTablesPanel;
          if (MediaQuery.of(context).size.width < 900) {
            final homeView =
                widget.storeMode ? MobileView.products : MobileView.tables;
            _currentMobileView = _currentMobileView == MobileView.orders
                ? homeView
                : MobileView.orders;
          }
        });
        _saveTablesPanelPreference(_showTablesPanel);
        return;
      }

      final disableCounterConfirmActions =
          _shouldDisableCounterCheckoutActions();
      if (key == LogicalKeyboardKey.f1) {
        unawaited(orderPanelState?.clearCurrentCartFromParent() ??
            Future<void>.value());
      } else if (key == LogicalKeyboardKey.f2) {
        if (disableCounterConfirmActions) return;
        if (hasInternet && !showConfirmOrderButton) return;
        if (hasInternet) {
          orderPanelState?.showCheckoutFromParent();
        } else {
          // Offline F2 opens checkout (Save), never skip-to-print.
          orderPanelState?.showOfflineSaveAndPrintCheckoutFromParent(
            allowSkipCheckout: false,
          );
        }
      } else if (key == LogicalKeyboardKey.f3) {
        unawaited(orderPanelState?.showCustomerSelectionModal() ??
            Future<void>.value());
      } else if (key == LogicalKeyboardKey.f4) {
        if (_isCounterBillingMode) {
          unawaited(orderPanelState?.showDeliverySelectionModalFromParent() ??
              Future<void>.value());
        } else {
          _showDiningSelectionModal();
        }
      } else if (key == LogicalKeyboardKey.f5) {
        if (disableCounterConfirmActions) return;
        if (hasInternet) {
          orderPanelState?.showCheckoutFromParent(initialStep: 3);
        } else {
          orderPanelState?.showOfflineSaveAndPrintCheckoutFromParent(
            initialStep: 3,
            allowSkipCheckout: false,
          );
        }
      } else if (key == LogicalKeyboardKey.f6) {
        if (disableCounterConfirmActions) return;
        if (hasInternet && !showConfirmAndPrintButton) return;
        if (hasInternet) {
          orderPanelState?.showCurrentCartConfirmAndPrintFromParent();
        } else {
          // Offline F6 = Save & Print (respects skip-checkout setting).
          orderPanelState?.showOfflineSaveAndPrintCheckoutFromParent();
        }
      } else if (key == LogicalKeyboardKey.f7) {
        _startNewCounterOrder();
      } else if (key == LogicalKeyboardKey.f8) {
        unawaited(orderPanelState?.saveCurrentCartFromParent() ??
            Future<void>.value());
      } else if (key == LogicalKeyboardKey.f9) {
        if (hasInternet) {
          unawaited(orderPanelState?.saveCurrentCartFromParent() ??
              Future<void>.value());
        } else {
          if (disableCounterConfirmActions) return;
          // Offline F9 = Save & Print (respects skip-checkout setting).
          orderPanelState?.showOfflineSaveAndPrintCheckoutFromParent();
        }
      } else if (key == LogicalKeyboardKey.f10) {
        if (disableCounterConfirmActions) return;
        if (hasInternet) {
          orderPanelState?.showCheckoutFromParent(initialStep: 2);
        } else {
          orderPanelState?.showOfflineSaveAndPrintCheckoutFromParent(
            initialStep: 2,
            allowSkipCheckout: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling restaurant shortcut: $e');
    }
  }

  Future<void> _loadPanelWidthPreferences() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final prefsProvider =
        Provider.of<SharedPreferenceProvider>(context, listen: false);

    final leftFraction =
        await prefsProvider.getRestaurantLeftPanelWidthFraction(
      userId: authModel.userId,
    );
    final rightFraction =
        await prefsProvider.getRestaurantRightPanelWidthFraction(
      userId: authModel.userId,
    );

    if (!mounted) return;
    setState(() {
      if (leftFraction != null && leftFraction.isFinite && leftFraction > 0) {
        _leftPanelWidthFraction = leftFraction;
      }
      if (rightFraction != null &&
          rightFraction.isFinite &&
          rightFraction > 0) {
        _rightPanelWidthFraction = rightFraction;
      }
    });
  }

  Future<void> _saveLeftPanelWidthPreference() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final prefsProvider =
        Provider.of<SharedPreferenceProvider>(context, listen: false);
    await prefsProvider.saveRestaurantLeftPanelWidthFraction(
      _leftPanelWidthFraction,
      userId: authModel.userId,
    );
  }

  Future<void> _saveRightPanelWidthPreference() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final prefsProvider =
        Provider.of<SharedPreferenceProvider>(context, listen: false);
    await prefsProvider.saveRestaurantRightPanelWidthFraction(
      _rightPanelWidthFraction,
      userId: authModel.userId,
    );
  }

  Future<void> _loadTablesPanelPreference() async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final prefsProvider =
        Provider.of<SharedPreferenceProvider>(context, listen: false);
    final isVisible = await prefsProvider.getRestaurantTablesPanelVisible(
      userId: authModel.userId,
    );

    if (!mounted) return;
    setState(() {
      if (isVisible != null) {
        _showTablesPanel = isVisible;
      }
      _isTablesPanelPrefLoaded = true;
    });
  }

  Future<void> _saveTablesPanelPreference(bool isVisible) async {
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final prefsProvider =
        Provider.of<SharedPreferenceProvider>(context, listen: false);
    await prefsProvider.saveRestaurantTablesPanelVisible(
      isVisible,
      userId: authModel.userId,
    );
  }

  Future<void> _initializeData() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final productProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final authModel = Provider.of<AuthModel>(context, listen: false);

    // Load categories if not already loaded
    if (!categoryProvider.isCategoriesLoaded) {
      await categoryProvider.ensureCategoriesLoaded();
    }

    // Load all products (refreshProducts is void, so no await needed)
    productProvider.refreshProducts();

    // Delivery methods: already loaded during store bootstrap (StoreSessionProvider).
    // Just ensure they're available — this returns immediately from memory if already loaded.
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    if (!deliveryMethodsProvider.hasMethods) {
      debugPrint(
          '🚚 [RestaurantPage] Delivery methods not in memory — triggering fetch (will use cache if available)');
      await deliveryMethodsProvider.fetchDeliveryMethods();
    } else {
      debugPrint(
          '🚚 [RestaurantPage] ✅ ${deliveryMethodsProvider.deliveryMethods.length} delivery methods already in provider memory — no API call needed');
    }

    // Load tables from API
    await tableProvider.loadTables(accessToken: authModel.token);

    _applyDefaultCounterDeliveryMethodContext();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // Better responsive breakpoints
    final isLargeScreen = screenWidth >= 1024;
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern light background
      body: SafeArea(
        // Note: no AnimatedSwitcher here — both layouts hold OrderPanel with
        // the same GlobalKey, so cross-fading them would duplicate the key.
        child: isSmallScreen
            ? _buildMobileLayout(screenSize)
            : _buildDesktopLayout(screenSize, isLargeScreen),
      ),
    );
  }

  Widget _buildDesktopLayout(Size screenSize, bool isLargeScreen) {
    if (!_isTablesPanelPrefLoaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final isDenseDesktop = screenSize.width < 1180 || screenSize.height <= 800;

    return Column(
      children: [
        _buildAttenderTopBar(isCompact: isDenseDesktop || !isLargeScreen),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final splitterCount = _showTablesPanel ? 2 : 1;
              final totalSplitterWidth = splitterCount * _splitterWidth;
              final availableWidth =
                  math.max(0, totalWidth - totalSplitterWidth);
              final leftMin = _showTablesPanel
                  ? (isDenseDesktop
                      ? _denseLeftPanelMinWidth
                      : _leftPanelMinWidth)
                  : 0.0;
              final menuMin =
                  isDenseDesktop ? _denseMenuPanelMinWidth : _menuPanelMinWidth;
              final rightMin = isDenseDesktop
                  ? _denseRightPanelMinWidth
                  : _rightPanelMinWidth;
              final leftMax = _showTablesPanel
                  ? math.max(leftMin, availableWidth - menuMin - rightMin)
                  : 0.0;
              final rightMax = math.max(
                rightMin,
                availableWidth - (_showTablesPanel ? leftMin : 0) - menuMin,
              );

              final leftWidth = _showTablesPanel
                  ? (availableWidth * _leftPanelWidthFraction)
                      .clamp(leftMin, leftMax)
                      .toDouble()
                  : 0.0;
              final rightWidth = (availableWidth * _rightPanelWidthFraction)
                  .clamp(rightMin, rightMax)
                  .toDouble();
              final menuWidth = math.max(
                menuMin,
                availableWidth - leftWidth - rightWidth,
              );

              return Row(
                children: [
                  if (_showTablesPanel)
                    SizedBox(
                      width: leftWidth,
                      child: _buildLeftPanel(screenSize),
                    ),
                  if (_showTablesPanel)
                    _buildHorizontalSplitter(
                      onDragUpdate: (dx) {
                        final nextLeftWidth =
                            (leftWidth + dx).clamp(leftMin, leftMax).toDouble();
                        setState(() {
                          _leftPanelWidthFraction =
                              nextLeftWidth / availableWidth;
                        });
                      },
                      onDragEnd: _saveLeftPanelWidthPreference,
                    ),
                  SizedBox(
                    width: menuWidth,
                    child: _buildMenuArea(
                      screenSize,
                      isCompact: isDenseDesktop,
                    ),
                  ),
                  _buildHorizontalSplitter(
                    onDragUpdate: (dx) {
                      final nextRightWidth = (rightWidth - dx)
                          .clamp(rightMin, rightMax)
                          .toDouble();
                      setState(() {
                        _rightPanelWidthFraction =
                            nextRightWidth / availableWidth;
                      });
                    },
                    onDragEnd: _saveRightPanelWidthPreference,
                  ),
                  SizedBox(
                    width: rightWidth,
                    child: OrderPanel(
                      key: _orderPanelKey,
                      tableId: _activeTableId,
                      preselectedDeliveryMethodId: _selectedDeliveryMethodId,
                      preselectedDeliveryMethodName:
                          _selectedDeliveryMethodName,
                      screenSize: screenSize,
                      onSendToKitchen: _sendOrderToKitchenWithLoading,
                      onNewOrder: _handleNewOrder,
                      onPrintOrder: _printOrderWithLoading,
                      onKotBill: _sendKotBillWithLoading,
                      allowCounterBilling:
                          widget.allowCounterBillingFromAttender,
                      isCounterBillingMode: _isCounterBillingMode,
                      onOrderSelected: (order) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedOrderFromOrderPanel = order;
                              if (order != null) {
                                _editingLocalDraft = null;
                                _captureEditingOrderDisplayContext(order);
                              } else {
                                _clearEditingOrderDisplayContext();
                              }
                            });
                          }
                        });
                      },
                      selectedOrderFromParent: _selectedOrderFromOrderPanel,
                      refreshCounter: _refreshCounter,
                      isLoadingSendToKitchen: _isLoadingSendToKitchen,
                      isLoadingPrint: _isLoadingPrint,
                      isLoadingKotBill: _isLoadingKotBill,
                      isCompact: isDenseDesktop,
                      onLocalDraftLoaded: _applyLocalDraftContext,
                      onLocalDraftSaved: _resetCounterOrderContextAfterSave,
                      onEditedOrderConfirmed:
                          _resetCounterOrderContextAfterSave,
                      onCheckoutActionLoadingChanged:
                          _setCounterCheckoutLoading,
                      hideFooterActionButtons: widget.storeMode,
                      hideOngoingOrdersTab: widget.storeMode,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(Size screenSize) {
    if (_isCounterBillingMode) {
      return _buildCounterSelectionPanel(screenSize);
    }

    return TablesPanel(
      activeTableId: _activeTableId,
      onSelect: _selectDiningTable,
      selectedDeliveryMethodId: _selectedDeliveryMethodId,
      showDeliveryMethods: _isCounterBillingMode,
      onDeliveryMethodSelected: _selectDeliveryMethod,
      screenSize: screenSize,
    );
  }

  Widget _buildMenuArea(Size screenSize, {bool isCompact = false}) {
    final menuPanel = MenuPanel(
      key: _menuPanelKey,
      onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
      activeCategoryId: _activeCategoryId,
      onItemAdd: _handleItemAdd,
      isCompact: isCompact,
      useFontCardModeInCompact: isCompact,
      screenSize: screenSize,
      selectedOrder: _selectedOrderFromOrderPanel,
      headerTitle: _menuTitle,
      storeMode: widget.storeMode,
    );

    if (!_isCounterBillingMode) {
      return menuPanel;
    }

    return Column(
      children: [
        Expanded(child: menuPanel),
        _buildCounterActionBar(),
      ],
    );
  }

  Widget _buildCounterSelectionPanel(Size screenSize) {
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context);

    return Container(
      margin: const EdgeInsets.all(8),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.05),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'restaurant.order_tab'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s16,
                      0.30,
                      const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  // Store mode is walk-in/delivery billing only — no tables.
                  if (!widget.storeMode) ...[
                    _buildCounterSelectorButton(
                      icon: Icons.restaurant_rounded,
                      title: 'restaurant.dining_label'.tr,
                      value: _counterDiningLabel(
                          fallback: 'restaurant.select_table_short'.tr),
                      color: const Color(0xFF2563EB),
                      isSelected: _hasCounterDiningSelection,
                      onTap: _showDiningSelectionModal,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildCounterSelectorButton(
                    icon: Icons.person_rounded,
                    title: 'restaurant.customer_label'.tr,
                    value: _counterCustomerLabel(
                      customerSelectionProvider,
                      fallback: 'restaurant.select_customer_placeholder'.tr,
                    ),
                    color: const Color(0xFF7C3AED),
                    isSelected: _hasCounterCustomer(customerSelectionProvider),
                    onTap: () async {
                      final state = await _ensureOrderPanelState();
                      if (state == null) {
                        if (!mounted) return;
                        showScaffoldError(
                          context: context,
                          message: 'Customer selector is not ready yet',
                        );
                        return;
                      }
                      await state.showCustomerSelectionModal();
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCounterSelectorButton(
                    icon: Icons.payments_rounded,
                    title: 'restaurant.payment_label'.tr,
                    value: _counterPaymentLabel(
                        fallback: 'restaurant.select_payment'.tr),
                    color: const Color(0xFFEA580C),
                    isSelected: _hasCounterPaymentSelection,
                    onTap: () async {
                      final state = await _ensureOrderPanelState();
                      if (state == null) {
                        if (!mounted) return;
                        showScaffoldError(
                          context: context,
                          message: 'Payment selector is not ready yet',
                        );
                        return;
                      }
                      await state.showPaymentSelectionModalFromParent();
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildCounterSelectorButton(
                    icon: Icons.local_shipping_rounded,
                    title: 'restaurant.delivery_label'.tr,
                    value: _counterDeliveryLabel(
                        fallback: 'restaurant.select_delivery'.tr),
                    color: const Color(0xFF059669),
                    isSelected: _hasCounterDeliverySelection,
                    onTap: () async {
                      final state = await _ensureOrderPanelState();
                      if (state == null) {
                        if (!mounted) return;
                        showScaffoldError(
                          context: context,
                          message: 'Delivery selector is not ready yet',
                        );
                        return;
                      }
                      await state.showDeliverySelectionModalFromParent();
                      if (!mounted) return;
                      final deliveryMethodId =
                          state.selectedDeliveryMethodIdForDraft;
                      final deliveryMethod =
                          state.selectedDeliveryMethodForDraft;
                      if (deliveryMethodId.isNotEmpty) {
                        _selectDeliveryMethod(
                          deliveryMethodId,
                          deliveryMethod.isNotEmpty
                              ? deliveryMethod
                              : 'restaurant.delivery_label'.tr,
                        );
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterSelectorButton({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s13,
                        0.21,
                        const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s11,
                        0.21,
                        const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade500, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterActionBar({bool showShortcuts = true}) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, _) {
        final hasItems = localProductProvider.cartItems.isNotEmpty;
        final hasInternet = Provider.of<BillingProvider>(context).hasInternet;
        final appSettings =
            Provider.of<AppSettingsProvider>(context).appSettings;
        final showConfirmAndPrintButton =
            appSettings?.showConfirmOrderAndPrintButton ?? true;
        final canCheckout = hasItems;
        final isCheckoutActionLoading =
            _isLoadingCounterConfirmOrder || _isLoadingCounterConfirmAndPrint;
        final disableConfirmActions =
            _shouldDisableCounterCheckoutActions() || isCheckoutActionLoading;
        final showFooterConfirmOrder = widget.allowCounterBillingFromAttender &&
            _isCounterBillingMode &&
            hasInternet &&
            (appSettings?.showConfirmOrderButton ?? true);
        final hasFooterCheckoutAction =
            !hasInternet || showConfirmAndPrintButton || showFooterConfirmOrder;
        final confirmOrderIsLoading = _isLoadingCounterConfirmOrder ||
            (!showConfirmAndPrintButton && _isLoadingCounterConfirmAndPrint);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildCounterActionButton(
                    text: 'restaurant.clear_cart'.tr,
                    shortcutLabel: showShortcuts ? 'F1' : null,
                    color: const Color(0xFFEF233C),
                    isDisabled: !hasItems || isCheckoutActionLoading,
                    onPressed: () => _orderPanelKey.currentState
                        ?.clearCurrentCartFromParent(),
                  ),
                  const SizedBox(width: 12),
                  _buildCounterActionButton(
                    text: 'restaurant.save_order'.tr,
                    shortcutLabel: showShortcuts ? 'F8' : null,
                    color: const Color(0xFFF59E0B),
                    isDisabled: !hasItems || isCheckoutActionLoading,
                    onPressed: () => _orderPanelKey.currentState
                        ?.saveCurrentCartFromParent(),
                  ),
                  if (hasFooterCheckoutAction) const SizedBox(width: 12),
                  if (hasInternet) ...[
                    if (showConfirmAndPrintButton) ...[
                      _buildCounterActionButton(
                        text: 'restaurant.confirm_and_print'.tr,
                        shortcutLabel: showShortcuts ? 'F6' : null,
                        color: const Color(0xFF5B8DEF),
                        isDisabled: !canCheckout || disableConfirmActions,
                        isLoading: _isLoadingCounterConfirmAndPrint,
                        onPressed: () => _orderPanelKey.currentState
                            ?.showCurrentCartConfirmAndPrintFromParent(),
                      ),
                      if (showFooterConfirmOrder) const SizedBox(width: 12),
                    ],
                    if (showFooterConfirmOrder)
                      _buildCounterActionButton(
                        text: 'restaurant.confirm_order'.tr,
                        shortcutLabel: showShortcuts ? 'F2' : null,
                        color: const Color(0xFF08C63F),
                        isDisabled: !canCheckout || disableConfirmActions,
                        isLoading: confirmOrderIsLoading,
                        onPressed: () => _orderPanelKey.currentState
                            ?.showCurrentCartCheckoutFromParent(),
                      ),
                  ] else
                    _buildCounterActionButton(
                      text: 'restaurant.save_print'.tr,
                      shortcutLabel: showShortcuts ? 'F9' : null,
                      color: const Color(0xFFF59E0B),
                      isDisabled: !canCheckout || disableConfirmActions,
                      isLoading: isCheckoutActionLoading,
                      onPressed: () => _orderPanelKey.currentState
                          ?.showOfflineSaveAndPrintCheckoutFromParent(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldDisableCounterCheckoutActions() {
    return false;
  }

  bool _isKotBillEnabled(AppSettings? appSettings) {
    return widget.allowCounterBillingFromAttender &&
        _isCounterBillingMode &&
        (appSettings?.enableKotBillButton ?? false);
  }

  bool _isKotBillAllowedForCurrentContext(AppSettings? appSettings) {
    final hasDineInContext =
        _activeTableId != null || _isSelectedDeliveryMethodDineIn();
    return !hasDineInContext || (appSettings?.kotBillAllowedForDineIn ?? false);
  }

  bool _isSelectedDeliveryMethodDineIn() {
    final selectedId = _selectedDeliveryMethodId?.trim();
    final selectedName = _selectedDeliveryMethodName?.trim();
    if ((selectedId == null || selectedId.isEmpty) &&
        (selectedName == null || selectedName.isEmpty)) {
      return false;
    }

    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    DeliveryMethod? selectedMethod;
    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if (selectedId != null &&
          selectedId.isNotEmpty &&
          method.id == selectedId) {
        selectedMethod = method;
        break;
      }
    }

    final code = selectedMethod?.code ?? '';
    final name = selectedMethod?.name ?? selectedName ?? '';
    return _normalizesAsDineIn(code) || _normalizesAsDineIn(name);
  }

  bool _normalizesAsDineIn(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'dinein';
  }

  Widget _buildCounterActionButton({
    required String text,
    String? shortcutLabel,
    required Color color,
    required VoidCallback onPressed,
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    final disabled = isDisabled || isLoading;
    final foregroundColor = disabled ? const Color(0xFF94A3B8) : Colors.white;
    final shortcutBackgroundColor =
        disabled ? const Color(0xFFF8FAFC) : Colors.white.withOpacity(0.18);
    final shortcutBorderColor =
        disabled ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.35);

    return Expanded(
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          foregroundColor: foregroundColor,
          disabledForegroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (shortcutLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: shortcutBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: shortcutBorderColor),
                      ),
                      child: Text(
                        shortcutLabel,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  void _setCounterCheckoutLoading({
    required bool isLoading,
    required bool printBill,
  }) {
    if (!mounted) return;
    setState(() {
      if (printBill) {
        _isLoadingCounterConfirmAndPrint = isLoading;
      } else {
        _isLoadingCounterConfirmOrder = isLoading;
      }
    });
  }

  void _selectDiningTable(String id) {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final selectedTable = tableProvider.tables.firstWhere(
      (table) => table.id == id,
      orElse: () => tableProvider.tables.first,
    );

    final isEditingSelectedOrder = _selectedOrderFromOrderPanel != null;
    if (!_isCounterBillingMode && !isEditingSelectedOrder) {
      _autoSaveCurrentTableBeforeSwitch();
    }
    setState(() {
      _activeTableId = id;
      _selectedTableName = selectedTable.name;
      _selectedDeliveryMethodId = null;
      _selectedDeliveryMethodName = null;
      if (isEditingSelectedOrder) {
        _editingOrderTableName = selectedTable.name;
        _editingOrderHasTable = true;
        _editingOrderDeliveryMethodId = null;
        _editingOrderDeliveryMethodName = null;
      }
    });
    final orderPanelState = _orderPanelKey.currentState;
    orderPanelState?.resetPaymentModalFlag();
    if (!isEditingSelectedOrder) {
      if (!(orderPanelState?.isViewingCounterListTab ?? false)) {
        orderPanelState?.showCurrentOrderTab();
      }
    }
  }

  void _selectDeliveryMethod(String id, String name) {
    if (id.isEmpty) {
      setState(() {
        _selectedDeliveryMethodId = null;
        _selectedDeliveryMethodName = null;
        if (_selectedOrderFromOrderPanel != null) {
          _editingOrderDeliveryMethodId = null;
          _editingOrderDeliveryMethodName = null;
        }
      });
      return;
    }

    final isEditingSelectedOrder = _selectedOrderFromOrderPanel != null;
    if (!_isCounterBillingMode && !isEditingSelectedOrder) {
      _autoSaveCurrentTableBeforeSwitch();
    }
    setState(() {
      _selectedDeliveryMethodId = id;
      _selectedDeliveryMethodName = name;
      _activeTableId = null;
      _selectedTableName = null;
      if (isEditingSelectedOrder) {
        _editingOrderDeliveryMethodId = id;
        _editingOrderDeliveryMethodName = name;
        _editingOrderTableName = null;
        _editingOrderHasTable = false;
      }
    });
    final orderPanelState = _orderPanelKey.currentState;
    orderPanelState?.resetPaymentModalFlag();
    if (!isEditingSelectedOrder) {
      if (!(orderPanelState?.isViewingCounterListTab ?? false)) {
        orderPanelState?.showCurrentOrderTab();
      }
    }
  }

  void _applyLocalDraftContext(SavedOrder order) {
    String? tableName;
    if (order.tableId != null && order.tableId!.isNotEmpty) {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      for (final table in tableProvider.tables) {
        if (table.id == order.tableId) {
          tableName = table.name;
          break;
        }
      }
    }

    setState(() {
      _editingLocalDraft = order;
      _selectedOrderFromOrderPanel = null;
      _clearEditingOrderDisplayContext();
      if (order.tableId != null && order.tableId!.isNotEmpty) {
        _activeTableId = order.tableId;
        _selectedTableName = tableName ?? order.tableId;
        _selectedDeliveryMethodId = null;
        _selectedDeliveryMethodName = null;
      } else {
        _activeTableId = null;
        _selectedTableName = null;
        _selectedDeliveryMethodId = order.deliveryMethodId;
        _selectedDeliveryMethodName = order.deliveryMethod;
      }
    });
  }

  void _resetCounterOrderContextAfterSave() {
    if (!_isCounterBillingMode) {
      setState(() {
        _selectedOrderFromOrderPanel = null;
        _editingLocalDraft = null;
        _clearEditingOrderDisplayContext();
        _refreshCounter = (_refreshCounter ?? 0) + 1;
      });
      return;
    }

    setState(() {
      _activeTableId = null;
      _selectedTableName = null;
      _selectedDeliveryMethodId = null;
      _selectedDeliveryMethodName = null;
      _selectedOrderFromOrderPanel = null;
      _editingLocalDraft = null;
      _clearEditingOrderDisplayContext();
      _refreshCounter = (_refreshCounter ?? 0) + 1;
    });
    _applyDefaultCounterDeliveryMethodContext();
  }

  void _resetCounterOrderContextAfterKitchenSend() {
    if (!_isCounterBillingMode) return;
    _orderPanelKey.currentState?.resetActiveOrderContext();
    _orderPanelKey.currentState?.showCurrentOrderTab();
    _resetCounterOrderContextAfterSave();
  }

  String? _normalizeOrderResponseValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  Future<bool> _openCounterKitchenOrderAfterSend(dynamic response) async {
    if (!mounted ||
        !_isCounterBillingMode ||
        !widget.allowCounterBillingFromAttender ||
        response is! Map) {
      return false;
    }

    final orderId = _normalizeOrderResponseValue(
      response['order_id'] ?? response['id'],
    );
    final orderNumber = _normalizeOrderResponseValue(
      response['order_number'] ?? response['display_order_id'],
    );

    debugPrint(
      '[Counter KOT] Send success; opening edit order for id=$orderId number=$orderNumber',
    );

    final orderPanelState = _orderPanelKey.currentState;
    if (orderPanelState == null) {
      debugPrint('[Counter KOT] Order panel state unavailable');
      return false;
    }

    final opened = await orderPanelState.openCreatedOrderForEditing(
      orderId: orderId,
      orderNumber: orderNumber,
      seedOrder: response,
    );

    if (!opened) {
      debugPrint(
        '[Counter KOT] Could not open created order automatically',
      );
    }

    return opened;
  }

  DeliveryMethod? _resolveDefaultDeliveryMethod() {
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    final appSettingsDefault =
        Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.defaultDeliveryMethod
            .trim();

    return deliveryMethodsProvider.resolveDefaultDeliveryMethod(
      appSettingsDefault: appSettingsDefault,
    );
  }

  void _applyDefaultCounterDeliveryMethodContext() {
    if (!mounted ||
        !_isCounterBillingMode ||
        _activeTableId != null ||
        (_selectedDeliveryMethodId?.isNotEmpty ?? false)) {
      return;
    }

    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    if (!deliveryMethodsProvider.hasMethods) return;

    final defaultMethod = _resolveDefaultDeliveryMethod();
    if (defaultMethod == null || defaultMethod.id.isEmpty) return;

    setState(() {
      _selectedDeliveryMethodId = defaultMethod.id;
      _selectedDeliveryMethodName = defaultMethod.name;
    });
  }

  void _showDiningSelectionModal() {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => DiningSelectionModal(
        tables: tableProvider.tables,
        selectedTableId: _activeTableId,
        onTableSelected: (table) => _selectDiningTable(table.id),
      ),
    );
  }

  Widget _buildHorizontalSplitter({
    required void Function(double deltaDx) onDragUpdate,
    required Future<void> Function() onDragEnd,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: () => onDragEnd(),
        child: SizedBox(
          width: _splitterWidth,
          child: Center(
            child: Container(
              width: 2,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.60),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttenderTopBar(
      {required bool isCompact, bool isMobile = false}) {
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context);
    final isCounterEnabled =
        widget.allowCounterBillingFromAttender && _isCounterBillingMode;
    final hasActiveTable = _activeTableId != null;
    final contextLabel = hasActiveTable
        ? (_selectedTableName ?? 'Selected table')
        : isCounterEnabled
            ? (_selectedDeliveryMethodName ?? 'Choose Dining or Delivery')
            : (_selectedDeliveryMethodName ?? 'Select table or delivery');
    final title = _topBarOrderTitle;
    final contextIcon = hasActiveTable
        ? Icons.table_restaurant_rounded
        : isCounterEnabled
            ? Icons.point_of_sale_rounded
            : Icons.delivery_dining_rounded;

    if (isMobile) {
      return _buildMobileTopBar(
        customerSelectionProvider: customerSelectionProvider,
        isCounterEnabled: isCounterEnabled,
        title: title,
        contextLabel: contextLabel,
        contextIcon: contextIcon,
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(8, isCompact ? 6 : 8, 8, 0),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: isCompact ? 5 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints(
              minWidth: isCompact ? 30 : 34,
              minHeight: isCompact ? 30 : 34,
            ),
            icon: Icon(
              _showTablesPanel ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: const Color(0xFF2563EB),
              size: isCompact ? 18 : 20,
            ),
            tooltip:
                _showTablesPanel ? 'Hide Tables Panel' : 'Show Tables Panel',
            onPressed: () {
              final nextValue = !_showTablesPanel;
              setState(() => _showTablesPanel = nextValue);
              _saveTablesPanelPreference(nextValue);
            },
          ),
          // const SizedBox(width: 6),
          // Container(
          //   padding: EdgeInsets.all(isCompact ? 7 : 9),
          //   decoration: BoxDecoration(
          //     color: isCounterEnabled
          //         ? const Color(0xFF059669).withOpacity(0.12)
          //         : const Color(0xFF2563EB).withOpacity(0.10),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Icon(
          //     isCounterEnabled
          //         ? Icons.point_of_sale_rounded
          //         : Icons.restaurant_menu_rounded,
          //     color: isCounterEnabled
          //         ? const Color(0xFF059669)
          //         : const Color(0xFF2563EB),
          //     size: isCompact ? 16 : 19,
          //   ),
          // ),
          SizedBox(width: isCompact ? 8 : 10),
          Expanded(
            child: Wrap(
              spacing: isCompact ? 8 : 12,
              runSpacing: isCompact ? 2 : 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    isCompact ? FontSize.s14 : FontSize.s16,
                    0.30,
                    const Color(0xFF1E293B),
                  ),
                ),
                if (isCounterEnabled)
                  ..._buildCounterContextChips(
                    customerSelectionProvider: customerSelectionProvider,
                    isCompact: isCompact,
                  )
                else if (!isCompact)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          contextIcon,
                          size: 14,
                          color: isCounterEnabled
                              ? const Color(0xFF047857)
                              : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          contextLabel,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s12,
                            0.21,
                            isCounterEnabled
                                ? const Color(0xFF047857)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isCompact || MediaQuery.sizeOf(context).width >= 1000) ...[
            if (widget.allowCounterBillingFromAttender) ...[
              SizedBox(width: isCompact ? 6 : 8),
              _buildTopBarNewOrderButton(isCompact: isCompact),
            ],
            SizedBox(width: isCompact ? 8 : 14),
            _buildTopBarActions(isCompact: isCompact),
            if (!isCompact) ...[
              const SizedBox(width: 6),
              const LiveClock(),
            ],
          ] else if (isMobile) ...[
            const SizedBox(width: 6),
            const SyncButton(
              showTooltip: true,
              showText: false,
            ),
            const SizedBox(width: 4),
            _buildConnectivityIndicator(isCompact: true),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCounterContextChips({
    required CustomerSelectionProvider customerSelectionProvider,
    required bool isCompact,
    double? chipMaxWidth,
  }) {
    return [
      // Store mode is walk-in/delivery billing only — no table selection.
      if (!widget.storeMode)
        _buildTopBarContextChip(
          icon: Icons.restaurant_rounded,
          label: _counterDiningLabel(fallback: 'restaurant.dining_label'.tr),
          color: const Color(0xFF2563EB),
          isSelected: _hasCounterDiningSelection,
          onTap: _showDiningSelectionModal,
          isCompact: isCompact,
          maxWidth: chipMaxWidth,
        ),
      _buildTopBarContextChip(
        icon: Icons.person_rounded,
        label: _counterCustomerLabel(
          customerSelectionProvider,
          fallback: 'restaurant.customer_label'.tr,
        ),
        color: const Color(0xFF7C3AED),
        isSelected: _hasCounterCustomer(customerSelectionProvider),
        isCompact: isCompact,
        maxWidth: chipMaxWidth,
        onTap: () async {
          final state = await _ensureOrderPanelState();
          if (state == null) {
            if (!mounted) return;
            showScaffoldError(
              context: context,
              message: 'Customer selector is not ready yet',
            );
            return;
          }
          await state.showCustomerSelectionModal();
          if (mounted) setState(() {});
        },
      ),
      _buildTopBarContextChip(
        icon: Icons.payments_rounded,
        label: _counterPaymentLabel(fallback: 'restaurant.payment_label'.tr),
        color: const Color(0xFFEA580C),
        isSelected: _hasCounterPaymentSelection,
        isCompact: isCompact,
        maxWidth: chipMaxWidth,
        onTap: () async {
          final state = await _ensureOrderPanelState();
          if (state == null) {
            if (!mounted) return;
            showScaffoldError(
              context: context,
              message: 'Payment selector is not ready yet',
            );
            return;
          }
          await state.showPaymentSelectionModalFromParent();
          if (mounted) setState(() {});
        },
      ),
      _buildTopBarContextChip(
        icon: Icons.local_shipping_rounded,
        label: _counterDeliveryLabel(fallback: 'restaurant.delivery_label'.tr),
        color: const Color(0xFF059669),
        isSelected: _hasCounterDeliverySelection,
        isCompact: isCompact,
        maxWidth: chipMaxWidth,
        onTap: () async {
          final state = await _ensureOrderPanelState();
          if (state == null) {
            if (!mounted) return;
            showScaffoldError(
              context: context,
              message: 'Delivery selector is not ready yet',
            );
            return;
          }
          await state.showDeliverySelectionModalFromParent();
          if (!mounted) return;
          final deliveryMethodId = state.selectedDeliveryMethodIdForDraft;
          final deliveryMethod = state.selectedDeliveryMethodForDraft;
          if (deliveryMethodId.isNotEmpty) {
            _selectDeliveryMethod(
              deliveryMethodId,
              deliveryMethod.isNotEmpty
                  ? deliveryMethod
                  : 'restaurant.delivery_label'.tr,
            );
          } else {
            setState(() {});
          }
        },
      ),
    ];
  }

  /// Two-row top bar for phones: title + actions, then a horizontally
  /// scrollable context-chip rail. No tables-panel toggle here — that
  /// only affects the desktop layout.
  Widget _buildMobileTopBar({
    required CustomerSelectionProvider customerSelectionProvider,
    required bool isCounterEnabled,
    required String title,
    required String contextLabel,
    required IconData contextIcon,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s15,
                    0.30,
                    const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (widget.allowCounterBillingFromAttender)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                  tooltip: 'New Order',
                  onPressed: _startNewCounterOrder,
                ),
              const SyncButton(
                showTooltip: true,
                showText: false,
              ),
              const SizedBox(width: 4),
              _buildConnectivityIndicator(isCompact: true),
            ],
          ),
          if (isCounterEnabled) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in _buildCounterContextChips(
                    customerSelectionProvider: customerSelectionProvider,
                    isCompact: true,
                    chipMaxWidth: 200,
                  )) ...[
                    chip,
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  contextIcon,
                  size: 14,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    contextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s12,
                      0.21,
                      const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String get _topBarOrderTitle {
    if (_editingLocalDraft != null) {
      final orderNumber = _editingLocalDraft!.orderNumber.trim();
      return orderNumber.isNotEmpty
          ? 'Edit Draft - #$orderNumber'
          : 'Edit Draft';
    }

    final selected = _selectedOrderFromOrderPanel;
    if (selected is Map) {
      final orderNumber = _firstNonEmptyTopBarValue([
        selected['order_number'],
        selected['display_order_id'],
        selected['order_id'],
        selected['id'],
      ]);
      return orderNumber != null ? 'Edit Order - #$orderNumber' : 'Edit Order';
    }

    return 'billing.new_order'.tr;
  }

  String? _firstNonEmptyTopBarValue(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  Map<dynamic, dynamic>? _asMap(dynamic value) {
    return value is Map ? value : null;
  }

  dynamic _readPath(dynamic source, List<String> path) {
    dynamic current = source;
    for (final key in path) {
      final map = _asMap(current);
      if (map == null) return null;
      current = map[key];
    }
    return current;
  }

  String? _cleanContextText(dynamic value) {
    final text = _firstNonEmptyTopBarValue([value]);
    if (text == null) return null;
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      return text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  String? _orderPropValue(dynamic order, String propCode) {
    final normalizedCode = propCode.trim().toUpperCase();
    final propsMap = _readPath(order, ['orderProps']);
    if (propsMap is Map) {
      for (final entry in propsMap.entries) {
        if (entry.key.toString().trim().toUpperCase() == normalizedCode) {
          return _cleanContextText(entry.value);
        }
      }
    }

    final propsList = _readPath(order, ['order_props']);
    if (propsList is List) {
      for (final prop in propsList) {
        final propMap = _asMap(prop);
        if (propMap == null) continue;
        final code = _cleanContextText(propMap['props_code'] ?? propMap['code'])
            ?.toUpperCase();
        if (code != normalizedCode) continue;
        return _cleanContextText(propMap['props_value'] ?? propMap['value']);
      }
    }

    return null;
  }

  String? _deliveryMethodNameForId(String? id) {
    final normalizedId = id?.trim();
    if (normalizedId == null || normalizedId.isEmpty) return null;
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if (method.id == normalizedId) return method.name;
    }
    return null;
  }

  String? _deliveryMethodIdForName(String? name) {
    final normalizedName = name?.trim().toLowerCase();
    if (normalizedName == null || normalizedName.isEmpty) return null;
    final deliveryMethodsProvider =
        Provider.of<DeliveryMethodsProvider>(context, listen: false);
    for (final method in deliveryMethodsProvider.deliveryMethods) {
      if (method.name.trim().toLowerCase() == normalizedName ||
          (method.code?.trim().toLowerCase() == normalizedName)) {
        return method.id;
      }
    }
    return null;
  }

  String? _tableNameForValue(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) return null;
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    for (final table in tableProvider.tables) {
      if (table.id == normalizedValue || table.name == normalizedValue) {
        return table.name;
      }
    }
    return normalizedValue;
  }

  String? _editingOrderCustomerLabelFrom(dynamic order) {
    return _firstNonEmptyTopBarValue([
      _readPath(order, ['customer_details', 'name']),
      _readPath(order, ['customer', 'name']),
      _readPath(order, ['user', 'name']),
      _readPath(order, ['order', 'customer_details', 'name']),
      _readPath(order, ['order', 'customer_name']),
      _readPath(order, ['customer_name']),
      _readPath(order, ['name']),
      _readPath(order, ['customer_details', 'phone']),
      _readPath(order, ['customer', 'phone']),
      _readPath(order, ['user', 'phone']),
      _readPath(order, ['order', 'customer_details', 'phone']),
      _readPath(order, ['order', 'customer_phone']),
      _readPath(order, ['customer_phone']),
      _readPath(order, ['phone']),
    ]);
  }

  bool _editingOrderHasCustomerData(dynamic order) {
    return _firstNonEmptyTopBarValue([
          _readPath(order, ['customer_details', 'customer_id']),
          _readPath(order, ['customer', 'customer_id']),
          _readPath(order, ['customer', 'id']),
          _readPath(order, ['cart', 'customer_id']),
          _readPath(order, ['order', 'customer_id']),
          _readPath(order, ['customer_id']),
          _editingOrderCustomerLabelFrom(order),
        ]) !=
        null;
  }

  String? _editingOrderDeliveryMethodIdFrom(dynamic order) {
    final deliveryMethodMap = _asMap(_readPath(order, ['delivery_method']));
    return _firstNonEmptyTopBarValue([
      _readPath(order, ['delivery_method_id']),
      deliveryMethodMap?['id'],
      deliveryMethodMap?['delivery_method_id'],
      _readPath(order, ['order', 'delivery_method_id']),
      _readPath(order, ['cart', 'delivery_method_id']),
    ]);
  }

  String? _editingOrderDeliveryMethodNameFrom(dynamic order) {
    final deliveryMethodMap = _asMap(_readPath(order, ['delivery_method']));
    final directDeliveryMethod = deliveryMethodMap == null
        ? _readPath(order, ['delivery_method'])
        : null;
    return _firstNonEmptyTopBarValue([
          _readPath(order, ['delivery_method_name']),
          deliveryMethodMap?['name'],
          deliveryMethodMap?['label'],
          directDeliveryMethod,
          _readPath(order, ['order', 'delivery_method_name']),
          _readPath(order, ['cart', 'delivery_method_name']),
        ]) ??
        _deliveryMethodNameForId(_editingOrderDeliveryMethodIdFrom(order));
  }

  String? _editingOrderTableNameFrom(dynamic order) {
    final tableMap = _asMap(_readPath(order, ['table']));
    final rawTable = _firstNonEmptyTopBarValue([
      _readPath(order, ['table_name']),
      tableMap?['name'],
      tableMap?['value'],
      _orderPropValue(order, 'TABLE'),
      _readPath(order, ['table_id']),
      tableMap?['id'],
      _readPath(order, ['order', 'table_id']),
    ]);
    return _tableNameForValue(rawTable);
  }

  void _captureEditingOrderDisplayContext(dynamic order) {
    if (order == null) {
      _clearEditingOrderDisplayContext();
      return;
    }

    final deliveryId = _editingOrderDeliveryMethodIdFrom(order);
    final deliveryName = _editingOrderDeliveryMethodNameFrom(order);
    _editingOrderCustomerLabel = _editingOrderCustomerLabelFrom(order);
    _editingOrderHasCustomer = _editingOrderHasCustomerData(order);
    _editingOrderTableName = _editingOrderTableNameFrom(order);
    _editingOrderHasTable = _editingOrderTableName != null;
    _editingOrderDeliveryMethodId =
        deliveryId ?? _deliveryMethodIdForName(deliveryName);
    _editingOrderDeliveryMethodName =
        deliveryName ?? _deliveryMethodNameForId(deliveryId) ?? deliveryId;
  }

  void _clearEditingOrderDisplayContext() {
    _editingOrderCustomerLabel = null;
    _editingOrderHasCustomer = false;
    _editingOrderTableName = null;
    _editingOrderHasTable = false;
    _editingOrderDeliveryMethodId = null;
    _editingOrderDeliveryMethodName = null;
  }

  String _counterCustomerLabel(
    CustomerSelectionProvider customerSelectionProvider, {
    required String fallback,
  }) {
    final providerLabel = _firstNonEmptyTopBarValue([
      customerSelectionProvider.selectedCustomerName,
      customerSelectionProvider.selectedCustomerPhone,
    ]);
    final panelLabel = _firstNonEmptyTopBarValue([
      _orderPanelKey.currentState?.selectedCustomerNameForDraft,
      _orderPanelKey.currentState?.selectedCustomerPhoneForDraft,
    ]);
    final editLabel = _editingOrderCustomerLabel;

    if (_selectedOrderFromOrderPanel != null &&
        editLabel != null &&
        (providerLabel == null ||
            (customerSelectionProvider.isDefaultCustomer &&
                providerLabel != editLabel))) {
      return editLabel;
    }

    return providerLabel ?? panelLabel ?? editLabel ?? fallback;
  }

  bool _hasCounterCustomer(
    CustomerSelectionProvider customerSelectionProvider,
  ) {
    return customerSelectionProvider.selectedCustomerID != null ||
        (customerSelectionProvider.selectedCustomerPhone?.trim().isNotEmpty ??
            false) ||
        _orderPanelKey.currentState?.selectedCustomerIdForDraft != null ||
        (_orderPanelKey.currentState?.selectedCustomerPhoneForDraft
                ?.trim()
                .isNotEmpty ??
            false) ||
        (_selectedOrderFromOrderPanel != null && _editingOrderHasCustomer);
  }

  String _counterDiningLabel({required String fallback}) {
    if (_selectedOrderFromOrderPanel != null &&
        (_editingOrderTableName?.isNotEmpty ?? false)) {
      return _editingOrderTableName!;
    }
    return _selectedTableName ?? fallback;
  }

  bool get _hasCounterDiningSelection {
    return _activeTableId != null ||
        (_selectedOrderFromOrderPanel != null && _editingOrderHasTable);
  }

  String _counterDeliveryLabel({required String fallback}) {
    if (_selectedOrderFromOrderPanel != null &&
        (_editingOrderDeliveryMethodName?.isNotEmpty ?? false)) {
      return _editingOrderDeliveryMethodName!;
    }
    return _selectedDeliveryMethodName ?? fallback;
  }

  bool get _hasCounterDeliverySelection {
    return (_selectedDeliveryMethodId?.isNotEmpty ?? false) ||
        (_selectedOrderFromOrderPanel != null &&
            ((_editingOrderDeliveryMethodId?.isNotEmpty ?? false) ||
                (_editingOrderDeliveryMethodName?.isNotEmpty ?? false)));
  }

  String _appDefaultPaymentMethodLabel() {
    final raw = Provider.of<AppSettingsProvider>(context, listen: false)
        .appSettings
        ?.defaultPaymentMethod
        .trim()
        .toUpperCase();
    if (raw == null || raw.isEmpty) return 'CASH';
    return raw;
  }

  String _counterPaymentLabel({required String fallback}) {
    return _orderPanelKey.currentState?.selectedPaymentMethodLabelForDraft ??
        _appDefaultPaymentMethodLabel();
  }

  bool get _hasCounterPaymentSelection {
    // App default (usually CASH) is always treated as selected for the chip,
    // matching checkout autofill — even before OrderPanel hydrates.
    return _orderPanelKey.currentState?.hasPaymentMethodSelectedForDraft ??
        true;
  }

  /// Ensures OrderPanel is mounted (mobile Products tab keeps it Offstage)
  /// before opening selection modals from the top-bar chips.
  Future<OrderPanelState?> _ensureOrderPanelState() async {
    var state = _orderPanelKey.currentState;
    if (state != null) return state;

    // Fallback: switch to Orders so the panel mounts, then retry.
    if (_currentMobileView != MobileView.orders) {
      setState(() => _currentMobileView = MobileView.orders);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      state = _orderPanelKey.currentState;
    }
    return state;
  }

  Widget _buildTopBarContextChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCompact = false,
    double? maxWidth,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints:
              BoxConstraints(maxWidth: maxWidth ?? (isCompact ? 108 : 150)),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: isCompact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.10) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  isSelected ? color.withOpacity(0.45) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: isCompact ? 13 : 14,
                  color: isSelected ? color : Colors.grey.shade600),
              SizedBox(width: isCompact ? 5 : 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    isCompact ? FontSize.s11 : FontSize.s12,
                    0.21,
                    isSelected ? color : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarActions({bool isCompact = false}) {
    final buttonSize = isCompact ? 30.0 : 34.0;
    final iconSize = isCompact ? 18.0 : 20.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer<KeyboardProvider>(
          builder: (context, keyboardProvider, child) {
            return IconButton(
              visualDensity: VisualDensity.compact,
              constraints:
                  BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
              icon: Icon(
                keyboardProvider.showKeyboardFeature
                    ? Icons.keyboard_hide
                    : Icons.keyboard,
                size: iconSize,
                color: keyboardProvider.showKeyboardFeature
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade600,
              ),
              tooltip: keyboardProvider.showKeyboardFeature
                  ? 'billing.keyboard_hide'.tr
                  : 'billing.keyboard_show'.tr,
              onPressed: () {
                if (keyboardProvider.showKeyboardFeature) {
                  keyboardProvider.featureOff();
                  keyboardProvider.clear();
                } else {
                  keyboardProvider.featureOn();
                }
              },
            );
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints:
              BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
          icon: Icon(
            Icons.help_outline,
            size: iconSize,
            color: Colors.grey.shade600,
          ),
          tooltip: 'Keyboard Shortcuts (Ctrl+H)',
          onPressed: () => KeyboardShortcutsHelpDialog.show(
            context,
            mode: KeyboardShortcutsHelpMode.restaurant,
          ),
        ),
        Consumer<AppFontProvider>(
          builder: (context, fontProvider, child) {
            return IconButton(
              visualDensity: VisualDensity.compact,
              constraints:
                  BoxConstraints(minWidth: buttonSize, minHeight: buttonSize),
              icon: Icon(
                Icons.text_fields,
                size: iconSize,
                color: fontProvider.fontSizeLevel > 0
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade600,
              ),
              tooltip: 'Font: ${fontProvider.fontSizeLevelName}',
              onPressed: fontProvider.cycleFontSize,
            );
          },
        ),
        OpenCashDrawerButton(color: Colors.grey.shade600),
        const SyncButton(
          showTooltip: true,
          showText: false,
        ),
        _buildConnectivityIndicator(isCompact: isCompact),
      ],
    );
  }

  Widget _buildConnectivityIndicator({bool isCompact = false}) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        final hasInternet = billingProvider.hasInternet;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 3 : 4,
            vertical: isCompact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: hasInternet
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasInternet ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Icon(
            hasInternet ? Icons.wifi : Icons.wifi_off,
            size: isCompact ? 14 : 16,
            color: hasInternet ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildTopBarCounterToggle({required bool isCompact}) {
    final isEnabled = _isCounterBillingMode;

    return Tooltip(
      message: isEnabled
          ? 'Disable quick counter billing'
          : 'Enable quick counter billing',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _setCounterBillingMode(!isEnabled),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 14,
              vertical: isCompact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.point_of_sale_rounded,
                  size: isCompact ? 15 : 16,
                  color: const Color(0xFF64748B),
                ),
                SizedBox(width: isCompact ? 6 : 8),
                Text(
                  isCompact
                      ? (isEnabled ? 'Counter On' : 'Counter')
                      : 'Quick Counter',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    isCompact ? FontSize.s12 : FontSize.s13,
                    0.21,
                    const Color(0xFF0F766E),
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isCompact ? 30 : 34,
                  height: isCompact ? 16 : 18,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: isEnabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: isCompact ? 12 : 14,
                      height: isCompact ? 12 : 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarNewOrderButton({bool isCompact = false}) {
    return SizedBox(
      height: isCompact ? 30 : 34,
      child: ElevatedButton.icon(
        onPressed: _startNewCounterOrder,
        icon: Icon(Icons.add_shopping_cart_rounded, size: isCompact ? 13 : 14),
        label: Text(
          'billing.new_order'.tr,
          style: buildCustomStyle(
            FontWeightManager.bold,
            isCompact ? FontSize.s10 : FontSize.s11,
            0.21,
            Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Size screenSize) {
    // Keep OrderPanel mounted (Offstage) even on Products/Tables so top-bar
    // customer/payment chips and New Order reset can use _orderPanelKey.
    final showOrders = _currentMobileView == MobileView.orders;
    return Column(
      children: [
        _buildAttenderTopBar(isCompact: true, isMobile: true),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: !showOrders,
                child: TickerMode(
                  enabled: showOrders,
                  child: _buildOrdersView(screenSize),
                ),
              ),
              if (!showOrders)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: switch (_currentMobileView) {
                    MobileView.tables => _buildTablesView(screenSize),
                    MobileView.products => _buildMobileProductsView(screenSize),
                    MobileView.orders => const SizedBox.shrink(),
                  },
                ),
            ],
          ),
        ),
        _buildMobileBottomNav(),
      ],
    );
  }

  // Full-page products view (Store mode home): delivery chip rail on top,
  // products grid, and a sticky cart bar when the cart has items.
  Widget _buildMobileProductsView(Size screenSize) {
    return Column(
      key: const ValueKey('products_view'),
      children: [
        _buildMobileDeliveryRail(),
        Expanded(
          child: MenuPanel(
            onCategoryChanged: (cid) => setState(() => _activeCategoryId = cid),
            activeCategoryId: _activeCategoryId,
            onItemAdd: _handleItemAdd,
            screenSize: screenSize,
            selectedOrder: _selectedOrderFromOrderPanel,
            headerTitle: _menuTitle,
          ),
        ),
        _buildMobileCartBar(),
      ],
    );
  }

  Widget _buildMobileDeliveryRail() {
    return Consumer<DeliveryMethodsProvider>(
      builder: (context, deliveryMethodsProvider, _) {
        final methods = deliveryMethodsProvider.deliveryMethods;
        if (methods.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.delivery_dining,
                  color: Color(0xFF1A56DB),
                  size: 18,
                ),
                const SizedBox(width: 8),
                for (final method in methods) ...[
                  _buildMobileDeliveryChip(method.id, method.name),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDeliveryChip(String id, String name) {
    final isSelected = _selectedDeliveryMethodId == id;
    return GestureDetector(
      onTap: () => _selectDeliveryMethod(id, name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A56DB)
              : const Color(0xFF1A56DB).withOpacity(0.07),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A56DB)
                : const Color(0xFF1A56DB).withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            isSelected ? Colors.white : const Color(0xFF1A56DB),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Sticky "N items • total → View Order" bar shown while the cart has items.
  Widget _buildMobileCartBar() {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, _) {
        final items = localProductProvider.cartItems;
        final itemCount =
            items.fold<int>(0, (sum, item) => sum + item.quantity.toInt());
        if (itemCount == 0) return const SizedBox.shrink();

        double total = 0;
        for (final item in items) {
          total += (item.price ?? 0) * item.quantity;
        }
        final currency =
            Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings
                    ?.currency ??
                'INR';

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Material(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () =>
                  setState(() => _currentMobileView = MobileView.orders),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$currency ${total.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'restaurant.view_order'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (widget.storeMode)
              _buildMobileNavItem(
                icon: Icons.storefront_rounded,
                label: 'restaurant.products_tab'.tr,
                isSelected: _currentMobileView == MobileView.products,
                onTap: () {
                  if (_currentMobileView != MobileView.products) {
                    setState(() => _currentMobileView = MobileView.products);
                  }
                },
              )
            else ...[
              _buildMobileNavItem(
                icon: Icons.table_restaurant_rounded,
                label: 'restaurant.tables_tab'.tr,
                isSelected: _currentMobileView == MobileView.tables,
                onTap: () {
                  if (_currentMobileView != MobileView.tables) {
                    setState(() => _currentMobileView = MobileView.tables);
                  }
                },
              ),
              _buildMobileNavItem(
                icon: Icons.restaurant_menu_rounded,
                label: _menuTitle,
                isSelected: false,
                onTap: () => _showProductsBottomSheet(context),
              ),
            ],
            Consumer<LocalProductProvider>(
              builder: (context, localProductProvider, _) {
                final itemCount = localProductProvider.cartItems.fold<int>(
                  0,
                  (sum, item) => sum + item.quantity.toInt(),
                );
                return _buildMobileNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'restaurant.order_tab'.tr,
                  isSelected: _currentMobileView == MobileView.orders,
                  badgeCount: itemCount,
                  onTap: () {
                    if (_currentMobileView != MobileView.orders) {
                      setState(() => _currentMobileView = MobileView.orders);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final color =
        isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB).withOpacity(0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -4,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF233C),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: buildCustomStyle(
                    isSelected
                        ? FontWeightManager.bold
                        : FontWeightManager.medium,
                    FontSize.s11,
                    0.21,
                    color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Full-page tables view for mobile
  Widget _buildTablesView(Size screenSize) {
    return Column(
      key: const ValueKey('tables_view'),
      children: [
        // Tables Panel - full page (has its own "Tables" header, so no
        // extra page header here — vertical space is precious on phones)
        Expanded(
          child: TablesPanel(
            isMobile: true,
            showTables: !widget.storeMode,
            activeTableId: _activeTableId,
            onSelect: (id) {
              // Reuse the shared selection logic (auto-save, payment modal
              // reset, current-order tab) then navigate to the orders view.
              _selectDiningTable(id);
              setState(() => _currentMobileView = MobileView.orders);
            },
            selectedDeliveryMethodId: _selectedDeliveryMethodId,
            showDeliveryMethods: _isCounterBillingMode,
            onDeliveryMethodSelected: (id, name) {
              _selectDeliveryMethod(id, name);
              if (id.isNotEmpty) {
                setState(() => _currentMobileView = MobileView.orders);
              }
            },
            screenSize: screenSize,
          ),
        ),
      ],
    );
  }

  // Full-page orders view for mobile
  Widget _buildOrdersView(Size screenSize) {
    return Column(
      key: const ValueKey('orders_view'),
      children: [
        // Header with back button — styled as an inset card so it aligns
        // with the top bar above and the order panel below.
        Container(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
                tooltip:
                    widget.storeMode ? 'restaurant.back_to_products'.tr : 'restaurant.back_to_tables'.tr,
                onPressed: () {
                  setState(() {
                    _currentMobileView = widget.storeMode
                        ? MobileView.products
                        : MobileView.tables;
                  });
                },
              ),
              const SizedBox(width: 4),
              Icon(
                _activeTableId != null
                    ? Icons.table_restaurant_rounded
                    : _selectedDeliveryMethodId != null
                        ? Icons.local_shipping_rounded
                        : Icons.receipt_long,
                color: const Color(0xFF2563EB),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedTableName ?? _selectedDeliveryMethodName ?? 'Orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.30,
                    const Color(0xFF1E293B),
                  ),
                ),
              ),
              // Menu shortcut (also available in the bottom nav)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon:
                    const Icon(Icons.restaurant_menu, color: Color(0xFF2563EB)),
                onPressed: () => _showProductsBottomSheet(context),
                tooltip: _menuTitle,
              ),
            ],
          ),
        ),
        // Orders Panel - full page
        Expanded(
          child: OrderPanel(
            key: _orderPanelKey,
            isCompact: true,
            tableId: _activeTableId,
            preselectedDeliveryMethodId: _selectedDeliveryMethodId,
            preselectedDeliveryMethodName: _selectedDeliveryMethodName,
            screenSize: screenSize,
            onSendToKitchen: _sendOrderToKitchenWithLoading,
            onNewOrder: _handleNewOrder,
            onPrintOrder: _printOrderWithLoading,
            onKotBill: _sendKotBillWithLoading,
            allowCounterBilling: widget.allowCounterBillingFromAttender,
            isCounterBillingMode: _isCounterBillingMode,
            onOrderSelected: (order) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedOrderFromOrderPanel = order;
                    if (order != null) {
                      _editingLocalDraft = null;
                      _captureEditingOrderDisplayContext(order);
                    } else {
                      _clearEditingOrderDisplayContext();
                    }
                  });
                }
              });
            },
            selectedOrderFromParent: _selectedOrderFromOrderPanel,
            refreshCounter: _refreshCounter,
            isLoadingSendToKitchen: _isLoadingSendToKitchen,
            isLoadingPrint: _isLoadingPrint,
            isLoadingKotBill: _isLoadingKotBill,
            onLocalDraftLoaded: _applyLocalDraftContext,
            onLocalDraftSaved: _resetCounterOrderContextAfterSave,
            onEditedOrderConfirmed: _resetCounterOrderContextAfterSave,
            onCheckoutActionLoadingChanged: _setCounterCheckoutLoading,
            hideFooterActionButtons: widget.storeMode,
            hideOngoingOrdersTab: widget.storeMode,
          ),
        ),
        // Store mode hides the order panel's own footer buttons, so the
        // checkout actions live in this bar instead (same as desktop).
        if (widget.storeMode) _buildCounterActionBar(showShortcuts: false),
      ],
    );
  }

  // Show products as a bottom sheet
  void _showProductsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restaurant_menu_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _menuTitle,
                              style: buildCustomStyle(
                                FontWeightManager.bold,
                                FontSize.s16,
                                0.30,
                                const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Products panel
                    Expanded(
                      child: MenuPanel(
                        onCategoryChanged: (cid) {
                          // Update both parent and modal state
                          setState(() => _activeCategoryId = cid);
                          setModalState(() => _activeCategoryId = cid);
                        },
                        activeCategoryId: _activeCategoryId,
                        onItemAdd: (product, quantity) async {
                          final itemWasAdded =
                              await _handleItemAdd(product, quantity);
                          // Optionally close the bottom sheet after adding
                          // Navigator.pop(context);
                          return itemWasAdded;
                        },
                        screenSize: MediaQuery.of(context).size,
                        selectedOrder: _selectedOrderFromOrderPanel,
                        headerTitle: _menuTitle,
                      ),
                    ),
                    // Pinned "View Order" footer (local cart only; hidden
                    // while editing an existing order, which adds via API)
                    Consumer<LocalProductProvider>(
                      builder: (context, localProductProvider, _) {
                        final itemCount =
                            localProductProvider.cartItems.fold<int>(
                          0,
                          (sum, item) => sum + item.quantity.toInt(),
                        );
                        if (itemCount == 0) return const SizedBox.shrink();
                        return SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _currentMobileView = MobileView.orders;
                                  });
                                },
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'View Order  •  $itemCount item${itemCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _setCounterBillingMode(bool enabled) {
    if (!widget.allowCounterBillingFromAttender) {
      showScaffoldError(
        context: context,
        message: 'restaurant.counter_billing_disabled'.tr,
      );
      return;
    }

    if (!enabled) {
      setState(() {
        _isCounterBillingMode = false;
      });
      _orderPanelKey.currentState?.resetPaymentModalFlag();
      _orderPanelKey.currentState?.showCurrentOrderTab();
      return;
    }

    setState(() {
      _isCounterBillingMode = true;
    });
    _applyDefaultCounterDeliveryMethodContext();
    _orderPanelKey.currentState?.resetPaymentModalFlag();
    _orderPanelKey.currentState?.showCurrentOrderTab();
  }

  void _startNewCounterOrder() {
    if (!widget.allowCounterBillingFromAttender) return;

    _autoSaveCurrentTableBeforeSwitch();
    Provider.of<LocalProductProvider>(context, listen: false).clearCart();

    setState(() {
      _isCounterBillingMode = true;
      _activeTableId = null;
      _selectedTableName = null;
      _selectedOrderFromOrderPanel = null;
      _editingLocalDraft = null;
      _selectedDeliveryMethodId = null;
      _selectedDeliveryMethodName = null;
      _clearEditingOrderDisplayContext();
      _refreshCounter = (_refreshCounter ?? 0) + 1;
    });

    _applyDefaultCounterDeliveryMethodContext();
    _orderPanelKey.currentState?.resetActiveOrderContext();
    _orderPanelKey.currentState?.showCurrentOrderTab();
    // Order panel applies default payment inside reset; rebuild parent so the
    // top-bar Payment chip picks up the restored default label.
    if (mounted) setState(() {});
  }

  Future<bool> _handleItemAdd(GetProduct product, int quantity) async {
    var itemWasAdded = false;
    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      // Only call API when editing an existing saved order
      final bool isEditingExistingOrder = _selectedOrderFromOrderPanel != null;

      if (isEditingExistingOrder) {
        // Use the cart_id from the selected saved order
        int? targetCartId = int.tryParse((_selectedOrderFromOrderPanel['cart']
                        ?['id'] ??
                    _selectedOrderFromOrderPanel['cart_id'])
                ?.toString() ??
            '');

        // Get the customer ID from the selected order (not the logged-in user ID)
        final customerId = _selectedOrderFromOrderPanel['cart']
                ?['customer_id'] ??
            _selectedOrderFromOrderPanel['customer_id'] ??
            authModel.userId ??
            1;

        debugPrint(
            '🔄 Editing existing order - Using cart_id: $targetCartId, customerId: $customerId');

        debugPrint('➡️ Calling CartProvider.addToCartAPI');
        final addResponse = await cartProvider.addToCartAPI(
          customerId: int.parse(customerId.toString()),
          productId: product.productId!,
          quantity: quantity,
          accessToken: authModel.token ?? '',
          unitPrice: product.price?.price?.toString(),
          cartId: targetCartId,
        );
        debugPrint('✅ addToCartAPI Response: $addResponse');

        // Check if the API call was successful
        if (isApiSuccess(addResponse)) {
          itemWasAdded = true;
          if (mounted) {
            showScaffold(
              context: context,
              message: 'Added ${product.productName} to existing order',
            );

            // Wait for server update then refresh the selected order and list silently
            await Future.delayed(const Duration(milliseconds: 1000));
            setState(() {
              _refreshCounter = (_refreshCounter ?? 0) + 1;
            });
            await _orderPanelKey.currentState?.refreshSavedOrdersSilently();
            // Scroll to and highlight the newly added item so it's impossible to miss
            if (product.productId != null) {
              _orderPanelKey.currentState
                  ?.scrollToAndHighlightNewItem(product.productId!);
            }

            // Ensure parent widget also updates its state
            if (mounted) {
              setState(() {});
            }
          }
        } else {
          // API call failed, show error message
          if (mounted) {
            showScaffoldError(
              context: context,
              message:
                  'Failed to add ${product.productName}: ${addResponse?['message'] ?? 'Unknown error'}',
            );
          }
        }
      } else {
        // New order: strictly local cart only (no API here)
        debugPrint(
            '🛒 Adding product to local cart via LocalProductProvider (new order)');
        final localProductProvider =
            Provider.of<LocalProductProvider>(context, listen: false);
        final cartQuantityBefore = localProductProvider.cartItems.fold<num>(
          0,
          (sum, item) => sum + item.quantity,
        );

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
        );

        final cartQuantityAfter = localProductProvider.cartItems.fold<num>(
          0,
          (sum, item) => sum + item.quantity,
        );
        itemWasAdded = cartQuantityAfter > cartQuantityBefore;

        if (mounted) {
          if (itemWasAdded) {
            showScaffold(
              context: context,
              message: _activeTableId != null
                  ? 'Added ${product.productName} to Table $_activeTableId'
                  : 'Added ${product.productName} to order',
            );
            // Ensure the OrderPanel shows Current Order immediately
            setState(() {});
            _orderPanelKey.currentState
                ?.showCurrentOrderTab(preserveLoadedDraftMetadata: true);
          }
        }
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to add item: ${e.toString()}',
      );
    }

    if (itemWasAdded && mounted) {
      _menuPanelKey.currentState?.focusSearch();
    }
    return itemWasAdded;
  }

  Future<dynamic> _sendOrderToKitchen() async {
    if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(context)) {
      return null;
    }
    if (_activeTableId == null && _selectedDeliveryMethodId == null) {
      showScaffoldError(
        context: context,
        message: 'restaurant.select_table_first'.tr,
      );
      return null;
    }

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      final cartItems = _cartItemsForKitchenSync(localProductProvider);
      if (cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'restaurant.no_items_kitchen'.tr,
        );
        return null;
      }
      final loadedDraftIdForCleanup =
          _loadedLocalDraftIdForKitchenSync(localProductProvider);

      // Convert local cart items to API format
      List<Map<String, dynamic>> items = [];
      for (var item in cartItems) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price?.toString() ?? '0',
          'mrp': item.mrp?.toString() ?? '0',
          'stock_id': item.selectedStock?.id, // Include stock_id if available
          if (item.comment != null && item.comment!.isNotEmpty)
            'comment': item.comment,
        });
      }

      // Get cart total from local provider (apply round-off when enabled)
      final total = _totalForKitchenItems(cartItems);

      // Call the addToOrderAPI with status: "new"
      debugPrint('➡️ Calling CartProvider.addToOrderAPI');
      final currentComment = _orderPanelKey.currentState?.orderComment ?? "";
      final manualComment = currentComment.trim();
      final resolvedCustomerId =
          _orderPanelKey.currentState?.selectedCustomerIdForDraft;
      final resolvedDeliveryMethodId =
          _selectedDeliveryMethodId ?? _resolveDefaultDeliveryMethodId();
      final sendToKitchenRequestBody = {
        'items': items,
        'cart_id': 0,
        'transaction_number': '',
        'total_price': total.toStringAsFixed(2),
        'customer_id': resolvedCustomerId,
        'payment_method': null,
        'paid_amount': null,
        'payment_methods': <String>[],
        'paid_methods': <Map<String, dynamic>>[],
        'balance': '0',
        'coupon_id': null,
        'comment': manualComment.isNotEmpty ? manualComment : null,
        'delivery_method_id': resolvedDeliveryMethodId,
        'car_number': null,
        'status': 'new',
        'delivery_date': null,
        'delivery_time': null,
        'table': _activeTableId,
      };
      debugPrint(
          '📤 SEND TO KITCHEN request body: ${json.encode(sendToKitchenRequestBody)}');
      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0, // Use 0 for new cart since we're creating a new order
        accessToken: authModel.token ?? "",
        transactionId: "", // Not applicable for initial kitchen order
        totalPrice: total.toStringAsFixed(2),
        customerId: resolvedCustomerId,
        customerPhone: null, // Not applicable
        paymentMethod: null, // Not applicable
        paidAmount: null, // Not applicable
        paymentMethods: [], // Not applicable
        paidMethods: [], // Not applicable
        balanceAmount: "0", // Not applicable
        couponId: null, // Not applicable
        comment: manualComment.isNotEmpty ? manualComment : null,
        deliveryMethodId: resolvedDeliveryMethodId,
        carNumber: null, // Not applicable
        status: "new", // Set status to "new"
        deliveryDate: null, // Not applicable
        deliveryTime: null, // Not applicable
        tableId: _activeTableId,
      );
      debugPrint('📥 SEND TO KITCHEN response body: ${json.encode(response)}');

      if (await SubscriptionActionGuard.handleBackendResponse(
        context,
        response,
      )) {
        return null;
      }
      if (response["order_id"] != null) {
        showScaffold(
          context: context,
          message:
              'Order for $_activeTableId sent to kitchen successfully! Order ID: ${response["order_id"]}',
        );

        // Clear the local cart after successful submission
        if (cartItems.isNotEmpty) {
          debugPrint('🗑️ Clearing local cart after successful kitchen order');
          localProductProvider.clearCart();
          localProductProvider.clearCurrentOrder();
        }
        _orderPanelKey.currentState?.clearCurrentOrderComment();

        // If a local draft was loaded, remove it after successful send
        _orderPanelKey.currentState
            ?.deleteLoadedDraftIfAny(fallbackDraftId: loadedDraftIdForCleanup);
        if (loadedDraftIdForCleanup != null &&
            _editingLocalDraft?.id == loadedDraftIdForCleanup &&
            mounted) {
          setState(() {
            _editingLocalDraft = null;
          });
        }

        final openedCreatedOrder =
            await _openCounterKitchenOrderAfterSend(response);
        if (!openedCreatedOrder) {
          // Refresh saved orders for the currently opened table/delivery method
          if (mounted &&
              (_activeTableId != null || _selectedDeliveryMethodId != null)) {
            debugPrint(
                '🔄 Refreshing saved orders after sending order to kitchen');
            await Future.delayed(const Duration(
                milliseconds: 1000)); // Wait for server to process
            _orderPanelKey.currentState?.refreshSavedOrders();
          }

          _resetCounterOrderContextAfterKitchenSend();
        }
        return response;
      } else {
        showScaffoldError(
          context: context,
          message:
              'Failed to send order to kitchen: ${response["message"] ?? "Unknown error"}',
        );
        return null;
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Failed to send order to kitchen: ${e.toString()}',
      );
      return null;
    }
  }

  List<LocalCartItem> _cartItemsForKitchenSync(
    LocalProductProvider localProductProvider,
  ) {
    final loadedDraftId = _orderPanelKey.currentState?.loadedLocalDraftId ??
        _editingLocalDraft?.id;
    if (loadedDraftId != null && loadedDraftId.isNotEmpty) {
      if (localProductProvider.currentOrder?.id == loadedDraftId &&
          localProductProvider.cartItems.isNotEmpty) {
        return localProductProvider.getCartItems();
      }

      final draft = localProductProvider.findOrderById(loadedDraftId);
      if (draft != null) {
        return List<LocalCartItem>.from(draft.items);
      }
    }

    return localProductProvider.getCartItems();
  }

  String? _loadedLocalDraftIdForKitchenSync(
    LocalProductProvider localProductProvider,
  ) {
    final candidateIds = <String?>[
      _orderPanelKey.currentState?.loadedLocalDraftId,
      _editingLocalDraft?.id,
      localProductProvider.currentOrder?.id,
    ];

    for (final id in candidateIds) {
      if (id != null &&
          id.isNotEmpty &&
          localProductProvider.findOrderById(id) != null) {
        return id;
      }
    }

    return null;
  }

  double _totalForKitchenItems(List<LocalCartItem> cartItems) {
    final total = cartItems.fold<double>(
      0,
      (sum, item) => sum + ((item.price ?? 0) * item.quantity).toDouble(),
    );
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings?.priceRoundOff == true) {
      return AmountHelper.roundOffAmount(total);
    }
    return total;
  }

  String _resolveDefaultDeliveryMethodId() {
    return _resolveDefaultDeliveryMethod()?.id ?? kFallbackDeliveryMethodId;
  }

  String? _extractTokenNumber(dynamic order) {
    if (order is! Map) return null;

    String? tokenNumber = order['token_number']?.toString();
    if (tokenNumber == null || tokenNumber.isEmpty) {
      final propsMap = order['orderProps'];
      if (propsMap is Map && propsMap['ORDER_TOKEN_NUMBER'] != null) {
        tokenNumber = propsMap['ORDER_TOKEN_NUMBER']?.toString();
      }
    }
    if (tokenNumber == null || tokenNumber.isEmpty) {
      final propsList = order['order_props'];
      if (propsList is List) {
        try {
          final match = propsList.firstWhere(
            (e) =>
                (e is Map) &&
                (e['code'] ?? e['props_code'])?.toString().toUpperCase() ==
                    'ORDER_TOKEN_NUMBER',
            orElse: () => null,
          );
          if (match is Map &&
              (match['value'] ?? match['props_value']) != null) {
            tokenNumber = (match['value'] ?? match['props_value']).toString();
          }
        } catch (_) {}
      }
    }
    if (tokenNumber != null) {
      tokenNumber = tokenNumber.trim();
      if (tokenNumber.startsWith('"') && tokenNumber.endsWith('"')) {
        tokenNumber = tokenNumber.substring(1, tokenNumber.length - 1);
      }
    }

    return tokenNumber;
  }

  Future<void> _handleNewOrder() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    // Clear the local cart first
    if (localProductProvider.cartItems.isNotEmpty) {
      debugPrint('🗑️ Clearing local cart via LocalProductProvider');
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();
    }

    // Clear the cart from API if it exists
    if (cartProvider.cartData.isNotEmpty &&
        cartProvider.cartData.first.cartItems?.isNotEmpty == true) {
      debugPrint('➡️ Calling CartProvider.clearCartAPI');
      await cartProvider.clearCartAPI(
        customerId: cartProvider.cartData.first.customerId ?? 1,
        productId: cartProvider.cartData.first.cartItems!.first.id ??
            0, // A dummy product ID, as clearCartAPI uses cart_item_id only if provided
        accessToken: Provider.of<AuthModel>(context, listen: false).token ?? '',
      );
    }

    // Deselect active order context
    setState(() {
      _activeTableId = null;
      _selectedTableName = null;
      _selectedDeliveryMethodId = null;
      _selectedDeliveryMethodName = null;
      _selectedOrderFromOrderPanel = null;
      _editingLocalDraft = null;
      _clearEditingOrderDisplayContext();
    });
    _applyDefaultCounterDeliveryMethodContext();

    _orderPanelKey.currentState?.resetActiveOrderContext();
    _orderPanelKey.currentState?.showCurrentOrderTab();

    showScaffold(
      context: context,
      message: 'New order started. Cart and context cleared.',
    );
  }

  Future<void> _sendOrderToKitchenWithLoading() async {
    setState(() {
      _isLoadingSendToKitchen = true;
    });

    try {
      await _sendOrderToKitchen();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSendToKitchen = false;
        });
      }
    }
  }

  bool _shouldAutoMarkServedForKotBill() {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    return _isKotBillEnabled(appSettings) &&
        (appSettings?.kotBillAutoMarkServed ?? false);
  }

  Future<void> _sendKotBillWithLoading() async {
    if (_isLoadingKotBill) return;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    if (!_isKotBillEnabled(appSettings)) {
      showScaffoldError(
        context: context,
        message: 'KOT + Bill is disabled in app settings',
      );
      return;
    }
    if (!_isKotBillAllowedForCurrentContext(appSettings)) {
      showScaffoldError(
        context: context,
        message: 'KOT + Bill is not allowed for dine-in/table orders',
      );
      return;
    }
    setState(() {
      _isLoadingKotBill = true;
    });

    try {
      final response = await _sendOrderToKitchen();
      if (response == null || !mounted) return;

      final orderPanelState = _orderPanelKey.currentState;
      if (orderPanelState == null) {
        showScaffoldError(
          context: context,
          message: 'restaurant.order_panel_not_ready'.tr,
        );
        return;
      }

      await orderPanelState.prepareCounterKotBill(
        autoMarkServed: _shouldAutoMarkServedForKotBill(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingKotBill = false;
        });
      }
    }
  }

  Future<void> _printOrderWithLoading() async {
    if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(context)) {
      return;
    }
    if (_activeTableId == null && _selectedDeliveryMethodId == null) {
      showScaffoldError(
        context: context,
        message: 'restaurant.select_table_first'.tr,
      );
      return;
    }

    setState(() {
      _isLoadingPrint = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Get the selected draft/current cart data BEFORE sending.
      final cartItems = _cartItemsForKitchenSync(localProductProvider);

      if (cartItems.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'No items in cart to print',
        );
        return;
      }
      final loadedDraftIdForCleanup =
          _loadedLocalDraftIdForKitchenSync(localProductProvider);

      // Capture data for printing BEFORE clearing
      final tableName =
          _selectedTableName ?? _selectedDeliveryMethodName ?? 'Order';
      final showTableLabel =
          _selectedTableName != null && _selectedTableName!.trim().isNotEmpty;
      final currentComment = _orderPanelKey.currentState?.orderComment ?? "";
      final manualComment = currentComment.trim();
      final total = _totalForKitchenItems(cartItems);

      // Build print items BEFORE clearing cart
      List<Map<String, dynamic>> printItems = [];
      for (var item in cartItems) {
        printItems.add({
          'productName': item.product.productName ?? '',
          'quantity': item.quantity.toString(),
          'unitPrice': item.price?.toStringAsFixed(2) ?? '0.00',
          'totalPrice': ((item.price ?? 0) * item.quantity).toStringAsFixed(2),
          'mrp': item.mrp?.toStringAsFixed(2) ??
              item.price?.toStringAsFixed(2) ??
              '0.00',
          if (item.comment != null && item.comment!.isNotEmpty)
            'notes': item.comment,
        });
      }

      // Convert local cart items to API format
      List<Map<String, dynamic>> items = [];
      for (var item in cartItems) {
        items.add({
          'product_id': item.product.productId,
          'quantity': item.quantity,
          'price': item.price?.toString() ?? '0',
          'mrp': item.mrp?.toString() ?? '0',
          'stock_id': item.selectedStock?.id,
          if (item.comment != null && item.comment!.isNotEmpty)
            'comment': item.comment,
        });
      }

      // Call the addToOrderAPI with status: "new"
      debugPrint('➡️ Print: Calling CartProvider.addToOrderAPI');
      final resolvedCustomerId =
          _orderPanelKey.currentState?.selectedCustomerIdForDraft;
      final resolvedDeliveryMethodId =
          _selectedDeliveryMethodId ?? _resolveDefaultDeliveryMethodId();
      final response = await cartProvider.addToOrderAPI(
        items: items,
        cartIds: 0,
        accessToken: authModel.token ?? "",
        transactionId: "",
        totalPrice: total.toStringAsFixed(2),
        customerId: resolvedCustomerId,
        customerPhone: null,
        paymentMethod: null,
        paidAmount: null,
        paymentMethods: [],
        paidMethods: [],
        balanceAmount: "0",
        couponId: null,
        comment: manualComment.isNotEmpty ? manualComment : null,
        deliveryMethodId: resolvedDeliveryMethodId,
        carNumber: null,
        status: "new",
        deliveryDate: null,
        deliveryTime: null,
        tableId: _activeTableId,
      );

      if (await SubscriptionActionGuard.handleBackendResponse(
        context,
        response,
      )) {
        return;
      }
      if (response["order_id"] != null) {
        // Get order number from API response
        final orderNumber = response["order_number"]?.toString() ??
            'ORD-${response["order_id"]}';
        String? tokenNumber = _extractTokenNumber(response);
        if ((tokenNumber == null || tokenNumber.isEmpty) &&
            (_activeTableId != null || _selectedDeliveryMethodId != null)) {
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            final savedResponse = await cartProvider.listSavedOrders(
              accessToken: authModel.token ?? '',
              tableId: _activeTableId,
              deliveryMethodId:
                  _activeTableId == null ? _selectedDeliveryMethodId : null,
            );
            if (savedResponse['status'] == 'success') {
              final orders = savedResponse['orders'] as List<dynamic>;
              final targetOrder = orders.firstWhere(
                (o) =>
                    o['order_id'] == response['order_id'] ||
                    o['id'] == response['order_id'] ||
                    o['order_number']?.toString() == orderNumber,
                orElse: () => null,
              );
              if (targetOrder != null) {
                tokenNumber = _extractTokenNumber(targetOrder);
              }
            }
          } catch (_) {}
        }

        showScaffold(
          context: context,
          message: '${'restaurant.order_sent_kitchen'.tr}$orderNumber',
        );

        // Clear the local cart after successful submission
        debugPrint('🗑️ Clearing local cart after successful kitchen order');
        localProductProvider.clearCart();
        localProductProvider.clearCurrentOrder();
        _orderPanelKey.currentState?.clearCurrentOrderComment();

        // If a local draft was loaded, remove it after successful send
        _orderPanelKey.currentState
            ?.deleteLoadedDraftIfAny(fallbackDraftId: loadedDraftIdForCleanup);
        if (loadedDraftIdForCleanup != null &&
            _editingLocalDraft?.id == loadedDraftIdForCleanup &&
            mounted) {
          setState(() {
            _editingLocalDraft = null;
          });
        }

        final openedCreatedOrder =
            await _openCounterKitchenOrderAfterSend(response);
        if (!openedCreatedOrder) {
          // Refresh saved orders for both table and delivery-method contexts
          if (mounted &&
              (_activeTableId != null || _selectedDeliveryMethodId != null)) {
            _orderPanelKey.currentState?.refreshSavedOrders();
          }

          _resetCounterOrderContextAfterKitchenSend();
        }

        // Check if KOT print is enabled in app settings
        final appSettingsProvider =
            Provider.of<AppSettingsProvider>(context, listen: false);
        if (appSettingsProvider.appSettings?.enableKOTPrint ?? true) {
          // Get current time for KOT (using DateHelper for timezone support)
          final orderTime = DateHelper.getCurrentFormattedTimeWithAMPM();

          // Try auto-print with default printer first
          if (mounted) {
            KotPrintPage.autoPrint(
              context,
              orderNumber: orderNumber,
              tokenNumber: tokenNumber,
              tableName: tableName,
              showTableLabel: showTableLabel,
              orderTime: orderTime,
              items: printItems,
              comment: currentComment.isNotEmpty ? currentComment : null,
            ).then((success) {
              // Only show print page if auto-print failed
              if (!success && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KotPrintPage(
                      orderNumber: orderNumber,
                      tokenNumber: tokenNumber,
                      tableName: tableName,
                      showTableLabel: showTableLabel,
                      orderTime: orderTime,
                      items: printItems,
                      comment:
                          currentComment.isNotEmpty ? currentComment : null,
                    ),
                  ),
                );
              }
            });
          }
        }
      } else {
        showScaffoldError(
          context: context,
          message:
              '${'restaurant.failed_send_order'.tr}: ${response["message"] ?? "Unknown error"}',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: '${'restaurant.failed_print_order'.tr}: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrint = false;
        });
      }
    }
  }

  // Auto-save current context's cart before switching to another table/delivery method
  void _autoSaveCurrentTableBeforeSwitch() {
    if (_activeTableId == null && _selectedDeliveryMethodId == null) return;

    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final orderPanelState = _orderPanelKey.currentState;
      final cartItems = localProductProvider.cartItems;

      if (cartItems.isEmpty) {
        debugPrint(
            '💾 No items in cart for ${_activeTableId ?? _selectedDeliveryMethodName}, skipping auto-save');
        return;
      }

      debugPrint(
          '💾 Auto-saving cart for ${_activeTableId ?? _selectedDeliveryMethodName} before switch (${cartItems.length} items)');

      // Auto-save as pending draft with tableId or deliveryMethodId
      localProductProvider.saveCurrentCartAsOrder(
        customerName: orderPanelState?.selectedCustomerNameForDraft,
        customerPhone: orderPanelState?.selectedCustomerPhoneForDraft,
        comment: (() {
          final draftComment =
              orderPanelState?.buildTaggedDraftComment(_activeTableId ?? '');
          if (draftComment == null) return null;
          final trimmed = draftComment.trim();
          return trimmed.isNotEmpty ? trimmed : null;
        })(),
        deliveryMethod: orderPanelState?.deliveryMethodForDraft,
        customerId: orderPanelState?.selectedCustomerIdForDraft,
        paymentMethod: orderPanelState?.paymentMethodForDraft,
        paidAmount: orderPanelState?.paidAmountForDraft,
        balanceAmount: orderPanelState?.balanceAmountForDraft,
        transactionId: orderPanelState?.transactionNumberForDraft,
        couponId: orderPanelState?.couponIdForDraft,
        deliveryMethodId: _selectedDeliveryMethodId ??
            orderPanelState?.deliveryMethodIdForDraft,
        carNumber: orderPanelState?.carNumberForDraft,
        status: 'pending',
        deliveryDate: orderPanelState?.deliveryDateForDraft,
        deliveryTime: orderPanelState?.deliveryTimeForDraft,
        toCustomerCredit: orderPanelState?.toCustomerCreditForDraft,
        context: context,
        tableId: _activeTableId,
        address: orderPanelState?.deliveryAddressForDraft,
        deliveryCharge: orderPanelState?.deliveryChargeForDraft,
        alternatePhone: orderPanelState?.selectedCustomerAlternatePhoneForDraft,
        customerVatNumber: orderPanelState?.selectedCustomerVatNumberForDraft,
        customerCrNumber: orderPanelState?.selectedCustomerCrNumberForDraft,
        customerType: orderPanelState?.selectedCustomerTypeForDraft,
      );

      debugPrint(
          '✅ Auto-saved pending draft for ${_activeTableId ?? _selectedDeliveryMethodName}');
      localProductProvider.clearCart();
      localProductProvider.clearCurrentOrder();
    } catch (e) {
      debugPrint('❌ Error auto-saving cart: $e');
    }
  }
}
