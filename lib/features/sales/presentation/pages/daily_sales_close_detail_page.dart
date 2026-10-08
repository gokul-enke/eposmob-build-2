import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:pos_machine/screens/print/daily_close_standard_printer.dart';
import 'package:pos_machine/screens/print/print_daily_close.dart';
import 'package:provider/provider.dart';

import '../navigation/sales_navigation.dart';
import '../state/daily_close_detail_controller.dart';
import '../widgets/day_close_detail/daily_close_detail_inputs.dart';
import '../widgets/day_close_detail/day_close_action_buttons.dart';
import '../widgets/day_close_detail/day_close_cash_breakdown_section.dart';
import '../widgets/day_close_detail/day_close_cash_summary.dart';
import '../widgets/day_close_detail/day_close_closing_period_details.dart';
import '../widgets/day_close_detail/day_close_closing_range_details.dart';
import '../widgets/day_close_detail/day_close_expenses_breakdown.dart';
import '../widgets/day_close_detail/day_close_header.dart';
import '../widgets/day_close_detail/day_close_key_fields.dart';
import '../widgets/day_close_detail/day_close_sales_summary.dart';
import '../widgets/day_close_detail/day_close_section_header.dart';
import '../widgets/day_close_detail/day_close_transaction_details.dart';

class DailySalesCloseDetailPage extends StatefulWidget {
  const DailySalesCloseDetailPage({super.key});
  @override
  State<DailySalesCloseDetailPage> createState() =>
      _DailySalesCloseDetailPageState();
}

class _DailySalesCloseDetailPageState extends State<DailySalesCloseDetailPage> {
  late final SalesProvider sales;
  late final AppSettingsProvider settings;
  late final DailyCloseDetailController controller;
  @override
  void initState() {
    super.initState();
    sales = context.read<SalesProvider>();
    settings = context.read<AppSettingsProvider>();
    final auth = context.read<AuthModel>();
    controller = DailyCloseDetailController(
        data: sales.selectedDailySalesCloseData,
        fetch: (id) => sales.fetchDailySalesCloseDetail(
            accessToken: auth.token ?? '', id: id),
        onLoaded: sales.setSelectedDailySalesCloseData);
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, settings]),
      builder: (context, _) => _buildPage(
          context,
          DailyCloseDetailInputs(
              controller: controller,
              currency: settings.appSettings?.currency ?? 'INR',
              onBack: () =>
                  SalesNavigation.returnFromDailyClose(sales.returnIndex),
              onPrint: _handlePrint,
              onExport: _handleExport)));
  String _getLocalizedAction(String action) {
    if (action.toLowerCase() == 'print') {
      return 'general.print'.tr;
    } else if (action.toLowerCase() == 'export') {
      return 'daily_sales_close.export'.tr;
    }
    return action;
  }

  Future<bool?> _askIncludeTransactions({String action = 'Print'}) async {
    final localizedAction = _getLocalizedAction(action);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'daily_sales_close.confirm_action_title'.tr.replaceAll(
                  '@action',
                  localizedAction,
                ),
          ),
          content: Text(
            'daily_sales_close.confirm_action_body'.tr.replaceAll(
                  '@action',
                  localizedAction,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('daily_sales_close.cancel'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('daily_sales_close.no'.tr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('daily_sales_close.yes'.tr),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePrint(DailySalesCloseData data) async {
    final includeTransactions = await _askIncludeTransactions(action: 'Print');
    if (!mounted) return;
    if (includeTransactions == null) {
      return;
    }

    final autoPrinted = await DailyClosePrintPage.autoPrint(
      context,
      data: data,
      includeTransactions: includeTransactions,
    );

    if (autoPrinted) {
      if (!mounted) return;
      showScaffold(
        context: context,
        message: 'daily_sales_close.msg_print_success'.tr,
      );
      return;
    }

    if (!mounted) return;
    Get.to(() => DailyClosePrintPage(data: data));
  }

  Future<void> _handleExport(DailySalesCloseData data) async {
    final includeTransactions = await _askIncludeTransactions(action: 'Export');
    if (!mounted) return;
    if (includeTransactions == null) return;

    await DailyCloseStandardPrinter(context).generateAndShareDailyClosePDF(
      data: data,
      selectedPaperSize: 'A4',
      includeTransactions: includeTransactions,
    );
  }

  Widget _buildPage(BuildContext context, DailyCloseDetailInputs inputs) {
    final data = controller.data;
    Size size = MediaQuery.of(context).size;

    if (controller.isLoading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (data == null) {
      return Center(child: Text("daily_sales_close.no_data_selected".tr));
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: CustomBoxShadowContainer(
          circleRadius: 22,
          margin: const EdgeInsets.all(10.0),
          padding: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DayCloseHeader(inputs: inputs),
                const SizedBox(height: 10),
                Text(
                  'daily_sales_close.detail_title'.tr.replaceAll(
                        '@period',
                        data.closingPeriod ?? "",
                      ),
                  style: ResponsiveWidget.isMobile(context)
                      ? buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s12,
                          0.30,
                          ColorManager.textColor,
                        )
                      : buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s20,
                          0.30,
                          ColorManager.textColor,
                        ),
                ),
                const SizedBox(height: 20),
                DayCloseSectionHeader(
                    'daily_sales_close.closing_period_details'.tr,
                    Icons.calendar_today,
                    inputs: inputs),
                const SizedBox(height: 10),
                DayCloseClosingPeriodDetails(data, inputs: inputs),
                const SizedBox(height: 20),
                DayCloseSalesSummary(data, inputs: inputs),
                const SizedBox(height: 20),
                DayCloseSectionHeader('daily_sales_close.expenses_breakdown'.tr,
                    Icons.receipt_long_outlined,
                    inputs: inputs),
                const SizedBox(height: 10),
                DayCloseExpensesBreakdown(data, inputs: inputs),
                const SizedBox(height: 20),
                if (data.cashSummary != null) ...[
                  DayCloseSectionHeader('daily_sales_close.cash_summary'.tr,
                      Icons.account_balance_wallet_outlined,
                      inputs: inputs),
                  const SizedBox(height: 10),
                  DayCloseCashSummary(data.cashSummary!, inputs: inputs),
                  const SizedBox(height: 20),
                  DayCloseSectionHeader(
                      'daily_sales_close.cash_denomination_breakdown'.tr,
                      Icons.payments_outlined,
                      inputs: inputs),
                  const SizedBox(height: 10),
                  DayCloseCashBreakdownSection(data.cashSummary!,
                      inputs: inputs),
                  const SizedBox(height: 20),
                ],
                DayCloseSectionHeader(
                    'daily_sales_close.key_fields'.tr, Icons.info_outline,
                    inputs: inputs),
                const SizedBox(height: 10),
                DayCloseKeyFields(data, inputs: inputs),
                const SizedBox(height: 20),
                DayCloseSectionHeader(
                    'daily_sales_close.closing_range_details'.tr,
                    Icons.access_time,
                    inputs: inputs),
                const SizedBox(height: 10),
                DayCloseClosingRangeDetails(data, inputs: inputs),
                const SizedBox(height: 20),
                DayCloseSectionHeader(
                    'daily_sales_close.transaction_details'.tr,
                    Icons.receipt_long,
                    inputs: inputs),
                const SizedBox(height: 10),
                DayCloseTransactionDetails(size, inputs: inputs),
                const SizedBox(height: 20),
                DayCloseActionButtons(size, data, inputs: inputs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
