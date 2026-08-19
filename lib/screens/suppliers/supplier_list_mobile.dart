import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_pagination_control.dart';
import '../../controllers/sidebar_controller.dart';
import '../../providers/supplier_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class SupplierListMobileView extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String selectedBalanceFilter;
  final ValueChanged<String?> onBalanceChanged;
  final VoidCallback onReset;
  final VoidCallback onAddSupplier;
  final Function({String name, String email, String phone, String balance})
      onSearch;

  const SupplierListMobileView({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.selectedBalanceFilter,
    required this.onBalanceChanged,
    required this.onReset,
    required this.onAddSupplier,
    required this.onSearch,
  });

  @override
  State<SupplierListMobileView> createState() => _SupplierListMobileViewState();
}

class _SupplierListMobileViewState extends State<SupplierListMobileView> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildFiltersPanel(),
        const SizedBox(height: 8),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'supplier_list_mobile.title'.tr,
          style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
              0.25, ColorManager.textColor),
        ),
        ElevatedButton.icon(
          onPressed: widget.onAddSupplier,
          icon: const Icon(Icons.add, size: 16),
          label: Text('supplier_list_mobile.btn_add_new'.tr, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
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
          _filtersExpanded ? 'supplier_list_mobile.hide_filters'.tr : 'supplier_list_mobile.show_filters'.tr,
          style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
              0.18, ColorManager.textColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _inputField(widget.nameController, 'supplier_list_mobile.hint_name'.tr, (v) {
                  widget.onSearch(
                    name: v,
                    email: widget.emailController.text,
                    phone: widget.phoneController.text,
                    balance: widget.selectedBalanceFilter,
                  );
                }),
                const SizedBox(height: 8),
                _inputField(widget.emailController, 'supplier_list_mobile.hint_email'.tr, (v) {
                  widget.onSearch(
                    name: widget.nameController.text,
                    email: v,
                    phone: widget.phoneController.text,
                    balance: widget.selectedBalanceFilter,
                  );
                }),
                const SizedBox(height: 8),
                _inputField(widget.phoneController, 'supplier_list_mobile.hint_phone'.tr, (v) {
                  widget.onSearch(
                    name: widget.nameController.text,
                    email: widget.emailController.text,
                    phone: v,
                    balance: widget.selectedBalanceFilter,
                  );
                }),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: widget.selectedBalanceFilter,
                  items: ['All', 'Positive (+ve)', 'Negative (-ve)', 'Zero (0)']
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: widget.onBalanceChanged,
                  decoration: _inputDecoration('supplier_list_mobile.hint_balance'.tr),
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side:
                          const BorderSide(color: ColorManager.kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('supplier_list_mobile.btn_reset'.tr),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint,
      ValueChanged<String> onChanged) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(
              color: ColorManager.kPrimaryColor, width: 1.2)),
      isDense: true,
    );
  }

  Widget _buildList() {
    return Consumer<SupplierProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final suppliers = provider.supplierList ?? [];
        if (suppliers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business,
                    size: 60,
                    color: ColorManager.kPrimaryColor.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('supplier_list_mobile.no_suppliers'.tr,
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
                itemCount: suppliers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  final balance = supplier.currentBalance;
                  final isNeg = balance < 0;

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
                        Text(
                          supplier.name,
                          style: buildCustomStyle(FontWeightManager.semiBold,
                              FontSize.s13, 0.19, ColorManager.textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                supplier.email.isNotEmpty
                                    ? supplier.email
                                    : '—',
                                style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s11,
                                    0.16,
                                    Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              supplier.phone.isNotEmpty ? supplier.phone : '—',
                              style: buildCustomStyle(FontWeightManager.regular,
                                  FontSize.s11, 0.16, Colors.black87),
                            ),
                            const Spacer(),
                            Text(
                              'supplier_list_mobile.balance_prefix'.trParams({'amount': balance.toStringAsFixed(2)}),
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
                              provider.selectSupplier(supplier);
                              Get.find<SideBarController>().index.value = 69;
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
                                  Text('supplier_list_mobile.btn_view'.tr,
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