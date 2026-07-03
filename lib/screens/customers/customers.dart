import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../../controllers/sidebar_controller.dart';
import '../../models/customer_list.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'add_customer_modal.dart';
import 'customers_mobile.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final customerNameController = TextEditingController();
  final customerEmailController = TextEditingController();
  final customerPhoneController = TextEditingController();
  String selectedBalanceFilter = 'All'; // Balance filter state
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCustomers();
    });
  }

  Widget _buildCustomerTypeBadge(String? type) {
    final t = (type ?? 'B2C').toUpperCase();
    final isB2B = t == 'B2B';
    final bg = isB2B ? Colors.green.shade50 : Colors.blue.shade50;
    final fg = isB2B ? Colors.green.shade700 : Colors.blue.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        t,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.18,
          fg,
        ),
      ),
    );
  }

  Future<void> loadCustomers() async {
    if (isInitialized) return;

    try {
      final String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }

      // Load all customers for local pagination
      await Provider.of<CustomerProvider>(context, listen: false)
          .loadAllCustomers(accessToken);
      setState(() {
        isInitialized = true;
      });
    } catch (error) {
      debugPrint("Error loading customers: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading customers: $error")),
      );
    }
  }

  void searchCustomers() {
    CustomerProvider provider =
        Provider.of<CustomerProvider>(context, listen: false);
    provider.applyFiltersLocally(
      filterName: customerNameController.text,
      filterEmail: customerEmailController.text,
      filterPhone: customerPhoneController.text,
      filterBalance:
          selectedBalanceFilter == 'All' ? null : selectedBalanceFilter,
      page: 1,
    );
  }

  void resetSearch() {
    setState(() {
      customerNameController.clear();
      customerEmailController.clear();
      customerPhoneController.clear();
      selectedBalanceFilter = 'All'; // Reset balance filter
    });
    Provider.of<CustomerProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    final String? accessToken =
        Provider.of<AuthModel>(context, listen: false).token;
    if (accessToken == null || accessToken.isEmpty) return;

    await Provider.of<CustomerProvider>(context, listen: false)
        .loadAllCustomers(accessToken);
  }

  Widget _buildFilterField({
    required String label,
    required Size size,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        buildColumnWidgetForTextFields(
          height: 45,
          width: double.infinity,
          onchanged: (value) {
            searchCustomers();
          },
          controller: controller,
          size: size,
          hintText: hintText,
        ),
      ],
    );
  }

  Widget _buildBalanceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Balance",
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          height: 45,
          width: double.infinity,
          color: Colors.white,
          child: DropdownButtonFormField<String>(
            value: selectedBalanceFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            hint: Text(
              'Select Balance',
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
            ),
            items: [
              'All',
              'Positive (+ve)',
              'Negative (-ve)',
              'Zero (0)'
            ].map((String balance) {
              return DropdownMenuItem<String>(
                value: balance,
                child: Text(
                  balance,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(.5),
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                selectedBalanceFilter = value ?? 'All';
              });
              searchCustomers();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  void _openCustomerProfile(
    CustomerProvider customerProvider,
    CustomerListModelData customer,
    SideBarController sideBarController,
  ) {
    customerProvider.selectCustomer(customer);
    sideBarController.index.value = 38;
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No customers found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard({
    required int displayNumber,
    required CustomerListModelData customer,
    required VoidCallback onView,
  }) {
    final double balance = customer.balance ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  customer.name != null && customer.name!.isNotEmpty
                      ? customer.name![0].toUpperCase()
                      : '#',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.2,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name ?? 'Unnamed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.2,
                        ColorManager.kTitleTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$displayNumber',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.1,
                        ColorManager.kGreyColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCustomerTypeBadge(customer.customerType),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCardMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Balance',
                  value: balance.toStringAsFixed(2),
                  valueColor:
                      balance >= 0 ? ColorManager.kSuccessColor : Colors.red,
                ),
              ),
              Expanded(
                child: _buildCardMetric(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: customer.phone ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.visibility,
                  size: 18, color: ColorManager.kPrimaryColor),
              label: Text(
                'View Profile',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.2,
                  ColorManager.kPrimaryColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: BorderSide(
                    color: ColorManager.kPrimaryColor.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetric({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ColorManager.kGreyColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s10,
                0.1,
                ColorManager.kGreyColor,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s12,
                0.1,
                valueColor ?? ColorManager.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(String text, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          textColor ?? Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    Size size = MediaQuery.of(context).size;

    final isMobile = size.width < 700;

    if (isMobile) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CustomersMobileView(
            nameController: customerNameController,
            emailController: customerEmailController,
            phoneController: customerPhoneController,
            selectedBalanceFilter: selectedBalanceFilter,
            onBalanceChanged: (val) {
              setState(() => selectedBalanceFilter = val ?? 'All');
              searchCustomers();
            },
            onReset: resetSearch,
            onAddCustomer: () =>
                showAddCustomerModal(context, size, mobileNumber: ''),
            onRefresh: refreshData,
            onSearch: searchCustomers,
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(
          children: [
            Container(
              margin: const EdgeInsets.only(
                  left: 10, top: 20, bottom: 0, right: 10),
              padding: const EdgeInsets.only(
                  left: 10, top: 20, bottom: 0, right: 10),
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
                padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 12,
                      spacing: 12,
                      children: [
                        Text(
                          'Customers',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                        CustomRoundButton(
                          title: "Add New Customer",
                          fct: () {
                            showAddCustomerModal(context, size, mobileNumber: '');
                          },
                          fontSize: 12,
                          height: 45,
                          width: 150,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double available = constraints.maxWidth;
                        // 1 column on phones, 2 on tablets, 4 on wide.
                        int columns = available < 520
                            ? 1
                            : available < 900
                                ? 2
                                : 4;
                        const double gap = 15;
                        final double fieldWidth =
                            (available - gap * (columns - 1)) / columns;
                        final filters = <Widget>[
                          SizedBox(
                            width: fieldWidth,
                            child: _buildFilterField(
                              label: "Name",
                              size: size,
                              controller: customerNameController,
                              hintText: 'Name',
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildFilterField(
                              label: "Email",
                              size: size,
                              controller: customerEmailController,
                              hintText: 'Email',
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildFilterField(
                              label: "Phone",
                              size: size,
                              controller: customerPhoneController,
                              hintText: 'Phone',
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildBalanceFilter(),
                          ),
                        ];
                        return Column(
                          children: [
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: filters,
                            ),
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: columns == 1 ? double.infinity : 180,
                                child: CustomRoundButton(
                                  title: "Reset",
                                  boxColor: Colors.white,
                                  textColor: ColorManager.kPrimaryColor,
                                  fct: () {
                                    resetSearch();
                                  },
                                  height: 45,
                                  width: double.infinity,
                                  fontSize: FontSize.s12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 500, // Set a fixed height or adjust as needed
                      child: Consumer<CustomerProvider>(
                        builder: (context, customerProvider, child) {
                          final isLoading = customerProvider.isLoading;
                          final customerList = customerProvider.getCustomerList;

                          return Column(
                            children: [
                              Expanded(
                                child: isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator
                                            .adaptive())
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          final bool isNarrow =
                                              constraints.maxWidth < 640;
                                          if (isNarrow) {
                                            if (customerList == null ||
                                                customerList.isEmpty) {
                                              return _buildEmptyState();
                                            }
                                            return ListView.builder(
                                              padding: const EdgeInsets.only(
                                                  top: 12, bottom: 8),
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              itemCount: customerList.length,
                                              itemBuilder: (context, index) {
                                                final customer =
                                                    customerList[index];
                                                return _buildCustomerCard(
                                                  displayNumber: index +
                                                      1 +
                                                      (customerProvider
                                                                  .currentPage -
                                                              1) *
                                                          customerProvider
                                                              .itemsPerPage,
                                                  customer: customer,
                                                  onView: () =>
                                                      _openCustomerProfile(
                                                    customerProvider,
                                                    customerList[index],
                                                    sideBarController,
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                          return BuildBoxShadowContainer(
                                        width: size.width,
                                        margin: const EdgeInsets.only(top: 20),
                                        circleRadius: 7,
                                        offsetValue: const Offset(1, 1),
                                        blurRadius: 8.0,
                                        color: Colors.white,
                                        child: Column(
                                          children: [
                                            // Fixed table header
                                            Container(
                                              decoration: const BoxDecoration(
                                                color:
                                                    ColorManager.tableBGColor,
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
                                                  0: FlexColumnWidth(0.5),
                                                  1: FlexColumnWidth(2.0),
                                                  2: FlexColumnWidth(2.0),
                                                  3: FlexColumnWidth(1.5),
                                                  4: FlexColumnWidth(1.2),
                                                  5: FlexColumnWidth(1.0),
                                                },
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  TableRow(
                                                    children: [
                                                      _buildTableHeader('No'),
                                                      _buildTableHeader('Name'),
                                                      _buildTableHeader(
                                                          'Balance'),
                                                      _buildTableHeader(
                                                          'Phone No.'),
                                                      _buildTableHeader(
                                                          'Customer Type'),
                                                      _buildTableHeader(
                                                          'Action'),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Scrollable table body
                                            Expanded(
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.grab,
                                                child: ScrollConfiguration(
                                                  behavior:
                                                      ScrollConfiguration.of(
                                                              context)
                                                          .copyWith(
                                                    dragDevices: {
                                                      PointerDeviceKind.mouse,
                                                      PointerDeviceKind.touch,
                                                      PointerDeviceKind.stylus,
                                                      PointerDeviceKind
                                                          .trackpad,
                                                    },
                                                  ),
                                                  child: SingleChildScrollView(
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    child:
                                                        customerList == null ||
                                                                customerList
                                                                    .isEmpty
                                                            ? Container(
                                                                height: 300,
                                                                width: double
                                                                    .infinity,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .person_search,
                                                                      size: 60,
                                                                      color: ColorManager
                                                                          .kPrimaryColor
                                                                          .withOpacity(
                                                                              0.7),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            15),
                                                                    Text(
                                                                      'No customers found',
                                                                      style:
                                                                          buildCustomStyle(
                                                                        FontWeightManager
                                                                            .medium,
                                                                        FontSize
                                                                            .s18,
                                                                        0.27,
                                                                        ColorManager
                                                                            .textColor,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                      'Try adjusting your search criteria',
                                                                      style:
                                                                          buildCustomStyle(
                                                                        FontWeightManager
                                                                            .regular,
                                                                        FontSize
                                                                            .s14,
                                                                        0.20,
                                                                        Colors
                                                                            .grey,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            : Table(
                                                                columnWidths: const {
                                                                  0: FlexColumnWidth(0.5),
                                                                  1: FlexColumnWidth(2.0),
                                                                  2: FlexColumnWidth(2.0),
                                                                  3: FlexColumnWidth(1.5),
                                                                  4: FlexColumnWidth(1.2),
                                                                  5: FlexColumnWidth(1.0),
                                                                },
                                                                border: null,
                                                                defaultVerticalAlignment:
                                                                    TableCellVerticalAlignment
                                                                        .middle,
                                                                children:
                                                                    customerList
                                                                        .asMap()
                                                                        .entries
                                                                        .map(
                                                                            (entry) {
                                                                  final int
                                                                      index =
                                                                      entry.key;
                                                                  final customer =
                                                                      entry
                                                                          .value;
                                                                  return TableRow(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: index %
                                                                                  2 ==
                                                                              0
                                                                          ? Colors
                                                                              .white
                                                                          : Colors
                                                                              .grey
                                                                              .withOpacity(0.1),
                                                                    ),
                                                                    children: [
                                                                      _buildTableCell(
                                                                          '${index + 1 + (customerProvider.currentPage - 1) * customerProvider.itemsPerPage}'),
                                                                      _buildTableCell(
                                                                          customer.name ??
                                                                              ''),
                                                                      _buildTableCell(
                                                                        customer.balance != null
                                                                            ? customer.balance!.toStringAsFixed(2)
                                                                            : '0.00',
                                                                        textColor: (customer.balance ?? 0) >= 0
                                                                            ? ColorManager.kSuccessColor
                                                                            : Colors.red,
                                                                      ),
                                                                      _buildTableCell(
                                                                          customer.phone ??
                                                                              ''),
                                                                      Center(
                                                                        child: _buildCustomerTypeBadge(customer.customerType),
                                                                      ),
                                                                      Center(
                                                                        child:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              8.0),
                                                                          child:
                                                                              BuildBoxShadowContainer(
                                                                            margin:
                                                                                const EdgeInsets.only(left: 5, right: 5),
                                                                            circleRadius:
                                                                                5,
                                                                            child:
                                                                                IconButton(
                                                                              icon: Icon(
                                                                                Icons.visibility,
                                                                                size: 18,
                                                                                color: ColorManager.kPrimaryColor.withOpacity(0.9),
                                                                              ),
                                                                              onPressed: () {
                                                                                _openCustomerProfile(customerProvider, customerList[index], sideBarController);
                                                                              },
                                                                              constraints: const BoxConstraints(
                                                                                minWidth: 36,
                                                                                minHeight: 36,
                                                                              ),
                                                                              padding: EdgeInsets.zero,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                }).toList(),
                                                              ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 10),
                              PaginationControl(
                                currentPage: customerProvider.currentPage,
                                totalPages: customerProvider.totalPages,
                                onPageChanged: (int page) {
                                  customerProvider.goToPage(page);
                                },
                              ),
                              const SizedBox(height: 25),
                            ],
                          );
                        },
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
