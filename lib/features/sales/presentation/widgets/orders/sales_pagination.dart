import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_pagination_control.dart';

/// Delegates to the existing pagination control without changing its layout.
class SalesPagination extends StatelessWidget {
  const SalesPagination(
      {super.key,
      required this.currentPage,
      required this.totalPages,
      required this.onPageChanged});
  final int currentPage, totalPages;
  final ValueChanged<int> onPageChanged;
  @override
  Widget build(BuildContext context) => PaginationControl(
      currentPage: currentPage,
      totalPages: totalPages,
      onPageChanged: onPageChanged);
}
