import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/compact_quantity_control_local.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

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
  bool isLoadingAddItem = false;

  bool _isDialogOpen = false;
  Timer? _debounce;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');
    _focusNode.addListener(_handleFocusChange);
    deliveryMethodId = "3";
    deliveryMethod = "Store Takeaway";
    iconColor = 1;
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

    _debounce?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
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
            salesCustomer = customerList![0];
            salesExecutivemobileNumberText = salesCustomer.phone!;
            mobileNumberText = salesCustomer.phone!;
            mobileNumberTextController.text =
                "${salesCustomer.name!} ${salesCustomer.phone!}";
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

  void _refetchCartData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    // Fetch cart data
    Provider.of<CartProvider>(context, listen: false)
        .fetchCartDataFromApi(
      customerId: customerId!,
      accessToken: accessToken ?? '',
    )
        .then((_) {
      // Optionally, you can add a message or handle UI changes after fetching
      setState(() {
        // Update the UI if necessary
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);

    return SafeArea(
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: Scaffold(
          body: Center(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main content area
                Expanded(
                  flex: 5,
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
                            const HorizontalProductViewLocal(),
                            const SizedBox(height: 10),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          color: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0, vertical: 10),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              _buildMobileNumberInput(
                                                  size: size,
                                                  mobileNumberTextController:
                                                      mobileNumberTextController),
                                              const SizedBox(height: 10),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildPaymentMethodSelection(),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _buildDeliveryMethodSelection(),
                                      ),
                                      Expanded(
                                          flex: 3,
                                          child: Container(
                                            color: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16.0, vertical: 10),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                _buildCouponInput(),
                                                const SizedBox(height: 10),
                                                _buildPaymentSummary(),
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

                // Saved orders on the right side
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: VerticalSavedOrdersView(
                      onOrderSelected: (orderId) {
                        // Get the local provider
                        final localProductProvider =
                            Provider.of<LocalProductProvider>(context,
                                listen: false);

                        // If we're editing an order and there are items in the cart, update that order
                        if (localProductProvider.currentOrder != null &&
                            localProductProvider.cartItems.isNotEmpty) {
                          try {
                            // Update the current order being edited
                            localProductProvider.updateSavedOrder(
                              localProductProvider.currentOrder!.id,
                              customerName: selectedCustomer?.name,
                              customerPhone:
                                  selectedCustomerPhone ?? mobileNumberText,
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
                        }

                        // Now load the selected order
                        _loadSavedOrderForEditing(orderId);
                      },
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

  Widget _buildHeader() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final bool isEditingOrder = localProductProvider.currentOrder != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEditingOrder ? 'Edit Order' : 'New Order',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            Text(
              isEditingOrder
                  ? 'Order No #${localProductProvider.currentOrder!.orderNumber}'
                  : 'Order No #00000',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.18, ColorManager.textColor),
            ),
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
                                          // Handle the case where products are found
                                          // For example, you can update the UI or add to cart
                                          // Example: add the first product to the cart
                                          GetProduct product =
                                              filteredProducts.first;

                                          if (product.unit == 'KGS' &&
                                              prefix == '000' &&
                                              query.length == 14) {
                                            // Weight-based product
                                            String weightKg = lastFive!
                                                .substring(0,
                                                    2); // First 2 digits = KG
                                            String weightGrams =
                                                lastFive.substring(2,
                                                    5); // Last 3 digits = Grams
                                            double totalWeight =
                                                double.parse(weightKg) +
                                                    (double.parse(weightGrams) /
                                                        1000);

                                            localProductProvider.addToCart(
                                              product: product,
                                              quantity: totalWeight,
                                            );

                                            showScaffold(
                                              context: context,
                                              message: 'Added To Cart',
                                            );
                                          } else if (product.unit == 'PCS' &&
                                              prefix == '000' &&
                                              query.length == 14) {
                                            // Count-based product
                                            int quantity = int.parse(
                                                lastFive!); // Last 5 digits represent quantity

                                            localProductProvider.addToCart(
                                              product: product,
                                              quantity: quantity,
                                            );

                                            showScaffold(
                                              context: context,
                                              message: 'Added To Cart',
                                            );
                                          } else {
                                            localProductProvider.addToCart(
                                                product: product);

                                            showScaffold(
                                              context: context,
                                              message: 'Added To Cart',
                                            );
                                          }

                                          // Clear input fields if necessary
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
                                          _isDialogOpen =
                                              true; // Set dialog state to open
                                          final result = await showDialog(
                                            context: context,
                                            builder: (context) =>
                                                AddProductWithBarcodeModal(
                                                    barcode: query),
                                          );
                                          _isDialogOpen =
                                              false; // Reset dialog state
                                          debugPrint("result $result");
                                          if (result != null) {
                                            localProductProvider.addToCart(
                                                productId: result["id"],
                                                price: double.tryParse(
                                                    result["price"]
                                                        .toString()));
                                            barcodeController.clear();
                                          } else {
                                            barcodeController.clear();
                                            _focusTextField();
                                          }
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
                                onSelected: (GetProduct selectedProduct) {
                                  setState(() {
                                    selectedProductIdController.text =
                                        selectedProduct.productId.toString();
                                    unitPriceController.text =
                                        selectedProduct.price?.price ?? '';
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
                              fct: () {
                                setState(() {
                                  isLoadingAddItem = true; // Start loading
                                });
                                try {
                                  // Get the selected product from LocalProductProvider
                                  final localProductProvider =
                                      Provider.of<LocalProductProvider>(context,
                                          listen: false);

                                  final selectedProduct =
                                      localProductProvider.selectedProduct;

                                  if (selectedProduct != null) {
                                    // Add the selected product to the local cart
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
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                    ),
                    headingRowColor: WidgetStateColor.resolveWith((states) =>
                        ColorManager.kPrimaryColor.withOpacity(0.1)),
                    dataRowColor: WidgetStateColor.resolveWith((states) =>
                        states.contains(WidgetState.selected)
                            ? Colors.grey.shade100
                            : Colors.white),
                    dividerThickness: 0,
                    columns: [
                      DataColumn(
                        label: Expanded(
                          child: Text('Item Name',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Text('Unit',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Text('Quantity',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Text('Unit Price',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Text('Total Price',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Text('Actions',
                              textAlign: TextAlign.center,
                              style: buildCustomStyle(FontWeightManager.bold,
                                  14, 0.21, ColorManager.textColor)),
                        ),
                      ),
                    ],
                    rows: cartItems.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Align(
                            alignment: Alignment.center,
                            child: Text(
                              item.product.productName ?? 'Unknown',
                              style: buildCustomStyle(FontWeightManager.regular,
                                  12, 0.21, ColorManager.textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          )),
                          DataCell(Align(
                            alignment: Alignment.center,
                            child: Text(
                              item.product.unit ?? '-',
                              style: buildCustomStyle(FontWeightManager.regular,
                                  12, 0.21, ColorManager.textColor),
                              textAlign: TextAlign.center,
                            ),
                          )),
                          DataCell(Center(
                            child: CompactQuantityControlLocal(
                              productId: item.product.productId!,
                              quantity: item.quantity.toDouble(),
                              unitPrice: item.price.toString(),
                              productUnit: item.product.unit,
                              product: item.product,
                            ),
                          )),
                          DataCell(Center(
                            child: SizedBox(
                              width: 80,
                              child: Builder(builder: (context) {
                                // Create a controller that we can actually reference
                                final TextEditingController controller =
                                    TextEditingController(
                                        text: item.price.toString());
                                final FocusNode focusNode = FocusNode();

                                // Add listener to focus node to select all text when focused
                                focusNode.addListener(() {
                                  if (focusNode.hasFocus) {
                                    controller.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: controller.text.length,
                                    );
                                  } else {
                                    // When focus is lost, update the price
                                    localProductProvider.updateItemPrice(
                                      item.product.productId!,
                                      double.tryParse(controller.text) ??
                                          item.price!,
                                    );
                                  }
                                });

                                return TextField(
                                  textAlign: TextAlign.center,
                                  controller: controller,
                                  focusNode: focusNode,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Unit Price',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onSubmitted: (newPrice) {
                                    // Update when user presses enter
                                    localProductProvider.updateItemPrice(
                                      item.product.productId!,
                                      double.tryParse(newPrice) ?? item.price!,
                                    );
                                  },
                                );
                              }),
                            ),
                          )),
                          DataCell(
                            Center(
                              child: SizedBox(
                                width: 80,
                                child: Text(
                                  (item.price! * item.quantity)
                                      .toStringAsFixed(2),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Center(
                            child: IconButton(
                              icon: WebsafeSvg.asset(
                                ImageAssets.oderlistCloseIcon,
                                width: 15,
                              ),
                              onPressed: () {
                                localProductProvider
                                    .removeFromCart(item.product.productId!);
                              },
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentSummary() {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);

    localProductProvider.cartTotal; // Call this to ensure priceSummary is set
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
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.subTotal ?? 0.00)}",
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
              "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.discount ?? 0.00)}",
          title: "Discount",
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount:
                "INR ${AmountHelper.formatAmount(localProductProvider.priceSummary!.totalTax ?? 0.00)}",
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
    return Column(
      children: [
        BuildPaymentRow(
          amount: "",
          title: "Payment Method",
          firstRowTextStyle: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.21,
            ColorManager.kPrimaryColor,
          ),
          color: ColorManager.kPrimaryColor,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  iconColor = 1;
                });
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 1
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(8),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.cashIcon,
                      width: 15,
                      height: 15,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Cash',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  iconColor = 2;
                });
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 2
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(left: 10, top: 10),
                padding: const EdgeInsets.only(
                    left: 12, top: 8, bottom: 8, right: 12),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.creditCardIcon,
                      width: 15,
                      height: 15,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Card',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  iconColor = 3;
                });
              },
              child: BuildBoxShadowContainer(
                border: iconColor == 3
                    ? Border.all(color: ColorManager.kPrimaryColor)
                    : null,
                margin: const EdgeInsets.only(left: 10, top: 10),
                padding: const EdgeInsets.only(
                    left: 12, top: 8, bottom: 8, right: 12),
                blurRadius: 4,
                circleRadius: 5,
                child: Column(
                  children: [
                    WebsafeSvg.asset(
                      ImageAssets.creditCardIcon,
                      width: 15,
                      height: 15,
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Upi',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s10, 0.12, Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            if (iconColor == 2 || iconColor == 3 || iconColor == 1)
              Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: iconColor != 1
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: buildColumnWidgetForTextFields(
                              controller: _transactionNumberController,
                              size: size,
                              height: size.height * .06,
                              hintText: 'Transaction Reference No:',
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: buildColumnWidgetForTextFields(
                              controller: _paidAmountController,
                              size: size,
                              onchanged: (value) {
                                _getBalanceAmount();
                              },
                              height: size.height * .06,
                              hintText: 'Enter Paid Amount Here:',
                            ),
                          )),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (iconColor == 1)
          BuildPaymentRow(
            amount: "INR ${_balanceAmount.toStringAsFixed(2)}",
            title: "Balance amount",
            secondRowTextStyle: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s15,
              0.18,
              ColorManager.textColorRed,
            ),
            firstRowTextStyle: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s15,
              0.23,
              ColorManager.textColorRed,
            ),
            color: ColorManager.textColorRed,
          ),
        if (iconColor == 1) const SizedBox(height: 10),
      ],
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
          _buildActionButton(
            text: 'Create Order and Print',
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
    return Row(
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  padding: const EdgeInsets.only(left: 15),
                  height: size.height * .07,
                  width: size.width / 3,
                  child: Autocomplete<CustomerListModelData>(
                    key: _autocompletePhoneKey, // Set the key here
                    optionsBuilder: (mobileNumberTextController) async {
                      // debugPrint(mobileNumberTextController.text);
                      if (mobileNumberTextController.text.isEmpty) {
                        setState(() {
                          isCustomerFound = false; // Reset validity
                        });
                        return const Iterable<CustomerListModelData>.empty();
                      }

                      String? accessToken =
                          Provider.of<AuthModel>(context, listen: false).token;
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
                          List<CustomerListModelData>? filteredCustomerList =
                              customerListModel.data;

                          if (mobileNumberTextController.text.length == 10 &&
                              filteredCustomerList!.length == 1) {
                            setState(() {
                              isCustomerFound = true;
                            });
                          } else {
                            setState(() {
                              isCustomerFound = false;
                            });
                          }

                          return filteredCustomerList!.isNotEmpty
                              ? filteredCustomerList
                              : const Iterable<CustomerListModelData>.empty();
                        } else {
                          // debugPrint('Error in response: ${response["message"]}');
                        }
                      } catch (error) {
                        // debugPrint('Exception caught: $error');
                      }
                      setState(() {
                        isCustomerFound = false;
                      });
                      return const Iterable<
                          CustomerListModelData>.empty(); // Return empty if no customers found
                    },
                    displayStringForOption: (CustomerListModelData customer) =>
                        "${customer.name} ${customer.phone}",
                    onSelected: (CustomerListModelData selection) {
                      String? accessToken =
                          Provider.of<AuthModel>(context, listen: false).token;
                      // debugPrint("accessToken From AuthModel $accessToken");
                      Provider.of<CartProvider>(context, listen: false)
                          .fetchCartDataFromApi(
                              customerId: selection.id ?? 0,
                              accessToken: accessToken ?? '');
                      setState(() {
                        mobileNumberText = "";
                        selectedCustomerID = selection.id!;
                        selectedCustomerPhone = selection.phone;
                        selectedCustomer = selection;
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController mobileNumberTextController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextField(
                        controller: mobileNumberTextController,
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
                              maxWidth: 30), // Constrains the suffix icon size
                          suffixIcon:
                              (isCustomerFound || selectedCustomerID != null)
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
                          setState(() {
                            mobileNumberText = value;
                            selectedCustomerID = null;
                            selectedCustomerPhone = null;
                            selectedCustomer = null;
                          });
                        },
                        style: buildCustomStyle(
                          FontWeight.w500,
                          12,
                          0.27,
                          Colors.black.withOpacity(.5),
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
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final CustomerListModelData option =
                                    options.elementAt(index);
                                return MouseRegion(
                                  onEnter: (_) {
                                    setState(() {
                                      hoverMap[index] = true;
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
                                      color: hoverMap[index] == true
                                          ? Colors.grey[200]
                                          : Colors.white,
                                      child: ListTile(
                                        title: Text(
                                          "${option.name} ${option.phone}",
                                          style: buildCustomStyle(
                                            FontWeight.w500,
                                            12,
                                            0.27,
                                            Colors.black.withOpacity(.5),
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
              setState(() {
                _autocompletePhoneKey = GlobalKey();
                mobileNumberTextController.clear();
                mobileNumberText = "";
                selectedCustomerID = null;
                selectedCustomerPhone = null;
                selectedCustomer = null;
                isCustomerFound = false;
                salesExecutivemobileNumberText = "";
              }),
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
        iconColor = 0;
        coupenCodeTextController.clear();
        _transactionNumberController.clear();
        _paidAmountController.clear();
        _balanceAmount = 0;
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

      // Check if we're editing an existing order
      SavedOrder? currentOrder = localProductProvider.currentOrder;

      if (currentOrder != null) {
        // Update existing order
        localProductProvider.updateSavedOrder(
          currentOrder.id,
          customerName: selectedCustomer?.name,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
        );

        showScaffold(
          context: context,
          message: "Order Updated Successfully",
        );
      } else {
        // Save as new order
        // Get customer name if available
        String? customerName;
        if (selectedCustomer != null) {
          customerName = selectedCustomer!.name;
        }

        localProductProvider.saveCurrentCartAsOrder(
          customerName: customerName,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          comment: _commentController.text,
          deliveryMethod: deliveryMethod,
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
        iconColor = 0;
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
        _carNumberController.clear();
        _commentController.clear();
      });

      resetAutocomplete();
      _focusTextField();
    } catch (error) {
      debugPrint(error.toString());
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
    } finally {
      setState(() {
        isLoadingSaveOrder = false; // Indicate that loading has finished
      });
    }
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
    debugPrint("Create Order and Print pressed");
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
        // debugPrint("$cartId");

        String paymentMethod = "";

        if (iconColor == 1) {
          paymentMethod = "CASH";
        } else if (iconColor == 2) {
          paymentMethod = "CARD";
        } else if (iconColor == 3) {
          paymentMethod = "UPI";
        }

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

        List<Map<String, dynamic>> items = [];

        for (var item in cartItems) {
          items.add({
            'product_id': item.product.productId,
            'quantity': item.quantity,
            'price': item.price,
          });
        }

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
          paymentMethod: paymentMethod,
          paidAmount: _paidAmountController.text,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          comment: _commentController.text,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
        )
            .then((response) async {
          debugPrint("response ${response["order_id"]}");
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

              final OrderDetailsresponse = await SalesProvider()
                  .listOrderDetails(context, ordersId, accessToken ?? "");

              OrderDetailsModel orderDetails =
                  OrderDetailsModel.fromJson(OrderDetailsresponse);

              String? formattedTotal =
                  orderDetails.data?.cart?.priceSummary?.netTotal.toString();
              String? savedTotal =
                  orderDetails.data?.cart?.priceSummary?.savedTotal.toString();

              String storeName = orderDetails.data!.cart!.storeName ?? "";
              String orderDate = orderDetails.data!.orderDate ?? "";

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
              debugPrint(error.toString());
            }

            // Clear the mobile number after successful save
            setState(() {
              mobileNumberText = ""; // Clear the variable
              selectedCustomerID = null;
              selectedCustomerPhone = null;
              iconColor = 0;
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
              _carNumberController.clear();
              _commentController.clear();
            });
            resetAutocomplete();
          } else {
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
      debugPrint(error.toString());
    } finally {
      // Set loading to false at the end of the function
      setState(() {
        isLoadingCreateOrder = false; // Indicate that loading has finished
      });
    }
  }

  void _confirmOrder() async {
    debugPrint("Create Order pressed");
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
        // debugPrint("$cartId");

        String paymentMethod = "";

        if (iconColor == 1) {
          paymentMethod = "CASH";
        } else if (iconColor == 2) {
          paymentMethod = "CARD";
        } else if (iconColor == 3) {
          paymentMethod = "UPI";
        }

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

        List<Map<String, dynamic>> items = [];

        for (var item in cartItems) {
          items.add({
            'product_id': item.product.productId,
            'quantity': item.quantity,
            'price': item.price,
          });
        }

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
          paymentMethod: paymentMethod,
          paidAmount: _paidAmountController.text,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
          comment: _commentController.text,
          deliveryMethodId: deliveryMethodId,
          carNumber: _carNumberController.text,
          status: "confirmed",
        )
            .then((response) {
          debugPrint("response ${response["order_id"]}");
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
              iconColor = 0;
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
              _carNumberController.clear();
              _commentController.clear();
            });
            resetAutocomplete();
          } else {
            showScaffoldError(
              context: context,
              message: "Failed to Confirm Order",
            );
          }
        });
        _focusTextField();
      }
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      // Set loading to false at the end of the function
      setState(() {
        isLoadingConfirmOrder = false; // Indicate that loading has finished
      });
    }
  }

  void _getBalanceAmount() {
    // debugPrint(_paidAmountController.text);
    num netTotal = Provider.of<LocalProductProvider>(context, listen: false)
            .priceSummary!
            .netTotal ??
        0.00;
    double paidAmount = double.tryParse(_paidAmountController.text) ?? 0.00;
    double balanceAmount = paidAmount - netTotal;
    if (balanceAmount < 0) {
      balanceAmount = 0.00;
    }
    setState(() {
      _balanceAmount = balanceAmount;
    });
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

  void resetAutocomplete() {
    setState(() {
      _autocompletePhoneKey = GlobalKey(); // Reset the key to force rebuild
      _autocompleteProductKey = GlobalKey(); // Reset the key to force rebuild
      isCustomerFound = false;
      _fetchCustomers();
      deliveryMethodId = "3";
      deliveryMethod = "Store Takeaway";
      iconColor = 1;
    });
  }

  void printFromSavedOrder(SavedOrder savedOrder) {
    try {
      // Extract cart items from the saved order
      List<Map<String, dynamic>> cartItems = [];

      // Convert SavedOrder items to the format expected by PrintPage
      for (var item in savedOrder.items) {
        cartItems.add({
          'productName': item.product.productName ?? 'Unknown',
          'mrp': (item.product.price?.mrp?.toString() ?? '0.00'),
          'quantity': item.quantity.toString(),
          'unitPrice': (item.price?.toString() ??
              item.product.price?.price?.toString() ??
              '0.00'),
          'totalPrice': ((item.price ?? (item.product.price?.price ?? 0.0)) *
                  item.quantity)
              .toString(),
        });
      }

      // Debug - check what's being sent
      debugPrint("Sending ${cartItems.length} items to PrintPage");
      debugPrint(
          "Sample item: ${cartItems.isNotEmpty ? json.encode(cartItems[0]) : 'No items'}");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrintPage(
            storeName: savedOrder.customerName ?? "",
            cartItems: cartItems,
            formattedTotal: savedOrder.total.toString(),
            savedTotal: "0.00", // Adjust if you track discounts
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
}

/// A widget to display saved orders in a vertical scrollable list
class VerticalSavedOrdersView extends StatelessWidget {
  final Function(String) onOrderSelected;

  const VerticalSavedOrdersView({
    Key? key,
    required this.onOrderSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        return BuildBoxShadowContainer(
          circleRadius: 7,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Saved Orders",
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.21,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),

              // New order button
              _buildNewOrderButton(context, provider),

              // Orders list
              Expanded(
                child: provider.savedOrders.isEmpty
                    ? const Center(
                        child: Text("No saved orders"),
                      )
                    : ListView.builder(
                        itemCount: provider.savedOrders.length,
                        itemBuilder: (context, index) {
                          final order = provider.savedOrders[index];
                          String time = _formatTimeWith12Hour(order.createdAt);

                          return BuildBoxShadowContainer(
                            circleRadius: 7,
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: InkWell(
                              onTap: () => onOrderSelected(order.id),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          order.orderNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "₹${order.total.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Items: ${order.items.length}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (context.findAncestorStateOfType<
                                                    _BillingPageState>() !=
                                                null) {
                                              context
                                                  .findAncestorStateOfType<
                                                      _BillingPageState>()!
                                                  .printFromSavedOrder(order);
                                            }
                                          },
                                          child: const Icon(
                                            Icons.print,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
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
          ),
        );
      },
    );
  }

  Widget _buildNewOrderButton(
      BuildContext context, LocalProductProvider provider) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          // If currently editing an order and cart has items, update it
          if (provider.currentOrder != null && provider.cartItems.isNotEmpty) {
            provider.updateSavedOrder(
              provider.currentOrder!.id,
              customerName: null, // Get these from context if needed
              customerPhone: null,
              comment: null,
              deliveryMethod: null,
            );
          }

          // If cart has items, save as new order
          else if (provider.cartItems.isNotEmpty) {
            try {
              provider.saveCurrentCartAsOrder();

              // Show feedback
              showScaffold(
                context: context,
                message: "Order Saved Successfully",
              );
            } catch (e) {
              // Swallow exception if cart is empty
            }
          }

          // Clear cart and reset current order
          provider.clearCart();
          // Reset current order using proper method
          if (provider.currentOrder != null) {
            // Create a temporary order ID before clearing
            String orderId = provider.currentOrder!.id;
            // Need to manually clear the current order reference
            provider.loadOrderForEditing(orderId);
            provider.clearCart();
          }
          provider.notifyListeners();

          // Update UI
          (context as Element).markNeedsBuild();
        },
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(
                Icons.add_circle,
                color: ColorManager.kPrimaryColor,
              ),
              SizedBox(width: 8),
              Text(
                "New Order",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorManager.kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeWith12Hour(String isoDate) {
    // Convert ISO date string to DateTime
    DateTime dateTime = DateTime.parse(isoDate);

    // Format time in 12-hour format with AM/PM
    String formattedTime = DateFormat('h:mm a').format(dateTime);

    return formattedTime;
  }
}
