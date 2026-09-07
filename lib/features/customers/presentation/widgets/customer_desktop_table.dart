import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'customer_ui.dart';

class CustomerDesktopTable extends StatelessWidget {
  const CustomerDesktopTable({
    super.key,
    required this.customers,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onViewCustomer,
    this.onRefresh,
  });

  final List<CustomerListModelData>? customers;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<CustomerListModelData> onViewCustomer;
  final Future<void> Function()? onRefresh;

  static const Map<int, TableColumnWidth> _columnWidths = {
    0: FlexColumnWidth(0.55),
    1: FlexColumnWidth(2.3),
    2: FlexColumnWidth(1.25),
    3: FlexColumnWidth(1.55),
    4: FlexColumnWidth(1.2),
    5: FlexColumnWidth(1.15),
  };

  Widget _headerCell(String text, {TextAlign alignment = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      child: Text(
        text,
        textAlign: alignment,
        style: const TextStyle(
          color: CustomerUiColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _bodyCell(
    String text, {
    Color? textColor,
    FontWeight fontWeight = FontWeight.w500,
    TextAlign alignment = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment,
        style: TextStyle(
          color: textColor ?? CustomerUiColors.body,
          fontSize: 13,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  List<TableRow> _rows() {
    return (customers ?? []).asMap().entries.map((entry) {
      final index = entry.key;
      final customer = entry.value;
      final balance = customer.balance ?? 0;
      final displayNumber = index + 1 + (currentPage - 1) * itemsPerPage;
      final name = CustomerDisplay.name(customer.name);

      return TableRow(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: CustomerUiColors.subtleBorder),
          ),
        ),
        children: [
          _bodyCell(
            '$displayNumber',
            textColor: CustomerUiColors.muted,
            alignment: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            child: Row(
              children: [
                CustomerAvatar(name: customer.name, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CustomerUiColors.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bodyCell(
            balance.toStringAsFixed(2),
            textColor:
                balance >= 0 ? CustomerUiColors.green : CustomerUiColors.red,
            fontWeight: FontWeight.w700,
          ),
          _bodyCell(
            customer.phone?.isNotEmpty == true ? customer.phone! : '—',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CustomerTypeBadge(type: customer.customerType),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onViewCustomer(customer),
                icon: const Icon(Icons.visibility, size: 15),
                label: Text('customers.view'.tr),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: ColorManager.kPrimaryColor,
                  side: const BorderSide(color: CustomerUiColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _scrollableBody() {
    final body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: customers == null || customers!.isEmpty
          ? const SizedBox(height: 310, child: CustomerEmptyState())
          : Table(
              columnWidths: _columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: _rows(),
            ),
    );

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: CustomerUiColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              color: CustomerUiColors.canvas,
              child: Table(
                columnWidths: _columnWidths,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _headerCell('customers.col_no'.tr, alignment: TextAlign.center),
                      _headerCell('customers.col_customer'.tr),
                      _headerCell('customers.col_balance'.tr),
                      _headerCell('customers.col_phone'.tr),
                      _headerCell('customers.col_type'.tr),
                      _headerCell('customers.col_action'.tr),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: _scrollableBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
