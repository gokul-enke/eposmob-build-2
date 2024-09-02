import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/models/add_to_cart.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({Key? key}) : super(key: key);

  @override
  _KioskScreenState createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).listAllCategory();
      Provider.of<GridSelectionProvider>(context, listen: false)
          .listAllProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Place Your Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: FontSize.s16),
        ),
      ),
      body: SizedBox(
        height: size.height,
        child: Column(
          children: [
            _buildCategoryList(),
            Expanded(
              child: _buildMenuItems(),
            ),
            _buildCheckoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        if (categoryProvider.category!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categoryProvider.category!.length,
            itemBuilder: (context, index) {
              final category = categoryProvider.category![index];
              final isSelected =
                  categoryProvider.selectedCategoryIndex == index;
              return _categoryButton(category.categoryName ?? 'Unknown',
                  isSelected, index, categoryProvider);
            },
          ),
        );
      },
    );
  }

  Widget _categoryButton(String title, bool isSelected, int index,
      CategoryProvider categoryProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () {
          categoryProvider.setSelectCategoryIndex(index);
          categoryProvider.updateCategoryPageFilteredCategories(
              categoryProvider.filteredcategoryList ?? []);
        },
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
          decoration: BoxDecoration(
            color: isSelected ? ColorManager.kPrimaryColor : Colors.transparent,
            border: Border.all(color: ColorManager.kPrimaryColor),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 10.0,
                color: isSelected ? Colors.white : ColorManager.kPrimaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Consumer<GridSelectionProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.productList!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: productProvider.productList!.length,
          itemBuilder: (context, index) {
            final product = productProvider.productList![index];
            return _menuItem(
              product.productName ?? 'Unknown',
              product.description ?? 'This is description',
              product.price!.price ?? 0.0,
              product.productId ?? 0,
              product.currency ?? 'Rs',
            );
          },
        );
      },
    );
  }

  Widget _menuItem(String title, String description, double price,
      int productId, String currency) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        int count = 0;
        // int count = cartProvider.getItemCount(productId);

        return Container(
          height: 100,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Image.network('https://via.placeholder.com/150',
                    fit: BoxFit.cover),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(fontSize: 12)),
                      Text(
                        '$currency ${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Text('$currency ${price.toStringAsFixed(2)}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: ColorManager.kPrimaryColor),
                          onPressed: () {
                            _removeFromCart(context, productId);
                          },
                        ),
                        Text('$count'),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: ColorManager.kPrimaryColor),
                          onPressed: () {
                            _addToCart(context, productId);
                          },
                        ),
                      ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addToCartModel.message ?? "Added To Cart")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(addToCartModel.message ?? "Error Occurred! Try Again!")),
        );
      }
    });
  }

  void _removeFromCart(BuildContext context, int productId) {
    final customerId = Provider.of<AuthModel>(context, listen: false).userId;
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;

    Provider.of<CartProvider>(context, listen: false)
        .removeFromCartAPI(
      customerId: customerId ?? 1,
      productId: productId,
      accessToken: accessToken ?? "",
      remove: "true",
    )
        .then((value) {
      AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
      if (value["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(addToCartModel.message ?? "Added To Cart")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(addToCartModel.message ?? "Error Occurred! Try Again!")),
        );
      }
    });
  }

  Widget _buildCheckoutButton() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        double total = 5000;
        // double total = cartProvider.getTotalAmount();
        return Container(
          padding: const EdgeInsets.all(16),
          child: CustomRoundButton(
            fontSize: FontSize.s14,
            height: MediaQuery.of(context).size.height * .07,
            width: MediaQuery.of(context).size.width * .8,
            fct: () {},
            title: 'CHECKOUT INR ${total.toStringAsFixed(2)}',
          ),
        );
      },
    );
  }
}
