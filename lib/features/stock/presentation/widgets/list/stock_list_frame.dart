import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/product/widgets/stock_responsive.dart';

class StockListFrame extends StatelessWidget {
  final bool showFilters;
  final Widget header;
  final Widget filters;
  final Widget content;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  const StockListFrame(
      {super.key,
      required this.showFilters,
      required this.header,
      required this.filters,
      required this.content,
      required this.currentPage,
      required this.totalPages,
      required this.onPageChanged});
  @override
  Widget build(BuildContext context) {
    final bool isMobile = stockIsPhone(context);
    final double horizontalMargin = isMobile ? 8 : 10;
    final double horizontalPadding = isMobile ? 12 : 20;

    return SafeArea(
      child: Container(
        margin: EdgeInsetsDirectional.only(
          start: horizontalMargin,
          end: horizontalMargin,
          top: isMobile ? 8 : 10,
          bottom: isMobile ? 8 : 10,
        ),
        padding: EdgeInsets.all(isMobile ? 4 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 22),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
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
          padding: EdgeInsetsDirectional.symmetric(
            vertical: isMobile ? 12.0 : 5.0,
            horizontal: horizontalPadding,
          ),
          child: isMobile
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 10),
                      if (showFilters)
                        KeyedSubtree(
                          key: const ValueKey('stock-mobile-filters'),
                          child: filters,
                        ),
                      const SizedBox(height: 10),
                      content,
                      const SizedBox(height: 10),
                      StockPaginationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onPageChanged: onPageChanged,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    if (showFilters) ...[
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: const ValueKey('stock-desktop-filters'),
                        child: filters,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: content,
                          ),
                          const SizedBox(height: 10),
                          PaginationControl(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            onPageChanged: onPageChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
