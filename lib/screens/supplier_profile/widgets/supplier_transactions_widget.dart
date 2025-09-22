import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierTransactionsWidget extends StatefulWidget {
  final Size size;
  final Supplier supplier;

  const SupplierTransactionsWidget({
    Key? key,
    required this.size,
    required this.supplier,
  }) : super(key: key);

  @override
  State<SupplierTransactionsWidget> createState() =>
      _SupplierTransactionsWidgetState();
}

class _SupplierTransactionsWidgetState
    extends State<SupplierTransactionsWidget> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  color: ColorManager.kPrimaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Transactions',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
                    ColorManager.kTitleTextColor),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: () {},
            color: ColorManager.kGreyColor,
            tooltip: 'Filter transactions',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 60, color: ColorManager.kPrimaryColor.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text('No Transactions Found',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0, ColorManager.kTitleTextColor)),
          const SizedBox(height: 8),
          Text(
            'Transaction data is not available for this supplier.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0,
                ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }
}

// Simple model for supplier transactions (this would need to be defined properly based on your API)
class SupplierTransaction {
  final int? id;
  final String? reference;
  final String? type;
  final String? amount;
  final String? currency;
  final String? status;
  final String? date;
  final String? description;

  SupplierTransaction({
    this.id,
    this.reference,
    this.type,
    this.amount,
    this.currency,
    this.status,
    this.date,
    this.description,
  });
}
