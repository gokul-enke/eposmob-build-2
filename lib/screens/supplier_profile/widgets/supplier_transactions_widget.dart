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
              child: widget.supplier.transactions.isEmpty
                  ? _buildEmptyState()
                  : _buildTransactionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                  color: Color(0xFF3C92F5), size: 28),
              const SizedBox(width: 12),
              Text(
                'Transactions (${widget.supplier.transactions.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () {
                  // Add print functionality
                },
                color: const Color(0xFF7F8C8D),
                tooltip: 'Print transactions',
              ),
              IconButton(
                icon: const Icon(Icons.filter_list_alt),
                onPressed: () {},
                color: const Color(0xFF7F8C8D),
                tooltip: 'Filter transactions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.supplier.transactions.length,
      itemBuilder: (context, index) =>
          _buildTransactionCard(context, widget.supplier.transactions[index]),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    dynamic transaction,
  ) {
    // Determine if this is a credit or debit transaction
    final bool isCredit = transaction.type == 'Credit';
    final Color amountColor = isCredit ? ColorManager.kSuccessColor : ColorManager.kRed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kBgDarkColor),
        boxShadow: [
          BoxShadow(
            color: ColorManager.boxShadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildTransactionIcon(transaction.type),
          title: Text(
            transaction.reference ?? 'No Reference',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s15, 0,
                ColorManager.kTitleTextColor),
          ),
          subtitle: Text(
            transaction.date ?? '',
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s12, 0, ColorManager.kGreyColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.currency} ${transaction.amount}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s14,
                  0,
                  amountColor,
                ),
              ),
              const SizedBox(height: 2),
              _buildStatusBadge(transaction.status),
            ],
          ),
          children: [_buildTransactionDetails(transaction)],
        ),
      ),
    );
  }

  Widget _buildTransactionIcon(String? type) {
    IconData iconData;
    switch (type?.toLowerCase()) {
      case 'credit':
        iconData = Icons.add_circle_outline;
        break;
      case 'debit':
        iconData = Icons.remove_circle_outline;
        break;
      case 'payment':
        iconData = Icons.payment;
        break;
      default:
        iconData = Icons.receipt_long;
    }
    return CircleAvatar(
      backgroundColor: ColorManager.kPrimaryWithOpacity10,
      child: Icon(iconData, color: ColorManager.kPrimaryColor, size: 22),
    );
  }

  Widget _buildStatusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'N/A',
        style: buildCustomStyle(
            FontWeightManager.medium, FontSize.s10, 0, _getStatusColor(status)),
      ),
    );
  }

  Widget _buildTransactionDetails(dynamic transaction) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: ColorManager.kBgLightColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow('Transaction Type', transaction.transactionType ?? 'N/A'),
          _buildDetailRow('Payment Method', transaction.paymentMethod?.isEmpty == true ? 'N/A' : transaction.paymentMethod),
          _buildDetailRow('Date', transaction.date ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                  0, ColorManager.kGreyColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0, ColorManager.kTitleTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succ':
      case 'completed':
        return ColorManager.kSuccessColor;
      case 'fail':
      case 'failed':
        return ColorManager.kRed;
      case 'init':
      case 'pending':
        return ColorManager.kOrange;
      default:
        return ColorManager.kGreyColor;
    }
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
