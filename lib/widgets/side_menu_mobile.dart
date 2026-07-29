import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:pos_machine/services/session_reset_service.dart';
import 'package:provider/provider.dart';

import '../controllers/sidebar_controller.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../widgets/store_switcher.dart';
import '../widgets/user_switcher.dart';
import 'side_menu.dart';

class SideMenuMobile extends StatefulWidget {
  const SideMenuMobile({super.key});

  @override
  State<SideMenuMobile> createState() => _SideMenuMobileState();
}

class _SideMenuMobileState extends State<SideMenuMobile> {
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = Provider.of<RoleProvider>(context, listen: false);
      debugPrint(
          "🟡 [SideMenuMobile] initState postFrame: roles count=${roleProvider.roles.length}, userRole='$userRole'");
      if (roleProvider.roles.isEmpty) {
        roleProvider.fetchRoles(context);
      }
    });
  }

  void _loadUserRole() async {
    final role = await SharedPreferenceProvider().getUserRole();
    debugPrint("🟡 [SideMenuMobile] _loadUserRole: loaded role = '$role'");
    if (mounted) {
      setState(() {
        userRole = role;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sideBarController = Get.find<SideBarController>();
    debugPrint("🟡 [SideMenuMobile] build: userRole='$userRole'");

    void navigate(int index) {
      sideBarController.index.value = index;
      Navigator.of(context).pop();
    }

    void fetchSalesOrders() {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      salesProvider.fetchOrders(accessToken: accessToken ?? '', storeId: 1);
    }

    void fetchSuppliers() {
      final supplierProvider =
          Provider.of<SupplierProvider>(context, listen: false);
      final accessToken = Provider.of<AuthModel>(context, listen: false).token;
      supplierProvider.fetchSuppliers(accessToken: accessToken ?? '');
    }

    Future<void> handleLogout() async {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token ?? '';
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator.adaptive(),
          );
        },
      );
      await AuthenticationProvider().logout(token, context).then((value) async {
        if (value['status'] == 'success') {
          await SessionResetService.resetAfterLogout(context);
          if (!context.mounted) return;
          showScaffold(
            context: context,
            message: '${value['message']}',
          );
          Navigator.pop(context);
          await Future.delayed(const Duration(seconds: 0)).then(
            (value) => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SignInScreen(),
              ),
            ),
          );
        } else {
          Navigator.pop(context);
          showScaffoldError(
            context: context,
            message: '${value['message']}',
          );
        }
      });
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MobileDrawerHeader(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                children: [
                  _buildMainSection(sideBarController, navigate),
                  _buildSalesSection(
                    sideBarController,
                    navigate,
                    fetchSalesOrders,
                  ),
                  _buildInventorySection(sideBarController, navigate),
                  _buildReportsSection(sideBarController, navigate),
                  _buildAccountsSection(sideBarController, navigate),
                  _buildDirectorySection(
                    sideBarController,
                    navigate,
                    fetchSuppliers,
                  ),
                  _buildSettingsSection(sideBarController, navigate),
                ],
              ),
            ),
            _MobileDrawerFooter(onLogout: handleLogout),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSection(
    SideBarController sideBarController,
    void Function(int index) navigate,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasHome =
            roleProvider.currentUserHasPermissionSync('menu.home.main.access');
        final hasBilling = roleProvider
            .currentUserHasPermissionSync('menu.supermarket.main.access');
        final hasDashboard = roleProvider
            .currentUserHasPermissionSync('menu.dashboard.main.access');
        final hasRestaurant = roleProvider
            .currentUserHasPermissionSync('menu.restaurant.main.access');
        final hasAttender = roleProvider
            .currentUserHasPermissionSync('menu.restaurant.attender.access');
        final hasKitchen = roleProvider.currentUserHasPermissionSync(
            'menu.restaurant.kitchen_master.access');

        if (!hasHome &&
            !hasBilling &&
            !hasDashboard &&
            !hasRestaurant &&
            !hasAttender &&
            !hasKitchen) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionHeader(title: 'Main'),
            if (hasHome)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  onTap: () => navigate(0),
                  selected: sideBarController.index.value == 0,
                ),
              ),
            if (hasBilling)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Billing',
                  onTap: () => navigate(90),
                  selected: sideBarController.index.value == 90,
                ),
              ),
            if (hasDashboard)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  onTap: () => navigate(1),
                  selected: sideBarController.index.value == 1,
                ),
              ),
            if (hasRestaurant)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.restaurant_rounded,
                  title: 'Restaurant',
                  onTap: () => navigate(89),
                  selected: sideBarController.index.value == 89,
                ),
              ),
            if (hasRestaurant)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.storefront_rounded,
                  title: 'Store',
                  onTap: () => navigate(97),
                  selected: sideBarController.index.value == 97,
                ),
              ),
            if (hasAttender)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.room_service_rounded,
                  title: 'Attender',
                  onTap: () => navigate(55),
                  selected: sideBarController.index.value == 55,
                ),
              ),
            if (hasKitchen)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.soup_kitchen_rounded,
                  title: 'Kitchen Master',
                  onTap: () => navigate(56),
                  selected: sideBarController.index.value == 56,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSalesSection(
    SideBarController sideBarController,
    void Function(int index) navigate,
    VoidCallback fetchSalesOrders,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasSalesPermission = roleProvider
            .currentUserHasPermissionSync('menu.sales.orders.access');
        final hasConfirmedOrdersPermission = roleProvider
            .currentUserHasPermissionSync('menu.sales.confirmed_orders.access');
        final hasSalesReturnPermission = roleProvider
            .currentUserHasPermissionSync('menu.sales.returns.access');
        final hasDayClosingPermission = roleProvider
            .currentUserHasPermissionSync('menu.sales.day_closing.access');
        final hasOnlineSalesPermission = roleProvider
            .currentUserHasPermissionSync('menu.sales.online_sales.access');
        final hasQuotationPermission = roleProvider
            .currentUserHasPermissionSync('menu.quotation.main.access');
        final isCompanyAdmin = userRole == 'company_admin';

        final hasSalesGroup = hasSalesPermission ||
            hasConfirmedOrdersPermission ||
            hasSalesReturnPermission ||
            hasDayClosingPermission ||
            hasOnlineSalesPermission;

        if (!hasSalesGroup && !hasQuotationPermission) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Sales'),
            if (hasSalesGroup)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.shopping_cart_rounded,
                  title: 'Sales',
                  selected: [
                    2,
                    11,
                    49,
                    50,
                    51,
                    54,
                    78,
                    79,
                    84,
                    92,
                  ].contains(sideBarController.index.value),
                  subItems: [
                    if (hasSalesPermission)
                      _MobileDrawerSubItem(
                        title: 'Sales',
                        onTap: () {
                          fetchSalesOrders();
                          navigate(2);
                        },
                      ),
                    if (hasConfirmedOrdersPermission)
                      _MobileDrawerSubItem(
                        title: 'Confirmed Orders',
                        onTap: () => navigate(54),
                      ),
                    if (hasSalesReturnPermission)
                      _MobileDrawerSubItem(
                        title: 'Sales Return',
                        onTap: () => navigate(50),
                      ),
                    if (hasDayClosingPermission)
                      _MobileDrawerSubItem(
                        title: 'Day Sale Closing',
                        onTap: () => navigate(78),
                      ),
                    if (isCompanyAdmin && hasDayClosingPermission)
                      _MobileDrawerSubItem(
                        title: 'Admin Day Sale records',
                        onTap: () => navigate(84),
                      ),
                    if (hasOnlineSalesPermission || isCompanyAdmin)
                      _MobileDrawerSubItem(
                        title: 'Online Orders',
                        onTap: () => navigate(92),
                      ),
                  ],
                ),
              ),
            if (hasQuotationPermission)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.request_quote_rounded,
                  title: 'Quotations',
                  selected:
                      [86, 87, 88].contains(sideBarController.index.value),
                  subItems: [
                    _MobileDrawerSubItem(
                      title: 'Quotations',
                      onTap: () => navigate(86),
                    ),
                    _MobileDrawerSubItem(
                      title: 'Quotation List',
                      onTap: () => navigate(87),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInventorySection(
    SideBarController sideBarController,
    void Function(int index) navigate,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasCategory = roleProvider
            .currentUserHasPermissionSync('menu.catalog.category.access');
        final hasProductPermission = roleProvider
            .currentUserHasPermissionSync('menu.catalog.product.list.access');
        final hasStockPermission = roleProvider
            .currentUserHasPermissionSync('menu.catalog.product.stock.access');
        final hasBarcodePermission = roleProvider.currentUserHasPermissionSync(
            'menu.catalog.product.barcode.access');
        final hasPurchase = roleProvider
            .currentUserHasPermissionSync('menu.purchase.orders.access');

        final hasProductGroup =
            hasProductPermission || hasStockPermission || hasBarcodePermission;

        if (!hasCategory && !hasProductGroup && !hasPurchase) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Inventory'),
            if (hasCategory)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.category_rounded,
                  title: 'Category',
                  onTap: () => navigate(12),
                  selected: [12, 13, 16, 27, 34]
                      .contains(sideBarController.index.value),
                ),
              ),
            if (hasProductGroup)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.inventory_2_rounded,
                  title: 'Product',
                  selected: [14, 15, 17, 18, 28, 33, 35, 83]
                      .contains(sideBarController.index.value),
                  subItems: [
                    if (hasProductPermission)
                      _MobileDrawerSubItem(
                        title: 'Product',
                        onTap: () => navigate(14),
                      ),
                    if (hasStockPermission)
                      _MobileDrawerSubItem(
                        title: 'Stock',
                        onTap: () => navigate(15),
                      ),
                    if (hasBarcodePermission)
                      _MobileDrawerSubItem(
                        title: 'Product Barcode',
                        onTap: () => navigate(83),
                      ),
                  ],
                ),
              ),
            if (hasPurchase)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.shopping_bag_rounded,
                  title: 'Purchase',
                  onTap: () => navigate(81),
                  selected:
                      [81, 82, 36].contains(sideBarController.index.value),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReportsSection(
    SideBarController sideBarController,
    void Function(int index) navigate,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasSalesExecutiveReportsPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.reports.sales_executive.access');
        final hasExecutiveSummaryPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.reports.executive_summary.access');
        final hasCustomerTransactionsPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.reports.customer_transactions.access');
        final hasSupplierTransactionsPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.reports.supplier_transactions.access');
        final hasNonStockPermission = roleProvider
            .currentUserHasPermissionSync('menu.reports.non_stock.access');
        final hasConsumedStockPermission = roleProvider
            .currentUserHasPermissionSync('menu.reports.consumed_stock.access');
        final isCompanyAdmin = userRole == 'company_admin';
        final hasStockReportPermission = roleProvider
            .currentUserHasPermissionSync('menu.reports.stock.access') ||
            isCompanyAdmin;
        final canViewExecutiveSummary = isCompanyAdmin ||
            (hasExecutiveSummaryPermission && userRole != 'sales_executive');

        if (!hasSalesExecutiveReportsPermission &&
            !hasCustomerTransactionsPermission &&
            !hasSupplierTransactionsPermission &&
            !canViewExecutiveSummary &&
            !hasStockReportPermission &&
            !hasNonStockPermission &&
            !hasConsumedStockPermission &&
            !isCompanyAdmin) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Reports'),
            Obx(
              () => _MobileDrawerExpandableTile(
                icon: Icons.analytics_rounded,
                title: 'Reports',
                selected: [
                  39,
                  40,
                  41,
                  42,
                  58,
                  65,
                  66,
                  67,
                  68,
                  77,
                  80,
                  85,
                  98,
                ].contains(sideBarController.index.value),
                subItems: [
                  if (hasSalesExecutiveReportsPermission)
                    _MobileDrawerSubItem(
                      title: 'Sales Executive Reports',
                      onTap: () => navigate(58),
                    ),
                  if (canViewExecutiveSummary)
                    _MobileDrawerSubItem(
                      title: 'Executive Reports',
                      onTap: () => navigate(85),
                    ),
                  if (hasCustomerTransactionsPermission)
                    _MobileDrawerSubItem(
                      title: 'Customer Transactions Reports',
                      onTap: () => navigate(65),
                    ),
                  if (hasSupplierTransactionsPermission)
                    _MobileDrawerSubItem(
                      title: 'Supplier Transactions Reports',
                      onTap: () => navigate(67),
                    ),
                  if (hasStockReportPermission)
                    _MobileDrawerSubItem(
                      title: 'Stock Report',
                      onTap: () => navigate(98),
                    ),
                  if (hasNonStockPermission)
                    _MobileDrawerSubItem(
                      title: 'Non-Stock Report',
                      onTap: () => navigate(77),
                    ),
                  if (hasConsumedStockPermission)
                    _MobileDrawerSubItem(
                      title: 'Consumed Stocks Report',
                      onTap: () => navigate(80),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountsSection(
    SideBarController sideBarController,
    void Function(int index) navigate,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasInvoicePermission = roleProvider
            .currentUserHasPermissionSync('menu.transactions.invoice.access');
        final hasProformaPermission = roleProvider
            .currentUserHasPermissionSync('menu.transactions.proforma.access');
        final hasReceiptsPermission = roleProvider
            .currentUserHasPermissionSync('menu.transactions.receipts.access');
        final hasCustomerVouchersPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.transactions.customer_voucher.access');
        final hasSupplierVouchersPermission =
            roleProvider.currentUserHasPermissionSync(
                'menu.transactions.supplier_voucher_purchase.access');
        final hasPartyCustomer = roleProvider.currentUserHasPermissionSync(
            'menu.party_accounts.customer_transactions.access');
        final hasPartySupplier = roleProvider.currentUserHasPermissionSync(
            'menu.party_accounts.supplier_transactions.access');

        final hasTransactions = hasInvoicePermission ||
            hasReceiptsPermission ||
            hasCustomerVouchersPermission ||
            hasSupplierVouchersPermission ||
            hasProformaPermission;
        final hasPartyAccounts = hasPartyCustomer || hasPartySupplier;

        if (!hasTransactions && !hasPartyAccounts) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Accounts'),
            if (hasTransactions)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Transactions',
                  selected: [
                    21,
                    24,
                    30,
                    31,
                    47,
                    48,
                    70,
                    71,
                    75,
                    76,
                    91,
                    93,
                    94,
                    95,
                  ].contains(sideBarController.index.value),
                  subItems: [
                    if (hasInvoicePermission)
                      _MobileDrawerSubItem(
                        title: 'Invoice',
                        onTap: () => navigate(21),
                      ),
                    if (hasReceiptsPermission)
                      _MobileDrawerSubItem(
                        title: 'Receipts',
                        onTap: () => navigate(47),
                      ),
                    if (hasCustomerVouchersPermission)
                      _MobileDrawerSubItem(
                        title: 'Customer Voucher',
                        onTap: () => navigate(70),
                      ),
                    if (hasSupplierVouchersPermission)
                      _MobileDrawerSubItem(
                        title: 'Supplier Voucher (Purchase Entry)',
                        onTap: () => navigate(75),
                      ),
                    if (hasProformaPermission)
                      _MobileDrawerSubItem(
                        title: 'Proforma Invoice',
                        onTap: () => navigate(91),
                      ),
                    _MobileDrawerSubItem(
                      title: 'Expense',
                      onTap: () => navigate(93),
                    ),
                  ],
                ),
              ),
            if (hasPartyAccounts)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Party Accounts',
                  selected: [23, 74].contains(sideBarController.index.value),
                  subItems: [
                    if (hasPartyCustomer)
                      _MobileDrawerSubItem(
                        title: 'Customer Transactions',
                        onTap: () => navigate(23),
                      ),
                    if (hasPartySupplier)
                      _MobileDrawerSubItem(
                        title: 'Supplier Transactions',
                        onTap: () => navigate(74),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDirectorySection(
    SideBarController sideBarController,
    void Function(int index) navigate,
    VoidCallback fetchSuppliers,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasCustomers = roleProvider
            .currentUserHasPermissionSync('menu.customers.main.access');
        final hasSuppliersPermission = roleProvider
            .currentUserHasPermissionSync('menu.suppliers.list.access');
        final hasSupplierTransactionsPermission = roleProvider
            .currentUserHasPermissionSync('menu.suppliers.transactions.access');
        final hasSupplierVouchersPermission = roleProvider
            .currentUserHasPermissionSync('menu.suppliers.voucher.access');

        final hasSuppliersGroup = hasSuppliersPermission ||
            hasSupplierTransactionsPermission ||
            hasSupplierVouchersPermission;

        if (!hasCustomers && !hasSuppliersGroup) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Directory'),
            if (hasCustomers)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.people_rounded,
                  title: 'Customers',
                  onTap: () => navigate(5),
                  selected:
                      [5, 9, 10, 38].contains(sideBarController.index.value),
                ),
              ),
            if (hasSuppliersGroup)
              Obx(
                () => _MobileDrawerExpandableTile(
                  icon: Icons.local_shipping_rounded,
                  title: 'Suppliers',
                  selected: [52, 57, 69, 4, 72, 73]
                      .contains(sideBarController.index.value),
                  subItems: [
                    if (hasSuppliersPermission)
                      _MobileDrawerSubItem(
                        title: 'Suppliers',
                        onTap: () {
                          fetchSuppliers();
                          navigate(52);
                        },
                      ),
                    if (hasSupplierTransactionsPermission)
                      _MobileDrawerSubItem(
                        title: 'Supplier Transactions',
                        onTap: () => navigate(4),
                      ),
                    if (hasSupplierVouchersPermission)
                      _MobileDrawerSubItem(
                        title: 'Supplier Voucher',
                        onTap: () => navigate(72),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsSection(
    SideBarController sideBarController,
    void Function(int index) navigate,
  ) {
    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        final hasPrinter = roleProvider
            .currentUserHasPermissionSync('menu.settings.printer.access');
        final hasSettings = roleProvider
            .currentUserHasPermissionSync('menu.settings.main.access');

        if (!hasPrinter && !hasSettings) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MobileSectionDivider(),
            const _MobileSectionHeader(title: 'Settings'),
            if (hasPrinter)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.print_rounded,
                  title: 'Printer',
                  onTap: () => navigate(53),
                  selected: sideBarController.index.value == 53,
                ),
              ),
            if (hasSettings)
              Obx(
                () => _MobileDrawerTile(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () => navigate(62),
                  selected: [62, 63].contains(sideBarController.index.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MobileDrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SidebarBrandLogo(height: 28)),
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider.currentUserHasPermissionSync(
                  'menu.utility.user_switcher.access')) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: UserSwitcher(compact: true),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileSectionHeader extends StatelessWidget {
  final String title;

  const _MobileSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.6,
          ColorManager.kGreyColor,
        ),
      ),
    );
  }
}

class _MobileSectionDivider extends StatelessWidget {
  const _MobileSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(
        height: 1,
        thickness: 1,
        color: ColorManager.kPrimaryColor.withOpacity(0.12),
      ),
    );
  }
}

class _MobileDrawerSubItem {
  final String title;
  final VoidCallback onTap;

  const _MobileDrawerSubItem({
    required this.title,
    required this.onTap,
  });
}

class _MobileDrawerExpandableTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final List<_MobileDrawerSubItem> subItems;

  const _MobileDrawerExpandableTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.subItems,
  });

  @override
  State<_MobileDrawerExpandableTile> createState() =>
      _MobileDrawerExpandableTileState();
}

class _MobileDrawerExpandableTileState
    extends State<_MobileDrawerExpandableTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.selected;
  }

  @override
  void didUpdateWidget(covariant _MobileDrawerExpandableTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.subItems.length == 1) {
      return _MobileDrawerTile(
        icon: widget.icon,
        title: widget.title,
        selected: widget.selected,
        onTap: widget.subItems.first.onTap,
      );
    }

    final foregroundColor =
        widget.selected ? Colors.white : ColorManager.kTitleTextColor;
    final iconColor =
        widget.selected ? Colors.white : ColorManager.kPrimaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: widget.selected
                ? ColorManager.kPrimaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            elevation: widget.selected ? 1 : 0,
            shadowColor: ColorManager.kPrimaryColor.withOpacity(0.25),
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 22, color: iconColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 15,
                            color: foregroundColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: iconColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final subItem in widget.subItems)
                    _MobileDrawerSubTile(
                      title: subItem.title,
                      onTap: subItem.onTap,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileDrawerSubTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MobileDrawerSubTile({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorManager.kPrimaryColor.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: ColorManager.kTitleTextColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileDrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _MobileDrawerTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? ColorManager.kPrimaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: selected ? 1 : 0,
        shadowColor: ColorManager.kPrimaryColor.withOpacity(0.25),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : ColorManager.kPrimaryColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 15,
                        color: selected
                            ? Colors.white
                            : ColorManager.kTitleTextColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileDrawerFooter extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _MobileDrawerFooter({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: ColorManager.kPrimaryColor.withOpacity(0.12)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider.currentUserHasPermissionSync(
                  'menu.utility.store_switcher.access')) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: StoreSwitcher(),
              );
            },
          ),
          const SizedBox(height: 4),
          _MobileDrawerTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            selected: false,
            onTap: () => onLogout(),
          ),
          const SizedBox(height: 6),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version =
                  snapshot.hasData ? 'v${snapshot.data!.version}' : 'CloudPOS';
              return Center(
                child: Text(
                  version,
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.2,
                    ColorManager.kGreyColor,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
