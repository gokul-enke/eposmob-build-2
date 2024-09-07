import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';

class ProductCardList extends StatelessWidget {
  final String? imageLink;
  final double? height;
  final String title;
  final String currency;
  final int price;
  final String? totalPrice;
  final int count;
  final int productId;
  final VoidCallback removeFromCart;
  final VoidCallback addToCart;

  const ProductCardList({
    Key? key,
    this.imageLink,
    this.height,
    required this.title,
    required this.currency,
    required this.price,
    this.totalPrice,
    required this.count,
    required this.productId,
    required this.removeFromCart,
    required this.addToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BuildBoxShadowContainer(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      circleRadius: 20,
      color: Colors.white,
      child: SizedBox(
        height: height ?? 100,
        child: Row(
          children: [
            if (imageLink != null)
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageLink!, fit: BoxFit.cover),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Highest priority
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currency ${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14, // Medium priority
                      ),
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
                          removeFromCart();
                        },
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14, // Medium priority
                        ),
                      ), // Display the count of items here
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: ColorManager.kPrimaryColor),
                        onPressed: () {
                          addToCart();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if(totalPrice != null)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency $totalPrice',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12, // Lower priority
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
