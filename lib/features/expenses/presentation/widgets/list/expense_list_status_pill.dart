import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

/// Status pill with colour derived from the status string (visual only).
class ExpenseListStatusPill extends StatelessWidget {
  final String status;

  const ExpenseListStatusPill({super.key, required this.status});

  String _statusLabel(String normalized) {
    if (normalized.contains('SUCC') || normalized.contains('PAID')) {
      return 'transaction_status_labels.succ'.tr;
    }
    if (normalized.contains('PEND') || normalized.contains('WAIT')) {
      return 'quotations.status_pending'.tr;
    }
    if (normalized.contains('FAIL') || normalized.contains('REJ')) {
      return 'transaction_status_labels.fail'.tr;
    }
    if (normalized.contains('INIT')) {
      return 'transaction_status_labels.init'.tr;
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    Color fg;
    Color bg;

    if (normalized.contains('SUCC') || normalized.contains('PAID')) {
      fg = Colors.green.shade700;
      bg = Colors.green.withOpacity(0.12);
    } else if (normalized.contains('PEND') || normalized.contains('WAIT')) {
      fg = Colors.orange.shade800;
      bg = Colors.orange.withOpacity(0.12);
    } else if (normalized.contains('FAIL') || normalized.contains('REJ')) {
      fg = Colors.red.shade700;
      bg = Colors.red.withOpacity(0.12);
    } else {
      fg = ColorManager.kPrimaryColor;
      bg = ColorManager.kPrimaryColor.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        _statusLabel(normalized),
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s10,
          0.05,
          fg,
        ),
      ),
    );
  }
}
