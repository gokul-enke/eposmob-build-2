import 'package:carousel_slider/carousel_slider.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_category_container.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_product_dummy.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/add_to_cart.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/carousel_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/product.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/widgets/category_list_item_widget.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CategoryListItemNew extends StatefulWidget {
  const CategoryListItemNew({
    super.key,
  });

  @override
  State<CategoryListItemNew> createState() => _CategoryListItemNewState();
}

class _CategoryListItemNewState extends State<CategoryListItemNew> {
  @override
  void initState() {
    super.initState();
    Provider.of<GridSelectionProvider>(context, listen: false)
        .listAllProducts();
  }

  @override
  Widget build(BuildContext context) {
    // final TextEditingController searchTextController =
    //     TextEditingController(text: "");
    Size size = MediaQuery.of(context).size;

    // final categoryProvider =
    //     Provider.of<CategoryProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    // List<GetProduct> p = Provider.of<GridSelectionProvider>(context)
    //     .selectedProductsUpOnCategory;
//  String? accessToken =
//           Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;
    debugPrint("CategoryListItem  customerId  : $customerId");
    // Provider.of<CartProvider>(context, listen: false)
    //     .fetchCartData(customerId: 1);
    // Load products when the widget is built
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await categoryProvider.listAllCategory();
    //   //  categoryProvider.listAllProducts(context, categoryId: 1);
    // });

    debugPrint(size.width.toString());
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Category',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s20,
                  0.30, ColorManager.textColor),
            ),
            const SizedBox(
              height: 10,
            ),
            // TextField(
            //   cursorWidth: 1,
            //   //  controller: searchTextController,
            //   cursorColor: ColorManager.kPrimaryColor,
            //   onChanged: (query) {
            //     debugPrint(query);
            //     final filteredCategories =
            //         categoryProvider.searchCategories(query);

            //     categoryProvider.updateFilteredCategories(filteredCategories);
            //   },
            //   decoration: decoration.copyWith(
            //     prefixIcon: WebsafeSvg.asset(
            //       ImageAssets.categorySearchIcon,
            //       fit: BoxFit.none,
            //     ),
            //     // suffixIcon: WebsafeSvg.asset(
            //     //   ImageAssets.barcodeIcon,
            //     //   fit: BoxFit.none,
            //     // ),
            //     labelStyle: buildCustomStyle(FontWeightManager.regular,
            //         FontSize.s10, 0.10, ColorManager.textColor),
            //     hintText: 'Search category',
            //     hintStyle: buildCustomStyle(FontWeightManager.regular,
            //         FontSize.s10, 0.13, ColorManager.textColor1),
            //   ),
            // ),
            buildColumnWidgetForTextFields(
              onchanged: (query) {
                categoryProvider.listAllCategory(filterName: query);
              },
              size: size,
              hintText: 'Search category',
            ),
            const SizedBox(
              height: 10,
            ),
            SizedBox(
                height: 110,
                child: Consumer<CategoryProvider>(
                    builder: (context, provider, child) {
                  final filteredCategories = provider.categoryList!.isEmpty
                      ? provider.categoryList
                      : provider.categoryList;
                  if (provider.category!.isEmpty) {
                    provider.listAllCategory();

                    return ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: 1, //5,
                        itemBuilder: (context, index) {
                          return const BuildCategoryContainerDummy();
                        });
                    //const Center(child: CircularProgressIndicator());
                  } else {
                    return ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredCategories!
                            .length, //provider.category!.length,
                        itemBuilder: (context, index) {
                          final categorys = provider.category![index];
                          // final categorys = filteredCategories[index];
                          // final categoryProviders =
                          //     Provider.of<GridSelectionProvider>(context,
                          //         listen: true);
                          final isSelected =
                              index == provider.selectedCategoryIndex;

                          // debugPrint(
                          //     "Inside category ListItem Widgetcategorys.categorySlug");
                          // debugPrint("categorys.categoryImage");
                          // debugPrint(categorys.categoryIcon);
                          // debugPrint("${provider.category!.length}");
                          return GestureDetector(
                            onTap: () {
                              // provider.selectCategory(
                              //     index,
                              //     provider.category![index].categoryName ?? "",
                              //     index == 0
                              //         ? productProvider.productList!.length
                              //         : provider
                              //                 .category![index].productsCount ??
                              //             0);
                              // productProvider.updateCategory(
                              //     provider.category![index].categoryId ?? 0);

                              // productProvider.selectedProductsUpOnCategory;
                              // productProvider.selectedProducts(index == 0
                              //     ? 0
                              //     : provider.category![index].categoryId ?? 0);
                              //  productProvider.selectedProductsUpOnCategory;
                              productProvider.listAllProducts(
                                  filterCategory: provider
                                      .category![index].categoryId
                                      .toString());
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected
                                        ? ColorManager.kPrimaryColor
                                        : ColorManager.textColor1,
                                    radius: 40,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          40), // Half of the height/width to make it a circle
                                      child: Image.network(
                                        provider.category![index]
                                                .categoryIcon ??
                                            'https://epos-bucket.s3.ap-southeast-1.amazonaws.com/images/Owtpjeb18CalthcsGsfnWlBIZxb137QI5TIneBdd.jpg',
                                        fit: BoxFit.cover,
                                        height: 80,
                                        width: 80,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    categorys.categoryName ?? 'All',
                                    style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s11,
                                        0.17,
                                        Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          );
                        });
                  }
                })),
            // const SizedBox(
            //   width: 20,
            // ),
            const Divider(
              color: ColorManager.boxShadowColor,
            ),
            const SizedBox(
              height: 10,
            ),
            // TextField(
            //   cursorWidth: 1,
            //   //  controller: searchTextController,
            //   cursorColor: ColorManager.kPrimaryColor,
            //   onChanged: (query) {
            //     debugPrint(query);
            //     final filteredProducts = productProvider.searchProducts(query);

            //     productProvider.updateFilteredProducts(filteredProducts);
            //   },
            //   decoration: decoration.copyWith(
            //     prefixIcon: WebsafeSvg.asset(
            //       ImageAssets.categorySearchIcon,
            //       fit: BoxFit.none,
            //     ),
            //     // suffixIcon: WebsafeSvg.asset(
            //     //   ImageAssets.barcodeIcon,
            //     //   fit: BoxFit.none,
            //     // ),
            //     labelStyle: buildCustomStyle(FontWeightManager.regular,
            //         FontSize.s10, 0.10, ColorManager.textColor),
            //     hintText: 'Search Product',
            //     hintStyle: buildCustomStyle(FontWeightManager.regular,
            //         FontSize.s10, 0.13, ColorManager.textColor1),
            //   ),
            // ),
            buildColumnWidgetForTextFields(
              onchanged: (query) {
                productProvider.listAllProducts(filterName: query);
              },
              size: size,
              hintText: 'Search Product',
            ),
            const SizedBox(
              height: 10,
            ),
            Consumer<GridSelectionProvider>(
                builder: (context, selectionProvider, child) {
              return DragSelectGridView(
                  // gridController: gridController,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveWidget.isDesktop(context)
                          ? MediaQuery.of(context).orientation ==
                                      Orientation.portrait ||
                                  size.width < 930
                              ? 3
                              : size.width < 1200
                                  ? 3
                                  : 3
                          : MediaQuery.of(context).orientation ==
                                      Orientation.portrait ||
                                  size.width < 930
                              ? 3
                              : 3,
                      childAspectRatio: MediaQuery.of(context).orientation ==
                              Orientation.portrait
                          ? 0.5
                          : size.width < 1200
                              ? 0.6
                              : 0.7,
                      crossAxisSpacing: 1.0,
                      mainAxisSpacing: 1.0),
                  itemCount: selectionProvider.productList!
                      .length, //selectionProvider.getProducts!.length,
                  itemBuilder: (ctx, index, isSelected) {
                    final product = selectionProvider.productList![index];
                    // selectionProvider.productList![index];
                    //   final isSelected = product.isSelected;
                    final isSelected =
                        selectionProvider.selectedProductList.contains(product);
                    // final isSelected =
                    //     selectionProvider.selectedIndices.contains(index);

                    debugPrint("selectionProvider.getProducts!.length");
                    debugPrint("${selectionProvider.productList!.length}");
                    // if (selectionProvider.isLoading ||
                    //     selectionProvider.productList!.isEmpty) {
                    if (selectionProvider.productList!.isEmpty) {
                      return const BuildProductDummy();
                    } else {
                      String? file = "";
                      debugPrint("file-$index$file");
                      for (var v in product.attachment ?? []) {
                        debugPrint(v.filePath);

                        if (v.isPrimary == 1) {
                          debugPrint("file$file");
                          file = v.filePath;
                        } else {
                          debugPrint("fileShanidha$file");
                        }
                      }

                      return isSelected
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () {
                                  selectionProvider.toggleSelectionProduct(
                                      index, product);

                                  // await cartProvider.addToCartAPI(
                                  //     customerId: 1,
                                  //     productId: p[index].productId ?? 1,
                                  //     quantity: 1);
                                  //  product.isSelected = !product.isSelected;
                                },
                                child: SelectedCategoryListItemWidget(
                                  isSelected: isSelected,
                                  currency: selectionProvider
                                          .productList![index].currency ??
                                      '',
                                  file: file ?? "",
                                  imageUrlPath: _items[0].imageUrl,
                                  price: "${product.price!.price}",
                                  title: product.productName ?? '',
                                  productId: product.productId ?? 1,
                                  customerId: customerId ?? 1,
                                  weight: selectionProvider
                                          .productList![index].unit ??
                                      '',
                                  attachment: selectionProvider
                                          .productList![index].attachment ??
                                      [],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: GestureDetector(
                                onTap: () {
                                  selectionProvider.toggleSelectionProduct(
                                      index, product);
                                  debugPrint("selected");
                                  // selectionProvider.setSelection(true);

                                  showDialogFunctionForProductDetailsAnimated(
                                      context,
                                      selectionProvider.productList![index]
                                              .productName ??
                                          '',
                                      "${selectionProvider.productList![index].price!.price}",
                                      selectionProvider
                                              .productList![index].currency ??
                                          '',
                                      selectionProvider
                                              .productList![index].unit ??
                                          '',
                                      customerId ?? 1,
                                      selectionProvider.productList![index]
                                              .category!.name ??
                                          "",
                                      selectionProvider
                                              .productList![index].productId ??
                                          0,
                                      selectionProvider
                                          .productList![index].attachment!
                                          .map((e) => e.filePath)
                                          .toList());
                                  // Provider.of<CartProvider>(context,
                                  //         listen: false)
                                  //     .addToCartAPI(
                                  //         customerId: 1,
                                  //         productId: p[index].productId ?? 1,
                                  //         quantity: 1);
                                  debugPrint(
                                      "product id ${selectionProvider.productList![index].productId}");
                                },
                                child: CategoryListItemWidget(
                                  file: file ?? "",
                                  attachment: selectionProvider
                                          .productList![index].attachment ??
                                      [],
                                  isSelected: isSelected,
                                  imageUrlPath: _items[0].imageUrl,
                                  price:
                                      "${selectionProvider.productList![index].price!.price}",
                                  title: selectionProvider
                                          .productList![index].productName ??
                                      '',
                                  weight: selectionProvider
                                          .productList![index].unit ??
                                      '',
                                  customerId: customerId ?? 1,
                                  productId: selectionProvider
                                          .productList![index].productId ??
                                      1,
                                  currency: selectionProvider
                                          .productList![index].currency ??
                                      '',
                                  fileType: '',
                                ),
                              ),
                            );
                    }
                  });
            }),
          ],
        ),
      ),
    );
  }
}

showDialogFunctionForProductDetails(
    BuildContext context,
    String productName,
    String price,
    String currency,
    String weight,
    int customerId,
    String categoryName,
    int productId,
    final List<Attachment>? attachment) {
  return showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: BuildBoxShadowContainer(
                circleRadius: 10,
                padding: const EdgeInsets.all(12),
                height: 380,
                border: Border.all(
                    color: ColorManager.kPrimaryColor.withOpacity(0.7)),
                width: 250, //MediaQuery.of(context).size.width * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 15,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          BuildBoxShadowContainer(
                            width: 15,
                            height: 15,
                            circleRadius: 10,
                            color: ColorManager.kPrimaryColor,
                            child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 10,
                                  color: Colors.white,
                                )),
                          )
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        ImageAssets.mightyZinkerImage,
                        width: 200,
                        height: 100,
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: '$productName\n ',
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s12, 0.13, Colors.black),
                        children: <TextSpan>[
                          TextSpan(
                            text: '$categoryName\n ',
                            style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.12,
                                Colors.black.withOpacity(0.5)),
                          ),
                          TextSpan(
                            text: '$currency $price/ $weight \n',
                            style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.12,
                                Colors.black.withOpacity(0.5)),
                          ),
                          TextSpan(
                            text:
                                '\n Ths is about Product details Specifically, the product description includes information about the technology behind the lens, how image stabilization works, the benefits of the lens’ light weight, and accessory compatibility. This merchant goes above and beyond with the product description by using it to educate customers on the product they’re buying.',
                            style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s10,
                                0.12,
                                Colors.black.withOpacity(0.5)),
                          ),
                          // TextSpan(
                          //   text: 'Rs $price',
                          //   style: buildCustomStyle(FontWeightManager.semiBold,
                          //       FontSize.s12, 0.12, Colors.black),
                          // ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomRoundButton(
                      title: "Add To Cart",
                      fct: () {
                        String? accessToken =
                            Provider.of<AuthModel>(context, listen: false)
                                .token;
                        debugPrint("accessToken From AuthModel $accessToken");
                        Provider.of<CartProvider>(context, listen: false)
                            .addToCartAPI(
                                customerId: customerId,
                                productId: productId,
                                quantity: 1,
                                accessToken: accessToken ?? "")
                            .then((value) {
                          if (value["status"] == "success") {
                            showScaffold(
                              context: context,
                              message: value.message ??
                                  "Added To Cart", //  'Added To Cart',
                            );
                          } else {
                            showScaffoldError(
                              context: context,
                              message: value.message,
                            );
                          }
                        });
                      },
                      fontSize: FontSize.s10,
                      height: 25,
                      width: 100,
                    ),
                  ],
                )),
          ),
        );
      });
}

showDialogFunctionForProductDetailsAnimated(
    BuildContext context,
    String productName,
    String price,
    String currency,
    String weight,
    int customerId,
    String categoryName,
    int productId,
    final List<String?> attachment) {
  return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, a1, a2, widget) {
        final pageProvider = Provider.of<CarouselProvider>(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
            child: Center(
              child: SizedBox(
                //  padding: const EdgeInsets.all(120.0),
                height: 600,
                width: 700,
                child: Material(
                  type: MaterialType.transparency,
                  child: BuildBoxShadowContainer(
                      circleRadius: 10,
                      padding: const EdgeInsets.all(12),
                      //  height: 380,
                      border: Border.all(
                          color: ColorManager.kPrimaryColor.withOpacity(0.7)),
                      // width: 250, //MediaQuery.of(context).size.width * 0.7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 15,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                BuildBoxShadowContainer(
                                  width: 15,
                                  height: 15,
                                  circleRadius: 10,
                                  color: ColorManager.kPrimaryColor,
                                  child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      )),
                                )
                              ],
                            ),
                          ),
                          // ClipRRect(
                          //   borderRadius: BorderRadius.circular(5),
                          //   child: Image.asset(
                          //     ImageAssets.mightyZinkerImage,
                          //     width: 200,
                          //     height: 100,
                          //   ),
                          // ),
                          CarouselSlider.builder(
                              itemCount:
                                  attachment.isEmpty ? 0 : attachment.length,
                              itemBuilder: (context, index, realIndex) {
                                final urlImage = attachment[index];
                                return buildImages(urlImage ?? "", index);
                              },
                              options: CarouselOptions(
                                  height: 300,
                                  autoPlay: true,
                                  enlargeStrategy:
                                      CenterPageEnlargeStrategy.height,
                                  enableInfiniteScroll: false,
                                  //enlargeCenterPage: true,
                                  onPageChanged: ((index, reason) {
                                    pageProvider.onPageChanged(index);
                                  }),
                                  autoPlayInterval:
                                      const Duration(seconds: 3))),
                          const SizedBox(height: 10),
                          attachment.isEmpty || attachment.length == 1
                              ? Container()
                              : buildIndicator(
                                  attachment.isEmpty ? 0 : attachment.length,
                                  pageProvider.currentPageIndex,
                                ),

                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: '$productName\n ',
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.13, Colors.black),
                              children: <TextSpan>[
                                TextSpan(
                                  text: '$categoryName\n ',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.12,
                                      Colors.black.withOpacity(0.5)),
                                ),
                                TextSpan(
                                  text: '$currency $price/ $weight \n',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.12,
                                      Colors.black.withOpacity(0.5)),
                                ),
                                TextSpan(
                                  text:
                                      '\n Ths is about Product details Specifically, the product description includes information about the technology behind the lens, how image stabilization works, the benefits of the lens’ light weight, and accessory compatibility. This merchant goes above and beyond with the product description by using it to educate customers on the product they’re buying.',
                                  style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s10,
                                      0.12,
                                      Colors.black.withOpacity(0.5)),
                                ),
                                // TextSpan(
                                //   text: 'Rs $price',
                                //   style: buildCustomStyle(FontWeightManager.semiBold,
                                //       FontSize.s12, 0.12, Colors.black),
                                // ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomRoundButton(
                            title: "Add To Cart",
                            fct: () {
                              String? accessToken =
                                  Provider.of<AuthModel>(context, listen: false)
                                      .token;
                              debugPrint(
                                  "accessToken From AuthModel $accessToken");
                              Provider.of<CartProvider>(context, listen: false)
                                  .addToCartAPI(
                                      customerId: customerId,
                                      productId: productId,
                                      quantity: 1,
                                      accessToken: accessToken ?? "")
                                  .then((value) {
                                AddToCartModel addToCartModel =
                                    AddToCartModel.fromJson(value);
                                if (value["status"] == "success") {
                                  showScaffold(
                                    context: context,
                                    message: addToCartModel.message ??
                                        "Added To Cart !", //  'Order Placed Successfully',
                                  );
                                } else {
                                  showScaffoldError(
                                    context: context,
                                    message: addToCartModel.message ??
                                        "Error Occured !Try Again !", //  'Added To Cart',
                                  );
                                }
                              });
                            },
                            fontSize: FontSize.s10,
                            height: 25,
                            width: 100,
                          ),
                        ],
                      )),
                ),
              ),
            ),
          ),
        );
      });
}

Widget buildImages(String urlImage, int index) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.grey,
      child: Image.network(
        urlImage,
        fit: BoxFit.cover,
      ),
    );
Widget buildIndicator(int count, int index) => AnimatedSmoothIndicator(
      activeIndex: index,
      count: count,
      effect: ScaleEffect(
          dotWidth: 14,
          dotHeight: 14,
          activeDotColor: ColorManager.kPrimaryColor.withOpacity(0.6),
          dotColor: ColorManager.grey.withOpacity(0.4)),
    );

final List<Product> _items = [
  Product(
      id: 'p1',
      title: 'MIGHTY ZINGER',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerImage),
  Product(
      id: 'p2',
      title: 'MIGHTY ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerBoxImage),
  Product(
      id: 'p3',
      title: 'ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerBoxImage),
  Product(
      id: 'p4',
      title: 'ZINGER SHRIMP BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerShrimpBoxImage),
  Product(
      id: 'p5',
      title: 'MIGHTY ZINGER',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerImage),
  Product(
      id: 'p6',
      title: 'MIGHTY ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerBoxImage),
  Product(
      id: 'p7',
      title: 'ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerBoxImage),
  Product(
      id: 'p8',
      title: 'ZINGER SHRIMP BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerShrimpBoxImage),
  Product(
      id: 'p4',
      title: 'ZINGER SHRIMP BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerShrimpBoxImage),
  Product(
      id: 'p5',
      title: 'MIGHTY ZINGER',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerImage),
  Product(
      id: 'p6',
      title: 'MIGHTY ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.mightyZinkerBoxImage),
  Product(
      id: 'p7',
      title: 'ZINGER BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerBoxImage),
  Product(
      id: 'p8',
      title: 'ZINGER SHRIMP BOX',
      weight: '150',
      price: 3.50,
      imageUrl: ImageAssets.zinkerShrimpBoxImage),
];
