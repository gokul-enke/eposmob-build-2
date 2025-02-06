import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_cart_list_skelton.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/models/add_to_order.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/compact_quantity_control.dart';
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
  int? selectedCustomerID;
  String? selectedCustomerPhone;
  CartProvider cartProvider = CartProvider();
  int iconColor = 0;
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
  bool isCustomerFound = false;
  bool isCouponApplied = false;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _barcodeNode = FocusNode();

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId ?? 1, accessToken: accessToken ?? '');
    _focusNode.addListener(_handleFocusChange);
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
    super.dispose();
  }

  void _focusTextField() {
    debugPrint("Focusing Text Field");
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    if (appSettingsProvider.appSettings!.barcodeSales) {
      FocusScope.of(context).requestFocus(_barcodeNode);
    } else {}
    selectedProductNameController.clear();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      debugPrint('Focus gained');
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
        debugPrint("Error handling key press: $e");
      }
    }
  }

  void _refetchCartData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    // Fetch cart data
    Provider.of<CartProvider>(context, listen: false)
        .fetchCartDataFromApi(
      customerId: customerId ?? 1,
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: BuildBoxShadowContainer(
                  circleRadius: 10,
                  margin: const EdgeInsets.only(
                      left: 10, top: 10, bottom: 10, right: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const Divider(thickness: 1),
                        const SizedBox(height: 5),
                        _buildOrderHeader(
                          size: size,
                          barcodeController: barcodeController,
                          quantityController: quantityController,
                          unitPriceController: unitPriceController,
                          selectedProductIdController:
                              selectedProductIdController,
                          productProvider: productProvider,
                        ),
                        const SizedBox(height: 5),
                        _buildCartItemsTable(size),
                        const SizedBox(height: 5),
                        // _buildMobileNumberInput(size),
                        // const SizedBox(height: 5),
                        // _buildCouponInput(),
                        const SizedBox(height: 10),
                        // _buildPaymentSummary(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildMobileNumberInput(
                                        size: size,
                                        mobileNumberTextController:
                                            mobileNumberTextController),
                                    const SizedBox(height: 10),
                                    _buildPaymentMethodSelection(),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                                child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 10),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'New Order',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
          ],
        ),
        Text(
          'Order No #00000',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.18,
              ColorManager.textColor),
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
                                List<GetProduct>? products;
                                products = await productProvider
                                    .filterProductByBarcodeAPI(barCode: query);
                                debugPrint(products?.first.toString());
                                if (products!.length == 1) {
                                  showScaffold(
                                    context: context,
                                    message: 'Product Found',
                                  );
                                  setState(() {
                                    selectedProductIdController.text =
                                        products!.first.productId.toString();
                                    unitPriceController.text =
                                        products.first.price?.price ?? '';
                                    quantityController.text = '1';
                                    selectedProductNameController.text =
                                        products.first.productName ?? '';
                                    barcodeController.text =
                                        products.first.barcode ?? '';
                                  });
                                }
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
                          child: ProductAutocomplete(
                            autocompleteProductKey: _autocompleteProductKey,
                            autofocus:
                                !appSettingsProvider.appSettings!.barcodeSales,
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
                              fct: () {
                                String? accessToken = Provider.of<AuthModel>(
                                        context,
                                        listen: false)
                                    .token;
                                debugPrint(
                                    "accessToken From AuthModel $accessToken");
                                Provider.of<CartProvider>(context,
                                        listen: false)
                                    .addToCartAPI(
                                        customerId: 1,
                                        productId: int.parse(
                                            selectedProductIdController.text),
                                        quantity:
                                            int.parse(quantityController.text),
                                        unitPrice: unitPriceController.text,
                                        accessToken: accessToken ?? "")
                                    .then((value) {
                                  AddToCartModel addToCartModel =
                                      AddToCartModel.fromJson(value);
                                  if (value["status"] == "success") {
                                    showScaffold(
                                      context: context,
                                      message: addToCartModel.message ??
                                          'Added To Cart',
                                    );
                                    setState(() {
                                      _autocompleteProductKey = GlobalKey();
                                      quantityController.clear();
                                      barcodeController.clear();
                                      selectedProductIdController.clear();
                                      unitPriceController.clear();
                                    });
                                    _focusTextField();
                                    //  'Order Placed Successfully',
                                  } else {
                                    showScaffoldError(
                                      context: context,
                                      message: addToCartModel.message ??
                                          "Error Occured ! Try Again",
                                    );
                                    //  'Added To Cart',
                                  }
                                });
                                _refetchCartData();
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
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return StreamBuilder<List<ListCartModelData>>(
          stream: cartProvider.cartStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List<ListCartModelDataCartItem>? cartItems =
                  snapshot.data!.isEmpty ? [] : snapshot.data!.first.cartItems;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.transparent),
                        ),
                        headingRowColor: WidgetStateColor.resolveWith(
                            (states) =>
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
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text('Unit',
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text('Quantity',
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text('Unity Price',
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text('Total Price',
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                          DataColumn(
                            label: Expanded(
                              child: Text('Actions',
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                      FontWeightManager.bold,
                                      14,
                                      0.21,
                                      ColorManager.textColor)),
                            ),
                          ),
                        ],
                        rows: cartItems!.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Align(
                                alignment: Alignment.center,
                                child: Text(
                                  item.productName ?? 'Unknown',
                                  style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      12,
                                      0.21,
                                      ColorManager.textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              )),
                              DataCell(Align(
                                alignment: Alignment.center,
                                child: Text(
                                  item.productUnit ?? '-',
                                  style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      12,
                                      0.21,
                                      ColorManager.textColor),
                                  textAlign: TextAlign.center,
                                ),
                              )),
                              DataCell(Center(
                                child: CompactQuantityControl(
                                  productId: item.productId!,
                                  cartItemId: item.id!,
                                  quantity: item.quantity ?? 0,
                                  unitPrice: item.unitPrice.toString(),
                                ),
                              )),
                              DataCell(Center(
                                child: SizedBox(
                                  width: 80,
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    controller: TextEditingController(
                                        text: item.unitPrice.toString()),
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
                                      _updateItemPrice(context, item, newPrice);
                                    },
                                  ),
                                ),
                              )),
                              DataCell(Center(
                                child: SizedBox(
                                  width: 80,
                                  child: Text(item.totalPrice.toString()),
                                ),
                              )),
                              DataCell(Center(
                                child: IconButton(
                                  icon: WebsafeSvg.asset(
                                    ImageAssets.oderlistCloseIcon,
                                    width: 15,
                                  ),
                                  onPressed: () {
                                    _removeCartItem(context, item);
                                  },
                                ),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              );
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return const Center(child: BuildCartListDesign());
            }
          },
        );
      },
    );
  }

  void _updateItemPrice(
      BuildContext context, ListCartModelDataCartItem item, String newPrice) {
    if (newPrice.isNotEmpty) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      Provider.of<CartProvider>(context, listen: false).updateCartItemPrice(
        accessToken: accessToken ?? "",
        cartItemId: item.id ?? 0,
        unitPrice: newPrice,
        customerId: 1, // Adjust this as necessary
      );

      showScaffold(
        context: context,
        message: 'Price Updated Successfully',
      );
    }
  }

  void _removeCartItem(BuildContext context, ListCartModelDataCartItem item) {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    Provider.of<CartProvider>(context, listen: false).removeFromCartAPI(
      accessToken: accessToken ?? "",
      customerId: Provider.of<AuthModel>(context, listen: false).userId!,
      productId: item.id ?? 1,
      remove: "true",
    );
  }

  Widget _buildPaymentSummary() {
    return Column(
      children: [
        BuildPaymentRow(
          amount:
              "INR ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.subTotal ?? 0.00)}",
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
              "INR ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.discount ?? 0.00)}",
          title: "Discount",
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount: "INR ${AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .totalTax ??
                  0.00,
            )}",
            title: "GST",
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            debugPrint("Tax Details ${taxNames.toString()}");
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
              "INR ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal ?? 0.00)}",
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
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Cash',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s8, 0.12, Colors.black),
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
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Card',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s8, 0.12, Colors.black),
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
                      color: Colors.black,
                      fit: BoxFit.none,
                    ),
                    Text(
                      'Upi',
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s8, 0.12, Colors.black),
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
                      ? TextFormField(
                          controller: _transactionNumberController,
                          decoration: const InputDecoration(
                            hintText: 'Transaction Reference No:',
                          ),
                        )
                      : TextFormField(
                          controller: _paidAmountController,
                          onChanged: (value) {
                            _getBalanceAmount();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Enter Paid Amount Here:',
                          ),
                        ),
                ),
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
          ),
          _buildActionButton(
            text: 'Save Order',
            color: ColorManager.kButtonYellow,
            onPressed: _saveOrder,
          ),
          _buildActionButton(
            text: 'Create Order and Print',
            color: ColorManager.kButtonBlue,
            onPressed: _createOrderAndPrint,
          ),
          _buildActionButton(
            text: 'Confirm Order',
            color: ColorManager.kButtonGreen,
            onPressed: _confirmOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Center(
              child: Text(
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
        Expanded(
          child: BuildBoxShadowContainer(
            circleRadius: 7,
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            padding: const EdgeInsets.only(left: 15),
            height: size.height * .07,
            width: size.width / 3,
            child: Autocomplete<CustomerListModelData>(
              key: _autocompletePhoneKey, // Set the key here
              optionsBuilder: (mobileNumberTextController) async {
                debugPrint(mobileNumberTextController.text);
                if (mobileNumberTextController.text.isEmpty) {
                  setState(() {
                    isCustomerFound = false; // Reset validity
                  });
                  return const Iterable<CustomerListModelData>.empty();
                }

                String? accessToken =
                    Provider.of<AuthModel>(context, listen: false).token;
                debugPrint("accessToken From AuthModel $accessToken");
                debugPrint(mobileNumberTextController.text);

                try {
                  final response = await CustomerProvider().findCustomerByPhone(
                      accessToken ?? "",
                      mobileNumberTextController.text,
                      context);

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
                    debugPrint('Error in response: ${response["message"]}');
                  }
                } catch (error) {
                  debugPrint('Exception caught: $error');
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
                debugPrint("accessToken From AuthModel $accessToken");
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
                  AutocompleteOnSelected<CustomerListModelData> onSelected,
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
          child: (isCustomerFound || selectedCustomerID != null)
              ? InkWell(
                  onTap: () => {},
                  child: const Icon(
                    Icons.check_circle,
                    color: ColorManager.kButtonGreen,
                    size: 30,
                  ),
                )
              : InkWell(
                  onTap: () => {
                    setState(() {
                      _autocompletePhoneKey = GlobalKey();
                      mobileNumberTextController.clear();
                      selectedCustomerID = null;
                      selectedCustomerPhone = null;
                      selectedCustomer = null;
                      isCustomerFound = false;
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
        //         child: Column(
        //           mainAxisAlignment: MainAxisAlignment.center,
        //           crossAxisAlignment: CrossAxisAlignment.center,
        //           children: [
        //             Center(
        //               child: WebsafeSvg.asset(
        //                 ImageAssets.oderlistCloseIcon,
        //                 width: 27,
        //                 color: ColorManager.kButtonRed,
        //               ),
        //             ),
        //           ],
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
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Provider.of<CartProvider>(context, listen: false).clearCartAPI(
      accessToken: accessToken ?? "",
      customerId: Provider.of<AuthModel>(context, listen: false).userId!,
      productId: Provider.of<CartProvider>(context, listen: false)
              .cartData[0]
              .cartItems![0]
              .id ??
          1,
      remove: "true",
    );
    _refetchCartData();
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
    _focusTextField();
  }

  void _saveOrder() async {
    debugPrint("Create Order pressed");
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
    } else {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      final provider = Provider.of<CartProvider>(context, listen: false);
      int cartId = provider.getCartIDForOrder;
      debugPrint("$cartId");

      String paymentMethod = "";

      if (iconColor == 1) {
        paymentMethod = "CASH";
      } else if (iconColor == 2) {
        paymentMethod = "CARD";
      } else if (iconColor == 3) {
        paymentMethod = "UPI";
      }

      try {
        await Provider.of<CartProvider>(context, listen: false)
            .addToOrderAPI(
          cartIds: cartId,
          accessToken: accessToken ?? "",
          transactionId: _transactionNumberController.text,
          totalPrice: Provider.of<CartProvider>(context, listen: false)
              .priceSummary!
              .netTotal
              .toString(),
          customerId: selectedCustomerID,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          paymentMethod: paymentMethod,
          paidAmount: _paidAmountController.text,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
        )
            .then((response) {
          if (response["order_number"] != null) {
            showScaffold(
              context: context,
              message: "Order Saved Succesfully",
            );

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
      } catch (error) {
        debugPrint(error.toString());
      }
    }
    _focusTextField();
  }

  void _createOrderAndPrint() async {
    debugPrint("selectedCustomerID");
    debugPrint(selectedCustomerPhone.toString());
    debugPrint("mobileNumberText");
    debugPrint(mobileNumberText.toString());
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
    } else {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      final provider = Provider.of<CartProvider>(context, listen: false);
      int cartId = provider.getCartIDForOrder;
      debugPrint("$cartId");

      String paymentMethod = "";

      if (iconColor == 1) {
        paymentMethod = "CASH";
      } else if (iconColor == 2) {
        paymentMethod = "CARD";
      } else if (iconColor == 3) {
        paymentMethod = "UPI";
      }

      try {
        await Provider.of<CartProvider>(context, listen: false)
            .addToOrderConfirmAPI(
          cartIds: cartId,
          accessToken: accessToken ?? "",
          transactionId: _transactionNumberController.text,
          totalPrice: Provider.of<CartProvider>(context, listen: false)
              .priceSummary!
              .netTotal
              .toString(),
          customerId: selectedCustomerID,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          paymentMethod: paymentMethod,
          paidAmount: _paidAmountController.text,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
        )
            .then((response) {
          AddToOrderModel addToOrderModel = AddToOrderModel.fromJson(response);
          debugPrint("$response");
          if (response["status"] == "success") {
            showScaffold(
              context: context,
              message: "${addToOrderModel.message}",
            );

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
            });
            resetAutocomplete();

            String formattedTotal = AmountHelper.formatAmount(
                Provider.of<CartProvider>(context, listen: false)
                    .priceSummary!
                    .netTotal);
            debugPrint(cartProductItems!.length.toString());
            debugPrint(formattedTotal.toString());

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrintPage(
                  cartItems: cartProductItems!,
                  formattedTotal: formattedTotal,
                  orderDate: DateHelper.formatDate(DateTime.now()),
                  orderNumber: "#000000",
                ),
              ),
            );
          } else {
            showScaffoldError(
              context: context,
              message: "${addToOrderModel.message}",
            );
          }
        });
      } catch (error) {
        debugPrint(error.toString());
      }
    }
    _focusTextField();
  }

  void _confirmOrder() async {
    debugPrint("Create Order pressed");
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
    } else {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");
      final provider = Provider.of<CartProvider>(context, listen: false);
      int cartId = provider.getCartIDForOrder;
      debugPrint("$cartId");

      String paymentMethod = "";

      if (iconColor == 1) {
        paymentMethod = "CASH";
      } else if (iconColor == 2) {
        paymentMethod = "CARD";
      } else if (iconColor == 3) {
        paymentMethod = "UPI";
      }

      try {
        await Provider.of<CartProvider>(context, listen: false)
            .addToOrderConfirmAPI(
          cartIds: cartId,
          accessToken: accessToken ?? "",
          transactionId: _transactionNumberController.text,
          totalPrice: Provider.of<CartProvider>(context, listen: false)
              .priceSummary!
              .netTotal
              .toString(),
          customerId: selectedCustomerID,
          customerPhone: selectedCustomerPhone ?? mobileNumberText,
          paymentMethod: paymentMethod,
          paidAmount: _paidAmountController.text,
          balanceAmount: _balanceAmount.toString(),
          couponId: isCouponApplied ? coupenCodeTextController.text : null,
        )
            .then((response) {
          AddToOrderModel addToOrderModel = AddToOrderModel.fromJson(response);
          debugPrint("$response");
          if (response["status"] == "success") {
            showScaffold(
              context: context,
              message: "${addToOrderModel.message}",
            );

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
            });
            resetAutocomplete();
          } else {
            showScaffoldError(
              context: context,
              message: "${addToOrderModel.message}",
            );
          }
        });
      } catch (error) {
        debugPrint(error.toString());
      }
    }
    _focusTextField();
  }

  void _getBalanceAmount() {
    debugPrint(_paidAmountController.text);
    num netTotal = Provider.of<CartProvider>(context, listen: false)
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
    double? totalAmount = Provider.of<CartProvider>(context, listen: false)
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
    });
  }
}
