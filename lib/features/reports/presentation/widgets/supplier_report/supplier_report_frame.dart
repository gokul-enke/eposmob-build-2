import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class SupplierReportFrame extends StatelessWidget {
  const SupplierReportFrame(
      {super.key,
      required this.showFilters,
      required this.onRefresh,
      required this.header,
      required this.filters,
      required this.content,
      required this.pagination});
  final bool showFilters;
  final Future<void> Function() onRefresh;
  final Widget header, filters, content, pagination;
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isMobile ? 5 : 10,
            vertical: isMobile ? 10 : 20,
          ),
          padding: EdgeInsets.all(isMobile ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: ColorManager.boxShadowColor,
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
            color: Colors.white,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 12.0 : 20.0,
              horizontal: isMobile ? 12.0 : 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 15),
                if (showFilters)
                  KeyedSubtree(
                    key: const ValueKey('supplier-transactions-report-filters'),
                    child: filters,
                  ),
                if (showFilters) const SizedBox(height: 20),
                content,
                const SizedBox(height: 10),
                pagination,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
