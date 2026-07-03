import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import '../../components/build_container_box.dart';
import '../../components/build_profile_picture.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

// Import supplier-specific widgets
import 'widgets/supplier_information_view_widget.dart';
import 'widgets/supplier_information_edit_widget.dart';
import 'widgets/supplier_transactions_widget.dart';
import 'widgets/supplier_orders_widget.dart';
import 'widgets/supplier_address_view_widget.dart';

class OpenSupplierProfileScreen extends StatefulWidget {
  const OpenSupplierProfileScreen({super.key});

  @override
  State<OpenSupplierProfileScreen> createState() =>
      _OpenSupplierProfileScreenState();
}

class _OpenSupplierProfileScreenState extends State<OpenSupplierProfileScreen> {
  int selectedIndex = 0;

  // Method to navigate to specific tab
  void navigateToTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    SupplierProvider supplierProvider = Provider.of<SupplierProvider>(context);
    Supplier? selectedSupplier = supplierProvider.selectedSupplier;
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());

    if (selectedSupplier == null) {
      return const Center(child: Text("No supplier selected."));
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBackButton(
                onPressed: () => sideBarController.index.value =
                    52, // Navigate back to supplier list
                text: 'All Suppliers',
              ),
              const SizedBox(height: 10),
              Text(
                'Supplier Profile',
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s24, 0,
                    ColorManager.kTitleTextColor),
              ),
              const SizedBox(height: 20),
             Expanded(
                child: size.width < 700
                    ? _buildMobileLayout(size, selectedSupplier)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: size.width / 4,
                            child: _buildSidebar(size, selectedSupplier),
                          ),
                          Expanded(
                            child: _buildMainContent(size, selectedSupplier),
                          ),
                        ],
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Size size, Supplier supplier) {
    final List<String> tabTitles = [
      'Information',
      'Edit Details',
      'Transactions',
      'All Orders',
      'Address',
    ];

    return Column(
      children: [
        BuildBoxShadowContainer(
          padding: const EdgeInsets.all(16),
          circleRadius: 12,
          child: Row(
            children: [
              const BuildProfilePicture(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name ?? 'Supplier Name',
                      style: buildCustomStyle(FontWeightManager.bold,
                          FontSize.s16, 0, ColorManager.kTitleTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${supplier.id}',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0, ColorManager.kGreyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(tabTitles.length, (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => selectedIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorManager.kPrimaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : ColorManager.kBgDarkColor,
                      ),
                    ),
                    child: Text(
                      tabTitles[index],
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s13,
                        0,
                        isSelected ? Colors.white : ColorManager.kTitleTextColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildMainContent(size, supplier)),
      ],
    );
  }

  Widget _buildSidebar(Size size, Supplier supplier) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(right: 24),
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      child: Column(
        children: [
          _buildProfileHeader(supplier),
          const SizedBox(height: 24),
          _buildSidebarButton(0, 'Information', ImageAssets.userProfile),
          _buildSidebarButton(1, 'Edit Details', ImageAssets.lock),
          _buildSidebarButton(2, 'Transactions', ImageAssets.transactionIcon),
          _buildSidebarButton(3, 'All Orders', ImageAssets.saleIcon),
          _buildSidebarButton(4, 'Supplier Address', ImageAssets.userIcon),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Supplier supplier) {
    return Column(
      children: [
        const BuildProfilePicture(),
        const SizedBox(height: 12),
        Text(
          supplier.name ?? 'Supplier Name',
          style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
              ColorManager.kTitleTextColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'ID: ${supplier.id}',
          style: buildCustomStyle(
              FontWeightManager.regular, FontSize.s14, 0, ColorManager.kGreyColor),
        ),
      ],
    );
  }

  Widget _buildSidebarButton(int index, String title, String iconPath) {
    bool isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? ColorManager.kPrimaryColor : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => selectedIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : ColorManager.kBgDarkColor,
              ),
            ),
            child: Row(
              children: [
                WebsafeSvg.asset(
                  iconPath,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : ColorManager.kGreyColor,
                    BlendMode.srcIn,
                  ),
                  width: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s14,
                        0,
                        isSelected
                            ? Colors.white
                            : ColorManager.kTitleTextColor),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isSelected ? Colors.white : ColorManager.kGreyColor,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(Size size, Supplier supplier) {
    final List<Widget> pages = [
      SupplierInformationViewWidget(
        size: size,
        supplier: supplier,
        onEditSupplier: () => navigateToTab(1),
        onViewOrders: () => navigateToTab(3),
      ),
      SupplierInformationEditWidget(size: size, supplier: supplier),
      SupplierTransactionsWidget(size: size, supplier: supplier),
      SupplierOrdersWidget(size: size, supplier: supplier),
      SupplierAddressViewWidget(size: size, supplier: supplier),
    ];
    return pages[selectedIndex];
  }
}
