import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import 'customer_address_form_widget.dart';

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
  bool showForm = false;
  Address? addressToEdit;

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
        margin: EdgeInsets.all(size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: size.height * 0.75,
        circleRadius: 12,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ColorManager.kPrimaryColor,
                ),
              )
            : showForm
                ? Column(
                    children: [
                      CustomerAddressFormWidget(
                        size: size,
                        customer: currentCustomer!,
                        address: addressToEdit,
                        onSuccess: (newAddress) {
                          setState(() {
                            showForm = false;
                            addressToEdit = null;

                            if (detailedCustomer != null) {
                              List<Address> currentAddresses =
                                  List.from(detailedCustomer!.addresses ?? []);
                              int index = currentAddresses
                                  .indexWhere((a) => a.id == newAddress.id);

                              if (index != -1) {
                                // Update existing
                                currentAddresses[index] = newAddress;
                              } else {
                                // Add new
                                currentAddresses.add(newAddress);
                              }

                              // Create a new CustomerListModelData with updated addresses
                              detailedCustomer = CustomerListModelData(
                                id: detailedCustomer!.id,
                                name: detailedCustomer!.name,
                                email: detailedCustomer!.email,
                                phone: detailedCustomer!.phone,
                                altPhone: detailedCustomer!.altPhone,
                                gender: detailedCustomer!.gender,
                                dob: detailedCustomer!.dob,
                                profileImage: detailedCustomer!.profileImage,
                                storeId: detailedCustomer!.storeId,
                                userId: detailedCustomer!.userId,
                                createdAt: detailedCustomer!.createdAt,
                                updatedAt: detailedCustomer!.updatedAt,
                                deletedAt: detailedCustomer!.deletedAt,
                                cardNumber: detailedCustomer!.cardNumber,
                                loyaltyPoints: detailedCustomer!.loyaltyPoints,
                                validFrom: detailedCustomer!.validFrom,
                                validUntil: detailedCustomer!.validUntil,
                                cardStatus: detailedCustomer!.cardStatus,
                                membershipName:
                                    detailedCustomer!.membershipName,
                                membershipCode:
                                    detailedCustomer!.membershipCode,
                                minRedeemablePoints:
                                    detailedCustomer!.minRedeemablePoints,
                                pricePerPoint: detailedCustomer!.pricePerPoint,
                                balance: detailedCustomer!.balance,
                                paymentType: detailedCustomer!.paymentType,
                                customerType: detailedCustomer!.customerType,
                                address: detailedCustomer!.address,
                                pincode: detailedCustomer!.pincode,
                                city: detailedCustomer!.city,
                                state: detailedCustomer!.state,
                                country: detailedCustomer!.country,
                                district: detailedCustomer!.district,
                                companyId: detailedCustomer!.companyId,
                                storeName: detailedCustomer!.storeName,
                                kyc: detailedCustomer!.kyc,
                                transactions: detailedCustomer!.transactions,
                                orders: detailedCustomer!.orders,
                                addresses: currentAddresses,
                              );
                            }
                          });
                          _fetchCustomerDetails();
                        },
                        onCancel: () {
                          setState(() {
                            showForm = false;
                            addressToEdit = null;
                          });
                        },
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Header Section
                      Builder(builder: (context) {
                        final isMobile = size.width < 600;
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryWithOpacity10,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(isMobile ? 8 : 12),
                              topRight: Radius.circular(isMobile ? 8 : 12),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 24,
                            horizontal: isMobile ? 12 : 24,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 40 : 60,
                                height: isMobile ? 40 : 60,
                                decoration: BoxDecoration(
                                  color: ColorManager.kPrimaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                      isMobile ? 20 : 30),
                                  border: Border.all(
                                      color: ColorManager.kPrimaryColor
                                          .withOpacity(0.2),
                                      width: 2),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  size: isMobile ? 22 : 32,
                                  color: ColorManager.kPrimaryColor,
                                ),
                              ),
                              SizedBox(width: isMobile ? 8 : 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Address Information",
                                      overflow: TextOverflow.ellipsis,
                                      style: buildCustomStyle(
                                        FontWeightManager.bold,
                                        isMobile ? FontSize.s16 : FontSize.s20,
                                        0,
                                        ColorManager.kTitleTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Customer: ${currentCustomer?.name ?? "N/A"}",
                                      overflow: TextOverflow.ellipsis,
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        isMobile ? FontSize.s12 : FontSize.s14,
                                        0,
                                        ColorManager.kGreyColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isMobile ? 4 : 16),
                              isMobile
                                  ? IconButton(
                                      onPressed: () {
                                        setState(() {
                                          addressToEdit = null;
                                          showForm = true;
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle,
                                          color: ColorManager.kPrimaryColor),
                                      tooltip: 'customer_address.tooltip_add'.tr,
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          addressToEdit = null;
                                          showForm = true;
                                        });
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text("Add New"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            ColorManager.kPrimaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        );
                      }),

                      // Content Section
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(size.width < 600 ? 12 : 24),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show the list of addresses
                                if (currentCustomer?.addresses != null &&
                                    currentCustomer!.addresses!.isNotEmpty) ...[
                                  ...currentCustomer.addresses!
                                      .map((addr) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16.0),
                                            child: _buildInfoCard(
                                              title:
                                                  'customer_address.title_address'.trParams({'type': addr.type ?? 'customer_address.type_other'.tr}),
                                              icon: Icons.location_on_outlined,
                                              onEdit: () {
                                                setState(() {
                                                  addressToEdit = addr;
                                                  showForm = true;
                                                });
                                              },
                                              children: [
                                                _buildInfoRow(
                                                    icon: Icons.place_outlined,
                                                    label: "Address",
                                                    value: addr.address ??
                                                        "Not provided"),
                                                const SizedBox(height: 12),
                                                _buildInfoRow(
                                                    icon: Icons
                                                        .location_city_outlined,
                                                    label: "City",
                                                    value: addr.city ??
                                                        "Not provided"),
                                                const SizedBox(height: 12),
                                                _buildInfoRow(
                                                    icon:
                                                        Icons.pin_drop_outlined,
                                                    label: "Pincode ID",
                                                    value: addr.pincodeId
                                                            ?.toString() ??
                                                        "Not provided"),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ] else if (!isLoading) ...[
                                  // Empty state
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 100),
                                        Icon(Icons.location_off_outlined,
                                            size: 80,
                                            color: ColorManager.kGreyColor
                                                .withOpacity(0.3)),
                                        const SizedBox(height: 16),
                                        Text(
                                          "No address records found",
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s16,
                                            0,
                                            ColorManager.kGreyColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    VoidCallback? onEdit,
  }) {
    final isMobile = widget.size.width < 600;
    final radius = isMobile ? 8.0 : 12.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorManager.kSecondaryColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ColorManager.kPrimaryWithOpacity10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryWithOpacity10,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
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
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.30,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 20, color: ColorManager.kPrimaryColor),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
          // Card Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
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
    final isMobile = widget.size.width < 600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isMobile ? 30 : 36,
          height: isMobile ? 30 : 36,
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryWithOpacity10,
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
          ),
          child: Icon(
            icon,
            size: isMobile ? 16 : 18,
            color: ColorManager.kPrimaryColor,
          ),
        ),
        SizedBox(width: isMobile ? 8 : 12),
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
                softWrap: true,
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
