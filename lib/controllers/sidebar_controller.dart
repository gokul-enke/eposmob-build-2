import 'package:get/get.dart';
import 'package:pos_machine/features/weigh_machine/presentation/weigh_machine_export_page.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_quotation_page_responsive.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page_responsive.dart';
import 'package:pos_machine/screens/billing/kitchen_master.dart';
import 'package:pos_machine/screens/billing/restaurant/restaurant_page.dart';
import 'package:pos_machine/features/categories/presentation/pages/category_list_page.dart';
import 'package:pos_machine/screens/category/add_category_properties.dart';
import 'package:pos_machine/screens/category/add_category_screen.dart';
import 'package:pos_machine/screens/category/edit_category_screen.dart';
import 'package:pos_machine/screens/category/widgets/view_category.dart';
import 'package:pos_machine/features/customers/presentation/pages/customer_profile_page.dart';
import 'package:pos_machine/features/customers/presentation/pages/add_customer_page.dart';
import 'package:pos_machine/screens/cart/cart_list.dart';
import 'package:pos_machine/features/customers/presentation/pages/customers_list_page.dart';
import 'package:pos_machine/screens/sales/widgets/quotation_details.dart';
import 'package:pos_machine/screens/dashboard/dashboard.dart';

import 'package:pos_machine/screens/edit_order/edit_order.dart';
import 'package:pos_machine/screens/homenew/home_new.dart';

import 'package:pos_machine/screens/loyality_card/loyality.dart';
import 'package:pos_machine/screens/notifications/notifications.dart';
import 'package:pos_machine/screens/print/printer_settings.dart';
import 'package:pos_machine/features/products/presentation/pages/product_list_page.dart';
import 'package:pos_machine/screens/product/product_barcode.dart';
import 'package:pos_machine/screens/product/tabbar_for_edit_product.dart';
import 'package:pos_machine/screens/product/widgets/add_product_stock.dart';
import 'package:pos_machine/screens/product/widgets/view_product.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_page.dart';
import 'package:pos_machine/screens/product/tabbar_for_add_new_product.dart';
import 'package:pos_machine/features/stock/presentation/pages/stock_list_page.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_order_list_page.dart';
import 'package:pos_machine/features/purchases/presentation/pages/create_purchase_order_page.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_voucher_page.dart';
import 'package:pos_machine/features/purchases/presentation/pages/add_purchase_page.dart';
import 'package:pos_machine/screens/profile/open_profile.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_details_page.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/purchase_return_list_page.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/create_purchase_return_page.dart';
import 'package:pos_machine/features/purchases/presentation/pages/purchase_voucher_details_page.dart';
import 'package:pos_machine/screens/reports/account_book/account_book.dart';
import 'package:pos_machine/features/reports/presentation/pages/customer_transactions_report_page.dart';
// Adding import for the new simple transaction details screen
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_transaction_details_screen.dart';
// Adding imports for supplier transaction report screens
import 'package:pos_machine/features/reports/presentation/pages/supplier_transactions_report_page.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_details_screen.dart';
import 'package:pos_machine/screens/reports/product_sales_report/product_sales_report.dart';
import 'package:pos_machine/screens/reports/sales_report/sales_report.dart';
import 'package:pos_machine/screens/reports/supplier_sales_report/supplier_sales_report.dart';
import 'package:pos_machine/features/reports/presentation/pages/my_sales_report_page.dart';
import 'package:pos_machine/screens/reports/sales_executive_report/admin_sales_executive_report.dart';
import 'package:pos_machine/screens/reports/non_stock_report/non_stock_report.dart';
import 'package:pos_machine/screens/reports/stock_report/stock_report.dart';
import 'package:pos_machine/screens/reports/consumed_stocks_report/consumed_stocks_report.dart';
import 'package:pos_machine/screens/settings/location_managment/location_managment.dart';
import 'package:pos_machine/features/suppliers/presentation/pages/supplier_profile_page.dart';
import 'package:pos_machine/screens/transactions/company_accounts/company_accounts.dart';
import 'package:pos_machine/screens/transactions/company_accounts/add_company_account.dart';
import 'package:pos_machine/screens/transactions/company_accounts/account_details_screen.dart';
import 'package:pos_machine/screens/sales/sales.dart';
import 'package:pos_machine/screens/sales_return/sales_return.dart';
import 'package:pos_machine/screens/sales_return/sales_return_list.dart';
import 'package:pos_machine/screens/settings/settings.dart';
import 'package:pos_machine/screens/settings/whatsapp_settings.dart';
import 'package:pos_machine/screens/settings/company_info.dart';
import 'package:pos_machine/screens/settings/widgets/offline_data_page.dart';
import 'package:pos_machine/screens/support/support.dart';
import 'package:pos_machine/screens/transactions/invoice_list.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list.dart';
import 'package:pos_machine/screens/transactions/receipt_list.dart';
import 'package:pos_machine/screens/transactions/receipt_voucher.dart';
import 'package:pos_machine/screens/transactions/transaction_list.dart';
import 'package:pos_machine/screens/transactions/widgets/add_voucher_details.dart';
import 'package:pos_machine/screens/transactions/widgets/create_new_invoice.dart';
import 'package:pos_machine/screens/transactions/widgets/create_new_voucher.dart';
import 'package:pos_machine/screens/transactions/widgets/view_invoice.dart';
import 'package:pos_machine/screens/transactions/widgets/view_receipt_details.dart';
import 'package:pos_machine/screens/transactions/widgets/view_transaction_details.dart';
import 'package:pos_machine/screens/transactions/widgets/view_voucher_details.dart';
import 'package:pos_machine/screens/transactions/supplier_transactions/supplier_transactions.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/customer_voucher_list_page.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/create_customer_voucher_page.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/supplier_voucher_list_page.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/create_supplier_voucher_page.dart';
import 'package:pos_machine/features/expenses/presentation/pages/expense_list_page.dart';
import 'package:pos_machine/features/expenses/presentation/pages/create_expense_page.dart';
import 'package:pos_machine/features/expenses/presentation/pages/view_expense_page.dart';

import '../screens/product/widgets/stock_details.dart';
import '../screens/sales/widgets/sales_order_details.dart';
import '../widgets/category_list.dart';
import 'package:pos_machine/features/suppliers/presentation/pages/suppliers_list_page.dart';
import 'package:pos_machine/screens/sales/confirmed_orders.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_detail.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_list.dart';
import 'package:pos_machine/screens/sales/admin_daily_sales_close_list.dart';
import 'package:pos_machine/screens/sales/quotations_list.dart';

class SideBarController extends GetxController {
  static const int stockListScreenIndex = 15;
  static const int addStockScreenIndex = 18;
  static const int weighMachineExportIndex = 101;
  static const int billingScreenIndex = 0;

  /// Position of [InvoiceListScreen] in [screens]. Named because more than one
  /// caller navigates to it, and the list is positional — inserting a screen
  /// above it would otherwise silently point those callers elsewhere.
  static const int invoiceListScreenIndex = 21;

  /// Customer screens in [screens]. Navigate through [CustomerNavigation]
  /// rather than setting these indices directly.
  static const int customersScreenIndex = 5;
  static const int addCustomerScreenIndex = 9;
  static const int userProfileScreenIndex = 10;
  static const int customerProfileScreenIndex = 38;

  /// Supplier screens in [screens]. Navigate through [SupplierNavigation].
  static const int suppliersScreenIndex = 52;

  /// Legacy "supplier details" slot; shows the supplier profile.
  static const int supplierDetailsScreenIndex = 57;
  static const int supplierProfileScreenIndex = 69;

  /// Report screens in [screens]. Navigate through [ReportNavigation].
  static const int mySalesReportScreenIndex = 58;
  static const int customerTransactionsReportScreenIndex = 65;
  static const int customerTransactionDetailsScreenIndex = 66;
  static const int supplierTransactionsReportScreenIndex = 67;
  static const int supplierTransactionDetailsScreenIndex = 68;

  /// Expense screens in [screens]. Navigate through [ExpenseNavigation].
  static const int expenseListScreenIndex = 93;
  static const int createExpenseScreenIndex = 94;
  static const int viewExpenseScreenIndex = 95;

  /// Customer and supplier voucher routes, including Transactions aliases.
  static const int customerVoucherListScreenIndex = 70;
  static const int createCustomerVoucherScreenIndex = 71;
  static const int supplierVoucherListScreenIndex = 72;
  static const int createSupplierVoucherScreenIndex = 73;
  static const int transactionSupplierVoucherListScreenIndex = 75;
  static const int transactionCreateSupplierVoucherScreenIndex = 76;

  /// Purchase return screens in [screens]. Navigate through [PurchaseReturnNavigation].
  static const int purchaseReturnListScreenIndex = 99;
  static const int createPurchaseReturnScreenIndex = 100;

  /// Purchase order screens in [screens]. Navigate through [PurchaseNavigation].
  static const int legacyPurchaseListScreenIndex = 19;
  static const int legacyCreatePurchaseScreenIndex = 20;
  static const int legacyPurchaseVoucherListScreenIndex = 26;
  static const int legacyPurchaseVoucherDetailsScreenIndex = 29;
  static const int legacyPurchaseVoucherEntryScreenIndex = 37;
  static const int purchaseOrderListScreenIndex = 81;
  static const int createPurchaseOrderScreenIndex = 82;
  static const int purchaseDetailsScreenIndex = 36;

  /// Catalog listing only. Inner product screen slots remain unchanged.
  static const int productListScreenIndex = 14;

  /// Category listing and the existing Add/Edit destinations.
  static const int categoryListScreenIndex = 12;
  static const int addCategoryScreenIndex = 16;
  static const int editCategoryScreenIndex = 34;

  RxInt index =
      0.obs; // Default to HomeNew, will be set based on user role during login
  RxBool isExpanded = false.obs;

  /// When set and [index] is [billingScreenIndex], mobile MainScreen shows this
  /// title instead of the brand logo. Cleared on Market tab or when leaving billing.
  final RxnString billingMobileAppBarTitle = RxnString(null);

  // Removed transactionCustomerName variable as it's now handled by TransactionProvider

  void setBillingMobileAppBarTitle(String? title) {
    billingMobileAppBarTitle.value = title;
  }

  void toggleExpansion() {
    isExpanded.value = !isExpanded.value;
  }

  var screens = const [
    BillingPageResponsive(), //0
    DashboardScreen(), //1 - Using the role-based dashboard
    SalesScreen(), //2
    CartScreen(), //3
    TransactionScreen(), //4
    CustomersListPage(), //5
    LoyalityCardScreen(), //6
    NotificationScreen(), //7
    SupportScreen(), //8
    AddCustomerPage(), //9
    OpenProfileScreen(), //10
    SalesOrderDetailsScreen(), //11
    CategoryListPage(), // categoryListScreenIndex
    AddCategoryPropertiesScreen(), //13
    ProductListPage(), // 14 productListScreenIndex
    StockListPage(), // stockListScreenIndex (15)
    AddCategoryPageScreen(), //16
    TabBarForAddNewProduct(), //17
    AddProductStockScreen(), //18
    LegacyPurchaseListPage(), // legacyPurchaseListScreenIndex
    LegacyAddPurchasePage(), // legacyCreatePurchaseScreenIndex
    InvoiceListScreen(), // invoiceListScreenIndex
    VoucherListScreen(), //22
    CustomerTransactionListScreen(), //23
    CreateNewInvoiceScreen(), //24
    CreateNewVoucherScreen(), //25
    LegacyPurchaseVoucherListPage(), // legacyPurchaseVoucherListScreenIndex
    ViewCategoryWidget(), //27
    ViewProductWidget(), //28
    LegacyPurchaseVoucherDetailsPage(), // legacyPurchaseVoucherDetailsScreenIndex
    ViewTransactionDetailsWidget(), //30
    ViewInvoiceDetailsWidget(), //31
    ViewVoucherDetailsWidget(), //32
    StockDetailsWidget(), //33
    EditCategoryPageScreen(), //34
    TabBarForEditProduct(), //35
    PurchaseDetailsPage(), // purchaseDetailsScreenIndex
    AddVoucherDetailsWidget(), //37
    CustomerProfilePage(), //38
    AccountBookScreen(), //39
    ProductSalesReportScreen(), //40
    SalesReportScreen(), //41
    SupplierSalesReportScreen(), //42
    LocationManagementScreen(), //43
    LocationManagementScreen(), //44
    CategoryList(), //45 Home Old
    HomeNew(), //46 Legacy Home alias
    ReceiptListScreen(), //47 Receipt List
    ViewReceiptDetailsWidget(), //48 Receipt Details
    SalesReturnScreen(), //49 Sales Return
    SalesReturnPage(), //50 Sales Return List
    EditOrder(), // 51 Edit Order
    SuppliersListPage(), // 52 Suppliers List
    PrinterSettings(), // 53 Printer Settings
    ConfirmedOrdersScreen(), // 54 Confirmed Orders
    RestaurantPage(
      allowCounterBillingFromAttender: false,
      defaultCounterBillingMode: false,
    ), // 55 Restaurant Page (Attender)
    KitchenMaster(), // 56 Kitchen Master
    SupplierProfilePage(), // 57 Supplier Details (legacy slot, same page)
    MySalesReportPage(), // 58 mySalesReportScreenIndex
    CompanyAccountsScreen(), // 59 Company Accounts
    AddCompanyAccountScreen(), // 60 Add Company Account
    AccountDetailsScreen(), // 61 Account Details Screen
    SettingsScreen(), // 62 Settings Home
    WhatsappSettingsScreen(), // 63 WhatsApp Settings
    CompanyInfoScreen(), // 64 Company Info
    CustomerTransactionsReportPage(), // 65 customerTransactionsReportScreenIndex
    SimpleTransactionDetailsScreen(), // 66 Simple Transaction Details Screen
    SupplierTransactionsReportPage(), // 67 supplierTransactionsReportScreenIndex
    SupplierTransactionDetailsScreen(), // 68 Supplier Transaction Details Screen
    SupplierProfilePage(), // 69 Supplier Profile
    CustomerVoucherListPage(), // 70 Customer Voucher List
    CreateCustomerVoucherPage(), // 71 Create Customer Voucher
    SupplierVoucherListPage(), // 72 Supplier Voucher List
    CreateSupplierVoucherPage(), // 73 Create Supplier Voucher
    TransactionScreen(), // 74 Supplier Transactions (alias for Party Accounts)
    SupplierVoucherListPage(), // 75 Supplier Voucher List (alias for Transactions)
    CreateSupplierVoucherPage(), // 76 Create Supplier Voucher (alias for Transactions)
    NonStockReportScreen(), // 77 Non-Stock Report
    DailySalesCloseListScreen(), // 78 Daily Sales Close List
    DailySalesCloseDetailScreen(), // 79 Daily Sales Close Detail
    ConsumedStocksReportScreen(), // 80 Consumed Stocks Report
    PurchaseOrderListPage(), // purchaseOrderListScreenIndex
    CreatePurchaseOrderPage(), // createPurchaseOrderScreenIndex
    ProductBarcodeScreen(), // 83 Product Barcode Screen
    AdminDailySalesCloseListScreen(), // 84 Admin Daily Sales Close List
    AdminSalesExecutiveReportScreen(), // 85 Admin Sales Executive Report
    BillingQuotationPageResponsive(), // 86 Quotations
    QuotationsListScreen(), // 87 Quotation List
    QuotationDetailsScreen(
        quotationId: null), // 88 Quotation Details (ID from Provider)
    RestaurantPage(
      allowCounterBillingFromAttender: true,
      defaultCounterBillingMode: true,
    ), // 89 Restaurant Billing Page
    BillingPageResponsive(), // 90 Supermarket Billing Page
    ProformaInvoiceListScreen(), // 91 Proforma Invoice List
    SalesScreen(isOnlineSales: true), // 92 Online Sales
    ExpenseListPage(), // expenseListScreenIndex (93)
    CreateExpensePage(), // createExpenseScreenIndex (94)
    ViewExpensePage(), // viewExpenseScreenIndex (95)
    OfflineDataPage(), // 96 Offline Data
    RestaurantPage(
      allowCounterBillingFromAttender: true,
      defaultCounterBillingMode: true,
      storeMode: true,
    ), // 97 Store Billing Page (restaurant UI, summary-only order panel)
    StockReportScreen(), // 98 Stock Report Screen
    PurchaseReturnListPage(), // 99 purchaseReturnListScreenIndex
    CreatePurchaseReturnPage(), // 100 createPurchaseReturnScreenIndex
    WeighMachineExportPage(), // 101 weighMachineExportIndex
  ];
}
