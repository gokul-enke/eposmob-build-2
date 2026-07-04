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

      await categoryProvider.refreshManagementCategories(force: false);
      if (mounted) {
        setState(() {
          categoryList = categoryProvider.category;
        });
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
      categoryProvider.searchCategoryList = categoryProvider.categoryList;
      categoryProvider.currentPage = 1;
      categoryProvider.totalPages = 1;
      categoryProvider.notifyListeners();
    } else {
      debugPrint(
          "📥 [AddCategory] Reset with API call - categories not cached");
      await categoryProvider.refreshManagementCategories(force: true);
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

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: isMobile ? 10 : 20,
          ),
          padding: EdgeInsets.all(isMobile ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 12.0 : 20.0,
              horizontal: isMobile ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(categoryProvider, sideBarController, isMobile),
                const SizedBox(height: 15),
                _buildSearchRow(isMobile, size),
                const SizedBox(height: 16),
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

  Widget _buildSearchRow(bool isMobile, Size size) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(size),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: "Reset",
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: resetSearch,
            height: 45,
            width: double.infinity,
            fontSize: FontSize.s12,
          ),
        ],
      );
    }

    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(flex: 3, child: _buildSearchField(size)),
          const SizedBox(width: 15),
          Expanded(
            flex: 1,
            child: CustomRoundButton(
              title: "Reset",
              boxColor: Colors.white,
              textColor: ColorManager.kPrimaryColor,
              fct: resetSearch,
              height: 45,
              width: double.infinity,
              fontSize: FontSize.s12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            "Search Category",
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              Colors.black.withOpacity(0.7),
            ),
          ),
        ),
        SizedBox(
          height: 45,
          child: BuildBoxShadowContainer(
            circleRadius: 10,
            alignment: Alignment.centerLeft,
            margin: EdgeInsets.zero,
            padding: const EdgeInsetsDirectional.only(start: 15),
            color: Colors.white,
            border: Border.all(color: Colors.grey.withOpacity(0.12)),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
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
                contentPadding: EdgeInsets.zero,
                isDense: true,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
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
    );
  }

  Widget _buildHeader(CategoryProvider categoryProvider,
      SideBarController sideBarController, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Category List",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.kTitleTextColor,
            ),
          ),
          const SizedBox(height: 12),
          CustomRoundButton(
            title: "Add Category",
            fct: () {
              sideBarController.index.value = 16;
            },
            fontSize: 12,
            height: 45,
            width: double.infinity,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Category List",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.kTitleTextColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        CustomRoundButton(
          title: "Add Category",
          fct: () {
            sideBarController.index.value = 16;
          },
          fontSize: 12,
          height: 45,
          width: 180,
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
        final categories = categoryProvider.searchCategory;
        final bool isMobile = _isMobile(context);

        if (categories == null || categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    size: 40,
                    color: ColorManager.kPrimaryColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No categories available',
                  textAlign: TextAlign.center,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s16,
                    0.27,
                    ColorManager.kTitleTextColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (isMobile) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BuildBoxShadowContainer(
                  circleRadius: 14,
                  padding: const EdgeInsets.all(16),
                  showShadow: true,
                  blurRadius: 10,
                  offsetValue: const Offset(0, 3),
                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.categoryName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.18,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.categorySlug ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.13,
                                ColorManager.kGreyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildActionButton(
                        Icons.edit_outlined,
                        Colors.blue.shade50,
                        Colors.blue,
                        () {
                          sideBarController.index.value = 34;
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return BuildBoxShadowContainer(
          margin: const EdgeInsets.only(top: 5),
          circleRadius: 14,
          offsetValue: const Offset(0, 3),
          blurRadius: 10.0,
          color: Colors.white,
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: ColorManager.tableBGColor,
                    border: Border(
                      bottom: BorderSide(color: Color(0x1F000000), width: 1),
                    ),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.0),
                      1: FlexColumnWidth(3.0),
                      2: FlexColumnWidth(3.0),
                      3: FlexColumnWidth(1.2),
                    },
                    border: null,
                    defaultVerticalAlignment:
                        TableCellVerticalAlignment.middle,
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
                Expanded(
                  child: MouseRegion(
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
                            0: FlexColumnWidth(1.0),
                            1: FlexColumnWidth(3.0),
                            2: FlexColumnWidth(3.0),
                            3: FlexColumnWidth(1.2),
                          },
                          border: null,
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            ...categories.toList().asMap().entries.map((entry) {
                              final int index = entry.key;
                              final category = entry.value;
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? Colors.white
                                      : Colors.grey.withOpacity(0.1),
                                ),
                                children: [
                                  _buildTableCell((index + 1).toString()),
                                  _buildTableCell(category.categoryName ?? ""),
                                  _buildTableCell(category.categorySlug ?? ""),
                                  Center(
                                    child: _buildActionButton(
                                      Icons.edit_outlined,
                                      Colors.blue.shade50,
                                      Colors.blue,
                                      () {
                                        sideBarController.index.value = 34;
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kTitleTextColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.13,
          ColorManager.kTextColor,
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, Color bgColor, Color iconColor, VoidCallback onPressed) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 5),
      color: bgColor,
      circleRadius: 10,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon, size: 18, color: iconColor),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: onPressed,
        ),
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
