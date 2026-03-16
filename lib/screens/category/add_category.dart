import 'dart:ui';

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
import '../../widgets/add_category_modal.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({Key? key}) : super(key: key);

  @override
  AddCategoryScreenState createState() => AddCategoryScreenState();
}

class AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController categoryNameController = TextEditingController();
  final TextEditingController parentCategoryController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool initLoading = false;
  String? selectedCategoryId;
  String? selectedParentCategoryId;
  List<Category>? categoryList;

  @override
  void initState() {
    loadInitData();
    super.initState();
  }

  void loadInitData() async {
    try {
      if (mounted) {
        setState(() {
          initLoading = true;
        });
      }

      CategoryProvider categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Check if categories are already loaded from login
      if (categoryProvider.isCategoriesLoaded &&
          categoryProvider.hasValidCategories) {
        debugPrint(
            "✅ [AddCategory] Using already loaded categories: ${categoryProvider.categoryList?.length} categories");
        // Use the already loaded categories for search display
        if (mounted) {
          setState(() {
            categoryList = categoryProvider.category;
          });
        }
        // Set the search categories to the loaded categories
        categoryProvider.searchCategoryList = categoryProvider.categoryList;
        categoryProvider.currentPage = 1;
        categoryProvider.totalPages = 1;
        categoryProvider.notifyListeners();
      } else {
        debugPrint(
            "📥 [AddCategory] Loading categories from API - not loaded or empty");
        if (mounted) {
          setState(() {
            categoryList = categoryProvider.category;
          });
        }
        await categoryProvider.searchAllCategory(
          page: 1,
        );
      }
    } catch (error) {
      debugPrint("Error in loadInitData: $error");
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  void searchCategory(int page) async {
    try {
      if (mounted) {
        setState(() {
          initLoading = true;
        });
      }
      CategoryProvider categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Always make API call for search/filter operations
      await categoryProvider.searchAllCategory(
        filterName:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        filterParent: selectedParentCategoryId,
        page: page,
      );
    } catch (error) {
      debugPrint("Error in searchCategory: $error");
    } finally {
      if (mounted) {
        setState(() {
          initLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> resetSearch() async {
    _searchController.clear();
    CategoryProvider categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Use already loaded categories if available, otherwise make API call
    if (categoryProvider.isCategoriesLoaded &&
        categoryProvider.hasValidCategories) {
      debugPrint("✅ [AddCategory] Reset using cached categories");
      // Reset to show all loaded categories
      categoryProvider.searchCategoryList = categoryProvider.categoryList;
      categoryProvider.currentPage = 1;
      categoryProvider.totalPages = 1;
      categoryProvider.notifyListeners();
    } else {
      debugPrint(
          "📥 [AddCategory] Reset with API call - categories not cached");
      await categoryProvider.searchAllCategory(
        page: 1,
      );
    }

    if (mounted) {
      setState(() {
        selectedCategoryId = null;
        selectedParentCategoryId = null;
      });
    }
  }

  Future<void> refreshData() async {
    await resetSearch();
  }

  Future<void> _openAddCategoryModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddCategoryModal(),
    );

    if (result == true && mounted) {
      await resetSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
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
                    children: [
                      // Search Category - Takes available space
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Search Category",
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
                              child: BuildBoxShadowContainer(
                                circleRadius: 7,
                                alignment: Alignment.centerLeft,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 0),
                                padding: const EdgeInsets.only(left: 15),
                                color: Colors.white,
                                child: TextField(
                                  controller: _searchController,
                                  textAlign: TextAlign.left,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s10,
                                    0.27,
                                    ColorManager.textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type to search...',
                                    hintStyle: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s10,
                                      0.27,
                                      ColorManager.textColor.withOpacity(.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 0),
                                    isDense: true,
                                    suffixIcon: _searchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _searchController.clear();
                                              resetSearch();
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (value) {
                                    if (value.isEmpty) {
                                      resetSearch();
                                    } else {
                                      searchCategory(1);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 15),

                      // First empty space
                      Expanded(
                        child: Container(), // Empty container for spacing
                      ),

                      const SizedBox(width: 15),

                      // Second empty space
                      Expanded(
                        child: Container(), // Empty container for spacing
                      ),

                      const SizedBox(width: 15),

                      // Reset button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                                height:
                                    35), // Space to align with the text field
                            CustomRoundButton(
                              title: "Reset",
                              boxColor: Colors.white,
                              textColor: ColorManager.kPrimaryColor,
                              fct: resetSearch,
                              height: 45,
                              width: double
                                  .infinity, // Take full width of the container
                              fontSize: FontSize.s12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child:
                      _buildCategoryTable(categoryProvider, sideBarController),
                ),
                _buildPaginationControls(categoryProvider),
              ],
            ),
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
<<<<<<< HEAD
        CustomRoundButton(
          title: "Add Category",
          fct: () {
            sideBarController.index.value = 16;
          },
          fontSize: 12,
          height: 45,
          width: 180,
=======
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomRoundButton(
              title: "Create New Category",
              fct: _openAddCategoryModal,
              fontSize: 12,
              height: 45,
              width: 200,
            ),
          ],
>>>>>>> e86d9c65bb28b60c09b2deb4496d08117639acdf
        ),
      ],
    );
  }

  // Replace your existing _buildCategoryTable method with this:
// Replace your existing _buildCategoryTable method with this:
  Widget _buildCategoryTable(
      CategoryProvider categoryProvider, SideBarController sideBarController) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        return BuildBoxShadowContainer(
          margin: const EdgeInsets.only(top: 5),
          circleRadius: 7,
          offsetValue: const Offset(2, 2),
          blurRadius: 8.0,
          color: Colors.white,
          child: Column(
            children: [
              // Fixed table header
              Container(
                decoration: const BoxDecoration(
                  color: ColorManager.tableBGColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 2),
                      blurRadius: 2.0,
                    ),
                  ],
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.0), // No
                    1: FlexColumnWidth(3.0), // Category Name
                    2: FlexColumnWidth(3.0), // Slug
                    3: FlexColumnWidth(1.2), // Action
                  },
                  border: null,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        _buildTableHeader("No"),
                        _buildTableHeader("Category Name"),
                        _buildTableHeader("Slug"),
                        _buildTableHeader("Action"),
                      ],
                    ),
                  ],
                ),
              ),
              // Scrollable table body
              Expanded(
                child: categoryProvider.searchCategory == null ||
                        categoryProvider.searchCategory!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category,
                              size: 60,
                              color:
                                  ColorManager.kPrimaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'No categories available',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s18,
                                0.27,
                                ColorManager.textColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.touch,
                              PointerDeviceKind.stylus,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.0), // No
                                1: FlexColumnWidth(3.0), // Category Name
                                2: FlexColumnWidth(3.0), // Slug
                                3: FlexColumnWidth(1.2), // Action
                              },
                              border: null,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                ...categoryProvider.searchCategory!
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final int index = entry.key;
                                  final category = entry.value;
                                  return TableRow(
                                    // Set minimum row height
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0
                                          ? Colors.white
                                          : Colors.grey.withOpacity(0.1),
                                    ),
                                    children: [
                                      _buildTableCell((index + 1).toString()),
                                      _buildTableCell(
                                          category.categoryName ?? ""),
                                      _buildTableCell(
                                          category.categorySlug ?? ""),
                                      Center(
                                        child: _buildActionButton(
                                          Icons.edit,
                                          Colors.blue.shade50,
                                          Colors.blue,
                                          () {
                                            sideBarController.index.value = 34;
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

// Updated _buildTableHeader with larger padding and font
  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 18.0, horizontal: 12.0), // Increased padding
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12, // Increased font size
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

// Updated _buildTableCell with larger padding and font
  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 20.0, horizontal: 12.0), // Increased padding
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9, // Increased font size
          0.13,
          Colors.black,
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
      currentPage: categoryProvider.currentPage,
      totalPages: categoryProvider.totalPages,
      onPageChanged: (int page) {
        searchCategory(page);
      },
    );
  }
}
