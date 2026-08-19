import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:provider/provider.dart';

import '../../controllers/sidebar_controller.dart';
import '../../features/customers/presentation/widgets/customer_card_list.dart';
import '../../features/customers/presentation/widgets/customer_desktop_table.dart';
import '../../features/customers/presentation/widgets/customer_filter_panel.dart';
import '../../features/customers/presentation/widgets/customer_page_header.dart';
import '../../features/customers/presentation/widgets/customer_ui.dart';
import '../../models/customer_list.dart';
import '../../providers/auth_model.dart';
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
  String selectedBalanceFilter = 'All';
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCustomers();
    });
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerEmailController.dispose();
    customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> loadCustomers() async {
    if (isInitialized) return;

    try {
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('customers.msg_token_missing'.tr)),
        );
        return;
      }

      await Provider.of<CustomerProvider>(context, listen: false)
          .loadAllCustomers(accessToken);
      if (!mounted) return;
      setState(() => isInitialized = true);
    } catch (error) {
      debugPrint('Error loading customers: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('customers.msg_load_error'.trParams({'error': '$error'}))),
      );
    }
  }

  void searchCustomers() {
    Provider.of<CustomerProvider>(context, listen: false).applyFiltersLocally(
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
      selectedBalanceFilter = 'All';
    });
    Provider.of<CustomerProvider>(context, listen: false).resetFilters();
  }

  Future<void> refreshData() async {
    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
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
    final sideBarController = Get.put(SideBarController());
    final size = MediaQuery.of(context).size;

    if (size.width < 700) {
      return SafeArea(
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CustomersMobileView(
              nameController: customerNameController,
              emailController: customerEmailController,
              phoneController: customerPhoneController,
              selectedBalanceFilter: selectedBalanceFilter,
              onBalanceChanged: (value) {
                setState(() => selectedBalanceFilter = value ?? 'All');
                searchCustomers();
              },
              onReset: resetSearch,
              onAddCustomer: () =>
                  showAddCustomerModal(context, size, mobileNumber: ''),
              onRefresh: refreshData,
              onSearch: searchCustomers,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomerPageHeader(
                    onRefresh: () {
                      refreshData();
                    },
                    onAddCustomer: () {
                      showAddCustomerModal(
                        context,
                        size,
                        mobileNumber: '',
                      );
                    },
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 14),
                  Expanded(
                    child: Consumer<CustomerProvider>(
                      builder: (context, customerProvider, child) {
                        final isLoading = customerProvider.isLoading;
                        final customerList = customerProvider.getCustomerList;

                        if (isLoading) {
                          return const CustomerSurface(
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 720;
                            final Widget list;

                            if (isNarrow) {
                              list = CustomerCardList(
                                customers: customerList,
                                currentPage: customerProvider.currentPage,
                                itemsPerPage: customerProvider.itemsPerPage,
                                onRefresh: refreshData,
                                onViewCustomer: (customer) {
                                  _openCustomerProfile(
                                    customerProvider,
                                    customer,
                                    sideBarController,
                                  );
                                },
                              );
                            } else {
                              list = CustomerDesktopTable(
                                customers: customerList,
                                currentPage: customerProvider.currentPage,
                                itemsPerPage: customerProvider.itemsPerPage,
                                onRefresh: refreshData,
                                onViewCustomer: (customer) {
                                  _openCustomerProfile(
                                    customerProvider,
                                    customer,
                                    sideBarController,
                                  );
                                },
                              );
                            }

                            return Column(
                              children: [
                                Expanded(child: list),
                                const SizedBox(height: 8),
                                CustomerPaginationBar(
                                  currentPage: customerProvider.currentPage,
                                  totalPages: customerProvider.totalPages,
                                  visibleItemCount: customerList?.length ?? 0,
                                  onPageChanged: customerProvider.goToPage,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
