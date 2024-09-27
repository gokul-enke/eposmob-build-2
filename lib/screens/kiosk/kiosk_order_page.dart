// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/models/add_to_order.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';
import 'package:pos_machine/screens/kiosk/kiosk_billing_page.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/product_card_list_kiosk.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class KioskOrderPage extends StatefulWidget {
  const KioskOrderPage({Key? key}) : super(key: key);

  @override
  KioskOrderPageState createState() => KioskOrderPageState();
}

class KioskOrderPageState extends State<KioskOrderPage> {
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  String mobileNumberText = "";
  CartProvider cartProvider = CartProvider();
  int iconColor = 0;
  UniqueKey keyTile = UniqueKey();
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;
  List<ListCartModelDataCartItem>? cartProductItems = [];
  Map<String, int> taxNames = {};
  Map<int, bool> hoverMap = {};

  @override
  void initState() {
    super.initState();
    _fetchCartData();
    getCustomersDetails();
  }

  void _fetchCartData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    debugPrint("accessToken From AuthModel $accessToken");
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId ?? 1, accessToken: accessToken ?? '');
  }

  Future<void> getCustomersDetails() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      debugPrint("accessToken From AuthModel $accessToken");

      final response =
          await CustomerProvider().listCustomer(accessToken: accessToken ?? "");

      if (response["status"] == "success") {
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setState(() {
          customerList = customerListModel.data;
        });
      } else {
        // Handle error
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  @override
  void dispose() {
    _transactionNumberController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Confirm Your Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: FontSize.s16),
        ),
      ),
      body: _buildBody(size),
    );
  }

  Widget _buildBody(Size size) {
    return BuildBoxShadowContainer(
      circleRadius: 13,
      color: Colors.white,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildOrderList(),
            ),

            const SizedBox(height: 10),
            _buildCouponRow(),
            const SizedBox(height: 10),
            _buildPaymentSummary(),
            const SizedBox(height: 10),
            _buildConfirmationButtons(size),

            //  _buildHeader(),
            // const Divider(thickness: 1),
            // _buildMobileInputRow(size),
            // const SizedBox(height: 10),
            // _buildOrderList(),
            // const SizedBox(height: 5),
            // _buildCouponRow(),
            // const SizedBox(height: 10),
            // _buildPaymentSummary(),
            // const SizedBox(height: 10),
            // _buildPaymentMethod(),
            // _buildConfirmationButtons(size),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'New Order',
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
              0.30, ColorManager.textColor),
        ),
      ],
    );
  }

  Widget _buildMobileInputRow(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMobileNumberField(size),
        ),
        const SizedBox(width: 15),
        _buildAddCustomerButton(),
      ],
    );
  }

  Widget _buildMobileNumberField(Size size) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 15),
      height: size.height * .07,
      width: size.width / 3,
      child: Autocomplete<CustomerListModelData>(
        optionsBuilder: (mobileNumberTextController) async {
          debugPrint(mobileNumberTextController.text);
          if (mobileNumberTextController.text.isEmpty) {
            return const Iterable<CustomerListModelData>.empty();
          }

          if (mobileNumberTextController.text.length < 3) {
            String? accessToken =
                Provider.of<AuthModel>(context, listen: false).token;

            debugPrint("accessToken From AuthModel $accessToken");
            debugPrint(mobileNumberTextController.text);

            try {
              final response = await CustomerProvider().findCustomerByPhone(
                  accessToken ?? "", mobileNumberTextController.text, context);

              if (response["status"] == "success") {
                CustomerListModel customerListModel =
                    CustomerListModel.fromJson(response);
                return customerListModel.data!;
              } else {
                // Handle error
                debugPrint('Error in response: ${response["message"]}');
              }
            } catch (error) {
              debugPrint('Exception caught: $error');
            }
          }

          return customerList!; // Return the existing list
        },
        displayStringForOption: (CustomerListModelData customer) =>
            customer.name ?? '',
        onSelected: (CustomerListModelData selection) {
          String? accessToken =
              Provider.of<AuthModel>(context, listen: false).token;
          Provider.of<CartProvider>(context, listen: false)
              .fetchCartDataFromApi(
                  customerId: selection.id ?? 0,
                  accessToken: accessToken ?? '');

          setState(() {
            mobileNumberText = selection.phone!;
            selectedCustomer = selection;
          });
        },
        fieldViewBuilder: (BuildContext context, mobileNumberTextController,
            FocusNode focusNode, VoidCallback onFieldSubmitted) {
          return TextField(
            controller: mobileNumberTextController,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Enter mobile number',
              hintStyle: buildCustomStyle(
                  FontWeight.w500, 12, 0.27, Colors.grey.withOpacity(.5)),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                mobileNumberText = value;
              });
            },
            style: buildCustomStyle(
                FontWeight.w500, 12, 0.27, Colors.black.withOpacity(.5)),
          );
        },
        optionsViewBuilder: (BuildContext context,
            AutocompleteOnSelected<CustomerListModelData> onSelected,
            Iterable<CustomerListModelData> options) {
          return _buildCustomerOptionsView(context, onSelected, options);
        },
      ),
    );
  }

  Widget _buildCustomerOptionsView(
      BuildContext context,
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
              final CustomerListModelData option = options.elementAt(index);
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
                        option.name ?? '',
                        style: buildCustomStyle(FontWeight.w500, 12, 0.27,
                            Colors.black.withOpacity(.5)),
                      ),
                      hoverColor: Colors.grey[200], // Hover effect
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAddCustomerButton() {
    return BuildBoxShadowContainer(
      height: MediaQuery.of(context).size.height * .07,
      width: 50,
      circleRadius: 5,
      child: InkWell(
        onTap: () => showAddCustomerModal(context, MediaQuery.of(context).size,
            mobileNumber: mobileNumberText),
        child: WebsafeSvg.asset(ImageAssets.userIcon, fit: BoxFit.none),
      ),
    );
  }

  Widget _buildOrderList() {
    return Consumer<CartProvider>(builder: (context, cartProvider, child) {
      return StreamBuilder<List<ListCartModelData>>(
        stream: cartProvider.cartStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            debugPrint("Inside Order List Consumer");
            List<ListCartModelData>? cartItems = snapshot.data;
            List<ListCartModelDataCartItem>? cartItem = cartItems!.isEmpty
                ? []
                : cartItems.map((e) => e.cartItems).first;

            if (cartItems.isNotEmpty) {
              taxNames = cartItems.first.taxAmounts ?? {};
            }

            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: cartItem!.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int index) {
                final product = cartItem[index];
                // return _buildOrderListItem(cartItem[index], index);
                return ProductCardList(
                  height: 50,
                  // imageLink: product.productAttchment?.isNotEmpty == true
                  //     ? product.productAttchment![0].filePath ??
                  //         'https://via.placeholder.com/150'
                  //     : 'https://via.placeholder.com/150',
                  title: product.productName.toString(),
                  currency: product.currency ?? "",
                  price: product.unitPrice ?? 0.0,
                  count: product.quantity ?? 0,
                  productId: product.productId ?? 0,
                  totalPrice: product.totalPrice ?? "",
                  removeFromCart: () =>
                      _removeFromCart(context, product.productId ?? 0),
                  addToCart: () => _addToCart(context, product.productId ?? 0),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      );
    });
  }

  void _addToCart(BuildContext context, int productId) {
    final customerId = Provider.of<AuthModel>(context, listen: false).userId;
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;

    Provider.of<CartProvider>(context, listen: false)
        .addToCartAPI(
      customerId: customerId ?? 1,
      productId: productId,
      quantity: 1,
      accessToken: accessToken ?? "",
    )
        .then((value) {
      AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
      if (value["status"] == "success") {
        showScaffold(
            context: context,
            message: addToCartModel.message ?? "Added to Cart");
        // Notify the cart provider of the change so it updates count
        Provider.of<CartProvider>(context, listen: false)
            .incrementCount(productId);
      } else {
        showScaffoldError(
            context: context,
            message: addToCartModel.message ?? "Error Occurred! Try Again!");
      }
    });
  }

  void _removeFromCart(BuildContext context, int productId) {
    final customerId = Provider.of<AuthModel>(context, listen: false).userId;
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;

    // Get the cartId associated with the productId
    int? cartId = Provider.of<CartProvider>(context, listen: false)
        .getCartIdFromProductId(productId);

    debugPrint("product id is ${productId.toString()}");
    debugPrint("cart id is ${cartId.toString()}");

    Provider.of<CartProvider>(context, listen: false)
        .removeFromCartAPI(
      customerId: customerId ?? 1,
      productId: cartId!,
      accessToken: accessToken ?? "",
      remove: "false",
    )
        .then((value) {
      debugPrint("removed succesrfully");

      AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
      if (value["status"] == "success") {
        showScaffold(
            context: context,
            message: addToCartModel.message ?? "Removed From Cart");
        // Notify the cart provider of the change so it updates count
        Provider.of<CartProvider>(context, listen: false)
            .decrementCount(productId);
      } else {
        showScaffoldError(
            context: context,
            message: addToCartModel.message ?? "Error Occurred! Try Again!");
      }
    });
  }

  Widget _buildOrderListItem(ListCartModelDataCartItem item, int index) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        maintainState: true,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        collapsedBackgroundColor:
            index % 2 == 0 ? Colors.grey.withOpacity(0.1) : null,
        backgroundColor: index % 2 == 0 ? Colors.grey.withOpacity(0.1) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        key: ValueKey(item.id),
        trailing: _buildRemoveFromCartIcon(item.id!),
        controlAffinity: ListTileControlAffinity.leading,
        iconColor: ColorManager.textColor,
        collapsedIconColor: ColorManager.textColor,
        title: _buildOrderListTitle(item, index),
      ),
    );
  }

  Widget _buildRemoveFromCartIcon(int itemId) {
    return GestureDetector(
      onTap: () {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        Provider.of<CartProvider>(context, listen: false).removeFromCartAPI(
            accessToken: accessToken ?? "",
            customerId: Provider.of<AuthModel>(context, listen: false).userId!,
            productId: itemId,
            remove: "true");
      },
      child: WebsafeSvg.asset(ImageAssets.oderlistCloseIcon,
          fit: BoxFit.none, width: 10),
    );
  }

  Widget _buildOrderListTitle(ListCartModelDataCartItem item, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = constraints.maxWidth < 600 ? 12 : 14;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${item.productName}',
                        style: buildCustomStyle(FontWeightManager.regular,
                            fontSize, 0.21, ColorManager.textColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '${item.productUnit}',
                        style: buildCustomStyle(FontWeightManager.medium,
                            fontSize - 2, 0.21, ColorManager.textColor),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: CompactQuantityControl(
                      quantity: item.quantity!,
                      onIncrement: () =>
                          _adjustCartQuantity(item.productId ?? 1, 1),
                      onDecrement: () => _adjustCartQuantity(item.id ?? 1, -1),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.currency} ${item.unitPrice}',
                    style: buildCustomStyle(FontWeightManager.regular, fontSize,
                        0.21, ColorManager.textColor),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _adjustCartQuantity(int productId, int change) {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    if (change > 0) {
      Provider.of<CartProvider>(context, listen: false).addToCartAPI(
          accessToken: accessToken ?? "",
          customerId: Provider.of<AuthModel>(context, listen: false).userId!,
          productId: productId,
          quantity: 1);
    } else {
      Provider.of<CartProvider>(context, listen: false).removeFromCartAPI(
          accessToken: accessToken ?? "",
          customerId: Provider.of<AuthModel>(context, listen: false).userId!,
          productId: productId,
          remove: '');
    }
  }

  Widget _buildCouponRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildCouponTextField(),
        ),
        const SizedBox(width: 10),
        _buildApplyButton(),
      ],
    );
  }

  Widget _buildCouponTextField() {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 15),
      height: MediaQuery.of(context).size.height * .07,
      width: MediaQuery.of(context).size.width / 3,
      child: TextField(
        controller: coupenCodeTextController,
        decoration: InputDecoration(
          hintText: 'Apply Coupon',
          hintStyle: buildCustomStyle(
              FontWeight.w500, 12, 0.27, Colors.grey.withOpacity(.5)),
          border: InputBorder.none,
        ),
        style: buildCustomStyle(
            FontWeight.w500, 12, 0.27, Colors.black.withOpacity(.5)),
      ),
    );
  }

  Widget _buildApplyButton() {
    return CustomRoundButton(
      title: "Apply",
      fct: _applyCoupon,
      fontSize: FontSize.s14,
      height: MediaQuery.of(context).size.height * .07,
      width: 100,
    );
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
        if (result['status'] == 'success') {
          final couponData = result['data']['data'];
          double discountAmount = _calculateDiscount(totalAmount, couponData);
          double discountedTotal = totalAmount - discountAmount;

          Provider.of<CartProvider>(context, listen: false).updatePriceSummary(
              discountAmount: discountAmount, discountedTotal: discountedTotal);

          showScaffold(
              context: context,
              message: result['message'] ?? 'Coupon Applied Successfully');
        } else {
          showScaffoldError(
              context: context,
              message: result['message'] ?? 'Failed to Apply Coupon');
        }
      } else {
        showScaffoldError(
            context: context, message: 'Error Occurred! Try Again');
      }
    } else {
      showScaffoldError(context: context, message: 'Not Authenticated');
    }
  }

  double _calculateDiscount(
      double totalAmount, Map<String, dynamic> couponData) {
    final discountType = couponData['discount_type'];
    final discountValue = double.parse(couponData['discount_value'].toString());
    final discountLimit =
        double.parse(couponData['discount_coupon_limit_amount'].toString());

    double discountAmount;

    if (discountType == 'percent') {
      discountAmount = totalAmount * (discountValue / 100);
      return discountAmount > discountLimit ? discountLimit : discountAmount;
    } else if (discountType == 'fixed') {
      discountAmount = discountValue;
      return discountAmount > discountLimit ? discountLimit : discountAmount;
    } else {
      showScaffoldError(context: context, message: 'Unknown discount type');
      return 0.0; // Default value in case of an error
    }
  }

  Widget _buildPaymentSummary() {
    return Column(
      children: [
        BuildPaymentRow(
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .subTotal ??
                  0.00),
          title: "Net amount",
          color: ColorManager.textColor,
        ),
        const BuildPaymentRow(
          amount: "0.00",
          title: "Shipping",
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .discount ??
                  0.00),
          title: "Discount",
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount: AmountHelper.formatAmount(
                Provider.of<CartProvider>(context, listen: true)
                        .priceSummary!
                        .totalTax ??
                    0.00),
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
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .netTotal ??
                  0.00),
          title: "Total Payable",
          secondRowTextStyle: buildCustomStyle(FontWeightManager.bold,
              FontSize.s15, 0.23, ColorManager.textColor),
          firstRowTextStyle: buildCustomStyle(FontWeightManager.bold,
              FontSize.s15, 0.23, ColorManager.textColor),
          color: ColorManager.textColor,
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      children: [
        SizedBox(height: 5),
        BuildPaymentRow(
          amount: "",
          title: "Chose Payment Method",
          firstRowTextStyle: buildCustomStyle(FontWeightManager.semiBold,
              FontSize.s14, 0.21, ColorManager.kPrimaryColor),
          color: ColorManager.kPrimaryColor,
        ),
        _buildPaymentMethodSelection(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Row(
      children: [
        _buildPaymentMethodOption(Icons.monetization_on, 'Cash', 1),
        _buildPaymentMethodOption(Icons.credit_card, 'Card', 2),
        _buildPaymentMethodOption(Icons.mobile_friendly, 'UPI', 3),
      ],
    );
  }

  Widget _buildPaymentMethodOption(
      IconData icon, String label, int colorIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
          iconColor = colorIndex;
        });
      },
      child: BuildBoxShadowContainer(
        border: iconColor == colorIndex
            ? Border.all(color: ColorManager.kPrimaryColor)
            : null,
        margin: const EdgeInsets.only(top: 10, right: 10),
        padding: const EdgeInsets.all(8),
        blurRadius: 4,
        circleRadius: 5,
        child: Column(
          children: [
            Icon(icon, color: Colors.black),
            Text(
              label,
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s8, 0.12, Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationButtons(Size size) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13.0),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: ColorManager.greyWithOpacity60,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSaveSalesButton(),
            // _buildPrintButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveSalesButton() {
    return Expanded(
      flex: 3,
      child: GestureDetector(
        onTap: () {
          Get.to(() => const KioskBillingPage());
        },
        child: Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(13.0)),
              color: ColorManager.kPrimaryColor,
            ),
            child: Center(
              child: Text(
                'Pay INR ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal)}',
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s16, 0.27, Colors.white),
              ),
            )),
      ),
    );
  }

  Future<void> _saveSales() async {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    final provider = Provider.of<CartProvider>(context, listen: false);
    int cartId = provider.getCartIDForOrder;

    try {
      await provider
          .addToOrderAPI(
        cartIds: cartId,
        accessToken: accessToken ?? "",
        transactionId: _transactionNumberController.text,
        totalPrice: provider.priceSummary!.netTotal.toString(),
        customerId: Provider.of<AuthModel>(context, listen: false).userId!,
      )
          .then((response) {
        AddToOrderModel addToOrderModel = AddToOrderModel.fromJson(response);
        if (response["status"] == "success") {
          showScaffold(context: context, message: "${addToOrderModel.message}");
        } else {
          showScaffoldError(
              context: context, message: "${addToOrderModel.message}");
        }
      });
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  Widget _buildPrintButton() {
    return Expanded(
      child: GestureDetector(
        onTap: _printOrder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebsafeSvg.asset(ImageAssets.printIcon, color: Colors.white),
            Text(
              'Print',
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s10, 0.16, Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _printOrder() {
    String formattedTotal = AmountHelper.formatAmount(
        Provider.of<CartProvider>(context, listen: false)
            .priceSummary!
            .netTotal);
    debugPrint(cartProductItems!.length.toString());

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
  }
}

class CompactQuantityControl extends StatelessWidget {
  final int quantity;
  final Function() onIncrement;
  final Function() onDecrement;

  const CompactQuantityControl({
    Key? key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorManager.kPrimaryColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDecrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.remove,
                  size: 16, color: ColorManager.kPrimaryColor),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            alignment: Alignment.center,
            child: Text(
              quantity.toString(),
              style: buildCustomStyle(
                  FontWeightManager.regular, 12, 0.10, ColorManager.textColor),
            ),
          ),
          InkWell(
            onTap: onIncrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child:
                  Icon(Icons.add, size: 16, color: ColorManager.kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
