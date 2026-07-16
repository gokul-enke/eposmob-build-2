import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:provider/provider.dart';
import '../../controllers/sidebar_controller.dart';
import '../../features/customers/presentation/widgets/customer_card_list.dart';
import '../../features/customers/presentation/widgets/customer_desktop_table.dart';
import '../../features/customers/presentation/widgets/customer_page_header.dart';
import '../../models/customer_list.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
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
                    CustomerPageHeader(
                      onAddCustomer: () {
                        showAddCustomerModal(
                          context,
                          size,
                          mobileNumber: '',
                        );
                      },
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
                                            return CustomerCardList(
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
