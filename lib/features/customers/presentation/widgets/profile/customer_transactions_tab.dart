import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_transactions_controller.dart';
import 'transactions/customer_transactions_view.dart';

/// Customer profile "Transactions" tab: the customer's ledger entries from
/// `InvoiceProvider.listCustomerTransactions`, paged 20 at a time, with
/// filters and a printable report.
class CustomerTransactionsTab extends StatefulWidget {
  const CustomerTransactionsTab({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  State<CustomerTransactionsTab> createState() =>
      _CustomerTransactionsTabState();
}

class _CustomerTransactionsTabState extends State<CustomerTransactionsTab> {
  late final CustomerTransactionsController _controller;

  @override
  void initState() {
    super.initState();
    // Read once: the controller's callbacks can run after this tab unmounts.
    final auth = context.read<AuthModel>();
    final invoices = context.read<InvoiceProvider>();
    _controller = CustomerTransactionsController(
      customerId: widget.customer.id?.toString(),
      initial: widget.customer.transactions ?? const [],
      readToken: () => auth.token,
      fetch: (query) => invoices.listCustomerTransactions(
        accessToken: query.accessToken,
        customerId: query.customerId,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
        type: query.type,
        perPage: query.perPage,
        page: query.page,
        // The tab keeps its own list; don't replace the shared one the
        // Transactions screen shows.
        updateState: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load(page: 1);
    });
  }

  @override
  void didUpdateWidget(covariant CustomerTransactionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) {
      _controller.setCustomer(widget.customer.id?.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerTransactionsView(
      controller: _controller,
      customer: widget.customer,
    );
  }
}
