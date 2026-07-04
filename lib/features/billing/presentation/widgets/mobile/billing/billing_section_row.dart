import 'package:flutter/material.dart';

/// Tappable, card-style summary row used on the mobile Billing tab in place
/// of an accordion section. Shows a leading icon, a title, a value/subtitle
/// describing the current selection, and a trailing chevron (or a caller
/// supplied trailing widget, e.g. a small "clear" button on the coupon row).
///
/// Matches the visual language of [BillingAccordionCard]'s header: same card
/// color, radius, and padding.
class BillingSectionRow extends StatelessWidget {
  const BillingSectionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.isHighlighted = false,
    this.trailing,
  });

  /// Leading icon representing the section (e.g. delivery, coupon, payment).
  final IconData icon;

  /// Section title, e.g. "Select Delivery Method".
  final String title;

  /// Current selection/value text shown as a secondary line, e.g.
  /// "Door Delivery" or "No coupon applied".
  final String value;

  /// Invoked when the row is tapped (typically opens a bottom sheet).
  final VoidCallback onTap;

  /// When true, [value] is rendered in a highlighted/success color, e.g. for
  /// an applied coupon or a fully-selected payment method.
  final bool isHighlighted;

  /// Optional override for the trailing widget. Defaults to a
  /// [Icons.chevron_right] icon. Pass a small clear button, for instance, to
  /// let the coupon row clear itself without opening the sheet.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF0066CC),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0066CC),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight:
                            isHighlighted ? FontWeight.w600 : FontWeight.w500,
                        color: isHighlighted
                            ? const Color(0xFF15803D)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.black54,
                    size: 24,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
