import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:provider/provider.dart';
import '../../controllers/sidebar_controller.dart';
import '../../features/customers/presentation/widgets/customer_desktop_table.dart';
import '../../models/customer_list.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'add_customer_modal.dart';
import 'customers_mobile.dart';
import '../../features/customers/presentation/widgets/customer_filter_panel.dart';

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
                            showAddCustomerModal(context, size,
                                mobileNumber: '');
                          },
                          fontSize: 12,
                          height: 45,
                          width: 150,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    CustomerFilterPanel(
                      nameController: customerNameController,
                      emailController: customerEmailController,
                      phoneController: customerPhoneController,
                      selectedBalanceFilter: selectedBalanceFilter,
                      onSearch: searchCustomers,
                      onBalanceChanged: (value) {
                        setState(() {
                          selectedBalanceFilter = value ?? 'All';
                        });
                        searchCustomers();
                      },
                      onReset: resetSearch,
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
                                            margin:
                                                const EdgeInsets.only(top: 20),
                                            circleRadius: 7,
                                            offsetValue: const Offset(1, 1),
                                            blurRadius: 8.0,
                                            color: Colors.white,
                                            child: CustomerDesktopTable(
                                              customers: customerList,
                                              currentPage:
                                                  customerProvider.currentPage,
                                              itemsPerPage:
                                                  customerProvider.itemsPerPage,
                                              onViewCustomer: (customer) {
                                                _openCustomerProfile(
                                                  customerProvider,
                                                  customer,
                                                  sideBarController,
                                                );
                                              },
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
