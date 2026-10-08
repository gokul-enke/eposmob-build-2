import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class LocalSalesHeader extends StatelessWidget {
  const LocalSalesHeader({super.key, required this.visibleCount});
  final int visibleCount;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync attention',
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Review saved sales that did not receive a verified server response.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Builder(
            builder: (context) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: visibleCount == 0
                      ? const Color(0xFFEAF7EF)
                      : const Color(0xFFFFF3DE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: visibleCount == 0
                        ? const Color(0xFFB7E4C7)
                        : const Color(0xFFF5D49B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      visibleCount == 0
                          ? Icons.cloud_done_outlined
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: visibleCount == 0
                          ? const Color(0xFF16764A)
                          : const Color(0xFF9A5B07),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      visibleCount == 0
                          ? 'No sales need review'
                          : '$visibleCount sale${visibleCount == 1 ? '' : 's'} need review',
                      style: TextStyle(
                        color: visibleCount == 0
                            ? const Color(0xFF16764A)
                            : const Color(0xFF9A5B07),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
