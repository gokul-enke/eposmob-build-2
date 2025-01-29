import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_border.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:web_date_picker/web_date_picker.dart';

class ProductSalesReportScreen extends StatefulWidget {
  const ProductSalesReportScreen({super.key});

  @override
  State<ProductSalesReportScreen> createState() =>
      _ProductSalesReportScreenState();
}

class _ProductSalesReportScreenState extends State<ProductSalesReportScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();
  final TextEditingController textEditingController = TextEditingController();
  final TextEditingController idController = TextEditingController(text: "0");
  final TextEditingController categoryIdController = TextEditingController();
  GetProduct? selectedValue;

  bool initLoading = false;

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
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      await reportsProvider.fetchProductSalesReport(
        accessToken: accessToken ?? "",
      );
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchAccountBook() async {
    try {
      setState(() {
        initLoading = true;
      });
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      ReportsProvider reportsProvider =
          Provider.of<ReportsProvider>(context, listen: false);

      debugPrint(categoryIdController.text.toString());

      await reportsProvider.fetchProductSalesReport(
        accessToken: accessToken ?? "",
        categoryId: categoryIdController.text,
        productId: selectedValue?.productId.toString(),
        startDate: startDateController.text,
        endDate: endDateController.text,
        amount: amountController.text,
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
      idController.clear();
      categoryIdController.clear();
      selectedValue = null;
      amountController.clear();
      startDateController.clear();
      endDateController.clear();
    });
    loadInitData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    ReportsProvider reportsProvider = Provider.of<ReportsProvider>(context);
    // Access the CategoryProvider
    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    // Access the CategoryProvider
    GridSelectionProvider gridSelectionProvider =
        Provider.of<GridSelectionProvider>(
      context,
    );

    // Access the category list

    List<GetProduct>? productList =
        gridSelectionProvider.getCategoryProductList;

    String? parentCategory;
    // Access the category list
    List<Category>? categoryList = categoryProvider.category;
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
            color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: ListView(
            children: [
              Text(
                "Product Sales Report",
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              const SizedBox(
                height: 15,
              ),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Categories ",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s14,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        BuildBorderContainer(
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: DropdownButtonFormField<Category>(
                            decoration: const InputDecoration(
                              border: InputBorder.none, // Remove the underline
                            ),
                            value: categoryProvider.selectedCategoryIndex >= 0
                                ? categoryList![
                                    categoryProvider.selectedCategoryIndex]
                                : null,
                            hint: Text(
                              'Select Category',
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.27,
                                ColorManager.textColor.withOpacity(.5),
                              ),
                            ),
                            items: categoryList!
                                .map((Category category) {
                                  return DropdownMenuItem<Category>(
                                      value: category,
                                      child: category.categoryName == "ALL"
                                          ? Text(
                                              ' Please Select',
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5),
                                              ),
                                            )
                                          : Text(
                                              category.categoryName ?? '',
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.27,
                                                ColorManager.textColor
                                                    .withOpacity(.5),
                                              ),
                                            ));
                                })
                                .toSet()
                                .toList(),
                            onChanged: (Category? selectedCategory) async {
                              if (selectedCategory != null) {
                                categoryProvider.selectCategory(
                                  categoryList.indexOf(selectedCategory),
                                  selectedCategory.categoryName ?? '',
                                  selectedCategory.productsCount ?? 0,
                                );

                                parentCategory =
                                    "${selectedCategory.categoryId ?? 0}";
                                debugPrint(parentCategory);

                                gridSelectionProvider.updateCategory(
                                    selectedCategory.categoryId ?? 0);

                                setState(() {
                                  productList = gridSelectionProvider
                                      .selectedProductsUpOnCategory;
                                  categoryIdController.text =
                                      selectedCategory.categoryId.toString();
                                });

                                await categoryProvider.setParentCategory(
                                    "${selectedCategory.categoryId ?? 0}");
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Select Product ",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s14,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        BuildBorderContainer(
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<GetProduct>(
                              isExpanded: true,
                              hint: Text(
                                '--Select--',
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0.27,
                                  Colors.black.withOpacity(0.6),
                                ),
                              ),
                              items: productList!
                                  .map((item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item.productName ?? "",
                                        style: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6),
                                        ),
                                      )))
                                  .toList(),
                              value: selectedValue,
                              onChanged: (value) {
                                debugPrint("${value?.productProps.toString()}");
                                setState(() {
                                  selectedValue = value;
                                });
                                idController.text = value == null
                                    ? ""
                                    : "${value.productId ?? 0}";
                                debugPrint(idController.text);
                              },
                              buttonStyleData: ButtonStyleData(
                                height: size.height * .07,
                                width: size.width / 3, //3.05,
                                padding:
                                    const EdgeInsets.only(left: 14, right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  // border: Border.all(
                                  //   color: Colors.grey.withOpacity(0.4),
                                  // ),
                                  color: Colors.white,
                                ),
                                //  elevation: 1,
                              ),
                              dropdownStyleData: const DropdownStyleData(
                                maxHeight: 300,
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                              ),
                              dropdownSearchData: DropdownSearchData(
                                searchController: textEditingController,
                                searchInnerWidgetHeight: 50,
                                searchInnerWidget: Container(
                                  height: 50,
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 4,
                                    right: 8,
                                    left: 8,
                                  ),
                                  child: TextFormField(
                                    expands: true,
                                    maxLines: null,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.27,
                                      Colors.black.withOpacity(0.6),
                                    ),
                                    controller: textEditingController,
                                    cursorColor: ColorManager.kPrimaryColor,
                                    decoration: decoration.copyWith(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      hintText: '',
                                      hintStyle: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.27,
                                        Colors.black.withOpacity(0.6),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                  ),
                                ),
                                searchMatchFn: (item, searchValue) {
                                  return item.value!.productName
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchValue.toLowerCase());
                                },
                              ),
                              //This to clear the search value when you close the menu
                              onMenuStateChange: (isOpen) {
                                if (!isOpen) {
                                  textEditingController.clear();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "From Date ",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s14,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        BuildBorderContainer(
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: CalendarPickerTableCell(
                            onDateSelected: (date) {
                              debugPrint(date.toString());
                              startDateController.text =
                                  DateFormat('yyyy-MM-dd').format(date);
                              debugPrint(DateFormat('yyyy-MM-dd')
                                  .format(date)
                                  .toString());
                            },
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "To Date ",
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s14,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        BuildBorderContainer(
                          margin: const EdgeInsets.only(left: 8),
                          height: 45,
                          width: 150, //size.width * 0.5,
                          child: Container(
                            height: size.height * .06,
                            width: size.width / 4.3,
                            margin: const EdgeInsets.only(left: 8),
                            child: CalendarPickerTableCell(
                              onDateSelected: (date) {
                                debugPrint(date.toString());
                                endDateController.text =
                                    DateFormat('yyyy-MM-dd').format(date);
                                debugPrint(DateFormat('yyyy-MM-dd')
                                    .format(date)
                                    .toString());
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Amount ",
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
                              controller: amountController,
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s10, 0.18, ColorManager.textColor),
                              decoration: decoration.copyWith(
                                  hintText: "Amount    ",
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
                      padding: const EdgeInsets.only(left: 10.0, top: 30),
                      child: CustomRoundButton(
                        title: "Search",
                        fct: searchAccountBook,
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
              Padding(
                padding: const EdgeInsets.only(top: 18.0),
                child: Text(
                  "Product Sales Report   ",
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ),
              const Divider(thickness: 0.5),
              BuildBoxShadowContainer(
                margin: const EdgeInsets.only(top: 20),
                circleRadius: 7,
                offsetValue: const Offset(1, 1),
                child: Table(
                  columnWidths: const {
                    0: FractionColumnWidth(0.06),
                    1: FractionColumnWidth(0.15),
                    2: FractionColumnWidth(0.15),
                    3: FractionColumnWidth(0.15),
                    4: FractionColumnWidth(0.15),
                    5: FractionColumnWidth(0.15),
                    6: FractionColumnWidth(0.10),
                  },
                  border: const TableBorder.symmetric(
                      outside: BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.3),
                      inside: BorderSide(
                          color: ColorManager.tableBOrderColor, width: 0.8)),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration:
                          const BoxDecoration(color: ColorManager.tableBGColor),
                      children: [
                        _buildTableHeader("No"),
                        _buildTableHeader("Product Name"),
                        _buildTableHeader("Category Name"),
                        _buildTableHeader("No. of Product Sold"),
                        _buildTableHeader("Unit Price"),
                        _buildTableHeader("Total Amount"),
                        _buildTableHeader("Action"),
                      ],
                    ),
                    if (reportsProvider.productSalesReport != null)
                      ...reportsProvider.productSalesReport!.data
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            _buildTableCell("${index + 1}"),
                            _buildTableCell(item.productName),
                            _buildTableCell(item.categoryName),
                            _buildTableCell(item.totalQuantity),
                            _buildTableCell(
                                AmountHelper.formatAmount(item.unitPrice)
                                    .toString()),
                            _buildTableCell(
                                AmountHelper.formatAmount(item.totalAmount)
                                    .toString()),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Center(
                                  child: BuildBoxShadowContainer(
                                    margin: const EdgeInsets.only(
                                        left: 5, right: 5),
                                    circleRadius: 5,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.visibility,
                                        size: 18,
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.9),
                                      ),
                                      onPressed: () {
                                        // Implement view action
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
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
}
