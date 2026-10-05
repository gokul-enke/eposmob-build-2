import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/responsive.dart';

class OrderExpandableSection extends StatefulWidget {
  final String title;
  final TextStyle titleStyle;
  final Widget child;

  const OrderExpandableSection({
    required this.title,
    required this.titleStyle,
    required this.child,
  });

  @override
  State<OrderExpandableSection> createState() => OrderExpandableSectionState();
}

class OrderExpandableSectionState extends State<OrderExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    return BuildBoxShadowContainer(
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.only(
        top: 8.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.title, style: widget.titleStyle),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ColorManager.kPrimaryColor,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            widget.child,
          ],
        ],
      ),
    );
  }
}
