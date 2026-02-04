import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import '../providers/grid_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_model.dart';
import '../models/get_product.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class HorizontalProductView extends StatefulWidget {
  final int? cartId;
  const HorizontalProductView({super.key, this.cartId});

  @override
  State<HorizontalProductView> createState() => _HorizontalProductViewState();
}

class _HorizontalProductViewState extends State<HorizontalProductView> {
  List<GetProduct> products = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  Future<void> _fetchProducts() async {
    final gridProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    await gridProvider.listQuickAccessProducts();
    setState(() {
      products = gridProvider.quickAccessProductList ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container();
    }
    return SizedBox(
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(
              products.length,
              (index) {
                final product = products[index];
                return Container(
                  width: 86, // Fixed width
                  margin: const EdgeInsets.only(left: 3, right: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        height: 40,
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            product.attachment?.isNotEmpty == true
                                ? product.attachment![0].filePath ??
                                    'https://via.placeholder.com/150'
                                : 'https://via.placeholder.com/150',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey[100],
                              child: const Icon(Icons.image_not_supported,
                                  color: Colors.grey, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 100,
                        height: 15,
                        alignment: Alignment.center,
                        child: Text(
                          product.productName ?? 'Product Name',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Consumer<AppSettingsProvider>(
                        builder: (context, appSettingsProvider, _) {
                          final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
                          final raw = product.price?.price; // can be String or num
                          String price;
                          if (raw is num) {
                            price = raw.toStringAsFixed(2);
                          } else if (raw is String) {
                            final parsed = double.tryParse(raw);
                            price = parsed != null ? parsed.toStringAsFixed(2) : raw;
                          } else {
                            price = '0.00';
                          }
                          final unit = product.unit ?? '';
                          return Text(
                            '$currency $price/$unit',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 15,
                        width: 60,
                        child: CustomRoundButton(
                          fct: () {
                            final authModel =
                                Provider.of<AuthModel>(context, listen: false);
                            final cartProvider = Provider.of<CartProvider>(
                                context,
                                listen: false);

                            cartProvider
                                .addToCartAPI(
                              customerId: authModel.userId ?? 0,
                              productId: product.productId ?? 0,
                              quantity: 1,
                              accessToken: authModel.token ?? "",
                              cartId: widget.cartId,
                            )
                                .then((value) {
                              AddToCartModel addToCartModel =
                                  AddToCartModel.fromJson(value);
                              if (value["status"] == "success") {
                                showScaffold(
                                  context: context,
                                  message: "Added to Cart",
                                );
                              } else {
                                showScaffoldError(
                                  context: context,
                                  message: addToCartModel.message ??
                                      "Error Occured ! Try Again",
                                );
                              }
                            });
                          },
                          title: "Add",
                          fontSize: 9,
                          height: 25,
                          width: 40,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
