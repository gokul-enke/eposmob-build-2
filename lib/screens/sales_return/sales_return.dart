import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:provider/provider.dart';

import '../../components/build_round_button.dart';
import '../../models/list_sales_order.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';

import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SalesReturnScreen extends StatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  GetStoreModelData? storeSelected;
  DateTime? selectedDate;
  TextEditingController quantityController = TextEditingController();
  TextEditingController unitPriceController = TextEditingController();
  TextEditingController selectedProductIdController = TextEditingController();

  bool isInitLoading = false;
  String orderNumber = "";
  OrderDetailsModelData? orderDetailsModelData;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  GlobalKey _autocompleteProductKey = GlobalKey();
  GlobalKey _autocompletePhoneKey = GlobalKey();
  bool isCustomerFound = false;
  String? mobileNumberText = "";
  int? selectedCustomerID;
  String? selectedCustomerPhone;
  CustomerListModelData? selectedCustomer;
  Map<int, bool> hoverMap = {};
  String? selectedOrderId;

  bool initLoading = false;
  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        storeId: 1,
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchOrders(page) async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SalesProvider orderProvider =
          Provider.of<SalesProvider>(context, listen: false);

      debugPrint("orderNumberController.text ${orderNumberController.text}");

      await orderProvider.fetchOrders(
        accessToken: accessToken ?? '',
        // storeId: 1,
        orderNumber: orderNumberController.text,
        customerId: selectedCustomerID,
        // productId: int.parse(selectedProductIdController.text),
        // // filterName: customerNameController.text,
        // // filterPrice: amountController.text,
        // // filterEmail: emailController.text,
        // // filterPhone: phoneController.text,
        date: selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
            : '',
        // filterStore: storeController.text,
        page: page,
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      orderNumberController.clear();
      customerNameController.clear();
      amountController.clear();
      emailController.clear();
      phoneController.clear();
      storeController.clear();
      selectedDate = null;
      dateController.clear();
    });
    loadInitData();
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  Future<void> getOrderDetails(ordersId) async {
    setState(() {
      isInitLoading = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      final response = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");
      if (response["status"] == "success") {
        setState(() {
          OrderDetailsModel orderDetails = OrderDetailsModel.fromJson(response);
          orderDetailsModelData = orderDetails.data;
        });
      } else {
        setState(() {
          orderNumber = "Order Details Not found";
        });
      }
    } catch (error) {
      debugPrint(error.toString());
      setState(() {
        orderNumber = "Error fetching order details";
      });
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
            margin:
                const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white),
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
              child: ListView(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Sales Return",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, ColorManager.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Order Number",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                width: 120,
                                onchanged: (value) {},
                                controller: orderNumberController,
                                size: size,
                                hintText: 'Order Number',
                              ),
                            ],
                          ),
                        ),

                        // Date
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Date",
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.27,
                                    Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              BuildBoxShadowContainer(
                                circleRadius: 7,
                                height: 45,
                                width: 150,
                                child: Center(
                                  child: CalendarPickerTableCell(
                                    onDateSelected: (DateTime date) {
                                      selectedDate = date;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 38),
                          child: ProductAutocomplete(
                            autocompleteProductKey: _autocompleteProductKey,
                            size: size,
                            onSelected: (GetProduct selectedProduct) {
                              setState(() {
                                selectedProductIdController.text =
                                    selectedProduct.productId.toString();
                                unitPriceController.text =
                                    selectedProduct.price?.price ?? '';
                                quantityController.text = '1';
                              });
                            },
                            productList: productProvider.productList!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0),
                          child: SizedBox(
                            height: size.height * .07,
                            width: size.width / 3,
                            child: _buildMobileNumberInput(size: size),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              CustomRoundButton(
                                title: "Search",
                                fct: () {
                                  searchOrders(1);
                                },
                                height: 45,
                                width: size.width * 0.09,
                                fontSize: FontSize.s12,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 25),
                          child: Column(
                            children: [
                              CustomRoundButton(
                                title: "Reset",
                                boxColor: Colors.white,
                                textColor: ColorManager.kPrimaryColor,
                                fct: resetSearch,
                                height: 45,
                                width: size.width * 0.09,
                                fontSize: FontSize.s12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Orders Found",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, ColorManager.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    height: 160, // Set a height for the card list
                    child: Center(
                      child: Consumer<SalesProvider>(
                          builder: (context, orderProvider, child) {
                        List<ListOrderModelData> orders = orderProvider.orders;
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderCard(
                              context,
                              orderId: order.id.toString(),
                              orderNumber: order.orderNumber.toString(),
                              date: order.orderDate.toString(),
                              customer: order.customerDetails!.name.toString(),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                  // PaginationControl(
                  //   currentPage:
                  //       Provider.of<SalesProvider>(context, listen: true)
                  //           .currentPage,
                  //   totalPages:
                  //       Provider.of<SalesProvider>(context, listen: true)
                  //           .totalPages,
                  //   onPageChanged: (int page) {
                  //     searchOrders(page);
                  //   },
                  // ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Order Items",
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, ColorManager.textColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  _buildOrderDetails(),
                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            )),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String date,
    required String customer,
  }) {
    bool isSelected = selectedOrderId == orderId;
    return GestureDetector(
      onTap: () {
        getOrderDetails(orderNumber);
        debugPrint('Card tapped for Order ID: $orderId');
      },
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.all(8),
        child: BuildBoxShadowContainer(
          circleRadius: 7,
          width: 250,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order ID: $orderId',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order Number: $orderNumber',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateHelper.formatDate(DateTime.parse(date))}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Customer: $customer',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNumberInput({
    required Size size,
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
      ],
    );
  }

  void _showReturnDialog(
      BuildContext context, String unitPrice, String orderId, int cartItemId) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final TextEditingController returnTotalController = TextEditingController();

    // Update return total whenever quantity changes
    quantityController.addListener(() {
      final quantity = int.tryParse(quantityController.text) ?? 0;
      final price = double.tryParse(unitPrice) ?? 0.0;
      final total = quantity * price;
      returnTotalController.text =
          total.toStringAsFixed(2); // Format to 2 decimal places
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Return Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  keyboardType: TextInputType.text,
                ),
                TextField(
                  controller: returnTotalController,
                  decoration: const InputDecoration(labelText: 'Return Total'),
                  keyboardType: TextInputType.number,
                  readOnly:
                      true, // Make it read-only since it's auto-calculated
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  String? accessToken =
                      Provider.of<AuthModel>(context, listen: false).token;

                  await Provider.of<SalesProvider>(context, listen: false)
                      .submitSalesReturn(
                    accessToken: accessToken ?? '',
                    orderId: int.parse(orderId),
                    price: double.parse(unitPrice),
                    quantity: int.parse(quantityController.text),
                    cartItemId: cartItemId,
                    reason: reasonController.text,
                  );

                  showScaffold(
                    context: context,
                    message: 'Sales Return Submitted',
                  );

                  // Optionally, refresh the orders or cart items after submission
                  // await Provider.of<SalesProvider>(context, listen: false).fetchOrders(...);

                  Navigator.of(context).pop(); // Close the dialog
                } catch (error) {
                  debugPrint('Error submitting sales return: $error');
                  // Optionally show an error message to the user
                }
              },
              child: const Text('Submit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrderDetails() {
    if (orderDetailsModelData == null ||
        orderDetailsModelData!.cart?.cartItems == null ||
        orderDetailsModelData!.cart!.cartItems!.isEmpty) {
      return const Column(
        children: [
          Center(child: Text("No order details available.")),
          SizedBox(height: 50),
        ],
      );
    }

    final cartItems = orderDetailsModelData!.cart!.cartItems!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product Name')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Quantity')),
          DataColumn(label: Text('Unit Price')),
          DataColumn(label: Text('Total Price')),
          // DataColumn(label: Text('Returned Quantity')),
          // DataColumn(label: Text('Reason')),
          // DataColumn(label: Text('Return Total')),
          // DataColumn(label: Text('Returned')),
          DataColumn(label: Text('Action')),
        ],
        rows: cartItems.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.productName ?? 'N/A')),
            DataCell(Text(item.categoryName ?? 'N/A')),
            DataCell(Text(item.quantity?.toString() ?? '0')),
            DataCell(Text(item.unitPrice ?? 'N/A')),
            DataCell(Text(item.totalPrice ?? 'N/A')),
            // DataCell(Text(item.quantity?.toString() ?? '0')),
            // DataCell(Text(item.quantity?.toString() ?? '0')),
            // DataCell(Text(item.quantity?.toString() ?? '0')),
            // DataCell(Text(item.quantity?.toString() ?? '0')),
            DataCell(
              TextButton(
                onPressed: () {
                  _showReturnDialog(
                    context,
                    item.unitPrice ?? '0',
                    orderDetailsModelData!.ordersId.toString(),
                    item.id ?? 0,
                  );
                },
                child: const Text("Return"),
              ),
            )
          ]);
        }).toList(),
      ),
    );
  }
}
