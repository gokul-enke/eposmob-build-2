import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../controllers/sidebar_controller.dart';
import '../../features/customers/presentation/widgets/customer_card_list.dart';
import '../../features/customers/presentation/widgets/customer_filter_panel.dart';
import '../../features/customers/presentation/widgets/customer_page_header.dart';
import '../../features/customers/presentation/widgets/customer_ui.dart';
import '../../providers/customer_provider.dart';

class CustomersMobileView extends StatefulWidget {
  const CustomersMobileView({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.selectedBalanceFilter,
    required this.onBalanceChanged,
    required this.onReset,
    required this.onAddCustomer,
    required this.onRefresh,
    required this.onSearch,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String selectedBalanceFilter;
  final ValueChanged<String?> onBalanceChanged;
  final VoidCallback onReset;
  final VoidCallback onAddCustomer;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;

  @override
  State<CustomersMobileView> createState() => _CustomersMobileViewState();
}

class _CustomersMobileViewState extends State<CustomersMobileView> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomerPageHeader(
          onAddCustomer: widget.onAddCustomer,
          onRefresh: () {
            widget.onRefresh();
          },
        ),
        const SizedBox(height: 12),
        CustomerSurface(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: _filtersExpanded,
              onExpansionChanged: (value) {
                setState(() => _filtersExpanded = value);
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: EdgeInsets.zero,
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CustomerUiColors.canvas,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: CustomerUiColors.body,
                ),
              ),
              title: const Text(
                'Search and filters',
                style: TextStyle(
                  color: CustomerUiColors.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _filtersExpanded
                    ? 'Hide filter controls'
                    : 'Name, email, phone and balance',
                style: const TextStyle(
                  color: CustomerUiColors.muted,
                  fontSize: 11,
                ),
              ),
              children: [
                CustomerFilterPanel(
                  nameController: widget.nameController,
                  emailController: widget.emailController,
                  phoneController: widget.phoneController,
                  selectedBalanceFilter: widget.selectedBalanceFilter,
                  onSearch: widget.onSearch,
                  onBalanceChanged: widget.onBalanceChanged,
                  onReset: widget.onReset,
                  showHeader: false,
                  useSurface: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final sideBarController = Get.find<SideBarController>();

    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final customers = provider.getCustomerList;
        return Column(
          children: [
            Expanded(
              child: CustomerCardList(
                customers: customers,
                currentPage: provider.currentPage,
                itemsPerPage: provider.itemsPerPage,
                onRefresh: widget.onRefresh,
                onViewCustomer: (customer) {
                  provider.selectCustomer(customer);
                  sideBarController.index.value = 38;
                },
              ),
            ),
            const SizedBox(height: 8),
            CustomerPaginationBar(
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              visibleItemCount: customers?.length ?? 0,
              onPageChanged: provider.goToPage,
            ),
          ],
        );
      },
    );
  }
}
