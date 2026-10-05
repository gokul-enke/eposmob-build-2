import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_orders_controller.dart';
import 'orders/customer_orders_view.dart';

/// Customer profile "Orders" tab: the customer's orders from
/// `SalesProvider.fetchOrders(customerId:)`, one API page at a time.
///
/// Uses its own [SalesProvider] instance so the app-wide sales list is not
/// replaced by this customer's orders.
class CustomerOrdersTab extends StatefulWidget {
  const CustomerOrdersTab({super.key, required this.customer});

  final CustomerListModelData customer;

  @override
  State<CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<CustomerOrdersTab> {
  final SalesProvider _salesProvider = SalesProvider();
  late final CustomerOrdersController _controller;

  @override
  void initState() {
    super.initState();
    // Read once: the controller's callbacks can run after this tab unmounts.
    final auth = context.read<AuthModel>();
    _controller = CustomerOrdersController(
      customerId: widget.customer.id,
      readToken: () => auth.token,
      fetch: _fetch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load(page: 1);
    });
  }

  Future<CustomerOrdersPage> _fetch({
    required String accessToken,
    required int customerId,
    required int page,
  }) async {
    await _salesProvider.fetchOrders(
      accessToken: accessToken,
      customerId: customerId,
      page: page,
    );
    return CustomerOrdersPage(
      orders: _salesProvider.orders,
      currentPage: _salesProvider.currentPage,
      totalPages: _salesProvider.totalPages,
    );
  }

  @override
  void didUpdateWidget(covariant CustomerOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.id != widget.customer.id) {
      _controller.setCustomer(widget.customer.id);
    }
  }

  @override
  void dispose() {
    // _salesProvider is not disposed: an in-flight fetch would notify it
    // after disposal. It holds no listeners or timers.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        context.watch<AppSettingsProvider>().appSettings?.currency ?? 'INR';
    return CustomerOrdersView(
      controller: _controller,
      currency: currency,
      customerName: widget.customer.name,
    );
  }
}
