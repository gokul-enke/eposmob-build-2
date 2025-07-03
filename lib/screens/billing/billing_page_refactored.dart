import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/billing/action_buttons.dart';
import 'package:pos_machine/widgets/billing/billing_cart_items_table.dart';
import 'package:pos_machine/widgets/billing/billing_payment_summary.dart';
import 'package:pos_machine/widgets/billing/coupon_input.dart';
import 'package:pos_machine/widgets/billing/customer_selection.dart';
import 'package:pos_machine/widgets/billing/delivery_method_selection.dart';
import 'package:pos_machine/widgets/billing/order_header.dart';
import 'package:pos_machine/widgets/billing/order_page_header.dart';
import 'package:pos_machine/widgets/billing/payment_method_selection.dart';
import 'package:pos_machine/widgets/horizontal_product_view_local.dart';
import 'package:pos_machine/widgets/horizontal_saved_orders_view.dart';
import 'package:provider/provider.dart';

class BillingPageRefactored extends StatefulWidget {
  const BillingPageRefactored({super.key});

  @override
  State<BillingPageRefactored> createState() => _BillingPageRefactoredState();
}

class _BillingPageRefactoredState extends State<BillingPageRefactored> {
  // Controllers
  final TextEditingController mobileNumberTextController =
      TextEditingController();
  final TextEditingController coupenCodeTextController =
      TextEditingController();
  final TextEditingController _transactionNumberController =
      TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController selectedProductIdController =
      TextEditingController();
  final TextEditingController selectedProductNameController =
      TextEditingController();

  // Form key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Autocomplete keys
  GlobalKey _autocompletePhoneKey = GlobalKey();
  GlobalKey _autocompleteProductKey = GlobalKey();

  // Focus nodes
  final FocusNode _focusNode = FocusNode();
  final FocusNode _barcodeNode = FocusNode();

  // State variables
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

  // Loading state variables
  bool isCustomerFound = false;
  bool isCouponApplied = false;
  bool isLoadingClearCart = false;
  bool isLoadingSaveOrder = false;
  bool isLoadingCreateOrder = false;
  bool isLoadingConfirmOrder = false;
  bool isLoadingAddItem = false;

  Timer? _debounce;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId!, accessToken: accessToken ?? '');
    _focusNode.addListener(_handleFocusChange);
    deliveryMethodId = "3";
    deliveryMethod = "Store Takeaway";
    iconColor = 1;
    _fetchCustomers();
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
        debugPrint("Error handling key press: $e");
      }
    }
  }

  void _handleBarcodeChanged(String? query) async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        if (query != null && query.isNotEmpty) {
          debugPrint("QUERY: ${query.length}");
          final localProductProvider =
              Provider.of<LocalProductProvider>(context, listen: false);

          List<GetProduct> filteredProducts = [];
          try {
            String? prefix;
            String? productCode;
            String? lastFive;

            if (query.length > 2) {
              prefix = query.substring(0, 3); // First 3 digits;
            }

            if (prefix != '000' || query.length != 14) {
              filteredProducts =
                  Provider.of<LocalProductProvider>(context, listen: false)
                      .filterProductByBarcode(
                barCode: query,
              );
            } else {
              productCode = query.substring(3, 9); // Next 6 digits
              lastFive = query.substring(9, 14); // Last 5 digits
              filteredProducts =
                  Provider.of<LocalProductProvider>(context, listen: false)
                      .filterProductByBarcode(
                barCode: productCode,
              );
            }

            if (filteredProducts.isNotEmpty) {
              // Handle the case where products are found
              GetProduct product = filteredProducts.first;

              if (product.unit == 'KGS' &&
                  prefix == '000' &&
                  query.length == 14) {
                // Weight-based product
                String weightKg =
                    lastFive!.substring(0, 2); // First 2 digits = KG
                String weightGrams =
                    lastFive.substring(2, 5); // Last 3 digits = Grams
                double totalWeight =
                    double.parse(weightKg) + (double.parse(weightGrams) / 1000);

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
                int quantity =
                    int.parse(lastFive!); // Last 5 digits represent quantity

                localProductProvider.addToCart(
                  product: product,
                  quantity: quantity,
                );

                showScaffold(
                  context: context,
                  message: 'Added To Cart',
                );
              } else {
                localProductProvider.addToCart(product: product);

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
            } else {
// Set dialog state to open
              final result = await showDialog(
                context: context,
                builder: (context) =>
                    AddProductWithBarcodeModal(barcode: query),
              );
// Reset dialog state
              debugPrint("result $result");
              if (result != null) {
                localProductProvider.addToCart(
                    productId: result["id"],
                    price: double.tryParse(result["price"].toString()));
                barcodeController.clear();
              } else {
                barcodeController.clear();
                _focusTextField();
              }
              debugPrint("No products found for barcode: $query");
            }
          } catch (e) {
            debugPrint("Error adding item: $e");
            if (mounted) {
              showScaffoldError(
                context: context,
                message: "Invalid Barcode. Please try again.",
              );
            }
          }
        }
      },
    );
  }

  void _getBalanceAmount() {
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

  void _loadSavedOrderForEditing(String orderId) {
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Load the order into the current cart
      localProductProvider.loadOrderForEditing(orderId);

      // Get the current order
      Provider.of<LocalProductProvider>(context, listen: false).currentOrder;

      showScaffold(
        context: context,
        message: "Order loaded for editing",
      );
    } catch (error) {
      debugPrint("Error loading order: $error");
      showScaffoldError(
          context: context, message: "Failed to load order. Please try again.");
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

  // Action methods
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

      // Clear the cart
      localProductProvider.clearCart();
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
        final provider = Provider.of<CartProvider>(context, listen: false);
        int? cartId = provider.getCartIDForOrder;

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
        final provider = Provider.of<CartProvider>(context, listen: false);
        int? cartId = provider.getCartIDForOrder;

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
        totalAmount: totalAmount,
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

  void _onCustomerSelected(
      int? id, String? phone, CustomerListModelData? customer) {
    setState(() {
      mobileNumberText = "";
      selectedCustomerID = id;
      selectedCustomerPhone = phone;
      selectedCustomer = customer;
    });
  }

  void _onPaymentMethodSelected(int methodId) {
    setState(() {
      iconColor = methodId;
    });
  }

  void _onDeliveryMethodSelected(String method, String id) {
    setState(() {
      deliveryMethod = method;
      deliveryMethodId = id;
    });
  }

  void _onClearCustomerDetails() {
    setState(() {
      _autocompletePhoneKey = GlobalKey();
      mobileNumberTextController.clear();
      mobileNumberText = "";
      selectedCustomerID = null;
      selectedCustomerPhone = null;
      selectedCustomer = null;
      isCustomerFound = false;
      salesExecutivemobileNumberText = "";
    });
    showScaffold(
      context: context,
      message: 'Customer Details Cleared Successfully',
    );
  }

  void _onAddItem() {
    setState(() {
      isLoadingAddItem = true; // Start loading
    });
    try {
      // Get the selected product from LocalProductProvider
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      final selectedProduct = localProductProvider.selectedProduct;

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
        message: "Failed to add item. Please try again.",
      );
    } finally {
      debugPrint('Finally adding item');
      setState(() {
        isLoadingAddItem = false; // End loading
      });
    }
  }

  void _onClearProductDetails() {
    setState(() {
      _autocompleteProductKey = GlobalKey();
      quantityController.clear();
      barcodeController.clear();
      selectedProductIdController.clear();
      unitPriceController.clear();
    });
    _focusTextField();
    showScaffold(
      context: context,
      message: 'Product Details Cleared Successfully',
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: HorizontalSavedOrdersView(
                        onOrderSelected: (orderId) {
                          _loadSavedOrderForEditing(orderId);
                        },
                      ),
                    ),
                    BuildBoxShadowContainer(
                      circleRadius: 10,
                      margin: const EdgeInsets.only(
                          left: 10, top: 0, bottom: 10, right: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const OrderPageHeader(),
                            const Divider(thickness: 1),
                            const HorizontalProductViewLocal(),
                            const SizedBox(height: 10),
                            OrderHeader(
                              size: size,
                              barcodeController: barcodeController,
                              quantityController: quantityController,
                              unitPriceController: unitPriceController,
                              selectedProductIdController:
                                  selectedProductIdController,
                              selectedProductNameController:
                                  selectedProductNameController,
                              autocompleteProductKey: _autocompleteProductKey,
                              barcodeNode: _barcodeNode,
                              onBarcodeChanged: _handleBarcodeChanged,
                              onAddItem: _onAddItem,
                              onClearProductDetails: _onClearProductDetails,
                              isLoadingAddItem: isLoadingAddItem,
                            ),
                            const SizedBox(height: 5),
                            BillingCartItemsTable(size: size),
                            const SizedBox(height: 5),
                            const SizedBox(height: 10),
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
                                        CustomerSelection(
                                          mobileNumberText: mobileNumberText,
                                          onMobileNumberChanged: (value) {
                                            setState(() {
                                              mobileNumberText = value;
                                              selectedCustomerID = null;
                                              selectedCustomerPhone = null;
                                              selectedCustomer = null;
                                            });
                                          },
                                          onCustomerSelected:
                                              _onCustomerSelected,
                                          mobileNumberTextController:
                                              mobileNumberTextController,
                                          isCustomerFound: isCustomerFound,
                                          selectedCustomerId:
                                              selectedCustomerID,
                                          autocompletePhoneKey:
                                              _autocompletePhoneKey,
                                          onClearCustomerDetails:
                                              _onClearCustomerDetails,
                                        ),
                                        const SizedBox(height: 10),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            PaymentMethodSelection(
                                              iconColor: iconColor,
                                              onPaymentMethodSelected:
                                                  _onPaymentMethodSelected,
                                              transactionNumberController:
                                                  _transactionNumberController,
                                              paidAmountController:
                                                  _paidAmountController,
                                              balanceAmount: _balanceAmount,
                                              onPaidAmountChanged: (value) {
                                                _getBalanceAmount();
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            DeliveryMethodSelection(
                                              deliveryMethod: deliveryMethod,
                                              onDeliveryMethodSelected:
                                                  _onDeliveryMethodSelected,
                                              carNumberController:
                                                  _carNumberController,
                                              commentController:
                                                  _commentController,
                                            ),
                                          ],
                                        ),
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
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      CouponInput(
                                        couponCodeController:
                                            coupenCodeTextController,
                                        isCouponApplied: isCouponApplied,
                                        onApplyCoupon: _applyCoupon,
                                        onRemoveCoupon: () {
                                          setState(() {
                                            isCouponApplied =
                                                false; // Reset coupon state
                                            coupenCodeTextController
                                                .clear(); // Clear the coupon code
                                            // Fetch the cart data again after removing the coupon
                                            String? accessToken =
                                                Provider.of<AuthModel>(context,
                                                        listen: false)
                                                    .token;
                                            int? customerId =
                                                Provider.of<AuthModel>(context,
                                                        listen: false)
                                                    .userId;

                                            Provider.of<CartProvider>(context,
                                                    listen: false)
                                                .fetchCartDataFromApi(
                                              customerId: customerId!,
                                              accessToken: accessToken ?? '',
                                            );
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      BillingPaymentSummary(taxNames: taxNames),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ActionButtons(
                              onClearCart: _clearCart,
                              onSaveOrder: _saveOrder,
                              onCreateOrderAndPrint: _createOrderAndPrint,
                              onConfirmOrder: _confirmOrder,
                              isLoadingClearCart: isLoadingClearCart,
                              isLoadingSaveOrder: isLoadingSaveOrder,
                              isLoadingCreateOrder: isLoadingCreateOrder,
                              isLoadingConfirmOrder: isLoadingConfirmOrder,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
