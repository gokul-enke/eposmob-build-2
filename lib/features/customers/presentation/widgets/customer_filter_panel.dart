import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

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
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String selectedBalanceFilter;
  final VoidCallback onSearch;
  final ValueChanged<String?> onBalanceChanged;
  final VoidCallback onReset;

  Widget _field({
    required String label,
    required Size size,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
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
          onchanged: (_) => onSearch(),
          onSubmitted: (_) => onSearch(),
          controller: controller,
          size: size,
          hintText: hintText,
        ),
      ],
    );
  }

  Widget _balanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Balance',
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
            items: ['All', 'Positive (+ve)', 'Negative (-ve)', 'Zero (0)']
                .map((balance) => DropdownMenuItem<String>(
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
                    ))
                .toList(),
            onChanged: onBalanceChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = available < 520
            ? 1
            : available < 900
                ? 2
                : 4;
        const gap = 15.0;
        final fieldWidth = (available - gap * (columns - 1)) / columns;
        final fields = [
          SizedBox(
              width: fieldWidth,
              child: _field(
                  label: 'Name',
                  size: size,
                  controller: nameController,
                  hintText: 'Name')),
          SizedBox(
              width: fieldWidth,
              child: _field(
                  label: 'Email',
                  size: size,
                  controller: emailController,
                  hintText: 'Email')),
          SizedBox(
              width: fieldWidth,
              child: _field(
                  label: 'Phone',
                  size: size,
                  controller: phoneController,
                  hintText: 'Phone')),
          SizedBox(width: fieldWidth, child: _balanceField()),
        ];

        return Column(
          children: [
            Wrap(spacing: gap, runSpacing: gap, children: fields),
            const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: columns == 1 ? double.infinity : 180,
                child: CustomRoundButton(
                  title: 'Reset',
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  fct: onReset,
                  height: 45,
                  width: double.infinity,
                  fontSize: FontSize.s12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
