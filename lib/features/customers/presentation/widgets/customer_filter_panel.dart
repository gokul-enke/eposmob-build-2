import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'customer_ui.dart';

class CustomerFilterPanel extends StatelessWidget {
  const CustomerFilterPanel({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.selectedBalanceFilter,
    required this.onSearch,
    required this.onBalanceChanged,
    required this.onReset,
    this.showHeader = true,
    this.useSurface = true,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String selectedBalanceFilter;
  final VoidCallback onSearch;
  final ValueChanged<String?> onBalanceChanged;
  final VoidCallback onReset;
  final bool showHeader;
  final bool useSurface;

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: CustomerUiColors.border),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      labelStyle: const TextStyle(
        color: CustomerUiColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9A9A9A),
        fontSize: 13,
      ),
      prefixIconColor: CustomerUiColors.muted,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: ColorManager.kPrimaryColor, width: 1.5),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      onChanged: (_) => onSearch(),
      onFieldSubmitted: (_) => onSearch(),
      style: const TextStyle(
        color: CustomerUiColors.heading,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(label: label, hint: hint, icon: icon),
    );
  }

  Widget _balanceField() {
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedBalanceFilter),
      initialValue: selectedBalanceFilter,
      isExpanded: true,
      decoration: _decoration(
        label: 'customers.balance'.tr,
        hint: 'customers.all_balances'.tr,
        icon: Icons.account_balance_wallet_outlined,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(10),
      style: const TextStyle(
        color: CustomerUiColors.heading,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      items: const ['All', 'Positive (+ve)', 'Negative (-ve)', 'Zero (0)']
          .map(
            (balance) => DropdownMenuItem<String>(
              value: balance,
              child: Text(switch (balance) {
                'Positive (+ve)' => 'customers.positive'.tr,
                'Negative (-ve)' => 'customers.negative'.tr,
                'Zero (0)' => 'customers.zero'.tr,
                _ => 'customers.all'.tr,
              }),
            ),
          )
          .toList(),
      onChanged: onBalanceChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = available < 540
            ? 1
            : available < 940
                ? 2
                : 4;
        const gap = 12.0;
        final fieldWidth = (available - gap * (columns - 1)) / columns;
        final fields = [
          SizedBox(
            width: fieldWidth,
            child: _field(
              controller: nameController,
              label: 'customers.name'.tr,
              hint: 'customers.search_name'.tr,
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _field(
              controller: emailController,
              label: 'customers.email'.tr,
              hint: 'customers.search_email'.tr,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: _field(
              controller: phoneController,
              label: 'customers.phone'.tr,
              hint: 'customers.search_phone'.tr,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ),
          SizedBox(width: fieldWidth, child: _balanceField()),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  Container(
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'customers.find'.tr,
                          style: const TextStyle(
                            color: CustomerUiColors.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'customers.find_hint'.tr,
                          style: const TextStyle(
                            color: CustomerUiColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                    label: Text('customers.reset'.tr),
                    style: TextButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: fields,
            ),
            if (!showHeader) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset filters'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: ColorManager.kPrimaryColor,
                    side: const BorderSide(color: CustomerUiColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (!useSurface) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: content,
      );
    }

    return CustomerSurface(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}
