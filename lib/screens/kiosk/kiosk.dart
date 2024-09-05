import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/widgets/category_list_item_widget.dart';
import 'package:pos_machine/widgets/product_card_kiosk.dart';
import 'package:pos_machine/widgets/showEmptyMessege.dart';
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
  bool _isListView = true;

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
        centerTitle: true,
        title: const Text(
          'Place Your Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: FontSize.s16),
        ),
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _isListView = !_isListView;
              });
            },
          ),
        ],
      ),
      body: SizedBox(
        height: size.height,
        child: Column(
          children: [
            _buildCategoryList(),
            Expanded(
              child: _isListView ? _buildListView() : _buildGridView(),
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
        return SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
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
          ),
        );
      },
    );
  }

  Widget _categoryButton(String title, bool isSelected, int index,
      CategoryProvider categoryProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkWell(
        onTap: () {
          categoryProvider.setSelectCategoryIndex(index);
          categoryProvider.updateCategoryPageFilteredCategories(
              categoryProvider.filteredcategoryList ?? []);
          final productProvider =
              Provider.of<GridSelectionProvider>(context, listen: false);
          productProvider.listAllProducts(
              filterCategory:
                  categoryProvider.category![index].categoryId.toString());
        },
        borderRadius: BorderRadius.circular(20.0),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? ColorManager.kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? ColorManager.kPrimaryColor.withOpacity(0.4)
                    : ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : ColorManager.kPrimaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return Consumer<GridSelectionProvider>(
      builder: (context, productProvider, child) {
        debugPrint("Products loaded ${productProvider.productList.toString()}");
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.productList!.isEmpty) {
          return showEmptyMessege(
            message: 'No products available',
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: productProvider.productList!.length,
            itemBuilder: (context, index) {
              final product = productProvider.productList![index];
              return _menuItem(
                product.productName ?? 'Name',
                product.description ?? 'This is description',
                product.attachment?.isNotEmpty == true
                    ? product.attachment![0].filePath ??
                        'https://via.placeholder.com/150'
                    : 'https://via.placeholder.com/150',
                product.price?.price ?? 0,
                product.productId ?? 0,
                product.currency ?? 'INR',
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return Consumer<GridSelectionProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.productList!.isEmpty) {
          return showEmptyMessege(
            message: 'No products available',
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200, // Maximum width for each item
              childAspectRatio: 3 / 3, // Updated to match 180w x 150h
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: productProvider.productList!.length,
            itemBuilder: (context, index) {
              int? customerId =
                  Provider.of<AuthModel>(context, listen: false).userId;

              String? file = "";
              debugPrint("file-$index$file");
              final product = productProvider.productList![index];
              for (var v in product.attachment ?? []) {
                debugPrint(v.filePath);

                if (v.isPrimary == 1) {
                  debugPrint("file$file");
                  file = v.filePath;
                } else {
                  debugPrint("fileShanidha$file");
                }
              }
              final selectionProvider = productProvider;
              return ProductCardSquare(
                file: file ?? "",
                attachment:
                    selectionProvider.productList![index].attachment ?? [],
                isSelected: false,
                price: "${selectionProvider.productList![index].price!.price}",
                title: selectionProvider.productList![index].productName ?? '',
                weight: selectionProvider.productList![index].unit ?? '',
                customerId: customerId ?? 1,
                productId: selectionProvider.productList![index].productId ?? 1,
                currency: selectionProvider.productList![index].currency ?? '',
                fileType: '',
                removeFromCart: _removeFromCart,
                addToCart: _addToCart,
                count: 0,
              );
            },
          ),
        );
      },
    );
  }

  Widget _menuItem(String title, String description, String imageLink,
      int price, int productId, String currency) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        int count = 0;
        // int count = cartProvider.getItemCount(productId);
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
          child: Container(
            padding: const EdgeInsets.all(4),
            height: 100,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageLink, fit: BoxFit.cover),
                  ),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
