import 'package:flutter/material.dart';

class SalesActionIcon extends StatelessWidget {
  const SalesActionIcon(
      {super.key,
      required this.icon,
      required this.color,
      required this.onPressed});
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: onPressed,
      ),
    );
  }
}
