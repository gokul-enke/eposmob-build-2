import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class StockListCompactValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? valueBgColor;
  final bool copyable;
  const StockListCompactValue(
      {super.key,
      required this.label,
      required this.value,
      required this.valueColor,
      required this.valueBgColor,
      required this.copyable});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          valueBgColor != null
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: valueBgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s12,
                      0.18,
                      valueColor ?? Colors.white,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s12,
                          0.18,
                          valueColor ?? ColorManager.textColor,
                        ),
                      ),
                    ),
                    if (copyable &&
                        value.isNotEmpty &&
                        value != 'stock.na'.tr) ...[
                      const SizedBox(width: 6),
                      Builder(
                        builder: (context) => GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: value));
                            showScaffold(
                              context: context,
                              message: 'stock.copied_to_clipboard'
                                  .tr
                                  .replaceAll('@label', label),
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ],
      ),
    );
  }
}
