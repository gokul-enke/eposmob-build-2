import 'package:flutter/material.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class CustomerAddressViewWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData? customer;

  const CustomerAddressViewWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerAddressViewWidget> createState() =>
      _CustomerAddressViewWidgetState();
}

class _CustomerAddressViewWidgetState extends State<CustomerAddressViewWidget> {
  bool isLoading = false;
  CustomerListModelData? detailedCustomer;

  @override
  void initState() {
    super.initState();
    _fetchCustomerDetails();
  }

  Future<void> _fetchCustomerDetails() async {
    if (widget.customer?.id == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final sharedPrefsProvider =
          Provider.of<SharedPreferenceProvider>(context, listen: false);
      final accessToken = await sharedPrefsProvider.getToken();

      if (accessToken != null) {
        final response = await customerProvider.fetchUserById(
            accessToken, widget.customer!.id!, context);

        if (response != null && response['status'] == 'success') {
          setState(() {
            detailedCustomer = CustomerListModelData.fromJson(response['data']);
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching customer details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = widget.size;

    // Use detailed customer data if available, otherwise fallback to widget.customer
    CustomerListModelData? currentCustomer =
        detailedCustomer ?? widget.customer;

    return Expanded(
      child: BuildBoxShadowContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: 12,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ColorManager.kPrimaryColor,
                ),
              )
            : Column(
                children: [
                  // Header Section
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ColorManager.kPrimaryWithOpacity10,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 24),
                    child: Row(
                      children: [
                        // Address Icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color:
                                    ColorManager.kPrimaryColor.withOpacity(0.2),
                                width: 2),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 32,
                            color: ColorManager.kPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Address Header Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Address Information",
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s20,
                                  0,
                                  ColorManager.kTitleTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Customer: ${currentCustomer?.name ?? "N/A"}",
                                style: buildCustomStyle(
                                  FontWeightManager.regular,
                                  FontSize.s14,
                                  0,
                                  ColorManager.kGreyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Address Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ColorManager.kButtonBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Primary",
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s12,
                              0.30,
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Section
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address Information Card
                            _buildInfoCard(
                              title: "Address Details",
                              icon: Icons.location_on_outlined,
                              children: [
                                _buildInfoRow(
                                  icon: Icons.place_outlined,
                                  label: "Address",
                                  value: currentCustomer?.address ??
                                      "Not provided",
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  icon: Icons.flag_outlined,
                                  label: "Country",
                                  value: currentCustomer?.country ??
                                      "Not provided",
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  icon: Icons.map_outlined,
                                  label: "State",
                                  value:
                                      currentCustomer?.state ?? "Not provided",
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  icon: Icons.domain_outlined,
                                  label: "District",
                                  value: currentCustomer?.district ??
                                      "Not provided",
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  icon: Icons.pin_drop_outlined,
                                  label: "Pincode",
                                  value: currentCustomer?.pincode ??
                                      "Not provided",
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kSecondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorManager.kPrimaryWithOpacity10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s14,
                    0.30,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Card Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryWithOpacity10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: ColorManager.kPrimaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.30,
                  ColorManager.kGreyColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.30,
                  valueColor ?? ColorManager.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to format address data
  String _getFullAddress() {
    CustomerListModelData? currentCustomer =
        detailedCustomer ?? widget.customer;

    List<String> addressParts = [];

    if (currentCustomer?.address != null &&
        currentCustomer!.address!.isNotEmpty) {
      addressParts.add(currentCustomer!.address!);
    }
    if (currentCustomer?.state != null && currentCustomer!.state!.isNotEmpty) {
      addressParts.add(currentCustomer!.state!);
    }
    if (currentCustomer?.district != null &&
        currentCustomer!.district!.isNotEmpty) {
      addressParts.add(currentCustomer!.district!);
    }
    if (currentCustomer?.pincode != null &&
        currentCustomer!.pincode!.isNotEmpty) {
      addressParts.add(currentCustomer!.pincode!);
    }
    if (currentCustomer?.country != null &&
        currentCustomer!.country!.isNotEmpty) {
      addressParts.add(currentCustomer!.country!);
    }

    return addressParts.isEmpty
        ? "No address information available"
        : addressParts.join(", ");
  }
}
