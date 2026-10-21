import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';

import 'local_order_detail_info_row.dart';
import 'local_order_detail_inputs.dart';
import 'local_order_items_table.dart';
import 'local_order_payment_info.dart';
import 'local_order_sync_notice.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _green = Color(0xFF16764A);

class LocalOrderDetailView extends StatelessWidget {
  const LocalOrderDetailView({super.key, required this.inputs});
  final LocalOrderDetailInputs inputs;

  SavedOrder get order => inputs.order;

  @override
  Widget build(BuildContext context) {
    final currency = inputs.currency;
    final syncRecord = inputs.record;
    final canDelete =
        syncRecord == null || syncRecord.state == LocalSaleSyncState.synced;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final pad = compact ? 16.0 : 24.0;
    final mrp = _calculateTotalMRP();
    final saved = _calculateYouSaved();
    String money(num value) => '$currency ${value.toStringAsFixed(2)}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.all(compact ? 12 : 24),
      elevation: 8,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 760, maxHeight: size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (fixed)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad - 4, pad - 8, 12),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: ColorManager.kBlueEFF6FF,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: ColorManager.kPrimaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("kitchen.order_details".tr,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: _ink)),
                        const SizedBox(height: 2),
                        Text('#${order.orderNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                                fontWeight: FontWeight.w500)),
                      ]),
                ),
                if (order.status?.isNotEmpty == true) ...[
                  _StatusChip(order.status!),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  tooltip: "confirmed_orders.close".tr,
                  icon: const Icon(Icons.close, color: _muted),
                  onPressed: () => inputs.onClose(),
                ),
              ]),
            ),
            const Divider(height: 1, color: _line),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (syncRecord != null &&
                        syncRecord.state != LocalSaleSyncState.synced) ...[
                      LocalOrderSyncNotice(syncRecord, inputs: inputs),
                      const SizedBox(height: 16),
                    ],
                    _summary(compact, [
                      _Stat("confirmed_orders.total_amount".tr,
                          money(order.total),
                          emphasis: true),
                      _Stat("confirmed_orders.total_mrp".tr, money(mrp)),
                      _Stat("confirmed_orders.you_saved".tr, money(saved),
                          color: saved > 0 ? _green : null),
                    ]),
                    const SizedBox(height: 16),
                    _Section(
                      title: "confirmed_orders.order_info".tr,
                      child: _FieldGrid(fields: _infoFields(currency)),
                    ),
                    if (_hasDiscount) ...[
                      const SizedBox(height: 12),
                      _Section(
                        title: "confirmed_orders.applied_discounts".tr,
                        child: Column(children: [
                          if ((order.flatDiscount ?? 0) > 0)
                            LocalOrderDetailInfoRow(
                                "confirmed_orders.flat_discount".tr,
                                money(order.flatDiscount!),
                                inputs: inputs),
                          if ((order.percentageDiscount ?? 0) > 0)
                            LocalOrderDetailInfoRow(
                                "confirmed_orders.percentage_discount".tr,
                                "${order.percentageDiscount!.toStringAsFixed(1)}%",
                                inputs: inputs),
                          if (order.couponId?.isNotEmpty == true)
                            LocalOrderDetailInfoRow(
                                "confirmed_orders.coupon_code".tr,
                                order.couponId!,
                                inputs: inputs),
                        ]),
                      ),
                    ],
                    if (order.paymentMethod != null) ...[
                      const SizedBox(height: 12),
                      _Section(
                        child: LocalOrderPaymentInfo(
                            order.paymentMethod!, currency,
                            inputs: inputs),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(children: [
                      Text("confirmed_orders.order_items".tr,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('${order.items.length}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    LocalOrderItemsTable(inputs: inputs),
                  ],
                ),
              ),
            ),

            // Actions (fixed)
            Container(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
              decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: _line))),
              child: Row(children: [
                if (canDelete)
                  TextButton.icon(
                    onPressed: () => inputs.onDelete(),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text("confirmed_orders.delete".tr),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                        minimumSize: const Size(0, 42)),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => inputs.onClose(),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text("confirmed_orders.close".tr),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => inputs.onPrint(),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text("confirmed_orders.print_order".tr),
                  style: FilledButton.styleFrom(
                      backgroundColor: ColorManager.kPrimaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(bool compact, List<_Stat> stats) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final stat in stats) ...[
            Expanded(child: stat),
            if (stat != stats.last) SizedBox(width: compact ? 8 : 10),
          ]
        ]),
      );

  bool get _hasDiscount =>
      (order.flatDiscount ?? 0) > 0 || (order.percentageDiscount ?? 0) > 0;

  List<_Field> _infoFields(String currency) {
    bool has(String? value) => value != null && value.isNotEmpty;
    final parsable = DateTime.tryParse(order.createdAt) != null;
    return [
      _Field("sales.order_number_hint".tr, '#${order.orderNumber}'),
      if (has(order.customerName))
        _Field("sales.customer_name_hint".tr, order.customerName!),
      _Field(
          "confirmed_orders.customer_phone".tr,
          has(order.customerPhone)
              ? order.customerPhone!
              : "confirmed_orders.na".tr),
      _Field(
          "sales.date_col".tr,
          parsable
              ? DateHelper.formatToISODateOnlyFromISO(order.createdAt)
              : order.createdAt),
      if (parsable)
        _Field("confirmed_orders.time".tr,
            DateHelper.formatToISOTimeOnlyFromISO(order.createdAt)),
      if (has(order.deliveryMethod))
        _Field("confirmed_orders.delivery_method".tr, order.deliveryMethod!),
      if (has(order.deliveryDate))
        _Field("confirmed_orders.delivery_date".tr,
            DateHelper.formatToISODateOnlyFromISO(order.deliveryDate!)),
      if (has(order.deliveryTime))
        _Field("confirmed_orders.delivery_time".tr, order.deliveryTime!),
      if (has(order.transactionId))
        _Field("confirmed_orders.transaction_id".tr, order.transactionId!),
      if (has(order.balanceAmount) && order.balanceAmount != "0.0")
        _Field("confirmed_orders.balance_amount".tr,
            "$currency ${order.balanceAmount}"),
      if (has(order.carNumber))
        _Field("confirmed_orders.car_number".tr, order.carNumber!),
      if (order.toCustomerCredit == true)
        _Field("confirmed_orders.credit_applied".tr, "confirmed_orders.yes".tr),
      if (has(order.comment))
        _Field("confirmed_orders.comment".tr, order.comment!, wide: true),
    ];
  }

  double _calculateTotalMRP() {
    double totalMRP = 0.0;
    for (var item in order.items) {
      final mrp = item.mrp ?? item.product.mrp ?? 0.0;
      totalMRP += mrp * item.quantity;
    }
    return totalMRP;
  }

  double _calculateYouSaved() {
    double totalMRP = _calculateTotalMRP();
    double netTotal = 0.0;
    for (var item in order.items) {
      netTotal += item.amounts.total;
    }
    double youSaved = totalMRP - netTotal;
    return youSaved > 0 ? youSaved : 0.0;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'confirmed' => _green,
      'saved' => const Color(0xFFB45309),
      _ => _muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999)),
      child: Text(UiCodeLabels.status(status),
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color, this.emphasis = false});
  final String label, value;
  final Color? color;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: emphasis ? ColorManager.kBlueEFF6FF : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: emphasis ? ColorManager.kBlueBFDBFE : _line)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        color: color ??
                            (emphasis ? ColorManager.kBlue0F3D75 : _ink),
                        fontSize: emphasis ? 20 : 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(title!,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      );
}

class _Field {
  const _Field(this.label, this.value, {this.wide = false});
  final String label, value;
  final bool wide;
}

/// Label-over-value pairs in two columns on wide dialogs, one on phones, so
/// long labels never wrap beside their values.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});
  final List<_Field> fields;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 480 ? 2 : 1;
        const gap = 16.0;
        final cell = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final field in fields)
              SizedBox(
                width: field.wide ? c.maxWidth : cell,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.label,
                          style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      SelectableText(field.value,
                          style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
          ],
        );
      });
}
