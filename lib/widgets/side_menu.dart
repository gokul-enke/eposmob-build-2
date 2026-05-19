import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart' as fa;

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../controllers/sidebar_controller.dart';
import '../providers/auth_model.dart';
import '../providers/admin_settings_provider.dart';
import '../providers/authentication_providers.dart';

import '../providers/sales_provider.dart';
import '../providers/shared_preferences.dart';
import '../providers/supplier_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../screens/login/login.dart';
import '../services/session_reset_service.dart';
import 'drawer_list_tile_expandable.dart';
import '../widgets/user_switcher.dart';
import '../widgets/store_switcher.dart';
import '../providers/role_provider.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Widget child;
  final Widget sidebarContent;

  const CollapsibleSidebar({
    super.key,
    required this.child,
    required this.sidebarContent,
  });

  @override
  CollapsibleSidebarState createState() => CollapsibleSidebarState();
}

class CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;
  final double _expandedWidth = 200;
  final double _collapsedWidth = 60;

  // Public getter for child widgets to access expanded state
  bool get isExpanded => _isExpanded;

  void _toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded ? _expandedWidth : _collapsedWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              // ExcludeFocus keeps the side menu out of Tab traversal so that
              // an accidental click on a side-menu item never traps the user
              // inside the menu's focus tree (which previously broke the
              // billing-page Tab order). Gestures (clicks, taps) still work
              // normally because ExcludeFocus only blocks focus, not pointer
              // input.
              child: ExcludeFocus(
                excluding: true,
                child: KeyedSubtree(
                  key: ValueKey(_isExpanded),
                  child: widget.sidebarContent,
                ),
              ),
            ),
            // Wrap child in a stateful widget to preserve its state
            Expanded(
              child: _PreservedChild(
                child: widget.child,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Helper widget to preserve child state during parent rebuilds
class _PreservedChild extends StatefulWidget {
  final Widget child;

  const _PreservedChild({
    required this.child,
  });

  @override
  _PreservedChildState createState() => _PreservedChildState();
}

class _PreservedChildState extends State<_PreservedChild>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    // Roles are now loaded during store bootstrap for better performance
    // But if they failed to load (e.g. network error), retry here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = Provider.of<RoleProvider>(context, listen: false);
      debugPrint(
          "🟡 [SideMenu] initState postFrame: roles count=${roleProvider.roles.length}, currentUserRole='${roleProvider.currentUserRole}'");
      if (roleProvider.roles.isEmpty) {
        debugPrint("🟡 [SideMenu] roles empty — triggering fetchRoles retry");
        roleProvider.fetchRoles(context);
      }
    });
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
    debugPrint("🟡 [SideMenu] _loadUserRole: loaded role = '$role'");
    setState(() {
      userRole = role;
    });
  }

  bool get _isExpanded {
    final sidebarState =
        context.findAncestorStateOfType<CollapsibleSidebarState>();
    return sidebarState?.isExpanded ?? true;
  }

  @override
  Widget build(BuildContext context) {
    SideBarController sideBarController = Get.put(SideBarController());
    final authModel = Provider.of<AuthModel>(context);
    final isExpanded = _isExpanded;

    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    debugPrint(
        "🟡 [SideMenu] build: userRole='$userRole' | roles loaded=${roleProvider.roles.length} | _currentUserRole='${roleProvider.currentUserRole}'");
    for (final r in roleProvider.roles) {
      debugPrint(
          "   🔹 role: '${r.originalName}' permissions: ${r.permissions.take(5).toList()}...");
    }
    debugPrint(
        "🟡 [SideMenu] permission checks — view_order=${roleProvider.currentUserHasPermissionSync('view_order')}, page_SalesExecutiveReport=${roleProvider.currentUserHasPermissionSync('page_SalesExecutiveReport')}, page_CustomerTransactionReport=${roleProvider.currentUserHasPermissionSync('page_CustomerTransactionReport')}");

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: isExpanded ? 8 : 6),
          // Modern toggle button - aligned to right in expanded, centered in collapsed
          Align(
            alignment: isExpanded ? Alignment.centerRight : Alignment.center,
            child: Container(
              margin: EdgeInsets.only(
                  right: isExpanded ? 10 : 8,
                  left: isExpanded ? 10 : 8,
                  top: isExpanded ? 8 : 6,
                  bottom: isExpanded ? 8 : 6),
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  isExpanded ? Icons.menu_open : Icons.menu,
                  color: ColorManager.kPrimaryColor,
                  size: isExpanded ? 24 : 16,
                ),
                tooltip: isExpanded ? 'Collapse Sidebar' : 'Expand Sidebar',
                padding: EdgeInsets.all(isExpanded ? 8 : 8),
                constraints: const BoxConstraints(),
                onPressed: () {
                  final CollapsibleSidebarState? sidebarState = context
                      .findAncestorStateOfType<CollapsibleSidebarState>();
                  sidebarState?._toggleSidebar();
                },
              ),
            ),
          ),
          SizedBox(height: isExpanded ? 12 : 8),
          // Logo - only show when expanded
          if (isExpanded)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SidebarBrandLogo(height: 35),
            ),
          if (!isExpanded) const SizedBox.shrink(),
          // const SizedBox(
          //   height: 5,
          // ),
          // Center(
          //   child: RichText(
          //     textAlign: TextAlign.center,
          //     text: TextSpan(
          //       text: 'Cloud',
          //       style: buildCustomStyle(FontWeightManager.semiBold,
          //           FontSize.s18, 0.27, ColorManager.textColor),
          //       children: <TextSpan>[
          //         TextSpan(
          //           text: 'POS',
          //           style: buildCustomStyle(FontWeightManager.semiBold,
          //               FontSize.s18, 0.27, ColorManager.kPrimaryColor),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          if (isExpanded)
            Consumer<RoleProvider>(
              builder: (context, roleProvider, child) {
                final hasPermission = roleProvider.currentUserHasPermissionSync(
                    'menu.utility.user_switcher.access');

                if (!hasPermission) {
                  return const SizedBox.shrink();
                }

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Builder(
                      builder: (context) {
                        debugPrint("🔧 SideMenu: Building UserSwitcher widget");
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15.0),
                          child: UserSwitcher(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          SizedBox(height: isExpanded ? 12 : 8),
          // Menu section divider
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 1,
              ),
            ),
          SizedBox(height: isExpanded ? 6 : 4),
          // ========== REORGANIZED MENU (Font Awesome Icons) ==========

          // 1. HOME (Index: 46)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.home.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.home,
                  title: 'Home',
                  onTap: () {
                    sideBarController.index.value = 46;
                  },
                  selected: sideBarController.index.value == 46,
                ),
              );
            },
          ),

          // 2. DASHBOARD (Index: 1)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.dashboard.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.chartLine,
                  title: 'Dashboard',
                  onTap: () {
                    sideBarController.index.value = 1;
                  },
                  selected: sideBarController.index.value == 1,
                ),
              );
            },
          ),

          // 1. HOME (Index: 46)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.restaurant.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.home,
                  title: 'Restaurant Legacy',
                  onTap: () {
                    sideBarController.index.value = 89;
                  },
                  selected: sideBarController.index.value == 89,
                ),
              );
            },
          ),
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.restaurant.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.home,
                  title: 'Restaurant',
                  onTap: () {
                    sideBarController.index.value = 46;
                  },
                  selected: sideBarController.index.value == 46,
                ),
              );
            },
          ),

          // 3. RESTAURANT (Index: 55) - Only for attender role
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider.currentUserHasPermissionSync(
                  'menu.restaurant.attender.access');
              if (!hasPermission) {
                return const SizedBox.shrink();
              }
              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.utensils,
                  title: 'Attender',
                  onTap: () {
                    sideBarController.index.value = 55;
                  },
                  selected: sideBarController.index.value == 55,
                ),
              );
            },
          ),

          // 4. KITCHEN MASTER (Index: 56) - Only for kitchen_master role
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider.currentUserHasPermissionSync(
                  'menu.restaurant.kitchen_master.access');
              if (!hasPermission) {
                return const SizedBox.shrink();
              }
              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.utensils,
                  title: 'Kitchen Master',
                  onTap: () {
                    sideBarController.index.value = 56;
                  },
                  selected: sideBarController.index.value == 56,
                ),
              );
            },
          ),
          // 5. SALES (Index: 2) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasSalesMenuPermission = roleProvider
                  .currentUserHasPermissionSync('menu.sales.orders.access');
              final hasSalesPermission = roleProvider
                  .currentUserHasPermissionSync('menu.sales.orders.access');
              final hasConfirmedOrdersPermission =
                  // roleProvider.currentUserHasPermissionSync('view_order');
                  roleProvider.currentUserHasPermissionSync(
                      'menu.sales.confirmed_orders.access');
              final hasSalesReturnPermission = roleProvider
                  // .currentUserHasPermissionSync('page_CreateSalesReturn');
                  .currentUserHasPermissionSync('menu.sales.returns.access');
              final hasDayClosingPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.sales.day_closing.access');
              final hasQuotationsPermission =
                  true; // TODO: revert to roleProvider check when backend adds 'menu.sales.quotations.access'
              final isCompanyAdmin = userRole == 'company_admin';

              // Only show the expandable menu if user has at least one permission
              if (!hasSalesMenuPermission &&
                  !hasSalesPermission &&
                  !hasConfirmedOrdersPermission &&
                  !hasSalesReturnPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                  onTapTitle1: () {
                    sideBarController.index.value = 2;
                  },
                  onTapTitle2: () {
                    sideBarController.index.value = 54;
                  },
                  onTapTitle3: () {
                    sideBarController.index.value = 50;
                  },
                  onTapTitle4: () {
                    sideBarController.index.value = 78;
                  },
                  onTapTitle5: () {
                    sideBarController.index.value = 84;
                  },
                  onTapTitle6: () {
                    sideBarController.index.value = 86;
                  },
                  listTitle1: "Sales",
                  listTitle2: "Confirmed Orders",
                  listTitle3: "Sales Return",
                  listTitle4: "Day Sale Closing",
                  listTitle5: "Admin Day Sale records",
                  listTitle6: "Quotations",

                  // Permission-based visibility
                  showTitle1: hasSalesPermission,
                  showTitle2: hasConfirmedOrdersPermission && !isCompanyAdmin,
                  showTitle3: hasSalesReturnPermission && !isCompanyAdmin,
                  showTitle4: hasDayClosingPermission && !isCompanyAdmin,
                  showTitle5: isCompanyAdmin && hasDayClosingPermission,
                  showTitle6: hasQuotationsPermission,
                  icon: fa.FontAwesomeIcons.shoppingCart,
                  title: 'Sales',
                  onTap: () {
                    sideBarController.index.value = 2;
                    final salesProvider =
                        Provider.of<SalesProvider>(context, listen: false);
                    String? accessToken =
                        Provider.of<AuthModel>(context, listen: false).token;
                    salesProvider.fetchOrders(
                      accessToken: accessToken ?? '',
                      storeId: 1,
                    );
                  },
                  selected: sideBarController.index.value == 2 ||
                      sideBarController.index.value == 11 ||
                      sideBarController.index.value == 49 ||
                      sideBarController.index.value == 50 ||
                      sideBarController.index.value == 51 ||
                      sideBarController.index.value == 54 ||
                      sideBarController.index.value == 78 ||
                      sideBarController.index.value == 79 ||
                      sideBarController.index.value == 84 ||
                      sideBarController.index.value == 86,
                ),
              );
            },
          ),
          // 6. CATEGORY (Index: 12)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.catalog.category.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.tags,
                  title: 'Category',
                  onTap: () {
                    sideBarController.index.value = 12;
                  },
                  selected: sideBarController.index.value == 12 ||
                      sideBarController.index.value == 13 ||
                      sideBarController.index.value == 16 ||
                      sideBarController.index.value == 27 ||
                      sideBarController.index.value == 34,
                ),
              );
            },
          ),

          // 7. PRODUCT (Index: 14) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasProductPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.catalog.product.list.access');
              final hasStockPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.catalog.product.stock.access');
              final hasBarcodePermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.catalog.product.barcode.access');

              // Only show the expandable menu if user has at least one permission
              if (!hasProductPermission &&
                  !hasStockPermission &&
                  !hasBarcodePermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 14;
                    },
                    onTapTitle2: () {
                      sideBarController.index.value = 15;
                    },
                    onTapTitle3: () {
                      sideBarController.index.value = 83;
                    },
                    listTitle1: "Product",
                    listTitle2: "Stock",
                    listTitle3: "Product Barcode",
                    // Permission-based visibility
                    showTitle1: hasProductPermission,
                    showTitle2: hasStockPermission,
                    showTitle3: hasBarcodePermission,
                    icon: fa.FontAwesomeIcons.cube,
                    title: 'Product',
                    onTap: () async {
                      sideBarController.index.value = 14;
                    },
                    selected: sideBarController.index.value == 14 ||
                        sideBarController.index.value == 15 ||
                        sideBarController.index.value == 17 ||
                        sideBarController.index.value == 18 ||
                        sideBarController.index.value == 28 ||
                        sideBarController.index.value == 33 ||
                        sideBarController.index.value == 83 ||
                        sideBarController.index.value == 35),
              );
            },
          ),

          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider.currentUserHasPermissionSync(
                  'menu.purchase.orders.access')) {
                return const SizedBox.shrink();
              }
              // Check permissions for each sub-item
              // final hasPurchasePermission = roleProvider
              //         .currentUserHasPermissionSync('page_StockManagement') ||
              //     roleProvider.currentUserHasPermissionSync(
              //         'menu.purchase.orders.access');
              final hasPurchasePermission = roleProvider
                  .currentUserHasPermissionSync('menu.purchase.orders.access');

              // Only show the expandable menu if user has at least one permission
              if (!hasPurchasePermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 81;
                    },
                    listTitle1: "Purchase Orders",
                    // Permission-based visibility
                    showTitle1: hasPurchasePermission,
                    icon: fa.FontAwesomeIcons.clipboardList,
                    title: 'Purchase',
                    onTap: () async {
                      sideBarController.index.value = 81;
                    },
                    selected:
                        [81, 82, 36].contains(sideBarController.index.value)),
              );
            },
          ),
          // 8. REPORTS (Index: 58) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              // final hasSalesExecutiveReportsPermission = roleProvider
              //         .currentUserHasPermissionSync('page_SalesExecutiveReport') ||
              //     roleProvider.currentUserHasPermissionSync(
              //         'menu.reports.sales_executive.access');
              final hasSalesExecutiveReportsPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.sales_executive.access');
              final hasExecutiveSummaryPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.executive_summary.access');
              final hasCustomerTransactionsPermission =
                  // roleProvider.currentUserHasPermissionSync(
                  //     'page_CustomerTransactionReport') ||
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.customer_transactions.access');
              final hasSupplierTransactionsPermission =
                  // roleProvider.currentUserHasPermissionSync(
                  //     'page_SupplierTransactionsReport') ||
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.supplier_transactions.access');
              final hasNonStockPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.non_stock.access');
              final hasConsumedStockPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.reports.consumed_stock.access');
              final isCompanyAdmin = userRole == 'company_admin';

              // Only show the expandable menu if user has at least one permission
              if (!hasSalesExecutiveReportsPermission &&
                  !hasCustomerTransactionsPermission &&
                  !hasSupplierTransactionsPermission &&
                  !hasExecutiveSummaryPermission &&
                  !hasNonStockPermission &&
                  !hasConsumedStockPermission &&
                  !isCompanyAdmin) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 58;
                    },
                    onTapTitle2: () {
                      sideBarController.index.value = 85;
                    },
                    onTapTitle3: () {
                      sideBarController.index.value = 65;
                    },
                    onTapTitle4: () {
                      sideBarController.index.value = 67;
                    },
                    onTapTitle5: () {
                      sideBarController.index.value = 77;
                    },
                    onTapTitle6: () {
                      sideBarController.index.value = 80;
                    },
                    listTitle1: "Sales Executive Reports",
                    listTitle2: "Executive Reports",
                    listTitle3: "Customer Transactions Reports",
                    listTitle4: "Supplier Transactions Reports",
                    listTitle5: "Non-Stock Report",
                    listTitle6: "Consumed Stocks Report",
                    // Permission-based visibility
                    showTitle1:
                        hasSalesExecutiveReportsPermission && !isCompanyAdmin,
                    showTitle2: isCompanyAdmin || hasExecutiveSummaryPermission,
                    showTitle3: hasCustomerTransactionsPermission,
                    showTitle4: hasSupplierTransactionsPermission,
                    showTitle5: hasNonStockPermission,
                    showTitle6: hasConsumedStockPermission,
                    icon: fa.FontAwesomeIcons.chartPie,
                    title: 'Reports',
                    onTap: () {
                      sideBarController.index.value = isCompanyAdmin ? 85 : 58;
                    },
                    selected: sideBarController.index.value == 39 ||
                        sideBarController.index.value == 40 ||
                        sideBarController.index.value == 41 ||
                        sideBarController.index.value == 42 ||
                        sideBarController.index.value == 58 ||
                        sideBarController.index.value == 65 ||
                        sideBarController.index.value == 66 ||
                        sideBarController.index.value == 67 ||
                        sideBarController.index.value == 68 ||
                        sideBarController.index.value == 77 ||
                        sideBarController.index.value == 80 ||
                        sideBarController.index.value == 85),
              );
            },
          ),

          // 9. TRANSACTIONS (Index: 21) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider.currentUserHasPermissionSync(
                  'menu.transactions.invoice.access')) {
                return const SizedBox.shrink();
              }
              // Check permissions for each sub-item
              // final hasInvoicePermission =
              //     roleProvider.currentUserHasPermissionSync('page_Invoices') ||
              //         roleProvider.currentUserHasPermissionSync(
              //             'menu.transactions.invoice.access');
              final hasInvoicePermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.transactions.invoice.access');

              // final hasReceiptsPermission =
              //     roleProvider.currentUserHasPermissionSync('page_Receipts') ||
              //         roleProvider.currentUserHasPermissionSync(
              //             'menu.transactions.receipts.access');
              final hasReceiptsPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.transactions.receipts.access');
              // final hasCustomerVouchersPermission =
              //     roleProvider.currentUserHasPermissionSync('page_Vouchers') ||
              //         roleProvider.currentUserHasPermissionSync(
              //             'menu.transactions.customer_voucher.access');
              final hasCustomerVouchersPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.transactions.customer_voucher.access');
              // final hasSupplierVouchersPermission = roleProvider
              //     .currentUserHasPermissionSync('view_company::account') ||
              //     roleProvider.currentUserHasPermissionSync(
              //         'menu.transactions.supplier_voucher_purchase.access');
              final hasSupplierVouchersPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.transactions.supplier_voucher_purchase.access');

              // Only show the expandable menu if user has at least one permission
              if (!hasInvoicePermission &&
                  !hasReceiptsPermission &&
                  !hasCustomerVouchersPermission &&
                  !hasSupplierVouchersPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 21;
                    },
                    onTapTitle2: () {
                      sideBarController.index.value = 47;
                    },
                    onTapTitle3: () {
                      sideBarController.index.value = 70;
                    },
                    onTapTitle4: () {
                      sideBarController.index.value = 75;
                    },
                    listTitle1: "Invoice",
                    listTitle2: "Receipts",
                    listTitle3: "Customer Voucher",
                    listTitle4: "Supplier Voucher (Purchase Entry)",
                    // Permission-based visibility
                    showTitle1: hasInvoicePermission,
                    showTitle2: hasReceiptsPermission,
                    showTitle3: hasCustomerVouchersPermission,
                    showTitle4: hasSupplierVouchersPermission,
                    icon: fa.FontAwesomeIcons.exchange,
                    title: 'Transactions',
                    onTap: () {
                      sideBarController.index.value = 21;
                    },
                    selected: sideBarController.index.value == 21 ||
                        sideBarController.index.value == 24 ||
                        sideBarController.index.value == 31 ||
                        sideBarController.index.value == 47 ||
                        sideBarController.index.value == 48 ||
                        sideBarController.index.value == 70 ||
                        sideBarController.index.value == 71 ||
                        sideBarController.index.value == 75 ||
                        sideBarController.index.value == 76 ||
                        sideBarController.index.value == 30),
              );
            },
          ),
          // 10. PARTY ACCOUNTS (Index: 4) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider.currentUserHasPermissionSync(
                      'menu.party_accounts.customer_transactions.access') &&
                  !roleProvider.currentUserHasPermissionSync(
                      'menu.party_accounts.supplier_transactions.access')) {
                return const SizedBox.shrink();
              }
              // Check permissions for each sub-item
              final hasCustomerTransactionsPermission = roleProvider
                  // .currentUserHasPermissionSync('page_CustomerTransactions');
                  .currentUserHasPermissionSync(
                      'menu.party_accounts.customer_transactions.access');
              final hasSupplierTransactionsPermission = roleProvider
                  // .currentUserHasPermissionSync('page_SupplierTransactions');
                  .currentUserHasPermissionSync(
                      'menu.party_accounts.supplier_transactions.access');

              // Only show the expandable menu if user has at least one permission
              if (!hasCustomerTransactionsPermission &&
                  !hasSupplierTransactionsPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 23;
                    },
                    onTapTitle2: () {
                      sideBarController.index.value = 74; // alias index
                    },
                    listTitle1: "Customer Transactions",
                    listTitle2: "Supplier Transactions",
                    // Permission-based visibility
                    showTitle1: hasCustomerTransactionsPermission,
                    showTitle2: hasSupplierTransactionsPermission,
                    icon: fa.FontAwesomeIcons.users,
                    title: 'Party Accounts',
                    onTap: () {
                      sideBarController.index.value = 23;
                    },
                    selected: sideBarController.index.value == 23 ||
                        sideBarController.index.value == 74),
              );
            },
          ),
          // 11. CUSTOMERS (Index: 5)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.customers.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.users,
                  title: 'Customers',
                  onTap: () {
                    sideBarController.index.value = 5;
                  },
                  selected: sideBarController.index.value == 5 ||
                      sideBarController.index.value == 9 ||
                      sideBarController.index.value == 10 ||
                      sideBarController.index.value == 38,
                ),
              );
            },
          ),
          // 12. COMPANY (Store, About)
          // Consumer<RoleProvider>(
          //   builder: (context, roleProvider, child) {
          //     final hasStorePermission =
          //         roleProvider.currentUserHasPermissionSync('view_store');
          //     final hasAboutPermission =
          //         roleProvider.currentUserHasPermissionSync('view_setting');

          //     if (!hasStorePermission && !hasAboutPermission) {
          //       return const SizedBox.shrink();
          //     }

          //     return Obx(
          //       () => DrawerListTileExpandableColumn(
          //         onTapTitle1: () {
          //           sideBarController.index.value = 43;
          //         },
          //         onTapTitle2: () {
          //           sideBarController.index.value = 64;
          //         },
          //         listTitle1: "Store",
          //         listTitle2: "About",
          //         // Permission-based visibility
          //         showTitle1: hasStorePermission,
          //         showTitle2: hasAboutPermission,
          //         icon: fa.FontAwesomeIcons.building,
          //         title: 'Company',
          //         onTap: () {
          //           sideBarController.index.value = 43;
          //         },
          //         selected: sideBarController.index.value == 43 ||
          //             sideBarController.index.value == 44 ||
          //             sideBarController.index.value == 64,
          //       ),
          //     );
          //   },
          // ),
          // 13. SUPPLIERS (Index: 52) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasSuppliersPermission = roleProvider
                  .currentUserHasPermissionSync('menu.suppliers.list.access');
              final hasSupplierTransactionsPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.suppliers.transactions.access');
              final hasSupplierVouchersPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'menu.suppliers.voucher.access');

              if (!hasSuppliersPermission &&
                  !hasSupplierTransactionsPermission &&
                  !hasSupplierVouchersPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                  onTapTitle1: () {
                    sideBarController.index.value = 52;
                    final supplierProvider =
                        Provider.of<SupplierProvider>(context, listen: false);
                    String? accessToken =
                        Provider.of<AuthModel>(context, listen: false).token;
                    supplierProvider.fetchSuppliers(
                        accessToken: accessToken ?? '');
                  },
                  onTapTitle2: () {
                    sideBarController.index.value = 4;
                  },
                  onTapTitle3: () {
                    sideBarController.index.value = 72;
                  },
                  listTitle1: "Suppliers",
                  listTitle2: "Supplier Transactions",
                  listTitle3: "Supplier Voucher",
                  // Permission-based visibility
                  showTitle1: hasSuppliersPermission,
                  showTitle2: hasSupplierTransactionsPermission,
                  showTitle3: hasSupplierVouchersPermission,
                  icon: fa.FontAwesomeIcons.truck,
                  title: 'Suppliers',
                  onTap: () {
                    sideBarController.index.value = 52;
                    final supplierProvider =
                        Provider.of<SupplierProvider>(context, listen: false);
                    String? accessToken =
                        Provider.of<AuthModel>(context, listen: false).token;
                    supplierProvider.fetchSuppliers(
                        accessToken: accessToken ?? '');
                  },
                  selected: sideBarController.index.value == 52 ||
                      sideBarController.index.value == 57 ||
                      sideBarController.index.value == 69 ||
                      sideBarController.index.value == 4 ||
                      sideBarController.index.value == 72 ||
                      sideBarController.index.value == 73,
                ),
              );
            },
          ),
          // 14. PRINTER (Index: 53)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.settings.printer.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isExpanded) const SizedBox(height: 15),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(left: 45.0),
                      child: Text(
                        'Other',
                        style: buildCustomStyle(FontWeightManager.medium,
                            FontSize.s13, 0.16, ColorManager.textColor),
                      ),
                    ),
                  if (isExpanded) const SizedBox(height: 15),
                  Obx(
                    () => DrawerListTile(
                      icon: fa.FontAwesomeIcons.print,
                      title: 'Printer',
                      onTap: () {
                        sideBarController.index.value = 53;
                      },
                      selected: sideBarController.index.value == 53,
                    ),
                  ),
                ],
              );
            },
          ),

          // 15. SETTINGS (Index: 62)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission = roleProvider
                  .currentUserHasPermissionSync('menu.settings.main.access');

              if (!hasPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTile(
                  icon: fa.FontAwesomeIcons.gear,
                  title: 'Settings',
                  onTap: () {
                    sideBarController.index.value = 62;
                  },
                  selected: sideBarController.index.value == 62 ||
                      sideBarController.index.value == 63,
                ),
              );
            },
          ),
          // LOGOUT
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              if (!roleProvider
                  .currentUserHasPermissionSync('menu.session.logout.access')) {
                return const SizedBox.shrink();
              }
              return DrawerListTile(
                icon: fa.FontAwesomeIcons.signOutAlt,
                title: 'Logout',
                onTap: () async {
                  String token = authModel.token ?? '';
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      });
                  await AuthenticationProvider()
                      .logout(token, context)
                      .then((value) async {
                    if (value["status"] == "success") {
                      await SessionResetService.resetAfterLogout(context);

                      // debugPrint(" authmodel logout token ${authModel.token}");
                      showScaffold(
                        context: context,
                        message: '${value["message"]}',
                      );
                      Navigator.pop(context);
                      await Future.delayed(const Duration(seconds: 0)).then(
                          (value) => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignInScreen())));
                    } else {
                      Navigator.pop(context);
                      showScaffoldError(
                        context: context,
                        message: '${value["message"]}',
                      );
                    }
                  });
                  // debugPrint(" 'Logout',${sideBarController.index.value}");
                },
                selected: false,
              );
            },
          ),
          const SizedBox(
            height: 10,
          ),
          if (isExpanded)
            Container(
              width: 180,
              margin: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage(ImageAssets.profilePhotoIcon),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<String>(
                    future: SharedPreferenceProvider().getCustomerName(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Text(
                          snapshot.data ?? 'Default Name',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.21,
                            ColorManager.textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      } else {
                        return const CircularProgressIndicator();
                      }
                    },
                  ),
                  Consumer<RoleProvider>(
                    builder: (context, roleProvider, child) {
                      final hasPermission =
                          roleProvider.currentUserHasPermissionSync(
                              'menu.utility.store_switcher.access');
                      if (!hasPermission) {
                        return const SizedBox.shrink();
                      }
                      return const Column(
                        children: [
                          SizedBox(height: 16),
                          Divider(height: 1),
                          SizedBox(height: 16),
                          StoreSwitcher(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (isExpanded) const SizedBox(height: 12),
          if (isExpanded)
            Center(
              child: Text(
                '2025 CloudPOS App',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.16,
                  ColorManager.textColor,
                ),
              ),
            ),
          if (isExpanded)
            const SizedBox(
              height: 50,
            ),
        ],
      ),
    );
  }
}

class SidebarBrandLogo extends StatelessWidget {
  final double height;

  const SidebarBrandLogo({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminSettingsProvider>(
      builder: (context, adminSettingsProvider, child) {
        final logoFilePath = adminSettingsProvider.logoFilePath;
        final logoUrl = adminSettingsProvider.logoUrl;

        if (logoFilePath != null && logoFilePath.trim().isNotEmpty) {
          final logoFile = File(logoFilePath);
          if (logoFile.existsSync()) {
            return Image.file(
              logoFile,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildNetworkOrFallbackLogo(logoUrl);
              },
            );
          }
        }

        return _buildNetworkOrFallbackLogo(logoUrl);
      },
    );
  }

  Widget _buildNetworkOrFallbackLogo(String? logoUrl) {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return Image.network(
        logoUrl,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackLogo();
        },
      );
    }

    return _buildFallbackLogo();
  }

  Widget _buildFallbackLogo() {
    return Image.asset(
      ImageAssets.posImageLogo,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

class DrawerListTile extends StatelessWidget {
  final String? iconPath;
  final IconData? icon;
  final String title;
  final int? items;
  final bool selected;
  final VoidCallback onTap;
  final double? iconSize;
  final double? horizontalGap;

  const DrawerListTile({
    super.key,
    this.iconPath,
    this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.items,
    this.iconSize,
    this.horizontalGap,
  });

  @override
  Widget build(BuildContext context) {
    final double resolvedIconSize = iconSize ?? 18.0;
    final double leadingBox = resolvedIconSize + 4.0;
    final double gap = horizontalGap ?? 12.0;
    final sidebarState =
        context.findAncestorStateOfType<CollapsibleSidebarState>();
    final isExpanded = sidebarState?.isExpanded ?? true;

    // Collapsed state - icon only with tooltip
    if (!isExpanded) {
      return Tooltip(
        message: title,
        preferBelow: false,
        verticalOffset: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? ColorManager.kPrimaryColor
                      : Colors.transparent,
                ),
                child: Center(
                  child: icon != null
                      ? Icon(
                          icon,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : ColorManager.kPrimaryColor,
                        )
                      : WebsafeSvg.asset(
                          iconPath!,
                          width: 16,
                          height: 16,
                          colorFilter: ColorFilter.mode(
                            selected
                                ? Colors.white
                                : ColorManager.kPrimaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded state - full tile
    return selected
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ColorManager.kPrimaryColor,
                  ColorManager.kPrimaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: ColorManager.kPrimaryColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              selected: selected,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              horizontalTitleGap: gap,
              visualDensity: const VisualDensity(vertical: -4, horizontal: 0),
              minVerticalPadding: 0,
              onTap: onTap,
              minLeadingWidth: leadingBox,
              leading: SizedBox(
                width: leadingBox,
                height: leadingBox,
                child: Center(
                  child: icon != null
                      ? Icon(
                          icon,
                          color: Colors.white,
                          size: resolvedIconSize,
                        )
                      : WebsafeSvg.asset(
                          iconPath!,
                          width: resolvedIconSize,
                          height: resolvedIconSize,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                ),
              ),
              trailing: items != null
                  ? buildNotification(
                      item: items ?? 0,
                      selected: selected,
                    )
                  : null,
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          )
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 0.5, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  selected: selected,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  horizontalTitleGap: gap,
                  visualDensity:
                      const VisualDensity(vertical: -4, horizontal: 0),
                  minVerticalPadding: 0,
                  minLeadingWidth: leadingBox,
                  leading: SizedBox(
                    width: leadingBox,
                    height: leadingBox,
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon,
                              size: resolvedIconSize,
                              color: ColorManager.kPrimaryColor,
                            )
                          : WebsafeSvg.asset(
                              iconPath!,
                              width: resolvedIconSize,
                              height: resolvedIconSize,
                              colorFilter: const ColorFilter.mode(
                                ColorManager.kPrimaryColor,
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                  ),
                  trailing: items != null
                      ? buildNotification(
                          item: items ?? 0,
                          selected: selected,
                        )
                      : null,
                  title: Text(
                    title,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s14,
                      0.21,
                      ColorManager.textColor,
                    ),
                  ),
                ),
              ),
            ),
          );
  }
}

Widget buildNotification({
  required int item,
  required bool selected,
}) {
  return Stack(
    children: [
      Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : ColorManager.kPrimaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$item',
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeightManager.regular,
              fontFamily: FontConstants.fontFamily,
              fontSize: FontSize.s10,
              letterSpacing: 0.16,
            )),
      ),
    ],
  );
}
