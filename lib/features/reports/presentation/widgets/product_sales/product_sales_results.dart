import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../domain/models/product_sales_report.dart';

String productSalesMoney(double value, String currency) =>
    '${currency.isEmpty ? '' : '$currency '}${value.toStringAsFixed(2)}';
String productSalesQuantity(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(3);

List<TableColumnDef<ProductSalesReportEntry>> productSalesColumns(
        String currency) =>
    [
      TableColumnDef(
          label: 'product_sales_report.col_category_name'.tr,
          flex: 1.2,
          cellBuilder: (row, _) => TableCells.text(row.category)),
      TableColumnDef(
          label: 'product_sales_report.col_product_name'.tr,
          flex: 1.6,
          cellBuilder: (row, _) => TableCells.text(row.productName)),
      TableColumnDef(
          label: 'product_sales_report.col_price'.tr,
          cellBuilder: (row, _) =>
              TableCells.text(productSalesMoney(row.price, currency))),
      TableColumnDef(
          label: 'product_sales_report.col_total_amount'.tr,
          cellBuilder: (row, _) =>
              TableCells.text(productSalesMoney(row.totalPrice, currency))),
      TableColumnDef(
          label: 'product_sales_report.col_products_sold'.tr,
          cellBuilder: (row, _) =>
              TableCells.text(productSalesQuantity(row.salesCount))),
    ];

class ProductSalesCard extends StatelessWidget {
  const ProductSalesCard(
      {super.key, required this.entry, required this.currency});
  final ProductSalesReportEntry entry;
  final String currency;
  @override
  Widget build(BuildContext context) => AppListCard(
      title: entry.productName,
      subtitle: entry.category,
      body: Column(children: [
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.payments_outlined,
              label: 'product_sales_report.col_price'.tr,
              value: productSalesMoney(entry.price, currency)),
          AppMetric(
              icon: Icons.inventory_2_outlined,
              label: 'product_sales_report.col_products_sold'.tr,
              value: productSalesQuantity(entry.salesCount)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        AppMetric(
            icon: Icons.monetization_on_outlined,
            label: 'product_sales_report.col_total_amount'.tr,
            value: productSalesMoney(entry.totalPrice, currency)),
      ]));
}

class ProductSalesTotals extends StatelessWidget {
  const ProductSalesTotals({super.key, required this.data});
  final ProductSalesReportData data;
  @override
  Widget build(BuildContext context) => AppMetricStrip(metrics: [
        AppMetric(
            icon: Icons.monetization_on_outlined,
            label: 'product_sales_report.total_revenue'.tr,
            value: productSalesMoney(data.summary.totalRevenue, data.currency)),
        AppMetric(
            icon: Icons.inventory_2_outlined,
            label: 'product_sales_report.total_quantity'.tr,
            value: productSalesQuantity(data.summary.totalQuantity)),
      ]);
}
