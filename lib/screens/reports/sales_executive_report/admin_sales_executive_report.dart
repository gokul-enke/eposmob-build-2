import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/sales_executive_report.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/features/reports/domain/admin_executive_report.dart';
import 'package:pos_machine/features/reports/presentation/pages/admin_executive_report_page.dart';

/// Only the listing delegates to Reports; the existing details dialog stays here.
class AdminSalesExecutiveReportScreen extends StatefulWidget {
  const AdminSalesExecutiveReportScreen({super.key, this.readSource});
  final Future<AdminExecutiveSource> Function()? readSource;
  @override
  State<AdminSalesExecutiveReportScreen> createState() =>
      _AdminSalesExecutiveReportScreenState();
}

class _AdminSalesExecutiveReportScreenState
    extends State<AdminSalesExecutiveReportScreen> {
  @override
  Widget build(BuildContext context) => AdminExecutiveReportPage(
      readSource: widget.readSource, onView: _showExecutiveDetails);

  void _showExecutiveDetails(
      SalesExecutiveReportData report, String dateRange) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'exec_report.detail_title'.tr,
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s20, 0.30, Colors.black),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(8)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                'exec_report.btn_back'.tr,
                                style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s14,
                                    0.20,
                                    Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildSection(
                          title: 'exec_report.section_exec_info'.tr,
                          children: [
                            _buildInfoRow(
                              _buildInfoItem('exec_report.info_name'.tr, report.name ?? 'exec_report.na'.tr),
                              _buildInfoItem('exec_report.info_phone'.tr, report.phone ?? 'exec_report.na'.tr),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              _buildInfoItem('exec_report.info_date_range'.tr, dateRange),
                              _buildInfoItem('exec_report.info_total_orders'.tr,
                                  (report.orderCount ?? 0).toString()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: 'exec_report.section_financial'.tr,
                          children: [
                            _buildFinancialItem('exec_report.card_total_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedTotalSales}'),
                            _buildFinancialItem('exec_report.card_online_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedOnlineSales}'),
                            _buildFinancialItem('exec_report.card_cash_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCashSales}'),
                            _buildFinancialItem('exec_report.card_credit_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCreditSales}'),
                            _buildFinancialItem('exec_report.card_collected_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCollectedSales}'),
                            _buildFinancialItem('exec_report.card_upi_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedUpiSales}'),
                            _buildFinancialItem('exec_report.card_card_sales'.tr,
                                '${Provider.of<AppSettingsProvider>(context, listen: false).appSettings?.currency ?? "INR"} ${report.formattedCardSales}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
                  0.24, Colors.black)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(Widget item1, Widget item2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: item1),
        const SizedBox(width: 16),
        Expanded(child: item2),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: buildCustomStyle(
                FontWeightManager.medium, FontSize.s12, 0.18, Colors.black87)),
        const SizedBox(height: 4),
        Text(value,
            style: buildCustomStyle(
                FontWeightManager.semiBold, FontSize.s14, 0.20, Colors.black),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildFinancialItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s13,
                    0.18, Colors.black87)),
          ),
          const SizedBox(width: 16),
          Text(value,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s14,
                  0.20, Colors.black)),
        ],
      ),
    );
  }
}
