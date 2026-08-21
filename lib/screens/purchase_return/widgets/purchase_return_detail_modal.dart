import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/purchase_return_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';
import 'package:provider/provider.dart';

class PurchaseReturnDetailModal extends StatefulWidget {
  final PurchaseReturnData returnData;

  const PurchaseReturnDetailModal({super.key, required this.returnData});

  @override
  State<PurchaseReturnDetailModal> createState() =>
      _PurchaseReturnDetailModalState();
}

class _PurchaseReturnDetailModalState extends State<PurchaseReturnDetailModal> {
  PurchaseReturnData? _detailedData;
  bool _isLoading = false;

  PurchaseReturnData get displayData => _detailedData ?? widget.returnData;

  @override
  void initState() {
    super.initState();
    if (widget.returnData.items == null || widget.returnData.items!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
    }
  }

  Future<void> _loadDetails() async {
    if (widget.returnData.id == null) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;
      final details = await provider.fetchPurchaseReturnDetails(
        accessToken: token ?? '',
        returnId: widget.returnData.id!,
      );
      if (mounted) {
        setState(() {
          _detailedData = details;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = purchaseOrdersIsPhone(context);
    final screenSize = MediaQuery.of(context).size;
    final data = displayData;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: isPhone ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 16 : 20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isPhone ? screenSize.width : 640,
          maxHeight: screenSize.height * (isPhone ? 0.92 : 0.85),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'purchase_return.details_title'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.28,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PurchaseOrdersContentCard(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'purchase_return.reference'.tr,
                              data.reference ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.voucher_number'.tr,
                              data.voucherNumber ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.supplier'.tr,
                              data.supplier?.name ?? '-',
                            ),
                            _buildInfoRow(
                              'purchase_return.return_date'.tr,
                              data.returnDate ?? '-',
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final amount =
                                    data.totalAmount?.toStringAsFixed(2) ??
                                        '0.00';
                                return _buildInfoRow(
                                  'purchase_return.total_amount'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            Consumer<AppSettingsProvider>(
                              builder: (context, settings, _) {
                                final currency =
                                    settings.appSettings?.currency ?? 'INR';
                                final amount =
                                    data.paidAmount?.toStringAsFixed(2) ??
                                        '0.00';
                                return _buildInfoRow(
                                  'purchase_return.paid_amount'.tr,
                                  '$currency $amount',
                                );
                              },
                            ),
                            _buildInfoRow(
                              'purchase_return.created_by'.tr,
                              data.createdBy?.name ?? '-',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${'purchase_return.status'.tr}: ',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s13,
                                    0.20,
                                    Colors.grey.shade600,
                                  ),
                                ),
                                _buildStatusBadge(data.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'purchase_return.return_items'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s16,
                          0.22,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (data.items != null && data.items!.isNotEmpty)
                        if (isPhone)
                          ...data.items!.map(_buildMobileItemCard)
                        else
                          _buildItemsTable(data.items!)
                      else
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'purchase_return.no_items'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.15,
                                Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('confirmed_orders.close'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 400;
          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  '$label:',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    final isCompleted = status == 'completed';
    final color =
        isCompleted ? Colors.green.shade700 : Colors.orange.shade800;
    final bgColor = isCompleted
        ? Colors.green.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1);
    final label = isCompleted
        ? 'purchase_return.status_completed'.tr
        : 'purchase_return.status_pending'.tr;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.13,
              color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(PurchaseReturnItemData item) {
    final displayName = item.variantName != null && item.variantName!.isNotEmpty
        ? '${item.productName ?? ''} (${item.variantName})'
        : item.productName ?? '-';

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'billing.table_qty'.tr,
                  item.quantity?.toString() ?? '0',
                ),
              ),
              Expanded(
                child: Consumer<AppSettingsProvider>(
                  builder: (context, settings, _) {
                    final currency = settings.appSettings?.currency ?? 'INR';
                    final amount = item.amount?.toStringAsFixed(2) ?? '0.00';
                    return _buildMetric(
                      'purchase_return.total_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${'purchase_return.reason'.tr}: ${item.reason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.18,
                Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s10,
            0.15,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(List<PurchaseReturnItemData> items) {
    return PurchaseOrdersResponsiveTable(
      minWidth: 560,
      table: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorManager.tableBGColor.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(110),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _headerCell('confirmed_orders.product'.tr),
                    _headerCell('billing.table_qty'.tr),
                    _headerCell('purchase_return.total_amount'.tr),
                    _headerCell('purchase_return.reason'.tr),
                  ],
                ),
              ],
            ),
          ),
          ...items.map((item) {
            final displayName =
                item.variantName != null && item.variantName!.isNotEmpty
                    ? '${item.productName ?? ''} (${item.variantName})'
                    : item.productName ?? '-';
            return Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(110),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _valueCell(displayName),
                    _valueCell(item.quantity?.toString() ?? '0'),
                    _valueCellWidget(
                      Consumer<AppSettingsProvider>(
                        builder: (context, settings, _) {
                          final currency =
                              settings.appSettings?.currency ?? 'INR';
                          final amount =
                              item.amount?.toStringAsFixed(2) ?? '0.00';
                          return Text('$currency $amount');
                        },
                      ),
                    ),
                    _valueCell(item.reason ?? '-'),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _valueCell(String value) {
    return _valueCellWidget(
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _valueCellWidget(Widget child) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: DefaultTextStyle(
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.15,
          ColorManager.textColor,
        ),
        child: child,
      ),
    );
  }
}
