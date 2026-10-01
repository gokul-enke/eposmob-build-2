import 'package:flutter/material.dart';

import '../../../domain/models/supplier.dart';
import '../../state/supplier_transactions_controller.dart';
import 'transactions/supplier_transactions_view.dart';

/// Supplier profile "Transactions" tab: the supplier's ledger entries (the
/// ones that came with the supplier record), filterable, 20 per page, with a
/// printable report.
class SupplierTransactionsTab extends StatefulWidget {
  const SupplierTransactionsTab({super.key, required this.supplier});

  final Supplier supplier;

  @override
  State<SupplierTransactionsTab> createState() =>
      _SupplierTransactionsTabState();
}

class _SupplierTransactionsTabState extends State<SupplierTransactionsTab> {
  late final SupplierTransactionsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SupplierTransactionsController(
      fetch: () async => widget.supplier.transactions,
    )..load();
  }

  @override
  void didUpdateWidget(covariant SupplierTransactionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.supplier, widget.supplier)) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SupplierTransactionsView(
      controller: _controller,
      supplier: widget.supplier,
    );
  }
}
