import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerTransactionsWidget extends StatelessWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerTransactionsWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final transactions = customer.transactions ?? [];

    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        height: size.height * 0.75,
        width: size.width < 1200 ? size.width / 1.8 : size.width / 2,
        circleRadius: 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions (${transactions.length})',
                  style: const TextStyle(
            fontSize: FontSize.s20,
            fontWeight: FontWeightManager.semiBold
          ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshData(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: transactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => _buildTransactionCard(
                        context,
                        transactions[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transactions found for this customer',
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.20,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    CustomerTransaction transaction,
  ) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      circleRadius: 7,
      child: ExpansionTile(
        title: Row(
          children: [
            // Status indicator
            _buildOrderStatusIndicator(transaction.status),
            const SizedBox(width: 12),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.reference ?? 'No Reference',
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s16,
                      0.20,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateHelper.formatISODate(transaction.date ?? ''),
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.18,
                      Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '${transaction.amount} ${transaction.currency}',
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s14,
                0.20,
                transaction.status?.toLowerCase() == 'succ'
                    ? Colors.green
                    : ColorManager.kOrange,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction Details
                _buildDetailRow('Transaction ID:',transaction.id?.toString()  ?? 'N/A'),
                _buildDetailRow('Type:', transaction.type ?? 'N/A'),
                _buildDetailRow(
                    'Payment Method:', transaction.paymentMethod ?? 'N/A'),

                // Status with colored text
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 120,
                        child: Text(
                          'Status:',
                          style:TextStyle(fontWeight: FontWeight.bold),

                        ),
                      ),
                      Expanded(
                        child: Text(
                          transaction.status ?? 'N/A',
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s12,
                            0.18,
                            _getStatusColor(transaction.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Additional notes if available
                if (transaction.transactionComment != null)
                  _buildDetailRow('Notes:', transaction.transactionComment!),

                // View Details Button
                // Center(
                //   child: TextButton(
                //     onPressed: ()=> _showTransactionDetails(context, transaction),
                //     child: const Text(
                //       'VIEW FULL DETAILS',
                //       style: TextStyle(
                //         color: ColorManager.kPrimaryColor,
                //         fontWeight: FontWeightManager.medium,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper function for status colors
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succ':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'init':
        return Colors.orange;
      default:
        return ColorManager.textColor;
    }
  }

// Reusable detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.18,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildDetailRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 120,
  //           child: Text(
  //             label,
  //             style: buildCustomStyle(
  //               FontWeightManager.medium,
  //               FontSize.s14,
  //               0.20,
  //               ColorManager.textColor,
  //             ),
  //           ),
  //         ),
  //         Expanded(
  //           child: Text(
  //             value,
  //             style: buildCustomStyle(
  //               FontWeightManager.regular,
  //               FontSize.s14,
  //               0.20,
  //               ColorManager.textColor,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _refreshData(BuildContext context) {
    showScaffold(
        context: context,
        message: "Refreshing transactions...",
      );
  }
  
}
Widget _buildOrderStatusIndicator(String? status) {
    Color color;
    IconData icon;
    
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'delivered':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'processing':
        color = Colors.blue;
        icon = Icons.autorenew;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Tooltip(
      message: status ?? 'Unknown status',
      child: Icon(icon, color: color, size: 20),
    );
  }