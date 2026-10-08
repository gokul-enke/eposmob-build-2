import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import 'day_close_amount_field.dart';
import 'day_close_breakdown_section.dart';
import 'day_close_date_field.dart';
import 'day_close_form_inputs.dart';
import 'day_close_info_row.dart';
import 'day_close_small_summary_item.dart';
import 'day_close_small_summary_row.dart';
import 'day_close_summary_card.dart';
import 'day_close_text_area_field.dart';
import 'day_close_time_picker_field.dart';
import 'day_close_two_column_row.dart';

class DayCloseCashClosingStepContent extends StatelessWidget {
  const DayCloseCashClosingStepContent(
      this.currency, this.isNarrow, this.constraints,
      {super.key, required this.inputs});
  final DayCloseFormInputs inputs;
  final String currency;
  final bool isNarrow;
  final BoxConstraints constraints;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Name & Store Info Section
        Text(
          'daily_sales_close.session_info'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              DayCloseInfoRow(Icons.person_outline, 'daily_sales_close.user'.tr,
                  inputs.controller.summary?.userName ?? '-',
                  inputs: inputs),
              const SizedBox(height: 10),
              DayCloseInfoRow(
                  Icons.calendar_today_outlined,
                  'daily_sales_close.opening'.tr,
                  '${inputs.controller.summary?.openingDate ?? '-'} ${'daily_sales_close.at'.tr} ${inputs.controller.summary?.openingTime ?? '-'}',
                  inputs: inputs),
              const SizedBox(height: 10),
              DayCloseInfoRow(
                  Icons.event_available_outlined,
                  'daily_sales_close.closing'.tr,
                  '${inputs.controller.summary?.closingDate ?? '-'} ${'daily_sales_close.at'.tr} ${inputs.controller.summary?.closingTime ?? '-'}',
                  inputs: inputs),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DayCloseTwoColumnRow(
            isNarrow: isNarrow,
            left: DayCloseDateField(
                label: 'daily_sales_close.business_date'.tr,
                controller: inputs.controller.businessDateController,
                inputs: inputs),
            right: DayCloseAmountField(
                label: 'daily_sales_close.shift_name'.tr,
                controller: inputs.controller.shiftNameController,
                enabled: true,
                inputs: inputs),
            inputs: inputs),
        const SizedBox(height: 12),
        DayCloseTwoColumnRow(
            isNarrow: isNarrow,
            left: DayCloseTimePickerField(
                label: 'daily_sales_close.opening_time'.tr,
                controller: inputs.controller.openingTimeController,
                inputs: inputs),
            right: DayCloseTimePickerField(
                label: 'daily_sales_close.closing_time'.tr,
                controller: inputs.controller.closingTimeController,
                inputs: inputs),
            inputs: inputs),
        const SizedBox(height: 20),

        Text(
          'daily_sales_close.tx_overview'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Total Orders and Total Sales
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width:
                  isNarrow ? double.infinity : (constraints.maxWidth - 12) / 2,
              child: DayCloseSummaryCard(
                  'daily_sales_close.total_orders_cap'.tr,
                  inputs.controller.summary?.totalOrders?.toString() ?? '0',
                  icon: Icons.shopping_bag_outlined,
                  inputs: inputs),
            ),
            SizedBox(
              width:
                  isNarrow ? double.infinity : (constraints.maxWidth - 12) / 2,
              child: DayCloseSummaryCard('daily_sales_close.total_sales_cap'.tr,
                  '$currency ${inputs.controller.summary?.totalSales ?? '0.00'}',
                  color: ColorManager.kPrimaryColor,
                  icon: Icons.account_balance_wallet_outlined,
                  inputs: inputs),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Payment Received and Collected On Sale
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width:
                  isNarrow ? double.infinity : (constraints.maxWidth - 12) / 2,
              child: DayCloseSummaryCard(
                  'daily_sales_close.payment_received_cap'.tr,
                  '$currency ${inputs.controller.summary?.paymentReceived ?? '0.00'}',
                  icon: Icons.check_circle_outline,
                  inputs: inputs),
            ),
            SizedBox(
              width:
                  isNarrow ? double.infinity : (constraints.maxWidth - 12) / 2,
              child: DayCloseSummaryCard(
                  'daily_sales_close.collected_on_sale_cap'.tr,
                  '$currency ${inputs.controller.summary?.collectedOnSale ?? '0.00'}',
                  icon: Icons.monetization_on_outlined,
                  inputs: inputs),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Small inputs.controller.summary rows
        DayCloseSmallSummaryRow(
            'daily_sales_close.cash_sales_cap'.tr,
            '$currency ${inputs.controller.summary?.cashSales ?? '0.00'}',
            'daily_sales_close.online_sales_cap'.tr,
            '$currency ${inputs.controller.summary?.onlineSales ?? '0.00'}',
            inputs: inputs),
        const SizedBox(height: 10),
        DayCloseSmallSummaryRow(
            'daily_sales_close.credit_amount_cap'.tr,
            '$currency ${inputs.controller.summary?.creditAmount ?? '0.00'}',
            'daily_sales_close.credit_collected_cap'.tr,
            '$currency ${inputs.controller.summary?.creditCollected ?? '0.00'}',
            inputs: inputs),
        const SizedBox(height: 10),
        DayCloseSmallSummaryRow(
            'daily_sales_close.cash_expenses_cap'.tr,
            '$currency ${inputs.controller.expenseCash.toStringAsFixed(2)}',
            'daily_sales_close.bank_expenses_cap'.tr,
            '$currency ${inputs.controller.expenseBank.toStringAsFixed(2)}',
            inputs: inputs),
        const SizedBox(height: 10),
        DayCloseSmallSummaryItem('daily_sales_close.total_expense_cap'.tr,
            '$currency ${inputs.controller.expenseTotal.toStringAsFixed(2)}',
            color: Colors.red.shade700, inputs: inputs),
        const SizedBox(height: 16),

        Text(
          'daily_sales_close.cash_in_hand'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        DayCloseAmountField(
            label: 'daily_sales_close.opening_cash_in_hand'.tr,
            controller: inputs.controller.openingCashInHandController,
            enabled: !inputs.controller.openingPrefilled,
            onChanged: (_) => inputs.controller.update(() {}),
            inputs: inputs),
        const SizedBox(height: 12),
        DayCloseAmountField(
            label: 'daily_sales_close.closing_cash_in_hand'.tr,
            controller: inputs.controller.closingCashInHandController,
            onChanged: (_) => inputs.controller.update(() {}),
            inputs: inputs),
        const SizedBox(height: 16),

        // Returns & Refunds Section
        Text(
          'daily_sales_close.returns_refunds'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.21,
            Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        DayCloseSmallSummaryRow(
            'daily_sales_close.total_returns_cap'.tr,
            '$currency ${inputs.controller.summary?.totalReturns ?? '0.00'}',
            'daily_sales_close.total_refunds_cap'.tr,
            '$currency ${inputs.controller.summary?.totalRefunds ?? '0.00'}',
            color1: Colors.red.shade600,
            color2: Colors.red.shade600,
            inputs: inputs),
        const SizedBox(height: 20),
        DayCloseBreakdownSection(
            title: 'daily_sales_close.opening_cash_breakdown'.tr,
            denominationControllers:
                inputs.controller.openingDenominationControllers,
            countControllers: inputs.controller.openingCountControllers,
            isNarrow: isNarrow,
            isReadOnly: inputs.controller.openingPrefilled,
            onAddRow: () {
              inputs.controller.update(() {
                inputs.controller.addOpeningBreakdownRow();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (inputs.controller.scrollController.hasClients) {
                  inputs.controller.scrollController.animateTo(
                    inputs.controller.scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
            inputs: inputs),
        const SizedBox(height: 20),
        DayCloseBreakdownSection(
            title: 'daily_sales_close.closing_cash_breakdown'.tr,
            onDenominationChanged: (_) =>
                inputs.controller.recalculateClosingCash(),
            onCountChanged: (_) => inputs.controller.recalculateClosingCash(),
            onRowRemoved: () => inputs.controller.recalculateClosingCash(),
            denominationControllers:
                inputs.controller.closingDenominationControllers,
            countControllers: inputs.controller.closingCountControllers,
            isNarrow: isNarrow,
            onAddRow: () {
              inputs.controller.update(() {
                inputs.controller.addClosingBreakdownRow();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (inputs.controller.scrollController.hasClients) {
                  inputs.controller.scrollController.animateTo(
                    inputs.controller.scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
            inputs: inputs),
        const SizedBox(height: 12),
        DayCloseAmountField(
            label: 'daily_sales_close.cash_refunds'.tr,
            controller: inputs.controller.cashRefundsController,
            onChanged: (_) => inputs.controller.update(() {}),
            inputs: inputs),
        const SizedBox(height: 12),
        DayCloseAmountField(
            label: 'daily_sales_close.cash_drop_amount'.tr,
            controller: inputs.controller.cashDropAmountController,
            onChanged: (_) => inputs.controller.update(() {}),
            inputs: inputs),
        const SizedBox(height: 12),
        DayCloseTextAreaField(
            label: 'daily_sales_close.notes'.tr,
            controller: inputs.controller.notesController,
            maxLines: 3,
            inputs: inputs),
      ],
    );
  }
}
