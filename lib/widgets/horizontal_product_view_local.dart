import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import '../providers/grid_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_model.dart';
import '../models/get_product.dart';
import 'package:provider/provider.dart';

class HorizontalProductViewLocal extends StatefulWidget {
  final int? cartId;
  const HorizontalProductViewLocal({super.key, this.cartId});

  @override
  State<HorizontalProductViewLocal> createState() =>
      _HorizontalProductViewLocalState();
}

class _HorizontalProductViewLocalState
    extends State<HorizontalProductViewLocal> {
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
    products = gridProvider.quickAccessProductList ?? [];
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
                      Text(
                        '${product.currency ?? ''} ${product.price?.price ?? ''}/${product.unit ?? ''}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 15,
                        width: 60,
                        child: CustomRoundButton(
                          fct: () {
                            final authModel =
                                Provider.of<AuthModel>(context, listen: false);
                            final localProvider =
                                Provider.of<LocalProductProvider>(context,
                                    listen: false);

                            localProvider.addToCart(
                              product: product,
                            );
                            showScaffold(
                              context: context,
                              message: 'Added To Cart',
                            );
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
