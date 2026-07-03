import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_address_view_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_chat_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_edit_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_information_view_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_loyalty_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_orders_widget.dart';
import 'package:pos_machine/screens/customer_profile/widgets/customer_transactions_widget.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';
import '../../components/build_container_box.dart';
import '../../components/build_profile_picture.dart';
import '../../resources/asset_manager.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class OpenCustomerProfileScreen extends StatefulWidget {
  const OpenCustomerProfileScreen({super.key});

  @override
  State<OpenCustomerProfileScreen> createState() =>
      _OpenCustomerProfileScreenState();
}

class _OpenCustomerProfileScreenState extends State<OpenCustomerProfileScreen> {
  int selectedIndex = 0;

  // Method to navigate to specific tab
  void navigateToTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    CustomerProvider customerProvider = Provider.of<CustomerProvider>(context);
    CustomerListModelData? selectedCustomer =
        customerProvider.getSelectedCustomer;
    Size size = MediaQuery.of(context).size;
    SideBarController sideBarController = Get.put(SideBarController());

    if (selectedCustomer == null) {
      return const Center(child: Text("No customer selected."));
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 600;
            final double pagePadding = isMobile ? 14 : 20;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  pagePadding, pagePadding, pagePadding, pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () => sideBarController.index.value = 5,
                    text: 'All Customers',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Customer Profile',
                    style: buildCustomStyle(
                        FontWeightManager.bold,
                        isMobile ? FontSize.s20 : FontSize.s24,
                        0,
                        ColorManager.kTitleTextColor),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMobileProfileHeader(selectedCustomer),
                              const SizedBox(height: 12),
                              _buildMobileTabBar(),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Row(
                                  children: [
                                    _buildMainContent(size, selectedCustomer),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sidebar
                              SizedBox(
                                width: size.width / 4,
                                child: _buildSidebar(size, selectedCustomer),
                              ),
                              // Main Content
                              Expanded(
                                child:
                                    _buildMainContent(size, selectedCustomer),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static const List<Map<String, dynamic>> _tabs = [
    {'index': 0, 'title': 'Information'},
    {'index': 1, 'title': 'Edit Details'},
    {'index': 2, 'title': 'Transactions'},
    {'index': 3, 'title': 'All Orders'},
    {'index': 6, 'title': 'Customer Address'},
    {'index': 4, 'title': 'Loyalty Card'},
    {'index': 5, 'title': 'Chat'},
  ];

  Widget _buildMobileProfileHeader(CustomerListModelData customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person,
                color: ColorManager.kPrimaryColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name ?? 'Customer Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                      0, ColorManager.kTitleTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${customer.id}',
                  style: buildCustomStyle(FontWeightManager.regular,
                      FontSize.s12, 0, ColorManager.kGreyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = _tabs[i];
          final int index = tab['index'] as int;
          final bool isSelected = selectedIndex == index;
          return Material(
            color: isSelected ? ColorManager.kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => setState(() => selectedIndex = index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : ColorManager.kBgDarkColor,
                  ),
                ),
                child: Text(
                  tab['title'] as String,
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
        },
      ),
    );
  }

  Widget _buildSidebar(Size size, CustomerListModelData customer) {
    return BuildBoxShadowContainer(
      margin: const EdgeInsets.only(right: 24),
      padding: const EdgeInsets.all(20),
      circleRadius: 12,
      child: Column(
        children: [
          _buildProfileHeader(customer),
          const SizedBox(height: 24),
          _buildSidebarButton(0, 'Information', ImageAssets.userProfile),
          _buildSidebarButton(1, 'Edit Details', ImageAssets.lock),
          _buildSidebarButton(2, 'Transactions', ImageAssets.transactionIcon),
          _buildSidebarButton(3, 'All Orders', ImageAssets.saleIcon),
          _buildSidebarButton(6, 'Customer Address', ImageAssets.userIcon),
          _buildSidebarButton(4, 'Loyalty Card', ImageAssets.cardIcon),
          _buildSidebarButton(5, 'Chat', ImageAssets.supportIcon),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(CustomerListModelData customer) {
    return Column(
      children: [
        const BuildProfilePicture(),
        const SizedBox(height: 12),
        Text(
          customer.name ?? 'Customer Name',
          style: buildCustomStyle(FontWeightManager.bold, FontSize.s18, 0,
              ColorManager.kTitleTextColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'ID: ${customer.id}',
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

  Widget _buildMainContent(Size size, CustomerListModelData customer) {
    final List<Widget> pages = [
      CustomerInformationViewWidget(
        size: size, 
        customer: customer,
        onEditCustomer: () => navigateToTab(1),
        onViewOrders: () => navigateToTab(3),
        onMessage: () => navigateToTab(5),
      ),
      CustomerInformationEditWidget(size: size, customer: customer),
      CustomerTransactionsWidget(size: size, customer: customer),
      CustomerOrdersWidget(size: size, customer: customer),
      CustomerLoyaltyWidget(size: size, customer: customer),
      CustomerChatWidget(size: size, customer: customer),
      CustomerAddressViewWidget(size: size, customer: customer),
    ];
    return pages[selectedIndex];
  }
}
