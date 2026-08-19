import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_order_list_design.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/add_to_order.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../../widgets/compact_quantity_control.dart';

class OrderListNew extends StatefulWidget {
  const OrderListNew({super.key});

  @override
  State<OrderListNew> createState() => _OrderListNewState();
}

class _OrderListNewState extends State<OrderListNew> {
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId ?? 1, accessToken: accessToken ?? '');
    getCustomersDetails();
  }

  void getCustomersDetails() async {
    try {
      setState(() {
        // Set loading state if needed
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      // debugPrint("accessToken From AuthModel $accessToken");
      CustomerProvider()
          .listCustomer(accessToken: accessToken ?? "")
          .then((response) {
        if (response["status"] == "success") {
          CustomerListModel customerListModel =
              CustomerListModel.fromJson(response);
          setState(() {
            customerList = customerListModel.data;
          });
        } else {
          // Handle error
        }
      });
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        // Reset loading state if needed
      });
    }
  }

  void _getBalanceAmount() {
    // debugPrint(_paidAmountController.text);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

    return Container(
      margin: const EdgeInsets.only(left: 10, top: 10, bottom: 10, right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: ColorManager.boxShadowColor,
            blurRadius: 2,
            offset: Offset(1, 1),
          ),
        ],
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10.0, right: 10.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(thickness: 1),
                const SizedBox(height: 5),
                _buildMobileNumberInput(size),
                const SizedBox(height: 10),
                _buildCartItemsList(size),
                const SizedBox(height: 5),
                _buildCouponInput(),
                const SizedBox(height: 10),
                _buildPaymentSummary(),
                const SizedBox(height: 10),
                _buildPaymentMethodSelection(),
                const SizedBox(height: 10),
                _buildActionButtons(),
              ],
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
              'order_list_new.title'.tr,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
          ],
        ),
        Text(
          'order_list_new.label_order_no'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s12, 0.18,
              ColorManager.textColor),
        ),
      ],
    );
  }

  Widget _buildMobileNumberInput(Size size) {
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
            height: size.height * .07,
            width: size.width / 3,
            child: Autocomplete<CustomerListModelData>(
              optionsBuilder: (mobileNumberTextController) async {
                // debugPrint(mobileNumberTextController.text);
                if (mobileNumberTextController.text.isEmpty) {
                  return const Iterable<CustomerListModelData>.empty();
                }

                String? accessToken =
                    Provider.of<AuthModel>(context, listen: false).token;
                // debugPrint("accessToken From AuthModel $accessToken");
                // debugPrint(mobileNumberTextController.text);

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
                    return filteredCustomerList!.isNotEmpty
                        ? filteredCustomerList
                        : const Iterable<CustomerListModelData>.empty();
                  } else {
                    // debugPrint('Error in response: ${response["message"]}');
                  }
                } catch (error) {
                  // debugPrint('Exception caught: $error');
                }

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
                  controller:
                      mobileNumberTextController, // Ensure this is correctly set
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'order_list_new.hint_mobile'.tr,
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
                      mobileNumberText =
                          value; // Update the state variable as well
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
          child: InkWell(
            onTap: () => {
              showAddCustomerModal(context, size,
                  mobileNumber: mobileNumberText ?? ""),
            },
            child: WebsafeSvg.asset(
              ImageAssets.userIcon,
              fit: BoxFit.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsList(Size size) {
    final generalSettingsprovider =
        Provider.of<GeneralSettingsProvider>(context);
    return SizedBox(
      height: size.height * 0.22,
      child: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          return StreamBuilder<List<ListCartModelData>>(
            stream: cartProvider.cartStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // debugPrint("Inside Order List Consumer");
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
                    String price = cartItem[index].unitPrice.toString();
                    TextEditingController priceController =
                        TextEditingController(text: price);

                    return BuildBoxShadowContainer(
                      circleRadius: 7,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 3),
                      child: ExpansionTile(
                        maintainState: true,
                        childrenPadding: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                        key: ValueKey(cartItem[index].id),
                        trailing: GestureDetector(
                          onTap: () {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            Provider.of<CartProvider>(context, listen: false)
                                .removeFromCartAPI(
                              accessToken: accessToken ?? "",
                              customerId:
                                  Provider.of<AuthModel>(context, listen: false)
                                      .userId!,
                              productId: cartItem[index].id ?? 1,
                              remove: "true",
                            );
                          },
                          child: WebsafeSvg.asset(
                            ImageAssets.oderlistCloseIcon,
                            fit: BoxFit.none,
                            width: 10,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        iconColor: ColorManager.textColor,
                        collapsedIconColor: ColorManager.textColor,
                        title: GestureDetector(
                          onTap: () {
                            debugPrint(
                                "stockEnabled ${generalSettingsprovider.generalSettings!.stockEnabled}");
                            if (!generalSettingsprovider
                                .generalSettings!.stockEnabled) {
                              // Handle stock enabled condition
                            }
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double fontSize =
                                  constraints.maxWidth < 600 ? 12 : 14;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${index + 1}. ${cartItem[index].productName}',
                                              style: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  fontSize,
                                                  0.21,
                                                  ColorManager.textColor),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            Text(
                                              '${cartItem[index].productUnit}',
                                              style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  fontSize - 2,
                                                  0.21,
                                                  ColorManager.textColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Center(
                                          child: CompactQuantityControl(
                                            productId:
                                                cartItem[index].productId!,
                                            cartItemId: cartItem[index].id!,
                                            quantity: cartItem[index].quantity!,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: priceController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.end,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: 'order_list_new.hint_price'.tr,
                                            hintStyle: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                          // onChanged: (newPrice) {
                                          //   if (newPrice.isNotEmpty) {
                                          //     String? accessToken =
                                          //         Provider.of<AuthModel>(
                                          //                 context,
                                          //                 listen: false)
                                          //             .token;

                                          //     Provider.of<CartProvider>(context,
                                          //             listen: false)
                                          //         .updateCartItemPrice(
                                          //       accessToken: accessToken ?? "",
                                          //       cartItemId:
                                          //           cartItem[index].id ?? 0,
                                          //       unitPrice: newPrice,
                                          //       customerId:
                                          //           1, // Adjust this as necessary
                                          //     );
                                          //     showScaffold(
                                          //       context: context,
                                          //       message:
                                          //           'Price Updated Successfully',
                                          //     );
                                          //   }
                                          // },
                                          onSubmitted: (newPrice) {
                                            if (newPrice.isNotEmpty) {
                                              String? accessToken =
                                                  Provider.of<AuthModel>(
                                                          context,
                                                          listen: false)
                                                      .token;

                                              Provider.of<CartProvider>(context,
                                                      listen: false)
                                                  .updateCartItemPrice(
                                                accessToken: accessToken ?? "",
                                                cartItemId:
                                                    cartItem[index].id ?? 0,
                                                unitPrice: newPrice,
                                                customerId:
                                                    1, // Adjust this as necessary
                                              );
                                              showScaffold(
                                                context: context,
                                                message:
                                                    'order_list_new.msg_price_updated'.tr,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: Text(
                                    cartItem[index].productName!,
                                    textAlign: TextAlign.start,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        12,
                                        0.21,
                                        ColorManager.textColor),
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
              } else if (snapshot.hasError) {
                return Text('order_list_new.err_snapshot'.trParams({'error': '${snapshot.error}'}));
              } else {
                return const BuildOrderListDesign();
              }
            },
          );
        },
      ),
    );
  }

  void _showCartItemDetailsDialog(
      BuildContext context, ListCartModelDataCartItem cartItem) {
    final TextEditingController amountController =
        TextEditingController(text: cartItem.unitPrice.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            cartItem.productName ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     const Text(
                  //       'Unit Price:',
                  //       style: TextStyle(
                  //           fontSize: 16, fontWeight: FontWeight.bold),
                  //     ),
                  //     Text(
                  //       '${cartItem.unitPrice} ${cartItem.currency}',
                  //       style: const TextStyle(
                  //           fontSize: 16, fontWeight: FontWeight.bold),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'order_list_new.label_enter_price'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('general.close'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                if (amountController.text.isEmpty) {
                  showScaffoldError(
                    context: context,
                    message: 'order_list_new.msg_invalid_price'.tr,
                  );
                  return;
                } else {
                  String newPrice = amountController.text;

                  String? accessToken =
                      Provider.of<AuthModel>(context, listen: false).token;

                  Provider.of<CartProvider>(context, listen: false)
                      .updateCartItemPrice(
                    accessToken: accessToken ?? "",
                    cartItemId: cartItem.id ?? 0,
                    unitPrice: newPrice,
                    customerId: 1,
                  );
                  showScaffold(
                    context: context,
                    message: 'order_list_new.msg_price_updated'.tr,
                  );
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
              child: Text('order_list_new.btn_update'.tr),
            ),
          ],
        );
      },
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
              decoration: InputDecoration(
                hintText: 'order_list_new.hint_coupon'.tr,
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

  Widget _buildPaymentSummary() {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return Column(
          children: [
            BuildPaymentRow(
              amount:
                  "$currency ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.subTotal ?? 0.00)}",
              title: "Net amount",
              color: ColorManager.textColor,
            ),
            BuildPaymentRow(
              amount: "$currency 0.00",
              title: "Shipping",
              color: ColorManager.textColor,
            ),
            BuildPaymentRow(
              amount:
                  "$currency ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.discount ?? 0.00)}",
              title: "Discount",
              color: ColorManager.textColor,
            ),
            GestureDetector(
              child: BuildPaymentRow(
                amount: "$currency ${AmountHelper.formatAmount(
                  Provider.of<CartProvider>(context, listen: true)
                          .priceSummary!
                          .totalTax ??
                      0.00,
                )}",
                title: "GST",
                color: ColorManager.kPrimaryColor,
              ),
              onTap: () {
                // debugPrint("Tax Details ${taxNames.toString()}");
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
                  "$currency ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal ?? 0.00)}",
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
      },
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

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
                          colorFilter: const ColorFilter.mode(
                              Colors.black, BlendMode.srcIn),
                          fit: BoxFit.none,
                        ),
                        Text(
                          'order_list_new.payment_cash'.tr,
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
                          colorFilter: const ColorFilter.mode(
                              Colors.black, BlendMode.srcIn),
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
                          colorFilter: const ColorFilter.mode(
                              Colors.black, BlendMode.srcIn),
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
                              decoration: InputDecoration(
                                hintText: 'order_list_new.hint_transaction_ref'.tr,
                              ),
                            )
                          : TextFormField(
                              controller: _paidAmountController,
                              onChanged: (value) {
                                _getBalanceAmount();
                              },
                              decoration: InputDecoration(
                                hintText: 'order_list_new.hint_paid_amount'.tr,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (iconColor == 1)
              BuildPaymentRow(
                amount: "$currency ${_balanceAmount.toStringAsFixed(2)}",
                title: 'order_list_new.label_balance_amount'.tr,
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
      },
    );
  }

  Widget _buildActionButtons() {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final currency = appSettingsProvider.appSettings?.currency ?? 'INR';

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(13.0),
                bottomRight: Radius.circular(13.0),
                topLeft: Radius.circular(13.0),
                bottomLeft: Radius.circular(13.0),
              ),
              boxShadow: [
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
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () async {
                      if (selectedCustomerID == null &&
                          mobileNumberText == "") {
                        showScaffoldError(
                          context: context,
                          message: 'order_list_new.msg_select_customer'.tr,
                        );
                      } else if (iconColor != 1 &&
                          iconColor != 2 &&
                          iconColor != 3) {
                        showScaffoldError(
                          context: context,
                          message: 'order_list_new.msg_select_payment'.tr,
                        );
                      } else {
                        String? accessToken =
                            Provider.of<AuthModel>(context, listen: false)
                                .token;
                        // debugPrint("accessToken From AuthModel $accessToken");
                        final provider =
                            Provider.of<CartProvider>(context, listen: false);
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

                        if (!await SubscriptionActionGuard
                            .ensureOrderSubmissionAllowed(context)) {
                          return;
                        }
                        try {
                          await Provider.of<CartProvider>(context,
                                  listen: false)
                              .addToOrderAPI(
                            cartIds: cartId!,
                            accessToken: accessToken ?? "",
                            transactionId: _transactionNumberController.text,
                            totalPrice: Provider.of<CartProvider>(context,
                                    listen: false)
                                .priceSummary!
                                .netTotal
                                .toString(),
                            customerId: selectedCustomerID,
                            customerPhone: selectedCustomerPhone,
                            phone: mobileNumberText,
                            paymentMethod: paymentMethod,
                          )
                              .then((response) async {
                            if (await SubscriptionActionGuard
                                .handleBackendResponse(context, response)) {
                              return;
                            }
                            AddToOrderModel addToOrderModel =
                                AddToOrderModel.fromJson(response);
                            // debugPrint("$response");
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
                                mobileNumberTextController
                                    .clear(); // Clear the text field
                              });
                            } else {
                              showScaffoldError(
                                context: context,
                                message: "${addToOrderModel.message}",
                              );
                            }
                          });
                        } catch (error) {
                          // debugPrint(error.toString());
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(0.0),
                          bottomLeft: Radius.circular(13.0),
                          topLeft: Radius.circular(13.0),
                          bottomRight: Radius.circular(0.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ColorManager.boxShadowColor,
                            blurRadius: 6,
                            offset: Offset(1, 1),
                          ),
                        ],
                        color: ColorManager.kPrimaryColor,
                      ),
                      child: Text(
                        'order_list_new.btn_save_sales'.trParams({'amount': AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal)}),
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s16, 0.27, Colors.white),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      String formattedTotal = AmountHelper.formatAmount(
                          Provider.of<CartProvider>(context, listen: false)
                              .priceSummary!
                              .netTotal);
                      // debugPrint(cartProductItems!.length.toString());
                      // debugPrint(formattedTotal.toString());
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintPage(
                            cartItems: cartProductItems!,
                            formattedTotal: formattedTotal,
                            discountAmount: Provider.of<CartProvider>(context,
                                        listen: false)
                                    .priceSummary
                                    ?.discount
                                    ?.toString() ??
                                "0.00",
                            orderDate: DateHelper.formatInputToDisplay(
                                DateHelper.now().toString()),
                            orderNumber: "#000000",
                          ),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WebsafeSvg.asset(
                          ImageAssets.printIcon,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                          fit: BoxFit.none,
                        ),
                        Text(
                          'general.print'.tr,
                          style: buildCustomStyle(FontWeightManager.medium,
                              FontSize.s10, 0.16, Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            discountAmount: discountAmount,
            discountedTotal: discountedTotal,
          );

          showScaffold(
            context: context,
            message: result['message'] ?? 'order_list_new.msg_coupon_applied'.tr,
          );
        } else {
          showScaffoldError(
            context: context,
            message: result['message'] ?? 'order_list_new.msg_coupon_failed'.tr,
          );
        }
      } else {
        showScaffoldError(
          context: context,
          message: 'order_list_new.msg_error'.tr,
        );
      }
    } else {
      showScaffoldError(context: context, message: 'order_list_new.msg_not_authenticated'.tr);
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
      showScaffoldError(context: context, message: 'order_list_new.msg_unknown_discount'.tr);
      return 0.0; // Default value in case of an error
    }
  }
}
