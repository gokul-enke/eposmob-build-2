import 'package:flutter/material.dart';
import '../models/get_product.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class ProductCardSquare extends StatelessWidget {
  final String? imageUrlPath;
  final String price;
  final String title;
  final String weight;
  final bool isSelected;
  final List<Attachment>? attachment;
  final int customerId;
  final String currency;
  final int productId;
  final String fileType;
  final String file;
  final Attachment? attachmentImage;
  final Function(BuildContext, int) removeFromCart;
  final Function(BuildContext, int) addToCart;
  final int count;

  const ProductCardSquare({
    super.key,
    this.imageUrlPath,
    required this.price,
    required this.title,
    required this.weight,
    required this.isSelected,
    required this.customerId,
    required this.productId,
    required this.currency,
    required this.attachment,
    this.attachmentImage,
    required this.fileType,
    required this.file,
    required this.removeFromCart,
    required this.addToCart,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    // String? file1;
    // attachment!.map((e) {
    //   if (e.isPrimary == 1) {
    //     file = e.filePath;
    //   } else {
    //     file = "";
    //   }
    // });

    return Container(
      height: 100,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10, top: 10),
            alignment: Alignment.center,
            height: 100,

            child: file.isEmpty
                ? Container()
                : Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white),
                    child: Image.network(
                      file,
                      fit: BoxFit.cover,
                    ),
                  ), //
            //  Image.network(
            //   fileType,
            // ),
            // Image.asset(imageUrlPath),
          ),
          SizedBox(
            height: 15,
            child: Text(
              '$title\n ',
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s11, 0.13, Colors.black),
            ),
          ),
          Text(
            '$currency $price/ $weight ',
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s10,
                0.12, Colors.black.withOpacity(0.5)),
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
                        removeFromCart(context, productId);
                      },
                    ),
                    Text('$count'),
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: ColorManager.kPrimaryColor),
                      onPressed: () {
                        addToCart(context, productId);
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
  }
}
