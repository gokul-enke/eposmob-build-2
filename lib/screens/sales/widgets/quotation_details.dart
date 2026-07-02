import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'build_quotation_details_widget.dart';
import 'quotations_responsive.dart';

class QuotationDetailsScreen extends StatefulWidget {
  final dynamic quotationId;
  const QuotationDetailsScreen({super.key, required this.quotationId});

  @override
  State<QuotationDetailsScreen> createState() => _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends State<QuotationDetailsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final quotationsProvider =
          Provider.of<QuotationsProvider>(context, listen: false);

      final qId = widget.quotationId ?? quotationsProvider.selectedQuotationId;

      if (qId != null) {
        await quotationsProvider.fetchQuotationDetails(
          accessToken: authProvider.token ?? '',
          quotationId: qId,
        );
      }
    } catch (e) {
      debugPrint("Error fetching quotation details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ColorManager.kPrimaryColor,
                      ),
                    )
                  : Consumer<QuotationsProvider>(
                      builder: (context, provider, child) {
                        final data = provider.currentQuotationDetails;
                        if (data == null) {
                          return Center(
                            child: Padding(
                              padding:
                                  const EdgeInsetsDirectional.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No details found",
                                    textAlign: TextAlign.center,
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s14,
                                      0.25,
                                      Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          child: QuotationsDetailsShell(
                            child: QuotationDetailWidget(data: data),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isPhone = quotationsIsPhone(context);

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: isPhone ? 12 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomBackButton(
              onPressed: () =>
                  Get.find<SideBarController>().index.value = 87,
              text: 'Quotation List',
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: BuildBoxShadowContainer(
              circleRadius: 12,
              color: ColorManager.kPrimaryColor,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () =>
                    Get.find<SideBarController>().index.value = 87,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
