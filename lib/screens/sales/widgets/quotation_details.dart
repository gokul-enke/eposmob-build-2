import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'build_quotation_details_widget.dart';

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
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer<QuotationsProvider>(
                      builder: (context, provider, child) {
                        final data = provider.currentQuotationDetails;
                        if (data == null) {
                          return const Center(child: Text("No details found"));
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: QuotationDetailWidget(data: data),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomBackButton(
            onPressed: () => Get.find<SideBarController>().index.value = 87,
            text: 'Quotation List',
          ),
          BuildBoxShadowContainer(
            width: 32,
            height: 32,
            circleRadius: 16,
            color: ColorManager.kPrimaryColor,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Get.find<SideBarController>().index.value = 87,
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
