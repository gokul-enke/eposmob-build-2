import 'package:flutter/material.dart';

class LocalSalesHeader extends StatelessWidget {
  const LocalSalesHeader({super.key, required this.visibleCount});
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    const title =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sync attention',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B))),
      SizedBox(height: 6),
      Text('Review requests, edit JSON and sync saved orders.',
          style:
              TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.45)),
    ]);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: visibleCount == 0
              ? const Color(0xFFEAF7EF)
              : const Color(0xFFFFF3DE),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            visibleCount == 0
                ? Icons.cloud_done_outlined
                : Icons.warning_amber_rounded,
            size: 18,
            color: visibleCount == 0
                ? const Color(0xFF16764A)
                : const Color(0xFF9A5B07)),
        const SizedBox(width: 7),
        Flexible(
            child: Text(
                visibleCount == 0
                    ? 'No orders need attention'
                    : '$visibleCount order${visibleCount == 1 ? '' : 's'} need attention',
                style: TextStyle(
                    color: visibleCount == 0
                        ? const Color(0xFF16764A)
                        : const Color(0xFF9A5B07),
                    fontSize: 13,
                    fontWeight: FontWeight.w600))),
      ]),
    );
    return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 650
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 12), badge])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(child: title),
                const SizedBox(width: 24),
                badge
              ]));
  }
}
