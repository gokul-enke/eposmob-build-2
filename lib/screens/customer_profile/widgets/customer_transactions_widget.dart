import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/transaction_report_print.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:intl/intl.dart';

class CustomerTransactionsWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerTransactionsWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerTransactionsWidget> createState() =>
      _CustomerTransactionsWidgetState();
}

class _CustomerTransactionsWidgetState
    extends State<CustomerTransactionsWidget> {
  late List<CustomerTransaction> transactions;

  @override
  void initState() {
    super.initState();
    transactions = widget.customer.transactions ?? [];
  }

  // Helper method to determine if transaction is credit or debit
  bool _isCreditTransaction(CustomerTransaction transaction) {
    // Add your logic to determine if it's a credit transaction
    // For example:
    // return transaction.type?.toLowerCase() == 'credit';
    // or based on amount sign:
    // return transaction.amount != null && transaction.amount!.startsWith('+');
    
    // This is a placeholder - implement based on your data structure
    return transaction.type?.toLowerCase() == 'credit' || 
           (transaction.amount != null && transaction.amount!.contains('+'));
  }

  // Print function similar to the one in simple_transaction_details_screen
  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Preparing transaction report..."),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }

    // Fetch customer details
    String customerName = widget.customer.name ?? "";
    String customerPhone = widget.customer.phone ?? "";
    String customerEmail = widget.customer.email ?? "";
    
    // Build complete address
    List<String> addressParts = [];
    if (widget.customer.address != null && widget.customer.address!.isNotEmpty) {
      addressParts.add(widget.customer.address!);
    }
    if (widget.customer.city != null && widget.customer.city!.isNotEmpty) {
      addressParts.add(widget.customer.city!);
    }
    if (widget.customer.state != null && widget.customer.state!.isNotEmpty) {
      addressParts.add(widget.customer.state!);
    }
    if (widget.customer.pincode != null && widget.customer.pincode!.isNotEmpty) {
      addressParts.add(widget.customer.pincode!);
    }
    if (widget.customer.country != null && widget.customer.country!.isNotEmpty) {
      addressParts.add(widget.customer.country!);
    }
    
    String customerAddress = addressParts.join(", ");

    // Convert CustomerTransaction objects to the format expected by the print page
    List<Map<String, dynamic>> cartItems = transactions.map((transaction) {
      return {
        'id': transaction.id,
        'order_id': transaction.orderId,
        'payment_method': transaction.paymentMethod,
        'date': transaction.date,
        'type': transaction.type,
        'reference_id': transaction.referenceId,
        'transaction_type': transaction.transactionType,
        'amount': transaction.amount,
        'currency': transaction.currency,
        'reference': transaction.reference,
        'transaction_comment': transaction.transactionComment,
        'status': transaction.status,
        // Add additional fields that might be needed
        'orderNumber': transaction.reference ?? 'N/A',
      };
    }).toList();

    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var transaction in transactions) {
      double amount = double.tryParse(transaction.amount?.replaceAll('+', '').replaceAll('-', '') ?? "0.00") ?? 0.0;
      bool isCredit = _isCreditTransaction(transaction);

      if (isCredit) {
        totalCredit += amount;
      } else {
        totalDebit += amount;
      }
    }

    // Calculate total amount (for backwards compatibility)
    double totalAmount = totalCredit - totalDebit;

    // Calculate saved amount (for this report, we'll set it to 0)
    double savedAmount = 0.0;

    // Get current date and time for the report
    String orderDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    String orderNumber = "TXN-REPORT-${DateTime.now().millisecondsSinceEpoch}";

    // Navigate to the print page with the transaction data
    Get.to(() => TransactionReportPrintPage(
          cartItems: cartItems, // Pass the converted data
          formattedTotal: totalAmount.toStringAsFixed(2),
          savedTotal: savedAmount.toStringAsFixed(2),
          orderDate: orderDate,
          orderNumber: orderNumber,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          customerAddress: customerAddress,
          isFromLocalStorage: false, // Set to false since we're converting to Map format
        ));

    // Show a message that the print process has started
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Preparing transaction report for printing..."),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

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
              child: transactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) =>
                          _buildTransactionCard(context, transactions[index]),
                    ),
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
                'Transactions (${transactions.length})',
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
                onPressed: _printReport,
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
            'This customer has not made any transactions yet.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s14, 0, ColorManager.kGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    CustomerTransaction transaction,
  ) {
    // Determine if this is a credit or debit transaction
    final bool isCredit = _isCreditTransaction(transaction);
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
            DateHelper.formatISODate(transaction.date ?? ''),
            style: buildCustomStyle(
                FontWeightManager.regular, FontSize.s12, 0, ColorManager.kGreyColor),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amount} ${transaction.currency ?? ''}',
                style: buildCustomStyle(
                  FontWeightManager.bold,
                  FontSize.s14,
                  0,
                  amountColor, // Use credit/debit color
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
      case 'sale':
        iconData = Icons.shopping_cart_checkout;
        break;
      case 'refund':
        iconData = Icons.replay_circle_filled_outlined;
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

  Widget _buildTransactionDetails(CustomerTransaction transaction) {
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
          _buildDetailRow('Transaction ID', transaction.id?.toString() ?? 'N/A'),
          _buildDetailRow('Type', transaction.type ?? 'N/A'),
          _buildDetailRow('Payment Method', transaction.paymentMethod ?? 'N/A'),
          if (transaction.transactionComment != null)
            _buildDetailRow('Comment', transaction.transactionComment!),
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
}