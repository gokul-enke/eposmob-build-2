import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/horizontal_saved_orders_view.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => BillingPageState();
}

// Custom widget for price text field with stable controller and focus node
class _PriceTextField extends StatefulWidget {
  final dynamic item;
  final dynamic localProductProvider;

  const _PriceTextField({
    Key? key,
    required this.item,
    required this.localProductProvider,
  }) : super(key: key);

  @override
  State<_PriceTextField> createState() => _PriceTextFieldState();
}

class _PriceTextFieldState extends State<_PriceTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.item.price.toString());
    focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_PriceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if price has changed
    if (oldWidget.item.price != widget.item.price) {
      controller.text = widget.item.price.toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the price has changed and update the controller if needed
        final currentPrice = widget.item.price.toString();
        if (!focusNode.hasFocus && controller.text != currentPrice) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentPrice;
            }
          });
        }

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'Price',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          onTap: () {
            // Use a post-frame callback to ensure text selection happens after the tap is processed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.text.isNotEmpty && focusNode.hasFocus) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            });
          },
          onChanged: (newPrice) {
            // Validate and update immediately on change
            final parsedPrice = double.tryParse(newPrice);
            if (parsedPrice != null && parsedPrice >= 0) {
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedPrice,
              );
            } else if (newPrice.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
              );
            }
          },
          onSubmitted: (newPrice) {
            // Validate and update on submit
            final parsedPrice = double.tryParse(newPrice);
            if (parsedPrice != null && parsedPrice >= 0) {
              widget.localProductProvider.updateItemPrice(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedPrice,
              );
            } else {
              // Revert to original price if invalid
              controller.text = widget.item.price.toString();
            }
          },
        );
      },
    );
  }
}

// Custom widget for MRP text field with stable controller and focus node
class _MrpTextField extends StatefulWidget {
  final dynamic item;
  final dynamic localProductProvider;

  const _MrpTextField({
    Key? key,
    required this.item,
    required this.localProductProvider,
  }) : super(key: key);

  @override
  State<_MrpTextField> createState() => _MrpTextFieldState();
}

class _MrpTextFieldState extends State<_MrpTextField> {
  late TextEditingController controller;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller =
        TextEditingController(text: (widget.item.mrp ?? 0.0).toString());
    focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_MrpTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if MRP has changed
    if (oldWidget.item.mrp != widget.item.mrp) {
      controller.text = (widget.item.mrp ?? 0.0).toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        // Check if the MRP has changed and update the controller if needed
        final currentMrp = (widget.item.mrp ?? 0.0).toString();
        if (!focusNode.hasFocus && controller.text != currentMrp) {
          // Only update if user is not currently editing the field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.text = currentMrp;
            }
          });
        }

        return TextField(
          textAlign: TextAlign.left,
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: InputBorder.none,
            hintText: 'MRP',
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          onTap: () {
            // Use a post-frame callback to ensure text selection happens after the tap is processed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (controller.text.isNotEmpty && focusNode.hasFocus) {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            });
          },
          onChanged: (newMrp) {
            // Validate and update immediately on change
            final parsedMrp = double.tryParse(newMrp);
            if (parsedMrp != null && parsedMrp >= 0) {
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedMrp,
              );
            } else if (newMrp.isEmpty) {
              // Allow empty field for editing
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                0.0,
              );
            }
          },
          onSubmitted: (newMrp) {
            // Validate and update on submit
            final parsedMrp = double.tryParse(newMrp);
            if (parsedMrp != null && parsedMrp >= 0) {
              widget.localProductProvider.updateItemMrp(
                widget.item.product.productId!,
                widget.item.selectedStock,
                parsedMrp,
              );
            } else {
              // Revert to original MRP if invalid
              controller.text = (widget.item.mrp ?? 0.0).toString();
            }
          },
        );
      },
    );
  }
}

class BillingPageState extends State<BillingPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final FocusNode _paidAmountFocusNode = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  // Flag to track if user has manually changed the paid amount
  bool _userChangedPaidAmount = false;

  String? mobileNumberText = "";
  String? salesExecutivemobileNumberText = "";
  int? selectedCustomerID;
  String? selectedCustomerPhone;
  CartProvider cartProvider = CartProvider();
  int iconColor = 0;
  String deliveryMethod = "";
  String deliveryMethodId = "";
  double _balanceAmount = 0;
  UniqueKey keyTile = UniqueKey();

  // Multi-payment method controllers
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
  final TextEditingController _upiAmountController = TextEditingController();
  final FocusNode _cashAmountFocusNode = FocusNode();
  final FocusNode _cardAmountFocusNode = FocusNode();
  final FocusNode _upiAmountFocusNode = FocusNode();

  // Payment method selection states
  bool _isCashSelected = true;
  bool _isCardSelected = false;
  bool _isUpiSelected = false;
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;
  List<ListCartModelDataCartItem>? cartProductItems = [];
  Map<String, num> taxNames = {};
  Map<int, bool> hoverMap = {};
  TextEditingController barcodeController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController selectedProductIdController = TextEditingController();
  TextEditingController selectedProductNameController = TextEditingController();

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();

  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _unitPriceFocusNode = FocusNode();

  bool isCustomerFound = false;
  bool isCouponApplied = false;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _barcodeNode = FocusNode();

  bool isLoadingClearCart = false;
  bool isLoadingSaveOrder = false;
  bool isLoadingCreateOrder = false;
  bool isLoadingConfirmOrder = false;
  bool isLoadingSaveOrderAndPrint = false;
  bool isLoadingAddItem = false;
  bool _isBottomSectionVisible = false; // Hide billing details panel by default

  // Add these variables for the new sidebar
  bool _isSidebarVisible = true;
  int _selectedSidebarTab =
      1; // 0 for products, 1 for orders/categories - default to orders tab

  Timer? _debounce;
  Timer? _debounceTimer;

  // Add these variables for keyboard navigation in customer list
  int? _highlightedCustomerIndex;
  final FocusNode _customerTextFieldFocus = FocusNode();
  final ScrollController _customerScrollController = ScrollController();
  List<CustomerListModelData> _currentCustomerOptions = [];
  final double _customerItemHeight = 48.0; // Height for customer list items

  // Add this variable to track internet connectivity
  bool _hasInternet = true;
  late StreamSubscription<InternetConnectionStatus> _internetSubscription;

  // Add flag to track if customer was manually selected
  bool _isCustomerManuallySelected = false;

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');
    _focusNode.addListener(_handleFocusChange);
    _paidAmountFocusNode
        .addListener(_handlePaidAmountFocusChange); // Add this line
    deliveryMethodId = "3";
    deliveryMethod = "Store Takeaway";
    iconColor = 1;

    // Initialize multi-payment with cash selected by default
    _isCashSelected = true;
    _isCardSelected = false;
    _isUpiSelected = false;

    _fetchCustomers();

    _quantityFocusNode.addListener(() {
      if (_quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    _unitPriceFocusNode.addListener(() {
      if (_unitPriceFocusNode.hasFocus) {
        unitPriceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: unitPriceController.text.length,
        );
      }
    });

    // Initialize internet connectivity listener
    _initConnectivityListener();

    // Listen for sales executive changes to update default customer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider.addListener(_onSalesExecutiveChanged);

      // Also listen for auth changes (more direct indicator of user switch)
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.addListener(_onUserSwitched);
    });
  }

  @override
  void dispose() {
    barcodeController.dispose();
    mobileNumberTextController.dispose();
    coupenCodeTextController.dispose();
    _transactionNumberController.dispose();
    _paidAmountController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    selectedProductIdController.dispose();
    _focusNode.dispose();
    _barcodeNode.dispose();

    // Dispose all the focus nodes
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();
    _paidAmountFocusNode.dispose();

    // Dispose multi-payment controllers and focus nodes
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _upiAmountController.dispose();
    _cashAmountFocusNode.dispose();
    _cardAmountFocusNode.dispose();
    _upiAmountFocusNode.dispose();

    _debounce?.cancel();
    _debounceTimer?.cancel();
    _customerTextFieldFocus.dispose();
    _customerScrollController.dispose();
    _internetSubscription.cancel(); // Cancel the subscription

    // Remove sales executive listener
    try {
      final salesExecutiveProvider =
          Provider.of<SalesExecutiveProvider>(context, listen: false);
      salesExecutiveProvider.removeListener(_onSalesExecutiveChanged);

      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.removeListener(_onUserSwitched);
    } catch (e) {
      debugPrint("Error removing listeners: $e");
    }

    super.dispose();
  }

  void _handlePaidAmountFocusChange() {
    if (_paidAmountFocusNode.hasFocus) {
      _paidAmountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _paidAmountController.text.length,
      );
    }
    // We don't necessarily need to do anything here, just having the listener
    // attached allows us to check focus state later.
    // debugPrint('Paid Amount field focus: ${_paidAmountFocusNode.hasFocus}');
  }

  // Function to initialize the connectivity listener
  void _initConnectivityListener() {
    _internetSubscription = InternetConnectionCheckerPlus()
        .onStatusChange
        .listen((InternetConnectionStatus status) {
      setState(() {
        _hasInternet = status == InternetConnectionStatus.connected;
      });
      if (!_hasInternet) {
        showScaffoldError(
          context: context,
          message: "No internet connection. Falling back to offline mode.",
        );
      } else {
        // showScaffold(
        //   context: context,
        //   message: "Internet connection restored.",
        // );
      }
    });
  }

  Future<void> _fetchCustomers() async {
    // If customer was manually selected (either from list or phone entry), don't reset to default
    if (_isCustomerManuallySelected &&
        (selectedCustomerID != null || mobileNumberText?.isNotEmpty == true)) {
      debugPrint("🛡️ Customer manually selected, skipping reset to default");
      debugPrint("  - selectedCustomerID: $selectedCustomerID");
      debugPrint("  - mobileNumberText: '$mobileNumberText'");
      return;
    }

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    try {
      final response = await CustomerProvider()
          .listCustomer(accessToken: accessToken!, sortAscending: true);

      if (response["status"] == "success") {
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setState(() {
          customerList = customerListModel.data; // Store the customer list
          CustomerListModelData? salesCustomer;

          if (customerList!.isNotEmpty) {
            // Get current sales executive's information
            final salesExecutiveProvider =
                Provider.of<SalesExecutiveProvider>(context, listen: false);
            final currentExecutive =
                salesExecutiveProvider.getCurrentUser(context);

            debugPrint(
                "🏢 BILLING: Setting up default customer from sales executive");
            debugPrint("  - Current executive: ${currentExecutive?.name}");
            debugPrint("  - Executive phone: ${currentExecutive?.phone}");
            debugPrint(
                "  - Available customers in list: ${customerList!.length}");

            if (currentExecutive != null) {
              // Create a virtual customer using sales executive's information
              salesCustomer = CustomerListModelData(
                id: currentExecutive.id, // Use executive ID
                name: currentExecutive.name,
                phone: currentExecutive.phone,
                email: currentExecutive.email,
                createdAt: currentExecutive.createdAt,
                updatedAt: currentExecutive.updatedAt,
              );
              debugPrint(
                  "✅ Created virtual customer from sales executive: ${salesCustomer.name} (${salesCustomer.phone})");
            } else {
              debugPrint(
                  "⚠️ No current executive found, falling back to first customer");
              salesCustomer = customerList![0];
            }

            debugPrint(
                "🎯 Selected default customer: ${salesCustomer.name} (${salesCustomer.phone})");

            debugPrint("📝 SETTING DEFAULT CUSTOMER STATE:");
            salesExecutivemobileNumberText = salesCustomer.phone!;
            mobileNumberText = salesCustomer.phone!;
            mobileNumberTextController.text =
                "${salesCustomer.name!} ${salesCustomer.phone!}";

            debugPrint(
                "  - Set salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
            debugPrint("  - Set mobileNumberText: '$mobileNumberText'");
            debugPrint(
                "  - Set mobileNumberTextController.text: '${mobileNumberTextController.text}'");

            // Set the default customer in the global provider and mark as default
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .setSelectedCustomer(salesCustomer, isDefault: true);

            selectedCustomerID = salesCustomer.id!;
            selectedCustomerPhone = salesCustomer.phone;
            selectedCustomer = salesCustomer;

            debugPrint("  - Set selectedCustomerID: $selectedCustomerID");
            debugPrint("  - Set selectedCustomerPhone: $selectedCustomerPhone");
            debugPrint("  - Set selectedCustomer: ${selectedCustomer?.name}");
          }
        });
      }
    } catch (error) {
      debugPrint('Error fetching customers: $error');
    }
  }

  void _focusTextField() {
    // debugPrint("Focusing Text Field");
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings!.barcodeSales) {
      FocusScope.of(context).requestFocus(_barcodeNode);
    } else {}
    selectedProductNameController.clear();
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      // debugPrint('Focus gained');
    }
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      try {
        if (event.logicalKey == LogicalKeyboardKey.f6) {
          _clearCart();
        } else if (event.logicalKey == LogicalKeyboardKey.f7) {
          _saveOrder();
        } else if (event.logicalKey == LogicalKeyboardKey.f8) {
          _createOrderAndPrint();
        } else if (event.logicalKey == LogicalKeyboardKey.f9) {
          _confirmOrder();
        }
      } catch (e) {
        // debugPrint("Error handling key press: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    debugPrint("🔨 BillingPage build() called");
    debugPrint(
        "  - Current salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");

    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);

    return SafeArea(
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: Scaffold(
          body: Stack(
            children: [
              // Main content
              Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content area
                    Expanded(
                      flex: _isSidebarVisible ? 3 : 4,
                      child: BuildBoxShadowContainer(
                        circleRadius: 10,
                        margin: const EdgeInsets.only(
                            left: 10, top: 10, bottom: 10, right: 10),
                        child: Form(
                          key: _formKey,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildHeader(),
                                const Divider(thickness: 1),
                                _buildOrderHeader(
                                  size: size,
                                  barcodeController: barcodeController,
                                  quantityController: quantityController,
                                  unitPriceController: unitPriceController,
                                  selectedProductIdController:
                                      selectedProductIdController,
                                  productProvider: productProvider,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: _buildCartItemsTable(size),
                                      ),
                                      const SizedBox(height: 5),
                                      // Always visible section
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Customer selection - always visible
                                          Expanded(
                                            flex:
                                                _isBottomSectionVisible ? 3 : 4,
                                            child: Container(
                                              color: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16.0,
                                                      vertical: 10),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  _buildMobileNumberInput(
                                                      size: size,
                                                      mobileNumberTextController:
                                                          mobileNumberTextController),
                                                  if (_isBottomSectionVisible) ...[
                                                    const SizedBox(height: 10),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        _buildPaymentMethodSelection(),
                                                      ],
                                                    ),
                                                  ] else ...[
                                                    const SizedBox(height: 10),
                                                    _buildQuickAccessIcons(),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Collapsible middle section
                                          if (_isBottomSectionVisible)
                                            Expanded(
                                              flex: 2,
                                              child:
                                                  _buildDeliveryMethodSelection(),
                                            ),
                                          // Payment summary - always visible
                                          Expanded(
                                              flex: _isBottomSectionVisible
                                                  ? 3
                                                  : 4,
                                              child: Container(
                                                color: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 10),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: [
                                                    if (_isBottomSectionVisible) ...[
                                                      _buildCouponInput(),
                                                      const SizedBox(
                                                          height: 10),
                                                    ],
                                                    _buildPaymentSummary(
                                                        compact:
                                                            !_isBottomSectionVisible),
                                                  ],
                                                ),
                                              )),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildActionButtons(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Collapsible Sidebar
                    if (_isSidebarVisible)
                      Expanded(
                        flex: 1,
                        child: _buildSidebar(),
                      ),

                    // Sidebar toggle button - moved to be positioned absolutely
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return BuildBoxShadowContainer(
      circleRadius: 10,
      margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
      child: Stack(
        children: [
          Column(
            children: [
              // Tab headers with improved design
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSidebarTab = 0;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _selectedSidebarTab == 0
                                ? ColorManager.kPrimaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: _selectedSidebarTab == 0
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Products',
                                style: TextStyle(
                                  color: _selectedSidebarTab == 0
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSidebarTab = 1;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _selectedSidebarTab == 1
                                ? ColorManager.kPrimaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                                color: _selectedSidebarTab == 1
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Orders',
                                style: TextStyle(
                                  color: _selectedSidebarTab == 1
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 50), // Space for toggle button
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: Container(
                  child: _selectedSidebarTab == 0
                      ? const SideBarProductList()
                      : _buildOrdersTab(),
                ),
              ),
            ],
          ),

          // Toggle button positioned at top-right
          Positioned(
            top: 10,
            right: 8,
            child: CustomRoundButton(
              title: "×",
              fct: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
              fontSize: 18,
              height: 35,
              width: 35,
              boxColor: ColorManager.kPrimaryColor,
              borderColor: ColorManager.kPrimaryColor,
              textColor: Colors.white,
              radius: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Saved Orders section with improved header
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        //   child: const Row(
        //     children: [
        //       Icon(
        //         Icons.bookmark_outline,
        //         size: 16,
        //         color: ColorManager.kPrimaryColor,
        //       ),
        //       SizedBox(width: 6),
        //       Text(
        //         'Saved Orders',
        //         style: TextStyle(
        //           fontSize: 14,
        //           fontWeight: FontWeight.w600,
        //           color: ColorManager.kPrimaryColor,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),

        // HorizontalSavedOrdersView in grid format
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: HorizontalSavedOrdersView(
              onOrderSelected: (orderId) {
                // Get the local provider
                final localProductProvider =
                    Provider.of<LocalProductProvider>(context, listen: false);

                // If we're editing an order and there are items in the cart, update that order
                if (localProductProvider.currentOrder != null &&
                    localProductProvider.cartItems.isNotEmpty) {
                  try {
                    // Update the current order being edited
                    localProductProvider.updateSavedOrder(
                      localProductProvider.currentOrder!.id,
                      customerName: selectedCustomer?.name,
                      customerPhone: selectedCustomerPhone ?? mobileNumberText,
                      comment: _commentController.text,
                      deliveryMethod: deliveryMethod,
                    );

                    // Show quick feedback
                    showScaffold(
                      context: context,
                      message: "Current order updated before switching",
                    );
                  } catch (e) {
                    debugPrint("Error updating current order: $e");
                  }
                } // If cart has items, save as new order
                else if (localProductProvider.cartItems.isNotEmpty) {
                  try {
                    localProductProvider.saveCurrentCartAsOrder();
                    showScaffold(
                      context: context,
                      message: "Order Saved Successfully",
                    );
                  } catch (e) {
                    // Swallow exception if cart is empty
                  }
                }

                // Now load the selected order
                _loadSavedOrderForEditing(orderId);
              },
            ),
          ),
        ),

        // Divider with improved styling
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.grey.shade300,
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Quick Access section with improved header

        // HorizontalProductViewLocal in grid format
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const HorizontalProductViewLocal(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final bool isEditingOrder = localProductProvider.currentOrder != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isEditingOrder ? 'Edit Order' : 'New Order',
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
        Row(
          children: [
            Text(
              isEditingOrder
                  ? 'Order No #${localProductProvider.currentOrder!.orderNumber}'
                  : 'Order No #00000',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.18, ColorManager.textColor),
            ),
            // Show toggle button next to order number when sidebar is hidden
            if (!_isSidebarVisible) ...[
              const SizedBox(width: 12),
              CustomRoundButton(
                title: "☰",
                fct: () {
                  setState(() {
                    _isSidebarVisible = !_isSidebarVisible;
                  });
                },
                fontSize: 16,
                height: 32,
                width: 32,
                boxColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
                radius: 8,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOrderHeader({
    required Size size,
    required TextEditingController barcodeController,
    required TextEditingController quantityController,
    required TextEditingController unitPriceController,
    required TextEditingController selectedProductIdController,
    required GridSelectionProvider productProvider,
  }) {
    return Consumer<AppSettingsProvider>(
        builder: (context, appSettingsProvider, child) {
      if (appSettingsProvider.appSettings == null) {
        return Container();
      }
      return SizedBox(
        height: size.height * 0.10,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                children: [
                  appSettingsProvider.appSettings!.barcodeSales
                      ? Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              autofocus:
                                  appSettingsProvider.appSettings!.barcodeSales,
                              controller: barcodeController,
                              focusNode: _barcodeNode,
                              readOnly:
                                  selectedProductNameController.text.isNotEmpty,
                              onchanged: (query) async {
                                if (_debounce?.isActive ?? false) {
                                  _debounce!.cancel();
                                }
                                _debounce = Timer(
                                  const Duration(milliseconds: 500),
                                  () async {
                                    if (query != null) {
                                      debugPrint("QUERY: ${query.length}");
                                      final localProductProvider =
                                          Provider.of<LocalProductProvider>(
                                              context,
                                              listen: false);

                                      List<GetProduct> filteredProducts = [];
                                      try {
                                        String? prefix;
                                        String? productCode;
                                        String? lastFive;

                                        if (query.length > 2) {
                                          prefix = query.substring(
                                              0, 3); // First 3 digits;
                                        }

                                        if (prefix != '000' ||
                                            query.length != 14) {
                                          filteredProducts =
                                              Provider.of<LocalProductProvider>(
                                                      context,
                                                      listen: false)
                                                  .filterProductByBarcode(
                                            barCode: query,
                                          );
                                        } else {
                                          productCode = query.substring(
                                              3, 9); // Next 6 digits
                                          lastFive = query.substring(
                                              9, 14); // Last 5 digits
                                          filteredProducts =
                                              Provider.of<LocalProductProvider>(
                                                      context,
                                                      listen: false)
                                                  .filterProductByBarcode(
                                            barCode: productCode,
                                          );
                                        }

                                        if (filteredProducts.isNotEmpty) {
                                          // Get the first product
                                          GetProduct product =
                                              filteredProducts.first;

                                          num? quantity;
                                          if ((product.unit == 'KGS' ||
                                                  product.unit == 'KG') &&
                                              prefix == '000' &&
                                              query.length == 14) {
                                            // Weight-based product
                                            String weightKg = lastFive!
                                                .substring(0,
                                                    2); // First 2 digits = KG
                                            String weightGrams =
                                                lastFive.substring(2,
                                                    5); // Last 3 digits = Grams
                                            quantity = double.parse(weightKg) +
                                                (double.parse(weightGrams) /
                                                    1000);
                                          } else if ((product.unit == 'PCS' ||
                                                  product.unit == 'PC') &&
                                              prefix == '000' &&
                                              query.length == 14) {
                                            // Count-based product
                                            quantity = int.parse(
                                                lastFive!); // Last 5 digits represent quantity
                                          }

                                          // Use centralized helper for stock handling
                                          debugPrint(
                                              "🛒 BARCODE SCAN - Calling ProductCartHelper with:");
                                          debugPrint(
                                              "  - Product: ${product.productName}");
                                          debugPrint("  - Quantity: $quantity");
                                          debugPrint(
                                              "  - Customer ID: $selectedCustomerID");
                                          debugPrint(
                                              "  - Customer Name: ${selectedCustomer?.name}");

                                          await ProductCartHelper
                                              .handleProductSelection(
                                            context: context,
                                            product: product,
                                            quantity: quantity,
                                            addToCartDirectly: true,
                                            customerId: selectedCustomerID,
                                            customerName:
                                                selectedCustomer?.name,
                                          );

                                          // Clear input fields
                                          setState(() {
                                            _autocompleteProductKey =
                                                GlobalKey();
                                            quantityController.clear();
                                            barcodeController.clear();
                                            selectedProductIdController.clear();
                                            unitPriceController.clear();
                                          });
                                          _focusTextField();
                                        } else {
                                          // Set dialog state to open
                                          await showDialog(
                                            context: context,
                                            builder: (context) =>
                                                AddProductWithBarcodeModal(
                                                    barcode: query),
                                          );
                                          // Reset dialog state

                                          barcodeController.clear();
                                          _focusTextField();

                                          debugPrint(
                                              "No products found for barcode: $query");
                                        }
                                      } catch (e) {
                                        debugPrint("Error adding item: $e");
                                        showScaffoldError(
                                          context: context,
                                          message:
                                              "Invalid Barcode. Please try again.",
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                              size: size,
                              hintText: 'Barcode',
                            ),
                          ),
                        )
                      : Container(),
                  appSettingsProvider.appSettings!.barcodeSales &&
                          selectedProductNameController.text.isNotEmpty
                      ? Expanded(
                          flex: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: buildColumnWidgetForTextFields(
                              readOnly: true,
                              controller: selectedProductNameController,
                              onchanged: (query) {},
                              size: size,
                              hintText: 'Quantity',
                            ),
                          ),
                        )
                      : Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProductAutocomplete(
                                autocompleteProductKey: _autocompleteProductKey,
                                autofocus: !appSettingsProvider
                                    .appSettings!.barcodeSales,
                                size: size,
                                onSelected: (GetProduct selectedProduct,
                                    Stock? selectedStock) async {
                                  // Directly populate form fields without showing price modal

                                  // Determine the price to use: stock price or product base price
                                  double defaultPrice = 0.0;
                                  if (selectedStock != null) {
                                    // Use stock price if available
                                    defaultPrice = double.tryParse(
                                            selectedStock.price ?? "0") ??
                                        0.0;
                                  } else {
                                    // Use product base price
                                    defaultPrice = double.tryParse(
                                            selectedProduct.price?.price ??
                                                "0") ??
                                        0.0;
                                  }

                                  setState(() {
                                    selectedProductIdController.text =
                                        selectedProduct.productId.toString();
                                    unitPriceController.text =
                                        defaultPrice.toString();
                                    quantityController.text = '1';
                                    selectedProductNameController.text =
                                        selectedProduct.productName ?? '';
                                    barcodeController.text =
                                        selectedProduct.barcode ?? '';
                                  });
                                },
                                productList: productProvider.productList!,
                              ),
                            ],
                          ),
                        ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: buildColumnWidgetForTextFields(
                        controller: quantityController,
                        onchanged: (query) {},
                        size: size,
                        hintText: 'Quantity',
                        focusNode: _quantityFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          if (unitPriceController.text == 'KG' ||
                              unitPriceController.text == 'LT')
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}$')),
                          if (unitPriceController.text != 'LT' &&
                              unitPriceController.text != 'KG')
                            FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: buildColumnWidgetForTextFields(
                        controller: unitPriceController,
                        onchanged: (query) {},
                        size: size,
                        focusNode: _unitPriceFocusNode,
                        hintText: 'Unit Price',
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomRoundButton(
                              title: "Add Item",
                              boxColor: ColorManager.kButtonGreen,
                              borderColor: ColorManager.kButtonGreen,
                              isLoading: isLoadingAddItem,
                              fct: () async {
                                setState(() {
                                  isLoadingAddItem = true; // Start loading
                                });
                                try {
                                  // Get the selected product from LocalProductProvider
                                  final localProductProvider =
                                      Provider.of<LocalProductProvider>(context,
                                          listen: false);
                                  final generalSettingsProvider =
                                      Provider.of<GeneralSettingsProvider>(
                                          context,
                                          listen: false);

                                  final selectedProduct =
                                      localProductProvider.selectedProduct;

                                  if (selectedProduct != null) {
                                    debugPrint("=== ADD ITEM DEBUG ===");
                                    debugPrint(
                                        "Product selected: ${selectedProduct.productName}");
                                    debugPrint(
                                        "Product ID: ${selectedProduct.productId}");
                                    debugPrint(
                                        "Product base price: ${selectedProduct.price?.price ?? 'null'}");
                                    debugPrint(
                                        "Product MRP: ${selectedProduct.mrp ?? 'null'}");
                                    debugPrint(
                                        "Product has ${selectedProduct.stock?.length ?? 0} stock entries");

                                    // Check if stock management is enabled
                                    bool stockEnabled = generalSettingsProvider
                                            .generalSettings?.stockEnabled ??
                                        false;
                                    debugPrint(
                                        "Stock management enabled: $stockEnabled");

                                    // Set the stock enabled status in LocalProductProvider
                                    localProductProvider
                                        .setStockEnabled(stockEnabled);

                                    if (!stockEnabled) {
                                      debugPrint(
                                          "Stock management disabled, adding product directly to cart...");

                                      // Add the selected product to the local cart without stock checking
                                      localProductProvider.addToCart(
                                          product: selectedProduct,
                                          quantity: num.tryParse(
                                            quantityController.text,
                                          ),
                                          price: double.tryParse(
                                            unitPriceController.text,
                                          ));

                                      showScaffold(
                                        context: context,
                                        message: 'Added To Cart',
                                      );

                                      // Clear input fields if necessary
                                      setState(() {
                                        _autocompleteProductKey = GlobalKey();
                                        quantityController.clear();
                                        barcodeController.clear();
                                        selectedProductIdController.clear();
                                        unitPriceController.clear();
                                      });
                                      _focusTextField();
                                      debugPrint("=== END ADD ITEM DEBUG ===");
                                      return;
                                    }

                                    // Check if we have a selected stock from the autocomplete
                                    Stock? selectedStock =
                                        localProductProvider.selectedStock;
                                    debugPrint(
                                        "Selected stock from autocomplete: ${selectedStock?.id ?? 'null'}");

                                    if (selectedStock != null) {
                                      debugPrint(
                                          "Using pre-selected stock from autocomplete...");

                                      // 🔧 FIX: Prioritize user's custom typed price over stock price
                                      double customPrice = double.tryParse(
                                              unitPriceController.text) ??
                                          0;
                                      double stockPrice = double.tryParse(
                                              selectedStock.price ?? "0") ??
                                          0;
                                      double stockMrp = double.tryParse(
                                              selectedStock.mrp ?? "0") ??
                                          0;

                                      // Use custom price if user typed one, otherwise use stock price
                                      double finalPrice = customPrice > 0
                                          ? customPrice
                                          : stockPrice;

                                      // 🔧 FIX: Check if product already exists in cart with custom MRP
                                      double? finalMrp;
                                      final bool itemExistsInCart =
                                          localProductProvider.cartItems.any(
                                              (item) =>
                                                  item.product.productId ==
                                                      selectedProduct
                                                          .productId &&
                                                  (item.selectedStock?.id ==
                                                          selectedStock.id ||
                                                      (item.selectedStock ==
                                                              null &&
                                                          selectedStock ==
                                                              null)));

                                      if (itemExistsInCart) {
                                        // Item exists, don't pass MRP to preserve existing custom MRP
                                        finalMrp = null;
                                        debugPrint(
                                            "Product already in cart - preserving existing custom MRP");
                                      } else {
                                        // New item, use stock MRP
                                        finalMrp = stockMrp;
                                        debugPrint(
                                            "New product to cart - using stock MRP: $finalMrp");
                                      }

                                      debugPrint(
                                          "Adding to cart with pre-selected stock: CustomPrice=${customPrice}, StockPrice=${stockPrice}, FinalPrice=${finalPrice}, MRP=${finalMrp ?? 'preserved'}");

                                      // Add the selected product to the local cart with the pre-selected stock
                                      localProductProvider.addToCart(
                                        product: selectedProduct,
                                        quantity: num.tryParse(
                                            quantityController.text),
                                        price:
                                            finalPrice, // 🔧 FIX: Use custom price if available
                                        mrp:
                                            finalMrp, // 🔧 FIX: Use null to preserve existing custom MRP
                                        selectedStock: selectedStock,
                                      );

                                      showScaffold(
                                        context: context,
                                        message: 'Added To Cart',
                                      );
                                    } else {
                                      debugPrint(
                                          "No pre-selected stock, using auto-selection logic...");

                                      // Let the addToCart method handle auto-selection for single stock
                                      localProductProvider.addToCart(
                                        product: selectedProduct,
                                        quantity: num.tryParse(
                                            quantityController.text),
                                        price: double.tryParse(
                                            unitPriceController.text),
                                      );

                                      showScaffold(
                                        context: context,
                                        message: 'Added To Cart',
                                      );
                                    }

                                    // Clear input fields if necessary
                                    setState(() {
                                      _autocompleteProductKey = GlobalKey();
                                      quantityController.clear();
                                      barcodeController.clear();
                                      selectedProductIdController.clear();
                                      unitPriceController.clear();
                                    });
                                    _focusTextField();
                                    debugPrint("=== END ADD ITEM DEBUG ===");
                                  } else {
                                    showScaffoldError(
                                      context: context,
                                      message: "No product selected!",
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error adding item: $e');
                                  showScaffoldError(
                                    context: context,
                                    message:
                                        "Failed to add item. Please try again.",
                                  );
                                } finally {
                                  debugPrint('Finally adding item');
                                  setState(() {
                                    isLoadingAddItem = false; // End loading
                                  });
                                }
                              },
                              fontSize: FontSize.s14,
                              height: size.height * .07,
                              width: size.width / 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        BuildBoxShadowContainer(
                          height: size.height * .07,
                          width: 50,
                          circleRadius: 5,
                          child: InkWell(
                            onTap: () => {
                              setState(() {
                                _autocompleteProductKey = GlobalKey();
                                quantityController.clear();
                                barcodeController.clear();
                                selectedProductIdController.clear();
                                unitPriceController.clear();
                              }),
                              Provider.of<LocalProductProvider>(context,
                                      listen: false)
                                  .resetSelectedProduct(),
                              _focusTextField(),
                              showScaffold(
                                context: context,
                                message: 'Product Details Cleared Successfully',
                              )
                            },
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: WebsafeSvg.asset(
                                      ImageAssets.oderlistCloseIcon,
                                      width: 27,
                                      color: ColorManager.kButtonRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCartItemsTable(Size size) {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        List<LocalCartItem> cartItems = localProductProvider.getCartItems();

        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                children: [
                  // Fixed header
                  Container(
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                    child: Row(
                      children: [
                        _buildHeaderCell('#',
                            flex: 1, alignment: Alignment.center),
                        _buildHeaderCell('Item Name',
                            flex: 3, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Unit',
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Qty',
                            flex: 2, alignment: Alignment.center),
                        _buildHeaderCell('MRP',
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Price',
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Total',
                            flex: 1, alignment: Alignment.centerLeft),
                        _buildHeaderCell('Actions',
                            flex: 1, alignment: Alignment.centerLeft),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return Container(
                              color: index % 2 == 0
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              child: Row(
                                children: [
                                  // Index Number
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        '${index + 1}',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          16,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.center,
                                  ),

                                  // Item Name
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        item.product.productName ?? 'Unknown',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          14,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    flex: 3,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Unit
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Text(
                                        item.product.unit ?? '-',
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          16,
                                          0.21,
                                          ColorManager.textColor,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Qty
                                  _buildContentCell(
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: CompactQuantityControlLocal(
                                          productId: item.product.productId!,
                                          quantity: item.quantity.toDouble(),
                                          unitPrice: item.price.toString(),
                                          productUnit: item.product.unit,
                                          product: item.product,
                                          selectedStock: item.selectedStock,
                                        ),
                                      ),
                                    ),
                                    flex: 2,
                                    alignment: Alignment.center,
                                  ),

                                  // MRP
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: _MrpTextField(
                                          item: item,
                                          localProductProvider:
                                              localProductProvider,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Price
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: _PriceTextField(
                                          item: item,
                                          localProductProvider:
                                              localProductProvider,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Total
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: SizedBox(
                                        width: 70,
                                        child: Text(
                                          (item.price! * item.quantity)
                                              .toStringAsFixed(3),
                                          style: const TextStyle(fontSize: 16),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),

                                  // Actions
                                  _buildContentCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: IconButton(
                                        icon: WebsafeSvg.asset(
                                          ImageAssets.oderlistCloseIcon,
                                          width: 15,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          localProductProvider.removeFromCart(
                                              item.product.productId!,
                                              item.selectedStock);
                                        },
                                      ),
                                    ),
                                    flex: 1,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCell(String text,
      {required int flex, required Alignment alignment}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: alignment,
        child: Text(
          text,
          textAlign:
              alignment == Alignment.center ? TextAlign.center : TextAlign.left,
          style: buildCustomStyle(
            FontWeightManager.bold,
            12,
            0.21,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildContentCell(Widget child,
      {required int flex, required Alignment alignment}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: alignment,
        child: child,
      ),
    );
  }

  Widget _buildPaymentSummary({bool compact = false}) {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);

    localProductProvider.cartTotal; // Call this to ensure priceSummary is set

    if (compact) {
      // Compact view: Only show Net amount, Discount, and Total
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          BuildPaymentRow(
            amount: "",
            title: "Payment Summary",
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.21,
              ColorManager.kPrimaryColor,
            ),
            color: ColorManager.kPrimaryColor,
          ),
          const SizedBox(height: 5),
          BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
            title: "Net amount",
            color: ColorManager.textColor,
          ),
          // if (localProductProvider.priceSummary!.discount > 0)
          BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)}",
            title: "Discount",
            color: ColorManager.textColor,
          ),
          const Divider(thickness: 2),
          BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.cartTotal)}",
            title: "Total Payable",
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.textColor,
            ),
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.textColor,
            ),
            color: ColorManager.textColor,
          ),
        ],
      );
    }

    // Full view
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        BuildPaymentRow(
          amount: "",
          title: "Payment Summary",
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        const SizedBox(
          height: 5,
        ),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal)}",
          title: "Net amount",
          color: ColorManager.textColor,
        ),
        const BuildPaymentRow(
          amount: "INR 0.00",
          title: "Shipping",
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount)}",
          title: "Discount",
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax)}",
            title: "GST",
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Center(
                  child: TaxDetailsDialog(
                    taxAmounts: taxNames,
                  ),
                );
              },
            );
          },
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(localProductProvider.cartTotal)}", // Use cartTotal from LocalProductProvider
          title: "Total Payable",
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            ColorManager.textColor,
          ),
          color: ColorManager.textColor,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelection() {
    Size size = MediaQuery.of(context).size;
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        return Column(
          children: [
            BuildPaymentRow(
              amount: "",
              padding: const EdgeInsets.only(left: 5.0),
              title: "Payment Methods",
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.21,
                ColorManager.kPrimaryColor,
              ),
              color: ColorManager.kPrimaryColor,
            ),
            const SizedBox(height: 10),

            // Cash Payment
            _buildPaymentMethodRow(
              isSelected: _isCashSelected,
              icon: ImageAssets.cashIcon,
              label: 'Cash',
              controller: _cashAmountController,
              focusNode: _cashAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  _isCashSelected = !_isCashSelected;
                  if (!_isCashSelected) {
                    _cashAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _updateBalanceAmount();
                });
              },
              onAmountChanged: (value) {
                _updateBalanceAmount();
              },
            ),

            const SizedBox(height: 8),

            // Card Payment
            _buildPaymentMethodRow(
              isSelected: _isCardSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'Card',
              controller: _cardAmountController,
              focusNode: _cardAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  _isCardSelected = !_isCardSelected;
                  if (!_isCardSelected) {
                    _cardAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _updateBalanceAmount();
                });
              },
              onAmountChanged: (value) {
                _updateBalanceAmount();
              },
            ),

            const SizedBox(height: 8),

            // UPI Payment
            _buildPaymentMethodRow(
              isSelected: _isUpiSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'UPI',
              controller: _upiAmountController,
              focusNode: _upiAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  _isUpiSelected = !_isUpiSelected;
                  if (!_isUpiSelected) {
                    _upiAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _updateBalanceAmount();
                });
              },
              onAmountChanged: (value) {
                _updateBalanceAmount();
              },
            ),

            const SizedBox(height: 12),

            // Transaction Reference Field - Show only if Card or UPI is selected
            if (_isCardSelected || _isUpiSelected) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: buildColumnWidgetForTextFields(
                  controller: _transactionNumberController,
                  size: size,
                  height: size.height * .05,
                  hintText: 'Transaction Reference Number',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Total Paid and Balance Display
            _buildPaymentSummaryRow(localProductProvider),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryMethodSelection() {
    Size size = MediaQuery.of(context).size;

    return Consumer<DeliveryMethodsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Container();
        }

        // Group delivery methods into pairs for 2 items per row
        List<List<DeliveryMethod>> groupedMethods = [];
        for (int i = 0; i < provider.deliveryMethods.length; i += 2) {
          if (i + 1 < provider.deliveryMethods.length) {
            // Add a pair
            groupedMethods.add(
                [provider.deliveryMethods[i], provider.deliveryMethods[i + 1]]);
          } else {
            // Add the last item if there's an odd number
            groupedMethods.add([provider.deliveryMethods[i]]);
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column of rows, each with max 2 delivery methods
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: groupedMethods.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: row.map((method) {
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 5, left: 5),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      deliveryMethod = method.name;
                                      deliveryMethodId = method.id;
                                    });
                                  },
                                  child: BuildBoxShadowContainer(
                                    border: deliveryMethod == method.name
                                        ? Border.all(
                                            color: ColorManager.kPrimaryColor)
                                        : null,
                                    padding: const EdgeInsets.all(8),
                                    blurRadius: 4,
                                    circleRadius: 5,
                                    child: Column(
                                      children: [
                                        Icon(
                                          method.name == "Store Takeaway"
                                              ? Icons.store
                                              : method.name == "Car Delivery"
                                                  ? Icons.car_rental
                                                  : method.name ==
                                                          "Door Delivery"
                                                      ? Icons.doorbell_outlined
                                                      : Icons.local_shipping,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        Text(
                                          method.name,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s10,
                                            0.12,
                                            Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (deliveryMethod == "Car Delivery")
                      buildColumnWidgetForTextFields(
                        controller: _carNumberController,
                        size: size,
                        margin: const EdgeInsets.all(0),
                        height: size.height * .06,
                        hintText: 'Car Number:',
                      ),
                    if (deliveryMethod == "Car Delivery")
                      const SizedBox(height: 10),
                    buildColumnWidgetForTextFields(
                      controller: _commentController,
                      margin: const EdgeInsets.all(0),
                      size: size,
                      height: size.height * .06,
                      hintText: 'Comment:',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            text: 'Clear Cart',
            color: ColorManager.kButtonRed,
            onPressed: _clearCart,
            isLoading: isLoadingClearCart,
          ),
          _buildActionButton(
            text: 'Save Order',
            color: ColorManager.kButtonYellow,
            onPressed: _saveOrder,
            isLoading: isLoadingSaveOrder,
          ),
          if (_hasInternet) ...[
            _buildActionButton(
              text: 'Confirm and Print',
              color: ColorManager.kButtonBlue,
              onPressed: _createOrderAndPrint,
              isLoading: isLoadingCreateOrder,
            ),
            _buildActionButton(
              text: 'Confirm Order',
              color: ColorManager.kButtonGreen,
              onPressed: _confirmOrder,
              isLoading: isLoadingConfirmOrder,
            ),
          ],
          if (!_hasInternet) ...[
            _buildActionButton(
              text: 'Save and Print',
              color: ColorManager.kButtonYellow,
              onPressed: _saveOrderAndPrint,
              isLoading: isLoadingSaveOrderAndPrint,
            ),
          ],
          // Hide/Show toggle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isBottomSectionVisible = !_isBottomSectionVisible;
                });
              },
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: ColorManager.kPrimaryColor,
                ),
                child: Center(
                  child: Icon(
                    _isBottomSectionVisible
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNumberInput({
    required Size size,
    required TextEditingController mobileNumberTextController,
  }) {
    debugPrint("🖼️ _buildMobileNumberInput - Rendering customer field");
    debugPrint(
        "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
    debugPrint(
        "  - salesExecutivemobileNumberText != '': ${salesExecutivemobileNumberText != ""}");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
    debugPrint("  - isCustomerFound: $isCustomerFound");
    debugPrint(
        "  - Showing: ${salesExecutivemobileNumberText != "" ? "READ-ONLY field" : "AUTOCOMPLETE field"}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (salesExecutivemobileNumberText != "")
                ? Expanded(
                    child: buildColumnWidgetForTextFields(
                      controller: mobileNumberTextController,
                      readOnly: true,
                      size: size,
                      hintText: 'Phone Number',
                    ),
                  )
                : Expanded(
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 0),
                      padding: const EdgeInsets.only(left: 15),
                      height: size.height * .07,
                      width: size.width / 3,
                      child: Autocomplete<CustomerListModelData>(
                        key: _autocompletePhoneKey, // Set the key here
                        initialValue: TextEditingValue(
                            text: mobileNumberText?.isNotEmpty == true
                                ? mobileNumberText!
                                : ""), // Use mobileNumberText directly
                        optionsBuilder: (mobileNumberTextController) async {
                          debugPrint(
                              "🔍 Autocomplete optionsBuilder called with text: '${mobileNumberTextController.text}'");
                          // debugPrint(mobileNumberTextController.text);
                          if (mobileNumberTextController.text.isEmpty) {
                            setState(() {
                              isCustomerFound = false; // Reset validity
                              _highlightedCustomerIndex =
                                  null; // Reset highlighted index
                            });
                            return const Iterable<
                                CustomerListModelData>.empty();
                          }

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          // debugPrint("accessToken From AuthModel $accessToken");
                          // debugPrint(mobileNumberTextController.text);

                          try {
                            final response;
                            if (RegExp(r'^[0-9]+$')
                                .hasMatch(mobileNumberTextController.text)) {
                              response = await CustomerProvider()
                                  .findCustomerByPhone(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            } else {
                              response = await CustomerProvider()
                                  .findCustomerByName(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            }

                            if (response["status"] == "success") {
                              CustomerListModel customerListModel =
                                  CustomerListModel.fromJson(response);
                              List<CustomerListModelData>?
                                  filteredCustomerList = customerListModel.data;

                              if (mobileNumberTextController.text.length ==
                                      10 &&
                                  filteredCustomerList!.length == 1) {
                                setState(() {
                                  isCustomerFound = true;
                                });
                              } else {
                                setState(() {
                                  isCustomerFound = false;
                                });
                              }

                              _currentCustomerOptions =
                                  filteredCustomerList ?? [];
                              return filteredCustomerList!.isNotEmpty
                                  ? filteredCustomerList
                                  : const Iterable<
                                      CustomerListModelData>.empty();
                            } else {
                              // debugPrint('Error in response: ${response["message"]}');
                            }
                          } catch (error) {
                            // debugPrint('Exception caught: $error');
                          }
                          setState(() {
                            isCustomerFound = false;
                            _currentCustomerOptions = [];
                          });
                          return const Iterable<
                              CustomerListModelData>.empty(); // Return empty if no customers found
                        },
                        displayStringForOption:
                            (CustomerListModelData customer) =>
                                "${customer.name} ${customer.phone}",
                        onSelected: (CustomerListModelData selection) {
                          debugPrint(
                              "===== NORMAL CUSTOMER SELECTION START =====");
                          debugPrint("👤 CUSTOMER SELECTED:");
                          debugPrint("  - Customer ID: ${selection.id}");
                          debugPrint("  - Customer Name: ${selection.name}");
                          debugPrint("  - Customer Phone: ${selection.phone}");
                          debugPrint(
                              "  - Current salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - Current mobileNumberText: '$mobileNumberText'");
                          debugPrint(
                              "  - Current mobileNumberTextController.text: '${mobileNumberTextController.text}'");

                          // Update the global customer selection provider
                          Provider.of<CustomerSelectionProvider>(context,
                                  listen: false)
                              .setSelectedCustomer(selection);

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          // debugPrint("accessToken From AuthModel $accessToken");
                          Provider.of<CartProvider>(context, listen: false)
                              .fetchCartDataFromApi(
                                  customerId: selection.id ?? 0,
                                  accessToken: accessToken ?? '');

                          debugPrint("📝 BEFORE setState:");
                          debugPrint(
                              "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - mobileNumberText: '$mobileNumberText'");

                          setState(() {
                            mobileNumberText = "";
                            selectedCustomerID = selection.id!;
                            selectedCustomerPhone = selection.phone;
                            selectedCustomer = selection;
                            // **FIX: Update our class controller for consistency**
                            mobileNumberTextController.text =
                                "${selection.name} ${selection.phone}";
                            // Mark as manually selected
                            _isCustomerManuallySelected = true;
                          });

                          debugPrint("📝 AFTER setState:");
                          debugPrint(
                              "  - mobileNumberText set to: '$mobileNumberText'");
                          debugPrint(
                              "  - selectedCustomerID: $selectedCustomerID");
                          debugPrint(
                              "  - selectedCustomerPhone: $selectedCustomerPhone");
                          debugPrint(
                              "  - salesExecutivemobileNumberText remains: '$salesExecutivemobileNumberText'");
                          debugPrint(
                              "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
                          debugPrint("  - isCustomerFound: $isCustomerFound");
                          debugPrint(
                              "===== NORMAL CUSTOMER SELECTION END =====");
                        },
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController autoCompleteController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted) {
                          debugPrint(
                              "🎨 fieldViewBuilder called - controller text: '${autoCompleteController.text}'");

                          // **FIX: Sync the autocomplete controller with our state**
                          if (mobileNumberText?.isNotEmpty == true &&
                              autoCompleteController.text != mobileNumberText) {
                            debugPrint(
                                "🔄 SYNC: Setting autocomplete controller text to: '$mobileNumberText'");
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (autoCompleteController.text !=
                                  mobileNumberText) {
                                autoCompleteController.text = mobileNumberText!;
                              }
                            });
                          }
                          return KeyboardListener(
                            focusNode: _customerTextFieldFocus,
                            onKeyEvent: (KeyEvent event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  setState(() {
                                    if (_highlightedCustomerIndex == null) {
                                      _highlightedCustomerIndex = 0;
                                    } else if (_currentCustomerOptions
                                            .isNotEmpty &&
                                        _highlightedCustomerIndex! <
                                            _currentCustomerOptions.length -
                                                1) {
                                      _highlightedCustomerIndex =
                                          _highlightedCustomerIndex! + 1;
                                    }
                                  });
                                  // Scroll to show the highlighted item
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  setState(() {
                                    if (_highlightedCustomerIndex == null) {
                                      _highlightedCustomerIndex = 0;
                                    } else if (_highlightedCustomerIndex! > 0) {
                                      _highlightedCustomerIndex =
                                          _highlightedCustomerIndex! - 1;
                                    }
                                  });
                                  // Scroll to show the highlighted item
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.enter) {
                                  // Handle Enter key to select highlighted item
                                  if (_highlightedCustomerIndex != null &&
                                      _currentCustomerOptions.isNotEmpty &&
                                      _highlightedCustomerIndex! <
                                          _currentCustomerOptions.length) {
                                    // Get the selected customer
                                    final selectedCust =
                                        _currentCustomerOptions[
                                            _highlightedCustomerIndex!];

                                    // Process the selection - this should match the onSelected behavior
                                    String? accessToken =
                                        Provider.of<AuthModel>(context,
                                                listen: false)
                                            .token;
                                    Provider.of<CartProvider>(context,
                                            listen: false)
                                        .fetchCartDataFromApi(
                                            customerId: selectedCust.id ?? 0,
                                            accessToken: accessToken ?? '');

                                    // Update text field with selected customer info
                                    autoCompleteController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";
                                    mobileNumberTextController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";

                                    setState(() {
                                      mobileNumberText = "";
                                      selectedCustomerID = selectedCust.id!;
                                      selectedCustomerPhone =
                                          selectedCust.phone;
                                      selectedCustomer = selectedCust;
                                      isCustomerFound = true;
                                      _isCustomerManuallySelected =
                                          true; // Mark as manually selected
                                    });

                                    // Unfocus to close the dropdown
                                    focusNode.unfocus();
                                  }
                                }
                              }
                            },
                            child: TextField(
                              controller: autoCompleteController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Enter mobile number',
                                hintStyle: buildCustomStyle(
                                  FontWeight.w500,
                                  12,
                                  0.27,
                                  Colors.grey.withOpacity(.5),
                                ),
                                border: InputBorder.none,
                                isDense: true, // Makes the field more compact
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                suffixIconConstraints: const BoxConstraints(
                                    maxHeight: 25,
                                    maxWidth:
                                        30), // Constrains the suffix icon size
                                suffixIcon: (isCustomerFound ||
                                        selectedCustomerID != null)
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: ColorManager.kButtonGreen,
                                          size: 25,
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                debugPrint("📝 TextField onChanged: '$value'");
                                setState(() {
                                  mobileNumberText = value;
                                  selectedCustomerID = null;
                                  selectedCustomerPhone = null;
                                  selectedCustomer = null;
                                  _highlightedCustomerIndex = null;
                                  isCustomerFound = false;
                                  // **FIX: Also update our class controller for consistency**
                                  mobileNumberTextController.text = value;

                                  // Mark as manually selected if user is typing a phone number
                                  if (value.isNotEmpty && value.length >= 10) {
                                    _isCustomerManuallySelected = true;
                                    debugPrint(
                                        "  - Marked as manually selected (phone entry)");
                                  } else if (value.isEmpty) {
                                    // Reset manual selection if field is cleared
                                    _isCustomerManuallySelected = false;
                                    debugPrint(
                                        "  - Reset manual selection (field cleared)");
                                  }
                                });
                                debugPrint(
                                    "  - Set mobileNumberText: '$mobileNumberText'");
                                debugPrint("  - Cleared customer selection");
                              },
                              style: buildCustomStyle(
                                FontWeight.w500,
                                12,
                                0.27,
                                Colors.black.withOpacity(.5),
                              ),
                            ),
                          );
                        },
                        optionsViewBuilder: (BuildContext context,
                            AutocompleteOnSelected<CustomerListModelData>
                                onSelected,
                            Iterable<CustomerListModelData> options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: Container(
                                width: MediaQuery.of(context).size.width / 3,
                                color: Colors.white,
                                constraints:
                                    const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  controller: _customerScrollController,
                                  padding: const EdgeInsets.all(8.0),
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final CustomerListModelData option =
                                        options.elementAt(index);
                                    final bool isHighlighted =
                                        _highlightedCustomerIndex == index;

                                    return MouseRegion(
                                      onEnter: (_) {
                                        setState(() {
                                          hoverMap[index] = true;
                                          _highlightedCustomerIndex = index;
                                        });
                                      },
                                      onExit: (_) {
                                        setState(() {
                                          hoverMap[index] = false;
                                        });
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          onSelected(option);
                                        },
                                        child: Container(
                                          color: isHighlighted
                                              ? Colors.blue.shade50
                                              : (hoverMap[index] == true
                                                  ? Colors.grey[200]
                                                  : Colors.white),
                                          child: ListTile(
                                            title: Text(
                                              "${option.name} ${option.phone}",
                                              style: buildCustomStyle(
                                                FontWeight.w500,
                                                12,
                                                0.27,
                                                isHighlighted
                                                    ? Colors.blue.shade800
                                                    : Colors.black
                                                        .withOpacity(.5),
                                              ),
                                            ),
                                            hoverColor: Colors.grey[200],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
            BuildBoxShadowContainer(
              height: size.height * .07,
              width: 50,
              circleRadius: 5,
              child: InkWell(
                onTap: () => {
                  debugPrint("❌ CLEAR CUSTOMER BUTTON PRESSED"),
                  debugPrint("  - Before clear:"),
                  debugPrint(
                      "    - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'"),
                  debugPrint("    - mobileNumberText: '$mobileNumberText'"),
                  debugPrint(
                      "    - mobileNumberTextController.text: '${mobileNumberTextController.text}'"),

                  // Clear the global customer selection provider
                  Provider.of<CustomerSelectionProvider>(context, listen: false)
                      .clearSelectedCustomer(),

                  setState(() {
                    _autocompletePhoneKey = GlobalKey();
                    mobileNumberTextController.clear();
                    mobileNumberText = "";
                    selectedCustomerID = null;
                    selectedCustomerPhone = null;
                    selectedCustomer = null;
                    isCustomerFound = false;
                    salesExecutivemobileNumberText = "";
                    _isCustomerManuallySelected = false; // Reset the flag
                    debugPrint(
                        "  - Reset manual selection (clear button pressed)");
                  }),

                  debugPrint("  - After clear:"),
                  debugPrint(
                      "    - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'"),
                  debugPrint("    - mobileNumberText: '$mobileNumberText'"),
                  debugPrint(
                      "    - mobileNumberTextController.text: '${mobileNumberTextController.text}'"),

                  showScaffold(
                    context: context,
                    message: 'Customer Details Cleared Successfully',
                  )
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: WebsafeSvg.asset(
                          ImageAssets.oderlistCloseIcon,
                          width: 27,
                          color: ColorManager.kButtonRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // if (selectedCustomerID == null || !isCustomerFound) ...[
            //   const SizedBox(width: 10),
            //   BuildBoxShadowContainer(
            //     height: size.height * .07,
            //     width: 50,
            //     circleRadius: 5,
            //     child: InkWell(
            //       onTap: () => {},
            //       child: Center(
            //         child: WebsafeSvg.asset(
            //           ImageAssets.oderlistCloseIcon,
            //           width: 27,
            //           color: ColorManager.kButtonRed,
            //         ),
            //       ),
            //     ),
            //   ),
            // ],
          ],
        ),
        // Customer Balance Display
        if (selectedCustomer?.balance != null && _shouldShowCustomerBalance())
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 5.0),
            child: _buildCustomerBalance(selectedCustomer!.balance!),
          ),
      ],
    );
  }

  bool _shouldShowCustomerBalance() {
    // Don't show balance if no customer is selected
    if (selectedCustomer?.phone == null) {
      return false;
    }

    // Get current sales executive
    final salesExecutiveProvider =
        Provider.of<SalesExecutiveProvider>(context, listen: false);
    final currentExecutive = salesExecutiveProvider.getCurrentUser(context);

    // Don't show balance if selected customer's phone matches current sales executive's phone
    if (currentExecutive?.phone != null &&
        selectedCustomer!.phone == currentExecutive!.phone) {
      return false;
    }

    return true;
  }

  Widget _buildCustomerBalance(double balance) {
    Color balanceColor;
    String balanceText;

    if (balance > 0) {
      balanceColor = Colors.green;
      balanceText = "+${balance.toStringAsFixed(2)}";
    } else if (balance < 0) {
      balanceColor = Colors.red;
      balanceText = balance.toStringAsFixed(2);
    } else {
      balanceColor = Colors.black;
      balanceText = balance.toStringAsFixed(2);
    }

    return Row(
      children: [
        Text(
          'Balance: ',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.14,
            Colors.grey.shade600,
          ),
        ),
        Text(
          'INR $balanceText',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.14,
            balanceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCouponInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: BuildBoxShadowContainer(
            circleRadius: 7,
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            padding: const EdgeInsets.only(left: 15),
            height: MediaQuery.of(context).size.height * .07,
            width: MediaQuery.of(context).size.width / 3,
            child: TextField(
              controller: coupenCodeTextController,
              enabled: !isCouponApplied,
              decoration: InputDecoration(
                hintText: 'Apply Coupon',
                hintStyle: buildCustomStyle(
                  FontWeight.w500,
                  12,
                  0.27,
                  Colors.grey.withOpacity(.5),
                ),
                border: InputBorder.none,
              ),
              style: buildCustomStyle(
                FontWeight.w500,
                12,
                0.27,
                Colors.black.withOpacity(.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (isCouponApplied) // Show remove button if coupon is applied
          CustomRoundButton(
            title: "Remove",
            fct: () => {
              setState(() {
                isCouponApplied = false; // Reset coupon state
                coupenCodeTextController.clear(); // Clear the coupon code
                // Fetch the cart data again after removing the coupon
                String? accessToken =
                    Provider.of<AuthModel>(context, listen: false).token;
                int? customerId =
                    Provider.of<AuthModel>(context, listen: false).userId;

                Provider.of<CartProvider>(context, listen: false)
                    .fetchCartDataFromApi(
                  customerId: customerId!,
                  accessToken: accessToken ?? '',
                );
              })
            },
            fontSize: FontSize.s14,
            height: MediaQuery.of(context).size.height * .07,
            width: 100,
          )
        else
          CustomRoundButton(
            title: "Apply",
            fct: _applyCoupon,
            fontSize: FontSize.s14,
            height: MediaQuery.of(context).size.height * .07,
            width: 100,
          ),
      ],
    );
  }

  void _clearCart() {
    debugPrint("Clear Cart pressed");
    setState(() {
      isLoadingClearCart = true; // Indicate that loading has started
    });
    try {
      Provider.of<LocalProductProvider>(context, listen: false).clearCart();
      setState(() {
        iconColor = 1; // Reset to default cash payment method
        coupenCodeTextController.clear();
        _transactionNumberController.clear();
        _paidAmountController.clear();
        _balanceAmount = 0;
        _userChangedPaidAmount = false; // Reset paid amount flag

        // Reset multi-payment fields
        _isCashSelected = true;
        _isCardSelected = false;
        _isUpiSelected = false;
        _cashAmountController.clear();
        _cardAmountController.clear();
        _upiAmountController.clear();
        _autocompleteProductKey = GlobalKey();
        quantityController.clear();
        barcodeController.clear();
        selectedProductIdController.clear();
        unitPriceController.clear();
        isCouponApplied = false;
      });
      showScaffold(
        context: context,
        message: "Cart Cleared Succesfully",
      );
      resetAutocomplete();
      _focusTextField();
    } catch (e) {
      debugPrint("Error clearing cart: $e");
      showScaffoldError(
        context: context,
        message: "Failed to clear cart. Please try again.",
      );
    } finally {
      setState(() {
        isLoadingClearCart = false;
      });
    }
  }

  void _saveOrder() async {
    setState(() {
      isLoadingSaveOrder = true; // Indicate that loading has started
    });
    debugPrint("Save Order pressed");
    try {
      if (Provider.of<LocalProductProvider>(context, listen: false)
          .cartItems
          .isEmpty) {
        showScaffoldError(
          context: context,
          message: "Please add items to cart",
        );
        return;
      }

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Debug: Log current cart items with custom pricing
      debugPrint("💾 LOCAL SAVE - Cart items with custom pricing:");
      for (var item in localProductProvider.cartItems) {
        debugPrint("  📦 ${item.product.productName}");
        debugPrint("    - Quantity: ${item.quantity}");
        debugPrint("    - Custom Price: ${item.price}");
        debugPrint("    - Custom MRP: ${item.mrp}");
        debugPrint("    - Stock ID: ${item.selectedStock?.id}");
      }

      // Validate that all items have valid pricing
      bool hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "Please ensure all items have valid prices before saving",
        );
        return;
      }

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;

      if (currentOrder != null) {
        // Update existing order
        debugPrint("💾 Updating existing order: ${currentOrder.orderNumber}");
        
        // Determine payment method and data
        String paymentMethod = "";
        String paidAmount = "";
        
        // Check if multi-payment is being used
        List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
        if (selectedPaymentMethods.length > 1) {
          // Multi-payment: store as JSON
          Map<String, dynamic> multiPaymentData = {
            "methods": selectedPaymentMethods,
            "amounts": {
              "CASH": _cashAmountController.text.isNotEmpty ? _cashAmountController.text : "0",
              "CARD": _cardAmountController.text.isNotEmpty ? _cardAmountController.text : "0",
              "UPI": _upiAmountController.text.isNotEmpty ? _upiAmountController.text : "0",
            },
            "isMultiPayment": true
          };
          paymentMethod = json.encode(multiPaymentData);
          paidAmount = _getTotalPaidAmount().toString();
        } else {
          // Single payment method
          if (selectedPaymentMethods.isNotEmpty) {
            paymentMethod = selectedPaymentMethods.first;
            if (paymentMethod == "CASH") {
              paidAmount = _cashAmountController.text;
            } else if (paymentMethod == "CARD") {
              paidAmount = _cardAmountController.text;
            } else if (paymentMethod == "UPI") {
              paidAmount = _upiAmountController.text;
            }
          } else {
            // Fallback to old iconColor logic
            if (iconColor == 1) {
              paymentMethod = "CASH";
            } else if (iconColor == 2) {
              paymentMethod = "CARD";
            } else if (iconColor == 3) {
              paymentMethod = "UPI";
            }
            paidAmount = _paidAmountController.text;
          }
        }

        // Debug customer info being saved
        debugPrint("📝 UPDATING ORDER - Customer info:");
        debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
        debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
        debugPrint("  - mobileNumberText: '$mobileNumberText' 🔍");
        debugPrint("  - selectedCustomerID: $selectedCustomerID");
        debugPrint(
            "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave;

        if (selectedCustomerID != null) {
          // Customer is selected from list
          customerPhoneToSave = selectedCustomerPhone;
          debugPrint(
              "  ✅ Customer from list - using selectedCustomerPhone: '$customerPhoneToSave'");
        } else if (mobileNumberText != null && mobileNumberText!.isNotEmpty) {
          // Phone number entered directly (not from customer list)
          customerPhoneToSave = mobileNumberText;
          debugPrint(
              "  ✅ Phone-only order - using mobileNumberText: '$customerPhoneToSave'");
        } else {
          // Fallback to selectedCustomerPhone
          customerPhoneToSave = selectedCustomerPhone;
          debugPrint(
              "  ⚠️ Fallback - using selectedCustomerPhone: '$customerPhoneToSave'");
        }

        localProductProvider.updateSavedOrder(
          currentOrder.id,
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "saved",
        );

        showScaffold(
          context: context,
          message: "Order Updated Successfully",
        );
      } else {
        // Save as new order
        debugPrint("💾 Saving as new order");

        // Debug customer info being saved
        debugPrint("📝 SAVING NEW ORDER - Customer info:");
        debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
        debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
        debugPrint("  - mobileNumberText: '$mobileNumberText' 🔍");
        debugPrint("  - selectedCustomerID: $selectedCustomerID");
        debugPrint(
            "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");

        // **FIX**: Properly determine customer info for phone-only orders
        String? customerNameToSave = selectedCustomer?.name;
        String? customerPhoneToSave;

        if (selectedCustomerID != null) {
          // Customer is selected from list
          customerPhoneToSave = selectedCustomerPhone;
          debugPrint(
              "  ✅ Customer from list - using selectedCustomerPhone: '$customerPhoneToSave'");
        } else if (mobileNumberText != null && mobileNumberText!.isNotEmpty) {
          // Phone number entered directly (not from customer list)
          customerPhoneToSave = mobileNumberText;
          debugPrint(
              "  ✅ Phone-only order - using mobileNumberText: '$customerPhoneToSave'");
        } else {
          // Fallback to selectedCustomerPhone
          customerPhoneToSave = selectedCustomerPhone;
          debugPrint(
              "  ⚠️ Fallback - using selectedCustomerPhone: '$customerPhoneToSave'");
        }

        // Determine payment method and data
        String paymentMethod = "";
        String paidAmount = "";
        
        // Check if multi-payment is being used
        List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
        if (selectedPaymentMethods.length > 1) {
          // Multi-payment: store as JSON
          Map<String, dynamic> multiPaymentData = {
            "methods": selectedPaymentMethods,
            "amounts": {
              "CASH": _cashAmountController.text.isNotEmpty ? _cashAmountController.text : "0",
              "CARD": _cardAmountController.text.isNotEmpty ? _cardAmountController.text : "0",
              "UPI": _upiAmountController.text.isNotEmpty ? _upiAmountController.text : "0",
            },
            "isMultiPayment": true
          };
          paymentMethod = json.encode(multiPaymentData);
          paidAmount = _getTotalPaidAmount().toString();
        } else {
          // Single payment method
          if (selectedPaymentMethods.isNotEmpty) {
            paymentMethod = selectedPaymentMethods.first;
            if (paymentMethod == "CASH") {
              paidAmount = _cashAmountController.text;
            } else if (paymentMethod == "CARD") {
              paidAmount = _cardAmountController.text;
            } else if (paymentMethod == "UPI") {
              paidAmount = _upiAmountController.text;
            }
          } else {
            // Fallback to old iconColor logic
            if (iconColor == 1) {
              paymentMethod = "CASH";
            } else if (iconColor == 2) {
              paymentMethod = "CARD";
            } else if (iconColor == 3) {
              paymentMethod = "UPI";
            }
            paidAmount = _paidAmountController.text;
          }
        }

        localProductProvider.saveCurrentCartAsOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "saved",
        );

        showScaffold(
          context: context,
          message: "Order Saved Successfully",
        );
      }

      localProductProvider.clearCart();

      // Clear form fields
      setState(() {
        mobileNumberText = ""; // Clear the variable
        selectedCustomerID = null;
        selectedCustomerPhone = null;
        iconColor = 1; // Reset to default cash payment method
        mobileNumberTextController.clear();
        quantityController.clear();
        barcodeController.clear();
        selectedProductIdController.clear();
        unitPriceController.clear();
        isCustomerFound = false;
        selectedCustomer = null;
        isCouponApplied = false;
        coupenCodeTextController.clear();
        _transactionNumberController.clear();
        _paidAmountController.clear();
        _balanceAmount = 0;
        _userChangedPaidAmount = false; // Reset paid amount flag
        _carNumberController.clear();
        _commentController.clear();
        _isCustomerManuallySelected =
            false; // Reset manual selection after save
        // Reset multi-payment fields
        _isCashSelected = true;
        _isCardSelected = false;
        _isUpiSelected = false;
        _cashAmountController.clear();
        _cardAmountController.clear();
        _upiAmountController.clear();
      });

      resetAutocomplete();
      _focusTextField();

      // Reset to default sales executive after saving
      _fetchCustomers();
    } catch (error) {
      debugPrint(error.toString());
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
    } finally {
      _clearCart();
      setState(() {
        isLoadingSaveOrder = false; // Indicate that loading has finished
      });
    }
  }

  void _saveOrderAndPrint() async {
    setState(() {
      isLoadingSaveOrderAndPrint = true; // Indicate that loading has started
    });
    debugPrint("Save Order and Print pressed");
    try {
      if (Provider.of<LocalProductProvider>(context, listen: false)
          .cartItems
          .isEmpty) {
        showScaffoldError(
          context: context,
          message: "Please add items to cart",
        );
        return;
      }

      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Debug: Log current cart items with custom pricing
      debugPrint("💾 LOCAL SAVE AND PRINT - Cart items with custom pricing:");
      for (var item in localProductProvider.cartItems) {
        debugPrint("  📦 ${item.product.productName}");
        debugPrint("    - Quantity: ${item.quantity}");
        debugPrint("    - Custom Price: ${item.price}");
        debugPrint("    - Custom MRP: ${item.mrp}");
        debugPrint("    - Stock ID: ${item.selectedStock?.id}");
      }

      // Validate that all items have valid pricing
      bool hasInvalidPricing = localProductProvider.cartItems
          .any((item) => item.price == null || item.price! < 0);

      if (hasInvalidPricing) {
        showScaffoldError(
          context: context,
          message: "Please ensure all items have valid prices before saving",
        );
        return;
      }

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;
      SavedOrder? orderToUse;

      if (currentOrder != null) {
        // We're editing an existing order, move it to confirmed orders
        debugPrint(
            "💾 Moving existing order to confirmed: ${currentOrder.orderNumber}");
        orderToUse =
            localProductProvider.moveToConfirmedOrders(currentOrder.id);

        if (orderToUse != null) {
          showScaffold(
            context: context,
            message: "Order moved to confirmed orders",
          );
        } else {
          // If the order couldn't be moved (shouldn't happen), create a new confirmed order
          debugPrint("💾 Creating new confirmed order (fallback)");

          // **FIX**: Properly determine customer info for phone-only orders
          String? customerNameToSave = selectedCustomer?.name;
          String? customerPhoneToSave;

          if (selectedCustomerID != null) {
            // Customer is selected from list
            customerPhoneToSave = selectedCustomerPhone;
            debugPrint(
                "  ✅ Save&Print(fallback) - Customer from list: '$customerPhoneToSave'");
          } else if (mobileNumberText != null && mobileNumberText!.isNotEmpty) {
            // Phone number entered directly (not from customer list)
            customerPhoneToSave = mobileNumberText;
            debugPrint(
                "  ✅ Save&Print(fallback) - Phone-only order: '$customerPhoneToSave'");
          } else {
            // Fallback to selectedCustomerPhone
            customerPhoneToSave = selectedCustomerPhone;
            debugPrint(
                "  ⚠️ Save&Print(fallback) - Fallback: '$customerPhoneToSave'");
          }

          // Determine payment method and data
          String paymentMethod = "";
          String paidAmount = "";
          
          // Check if multi-payment is being used
          List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
          if (selectedPaymentMethods.length > 1) {
            // Multi-payment: store as JSON
            Map<String, dynamic> multiPaymentData = {
              "methods": selectedPaymentMethods,
              "amounts": {
                "CASH": _cashAmountController.text.isNotEmpty ? _cashAmountController.text : "0",
                "CARD": _cardAmountController.text.isNotEmpty ? _cardAmountController.text : "0",
                "UPI": _upiAmountController.text.isNotEmpty ? _upiAmountController.text : "0",
              },
              "isMultiPayment": true
            };
            paymentMethod = json.encode(multiPaymentData);
            paidAmount = _getTotalPaidAmount().toString();
          } else {
            // Single payment method
            if (selectedPaymentMethods.isNotEmpty) {
              paymentMethod = selectedPaymentMethods.first;
              if (paymentMethod == "CASH") {
                paidAmount = _cashAmountController.text;
              } else if (paymentMethod == "CARD") {
                paidAmount = _cardAmountController.text;
              } else if (paymentMethod == "UPI") {
                paidAmount = _upiAmountController.text;
              }
            } else {
              // Fallback to old iconColor logic
              if (iconColor == 1) {
                paymentMethod = "CASH";
              } else if (iconColor == 2) {
                paymentMethod = "CARD";
              } else if (iconColor == 3) {
                paymentMethod = "UPI";
              }
              paidAmount = _paidAmountController.text;
            }
          }

          orderToUse = localProductProvider.saveCurrentCartAsConfirmedOrder(
            customerName: customerNameToSave,
            customerPhone: customerPhoneToSave,
            comment: _commentController.text,
            deliveryMethod: deliveryMethod,
            // Include all API-compatible fields
            customerId: selectedCustomerID,
            paymentMethod: paymentMethod,
            paidAmount: paidAmount,
            balanceAmount: _balanceAmount.toString(),
            transactionId: _transactionNumberController.text,
            couponId: isCouponApplied ? coupenCodeTextController.text : null,
            deliveryMethodId: deliveryMethodId,
            carNumber: _carNumberController.text,
            status: "confirmed",
          );

          showScaffold(
            context: context,
            message: "Order saved to confirmed orders",
          );
        }
      } else {
        // Create a new confirmed order
        debugPrint("💾 Creating new confirmed order");

                  // **FIX**: Properly determine customer info for phone-only orders
          String? customerNameToSave = selectedCustomer?.name;
          String? customerPhoneToSave;

          if (selectedCustomerID != null) {
            // Customer is selected from list
            customerPhoneToSave = selectedCustomerPhone;
            debugPrint(
                "  ✅ Save&Print - Customer from list: '$customerPhoneToSave'");
          } else if (mobileNumberText != null && mobileNumberText!.isNotEmpty) {
            // Phone number entered directly (not from customer list)
            customerPhoneToSave = mobileNumberText;
            debugPrint(
                "  ✅ Save&Print - Phone-only order: '$customerPhoneToSave'");
          } else {
            // Fallback to selectedCustomerPhone
            customerPhoneToSave = selectedCustomerPhone;
            debugPrint("  ⚠️ Save&Print - Fallback: '$customerPhoneToSave'");
          }

          // Determine payment method and data
          String paymentMethod = "";
          String paidAmount = "";
          
          // Check if multi-payment is being used
          List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
          if (selectedPaymentMethods.length > 1) {
            // Multi-payment: store as JSON
            Map<String, dynamic> multiPaymentData = {
              "methods": selectedPaymentMethods,
              "amounts": {
                "CASH": _cashAmountController.text.isNotEmpty ? _cashAmountController.text : "0",
                "CARD": _cardAmountController.text.isNotEmpty ? _cardAmountController.text : "0",
                "UPI": _upiAmountController.text.isNotEmpty ? _upiAmountController.text : "0",
              },
              "isMultiPayment": true
            };
            paymentMethod = json.encode(multiPaymentData);
            paidAmount = _getTotalPaidAmount().toString();
          } else {
            // Single payment method
            if (selectedPaymentMethods.isNotEmpty) {
              paymentMethod = selectedPaymentMethods.first;
              if (paymentMethod == "CASH") {
                paidAmount = _cashAmountController.text;
              } else if (paymentMethod == "CARD") {
                paidAmount = _cardAmountController.text;
              } else if (paymentMethod == "UPI") {
                paidAmount = _upiAmountController.text;
              }
            } else {
              // Fallback to old iconColor logic
              if (iconColor == 1) {
                paymentMethod = "CASH";
              } else if (iconColor == 2) {
                paymentMethod = "CARD";
              } else if (iconColor == 3) {
                paymentMethod = "UPI";
              }
              paidAmount = _paidAmountController.text;
            }
          }

        orderToUse = localProductProvider.saveCurrentCartAsConfirmedOrder(
          customerName: customerNameToSave,
          customerPhone: customerPhoneToSave,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
          // Include all API-compatible fields
          customerId: selectedCustomerID,
          paymentMethod: paymentMethod,
          paidAmount: paidAmount,
          balanceAmount: _balanceAmount.toString(),
          transactionId: _transactionNumberController.text,
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
        );

        showScaffold(
          context: context,
          message: "Order saved to confirmed orders",
        );
      }

      try {
        // Print the order that was just confirmed
        printFromSavedOrder(orderToUse);
      } catch (error) {
        debugPrint(error.toString());
      }

      localProductProvider.clearCart();

      // Clear form fields
      setState(() {
        mobileNumberText = ""; // Clear the variable
        selectedCustomerID = null;
        selectedCustomerPhone = null;
        iconColor = 1; // Reset to default cash payment method
        mobileNumberTextController.clear();
        quantityController.clear();
        barcodeController.clear();
        selectedProductIdController.clear();
        unitPriceController.clear();
        isCustomerFound = false;
        selectedCustomer = null;
        isCouponApplied = false;
        coupenCodeTextController.clear();
        _transactionNumberController.clear();
        _paidAmountController.clear();
        _balanceAmount = 0;
        _userChangedPaidAmount = false; // Reset paid amount flag
        _carNumberController.clear();
        _commentController.clear();
        _isCustomerManuallySelected =
            false; // Reset manual selection after save
      });

      resetAutocomplete();
      _focusTextField();

      // Reset to default sales executive after saving
      _fetchCustomers();
    } catch (error) {
      debugPrint(error.toString());
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
    } finally {
      _clearCart();
      setState(() {
        isLoadingSaveOrderAndPrint = false;
      });
    }
  }

  // Reset manual selection when loading an order
  void _resetManualSelection() {
    setState(() {
      _isCustomerManuallySelected = false;
    });
  }

  // Check if we have a manually entered phone number
  bool _hasManuallyEnteredPhone() {
    return mobileNumberText?.isNotEmpty == true &&
        mobileNumberText!.length >= 10 &&
        selectedCustomerID == null;
  }

  // Function to load a saved order for editing
  void _loadSavedOrderForEditing(String orderId) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Load the order into the current cart
      localProductProvider.loadOrderForEditing(orderId);

      // Get the current order
      SavedOrder? currentOrder = localProductProvider.currentOrder;

      if (currentOrder != null) {
        debugPrint("===== SAVED ORDER LOADING START =====");
        debugPrint("📋 LOADING SAVED ORDER FOR EDITING:");
        debugPrint("  - Order: ${currentOrder.orderNumber}");
        debugPrint("  - Order ID: ${currentOrder.id}");
        debugPrint("  - Customer Name: '${currentOrder.customerName}'");
        debugPrint("  - Customer ID: ${currentOrder.customerId}");
        debugPrint("  - Customer Phone: '${currentOrder.customerPhone}'");
        debugPrint("  - Payment Method: ${currentOrder.paymentMethod}");
        debugPrint("  - Delivery Method: ${currentOrder.deliveryMethod}");

        // **DEBUG**: Log all saved orders to check for phone number mixing
        debugPrint("🔍 ALL SAVED ORDERS IN MEMORY:");
        for (int i = 0; i < localProductProvider.savedOrders.length; i++) {
          final order = localProductProvider.savedOrders[i];
          debugPrint(
              "  [$i] ${order.orderNumber} - Phone: '${order.customerPhone}' - Name: '${order.customerName}'");
        }

        debugPrint("📝 CURRENT STATE BEFORE LOADING:");
        debugPrint(
            "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
        debugPrint("  - mobileNumberText: '$mobileNumberText'");
        debugPrint(
            "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
        debugPrint("  - selectedCustomerID: $selectedCustomerID");
        debugPrint("  - selectedCustomerPhone: $selectedCustomerPhone");
        debugPrint("  - isCustomerFound: $isCustomerFound");
        debugPrint("  - customerList length: ${customerList?.length ?? 0}");

        // **FIX: Restore all order details to the UI**
        setState(() {
          debugPrint("🔄 INSIDE setState - Starting restore process");

          // **FIX: Clear ALL customer-related state variables first to prevent cross-contamination**
          debugPrint("🧹 CLEARING ALL CUSTOMER STATE VARIABLES");
          salesExecutivemobileNumberText = "";
          mobileNumberText = "";
          selectedCustomerID = null;
          selectedCustomerPhone = null;
          selectedCustomer = null;
          isCustomerFound = false;
          mobileNumberTextController.clear();
          debugPrint("  ✅ All customer state variables cleared");

          // Clear current customer selection provider
          Provider.of<CustomerSelectionProvider>(context, listen: false)
              .clearSelectedCustomer();
          debugPrint("  ✅ Cleared customer selection provider");

          // Restore customer information
          if (currentOrder.customerId != null ||
              currentOrder.customerPhone != null) {
            debugPrint("📋 Customer info found in saved order");
            selectedCustomerID = currentOrder.customerId;
            selectedCustomerPhone = currentOrder.customerPhone;
            debugPrint("  - Set selectedCustomerID: $selectedCustomerID");
            debugPrint(
                "  - Set selectedCustomerPhone: '$selectedCustomerPhone'");

            // **FIX: Check if this is the default sales executive customer**
            final salesExecutiveProvider =
                Provider.of<SalesExecutiveProvider>(context, listen: false);
            final currentExecutive =
                salesExecutiveProvider.getCurrentUser(context);
            debugPrint("🔍 Checking if default sales executive customer:");
            debugPrint("  - Current Executive ID: ${currentExecutive?.id}");
            debugPrint("  - Current Executive Name: ${currentExecutive?.name}");
            debugPrint(
                "  - Current Executive Phone: ${currentExecutive?.phone}");
            debugPrint(
                "  - Saved Order Customer ID: ${currentOrder.customerId}");

            bool isDefaultSalesExecutiveCustomer = false;

            if (currentExecutive != null &&
                currentOrder.customerId == currentExecutive.id) {
              // This is the default sales executive customer - keep read-only behavior
              isDefaultSalesExecutiveCustomer = true;
              salesExecutivemobileNumberText = currentOrder.customerPhone ?? "";
              debugPrint(
                  "✅ Loading default sales executive customer (read-only)");
              debugPrint(
                  "  - Set salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");

              // Always show name + phone for sales executive
              if (currentExecutive.name != null &&
                  currentExecutive.name!.isNotEmpty) {
                mobileNumberTextController.text =
                    "${currentExecutive.name} ${currentExecutive.phone}";
              } else {
                mobileNumberTextController.text = currentExecutive.phone ?? "";
              }
            } else {
              // This is a different customer - make field editable
              salesExecutivemobileNumberText = "";
              debugPrint("✅ Loading different customer (editable)");
              debugPrint(
                  "  - Cleared salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
            }

            // Find and set the full customer object if available
            if (customerList != null &&
                customerList!.isNotEmpty &&
                currentOrder.customerId != null) {
              debugPrint(
                  "🔍 Searching for customer in list of ${customerList!.length} customers");
              try {
                selectedCustomer = customerList!.firstWhere(
                  (customer) => customer.id == currentOrder.customerId,
                );
                debugPrint("✅ Found customer in list:");
                debugPrint("  - ID: ${selectedCustomer!.id}");
                debugPrint("  - Name: '${selectedCustomer!.name}'");
                debugPrint("  - Phone: '${selectedCustomer!.phone}'");

                // Update the global customer selection provider
                Provider.of<CustomerSelectionProvider>(context, listen: false)
                    .setSelectedCustomer(selectedCustomer!);
                debugPrint("  ✅ Updated global customer selection provider");

                // **FIX: If this is NOT the sales executive customer, show in autocomplete field**
                if (!isDefaultSalesExecutiveCustomer) {
                  // **FIX: Use the exact same format as normal customer selection**
                  String textToSet = "";
                  if (selectedCustomer!.name != null &&
                      selectedCustomer!.name!.isNotEmpty) {
                    textToSet =
                        "${selectedCustomer!.name} ${selectedCustomer!.phone}";
                    debugPrint(
                        "  📝 Setting text with name+phone: '$textToSet'");
                  } else {
                    textToSet = selectedCustomer!.phone ?? "";
                    debugPrint(
                        "  📝 Setting text with phone only: '$textToSet'");
                  }
                  mobileNumberTextController.text = textToSet;
                  mobileNumberText = textToSet; // <-- Ensure both are set

                  // **FIX: For custom phone orders, mobileNumberText should be the phone number**
                  if (isDefaultSalesExecutiveCustomer) {
                    mobileNumberText = selectedCustomer!.phone ?? "";
                  } else if (currentOrder.customerId == null) {
                    // This is a phone-only order, set mobileNumberText to the phone
                    mobileNumberText = currentOrder.customerPhone ?? "";
                  } else {
                    // Regular customer from list, clear mobileNumberText
                    // mobileNumberText = ""; // <-- Don't clear, keep the text for display
                  }
                  debugPrint(
                      "  - Set mobileNumberText to: '$mobileNumberText'");
                  debugPrint(
                      "  - Set mobileNumberTextController.text to: '${mobileNumberTextController.text}'");
                }

                isCustomerFound = true;
                debugPrint("  - Set isCustomerFound: $isCustomerFound");
              } catch (e) {
                debugPrint(
                    "⚠️ Customer not found in list, creating virtual customer");
                debugPrint("  - Error: $e");
                // Create a virtual customer if not found in list
                selectedCustomer = CustomerListModelData(
                  id: currentOrder.customerId,
                  name: currentOrder.customerName,
                  phone: currentOrder.customerPhone,
                );
                debugPrint("  📝 Created virtual customer:");
                debugPrint("    - ID: ${selectedCustomer!.id}");
                debugPrint("    - Name: '${selectedCustomer!.name}'");
                debugPrint("    - Phone: '${selectedCustomer!.phone}'");

                Provider.of<CustomerSelectionProvider>(context, listen: false)
                    .setSelectedCustomer(selectedCustomer!);
                debugPrint("  ✅ Updated global customer selection provider");

                // **FIX: Handle case where name might be null/empty**
                String textToSet = "";
                if (selectedCustomer!.name != null &&
                    selectedCustomer!.name!.isNotEmpty) {
                  // Show name + phone (normal format)
                  textToSet =
                      "${selectedCustomer!.name} ${selectedCustomer!.phone}";
                  debugPrint("  📝 Setting text with name+phone: '$textToSet'");
                } else {
                  // Show only phone number if no name available
                  textToSet = selectedCustomer!.phone ?? "";
                  debugPrint("  📝 Setting text with phone only: '$textToSet'");
                }
                mobileNumberTextController.text = textToSet;

                // **FIX: Set mobileNumberText correctly based on order type**
                if (isDefaultSalesExecutiveCustomer) {
                  mobileNumberText = selectedCustomer!.phone ?? "";
                } else if (currentOrder.customerId == null &&
                    currentOrder.customerPhone != null) {
                  // This is a phone-only order, set mobileNumberText to the phone
                  mobileNumberText = currentOrder.customerPhone;
                  debugPrint(
                      "  - Set mobileNumberText for phone-only case: '$mobileNumberText'");
                } else {
                  // Regular customer from list, clear mobileNumberText
                  mobileNumberText = "";
                  debugPrint(
                      "  - Set mobileNumberText to: '$mobileNumberText'");
                }

                debugPrint(
                    "  - Set mobileNumberTextController.text to: '${mobileNumberTextController.text}'");

                isCustomerFound = currentOrder.customerId != null;
                debugPrint("  - Set isCustomerFound: $isCustomerFound");
              }
            } else {
              debugPrint(
                  "📋 No customer list available or customer ID is null");

              // Check if we have at least a phone number
              if (currentOrder.customerPhone != null &&
                  currentOrder.customerPhone!.isNotEmpty) {
                debugPrint(
                    "  - Found phone number: '${currentOrder.customerPhone}'");

                // Create virtual customer with available data
                selectedCustomer = CustomerListModelData(
                  id: currentOrder.customerId,
                  name: currentOrder.customerName,
                  phone: currentOrder.customerPhone,
                );

                // If we have a customer ID, set it in the provider
                if (currentOrder.customerId != null) {
                  Provider.of<CustomerSelectionProvider>(context, listen: false)
                      .setSelectedCustomer(selectedCustomer!);
                }

                // **FIX: Handle case where name might be null/empty**
                if (currentOrder.customerName != null &&
                    currentOrder.customerName!.isNotEmpty) {
                  // Show name + phone (normal format)
                  mobileNumberTextController.text =
                      "${currentOrder.customerName} ${currentOrder.customerPhone}";
                  debugPrint(
                      "  📝 Setting text with name+phone: '${mobileNumberTextController.text}'");
                } else {
                  // Show only phone number if no name available
                  mobileNumberTextController.text =
                      currentOrder.customerPhone ?? "";
                  debugPrint(
                      "  📝 Setting text with phone only: '${mobileNumberTextController.text}'");
                }

                // **FIX: Set mobileNumberText correctly based on order type**
                if (isDefaultSalesExecutiveCustomer) {
                  mobileNumberText = currentOrder.customerPhone ?? "";
                } else if (currentOrder.customerId == null) {
                  // This is a phone-only order, set mobileNumberText to the phone
                  mobileNumberText = currentOrder.customerPhone ?? "";
                  debugPrint(
                      "  - Set mobileNumberText for phone-only case: '$mobileNumberText'");
                } else {
                  // Regular customer from list, clear mobileNumberText
                  mobileNumberText = "";
                }

                isCustomerFound = currentOrder.customerId != null;
                debugPrint("  - Set isCustomerFound: $isCustomerFound");
              }
            }
          } else {
            // No customer info in saved order - reset to default behavior
            debugPrint(
                "📋 No customer info in saved order, resetting to default");
            salesExecutivemobileNumberText = ""; // Make field editable
            selectedCustomerID = null;
            selectedCustomerPhone = null;
            selectedCustomer = null;
            mobileNumberTextController.clear();
            mobileNumberText = "";
            isCustomerFound = false;

            // Clear customer selection provider
            Provider.of<CustomerSelectionProvider>(context, listen: false)
                .clearSelectedCustomer();
          }

          // Restore payment method
          if (currentOrder.paymentMethod != null) {
            // Check if it's a JSON string (multi-payment)
            if (currentOrder.paymentMethod!.startsWith('{')) {
              try {
                Map<String, dynamic> multiPaymentData = json.decode(currentOrder.paymentMethod!);
                if (multiPaymentData['isMultiPayment'] == true) {
                  List<String> methods = List<String>.from(multiPaymentData['methods'] ?? []);
                  Map<String, dynamic> amounts = Map<String, dynamic>.from(multiPaymentData['amounts'] ?? {});
                  
                  // Reset all payment methods first
                  _isCashSelected = false;
                  _isCardSelected = false;
                  _isUpiSelected = false;
                  _cashAmountController.clear();
                  _cardAmountController.clear();
                  _upiAmountController.clear();
                  
                  // Restore multi-payment selections and amounts
                  if (methods.contains("CASH")) {
                    _isCashSelected = true;
                    _cashAmountController.text = amounts['CASH'] ?? "0";
                  }
                  if (methods.contains("CARD")) {
                    _isCardSelected = true;
                    _cardAmountController.text = amounts['CARD'] ?? "0";
                  }
                  if (methods.contains("UPI")) {
                    _isUpiSelected = true;
                    _upiAmountController.text = amounts['UPI'] ?? "0";
                  }
                  
                  // Clear iconColor for multi-payment
                  iconColor = 0;
                }
              } catch (e) {
                debugPrint("Error parsing multi-payment data: $e");
                // Fall back to single payment method
                switch (currentOrder.paymentMethod?.toUpperCase()) {
                  case "CASH":
                    iconColor = 1;
                    _isCashSelected = true;
                    _isCardSelected = false;
                    _isUpiSelected = false;
                    break;
                  case "CARD":
                    iconColor = 2;
                    _isCashSelected = false;
                    _isCardSelected = true;
                    _isUpiSelected = false;
                    break;
                  case "UPI":
                    iconColor = 3;
                    _isCashSelected = false;
                    _isCardSelected = false;
                    _isUpiSelected = true;
                    break;
                  default:
                    iconColor = 1; // Default to cash
                    _isCashSelected = true;
                    _isCardSelected = false;
                    _isUpiSelected = false;
                }
              }
            } else {
              // Single payment method
              switch (currentOrder.paymentMethod?.toUpperCase()) {
                case "CASH":
                  iconColor = 1;
                  _isCashSelected = true;
                  _isCardSelected = false;
                  _isUpiSelected = false;
                  break;
                case "CARD":
                  iconColor = 2;
                  _isCashSelected = false;
                  _isCardSelected = true;
                  _isUpiSelected = false;
                  break;
                case "UPI":
                  iconColor = 3;
                  _isCashSelected = false;
                  _isCardSelected = false;
                  _isUpiSelected = true;
                  break;
                default:
                  iconColor = 1; // Default to cash
                  _isCashSelected = true;
                  _isCardSelected = false;
                  _isUpiSelected = false;
              }
            }
          } else {
            iconColor = 1; // Default to cash
          }

          // Restore payment amounts
          _paidAmountController.text = currentOrder.paidAmount ?? "0.0";
          _balanceAmount =
              double.tryParse(currentOrder.balanceAmount ?? "0.0") ?? 0.0;
          _userChangedPaidAmount =
              true; // Mark as user-set to prevent auto-update
          
          // For single payment methods, also populate the individual payment controllers
          if (!currentOrder.paymentMethod!.startsWith('{')) {
            String paidAmount = currentOrder.paidAmount ?? "0.0";
            if (_isCashSelected) {
              _cashAmountController.text = paidAmount;
            } else if (_isCardSelected) {
              _cardAmountController.text = paidAmount;
            } else if (_isUpiSelected) {
              _upiAmountController.text = paidAmount;
            }
          }

          // Restore transaction details
          _transactionNumberController.text = currentOrder.transactionId ?? "";

          // Restore delivery method
          if (currentOrder.deliveryMethod != null) {
            deliveryMethod = currentOrder.deliveryMethod!;
            deliveryMethodId = currentOrder.deliveryMethodId ?? "3";
          } else {
            deliveryMethod = "Store Takeaway";
            deliveryMethodId = "3";
          }

          // Restore comments and car number
          _commentController.text = currentOrder.comment ?? "";
          _carNumberController.text = currentOrder.carNumber ?? "";

          // Restore coupon if any
          if (currentOrder.couponId != null &&
              currentOrder.couponId!.isNotEmpty) {
            coupenCodeTextController.text = currentOrder.couponId!;
            isCouponApplied = true;
          } else {
            coupenCodeTextController.clear();
            isCouponApplied = false;
          }
          debugPrint("📝 FINAL STATE AFTER LOADING:");
          debugPrint(
              "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
          debugPrint("  - mobileNumberText: '$mobileNumberText' 🔍");
          debugPrint(
              "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
          debugPrint("  - selectedCustomerID: $selectedCustomerID");
          debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
          debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
          debugPrint("  - isCustomerFound: $isCustomerFound");
          debugPrint(
              "  - 🔍 SUMMARY: Order '${currentOrder.orderNumber}' with phone '${currentOrder.customerPhone}' → mobileNumberText='$mobileNumberText'");
        });

        debugPrint("✅ Order details restored to UI successfully");
        debugPrint("===== SAVED ORDER LOADING END =====");

        // Force a complete rebuild of the autocomplete widget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint("🔄 Post-frame callback - forcing rebuild");
          debugPrint("  - Will reset autocomplete key and trigger rebuild");
          if (mounted) {
            setState(() {
              // **FIX: Reset the autocomplete key to force complete rebuild**
              _autocompletePhoneKey = GlobalKey();
              debugPrint("🔨 Triggering rebuild after order load with new key");
            });
          }
        });

        showScaffold(
          context: context,
          message: "Order loaded for editing",
        );
      }
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "Failed to load order. Please try again.");
    }
  }

  void _createOrderAndPrint() async {
    // Check for internet connection before proceeding
    if (!_hasInternet) {
      showScaffoldError(
        context: context,
        message: "No internet connection. Cannot create order online.",
      );
      return; // Stop execution if no internet
    }
    debugPrint("Create Order and Print pressed");
    debugPrint("🚀 API REQUEST STARTING - Create Order and Print");

    // Debug multi-payment detection
    List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
    List<Map<String, dynamic>> paidMethods = _getPaidMethods();
    bool isMultiPayment = selectedPaymentMethods.length > 1;

    debugPrint("💰 Multi-payment check: $isMultiPayment");
    debugPrint("💰 Selected payment methods: $selectedPaymentMethods");
    debugPrint("💰 Paid methods: $paidMethods");
    setState(() {
      isLoadingCreateOrder = true; // Indicate that loading has started
    });
    try {
      if (selectedCustomerID == null && mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "Please select a customer",
        );
      } else if (iconColor != 1 && iconColor != 2 && iconColor != 3) {
        showScaffoldError(
          context: context,
          message: "Please chose a Payment Method",
        );
      } else if (deliveryMethod == "Car Delivery" &&
          _carNumberController.text == "") {
        showScaffoldError(
          context: context,
          message: "Please enter Car Number",
        );
      } else {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        // debugPrint("accessToken From AuthModel $accessToken");
        final provider = Provider.of<CartProvider>(context, listen: false);
        int? cartId = provider.getCartIDForOrder;
        debugPrint("📦 Cart ID for order: $cartId");

        String paymentMethod = "";

        if (iconColor == 1) {
          paymentMethod = "CASH";
        } else if (iconColor == 2) {
          paymentMethod = "CARD";
        } else if (iconColor == 3) {
          paymentMethod = "UPI";
        }
        debugPrint("💰 Payment Method: $paymentMethod");

        final localProductProvider =
            Provider.of<LocalProductProvider>(context, listen: false);
        final cartItems = localProductProvider.cartItems;

        if (localProductProvider.cartItems.isEmpty) {
          showScaffoldError(
            context: context,
            message: "Please add items to cart",
          );
          return;
        }

        // Validate that all items have valid pricing before API call
        bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
            item.price == null ||
            item.price! < 0 ||
            item.mrp == null ||
            item.mrp! < 0);

        if (hasInvalidPricing) {
          showScaffoldError(
            context: context,
            message:
                "Please ensure all items have valid prices and MRP before confirming order",
          );
          return;
        }

        List<Map<String, dynamic>> items = [];

        for (var item in cartItems) {
          debugPrint("📦 Order Item: ${item.product.productName}");
          debugPrint("  - Product ID: ${item.product.productId}");
          debugPrint("  - Quantity: ${item.quantity}");
          debugPrint("  - Custom Price: ${item.price}");
          debugPrint("  - Custom MRP: ${item.mrp}");
          debugPrint("  - Stock ID: ${item.selectedStock?.id}");

          items.add({
            'product_id': item.product.productId,
            'quantity': item.quantity,
            'price': item.price,
            'mrp': item.mrp, // 🔧 FIX: Include custom MRP in API call
            'stock_id': item
                .selectedStock?.id, // 🔧 FIX: Include stock_id for consistency
          });
        }

        debugPrint("📋 Order Items: ${items.length} products");
        debugPrint(
            "💵 Total Price: ${localProductProvider.priceSummary!.netTotal}");
        debugPrint("👤 Customer ID: $selectedCustomerID");
        debugPrint(
            "📱 Customer Phone: ${selectedCustomerPhone ?? mobileNumberText}");
        debugPrint(
            "💳 Payment Details - Paid: ${_paidAmountController.text}, Balance: $_balanceAmount");
        debugPrint(
            "🚚 Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");

        await Provider.of<CartProvider>(context, listen: false)
            .addToOrderAPI(
          items: items,
          cartIds: cartId ?? 0,
          accessToken: accessToken ?? "",
          transactionId: _transactionNumberController.text,
          totalPrice: Provider.of<LocalProductProvider>(context, listen: false)
              .priceSummary!
              .netTotal
              .toString(),
          customerId: selectedCustomerID,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          // Use multi-payment format if available, otherwise fallback to single payment
          paymentMethod:
              _getSelectedPaymentMethods().length > 1 ? null : paymentMethod,
          paidAmount: _getSelectedPaymentMethods().length > 1
              ? null
              : _paidAmountController.text,
          paymentMethods: _getSelectedPaymentMethods().length > 1
              ? _getSelectedPaymentMethods()
              : null,
          paidMethods: _getSelectedPaymentMethods().length > 1
              ? _getPaidMethods()
              : null,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          comment: _commentController.text,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
        )
            .then((response) async {
          debugPrint(
              "✅ API RESPONSE - Create Order and Print: ${json.encode(response)}");
          if (response["order_id"] != null) {
            showScaffold(
              context: context,
              message: "Order Saved Successfully",
            );

            // Delete the current order if it exists in local storage
            if (localProductProvider.currentOrder != null) {
              localProductProvider
                  .deleteSavedOrder(localProductProvider.currentOrder!.id);
            }

            localProductProvider.clearCart();

            try {
              String ordersId = response["order_number"].toString();
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;

              debugPrint(
                  "🔍 Fetching order details for print - Order #$ordersId");
              final OrderDetailsresponse = await SalesProvider()
                  .listOrderDetails(context, ordersId, accessToken ?? "");
              debugPrint("✅ Order details received for printing");

              OrderDetailsModel orderDetails =
                  OrderDetailsModel.fromJson(OrderDetailsresponse);

              String? formattedTotal =
                  orderDetails.data?.cart?.priceSummary?.netTotal.toString();
              String? savedTotal =
                  orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

              String storeName = orderDetails.data!.cart!.storeName ?? "";
              String orderDate = orderDetails.data!.orderDate ?? "";

              debugPrint(
                  "🖨️ Navigating to print page for order #${orderDetails.data!.orderNumber}");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrintPage(
                    storeName: storeName,
                    cartItems: orderDetails.data!.cart!.cartItems!,
                    formattedTotal: formattedTotal!,
                    savedTotal: savedTotal!,
                    orderDate: orderDate,
                    orderNumber: orderDetails.data!.orderNumber ?? "",
                  ),
                ),
              );
            } catch (error) {
              debugPrint("❌ Error fetching order details for print: $error");
            }

            // Clear the mobile number after successful save
            setState(() {
              mobileNumberText = ""; // Clear the variable
              selectedCustomerID = null;
              selectedCustomerPhone = null;
              iconColor = 1; // Reset to default cash payment method
              mobileNumberTextController.clear();
              quantityController.clear();
              barcodeController.clear();
              selectedProductIdController.clear();
              unitPriceController.clear();
              isCustomerFound = false;
              selectedCustomer = null;
              isCouponApplied = false;
              coupenCodeTextController.clear();
              _transactionNumberController.clear();
              _paidAmountController.clear();
              _balanceAmount = 0;
              _userChangedPaidAmount = false; // Reset paid amount flag
              _carNumberController.clear();
              _commentController.clear();
            });
            resetAutocomplete();

            // Reset to default sales executive after confirming
            _fetchCustomers();
          } else {
            debugPrint("❌ API ERROR - Create Order and Print failed");
            showScaffoldError(
              context: context,
              message: "Failed to Save Order",
              // message: "${addToOrderModel.message}",
            );
          }
        });
      }
      _focusTextField();
    } catch (error) {
      debugPrint("❌ EXCEPTION in _createOrderAndPrint: $error");
    } finally {
      _clearCart();
      // Set loading to false at the end of the function
      setState(() {
        isLoadingCreateOrder = false; // Indicate that loading has finished
      });
      debugPrint("🏁 Create Order and Print process completed");
    }
  }

  void _confirmOrder() async {
    // Check for internet connection before proceeding
    if (!_hasInternet) {
      showScaffoldError(
        context: context,
        message: "No internet connection. Cannot confirm order online.",
      );
      return; // Stop execution if no internet
    }
    debugPrint("Create Order pressed");
    debugPrint("🚀 API REQUEST STARTING - Confirm Order");

    // Debug multi-payment detection
    List<String> selectedPaymentMethods = _getSelectedPaymentMethods();
    List<Map<String, dynamic>> paidMethods = _getPaidMethods();
    bool isMultiPayment = selectedPaymentMethods.length > 1;

    debugPrint("💰 Multi-payment check: $isMultiPayment");
    debugPrint("💰 Selected payment methods: $selectedPaymentMethods");
    debugPrint("💰 Paid methods: $paidMethods");
    setState(() {
      isLoadingConfirmOrder = true; // Indicate that loading has started
    });
    try {
      if (selectedCustomerID == null && mobileNumberText == "") {
        showScaffoldError(
          context: context,
          message: "Please select a customer",
        );
      } else if (iconColor != 1 && iconColor != 2 && iconColor != 3) {
        showScaffoldError(
          context: context,
          message: "Please chose a Payment Method",
        );
      } else if (deliveryMethod == "Car Delivery" &&
          _carNumberController.text == "") {
        showScaffoldError(
          context: context,
          message: "Please enter Car Number",
        );
      } else {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        // debugPrint("accessToken From AuthModel $accessToken");
        final provider = Provider.of<CartProvider>(context, listen: false);
        int? cartId = provider.getCartIDForOrder;
        debugPrint("📦 Cart ID for order: $cartId");

        String paymentMethod = "";

        if (iconColor == 1) {
          paymentMethod = "CASH";
        } else if (iconColor == 2) {
          paymentMethod = "CARD";
        } else if (iconColor == 3) {
          paymentMethod = "UPI";
        }
        debugPrint("💰 Payment Method: $paymentMethod");

        final localProductProvider =
            Provider.of<LocalProductProvider>(context, listen: false);
        final cartItems = localProductProvider.cartItems;

        if (localProductProvider.cartItems.isEmpty) {
          showScaffoldError(
            context: context,
            message: "Please add items to cart",
          );
          return;
        }

        // Validate that all items have valid pricing before API call
        bool hasInvalidPricing = localProductProvider.cartItems.any((item) =>
            item.price == null ||
            item.price! < 0 ||
            item.mrp == null ||
            item.mrp! < 0);

        if (hasInvalidPricing) {
          showScaffoldError(
            context: context,
            message:
                "Please ensure all items have valid prices and MRP before confirming order",
          );
          return;
        }

        List<Map<String, dynamic>> items = [];

        for (var item in cartItems) {
          debugPrint("📦 Order Item: ${item.product.productName}");
          debugPrint("  - Product ID: ${item.product.productId}");
          debugPrint("  - Quantity: ${item.quantity}");
          debugPrint("  - Custom Price: ${item.price}");
          debugPrint("  - Custom MRP: ${item.mrp}");
          debugPrint("  - Stock ID: ${item.selectedStock?.id}");

          items.add({
            'product_id': item.product.productId,
            'quantity': item.quantity,
            'price': item.price,
            'mrp': item.mrp, // 🔧 FIX: Include custom MRP in API call
            'stock_id': item.selectedStock?.id,
          });
        }

        debugPrint("📋 Order Items: ${items.length} products");
        debugPrint(
            "💵 Total Price: ${localProductProvider.priceSummary!.netTotal}");
        debugPrint("👤 Customer ID: $selectedCustomerID");
        debugPrint(
            "📱 Customer Phone: ${selectedCustomerPhone ?? mobileNumberText}");
        debugPrint(
            "💳 Payment Details - Paid: ${_paidAmountController.text}, Balance: $_balanceAmount");
        debugPrint(
            "🚚 Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");

        await Provider.of<CartProvider>(context, listen: false)
            .addToOrderAPI(
          items: items,
          cartIds: cartId ?? 0,
          accessToken: accessToken ?? "",
          transactionId: _transactionNumberController.text,
          totalPrice: Provider.of<LocalProductProvider>(context, listen: false)
              .priceSummary!
              .netTotal
              .toString(),
          customerId: selectedCustomerID,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          // Use multi-payment format if available, otherwise fallback to single payment
          paymentMethod:
              _getSelectedPaymentMethods().length > 1 ? null : paymentMethod,
          paidAmount: _getSelectedPaymentMethods().length > 1
              ? null
              : _paidAmountController.text,
          paymentMethods: _getSelectedPaymentMethods().length > 1
              ? _getSelectedPaymentMethods()
              : null,
          paidMethods: _getSelectedPaymentMethods().length > 1
              ? _getPaidMethods()
              : null,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          comment: _commentController.text,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
        )
            .then((response) {
          debugPrint(
              "✅ API RESPONSE - Confirm Order: ${json.encode(response)}");
          if (response["order_id"] != null) {
            showScaffold(
              context: context,
              message: "Order Confirmed Successfully",
            );

            // Delete the current order if it exists in local storage
            if (localProductProvider.currentOrder != null) {
              localProductProvider
                  .deleteSavedOrder(localProductProvider.currentOrder!.id);
            }

            localProductProvider.clearCart();

            // Clear the mobile number after successful save
            setState(() {
              mobileNumberText = ""; // Clear the variable
              selectedCustomerID = null;
              selectedCustomerPhone = null;
              iconColor = 1; // Reset to default cash payment method
              mobileNumberTextController.clear();
              quantityController.clear();
              barcodeController.clear();
              selectedProductIdController.clear();
              unitPriceController.clear();
              isCustomerFound = false;
              selectedCustomer = null;
              isCouponApplied = false;
              coupenCodeTextController.clear();
              _transactionNumberController.clear();
              _paidAmountController.clear();
              _balanceAmount = 0;
              _userChangedPaidAmount = false; // Reset paid amount flag
              _carNumberController.clear();
              _commentController.clear();
            });
            resetAutocomplete();

            // Reset to default sales executive after confirming
            _fetchCustomers();
          } else {
            debugPrint("❌ API ERROR - Confirm Order failed");
            showScaffoldError(
              context: context,
              message: "Failed to Confirm Order",
            );
          }
        });
        _focusTextField();
      }
    } catch (error) {
      debugPrint("❌ EXCEPTION in _confirmOrder: $error");
    } finally {
      // Set loading to false at the end of the function
      setState(() {
        isLoadingConfirmOrder = false; // Indicate that loading has finished
      });
      debugPrint("🏁 Confirm Order process completed");
    }
  }

  void _getBalanceAmount() {
    // debugPrint(_paidAmountController.text);
    num netTotal = Provider.of<LocalProductProvider>(context, listen: false)
        .priceSummary!
        .netTotal;
    double paidAmount = double.tryParse(_paidAmountController.text) ?? 0.00;
    double balanceAmount = paidAmount - netTotal;
    if (balanceAmount < 0) {
      balanceAmount = 0.00;
    }
    setState(() {
      _balanceAmount = balanceAmount;
    });
  }

  // Multi-payment helper methods
  void _updateBalanceAmount() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    double cartTotal = localProductProvider.cartTotal;

    double totalPaid = _getTotalPaidAmount();
    double balance = totalPaid - cartTotal;

    if (balance < 0) {
      balance = 0.0;
    }

    setState(() {
      _balanceAmount = balance;
    });
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(_cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(_upiAmountController.text) ?? 0.0;
    return cashAmount + cardAmount + upiAmount;
  }

  void _autoFillPaymentAmount() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    double cartTotal = localProductProvider.cartTotal;
    double totalPaid = _getTotalPaidAmount();
    double remaining = cartTotal - totalPaid;

    if (remaining > 0) {
      // Find the first selected payment method that has no amount and fill it
      if (_isCashSelected && _cashAmountController.text.isEmpty) {
        _cashAmountController.text = remaining.toStringAsFixed(2);
      } else if (_isCardSelected && _cardAmountController.text.isEmpty) {
        _cardAmountController.text = remaining.toStringAsFixed(2);
      } else if (_isUpiSelected && _upiAmountController.text.isEmpty) {
        _upiAmountController.text = remaining.toStringAsFixed(2);
      }
    }
  }

  List<String> _getSelectedPaymentMethods() {
    List<String> methods = [];
    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      methods.add("CASH");
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      methods.add("CARD");
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      methods.add("UPI");
    }
    return methods;
  }

  List<Map<String, dynamic>> _getPaidMethods() {
    List<Map<String, dynamic>> paidMethods = [];

    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": "CASH",
        "amount": double.tryParse(_cashAmountController.text) ?? 0,
      });
    }

    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": "CARD",
        "amount": double.tryParse(_cardAmountController.text) ?? 0,
      });
    }

    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      paidMethods.add({
        "method": "UPI",
        "amount": double.tryParse(_upiAmountController.text) ?? 0,
      });
    }

    return paidMethods;
  }

  Widget _buildPaymentMethodRow({
    required bool isSelected,
    required String icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Size size,
    required VoidCallback onToggle,
    required void Function(String?) onAmountChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        children: [
          // Payment method icon (visual indicator only)
          BuildBoxShadowContainer(
            border: isSelected
                ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
                : Border.all(color: Colors.grey.shade300),
            padding: const EdgeInsets.all(8),
            blurRadius: 4,
            circleRadius: 5,
            width: 70,
            child: Column(
              children: [
                WebsafeSvg.asset(
                  icon,
                  width: 14,
                  height: 14,
                  color: isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                  fit: BoxFit.none,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s9,
                    0.12,
                    isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Amount input field - always visible
          Expanded(
            child: buildColumnWidgetForTextFields(
              controller: controller,
              size: size,
              height: size.height * .05,
              hintText: 'Enter $label amount',
              keyboardType: TextInputType.number,
              focusNode: focusNode,
              onchanged: (value) {
                // Auto-enable/disable based on amount
                double amount = double.tryParse(value ?? '') ?? 0;
                if (amount > 0 && !isSelected) {
                  onToggle(); // Enable the payment method
                } else if (amount == 0 && isSelected) {
                  onToggle(); // Disable the payment method
                }
                onAmountChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryRow(LocalProductProvider localProductProvider) {
    double totalPaid = _getTotalPaidAmount();

    return Column(
      children: [
        BuildPaymentRow(
          amount: "INR ${totalPaid.toStringAsFixed(2)}",
          title: "Total Paid",
          padding: const EdgeInsets.only(left: 5.0, right: 5.0),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.18,
            ColorManager.kPrimaryColor,
          ),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.18,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        const SizedBox(height: 8),
        BuildPaymentRow(
          amount: "INR ${_balanceAmount.toStringAsFixed(2)}",
          title: "Balance Amount",
          padding: const EdgeInsets.only(left: 5.0, right: 5.0),
          secondRowTextStyle: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s15,
            0.18,
            _balanceAmount > 0
                ? ColorManager.kButtonGreen
                : ColorManager.textColorRed,
          ),
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.bold,
            FontSize.s15,
            0.23,
            _balanceAmount > 0
                ? ColorManager.kButtonGreen
                : ColorManager.textColorRed,
          ),
          color: _balanceAmount > 0
              ? ColorManager.kButtonGreen
              : ColorManager.textColorRed,
        ),
      ],
    );
  }

  Widget _buildQuickAccessIcons() {
    return Consumer<LocalProductProvider>(
      builder: (context, localProductProvider, child) {
        double totalPaid = _getTotalPaidAmount();
        double cartTotal = localProductProvider.cartTotal;
        double balance = totalPaid - cartTotal;
        if (balance < 0) balance = 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 5),
                // Payment Method Icon
                _buildQuickAccessIcon(
                  icon: _getPaymentIcon(),
                  label: _getPaymentLabel(),
                  color: ColorManager.kPrimaryColor,
                  onTap: () => _showPaymentMethodModal(),
                ),
                const SizedBox(width: 12),
                // Delivery Method Icon
                _buildQuickAccessIcon(
                  icon: deliveryMethod == "Store Takeaway"
                      ? Icons.store
                      : deliveryMethod == "Car Delivery"
                          ? Icons.car_rental
                          : deliveryMethod == "Door Delivery"
                              ? Icons.doorbell_outlined
                              : Icons.local_shipping,
                  label: deliveryMethod.split(' ').first,
                  color: ColorManager.kButtonBlue,
                  onTap: () => _showDeliveryMethodModal(),
                ),
                const SizedBox(width: 12),
                // Coupon Icon
                _buildQuickAccessIcon(
                  icon: isCouponApplied
                      ? Icons.discount
                      : Icons.local_offer_outlined,
                  label: isCouponApplied ? 'Applied' : 'Coupon',
                  color: isCouponApplied
                      ? ColorManager.kButtonGreen
                      : ColorManager.kButtonYellow,
                  onTap: () => _showCouponModal(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Payment Summary in minimized view
            Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total Paid: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s13,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        'INR ${totalPaid.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.14,
                          ColorManager.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text(
                        'Balance: ',
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s13,
                          0.14,
                          ColorManager.textColor,
                        ),
                      ),
                      Text(
                        'INR ${balance.toStringAsFixed(2)}',
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s13,
                          0.14,
                          balance > 0
                              ? ColorManager.kButtonGreen
                              : ColorManager.textColorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getPaymentIcon() {
    List<String> activeMethods = [];
    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      activeMethods.add('Cash');
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      activeMethods.add('Card');
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      activeMethods.add('UPI');
    }

    if (activeMethods.length > 1) {
      return Icons.account_balance_wallet; // Multiple payment methods
    } else if (activeMethods.contains('Cash')) {
      return Icons.payments;
    } else if (activeMethods.contains('Card')) {
      return Icons.credit_card;
    } else if (activeMethods.contains('UPI')) {
      return Icons.phone_android;
    }
    return Icons.payment; // Default
  }

  String _getPaymentLabel() {
    List<String> activeMethods = [];
    if (_isCashSelected &&
        (double.tryParse(_cashAmountController.text) ?? 0) > 0) {
      activeMethods.add('Cash');
    }
    if (_isCardSelected &&
        (double.tryParse(_cardAmountController.text) ?? 0) > 0) {
      activeMethods.add('Card');
    }
    if (_isUpiSelected &&
        (double.tryParse(_upiAmountController.text) ?? 0) > 0) {
      activeMethods.add('UPI');
    }

    if (activeMethods.length > 1) {
      return 'Multi'; // Multiple payment methods
    } else if (activeMethods.length == 1) {
      return activeMethods.first;
    }
    return 'Payment'; // Default
  }

  Widget _buildQuickAccessIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: BuildBoxShadowContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        blurRadius: 4,
        circleRadius: 5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.14,
                color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodModal() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => PaymentMethodModal(
        initialIsCashSelected: _isCashSelected,
        initialIsCardSelected: _isCardSelected,
        initialIsUpiSelected: _isUpiSelected,
        initialCashAmount: _cashAmountController.text,
        initialCardAmount: _cardAmountController.text,
        initialUpiAmount: _upiAmountController.text,
        initialTransactionNumber: _transactionNumberController.text,
        cartTotal: localProductProvider.cartTotal,
        onPaymentMethodSelected: (isCash, isCard, isUpi, cashAmount, cardAmount,
            upiAmount, transactionNumber) {
          setState(() {
            _isCashSelected = isCash;
            _isCardSelected = isCard;
            _isUpiSelected = isUpi;
            _cashAmountController.text = cashAmount;
            _cardAmountController.text = cardAmount;
            _upiAmountController.text = upiAmount;
            _transactionNumberController.text = transactionNumber;
            _updateBalanceAmount();
          });
        },
      ),
    );
  }

  void _showDeliveryMethodModal() {
    showDialog(
      context: context,
      builder: (context) => DeliveryMethodModal(
        initialDeliveryMethod: deliveryMethod,
        initialDeliveryMethodId: deliveryMethodId,
        initialCarNumber: _carNumberController.text,
        initialComment: _commentController.text,
        onDeliveryMethodSelected: (method, methodId, carNumber, comment) {
          setState(() {
            deliveryMethod = method;
            deliveryMethodId = methodId;
            _carNumberController.text = carNumber;
            _commentController.text = comment;
          });
        },
      ),
    );
  }

  void _showCouponModal() {
    showDialog(
      context: context,
      builder: (context) => CouponModal(
        initialCouponCode: coupenCodeTextController.text,
        isCouponApplied: isCouponApplied,
        onCouponAction: (couponCode, shouldApply) async {
          if (shouldApply) {
            coupenCodeTextController.text = couponCode;
            await _applyCoupon();
          } else {
            setState(() {
              isCouponApplied = false;
              coupenCodeTextController.clear();

              // Fetch the cart data again after removing the coupon
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;
              int? customerId =
                  Provider.of<AuthModel>(context, listen: false).userId;

              Provider.of<CartProvider>(context, listen: false)
                  .fetchCartDataFromApi(
                customerId: customerId!,
                accessToken: accessToken ?? '',
              );
            });
          }
        },
      ),
    );
  }

  Future<void> _applyCoupon() async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    double? totalAmount =
        Provider.of<LocalProductProvider>(context, listen: false)
            .priceSummary!
            .netTotal;
    String couponCode = coupenCodeTextController.text;

    if (accessToken != null) {
      final result =
          await Provider.of<CartProvider>(context, listen: false).applyCoupon(
        totalAmount: totalAmount!,
        couponCode: couponCode,
        accessToken: accessToken,
      );

      if (result != null) {
        // Check if the response indicates success
        if (result['success'] == true) {
          final couponData = result['data']['data'];
          double discountAmount = double.parse(couponData['discount_amount']
              .replaceAll(',', '')); // Convert discount amount to double
          double discountedTotal = totalAmount - discountAmount;

          // Update the price summary with the new values
          Provider.of<CartProvider>(context, listen: false).updatePriceSummary(
            discountAmount: discountAmount,
            discountedTotal: discountedTotal,
          );

          setState(() {
            isCouponApplied = true;
          });

          showScaffold(
            context: context,
            message: result['message'] ?? 'Coupon Applied Successfully',
          );
        } else {
          // Handle failure to apply coupon
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'Failed to Apply Coupon',
          );
        }
      } else {
        // Handle case where result is null
        showScaffoldError(
          context: context,
          message: 'Error Occurred! Try Again',
        );
      }
    } else {
      // Handle unauthenticated state
      showScaffoldError(context: context, message: 'Not Authenticated');
    }
  }

  void resetAutocomplete({bool shouldFetchCustomers = true}) {
    debugPrint(
        "🔄 resetAutocomplete called - shouldFetchCustomers: $shouldFetchCustomers");
    setState(() {
      _autocompletePhoneKey = GlobalKey(); // Reset the key to force rebuild
      _autocompleteProductKey = GlobalKey(); // Reset the key to force rebuild
      isCustomerFound = false;
      _userChangedPaidAmount = false; // Reset paid amount flag

      // Only fetch customers if explicitly requested (not when loading saved orders)
      if (shouldFetchCustomers) {
        _fetchCustomers();
      }

      deliveryMethodId = "3";
      deliveryMethod = "Store Takeaway";
      iconColor = 1;
    });
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  void printFromSavedOrder(SavedOrder savedOrder) {
    try {
      // Extract cart items from the saved order
      List<Map<String, dynamic>> cartItems = [];
      double totalMRP = 0.0;
      double netTotal = 0.0;

      // Convert SavedOrder items to the format expected by PrintPage
      for (var item in savedOrder.items) {
        // Calculate individual item values
        double itemMrp = item.mrp ?? item.product.mrp ?? 0.0;
        double itemPrice = item.price ?? item.product.price?.price ?? 0.0;
        double itemTotalPrice = itemPrice * item.quantity;

        // Add to totals for "You Saved" calculation
        totalMRP += itemMrp * item.quantity;
        netTotal += itemTotalPrice;

        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': itemMrp.toString(),
          'quantity': item.quantity.toString(),
          'unitPrice': itemPrice.toString(),
          'totalPrice': itemTotalPrice.toString(),
        });
      }

      // 🔧 FIX: Calculate "You Saved" using Option 3 approach
      double youSaved = totalMRP - netTotal;
      youSaved = youSaved > 0 ? youSaved : 0.0; // Ensure non-negative

      // Debug - check what's being sent
      debugPrint("🖨️ BILLING SAVE AND PRINT CALCULATION:");
      debugPrint("  - Total MRP: $totalMRP");
      debugPrint("  - Net Total: $netTotal");
      debugPrint("  - You Saved: $youSaved");
      debugPrint("Sending ${cartItems.length} items to PrintPage");
      debugPrint(
          "Sample item: ${cartItems.isNotEmpty ? json.encode(cartItems[0]) : 'No items'}");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: "SOUQ POINT",
            cartItems: cartItems,
            formattedTotal: netTotal.toString(), // Use calculated net total
            savedTotal:
                youSaved.toString(), // 🔧 FIX: Use calculated "You Saved"
            orderDate: savedOrder.createdAt,
            orderNumber: savedOrder.orderNumber,
            isFromLocalStorage: true,
          ),
        ),
      );
    } catch (error) {
      debugPrint("Error printing saved order: ${error.toString()}");
      showScaffoldError(
        context: context,
        message: "Failed to print saved order. Please try again.",
      );
    }
  }

  // Function to scroll to the highlighted customer in the dropdown
  void _scrollToHighlightedCustomer() {
    if (_highlightedCustomerIndex == null) return;

    // Calculate the offset to scroll to
    final double scrollOffset =
        _highlightedCustomerIndex! * _customerItemHeight;

    // Get the current scroll position and visible height
    final double currentScroll = _customerScrollController.offset;
    const double visibleHeight =
        180.0; // Approximate visible height of dropdown

    // Adding buffer space to ensure the item is fully visible
    const double bufferSpace = 4.0;

    // Check if item is already visible
    if (scrollOffset < currentScroll + bufferSpace) {
      // Item is above visible area or partially visible at the top - scroll up to it
      _customerScrollController.animateTo(
        scrollOffset > 0 ? scrollOffset - bufferSpace : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (scrollOffset + _customerItemHeight >
        currentScroll + visibleHeight - bufferSpace) {
      // Item is below visible area or partially visible at bottom - scroll down to it
      _customerScrollController.animateTo(
        scrollOffset - visibleHeight + _customerItemHeight + bufferSpace,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
    // If item is already fully visible, do nothing
  }

  // Function to handle sales executive changes
  void _onSalesExecutiveChanged() {
    debugPrint(
        "🔄 BILLING: Sales executive changed, updating default customer...");

    // Don't reset if customer was manually selected (either from list or phone entry)
    if (_isCustomerManuallySelected &&
        (selectedCustomerID != null || mobileNumberText?.isNotEmpty == true)) {
      debugPrint("🛡️ Customer manually selected, skipping reset");
      debugPrint("  - selectedCustomerID: $selectedCustomerID");
      debugPrint("  - mobileNumberText: '$mobileNumberText'");
      return;
    }

    // Clear current customer selection
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    // Reset billing page customer state
    setState(() {
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey(); // Reset autocomplete
      _isCustomerManuallySelected = false;
    });

    // Re-fetch customers to set new default based on new executive
    _fetchCustomers();
  }

  // Public method to reset to default sales executive (for external calls)
  void resetToDefaultSalesExecutive() {
    debugPrint(
        "🔄 BILLING: Public method called - resetting to default sales executive...");

    // Clear the current order being edited
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    localProductProvider.clearCurrentOrder();

    // Reset all form fields
    setState(() {
      // Clear payment and delivery states
      iconColor = 1; // Default to cash
      deliveryMethod = "Store Takeaway";
      deliveryMethodId = "3";

      // Clear all controllers
      coupenCodeTextController.clear();
      _transactionNumberController.clear();
      _paidAmountController.clear();
      _carNumberController.clear();
      _commentController.clear();

      // Reset other flags
      isCouponApplied = false;
      _balanceAmount = 0;
      _userChangedPaidAmount = false;

      // Clear product entry fields
      quantityController.clear();
      barcodeController.clear();
      selectedProductIdController.clear();
      unitPriceController.clear();
      selectedProductNameController.clear();

      // Reset autocomplete keys
      _autocompletePhoneKey = GlobalKey();
      _autocompleteProductKey = GlobalKey();
    });

    _onSalesExecutiveChanged();
    resetAutocomplete();
  }

  // Public method to save current order (for external calls)
  void saveCurrentOrder() {
    debugPrint("===== PUBLIC SAVE CURRENT ORDER START =====");
    debugPrint("💾 BILLING: Public method called - saving current order...");
    debugPrint("📝 Current customer state:");
    debugPrint(
        "  - salesExecutivemobileNumberText: '$salesExecutivemobileNumberText'");
    debugPrint("  - mobileNumberText: '$mobileNumberText'");
    debugPrint(
        "  - mobileNumberTextController.text: '${mobileNumberTextController.text}'");
    debugPrint("  - selectedCustomerID: $selectedCustomerID");
    debugPrint("  - selectedCustomerPhone: '$selectedCustomerPhone'");
    debugPrint("  - selectedCustomer?.name: '${selectedCustomer?.name}'");
    debugPrint("  - isCustomerFound: $isCustomerFound");
    debugPrint(
        "  - Payment Method: ${iconColor == 1 ? 'CASH' : iconColor == 2 ? 'CARD' : iconColor == 3 ? 'UPI' : 'None'}");
    debugPrint("  - Delivery Method: $deliveryMethod (ID: $deliveryMethodId)");
    debugPrint("  - Comment: '${_commentController.text}'");
    debugPrint(
        "  - Cart Items: ${Provider.of<LocalProductProvider>(context, listen: false).cartItems.length}");
    _saveOrder();
    debugPrint("===== PUBLIC SAVE CURRENT ORDER END =====");
  }

  void _onUserSwitched() {
    debugPrint("🔄 BILLING: User switched, updating default customer...");

    // Clear current customer selection
    Provider.of<CustomerSelectionProvider>(context, listen: false)
        .clearSelectedCustomer();

    // Reset billing page customer state
    setState(() {
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
      mobileNumberTextController.clear();
      _autocompletePhoneKey = GlobalKey(); // Reset autocomplete
    });

    // Re-fetch customers to set new default based on new executive
    _fetchCustomers();
  }
}

// Multi-Payment Method Modal
class PaymentMethodModal extends StatefulWidget {
  final bool initialIsCashSelected;
  final bool initialIsCardSelected;
  final bool initialIsUpiSelected;
  final String initialCashAmount;
  final String initialCardAmount;
  final String initialUpiAmount;
  final String initialTransactionNumber;
  final double cartTotal;
  final Function(bool, bool, bool, String, String, String, String)
      onPaymentMethodSelected;

  const PaymentMethodModal({
    Key? key,
    required this.initialIsCashSelected,
    required this.initialIsCardSelected,
    required this.initialIsUpiSelected,
    required this.initialCashAmount,
    required this.initialCardAmount,
    required this.initialUpiAmount,
    required this.initialTransactionNumber,
    required this.cartTotal,
    required this.onPaymentMethodSelected,
  }) : super(key: key);

  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal> {
  late bool isCashSelected;
  late bool isCardSelected;
  late bool isUpiSelected;
  late TextEditingController cashAmountController;
  late TextEditingController cardAmountController;
  late TextEditingController upiAmountController;
  late TextEditingController transactionNumberController;
  late FocusNode cashAmountFocusNode;
  late FocusNode cardAmountFocusNode;
  late FocusNode upiAmountFocusNode;
  double balanceAmount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize selection states
    isCashSelected = widget.initialIsCashSelected;
    isCardSelected = widget.initialIsCardSelected;
    isUpiSelected = widget.initialIsUpiSelected;

    // Initialize controllers
    cashAmountController =
        TextEditingController(text: widget.initialCashAmount);
    cardAmountController =
        TextEditingController(text: widget.initialCardAmount);
    upiAmountController = TextEditingController(text: widget.initialUpiAmount);
    transactionNumberController =
        TextEditingController(text: widget.initialTransactionNumber);

    // Initialize focus nodes
    cashAmountFocusNode = FocusNode();
    cardAmountFocusNode = FocusNode();
    upiAmountFocusNode = FocusNode();

    // Calculate initial balance
    _calculateBalance();

    // Add focus listeners
    cashAmountFocusNode.addListener(() {
      if (cashAmountFocusNode.hasFocus &&
          cashAmountController.text.isNotEmpty) {
        cashAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: cashAmountController.text.length,
        );
      }
    });

    cardAmountFocusNode.addListener(() {
      if (cardAmountFocusNode.hasFocus &&
          cardAmountController.text.isNotEmpty) {
        cardAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: cardAmountController.text.length,
        );
      }
    });

    upiAmountFocusNode.addListener(() {
      if (upiAmountFocusNode.hasFocus && upiAmountController.text.isNotEmpty) {
        upiAmountController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: upiAmountController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    cashAmountController.dispose();
    cardAmountController.dispose();
    upiAmountController.dispose();
    transactionNumberController.dispose();
    cashAmountFocusNode.dispose();
    cardAmountFocusNode.dispose();
    upiAmountFocusNode.dispose();
    super.dispose();
  }

  void _calculateBalance() {
    double totalPaid = _getTotalPaidAmount();
    double balance = totalPaid - widget.cartTotal;
    if (balance < 0) {
      balance = 0.0;
    }
    setState(() {
      balanceAmount = balance;
    });
  }

  double _getTotalPaidAmount() {
    double cashAmount = double.tryParse(cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(upiAmountController.text) ?? 0.0;
    return cashAmount + cardAmount + upiAmount;
  }

  void _autoFillPaymentAmount() {
    double totalPaid = _getTotalPaidAmount();
    double remaining = widget.cartTotal - totalPaid;

    if (remaining > 0) {
      // Find the first selected payment method that has no amount and fill it
      if (isCashSelected && cashAmountController.text.isEmpty) {
        cashAmountController.text = remaining.toStringAsFixed(2);
      } else if (isCardSelected && cardAmountController.text.isEmpty) {
        cardAmountController.text = remaining.toStringAsFixed(2);
      } else if (isUpiSelected && upiAmountController.text.isEmpty) {
        upiAmountController.text = remaining.toStringAsFixed(2);
      }
    }
    _calculateBalance();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        width: 550,
        circleRadius: 12,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Methods',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cash Payment
            _buildModalPaymentRow(
              isSelected: isCashSelected,
              icon: ImageAssets.cashIcon,
              label: 'Cash',
              controller: cashAmountController,
              focusNode: cashAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  isCashSelected = !isCashSelected;
                  if (!isCashSelected) {
                    cashAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
            ),

            const SizedBox(height: 15),

            // Card Payment
            _buildModalPaymentRow(
              isSelected: isCardSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'Card',
              controller: cardAmountController,
              focusNode: cardAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  isCardSelected = !isCardSelected;
                  if (!isCardSelected) {
                    cardAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
            ),

            const SizedBox(height: 15),

            // UPI Payment
            _buildModalPaymentRow(
              isSelected: isUpiSelected,
              icon: ImageAssets.creditCardIcon,
              label: 'UPI',
              controller: upiAmountController,
              focusNode: upiAmountFocusNode,
              size: size,
              onToggle: () {
                setState(() {
                  isUpiSelected = !isUpiSelected;
                  if (!isUpiSelected) {
                    upiAmountController.clear();
                  } else {
                    _autoFillPaymentAmount();
                  }
                  _calculateBalance();
                });
              },
            ),

            const SizedBox(height: 15),

            // Transaction Reference Field - Show only if Card or UPI is selected
            if (isCardSelected || isUpiSelected) ...[
              Text(
                'Transaction Reference',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s13,
                  0.16,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 8),
              buildColumnWidgetForTextFields(
                controller: transactionNumberController,
                size: size,
                width: 600,
                height: size.height * .06,
                hintText: 'Enter transaction reference number',
              ),
              const SizedBox(height: 15),
            ],

            // Payment Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Required: INR ${widget.cartTotal.toStringAsFixed(2)}',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
                Text(
                  'Total Paid: INR ${_getTotalPaidAmount().toStringAsFixed(2)}',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.18,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            BuildPaymentRow(
              amount: "INR ${balanceAmount.toStringAsFixed(2)}",
              title: "Balance Amount",
              secondRowTextStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s15,
                0.18,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              firstRowTextStyle: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s15,
                0.23,
                balanceAmount > 0
                    ? ColorManager.kButtonGreen
                    : ColorManager.textColorRed,
              ),
              color: balanceAmount > 0
                  ? ColorManager.kButtonGreen
                  : ColorManager.textColorRed,
            ),

            const SizedBox(height: 20),
            CustomRoundButton(
              title: "Apply Payment Methods",
              fct: () {
                widget.onPaymentMethodSelected(
                  isCashSelected,
                  isCardSelected,
                  isUpiSelected,
                  cashAmountController.text,
                  cardAmountController.text,
                  upiAmountController.text,
                  transactionNumberController.text,
                );
                Navigator.of(context).pop();
              },
              fontSize: FontSize.s14,
              height: 45,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalPaymentRow({
    required bool isSelected,
    required String icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Size size,
    required VoidCallback onToggle,
  }) {
    return Row(
      children: [
        // Payment method icon (visual indicator only)
        BuildBoxShadowContainer(
          border: isSelected
              ? Border.all(color: ColorManager.kPrimaryColor, width: 2)
              : Border.all(color: Colors.grey.shade300),
          padding: const EdgeInsets.all(12),
          blurRadius: 4,
          circleRadius: 5,
          width: 90,
          child: Column(
            children: [
              WebsafeSvg.asset(
                icon,
                width: 18,
                height: 18,
                color: isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                fit: BoxFit.none,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s11,
                  0.12,
                  isSelected ? ColorManager.kPrimaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 15),

        // Amount input field - always visible
        Expanded(
          child: buildColumnWidgetForTextFields(
            controller: controller,
            size: size,
            height: size.height * .06,
            hintText: 'Enter $label amount',
            keyboardType: TextInputType.number,
            focusNode: focusNode,
            onchanged: (value) {
              // Auto-enable/disable based on amount
              double amount = double.tryParse(value ?? '') ?? 0;
              if (amount > 0 && !isSelected) {
                onToggle(); // Enable the payment method
              } else if (amount == 0 && isSelected) {
                onToggle(); // Disable the payment method
              }
              _calculateBalance();
            },
          ),
        ),
      ],
    );
  }
}

// Delivery Method Modal
class DeliveryMethodModal extends StatefulWidget {
  final String initialDeliveryMethod;
  final String initialDeliveryMethodId;
  final String initialCarNumber;
  final String initialComment;
  final Function(String, String, String, String) onDeliveryMethodSelected;

  const DeliveryMethodModal({
    Key? key,
    required this.initialDeliveryMethod,
    required this.initialDeliveryMethodId,
    required this.initialCarNumber,
    required this.initialComment,
    required this.onDeliveryMethodSelected,
  }) : super(key: key);

  @override
  State<DeliveryMethodModal> createState() => _DeliveryMethodModalState();
}

class _DeliveryMethodModalState extends State<DeliveryMethodModal> {
  late String deliveryMethod;
  late String deliveryMethodId;
  late TextEditingController carNumberController;
  late TextEditingController commentController;

  @override
  void initState() {
    super.initState();
    deliveryMethod = widget.initialDeliveryMethod;
    deliveryMethodId = widget.initialDeliveryMethodId;
    carNumberController = TextEditingController(text: widget.initialCarNumber);
    commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    carNumberController.dispose();
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Consumer<DeliveryMethodsProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Method',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s16,
                        0.21,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: provider.deliveryMethods.map((method) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          deliveryMethod = method.name;
                          deliveryMethodId = method.id;
                        });
                      },
                      child: BuildBoxShadowContainer(
                        border: deliveryMethod == method.name
                            ? Border.all(color: ColorManager.kPrimaryColor)
                            : null,
                        padding: const EdgeInsets.all(12),
                        blurRadius: 4,
                        circleRadius: 5,
                        child: Column(
                          children: [
                            Icon(
                              method.name == "Store Takeaway"
                                  ? Icons.store
                                  : method.name == "Car Delivery"
                                      ? Icons.car_rental
                                      : method.name == "Door Delivery"
                                          ? Icons.doorbell_outlined
                                          : Icons.local_shipping,
                              size: 20,
                              color: Colors.black,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              method.name,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.12,
                                Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (deliveryMethod == "Car Delivery") ...[
                  buildColumnWidgetForTextFields(
                    controller: carNumberController,
                    size: size,
                    height: size.height * .06,
                    hintText: 'Car Number:',
                    width: 600,
                  ),
                  const SizedBox(height: 10),
                ],
                buildColumnWidgetForTextFields(
                  controller: commentController,
                  size: size,
                  height: size.height * .06,
                  hintText: 'Comment:',
                  width: 600,
                ),
                const SizedBox(height: 20),
                CustomRoundButton(
                  title: "Apply",
                  fct: () {
                    widget.onDeliveryMethodSelected(
                      deliveryMethod,
                      deliveryMethodId,
                      carNumberController.text,
                      commentController.text,
                    );
                    Navigator.of(context).pop();
                  },
                  fontSize: FontSize.s14,
                  height: 45,
                  width: double.infinity,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Coupon Modal
class CouponModal extends StatefulWidget {
  final String initialCouponCode;
  final bool isCouponApplied;
  final Function(String, bool) onCouponAction;

  const CouponModal({
    Key? key,
    required this.initialCouponCode,
    required this.isCouponApplied,
    required this.onCouponAction,
  }) : super(key: key);

  @override
  State<CouponModal> createState() => _CouponModalState();
}

class _CouponModalState extends State<CouponModal> {
  late TextEditingController couponController;
  late bool isCouponApplied;

  @override
  void initState() {
    super.initState();
    couponController = TextEditingController(text: widget.initialCouponCode);
    isCouponApplied = widget.isCouponApplied;
  }

  @override
  void dispose() {
    couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BuildBoxShadowContainer(
        circleRadius: 12,
        color: Colors.white,
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Apply Coupon',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 15),
              height: 50,
              child: TextField(
                controller: couponController,
                enabled: !isCouponApplied,
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
                  hintStyle: buildCustomStyle(
                    FontWeight.w500,
                    12,
                    0.27,
                    Colors.grey.withOpacity(.5),
                  ),
                  border: InputBorder.none,
                ),
                style: buildCustomStyle(
                  FontWeight.w500,
                  12,
                  0.27,
                  Colors.black.withOpacity(.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isCouponApplied) ...[
                  Expanded(
                    child: CustomRoundButton(
                      title: "Remove",
                      fct: () {
                        widget.onCouponAction('', false);
                        Navigator.of(context).pop();
                      },
                      fontSize: FontSize.s14,
                      height: 45,
                      width: double.infinity,
                      boxColor: ColorManager.kButtonRed,
                      borderColor: ColorManager.kButtonRed,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: CustomRoundButton(
                      title: "Apply",
                      fct: () {
                        widget.onCouponAction(couponController.text, true);
                        Navigator.of(context).pop();
                      },
                      fontSize: FontSize.s14,
                      height: 45,
                      width: double.infinity,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Price Selection Modal Widget
class PriceSelectionModal extends StatelessWidget {
  final Function(double) onPriceSelected;
  final String productName;

  const PriceSelectionModal({
    Key? key,
    required this.onPriceSelected,
    required this.productName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Select Price for',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.18,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.16,
                ColorManager.kPrimaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 20,
                itemBuilder: (context, index) {
                  final price = (index + 1).toDouble();
                  return GestureDetector(
                    onTap: () {
                      onPriceSelected(price);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: ColorManager.kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '₹${price.toStringAsFixed(0)}',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.16,
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: ColorManager.kButtonRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.16,
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
