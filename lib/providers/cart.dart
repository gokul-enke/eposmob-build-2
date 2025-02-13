import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pos_machine/models/add_to_cart.dart';

import '../resources/app_url.dart';
import 'package:http/http.dart' as http;

class Cart with ChangeNotifier {
  int cartItems = 0;
  int get getCartItems {
    return cartItems;
  }

  setCartItem(int value) {
    cartItems = value;
    notifyListeners();
  }
  //          *********************** ADD TO CART  API ***************************************************

  Future<bool> addToCart(BuildContext context,
      {required int productId,
      required int quantity,
      required int customerId}) async {
    // debugPrintdebugPrint("ADD TO CART  API ");
    // debugPrintdebugPrint("customerId $customerId ");
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'app_type': "api",
      'quantity': quantity,
      // 'customer_id': customerId,
    };
    final url = Uri.parse(APPUrl.addToCartUrl);
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json'});
      // debugPrintdebugPrint('inside ${response.statusCode}');
      // debugPrintdebugPrint(json.decode(response.body).toString());
      // debugPrintdebugPrint("response${response.toString()}");
      if (response.statusCode == 200) {
        // debugPrintdebugPrint('inside');

        // debugPrintdebugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);

        String status = addToCartModel.status ?? "";

        // debugPrintdebugPrint('ADD TO CART  API');
        for (var v in addToCartModel.cart!.cartItem ?? []) {
          // debugPrintdebugPrint(v.cartItemId);
        }
        return status == "success" ? true : false;
      } else {
        return false;
      }
    } finally {}
  }
}
