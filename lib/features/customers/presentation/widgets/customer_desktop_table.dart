import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerDesktopTable extends StatelessWidget {
  const CustomerDesktopTable({
    super.key,
    required this.customers,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onViewCustomer,
  });

  final List<CustomerListModelData>? customers;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<CustomerListModelData> onViewCustomer;

  static const Map<int, TableColumnWidth> _columnWidths = {
    0: FlexColumnWidth(0.5),
    1: FlexColumnWidth(2),
    2: FlexColumnWidth(2),
    3: FlexColumnWidth(1.5),
    4: FlexColumnWidth(1.2),
    5: FlexColumnWidth(1),
  };

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _bodyCell(String text, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s9,
          0.13,
          textColor ?? Colors.black,
        ),
      ),
    );
  }

  Widget _customerTypeBadge(String? type) {
    final value = (type ?? 'B2C').toUpperCase();
    final isB2B = value == 'B2B';
    final background = isB2B ? Colors.green.shade50 : Colors.blue.shade50;
    final foreground = isB2B ? Colors.green.shade700 : Colors.blue.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withOpacity(0.3)),
      ),
      child: Text(
        value,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.18,
          foreground,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      height: 300,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 15),
          Text(
            'No customers found',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s18,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.20,
              Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  List<TableRow> _rows() {
    return (customers ?? []).asMap().entries.map((entry) {
      final index = entry.key;
      final customer = entry.value;
      final balance = customer.balance ?? 0;
      final displayNumber = index + 1 + (currentPage - 1) * itemsPerPage;

      return TableRow(
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : Colors.grey.withOpacity(0.1),
        ),
        children: [
          _bodyCell('$displayNumber'),
          _bodyCell(customer.name ?? ''),
          _bodyCell(
            balance.toStringAsFixed(2),
            textColor: balance >= 0 ? ColorManager.kSuccessColor : Colors.red,
          ),
          _bodyCell(customer.phone ?? ''),
          Center(child: _customerTypeBadge(customer.customerType)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BuildBoxShadowContainer(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                circleRadius: 5,
                child: IconButton(
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: ColorManager.kPrimaryColor.withOpacity(0.9),
                  ),
                  onPressed: () => onViewCustomer(customer),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: ColorManager.tableBGColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Table(
            columnWidths: _columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  _headerCell('No'),
                  _headerCell('Name'),
                  _headerCell('Balance'),
                  _headerCell('Phone No.'),
                  _headerCell('Customer Type'),
                  _headerCell('Action'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: customers == null || customers!.isEmpty
                    ? _emptyState()
                    : Table(
                        columnWidths: _columnWidths,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: _rows(),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
