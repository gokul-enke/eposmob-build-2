import 'package:flutter/material.dart';
// import 'package:get/get_core/src/get_main.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_order_list_design.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
// import 'package:pos_machine/components/build_round_button.dart';
// import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../components/build_payment_row.dart';
import '../models/add_to_order.dart';
import '../models/customer_list.dart';
import '../models/list_cart.dart';
import '../providers/auth_model.dart';
import '../providers/cart_provider.dart';
import '../providers/customer_provider.dart';
import '../resources/color_manager.dart';

class OrderList extends StatefulWidget {
  const OrderList({super.key});

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  String mobileNumberText = "";
  CartProvider cartProvider = CartProvider();
  int iconColor = 0;
  double _balanceAmount = 0;
  UniqueKey keyTile = UniqueKey();
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;
  List<ListCartModelDataCartItem>? cartProductItems = [];

  Map<int, bool> hoverMap = {};

  @override
  void initState() {
    super.initState();

    // _paidAmountController = TextEditingController();
    // _paidAmountController.addListener(_onTextChanged);

    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    // debugPrint("accessToken From AuthModel $accessToken");
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId ?? 1, accessToken: accessToken ?? '');
    // customerId: 1,
    // accessToken: accessToken ?? '');
    // _paidAmountController.text =

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
    // Retrieve netTotal from the provider
    num netTotal = Provider.of<CartProvider>(context, listen: false)
            .priceSummary!
            .netTotal ??
        0.00;

    // Parse the text from the controller
    double paidAmount = double.tryParse(_paidAmountController.text) ?? 0.00;

    // Calculate the balance amount
    double balanceAmount = paidAmount - netTotal;

    // Return the balance amount formatted to two decimal places
    setState(() {
      _balanceAmount = balanceAmount;
    });
  }

  // void _onTextChanged() {
  //   // debugPrint("called");
  //   _getBalanceAmount();
  // }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set the text of the controller based on the provider's value
    // final subTotal =
    //     "${Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal ?? 0.00}";
    // _paidAmountController.text = "$subTotal";
  }

  @override
  void dispose() {
    _transactionNumberController.dispose();
    // _paidAmountController.removeListener(_onTextChanged);
    _paidAmountController.dispose();
    super.dispose();
  }

  // @override
  // void dispose() {
  //   Provider.of<CartProvider>(context, listen: false).dispose();

  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Column(
      children: [
        Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 10, right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
              color: Colors.white),
          child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Order',
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s20, 0.30, ColorManager.textColor),
                    ),
                    // Row(
                    //   children: [
                    //     BuildBoxShadowContainer(
                    //       height: 29,
                    //       width: 30,
                    //       circleRadius: 7,
                    //       child: WebsafeSvg.asset(
                    //         ImageAssets.deleteIcon,
                    //         fit: BoxFit.none,
                    //       ),
                    //     ),
                    //     const SizedBox(width: 15),
                    //     WebsafeSvg.asset(
                    //       ImageAssets.verticalDotsIcon,
                    //       fit: BoxFit.none,
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
                Text(
                  'Order No #00000',
                  style: buildCustomStyle(FontWeightManager.regular,
                      FontSize.s12, 0.18, ColorManager.textColor),
                ),
                const Divider(thickness: 1),
                Text(
                  'Enter mobile number',
                  style: buildCustomStyle(FontWeightManager.regular,
                      FontSize.s10, 0.16, ColorManager.textColor),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // BuildBoxShadowContainer(
                          //   padding: const EdgeInsets.all(10),
                          //   height: 30,
                          //   circleRadius: 5,
                          //   alignment: Alignment.center,
                          //   child: TextField(
                          //     textAlign: TextAlign.start,
                          //     style: buildCustomStyle(
                          //         FontWeight.normal, 8, 0.16, Colors.black),
                          //     controller: mobileNumberTextController,
                          //     cursorHeight: 10,
                          //     cursorWidth: 1,
                          //     cursorColor: Colors.blue,
                          //     decoration: const InputDecoration(
                          //         border: InputBorder.none),
                          //   ),
                          // ),
                          // const SizedBox(height: 20),
                          // customerList!.isNotEmpty
                          //     ?
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 0),
                            padding: const EdgeInsets.only(left: 15),
                            height: MediaQuery.of(context).size.height * .07,
                            width: MediaQuery.of(context).size.width / 3,
                            child: Autocomplete<CustomerListModelData>(
                              optionsBuilder:
                                  (mobileNumberTextController) async {
                                // debugPrint(mobileNumberTextController.text);
                                if (mobileNumberTextController.text.isEmpty) {
                                  return const Iterable<
                                      CustomerListModelData>.empty();
                                }
                                if (mobileNumberTextController.text.length <
                                    5) {
                                  // debugPrint("called");
                                  String? accessToken = Provider.of<AuthModel>(
                                          context,
                                          listen: false)
                                      .token;
                                  debugPrint(
                                      "accessToken From AuthModel $accessToken");

                                  // debugPrint(mobileNumberTextController.text);

                                  try {
                                    final response = await CustomerProvider()
                                        .findCustomerByPhone(
                                            accessToken ?? "",
                                            mobileNumberTextController.text,
                                            context);

                                    if (response["status"] == "success") {
                                      CustomerListModel customerListModel =
                                          CustomerListModel.fromJson(response);

                                      List<CustomerListModelData>?
                                          filterdCustomerList =
                                          customerListModel.data;

                                      return filterdCustomerList!;
                                      // setState(() {
                                      // });
                                    } else {
                                      // Handle error
                                      debugPrint(
                                          'Error in response: ${response["message"]}');
                                    }
                                  } catch (error) {
                                    // Handle network or parsing error
                                    // debugPrint('Exception caught: $error');
                                  }
                                }
                                return customerList!;
                                // !.where(
                                //     (CustomerListModelData customer) {
                                //   return customer.name!
                                //       .toLowerCase()
                                //       .contains(textEditingValue.text
                                //           .toLowerCase());
                                // });
                              },
                              displayStringForOption:
                                  (CustomerListModelData customer) =>
                                      customer.name ?? '',
                              onSelected: (CustomerListModelData selection) {
                                setState(() {
                                  // mobileNumberTextController.text =
                                  //     selection.phone!;
                                  mobileNumberText = selection.phone!;
                                  selectedCustomer = selection;
                                });
                              },
                              fieldViewBuilder: (BuildContext context,
                                  mobileNumberTextController,
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
                                      width:
                                          MediaQuery.of(context).size.width / 3,
                                      color: Colors.white,
                                      constraints: const BoxConstraints(
                                        maxHeight: 200, // Set the height limit
                                      ),
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(8.0),
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
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
                                                    option.name ?? '',
                                                    style: buildCustomStyle(
                                                      FontWeight.w500,
                                                      12,
                                                      0.27,
                                                      Colors.black
                                                          .withOpacity(.5),
                                                    ),
                                                  ),
                                                  hoverColor: Colors.grey[
                                                      200], // Hover effect
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
                          )
                          // : Container(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    BuildBoxShadowContainer(
                      height: MediaQuery.of(context).size.height * .07,
                      width: 50,
                      circleRadius: 5,
                      child: InkWell(
                        onTap: () => {
                          showAddCustomerModal(context, size,
                              mobileNumber: mobileNumberText),
                        },
                        child: WebsafeSvg.asset(
                          ImageAssets.userIcon,
                          fit: BoxFit.none,
                        ),
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 5),
                // Text(
                //   'Select Customer',
                //   style: buildCustomStyle(FontWeightManager.regular,
                //       FontSize.s10, 0.16, ColorManager.textColor),
                // ),
                // const SizedBox(height: 5),
                // customerList != null && customerList!.isNotEmpty
                //     ? BuildBoxShadowContainer(
                //         circleRadius: 7,
                //         alignment: Alignment.centerLeft,
                //         margin: const EdgeInsets.symmetric(
                //             horizontal: 0, vertical: 0),
                //         padding: const EdgeInsets.only(left: 15),
                //         height: size.height * .07,
                //         width: size.width / 3,
                //         child: DropdownButtonFormField<CustomerListModelData>(
                //           decoration: const InputDecoration(
                //             border: InputBorder.none, // Remove the underline
                //           ),
                //           value: selectedCustomer,
                //           hint: Text(
                //             'Please Select',
                //             style: buildCustomStyle(
                //               FontWeightManager.medium,
                //               FontSize.s12,
                //               0.27,
                //               ColorManager.textColor.withOpacity(.5),
                //             ),
                //           ),
                //           items: customerList != null
                //               ? customerList!
                //                   .map((CustomerListModelData customer) {
                //                   return DropdownMenuItem<
                //                       CustomerListModelData>(
                //                     value: customer,
                //                     child: Text(
                //                       customer.name ?? '',
                //                       style: buildCustomStyle(
                //                         FontWeightManager.medium,
                //                         FontSize.s12,
                //                         0.27,
                //                         ColorManager.textColor.withOpacity(.5),
                //                       ),
                //                     ),
                //                   );
                //                 }).toList()
                //               : [],
                //           onChanged: (CustomerListModelData? selectedCustomer) {
                //             setState(() {
                //               this.selectedCustomer = selectedCustomer;
                //             });
                //           },
                //         ),
                //       )
                //     : Container(),
                const SizedBox(height: 10),

                SizedBox(
                  height: size.height * 0.32, // 150,

                  child: Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                    return StreamBuilder<List<ListCartModelData>>(
                        stream: cartProvider.cartStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            // debugPrint("Inside Order List Consumer");
                            List<ListCartModelData>? cartItems = snapshot.data;
                            // List<ListCartModelDataCartItem>? cart =
                            //     cartItems.;
                            List<ListCartModelDataCartItem>? cartItem =
                                cartProductItems = cartItems!.isEmpty
                                    ? []
                                    : cartItems.map((e) => e.cartItems).first;

                            return ListView.builder(
                                // physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: cartItem!.length, //3,
                                shrinkWrap: true,
                                itemBuilder: (BuildContext context, int index) {
                                  return Theme(
                                      data: ThemeData(
                                          dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                        maintainState: true,
                                        childrenPadding:
                                            const EdgeInsets.only(bottom: 10),
                                        collapsedBackgroundColor: index % 2 == 0
                                            ? Colors.grey.withOpacity(0.1)
                                            : null,
                                        backgroundColor: index % 2 == 0
                                            ? Colors.grey.withOpacity(0.1)
                                            : null,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                        tilePadding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        key: ValueKey(cartItem[index].id),
                                        trailing: GestureDetector(
                                          onTap: () {
                                            String? accessToken =
                                                Provider.of<AuthModel>(context,
                                                        listen: false)
                                                    .token;
                                            Provider.of<CartProvider>(context,
                                                    listen: false)
                                                .removeFromCartAPI(
                                              accessToken: accessToken ?? "",
                                              customerId:
                                                  Provider.of<AuthModel>(
                                                          context,
                                                          listen: false)
                                                      .userId!,
                                              productId:
                                                  cartItem[index].id ?? 1,
                                              remove: "true",
                                            );
                                          },
                                          child: WebsafeSvg.asset(
                                            ImageAssets.oderlistCloseIcon,
                                            fit: BoxFit.none,
                                            width: 10, // Adjust icon size
                                          ),
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        iconColor: ColorManager.textColor,
                                        collapsedIconColor:
                                            ColorManager.textColor,
                                        title: LayoutBuilder(
                                          builder: (context, constraints) {
                                            // Calculate responsive sizes
                                            double fontSize =
                                                constraints.maxWidth < 600
                                                    ? 12
                                                    : 14;
                                            // double iconSize =
                                            //     constraints.maxWidth < 600
                                            //         ? 20
                                            //         : 24;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${index + 1}. ${cartItem[index].productName}',
                                                            style: buildCustomStyle(
                                                                FontWeightManager
                                                                    .regular,
                                                                fontSize,
                                                                0.21,
                                                                ColorManager
                                                                    .textColor),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                          Text(
                                                            '${cartItem[index].productUnit}',
                                                            style: buildCustomStyle(
                                                                FontWeightManager
                                                                    .medium,
                                                                fontSize - 2,
                                                                0.21,
                                                                ColorManager
                                                                    .textColor),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Center(
                                                        child:
                                                            CompactQuantityControl(
                                                          quantity:
                                                              cartItem[index]
                                                                  .quantity!,
                                                          onIncrement: () {
                                                            String?
                                                                accessToken =
                                                                Provider.of<AuthModel>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .token;
                                                            Provider.of<CartProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .addToCartAPI(
                                                              accessToken:
                                                                  accessToken ??
                                                                      "",
                                                              customerId: Provider.of<
                                                                          AuthModel>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .userId!,
                                                              productId: cartItem[
                                                                          index]
                                                                      .productId ??
                                                                  1,
                                                              quantity: 1,
                                                            );
                                                          },
                                                          onDecrement: () {
                                                            String?
                                                                accessToken =
                                                                Provider.of<AuthModel>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .token;
                                                            Provider.of<CartProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .removeFromCartAPI(
                                                              accessToken:
                                                                  accessToken ??
                                                                      "",
                                                              customerId: Provider.of<
                                                                          AuthModel>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .userId!,
                                                              productId:
                                                                  cartItem[index]
                                                                          .id ??
                                                                      1,
                                                              remove: '',
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '${cartItem[index].currency} ${cartItem[index].unitPrice}',
                                                        style: buildCustomStyle(
                                                            FontWeightManager
                                                                .regular,
                                                            fontSize,
                                                            0.21,
                                                            ColorManager
                                                                .textColor),
                                                        textAlign:
                                                            TextAlign.end,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return SizedBox(
                                                  width: constraints.maxWidth,
                                                  child: Text(
                                                    cartItem[index]
                                                        .productName!,
                                                    textAlign: TextAlign.start,
                                                    maxLines: 4,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: buildCustomStyle(
                                                      FontWeightManager.regular,
                                                      12,
                                                      0.21,
                                                      ColorManager.textColor,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ));
                                });
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else {
                            // cartProvider.fetchCartData(customerId: 1);
                            return const BuildOrderListDesign();

                            // const Center(
                            //   child: SizedBox(
                            //     height: 50,
                            //     width: 50,
                            //     child: CircularProgressIndicator(
                            //       color: ColorManager.kPrimaryColor,
                            //     ),
                            //   ),
                            // );
                          }
                        });
                  }),
                ),
                // const SizedBox(
                //   height: 10,
                // ),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //   children: [
                //     CustomRoundButton(
                //       title: "Cash",
                //       fct: () async {
                //         String? accessToken =
                //             Provider.of<AuthModel>(context, listen: false)
                //                 .token;
                //         // debugPrint("accessToken From AuthModel $accessToken");

                //         // Ensure the cart ID is available
                //         int cartId =
                //             Provider.of<CartProvider>(context, listen: false)
                //                 .getCartIDForOrder;

                //         if (cartId != 0) {
                //           // Call the addToOrderAPI method
                //           dynamic result = await Provider.of<CartProvider>(
                //                   context,
                //                   listen: false)
                //               .addToOrderAPI(
                //             cartIds: cartId,
                //             accessToken: accessToken ?? "",
                //           );

                //           // Check the result and show a Snackbar accordingly
                //           if (result != false) {
                //             ScaffoldMessenger.of(context)
                //               ..removeCurrentSnackBar()
                //               ..showSnackBar(SnackBar(
                //                 showCloseIcon: true,
                //                 dismissDirection: DismissDirection.up,
                //                 closeIconColor: Colors.white,
                //                 duration: const Duration(seconds: 2),
                //                 behavior: SnackBarBehavior.floating,
                //                 elevation: 0,
                //                 margin: EdgeInsets.only(
                //                     top: 50,
                //                     left:
                //                         MediaQuery.of(context).size.width / 1.9,
                //                     right: 10),
                //                 backgroundColor:
                //                     ColorManager.kPrimaryColor.withOpacity(0.6),
                //                 shape: RoundedRectangleBorder(
                //                     borderRadius: BorderRadius.circular(10)),
                //                 content: Text(
                //                   'Order Added Successfully',
                //                   style: buildCustomStyle(
                //                       FontWeightManager.medium,
                //                       FontSize.s12,
                //                       0.12,
                //                       Colors.white),
                //                 ),
                //               ));
                //           } else {
                //             ScaffoldMessenger.of(context)
                //               ..removeCurrentSnackBar()
                //               ..showSnackBar(SnackBar(
                //                 showCloseIcon: true,
                //                 dismissDirection: DismissDirection.up,
                //                 closeIconColor: Colors.white,
                //                 duration: const Duration(seconds: 2),
                //                 behavior: SnackBarBehavior.floating,
                //                 elevation: 0,
                //                 margin: EdgeInsets.only(
                //                     top: 50,
                //                     left:
                //                         MediaQuery.of(context).size.width / 1.9,
                //                     right: 10),
                //                 backgroundColor: Colors.red.withOpacity(0.6),
                //                 shape: RoundedRectangleBorder(
                //                     borderRadius: BorderRadius.circular(10)),
                //                 content: Text(
                //                   'Failed to Add Order',
                //                   style: buildCustomStyle(
                //                       FontWeightManager.medium,
                //                       FontSize.s12,
                //                       0.12,
                //                       Colors.white),
                //                 ),
                //               ));
                //           }
                //         } else {
                //           ScaffoldMessenger.of(context)
                //             ..removeCurrentSnackBar()
                //             ..showSnackBar(SnackBar(
                //               showCloseIcon: true,
                //               dismissDirection: DismissDirection.up,
                //               closeIconColor: Colors.white,
                //               duration: const Duration(seconds: 2),
                //               behavior: SnackBarBehavior.floating,
                //               elevation: 0,
                //               margin: EdgeInsets.only(
                //                   top: 50,
                //                   left: MediaQuery.of(context).size.width / 1.9,
                //                   right: 10),
                //               backgroundColor: Colors.red.withOpacity(0.6),
                //               shape: RoundedRectangleBorder(
                //                   borderRadius: BorderRadius.circular(10)),
                //               content: Text(
                //                 'Cart ID not available',
                //                 style: buildCustomStyle(
                //                     FontWeightManager.medium,
                //                     FontSize.s12,
                //                     0.12,
                //                     Colors.white),
                //               ),
                //             ));
                //         }
                //       },
                //       fontSize: FontSize.s12,
                //       height: 40,
                //       width: 120,
                //     ),
                //     BuildBoxShadowContainer(
                //       blurRadius: 4,
                //       circleRadius: 5,
                //       child: CustomRoundButton(
                //           boxColor: Colors.transparent,
                //           borderColor: Colors.white,
                //           textColor: ColorManager.kPrimaryColor,
                //           title: "Details",
                //           fct: () {},
                //           fontSize: FontSize.s12,
                //           height: 40,
                //           width: 120),
                //     ),
                //   ],
                // ),
                // Column(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                Container(
                    // height: size.height * 0.45, // 280,
                    // height: size.height * 0.38, // 280,
                    // margin: const EdgeInsets.only(
                    //     left: 10, top: 10, bottom: 10, right: 10),
                    // padding: const EdgeInsets.all(8),
                    // decoration: const BoxDecoration(
                    //     borderRadius: BorderRadius.only(
                    //         topRight: Radius.circular(0.0),
                    //         bottomRight: Radius.circular(13.0),
                    //         topLeft: Radius.circular(0.0),
                    //         bottomLeft: Radius.circular(13.0)),
                    //     boxShadow: [
                    //       BoxShadow(
                    //         color: ColorManager.boxShadowColor,
                    //         blurRadius: 4,
                    //         offset: Offset(1, 1),
                    //       ),
                    //     ],
                    //     color: Colors.white),
                    child: Container(
                  // padding: const EdgeInsets.only(
                  //     left: 8, right: 8, top: 8, bottom: 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BuildPaymentRow(
                        amount:
                            "${Provider.of<CartProvider>(context, listen: true).priceSummary!.subTotal ?? 0.00}",
                        title: "Net amount",
                        color: ColorManager.textColor,
                      ),
                      BuildPaymentRow(
                        amount:
                            "${Provider.of<CartProvider>(context, listen: true).priceSummary!.discount ?? 0.00}",
                        title: "Discount",
                        color: ColorManager.textColor,
                      ),
                      BuildPaymentRow(
                        amount:
                            "${Provider.of<CartProvider>(context, listen: true).priceSummary!.totalTax ?? 0.00}",
                        title: "Tax Amount",
                        color: ColorManager.textColor,
                      ),
                      const Divider(thickness: 2),
                      BuildPaymentRow(
                        amount:
                            "${Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal ?? 0.00}",
                        title: "Payable",
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
                      const SizedBox(height: 5),
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
                              // _getBalanceAmount();
                              setState(() {
                                iconColor = 1;
                              });
                            },
                            child: BuildBoxShadowContainer(
                              border: iconColor == 1
                                  ? Border.all(
                                      color: ColorManager.kPrimaryColor)
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
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s8,
                                        0.12,
                                        Colors.black),
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
                                  ? Border.all(
                                      color: ColorManager.kPrimaryColor)
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
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s8,
                                        0.12,
                                        Colors.black),
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
                                  ? Border.all(
                                      color: ColorManager.kPrimaryColor)
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
                                    style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s8,
                                        0.12,
                                        Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // TextFormField for transaction number
                          if (iconColor == 2 ||
                              iconColor == 3 ||
                              iconColor ==
                                  1) // Assuming 1 is for Cash and 3 is for UPI
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: iconColor != 1
                                    ? TextFormField(
                                        controller:
                                            _transactionNumberController,
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
                          amount: _balanceAmount.toStringAsFixed(2),
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
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          // height: 55,
                          // margin: const EdgeInsets.only(
                          //     left: 10, top: 10, right: 10),
                          //  padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(13.0),
                                  bottomRight: Radius.circular(13.0),
                                  topLeft: Radius.circular(13.0),
                                  bottomLeft: Radius.circular(13.0)),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorManager.boxShadowColor,
                                  blurRadius: 6,
                                  offset: Offset(1, 1),
                                ),
                              ],
                              color: ColorManager.greyWithOpacity60),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: GestureDetector(
                                    onTap: () async {
                                      String? accessToken =
                                          Provider.of<AuthModel>(context,
                                                  listen: false)
                                              .token;
                                      debugPrint(
                                          "accessToken From AuthModel $accessToken");
                                      final provider =
                                          Provider.of<CartProvider>(context,
                                              listen: false);
                                      int? cartId = provider.getCartIDForOrder;
                                      // debugPrint("$cartId");
                                      try {
                                        await Provider.of<CartProvider>(context,
                                                listen: false)
                                            .addToOrderAPI(
                                          cartIds: cartId!,
                                          accessToken: accessToken ?? "",
                                          transactionId:
                                              _transactionNumberController.text,
                                          totalPrice: Provider.of<CartProvider>(
                                                  context,
                                                  listen: false)
                                              .priceSummary!
                                              .netTotal
                                              .toString(),
                                          customerId: Provider.of<AuthModel>(
                                                  context,
                                                  listen: false)
                                              .userId!,
                                        )
                                            .then((response) {
                                          AddToOrderModel addToOrderModel =
                                              AddToOrderModel.fromJson(
                                                  response);
                                          debugPrint(
                                              "$response  Provider.of<CartProvider>(context,listen: false).addToOrderAPI(); ");
                                          if (response["status"] == "success") {
                                            showScaffold(
                                              context: context,
                                              message:
                                                  "${addToOrderModel.message}", //  'Order Placed Successfully',
                                            );
                                          } else {
                                            showScaffoldError(
                                              context: context,
                                              message:
                                                  "${addToOrderModel.message}", //   'Error Occured! Try Again ',
                                            );
                                          }
                                        });
                                      } catch (error) {
                                        // debugPrint(error.toString());
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(0.0),
                                            bottomLeft: Radius.circular(13.0),
                                            topLeft: Radius.circular(13.0),
                                            bottomRight: Radius.circular(0.0)),
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
                                        'Save Sales ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal)}',
                                        style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s16,
                                            0.27,
                                            Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      String formattedTotal =
                                          AmountHelper.formatAmount(
                                              Provider.of<CartProvider>(context,
                                                      listen: false)
                                                  .priceSummary!
                                                  .netTotal);
                                      debugPrint(
                                          cartProductItems!.length.toString());
                                      // debugPrint(formattedTotal.toString());
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PrintPage(
                                            cartItems: cartProductItems!,
                                            formattedTotal: formattedTotal,
                                            discountAmount: Provider.of<CartProvider>(context, listen: false)
                                                .priceSummary?.discount?.toString() ?? "0.00",
                                            orderDate: DateHelper.formatDate(
                                                DateTime.now()),
                                            orderNumber: "#000000",
                                            // storeName: cartProductItems,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        WebsafeSvg.asset(
                                          ImageAssets.printIcon,
                                          color: Colors.white,
                                          fit: BoxFit.none,
                                        ),
                                        Text(
                                          'Print',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s10,
                                              0.16,
                                              Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ]),
                        ),
                      ),
                    ],
                  ),
                )),
                // ],
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
// Consumer<CartProvider>(
//   builder: (context, cartProvider, child) {
//     return YourWidgetWithStreamBuilder(
//       cartProvider: cartProvider,
//     );
//   },
// );
// class YourWidgetWithStreamBuilder extends StatelessWidget {
//   final CartProvider cartProvider;

//   YourWidgetWithStreamBuilder({required this.cartProvider});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<List<ListCartModelData>>(
//       stream: cartProvider.cartStream,
//       builder: (context, snapshot) {
//         if (snapshot.hasData) {
//           // debugPrint("Inside Order List Consumer");
//           List<ListCartModelData>? cartItems = snapshot.data;
//           return Text('Error: ${snapshot.error}');
//           // ... (rest of your code)
//         } else if (snapshot.hasError) {
//           return Text('Error: ${snapshot.error}');
//         } else {
//           return const BuildOrderListDesign();
//         }
//       },
//     );
//   }
// }
// UniqueKey keyTile1 = UniqueKey();
// void expandTile() {
//   setState(() {
//     expanded = true;
//     keyTile = UniqueKey();
//   });
// }

// void shrinkTile() {
//   setState(() {
//     expanded = false;
//     keyTile = UniqueKey();
//   });
// }

// void expandTile1() {
//   setState(() {
//     expanded1 = true;
//     keyTile1 = UniqueKey();
//   });
// }

// void shrinkTile1() {
//   setState(() {
//     expanded1 = false;
//     keyTile1 = UniqueKey();
//   });
// }
// @override
// void initState() {
//   super.initState();
//   Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi();
// }
// @override
// void dispose() {
//   Provider.of<CartProvider>(context, listen: false).dispose();
//   super.dispose();
// }

// class CartScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Shopping Cart'),
//       ),
//       body: Consumer<CartProvider>(
//         builder: (context, cartProvider, child) {
//           return StreamBuilder<List<CartItem>>(
//             stream: cartProvider.cartStream,
//             builder: (context, snapshot) {
//               if (snapshot.hasData) {
//                 List<CartItem> cartItems = snapshot.data;
//                 return /* Your UI to display the cart items */;
//               } else if (snapshot.hasError) {
//                 return Text('Error: ${snapshot.error}');
//               } else {
//                 return CircularProgressIndicator();
//               }
//             },
//           );
//         },
//       ),
//     );
//   }
// }
// const SizedBox(height: 10),
// Theme(
//   data: ThemeData(dividerColor: Colors.transparent),
//   child: ExpansionTile(
//     shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(3)),
//     childrenPadding: const EdgeInsets.only(bottom: 10),
//     tilePadding: EdgeInsets.zero,
//     key: keyTile1,
//     trailing: const SizedBox(),
//     initiallyExpanded: expanded1,
//     leading: expanded1
//         ? GestureDetector(
//             onTap: () {
//               shrinkTile1();
//             },
//             child: const Icon(
//               Icons.keyboard_arrow_down,
//             ),
//           )
//         : GestureDetector(
//             onTap: () {
//               expandTile1();
//             },
//             child: const Icon(
//               Icons.keyboard_arrow_right,
//             ),
//           ),
//     iconColor: ColorManager.textColor,
//     collapsedIconColor: ColorManager.textColor,
//     title: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         // const SizedBox(width: 5),
//         Text(
//           '2',
//           style: buildCustomStyle(FontWeightManager.regular,
//               FontSize.s10, 0.21, ColorManager.textColor),
//         ),
//         //  const SizedBox(width: 10),
//         Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'MIGHTY ZINGER BOX',
//               style: buildCustomStyle(FontWeightManager.regular,
//                   FontSize.s10, 0.21, ColorManager.textColor),
//             ),
//             Text(
//               '150 g',
//               style: buildCustomStyle(FontWeightManager.medium,
//                   FontSize.s8, 0.21, ColorManager.textColor),
//             ),
//           ],
//         ),
//         const SizedBox(width: 20),
//         Text(
//           '\$25.00',
//           style: buildCustomStyle(FontWeightManager.regular,
//               FontSize.s10, 0.21, ColorManager.textColor),
//         ),
//         const SizedBox(width: 15),
//         WebsafeSvg.asset(
//           ImageAssets.oderlistCloseIcon,
//           fit: BoxFit.none,
//         ),
//       ],
//     ),
//     children: <Widget>[
//       Padding(
//         padding: const EdgeInsets.only(left: 10, right: 10),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Column(
//               children: [
//                 Text(
//                   'Quantity',
//                   style: buildCustomStyle(
//                       FontWeightManager.regular,
//                       FontSize.s10,
//                       0.21,
//                       ColorManager.textColor),
//                 ),
//                 SizedBox(
//                   height: 25,
//                   width: 100,
//                   child: TextField(
//                     cursorWidth: 1,
//                     // controller: _searchTextController,
//                     cursorColor: ColorManager.kPrimaryColor,
//                     decoration: decorationBorder.copyWith(
//                       labelStyle: buildCustomStyle(
//                           FontWeightManager.regular,
//                           FontSize.s10,
//                           0.10,
//                           ColorManager.textColor),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(width: 10),
//             Column(
//               children: [
//                 Text(
//                   'Discount(%)',
//                   style: buildCustomStyle(
//                       FontWeightManager.regular,
//                       FontSize.s10,
//                       0.21,
//                       ColorManager.textColor),
//                 ),
//                 SizedBox(
//                   height: 25,
//                   width: 100,
//                   child: TextField(
//                     cursorWidth: 1,
//                     // controller: _searchTextController,
//                     cursorColor: ColorManager.kPrimaryColor,
//                     decoration: decorationBorder.copyWith(
//                       labelStyle: buildCustomStyle(
//                           FontWeightManager.regular,
//                           FontSize.s10,
//                           0.10,
//                           ColorManager.textColor),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     ],
//   ),
//      ),
//   ],

class CompactQuantityControl extends StatelessWidget {
  final num quantity;
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
