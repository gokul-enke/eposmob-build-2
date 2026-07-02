import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// A compact label/value row for mobile detail views.
///
/// - [label] is rendered as a small muted caption.
/// - [value] is selectable and may be highlighted (e.g. prices) via
///   [highlight] or coloured explicitly via [valueColor].
/// - [trailing] hosts optional actions (badges, inline icon buttons).
/// - When [copyable] is true and [value] is meaningful, a small copy chip is
///   rendered as the trailing affordance.
class MobileDetailRow extends StatelessWidget {
  const MobileDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.highlight = false,
    this.trailing,
    this.copyable = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool highlight;
  final Widget? trailing;
  final bool copyable;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty && value != 'N/A';
    final effectiveColor = valueColor ??
        (highlight ? ColorManager.kPrimaryColor : Colors.black87);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (copyable && hasValue && trailing == null)
                MobileCopyChip(value: value, label: label),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small, tappable copy affordance used by [MobileDetailRow] and other
/// inline contexts. Copies [value] to the clipboard and shows a scaffold
/// message via the parent [Scaffold].
class MobileCopyChip extends StatelessWidget {
  const MobileCopyChip({
    super.key,
    required this.value,
    this.label,
    this.iconSize = 16,
  });

  final String value;
  final String? label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label != null
                ? '$label copied to clipboard'
                : 'Copied to clipboard'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: ColorManager.kPrimaryWithOpacity10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: iconSize, color: ColorManager.kPrimaryColor),
            const SizedBox(width: 4),
            const Text(
              'Copy',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorManager.kPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
