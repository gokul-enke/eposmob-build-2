import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/models/add_to_cart.dart';

import '../resources/app_url.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    // debugPrint("ADD TO CART  API ");
    // debugPrint("customerId $customerId ");
    final Map<String, dynamic> apiBodyData = {
      'product_id': productId,
      'app_type': "api",
      'quantity': quantity,
      // 'customer_id': customerId,
    };
    final url = Uri.parse(APPUrl.addToCartUrl);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url,
          body: json.encode(apiBodyData),
          headers: {'Content-Type': 'application/json', 'api_key': apiKey});
      // debugPrint('inside ${response.statusCode}');
      // debugPrint(json.decode(response.body).toString());
      // debugPrint("response${response.toString()}");
      if (response.statusCode == 200) {
        // debugPrint('inside');

        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        AddToCartModel addToCartModel = AddToCartModel.fromJson(jsonData);

        String status = addToCartModel.status ?? "";

        // debugPrint('ADD TO CART  API');
        for (var v in addToCartModel.cart!.cartItem ?? []) {
          // debugPrint(v.cartItemId);
        }
        return status == "success" ? true : false;
      } else {
        return false;
      }
    } finally {}
  }
}
