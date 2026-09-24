import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:provider/provider.dart';

import '../components/build_round_button.dart';
import '../models/add_to_cart.dart';
import '../models/get_product.dart';
import '../providers/auth_model.dart';
import '../providers/cart_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

class CategoryListItemWidget extends StatelessWidget {
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

  const CategoryListItemWidget(
      {super.key,
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
      required this.file});

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

    return SizedBox(
      height: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            height: 90,
            width: 100,
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
            child: file.isEmpty
                ? Container()
                : Image.network(
                    file,
                    fit: BoxFit.cover,
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
          // RichText(
          //   textAlign: TextAlign.center,
          //   text: TextSpan(
          //     text: '$title\n ',
          //     style: buildCustomStyle(
          //         FontWeightManager.medium, FontSize.s11, 0.13, Colors.black),
          //     children: <TextSpan>[
          //       TextSpan(
          //         text: '$currency $price/ $weight ',
          //         style: buildCustomStyle(FontWeightManager.medium,
          //             FontSize.s10, 0.12, Colors.black.withOpacity(0.5)),
          //       ),
          //       // TextSpan(
          //       //   text: 'Rs $price',
          //       //   style: buildCustomStyle(FontWeightManager.semiBold,
          //       //       FontSize.s12, 0.12, Colors.black),
          //       // ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 4),
          CustomRoundButton(
            title: 'billing.add_to_cart'.tr,
            fct: () {
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;
              // debugPrint("accessToken From AuthModel $accessToken");
              Provider.of<CartProvider>(context, listen: false)
                  .addToCartAPI(
                      customerId: customerId,
                      productId: productId,
                      quantity: 1,
                      accessToken: accessToken ?? "")
                  .then((value) {
                AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
                if (value["status"] == "success") {
                  showScaffold(
                    context: context,
                    message: addToCartModel.message ??
                        'billing.added_to_cart'.tr,
                  );
                  //  'Order Placed Successfully',
                } else {
                  showScaffoldError(
                    context: context,
                    message:
                        addToCartModel.message ??
                            'general.error_occurred_try_again'.tr,
                  );
                }
              });
            },
            fontSize: FontSize.s10,
            height: 25,
            width: 100,
          ),
        ],
      ),
    );
  }
}

class SelectedCategoryListItemWidget extends StatelessWidget {
  final String imageUrlPath;
  final String price;
  final String title;
  final String weight;
  final bool isSelected;
  final int customerId;
  final int productId;
  final String currency;
  final String file;
  final Attachment? attachmentImage;
  final List<Attachment>? attachment;
  const SelectedCategoryListItemWidget(
      {super.key,
      required this.imageUrlPath,
      required this.price,
      required this.title,
      required this.weight,
      required this.isSelected,
      required this.customerId,
      required this.productId,
      required this.currency,
      required this.attachment,
      this.attachmentImage,
      required this.file});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                height: 90,
                width: 100,
                decoration: BoxDecoration(
                    border:
                        Border.all(color: ColorManager.kPrimaryColor, width: 3),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 6,
                        offset: Offset(1, 1),
                      ),
                    ],
                    color: Colors.white),
                child: file.isEmpty
                    ? Container()
                    : Image.network(
                        file,
                        fit: BoxFit.cover,
                      ), // Image.asset(imageUrlPath),
              ),
              Container(
                height: 20,
                width: 30,
                decoration: const BoxDecoration(
                  color: ColorManager.kPrimaryColor,
                  borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(10),
                      topLeft: Radius.circular(8)),
                ),
                child: const Icon(
                  Icons.done,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ],
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
          // RichText(
          //   textAlign: TextAlign.center,
          //   text: TextSpan(
          //     text: '$title\n ',
          //     style: buildCustomStyle(
          //         FontWeightManager.medium, FontSize.s11, 0.13, Colors.black),
          //     children: <TextSpan>[
          //       TextSpan(
          //         text: '$currency $price/ $weight ',
          //         style: buildCustomStyle(FontWeightManager.medium,
          //             FontSize.s10, 0.12, Colors.black.withOpacity(0.5)),
          //       ),
          //       // TextSpan(
          //       //   text: 'Rs $price',
          //       //   style: buildCustomStyle(FontWeightManager.semiBold,
          //       //       FontSize.s12, 0.12, Colors.black),
          //       // ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 4),
          CustomRoundButton(
            title: 'billing.add_to_cart'.tr,
            fct: () {
              String? accessToken =
                  Provider.of<AuthModel>(context, listen: false).token;
              // debugPrint("accessToken From AuthModel $accessToken");
              Provider.of<CartProvider>(context, listen: false)
                  .addToCartAPI(
                      customerId: customerId,
                      productId: productId,
                      quantity: 1,
                      accessToken: accessToken ?? "")
                  .then((value) {
                AddToCartModel addToCartModel = AddToCartModel.fromJson(value);
                if (value["status"] == "success") {
                  showScaffold(
                    context: context,
                    message: addToCartModel.message ??
                        'billing.added_to_cart'.tr,
                  );
                  //  'Order Placed Successfully',
                } else {
                  showScaffoldError(
                    context: context,
                    message:
                        addToCartModel.message ??
                            'general.error_occurred_try_again'.tr,
                  );
                  //  'Added To Cart',
                }
              });
            },
            fontSize: FontSize.s10,
            height: 25,
            width: 100,
          ),
        ],
      ),
    );
  }
}
