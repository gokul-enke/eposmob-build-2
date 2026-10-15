import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../helpers/dashboard_permissions.dart';
import '../../../helpers/ui_code_labels.dart';
import '../../../models/dashboard_widget_data.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/dashboard_widgets_repository.dart';
import '../../../resources/app_url.dart';
import '../../../resources/color_manager.dart';
import 'dashboard_data_section.dart';
import 'dashboard_responsive.dart';

/// New sections only; existing dashboard state/calculations are not consumed
/// or mutated. Each section and card is shown only when the user's role has
/// its `dashboard.widgets.*` permission. The supplier dashboard adds only the
/// supplier graph.
class DashboardAdditionalWidgets extends StatelessWidget {
  const DashboardAdditionalWidgets(
      {super.key, this.repository, this.supplierOnly = false});
  final DashboardWidgetsRepository? repository;
  final bool supplierOnly;

  @override
  Widget build(BuildContext context) {
    final token = context.select<AuthModel, String?>((auth) => auth.token);
    if (token == null || token.trim().isEmpty) return const SizedBox.shrink();
    final currency = context.select<AppSettingsProvider, String>(
        (settings) => settings.appSettings?.currency ?? '');
    final api = repository ?? DashboardWidgetsRepository();
    final requestKey = (token, APPUrl.baseURL, repository);
    String label(String key) => 'dashboard.new_widgets.$key'.tr;
    String amount(double value) =>
        '$currency ${NumberFormat('#,##0.00', Get.locale?.languageCode).format(value)}'
            .trim();
    DashboardStatCard card(String key, String value, IconData icon,
            {Color? color}) =>
        DashboardStatCard(
          title: label(key),
          subtitle: '',
          value: value,
          icon: icon,
          color: color ?? ColorManager.kPrimaryColor,
          showTrend: false,
        );

    bool can(String permission) => canSeeDashboardItem(context, permission);
    final showOrdersToday =
        can(DashboardPermissions.field('orders_widget', 'total_orders_today'));
    final showAverageOrder = can(
        DashboardPermissions.field('orders_widget', 'average_order_amount'));
    final showLatestOrders = can(DashboardPermissions.widget('latest_orders'));
    bool canSummary(String field) =>
        can(DashboardPermissions.field('customer_transactions_summary', field));
    final showSummaryCustomers = canSummary('total_customers');
    final showSummaryCredit = canSummary('total_credit');
    final showSummaryDebit = canSummary('total_debit');
    final showSummaryBalance = canSummary('total_balance');
    final showRevenueStats = can(DashboardPermissions.widget('revenue_stats'));
    final showSuppliersGraph =
        can(DashboardPermissions.widget('suppliers_graph'));

    return Column(children: [
      if (!supplierOnly) ...[
        if (showOrdersToday || showAverageOrder)
          DashboardDataSection<OrdersWidgetData>(
            key: const ValueKey('new_orders_widget'),
            requestKey: requestKey,
            title: label('orders_summary'),
            load: () => api.fetchOrdersWidget(token),
            builder: (data) => ResponsiveStatGrid(maxColumns: 2, cards: [
              if (showOrdersToday)
                card('orders_today', '${data.todayCount}', Icons.receipt_long),
              if (showAverageOrder)
                card('average_order_amount', amount(data.averageAmount),
                    Icons.payments_outlined),
            ]),
          ),
        if (showLatestOrders)
          DashboardDataSection<LatestOrdersData>(
            key: const ValueKey('new_latest_orders'),
            requestKey: requestKey,
            title: label('latest_orders'),
            load: () => api.fetchLatestOrders(token),
            builder: (data) => data.orders.isEmpty
                ? _empty()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BuildBoxShadowContainer(
                      circleRadius: 14,
                      padding: const EdgeInsets.all(8),
                      child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    columns: [
                                      for (final key in [
                                        'order_id',
                                        'date',
                                        'customer',
                                        'status',
                                        'total'
                                      ])
                                        DataColumn(label: Text(label(key))),
                                    ],
                                    rows: data.orders
                                        .map((order) => DataRow(cells: [
                                              DataCell(Text(order.id)),
                                              DataCell(Text(order.date.isEmpty
                                                  ? '—'
                                                  : order.date)),
                                              DataCell(SizedBox(
                                                  width: 180,
                                                  child: Text(
                                                    order.customerName
                                                            .trim()
                                                            .isEmpty
                                                        ? label(
                                                            'unknown_customer')
                                                        : order.customerName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ))),
                                              DataCell(Text(order.status.isEmpty
                                                  ? '—'
                                                  : UiCodeLabels.status(
                                                      order.status))),
                                              DataCell(Text(
                                                  amount(order.grandTotal))),
                                            ]))
                                        .toList(),
                                  ),
                                ),
                              )),
                    ),
                  ),
          ),
        if (showSummaryCustomers ||
            showSummaryCredit ||
            showSummaryDebit ||
            showSummaryBalance)
          DashboardDataSection<CustomerTransactionsSummaryData>(
            key: const ValueKey('new_customer_transactions_summary'),
            requestKey: requestKey,
            title: label('customer_transactions_summary'),
            load: () => api.fetchCustomerTransactionsSummary(token),
            builder: (data) => ResponsiveStatGrid(maxColumns: 4, cards: [
              if (showSummaryCustomers)
                card('customers', '${data.customers}', Icons.people_outline),
              if (showSummaryCredit)
                card('total_credit', amount(data.credit), Icons.call_received),
              if (showSummaryDebit)
                card('total_debit', amount(data.debit), Icons.call_made),
              if (showSummaryBalance)
                card('balance', amount(data.balance),
                    Icons.account_balance_wallet_outlined,
                    color: data.balance < 0 ? ColorManager.kRed : Colors.green),
            ]),
          ),
        if (showRevenueStats)
          DashboardDataSection<RevenueStatsData>(
            key: const ValueKey('new_revenue_stats'),
            requestKey: requestKey,
            title: label('revenue_stats'),
            load: () => api.fetchRevenueStats(token),
            builder: (data) => ResponsiveStatGrid(cards: [
              card('total_on_order', amount(data.totalOnOrder),
                  Icons.receipt_long_outlined),
              card('credit_collected', amount(data.creditCollected),
                  Icons.price_check),
              card('credit_sales', amount(data.creditSales),
                  Icons.credit_score_outlined),
              card('total_in_bank', amount(data.totalInBank),
                  Icons.account_balance_outlined),
              card('total_in_cash', amount(data.totalInCash),
                  Icons.payments_outlined),
            ]),
          ),
      ],
      if (showSuppliersGraph)
        DashboardDataSection<SuppliersGraphData>(
          key: const ValueKey('new_suppliers_graph'),
          requestKey: requestKey,
          title: label('suppliers_graph'),
          load: () => api.fetchSuppliersGraph(token),
          builder: (data) => SuppliersCountGraph(data: data),
        ),
    ]);
  }
}

Widget _empty() => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text('dashboard.new_widgets.no_data'.tr)),
    );

class SuppliersCountGraph extends StatelessWidget {
  const SuppliersCountGraph({super.key, required this.data});
  final SuppliersGraphData data;

  @override
  Widget build(BuildContext context) {
    if (data.counts.isEmpty) return _empty();
    final highest = data.counts.fold<int>(0, math.max);
    final interval = math.max(1, (highest / 5).ceil()).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BuildBoxShadowContainer(
        circleRadius: 14,
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(
                        constraints.maxWidth, data.labels.length * 52.0),
                    height: 260,
                    child: BarChart(BarChartData(
                      minY: 0,
                      maxY: highest < 1 ? 1 : highest * 1.2,
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                            '${data.labels[group.x]}: ${data.counts[group.x]}',
                            const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: true,
                          interval: interval,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 11),
                          ),
                        )),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  index >= 0 && index < data.labels.length
                                      ? data.labels[index]
                                      : '',
                                  style: const TextStyle(fontSize: 11)),
                            );
                          },
                        )),
                      ),
                      barGroups: [
                        for (var i = 0; i < data.counts.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: data.counts[i].toDouble(),
                              color: ColorManager.kPrimaryColor,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            )
                          ]),
                      ],
                    )),
                  ),
                )),
      ),
    );
  }
}
