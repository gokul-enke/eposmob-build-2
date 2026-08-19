import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../components/build_back_button.dart';
import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../controllers/sidebar_controller.dart';
import '../../helpers/date_helper.dart';
import '../../models/supplier.dart';
import '../../providers/auth_model.dart';
import '../../providers/supplier_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../responsive.dart';

class SupplierDetailsScreen extends StatefulWidget {
  const SupplierDetailsScreen({super.key});

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitLoading = false;
  Supplier? supplier;

  @override
  void initState() {
    super.initState();
    getSupplierDetails();
  }

  Future<void> getSupplierDetails() async {
    setState(() {
      isInitLoading = true;
    });

    try {
      // Get the selected supplier from provider (like SalesOrderDetailsScreen gets order from SalesProvider)
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);
      supplier = supplierProvider.selectedSupplier;

      if (supplier == null) {
        debugPrint("No supplier selected");
      } else {
        debugPrint("Loaded supplier: ${supplier!.name}");
      }

      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate API call
    } catch (error) {
      debugPrint("Error fetching supplier details: $error");
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(10.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: isInitLoading
                    ? SizedBox(
                        height: size.height,
                        child: const Center(
                            child: CircularProgressIndicator.adaptive()))
                    : supplier == null
                        ? SizedBox(
                            height: size.height,
                            child: Center(
                                child: Text('supplier_details.no_supplier'.tr)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment
                                .start, // Align items to start
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 10),
                              Text(
                                'supplier_details.profile_title'.tr,
                                style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s20,
                                    0.30,
                                    ColorManager.textColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                supplier!.name,
                                style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s14,
                                    0.30,
                                    ColorManager.textColor.withOpacity(0.6)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              _buildSupplierDetails(),
                              const SizedBox(height: 10),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            sideBarController.index.value =
                52; // Navigate back to supplier list
          },
          text: 'supplier_details.btn_all_suppliers'.tr,
        ),
        BuildBoxShadowContainer(
          width: 15,
          height: 15,
          circleRadius: 10,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              sideBarController.index.value =
                  52; // Navigate back to supplier list
            },
            icon:
                const Icon(Icons.close_rounded, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierDetails() {
    if (supplier == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'supplier_details.section_info'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('supplier_details.label_name'.tr, supplier!.name),
          const SizedBox(height: 8),
          _buildDetailRow(
              'supplier_details.label_email'.tr, supplier!.email.isNotEmpty ? supplier!.email : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRow(
              'supplier_details.label_phone'.tr, supplier!.phone.isNotEmpty ? supplier!.phone : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRow(
              'supplier_details.label_alt_phone'.tr,
              (supplier!.altPhone != null && supplier!.altPhone!.isNotEmpty)
                  ? supplier!.altPhone!
                  : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRow('supplier_details.label_address'.tr,
              supplier!.address.isNotEmpty ? supplier!.address : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRow(
              'supplier_details.label_product_categories'.tr,
              supplier!.productCategories.isNotEmpty
                  ? supplier!.productCategories
                  : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRow('supplier_details.label_balance'.tr,
              supplier!.balance > 0 ? supplier!.balance.toStringAsFixed(2) : 'supplier_details.na'.tr),
          const SizedBox(height: 8),
          _buildDetailRowWithColor(
              'supplier_details.label_current_balance'.tr,
              supplier!.currentBalance.toStringAsFixed(2),
              supplier!.paymentType),
          const SizedBox(height: 8),
          _buildDetailRowWithColor(
              'supplier_details.label_balance_status'.tr, supplier!.balanceStatus, supplier!.paymentType),
          const SizedBox(height: 8),
          _buildDetailRow('supplier_details.label_payment_type'.tr, supplier!.paymentType),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.27,
                ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                ColorManager.textColor.withOpacity(.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithColor(
      String label, String value, String paymentType) {
    Color valueColor = paymentType == 'to_pay'
        ? Colors.red
        : paymentType == 'to_receive'
            ? Colors.green
            : ColorManager.textColor.withOpacity(.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s14,
                0.27,
                ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
