import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../models/category_list.dart';
import '../../providers/category_providers.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({Key? key}) : super(key: key);

  @override
  AddCategoryScreenState createState() => AddCategoryScreenState();
}

class AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController categoryNameController = TextEditingController();
  final TextEditingController parentCategoryController =
      TextEditingController();
  final TextEditingController createdByController = TextEditingController();
  bool initLoading = false;

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     Provider.of<CategoryProvider>(context, listen: false).listAllCategory();
  //   });
  // }

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });
      // String? accessToken =
      //     Provider.of<AuthModel>(context, listen: false).token;

      CategoryProvider categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      await categoryProvider.listAllCategory(
        // accessToken: accessToken ?? "",
        page: 1,
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchCategory(page) async {
    debugPrint("category search called");
    try {
      setState(() {
        initLoading = true;
      });
      CategoryProvider categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      await categoryProvider.listAllCategory(
        filterName: categoryNameController.text,
        // filterCreatedBy: createdByController.text,
        filterParent: parentCategoryController.text,
        page: page,
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      categoryNameController.clear();
      createdByController.clear();
      parentCategoryController.clear();
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: true);
    final SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   "Category List",
              //   style: buildCustomStyle(FontWeightManager.semiBold,
              //       FontSize.s20, 0.30, ColorManager.textColor),
              // ),
              _buildHeader(categoryProvider, sideBarController),
              const SizedBox(
                height: 15,
              ),
              SizedBox(
                height: 90,
                child: Row(
                  // scrollDirection: Axis.horizontal,
                  // physics: const BouncingScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Category Name ",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 45,
                            width: 120, //size.width * 0.5,
                            child: TextFormField(
                              onChanged: (value) {
                                setState(() {
                                  // searchAmount = value;
                                });
                              },
                              cursorColor: ColorManager.kPrimaryColor,
                              cursorHeight: 13,
                              controller: categoryNameController,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: decoration.copyWith(
                                  hintText: "Category Name    ",
                                  hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s10,
                                      0.18,
                                      ColorManager.textColor),
                                  // prefixIcon: const Icon(
                                  //   Icons.search,
                                  //   color: Colors.black,
                                  //   size: 35,
                                  // ),
                                  prefixIconColor: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Parent Category ",
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 45,
                            width: 120, //size.width * 0.5,
                            child: TextFormField(
                              onChanged: (value) {
                                setState(() {
                                  // searchAmount = value;
                                });
                              },
                              cursorColor: ColorManager.kPrimaryColor,
                              cursorHeight: 13,
                              controller: parentCategoryController,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: decoration.copyWith(
                                  hintText: "Parent Category    ",
                                  hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s10,
                                      0.18,
                                      ColorManager.textColor),
                                  // prefixIcon: const Icon(
                                  //   Icons.search,
                                  //   color: Colors.black,
                                  //   size: 35,
                                  // ),
                                  prefixIconColor: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Padding(
                    //   padding: const EdgeInsets.only(left: 10.0),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Padding(
                    //         padding: const EdgeInsets.all(8.0),
                    //         child: Text(
                    //           "Created By ",
                    //           style: buildCustomStyle(
                    //             FontWeightManager.regular,
                    //             FontSize.s14,
                    //             0.27,
                    //             Colors.black.withOpacity(0.6),
                    //           ),
                    //         ),
                    //       ),
                    //       SizedBox(
                    //         height: 45,
                    //         width: 120, //size.width * 0.5,
                    //         child: TextFormField(
                    //           onChanged: (value) {
                    //             setState(() {
                    //               // searchAmount = value;
                    //             });
                    //           },
                    //           cursorColor: ColorManager.kPrimaryColor,
                    //           cursorHeight: 13,
                    //           controller: createdByController,
                    //           style: buildCustomStyle(FontWeightManager.medium,
                    //               FontSize.s10, 0.18, ColorManager.textColor),
                    //           decoration: decoration.copyWith(
                    //               hintText: "Created By   ",
                    //               hintStyle: buildCustomStyle(
                    //                   FontWeightManager.medium,
                    //                   FontSize.s10,
                    //                   0.18,
                    //                   ColorManager.textColor),
                    //               // prefixIcon: const Icon(
                    //               //   Icons.search,
                    //               //   color: Colors.black,
                    //               //   size: 35,
                    //               // ),
                    //               prefixIconColor: Colors.black),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Search",
                        fct: () => {searchCategory(1)},
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Reset",
                        boxColor: Colors.white,
                        textColor: ColorManager.kPrimaryColor,
                        fct: resetSearch,
                        height: 45,
                        width: size.width * 0.09,
                        fontSize: FontSize.s12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  offsetValue: const Offset(1, 1),
                  child:
                      _buildCategoryTable(categoryProvider, sideBarController),
                ),
              ),
              _buildPaginationControls(categoryProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      CategoryProvider categoryProvider, SideBarController sideBarController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Category List",
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s20,
            0.30,
            ColorManager.textColor,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // SizedBox(
            //   height: 45,
            //   width: 180,
            //   child: TextField(
            //     controller: _searchController,
            //     cursorWidth: 1,
            //     cursorColor: ColorManager.kPrimaryColor,
            //     onChanged: (query) {
            //       categoryProvider.searchCategories(query);
            //     },
            //     decoration: InputDecoration(
            //       prefixIcon: WebsafeSvg.asset(
            //         ImageAssets.categorySearchIcon,
            //         fit: BoxFit.none,
            //       ),
            //       labelStyle: buildCustomStyle(
            //         FontWeightManager.regular,
            //         FontSize.s10,
            //         0.10,
            //         ColorManager.textColor,
            //       ),
            //       hintText: 'Search category',
            //       hintStyle: buildCustomStyle(
            //         FontWeightManager.regular,
            //         FontSize.s10,
            //         0.13,
            //         ColorManager.textColor1,
            //       ),
            //     ),
            //   ),
            // ),
            // const SizedBox(width: 10),
            CustomRoundButton(
              title: "Create New Category",
              fct: () {
                sideBarController.index.value = 16;
              },
              fontSize: 12,
              height: 45,
              width: 200,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryTable(
      CategoryProvider categoryProvider, SideBarController sideBarController) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.symmetric(
                outside: const BorderSide(
                    color: ColorManager.tableBOrderColor, width: 0.3),
                inside: const BorderSide(
                    color: ColorManager.tableBOrderColor, width: 0.8),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(3),
                3: FlexColumnWidth(2),
              },
              children: [
                _buildTableHeader(),
                if (categoryProvider.categoryList != null)
                  ...categoryProvider.categoryList!
                      .skip(1)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    Category category = entry.value;
                    return _buildTableRow(
                        category, sideBarController, categoryProvider);
                  }).toList(),
              ],
            ),
          ),
        ),
        // const SizedBox(height: 20),
      ],
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: ColorManager.tableBGColor),
      children: ["No", "Category Name", "Slug", "Action"]
          .map((title) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Center(
                    child: Text(
                      title,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  TableRow _buildTableRow(Category category,
      SideBarController sideBarController, CategoryProvider categoryProvider) {
    return TableRow(
      children: [
        _buildTableCell(category.categoryId?.toString() ?? ""),
        _buildTableCell(category.categoryName ?? ""),
        _buildTableCell(category.categorySlug ?? ""),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  Icons.visibility,
                  ColorManager.kPrimaryColor.withOpacity(0.9),
                  Colors.white,
                  () async {
                    await categoryProvider.viewCategoryApi(
                        categoryId: category.categoryId ?? 1);
                    sideBarController.index.value = 27;
                  },
                ),
                _buildActionButton(
                  Icons.edit,
                  ColorManager.kPrimaryColor.withOpacity(0.9),
                  Colors.white,
                  () async {
                    await categoryProvider.setEditCategoryId(
                        categoryId: category.categoryId ?? 1);
                    await categoryProvider.viewCategoryApi(
                        categoryId: category.categoryId ?? 1);
                    sideBarController.index.value = 34;
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s9,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, Color bgColor, Color iconColor, VoidCallback onPressed) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(left: 5, right: 5),
      color: bgColor,
      circleRadius: 5,
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPaginationControls(CategoryProvider categoryProvider) {
    return PaginationControl(
      currentPage: 1,
      totalPages: 1,
      onPageChanged: (int page) {
        searchCategory(page);
      },
    );
  }
}
