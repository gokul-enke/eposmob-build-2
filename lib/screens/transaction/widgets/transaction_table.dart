import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class TransactionTableWidget extends StatelessWidget {
  final List<TransactionModel> transactions;
  final bool isLoading;

  const TransactionTableWidget({
    super.key,
    required this.transactions,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : BuildBoxShadowContainer(
            circleRadius: 7,
            offsetValue: const Offset(1, 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(),
                const Divider(thickness: 1),
                Expanded(
                  child: transactions.isEmpty
                      ? _buildNoTransactionsUI()
                      : SingleChildScrollView(
                          child: Table(
                            columnWidths: _getColumnWidths(),
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: transactions.map((tx) {
                              final index = transactions.indexOf(tx);
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? Colors.white
                                      : Colors.grey.withOpacity(0.1),
                                ),
                                children: [
                                  _buildCell(tx.siNo.toString()),
                                  _buildCell(_getSupplierName(tx)),
                                  _buildCell(tx.reference),
                                  _buildCell(tx.transactionType),
                                  _buildCell(tx.date.split(' ')[0]),
                                  _buildCell(tx.paymentMode),
                                  _buildCell(tx.type),
                                  _buildCell(tx.amount),
                                  _buildCell(tx.status),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          );
  }

  // Helper method to safely get supplier name
  String _getSupplierName(TransactionModel tx) {
    try {
      return tx.supplier.user.name;
    } catch (e) {
      // If supplier is not a Supplier object or doesn't have user.name
      return 'Unknown';
    }
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: ColorManager.tableBGColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 2.0,
          ),
        ],
      ),
      child: Table(
        columnWidths: _getColumnWidths(),
        children: const [
          TableRow(
            children: [
              _HeaderCell("SI No"),
              _HeaderCell("Supplier"),
              _HeaderCell("Reference Number"),
              _HeaderCell("Transaction Type"),
              _HeaderCell("Transaction Date"),
              _HeaderCell("Payment Mode"),
              _HeaderCell("Type"),
              _HeaderCell("Amount"),
              _HeaderCell("Status"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
            FontWeightManager.regular, FontSize.s12, 0.18, Colors.black),
      ),
    );
  }

  Widget _buildNoTransactionsUI() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Text(
          'No transactions found.',
          style: buildCustomStyle(
              FontWeightManager.medium, FontSize.s14, 0.18, Colors.grey),
        ),
      ),
    );
  }

  Map<int, TableColumnWidth> _getColumnWidths() {
    return const {
      0: FlexColumnWidth(0.5),
      1: FlexColumnWidth(1.0),
      2: FlexColumnWidth(1.5),
      3: FlexColumnWidth(1.0),
      4: FlexColumnWidth(1.5),
      5: FlexColumnWidth(1.0),
      6: FlexColumnWidth(1.0),
      7: FlexColumnWidth(1.5),
      8: FlexColumnWidth(1.5),
    };
  }
}

class _HeaderCell extends StatelessWidget {
  final String title;
  const _HeaderCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: buildCustomStyle(FontWeightManager.medium, FontSize.s12, 0.18,
            ColorManager.kPrimaryColor),
      ),
    );
  }
}
