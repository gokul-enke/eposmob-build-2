import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart' as fa;

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

import '../controllers/sidebar_controller.dart';
import '../providers/auth_model.dart';
import '../providers/authentication_providers.dart';

import '../providers/sales_provider.dart';
import '../providers/shared_preferences.dart';
import '../providers/supplier_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../screens/login/login.dart';
import 'drawer_list_tile_expandable.dart';
import '../widgets/user_switcher.dart';
import '../widgets/store_switcher.dart';
import '../providers/role_provider.dart';
import '../providers/local_product_provider.dart';
import '../providers/category_providers.dart';

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
              child: KeyedSubtree(
                key: ValueKey(_isExpanded),
                child: widget.sidebarContent,
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
  }

  void _loadUserRole() async {
    String role = await SharedPreferenceProvider().getUserRole();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Image.asset(
                ImageAssets.posImageLogo,
                height: 35,
                fit: BoxFit.contain,
              ),
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
                final hasPermission =
                    roleProvider.currentUserHasPermissionSync('view_user');

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
          userRole == 'sales_executive'
              ? Consumer<RoleProvider>(
                  builder: (context, roleProvider, child) {
                    final hasPermission = roleProvider
                        .currentUserHasPermissionSync('create_order');

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
                )
              : const SizedBox.shrink(),

          // 1. HOME (Index: 46)
          (userRole == 'restaurant_sales'
              //  || userRole == 'attender'
              )
              ? Consumer<RoleProvider>(
                  builder: (context, roleProvider, child) {
                    final hasPermission = roleProvider
                        .currentUserHasPermissionSync('create_order');

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
                )
              : const SizedBox.shrink(),

          // 2. DASHBOARD (Index: 1)
          (userRole == 'sales_executive' || userRole == 'restaurant_sales')
              ? Consumer<RoleProvider>(
                  builder: (context, roleProvider, child) {
                    final hasPermission =
                        roleProvider.currentUserHasPermissionSync('view_order');

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
                )
              : const SizedBox.shrink(),

          // 3. RESTAURANT (Index: 55) - Only for attender role
          (userRole == 'restaurant_sales' || userRole == 'attender')
              ? Consumer<RoleProvider>(
                  builder: (context, roleProvider, child) {
                    final hasPermission = roleProvider
                        .currentUserHasPermissionSync('create_order');
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
                )
              : const SizedBox.shrink(),

          // 4. KITCHEN MASTER (Index: 56) - Only for kitchen_master role
          (userRole == 'restaurant_sales' || userRole == 'kitchen_master'
              // || userRole == 'attender'
              )
              ? Consumer<RoleProvider>(
                  builder: (context, roleProvider, child) {
                    final hasPermission = roleProvider
                        .currentUserHasPermissionSync('create_order');
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
                )
              : const SizedBox.shrink(),
          // 5. SALES (Index: 2) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasSalesPermission =
                  roleProvider.currentUserHasPermissionSync('view_order');
              final hasConfirmedOrdersPermission =
                  roleProvider.currentUserHasPermissionSync('view_order');
              final hasSalesReturnPermission = roleProvider
                  .currentUserHasPermissionSync('page_CreateSalesReturn');

              // Only show the expandable menu if user has at least one permission
              if (!hasSalesPermission &&
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
                  listTitle1: "Sales",
                  listTitle2: "Confirmed Orders",
                  listTitle3: "Sales Return",
                  // Permission-based visibility
                  showTitle1: hasSalesPermission,
                  showTitle2: hasConfirmedOrdersPermission,
                  showTitle3: hasSalesReturnPermission,
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
                      sideBarController.index.value == 54,
                ),
              );
            },
          ),
          // 6. CATEGORY (Index: 12)
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              final hasPermission =
                  roleProvider.currentUserHasPermissionSync('view_category');

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
                  roleProvider.currentUserHasPermissionSync('view_product');
              final hasStockPermission = roleProvider
                  .currentUserHasPermissionSync('page_StockManagement');

              // Only show the expandable menu if user has at least one permission
              if (!hasProductPermission && !hasStockPermission) {
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
                    listTitle1: "Product",
                    listTitle2: "Stock",
                    // Permission-based visibility
                    showTitle1: hasProductPermission,
                    showTitle2: hasStockPermission,
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
                        sideBarController.index.value == 35),
              );
            },
          ),
          // 8. REPORTS (Index: 58) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasSalesExecutiveReportsPermission = roleProvider
                  .currentUserHasPermissionSync('page_SalesExecutiveReport');
              final hasCustomerTransactionsPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'page_CustomerTransactionReport');
              final hasSupplierTransactionsPermission =
                  roleProvider.currentUserHasPermissionSync(
                      'page_SupplierTransactionsReport');

              // Only show the expandable menu if user has at least one permission
              if (!hasSalesExecutiveReportsPermission &&
                  !hasCustomerTransactionsPermission &&
                  !hasSupplierTransactionsPermission) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => DrawerListTileExpandableColumn(
                    onTapTitle1: () {
                      sideBarController.index.value = 58;
                    },
                    onTapTitle2: () {
                      sideBarController.index.value = 65;
                    },
                    onTapTitle3: () {
                      sideBarController.index.value = 67;
                    },
                    onTapTitle4: () {
                      sideBarController.index.value = 77;
                    },
                    listTitle1: "Sales Executive Reports",
                    listTitle2: "Customer Transactions Reports",
                    listTitle3: "Supplier Transactions Reports",
                    listTitle4: "Non-Stock Report",
                    // Permission-based visibility
                    showTitle1: hasSalesExecutiveReportsPermission,
                    showTitle2: hasCustomerTransactionsPermission,
                    showTitle3: hasSupplierTransactionsPermission,
                    showTitle4:
                        true, // Show for now, add specific permission if needed
                    icon: fa.FontAwesomeIcons.chartPie,
                    title: 'Reports',
                    onTap: () {
                      sideBarController.index.value = 58;
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
                        sideBarController.index.value == 77),
              );
            },
          ),

          // 9. TRANSACTIONS (Index: 21) [EXPANDABLE]
          Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              // Check permissions for each sub-item
              final hasInvoicePermission =
                  roleProvider.currentUserHasPermissionSync('page_Invoices');
              final hasReceiptsPermission =
                  roleProvider.currentUserHasPermissionSync('page_Receipts');
              final hasCustomerVouchersPermission =
                  roleProvider.currentUserHasPermissionSync('page_Vouchers');
              final hasSupplierVouchersPermission = roleProvider
                  .currentUserHasPermissionSync('view_company::account');

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
              // Check permissions for each sub-item
              final hasCustomerTransactionsPermission = roleProvider
                  .currentUserHasPermissionSync('page_CustomerTransactions');
              final hasSupplierTransactionsPermission = roleProvider
                  .currentUserHasPermissionSync('page_SupplierTransactions');

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
              final hasPermission =
                  roleProvider.currentUserHasPermissionSync('view_customer');

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
              final hasSuppliersPermission =
                  roleProvider.currentUserHasPermissionSync('view_supplier');
              final hasSupplierTransactionsPermission = roleProvider
                  .currentUserHasPermissionSync('page_SupplierTransactions');
              final hasSupplierVouchersPermission = roleProvider
                  .currentUserHasPermissionSync('view_company::account');

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
              final hasPermission =
                  roleProvider.currentUserHasPermissionSync('view_setting');

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
              final hasPermission =
                  roleProvider.currentUserHasPermissionSync('view_setting');

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
          DrawerListTile(
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
                  // Clear all local data for multi-tenant isolation
                  final localProductProvider =
                      Provider.of<LocalProductProvider>(context, listen: false);
                  final categoryProvider =
                      Provider.of<CategoryProvider>(context, listen: false);
                  await localProductProvider.clearAllLocalData();
                  await categoryProvider.clearAllCategories();

                  authModel.logout();
                  SharedPreferenceProvider().removeTokenAndCustomerId();

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
                      final hasPermission = roleProvider
                          .currentUserHasPermissionSync('view_store');
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
