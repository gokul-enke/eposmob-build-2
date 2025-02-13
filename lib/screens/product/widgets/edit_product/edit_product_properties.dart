// import 'package:flutter/material.dart';

// import 'package:provider/provider.dart';

// import '../../../../components/build_container_box.dart';
// import '../../../../components/build_round_button.dart';
// import '../../../../components/build_text_fields.dart';

// import '../../../../providers/grid_provider.dart';
// import '../../../../resources/color_manager.dart';
// import '../../../../resources/font_manager.dart';
// import '../../../../resources/style_manager.dart';

// class EditProductPropertiesScreen extends StatelessWidget {
//   final Function(int) navigateToScreen;
//   const EditProductPropertiesScreen(
//       {super.key, required this.navigateToScreen});

//   @override
//   Widget build(BuildContext context) {
//     //final productPropertiesController = TextEditingController();
//     // Define the list of currency

//     List<String> property = [
//       'Choose Product Properties',
//       'brass',
//       'bronze',
//       "black",
//       "white",
//     ];

//     // Track the selected unit
//     String? selectedProperty;
//     GridSelectionProvider gridSelectionProvider =
//         Provider.of<GridSelectionProvider>(context);
//     Size size = MediaQuery.of(context).size;
//     //SideBarController sideBarController = Get.put(SideBarController());

//     return SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             height: size.height * 0.8,
//             width: double.infinity,
//             child: BuildBoxShadowContainer(
//               circleRadius: 7,
//               // margin: const EdgeInsets.only(bottom: 10),
//               blurRadius: 6,
//               padding: const EdgeInsets.only(
//                   left: 10.0, right: 20, top: 30, bottom: 10),
//               offsetValue: const Offset(1, 1),

//               child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     BuildDropDownStatic(
//                       selectedItem: selectedProperty,
//                       size: size,
//                       items: property,
//                       hintText: 'Choose Product Properties',
//                       title: 'Product Properties',
//                       onChanged: (String? newValue) {
//                         selectedProperty = newValue!;
//                       },
//                     ),
//                     const SizedBox(height: 50),
//                     Row(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(left: 10.0),
//                           child: CustomRoundButton(
//                             title: "Prev",
//                             boxColor: Colors.white,
//                             textColor: ColorManager.kPrimaryColor,
//                             fct: () async {
//                               navigateToScreen(1);
//                               // sideBarController.index.value = 14;
//                             },
//                             height: 50,
//                             width: size.width * 0.19,
//                             fontSize: FontSize.s12,
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.only(left: 10.0),
//                           child: CustomRoundButton(
//                             title: "Submit",
//                             fct: () async {
//                               navigateToScreen(3);
//                               int? productId =
//                                   gridSelectionProvider.getProductId;
//                               if (productId == null) {
//                                 ScaffoldMessenger.of(context)
//                                   ..removeCurrentSnackBar()
//                                   ..showSnackBar(SnackBar(
//                                       showCloseIcon: true,
//                                       dismissDirection: DismissDirection.up,
//                                       closeIconColor: Colors.white,
//                                       duration: const Duration(seconds: 2),
//                                       behavior: SnackBarBehavior.floating,
//                                       elevation: 0,
//                                       margin: EdgeInsets.only(
//                                           top: 50,
//                                           left: MediaQuery.of(context)
//                                                   .size
//                                                   .width /
//                                               1.9,
//                                           right: 10),
//                                       backgroundColor: ColorManager
//                                           .kPrimaryColor
//                                           .withOpacity(0.6),
//                                       shape: RoundedRectangleBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(10)),
//                                       content: Text(
//                                         'Failed',
//                                         style: buildCustomStyle(
//                                             FontWeightManager.medium,
//                                             FontSize.s12,
//                                             0.12,
//                                             Colors.white),
//                                       )));
//                                 // sideBarController.index.value = 14;
//                               } else {}
//                             },
//                             height: 50,
//                             width: size.width * 0.19,
//                             fontSize: FontSize.s12,
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.only(left: 10.0),
//                           child: CustomRoundButton(
//                             title: "Next",
//                             boxColor: Colors.white,
//                             textColor: ColorManager.kPrimaryColor,
//                             fct: () async {
//                               navigateToScreen(3);
//                               //   sideBarController.index.value = 14;
//                             },
//                             height: 50,
//                             width: size.width * 0.19,
//                             fontSize: FontSize.s12,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 25),
//                   ]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import '../../../../components/build_container_box.dart';
import '../../../../components/build_round_button.dart';
import '../../../../providers/grid_provider.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class EditProductPropertiesScreen extends StatefulWidget {
  final Function(int) navigateToScreen;
  const EditProductPropertiesScreen(
      {super.key, required this.navigateToScreen});

  @override
  _EditProductPropertiesScreenState createState() =>
      _EditProductPropertiesScreenState();
}

class _EditProductPropertiesScreenState
    extends State<EditProductPropertiesScreen> {
  Map<String, dynamic> apiBodyData = {};
  Map<String, List<String>> productPropData = {};
  Map<String, String> productPropStockApplicable = {};
  Map<String, int> productPropIds = {};
  Map<String, bool> stockApplicableMap = {};

  String? selectedProperty;

  @override
  void initState() {
    super.initState();
    // Fetch product properties when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      int? categoryId = Provider.of<CategoryProvider>(context, listen: false)
          .getPropCategoryId;
      // debugPrintdebugPrint("category id $categoryId");
      // debugPrintdebugPrint("category id $categoryId");
      Provider.of<CategoryProvider>(context, listen: false).fetchPropValues(
          categoryId: categoryId, accessToken: accessToken ?? "");
    
      // Load existing product properties
      loadExistingProperties();
    });
  }

  void loadExistingProperties() {
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    GetProduct? productDetails = gridSelectionProvider.getProductDetails;

    if (productDetails?.productProps != null) {
      for (var prop in productDetails!.productProps!) {
        if (prop.propsCode != null && prop.masterValue != null) {
          // debugPrintdebugPrint("propdada${prop.toString()}");
          String key = prop.propsCode!;
          String value = prop.masterValue!;

          // Populate productPropData
          productPropData[key] = value.split(',').toList();

          // Populate apiBodyData
          apiBodyData[key] = value.split(',');

          // Populate productPropStockApplicable
          productPropStockApplicable[key] = prop.stockApplicable ?? 'N';

          // Populate productPropIds
          if (prop.propsId != null) {
            productPropIds[key] = prop.propsId!;
          }

          // Populate stockApplicableMap
          stockApplicableMap[key] = prop.stockApplicable == 'Y';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(context);
    GetProduct? getProduct = gridSelectionProvider.getProductDetails;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: size.height * 0.7, // Adjust height
            width: double.infinity,
            child: BuildBoxShadowContainer(
              circleRadius: 7,
              blurRadius: 6,
              padding: const EdgeInsets.only(
                  left: 10.0, right: 20, top: 30, bottom: 10),
              offsetValue: const Offset(1, 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display product properties
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      if (categoryProvider.propValues == null) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (categoryProvider.propValues!.isEmpty) {
                        return const Center(child: Text("No properties found"));
                      } else {
                        return Flexible(
                          child: ListView.builder(
                            itemCount: categoryProvider.propValues!.length,
                            itemBuilder: (context, index) {
                              final property =
                                  categoryProvider.propValues![index];
                              final masterValue = property['master_value'];
                              final propType = property['prop_type'];
                              final propsCode = property['props_code'];
                              final propsLabel = property['label'];
                              debugPrint(
                                  "propsCode ${productPropData[propsCode].toString()}");
                              if (propType == "TXT") {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BuildTextTile(
                                      title: propsLabel,
                                      isStarRed: true,
                                      isTextField: true,
                                      textStyle: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.27,
                                        Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                    BuildBoxShadowContainer(
                                      circleRadius: 7,
                                      alignment: Alignment.centerLeft,
                                      margin: const EdgeInsets.only(left: 2),
                                      padding: const EdgeInsets.only(left: 15),
                                      height: size.height * .07,
                                      width: size.width / 3,
                                      child: TextFormField(
                                        initialValue: productPropData[propsCode]
                                                    ?[0]
                                                .toString() ??
                                            '',
                                        onChanged: (value) {
                                          setState(() {
                                            apiBodyData['$propsCode'] = value;
                                            productPropData[propsCode] = [
                                              value
                                            ];
                                          });
                                        },
                                        keyboardType: TextInputType.text,
                                        cursorColor: ColorManager.kPrimaryColor,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Enter $propsLabel',
                                          hintStyle: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.27,
                                            ColorManager.textColor
                                                .withOpacity(.5),
                                          ),
                                        ),
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s12,
                                          0.27,
                                          ColorManager.textColor
                                              .withOpacity(.5),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: size.width * .40,
                                      child: CheckboxListTile(
                                        title: const Text("Stock Applicable"),
                                        value: stockApplicableMap[propsCode] ??
                                            false,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            stockApplicableMap[propsCode] =
                                                value!;
                                            productPropStockApplicable[
                                                propsCode] = value ? "Y" : "N";
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                final items =
                                    List<String>.from(masterValue.split(','));
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    BuildTextTile(
                                      title: propsLabel,
                                      isStarRed: true,
                                      isTextField: true,
                                      textStyle: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.27,
                                        Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                    BuildBoxShadowContainer(
                                      circleRadius: 7,
                                      alignment: Alignment.centerLeft,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 0),
                                      padding: const EdgeInsets.only(left: 15),
                                      width: size.width / 3,
                                      child: MultiSelectDialogField(
                                        items: items
                                            .map((item) =>
                                                MultiSelectItem<String>(
                                                    item, item))
                                            .toList(),
                                        // error
                                        initialValue: productPropData[propsCode]
                                                ?.cast<String>() ??
                                            [],
                                        title: Text("Choose $propsLabel"),
                                        selectedColor:
                                            ColorManager.kPrimaryColor,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(10)),
                                          border: Border.all(
                                            color: Colors
                                                .transparent, // Transparent border
                                          ),
                                        ),
                                        buttonIcon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.grey,
                                        ),
                                        buttonText: Text(
                                          "Choose $propsCode",
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 16,
                                          ),
                                        ),
                                        onConfirm: (results) {
                                          setState(() {
                                            selectedProperty =
                                                results.join(', ');
                                            apiBodyData['$propsCode'] = results;
                                            productPropData[propsCode] =
                                                List<String>.from(results);
                                          });
                                        },
                                        chipDisplay: MultiSelectChipDisplay(
                                          onTap: (value) {
                                            setState(() {
                                              apiBodyData['$propsCode']
                                                  ?.remove(value);
                                              productPropData[propsCode]
                                                  ?.remove(value);
                                              if (apiBodyData['$propsCode']
                                                      ?.isEmpty ??
                                                  true) {
                                                apiBodyData
                                                    .remove('$propsCode');
                                                productPropData
                                                    .remove(propsCode);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: size.width * .40,
                                      child: CheckboxListTile(
                                        title: const Text("Stock Applicable"),
                                        value: stockApplicableMap[propsCode] ??
                                            false,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            stockApplicableMap[propsCode] =
                                                value!;
                                            productPropStockApplicable[
                                                propsCode] = value ? "Y" : "N";
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: CustomRoundButton(
                          title: "Prev",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          fct: () async {
                            widget.navigateToScreen(2);
                          },
                          height: 50,
                          width: size.width * 0.19,
                          fontSize: FontSize.s12,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: CustomRoundButton(
                          title: "Save",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          fct: () async {
                            // debugPrintdebugPrint("apiBodyData.toString()");
                            // debugPrintdebugPrint(apiBodyData.toString());
                            int? productId = getProduct!.productId;
                            if (productId == null) {
                              showScaffoldError(
                                  context: context, message: 'Failed');
                            } else {
                              showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) {
                                    return const Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    );
                                  });
                              String? accessToken =
                                  Provider.of<AuthModel>(context, listen: false)
                                      .token;
                              debugPrint(
                                  "accessToken From AuthModel $accessToken");
                              gridSelectionProvider
                                  .editProductPropsAPI(
                                productId: "$productId",
                                accessToken: accessToken ?? "",
                                productPropIds: productPropIds.values
                                    .map((id) => id.toString())
                                    .toList(),
                                productPropCodes: productPropData.keys.toList(),
                                productPropData: productPropData,
                                productPropStockApplicable:
                                    productPropStockApplicable,
                              )
                                  .then(
                                (value) {
                                  if (value["status"] == "success") {
                                    showScaffold(
                                      context: context,
                                      message: '${value["message"]}',
                                    );

                                    Navigator.pop(context);
                                    widget.navigateToScreen(3);
                                  } else {
                                    Navigator.pop(context);

                                    showScaffoldError(
                                        context: context,
                                        message: 'Failed to update properties');
                                  }
                                },
                              );
                            }
                          },
                          height: 50,
                          width: size.width * 0.19,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
