import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Collapsible, card-styled section for grouping related detail fields on
/// mobile sheets. Mirrors the visual language of [BillingAccordionCard] but is
/// generic (icon + title + optional badge + any child) so it can be reused
/// across product details, view and edit tabs.
class MobileDetailSection extends StatefulWidget {
  const MobileDetailSection({
    super.key,
    required this.title,
    this.icon,
    this.badge,
    this.child,
    this.children,
    this.initiallyExpanded = true,
    this.padding,
    this.headerColor,
  });

  final String title;
  final IconData? icon;
  final Widget? badge;
  final Widget? child;
  final List<Widget>? children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? padding;
  final Color? headerColor;

  @override
  State<MobileDetailSection> createState() => _MobileDetailSectionState();
}

class _MobileDetailSectionState extends State<MobileDetailSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    const Radius topRadius = Radius.circular(12);
    final Radius bottomRadius =
        _isExpanded ? Radius.zero : const Radius.circular(12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: topRadius,
              bottom: bottomRadius,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: widget.headerColor ?? const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  top: topRadius,
                  bottom: bottomRadius,
                ),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 18,
                      color: ColorManager.kPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                  if (widget.badge != null) ...[
                    widget.badge!,
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black54,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: widget.child ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children ?? const [],
                  ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
