import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/add_to_cart.dart';
import '../models/list_cart.dart';
import '../resources/app_url.dart';
import 'package:http/http.dart' as http;

class CartProvider with ChangeNotifier {
  final StreamController<List<ListCartModelData>> _cartStreamController =
      StreamController<List<ListCartModelData>>.broadcast();

  List<ListCartModelData> cartData = [];

  Stream<List<ListCartModelData>> get cartStream =>
      _cartStreamController.stream;
  PriceSummary? priceSummary = PriceSummary(
    discount: 0,
    netPayable: 0,
    subTotal: 0,
    totalTax: 0,
    netTotal: 0,
  );
  int? cartId;

  final Map<int, int> _itemCounts = {}; // Map to track item counts

  setCartIDForOrder(int value) {
    cartId = value;
    notifyListeners();
  }

  void updatePriceSummary(
      {required double discountAmount, required double discountedTotal}) {
    if (priceSummary != null) {
      priceSummary!.discount = discountAmount;
      priceSummary!.netTotal = discountedTotal;
      notifyListeners();
    }
  }

  int? get getCartIDForOrder => cartId;

  int? getCartIdFromProductId(int productId) {
    if (cartData.isNotEmpty) {
      for (var item in cartData) {
        // debugPrint("erererererer");
        // debugPrint(item.toString());
        for (var cartItem in item.cartItems ?? []) {
          // debugPrint(cartItem.toString());
          if (cartItem.productId == productId) {
            // Return the cart ID if found
            // debugPrint(cartItem.id.toString());
            return cartItem
                .id; // Assuming `id` is the cartId you want to return
          }
        }
      }
    }
    return null; // Return null if no cart ID was found for the product ID
  }

  int getItemCount(int productId) {
    return _itemCounts[productId] ?? 0; // Return 0 if not in cart
  }

  void incrementCount(int productId) {
    if (_itemCounts.containsKey(productId)) {
      _itemCounts[productId] = _itemCounts[productId]! + 1;
    } else {
      _itemCounts[productId] = 1; // Set to 1 if not present
    }
    notifyListeners();
  }

  void decrementCount(int productId) {
    if (_itemCounts.containsKey(productId) && _itemCounts[productId]! > 0) {
      _itemCounts[productId] = _itemCounts[productId]! - 1;
      if (_itemCounts[productId] == 0) {
        _itemCounts.remove(productId); // Remove if count is 0
      }
      notifyListeners();
    }
  }

  void resetProductCounts() {
    _itemCounts.clear();
    notifyListeners();
  }

  Future<void> fetchCartDataFromApi({
    required int customerId,
    required String accessToken,
    int? cartId,
  }) async {
    // debugPrint("fetching cart of $customerId");
    // debugPrint("fetching cart of $cartId");
    // Fetch cart data from your API and add it to the stream
    cartData = await fetchCartData(
        customerId: customerId, token: accessToken, cartId: cartId);
    _cartStreamController.add(cartData.isEmpty ? [] : cartData);
    notifyListeners();
  }

  CartProvider() {
    getData();
    // Initialize your stream or add any initial data here if needed.
  }
  getData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? customerId = prefs.getInt('customerId');
    // sample data
    // int? customerId = 1;
    String? token = prefs.getString('access_token');
    fetchCartDataFromApi(customerId: customerId!, accessToken: token ?? "");
  }

  // Dispose the stream controller when done
  @override
  void dispose() {
    _cartStreamController.close();
    super.dispose();
  }

  //          *********************** FETCH  LIST CART API ***************************************************

  Future<List<ListCartModelData>> fetchCartData(
      {required int customerId, required String token, int? cartId}) async {
    debugPrint("LIST ALL CART ITEMS ");
    debugPrint("customerId $customerId");
    debugPrint("cart_id IS $cartId");

    final url = Uri.parse(APPUrl.listCartUrl).replace(queryParameters: {
      'customer_id': "1",
      if (cartId != null) 'cart_id': cartId.toString(),
    });

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');
        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        ListCartModel listCartModel = ListCartModel.fromJson(jsonData);

        // debugPrint(listCartModel.data!.toString());

        PriceSummary? priceSummary = listCartModel.data!.isEmpty
            ? PriceSummary(
                discount: 0,
                netPayable: 0,
                subTotal: 0,
                totalTax: 0,
                netTotal: 0,
              )
            : listCartModel.data!.map((e) => e.priceSummary).first;

        if (listCartModel.data!.isNotEmpty) {
          // debugPrint("  listCartModel.data!.isNotEmpty");
          // debugPrint("${listCartModel.data![0].id ?? 0}");
          setCartIDForOrder(listCartModel.data![0].id ?? 0);
          notifyListeners();
          // debugPrint(
          //     "  listCartModel.data!.isNotEmpty cartId $cartId $getCartIDForOrder");
          // debugPrint("${listCartModel.data![0].id ?? 0}");
        }

        updateSummary(priceSummary);

        return listCartModel.data ?? [];
        // } else if (response.statusCode == 404) {
      } else {
        // debugPrint('Cart not found, setting price fields to 0');
        PriceSummary emptyPriceSummary = PriceSummary(
          discount: 0,
          netPayable: 0,
          subTotal: 0,
          totalTax: 0,
          netTotal: 0,
        );
        updateSummary(emptyPriceSummary);
        return [
          ListCartModelData(
            id: null,
            customerId: customerId,
            userId: null,
            itemCount: 0,
            storeId: null,
            cartItems: [],
            priceSummary: emptyPriceSummary,
            taxAmounts: {},
          )
        ];
      }
      //  else {
      //   return [];
      // }
    } finally {}
  }

  //          *********************** UPDATE PRICE SUMMARY ***************************************************

  void updateSummary(PriceSummary? priceSummaryUpdate) {
    priceSummary = priceSummaryUpdate;
    notifyListeners();
  }

  //          *********************** ADD TO CART API ***************************************************

  Future<dynamic> addToCartAPI({
    required int customerId,
    required int productId,
    required num quantity,
    String? unitPrice,
    required String accessToken,
    int? cartId,
  }) async {
    // sample data
    // customerId = 1;
    // debugPrint("********************ADD TO CART API******************** ");
    // debugPrint(customerId.toString());
    // debugPrint(productId.toString());
    // debugPrint(quantity.toString());
    Map<String, dynamic> apiBodyData = {};
    apiBodyData = {
      'customer_id': "1",
      'quantity': quantity,
      // 'app_type': "api",
      'product_id': productId,
      'source_type': "executive",
      if (cartId != null) "cart_id": cartId.toString(),
      if (unitPrice != null) "price": unitPrice,
      // 'address_id':1,
      // "type": 1
    };

    // debugPrint("productId $productId");
    // debugPrint("customerId $customerId");
    debugPrint("customerId $apiBodyData");
    final url = Uri.parse(APPUrl.addToCartUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      debugPrint('inside 200');

      debugPrint(response.body);
      final jsonData = json.decode(response.body);

      AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);
      if (response.statusCode == 200) {
        await fetchCartDataFromApi(
            customerId: customerId, accessToken: accessToken, cartId: cartId);
        // customerId: customerId, accessToken: accessToken);
        // debugPrint(addToCartModel.status);
        // List<ListCartModelData> cartData = await fetchCartData(customerId: 1);
        //   _cartStreamController.add(cartData);

        // ListCartModelDataPriceSummary? priceSummary =
        //     addToCartModel.cart!.map((e) => e.priceSummary).single;

        // updateSummary(priceSummary);
        if (addToCartModel.status == 'sucesss') {
          // debugPrint("  if (addToCartModel.status == 'sucesss') {");
          // debugPrint("${addToCartModel.cart!.cartItem![0].cartItemId ?? 0}");

          setCartIDForOrder(addToCartModel.cart!.cartItem![0].cartItemId ?? 0);
        }

        return jsonData; //addToCartModel.status == 'sucesss' ? true : false;
      } else {
        return jsonData;
      }
    } finally {}
  }

  //          *********************** REMOVE FROM CART API ***************************************************

  Future<dynamic> removeFromCartAPI({
    required int customerId,
    required int productId,
    int? cartId,
    String remove = "false",
    required String accessToken,
  }) async {
    // debugPrint("********************REMOVE FROM CART API******************** ");
    // debugPrint("product id is ${productId.toString()}");
    final Map<String, dynamic> apiBodyData = {
      'cart_item_id': productId,
      // 'remove': remove,
      // 'action': "update_quantity",
      // 'quantity': 1,
      'action': "remove_item",
      // 'action': "clear_cart",
      'customer_id': "1"
    };
    // debugPrint("productId $productId");
    final url = Uri.parse(APPUrl
        .removeFromCartUrl); // Update this to the correct endpoint for removing items
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);
        await fetchCartDataFromApi(
          customerId: customerId,
          accessToken: accessToken,
          cartId: cartId,
        );
        // customerId: customerId, accessToken: accessToken);
        // debugPrint(addToCartModel.status);
        if (addToCartModel.status == 'success') {
          // debugPrint("  if (addToCartModel.status == 'success') {");
          // debugPrint("${addToCartModel.cart!.cartItem![0].cartItemId ?? 0}");

          // setCartIDForOrder(addToCartModel.cart!.cartItem![0].cartItemId ?? 0);
        }

        // debugPrint("Removed from cart successfully");

        return jsonData; // Return response data or success status
      } else {
        return false;
      }
    } finally {}
  }

  //          *********************** REMOVE FROM CART API ***************************************************

  Future<dynamic> clearCartAPI({
    required int customerId,
    required int productId,
    String remove = "false",
    required String accessToken,
  }) async {
    // debugPrint("********************REMOVE FROM CART API******************** ");
    // debugPrint("product id is ${productId.toString()}");
    final Map<String, dynamic> apiBodyData = {
      'cart_item_id': productId,
      // 'remove': remove,
      // 'action': "update_quantity",
      // 'quantity': 1,
      // 'action': "remove_item",
      'action': "clear_cart",
      'customer_id': "1"
    };
    // debugPrint("productId $productId");
    final url = Uri.parse(APPUrl
        .removeFromCartUrl); // Update this to the correct endpoint for removing items
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);
        await fetchCartDataFromApi(
            customerId: customerId, accessToken: accessToken);
        // customerId: customerId, accessToken: accessToken);
        // debugPrint(addToCartModel.status);
        if (addToCartModel.status == 'success') {
          // debugPrint("  if (addToCartModel.status == 'success') {");
          // debugPrint("${addToCartModel.cart!.cartItem![0].cartItemId ?? 0}");

          // setCartIDForOrder(addToCartModel.cart!.cartItem![0].cartItemId ?? 0);
        }

        // debugPrint("Cart cleared successfully");

        return jsonData; // Return response data or success status
      } else {
        return false;
      }
    } finally {}
  }

  //          *********************** Decrement Cart Item Quantity API ***************************************************

  Future<dynamic> decrementCartItemQuantityAPI({
    required int customerId,
    int? productId,
    int? cartId,
    String remove = "false",
    required String accessToken,
    required num quantity,
  }) async {
    // debugPrint("********************REMOVE FROM CART API******************** ");
    debugPrint("product id is ${productId.toString()}");
    // debugPrint("product id is ${quantity.toString()}");
    // debugPrint("product id is ${quantity.toString()}");
    final Map<String, dynamic> apiBodyData = {
      if (productId != null) 'cart_item_id': productId,
      if (cartId != null) 'cart_id': cartId,
      // 'remove': remove,
      'action': "update_quantity",
      'quantity': quantity,
      // 'action': "remove_item",
      // 'action': "clear_cart",
      'customer_id': "1"
    };
    debugPrint("apiBodyData $apiBodyData");
    final url = Uri.parse(APPUrl
        .removeFromCartUrl); // Update this to the correct endpoint for removing items
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);
        await fetchCartDataFromApi(
            customerId: customerId, accessToken: accessToken, cartId: cartId);
        // customerId: customerId, accessToken: accessToken);
        // debugPrint(addToCartModel.status);
        if (addToCartModel.status == 'success') {
          // debugPrint("  if (addToCartModel.status == 'success') {");
          // debugPrint("${addToCartModel.cart!.cartItem![0].cartItemId ?? 0}");

          setCartIDForOrder(addToCartModel.cart!.cartItem![0].cartItemId ?? 0);
        }

        // debugPrint("Removed from cart successfully");

        return jsonData; // Return response data or success status
      } else {
        return false;
      }
    } finally {}
  }

  //          *********************** Change Cart Item Price API ***************************************************

  Future<dynamic> updateCartItemPrice({
    required int cartItemId,
    int? cartId,
    required String accessToken,
    required String unitPrice,
    int? customerId,
  }) async {
    // debugPrint("***********Change Cart Item Price API************** ");
    // debugPrint("cartItem id is ${cartItemId.toString()}");
    // debugPrint("unitPrice is ${unitPrice.toString()}");
    final Map<String, dynamic> apiBodyData = {
      'cart_item_id': cartItemId,
      'unit_price': unitPrice,
    };
    final url = Uri.parse(APPUrl.updateCartItemPriceUrl);
    try {
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      // debugPrint('inside ${response.body.toString()}');
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);
        await fetchCartDataFromApi(
            customerId: customerId!, accessToken: accessToken, cartId: cartId);
        // customerId: customerId, accessToken: accessToken);
        // debugPrint(addToCartModel.status);
        if (addToCartModel.status == 'success') {
          // debugPrint("  if (addToCartModel.status == 'success') {");
          // debugPrint("${addToCartModel.cart!.cartItem![0].cartItemId ?? 0}");

          // setCartIDForOrder(addToCartModel.cart!.cartItem![0].cartItemId ?? 0);
        }

        // debugPrint("Removed from cart successfully");

        return jsonData; // Return response data or success status
      } else {
        return false;
      }
    } finally {}
  }

  //          *********************** ADD TO ORDER API ***************************************************

  Future<dynamic> addToOrderAPI({
    List<Map<String, dynamic>>? items,
    required int cartIds,
    required String accessToken,
    String? orderId,
    int? customerId,
    String? customerPhone,
    String? phone,
    required String transactionId,
    required String totalPrice,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
    String? couponId,
    String? comment,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
  }) async {
    debugPrint("📤 ADD TO ORDER API - Starting request");
    debugPrint("📦 Order items count: ${items?.length ?? 0}");
    debugPrint("🛒 Cart ID: $cartIds");
    debugPrint("👤 Customer ID: $customerId");
    debugPrint("📱 Customer Phone: $customerPhone");
    debugPrint("💰 Payment Method: $paymentMethod");
    debugPrint("💰 Payment Methods: $paymentMethods");
    debugPrint("💰 Paid Methods: $paidMethods");
    debugPrint("💵 Total Price: $totalPrice");
    debugPrint("💳 Transaction ID: $transactionId");
    debugPrint("💸 Paid Amount: $paidAmount");
    debugPrint("🔄 Balance Amount: $balanceAmount");
    debugPrint("🎫 Coupon ID: $couponId");
    debugPrint("💬 Comment: $comment");
    debugPrint("🚚 Delivery Method ID: $deliveryMethodId");
    debugPrint("🚗 Car Number: $carNumber");
    debugPrint("📊 Status: $status");
    
    DateTime now = DateTime.now();

    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    // debugPrint("$cartIds CadtId Inside ADD TO CART API $formattedDate");

    // debugPrint("Customer ID $customerId");
    // debugPrint("Phone $phone");
    // debugPrint("Phone $accessToken");

    Map<String, dynamic> apiBodyData = {};

    // Use multi-payment format if available, otherwise fall back to single payment
    if (paymentMethods != null && paidMethods != null && paidMethods.isNotEmpty) {
      apiBodyData = {
        "items": items,
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_methods": paymentMethods,
        "paid_methods": paidMethods,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
        if (status != null) "status": status,
      };
    } else {
      // Fallback to single payment method format
      apiBodyData = {
        "items": items,
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_method": paymentMethod,
        "paid_amount": paidAmount,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
        if (status != null) "status": status,
      };
    }

    debugPrint("📝 API Request Body: ${json.encode(apiBodyData)}");

    final url = Uri.parse(APPUrl.addToOrderUrl);
    debugPrint("🌐 API URL: ${url.toString()}");

    try {
      debugPrint("🔄 Sending POST request to server...");
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      debugPrint('📥 Response status code: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Order created successfully (status ${response.statusCode})');

        final jsonData = json.decode(response.body);
        debugPrint('📊 Order ID: ${jsonData["order_id"]}');
        debugPrint('📊 Order Number: ${jsonData["order_number"]}');
        
        getData();
        return jsonData;
      } else {
        debugPrint('❌ Failed to create order (status ${response.statusCode})');
        return {"status": "failure", "message": "Failed to add order"};
      }
    } catch (e) {
      debugPrint('❌ Exception during API call: $e');
      return {"status": "error", "message": e.toString()};
    } finally {
      debugPrint("🏁 ADD TO ORDER API - Request completed");
    }
  }

  // Update Order Api

  Future<dynamic> updateOrderAPI({
    required String accessToken,
    required String? orderId,
    int? customerId,
    String? customerPhone,
    String? phone,
    required String transactionId,
    required String totalPrice,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
    String? couponId,
    String? comment,
    String? deliveryMethodId,
    String? carNumber,
    String? status,
  }) async {
    debugPrint("📤 UPDATE ORDER API - Starting request");
    DateTime now = DateTime.now();

    String formattedDate = DateFormat('yyyy-MM-dd').format(now);

    Map<String, dynamic> apiBodyData = {};

    // Use multi-payment format if available, otherwise fall back to single payment
    if (paymentMethods != null && paidMethods != null && paidMethods.isNotEmpty) {
      apiBodyData = {
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_methods": paymentMethods,
        "paid_methods": paidMethods,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
        if (status != null) "status": status,
      };
    } else {
      // Fallback to single payment method format
      apiBodyData = {
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_method": paymentMethod,
        "paid_amount": paidAmount,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
        if (status != null) "status": status,
      };
    }

    debugPrint("📝 API Request Body: ${json.encode(apiBodyData)}");

    final url = Uri.parse(APPUrl.updateOrderUrl);
    debugPrint("🌐 API URL: ${url.toString()}");

    try {
      debugPrint("🔄 Sending POST request to server...");
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      debugPrint('📥 Response status code: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Order updated successfully (status ${response.statusCode})');

        final jsonData = json.decode(response.body);
        getData();
        return jsonData;
      } else {
        debugPrint('❌ Failed to update order (status ${response.statusCode})');
        return {"status": "failure", "message": "Failed to update order"};
      }
    } catch (e) {
      debugPrint('❌ Exception during API call: $e');
      return {"status": "error", "message": e.toString()};
    } finally {
      debugPrint("🏁 UPDATE ORDER API - Request completed");
    }
  }

  Future<dynamic> addToOrderConfirmAPI({
    required int cartIds,
    required String accessToken,
    int? customerId,
    String? orderId,
    String? customerPhone,
    String? phone,
    required String transactionId,
    required String totalPrice,
    String? paymentMethod,
    String? paidAmount,
    String? balanceAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
    String? couponId,
    String? comment,
    String? deliveryMethodId,
    String? carNumber,
  }) async {
    debugPrint("📤 CONFIRM ORDER API - Starting request");
    DateTime now = DateTime.now();

    String formattedDate = DateFormat('yyyy-MM-dd').format(now);

    Map<String, dynamic> apiBodyData = {};

    // Use multi-payment format if available, otherwise fall back to single payment
    if (paymentMethods != null && paidMethods != null && paidMethods.isNotEmpty) {
      apiBodyData = {
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_methods": paymentMethods,
        "paid_methods": paidMethods,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        "cart_id": cartIds,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
      };
    } else {
      // Fallback to single payment method format
      apiBodyData = {
        "phone": customerPhone,
        "transaction_number": transactionId,
        "payment_method": paymentMethod,
        "paid_amount": paidAmount,
        "source_type": "executive",
        "balance": balanceAmount,
        "coupon_id": couponId,
        if (orderId != null) "order_id": orderId,
        "cart_id": cartIds,
        if (comment != null) "comment": comment,
        if (deliveryMethodId != null) "delivery_method_id": deliveryMethodId,
        if (carNumber != null) "car_number": carNumber,
      };
    }

    debugPrint("📝 API Request Body: ${json.encode(apiBodyData)}");

    final url = Uri.parse(APPUrl.addToOrderConfirmUrl);
    debugPrint("🌐 API URL: ${url.toString()}");

    try {
      debugPrint("🔄 Sending POST request to server...");
      final response =
          await http.post(url, body: json.encode(apiBodyData), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      
      debugPrint('📥 Response status code: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        debugPrint('✅ Order confirmed successfully');
        final jsonData = json.decode(response.body);
        getData();
        return jsonData;
      } else {
        debugPrint('❌ Failed to confirm order (status ${response.statusCode})');
        return {"status": "failure", "message": "Failed to confirm order"};
      }
    } catch (e) {
      debugPrint('❌ Exception during API call: $e');
      return {"status": "error", "message": e.toString()};
    } finally {
      debugPrint("🏁 CONFIRM ORDER API - Request completed");
    }
  }

  Future<dynamic> applyCoupon({
    required double totalAmount,
    required String couponCode,
    required String accessToken,
  }) async {
    // debugPrint("********************APPLY COUPON API******************** ");

    final url = Uri.parse(APPUrl.applyCoupon).replace(queryParameters: {
      'price': totalAmount.toString(),
      'coupon_code': couponCode,
    });

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      // debugPrint('Response status: ${response.statusCode}');
      // debugPrint('Response body: ${response.body}');

      final jsonData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': jsonData['message'],
          'data': jsonData['data'],
        };
      } else {
        return {
          'success': false,
          'message': jsonData['message'],
          'data': null,
        };
      }
    } catch (e) {
      // debugPrint('Error applying coupon: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
        'data': null,
      };
    }
  }
}
