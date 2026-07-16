import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerPageHeader extends StatelessWidget {
  const CustomerPageHeader({
    super.key,
    required this.onAddCustomer,
  });

  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
          title: 'Add New Customer',
          fct: onAddCustomer,
          fontSize: 12,
          height: 45,
          width: 150,
        ),
      ],
    );
  }
}
