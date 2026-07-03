import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_pagination_control.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/customer_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'add_customer_modal.dart';

class CustomersMobileView extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String selectedBalanceFilter;
  final ValueChanged<String?> onBalanceChanged;
  final VoidCallback onReset;
  final VoidCallback onAddCustomer;

  const CustomersMobileView({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.selectedBalanceFilter,
    required this.onBalanceChanged,
    required this.onReset,
    required this.onAddCustomer,
  });

  @override
  State<CustomersMobileView> createState() => _CustomersMobileViewState();
}

class _CustomersMobileViewState extends State<CustomersMobileView> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const SizedBox(height: 8),
        _buildFiltersPanel(),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Customers',
          style: buildCustomStyle(
              FontWeightManager.semiBold, FontSize.s18, 0.25, ColorManager.textColor),
        ),
        ElevatedButton.icon(
          onPressed: widget.onAddCustomer,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add New', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
        leading: const Icon(Icons.filter_list, size: 18),
        title: Text(
          _filtersExpanded ? 'Hide Filters' : 'Show Filters',
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s12, 0.18, ColorManager.textColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _inputField(widget.nameController, 'Name'),
                const SizedBox(height: 8),
                _inputField(widget.emailController, 'Email'),
                const SizedBox(height: 8),
                _inputField(widget.phoneController, 'Phone'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: widget.selectedBalanceFilter,
                  items: ['All', 'Positive (+ve)', 'Negative (-ve)', 'Zero (0)']
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: widget.onBalanceChanged,
                  decoration: _inputDecoration('Balance'),
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: const BorderSide(color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Reset Filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      style: buildCustomStyle(
          FontWeightManager.medium, FontSize.s12, 0.18, ColorManager.textColor),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: buildCustomStyle(
          FontWeightManager.medium, FontSize.s12, 0.18, Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              const BorderSide(color: ColorManager.kPrimaryColor, width: 1.2)),
      isDense: true,
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
        if (customers == null || customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search,
                    size: 60,
                    color: ColorManager.kPrimaryColor.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('No customers found',
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s16, 0.27, ColorManager.textColor)),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  final balance = customer.balance ?? 0.0;
                  final isNeg = balance < 0;
                  final custType = (customer.customerType ?? 'B2C').toUpperCase();
                  final isB2B = custType == 'B2B';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                customer.name ?? '',
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s13,
                                    0.19,
                                    ColorManager.textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isB2B
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isB2B
                                        ? Colors.green.shade300
                                        : Colors.blue.shade300),
                              ),
                              child: Text(custType,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isB2B
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(customer.phone ?? '—',
                                style: buildCustomStyle(FontWeightManager.regular,
                                    FontSize.s12, 0.18, Colors.black87)),
                            const Spacer(),
                            Text(
                              'Balance: ${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isNeg ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              provider.selectCustomer(customers[index]);
                              sideBarController.index.value = 38;
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_outlined,
                                      size: 13,
                                      color: ColorManager.kPrimaryColor),
                                  const SizedBox(width: 4),
                                  Text('View',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: ColorManager.kPrimaryColor)),
                                ],
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
            const SizedBox(height: 8),
            PaginationControl(
              currentPage: provider.currentPage,
              totalPages: provider.totalPages,
              onPageChanged: (page) => provider.goToPage(page),
            ),
          ],
        );
      },
    );
  }
}