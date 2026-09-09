import 'package:get/get.dart';
import 'package:pos_machine/components/order_submission_status.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_quotation_page_responsive.dart';
import 'package:pos_machine/features/billing/presentation/pages/billing_page_responsive.dart';
import 'package:pos_machine/screens/billing/kitchen_master.dart';
import 'package:pos_machine/screens/billing/restaurant/restaurant_page.dart';
import 'package:pos_machine/screens/category/add_category.dart';
import 'package:pos_machine/screens/category/add_category_properties.dart';
import 'package:pos_machine/screens/category/add_category_screen.dart';
import 'package:pos_machine/screens/category/edit_category_screen.dart';
import 'package:pos_machine/screens/category/widgets/view_category.dart';
import 'package:pos_machine/screens/customer_profile/open_customer_profile.dart';
import 'package:pos_machine/screens/customers/add_customers.dart';
import 'package:pos_machine/screens/cart/cart_list.dart';
import 'package:pos_machine/screens/customers/customers.dart';
import 'package:pos_machine/screens/sales/widgets/quotation_details.dart';
import 'package:pos_machine/screens/dashboard/dashboard.dart';

import 'package:pos_machine/screens/edit_order/edit_order.dart';
import 'package:pos_machine/screens/homenew/home_new.dart';

import 'package:pos_machine/screens/loyality_card/loyality.dart';
import 'package:pos_machine/screens/notifications/notifications.dart';
import 'package:pos_machine/screens/print/printer_settings.dart';
import 'package:pos_machine/screens/product/add_product.dart';
import 'package:pos_machine/screens/product/product_barcode.dart';
import 'package:pos_machine/screens/product/tabbar_for_edit_product.dart';
import 'package:pos_machine/screens/product/widgets/add_product_stock.dart';
import 'package:pos_machine/screens/product/widgets/view_product.dart';
import 'package:pos_machine/screens/purchase/purchase.dart';
import 'package:pos_machine/screens/product/tabbar_for_add_new_product.dart';
import 'package:pos_machine/screens/product/stock.dart';
import 'package:pos_machine/screens/purchase/purchase_orders.dart';
import 'package:pos_machine/screens/purchase/widgets/create_purchase_order.dart';
import 'package:pos_machine/screens/purchase/purchase_voucher.dart';
import 'package:pos_machine/screens/purchase/widgets/add_purchase.dart';
import 'package:pos_machine/screens/profile/open_profile.dart';
import 'package:pos_machine/screens/purchase/widgets/view_purchase.dart';
import 'package:pos_machine/screens/purchase_return/purchase_return_list.dart';
import 'package:pos_machine/screens/purchase_return/create_purchase_return.dart';
import 'package:pos_machine/screens/purchase/widgets/view_voucher.dart';
import 'package:pos_machine/screens/reports/account_book/account_book.dart';
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_tranctions_reports .dart';
// Adding import for the new simple transaction details screen
import 'package:pos_machine/screens/reports/customer_transactions_reports/customer_transaction_details_screen.dart';
// Adding imports for supplier transaction report screens
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_report.dart';
import 'package:pos_machine/screens/reports/supplier_transaction_report/supplier_transaction_details_screen.dart';
import 'package:pos_machine/screens/reports/product_sales_report/product_sales_report.dart';
import 'package:pos_machine/screens/reports/sales_report/sales_report.dart';
import 'package:pos_machine/screens/reports/supplier_sales_report/supplier_sales_report.dart';
import 'package:pos_machine/screens/reports/sales_executive_report/sales_executive_report.dart';
import 'package:pos_machine/screens/reports/sales_executive_report/admin_sales_executive_report.dart';
import 'package:pos_machine/screens/reports/non_stock_report/non_stock_report.dart';
import 'package:pos_machine/screens/reports/stock_report/stock_report.dart';
import 'package:pos_machine/screens/reports/consumed_stocks_report/consumed_stocks_report.dart';
import 'package:pos_machine/screens/settings/location_managment/location_managment.dart';
import 'package:pos_machine/screens/supplier_profile/open_supplier_profile.dart';
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
import 'package:pos_machine/screens/transactions/customer_voucher_list.dart';
import 'package:pos_machine/screens/transactions/widgets/create_customer_voucher.dart';
import 'package:pos_machine/screens/transactions/supplier_voucher_list.dart';
import 'package:pos_machine/screens/transactions/widgets/create_supplier_voucher.dart';
import 'package:pos_machine/screens/transactions/expense_list_screen.dart';
import 'package:pos_machine/screens/transactions/create_expense_screen.dart';
import 'package:pos_machine/screens/transactions/view_expense_screen.dart';

import '../screens/product/widgets/stock_details.dart';
import '../screens/sales/widgets/sales_order_details.dart';
import '../widgets/category_list.dart';
import 'package:pos_machine/screens/suppliers/supplier_list.dart';
import 'package:pos_machine/screens/suppliers/supplier_details.dart';
import 'package:pos_machine/screens/sales/confirmed_orders.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_detail.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_list.dart';
import 'package:pos_machine/screens/sales/admin_daily_sales_close_list.dart';
import 'package:pos_machine/screens/sales/quotations_list.dart';

class SideBarController extends GetxController {
  static const int ordersToReviewIndex = 101;
  static const int billingScreenIndex = 0;

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
    CustomersScreen(), //5
    LoyalityCardScreen(), //6
    NotificationScreen(), //7
    SupportScreen(), //8
    AddCustomersScreen(), //9
    OpenProfileScreen(), //10
    SalesOrderDetailsScreen(), //11
    AddCategoryScreen(), //12
    AddCategoryPropertiesScreen(), //13
    AddProductScreen(), //14
    AddStockScreen(), //15
    AddCategoryPageScreen(), //16
    TabBarForAddNewProduct(), //17
    AddProductStockScreen(), //18
    PurchaseScreen(), //19
    AddPurchaseScreen(), //20
    InvoiceListScreen(), //21
    VoucherListScreen(), //22
    CustomerTransactionListScreen(), //23
    CreateNewInvoiceScreen(), //24
    CreateNewVoucherScreen(), //25
    PurchaseVoucherScreen(), //26
    ViewCategoryWidget(), //27
    ViewProductWidget(), //28
    ViewVoucherWidget(), //29
    ViewTransactionDetailsWidget(), //30
    ViewInvoiceDetailsWidget(), //31
    ViewVoucherDetailsWidget(), //32
    StockDetailsWidget(), //33
    EditCategoryPageScreen(), //34
    TabBarForEditProduct(), //35
    ViewPurchaseWidget(), //36
    AddVoucherDetailsWidget(), //37
    OpenCustomerProfileScreen(), //38
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
    SupplierListScreen(), // 52 Suppliers List
    PrinterSettings(), // 53 Printer Settings
    ConfirmedOrdersScreen(), // 54 Confirmed Orders
    RestaurantPage(
      allowCounterBillingFromAttender: false,
      defaultCounterBillingMode: false,
    ), // 55 Restaurant Page (Attender)
    KitchenMaster(), // 56 Kitchen Master
    SupplierDetailsScreen(), // 57 Supplier Details
    SalesExecutiveReportScreen(), // 58 Sales Executive Report
    CompanyAccountsScreen(), // 59 Company Accounts
    AddCompanyAccountScreen(), // 60 Add Company Account
    AccountDetailsScreen(), // 61 Account Details Screen
    SettingsScreen(), // 62 Settings Home
    WhatsappSettingsScreen(), // 63 WhatsApp Settings
    CompanyInfoScreen(), // 64 Company Info
    CustomerTransactionsReportScreen(), // 65 Customer Transactions Report
    SimpleTransactionDetailsScreen(), // 66 Simple Transaction Details Screen
    SupplierTransactionReportScreen(), // 67 Supplier Transaction Report
    SupplierTransactionDetailsScreen(), // 68 Supplier Transaction Details Screen
    OpenSupplierProfileScreen(), // 69 Open Supplier Profile Screen
    CustomerVoucherListScreen(), // 70 Customer Voucher List
    CreateCustomerVoucherScreen(), // 71 Create Customer Voucher
    SupplierVoucherListScreen(), // 72 Supplier Voucher List
    CreateSupplierVoucherScreen(), // 73 Create Supplier Voucher
    TransactionScreen(), // 74 Supplier Transactions (alias for Party Accounts)
    SupplierVoucherListScreen(), // 75 Supplier Voucher List (alias for Transactions)
    CreateSupplierVoucherScreen(), // 76 Create Supplier Voucher (alias for Transactions)
    NonStockReportScreen(), // 77 Non-Stock Report
    DailySalesCloseListScreen(), // 78 Daily Sales Close List
    DailySalesCloseDetailScreen(), // 79 Daily Sales Close Detail
    ConsumedStocksReportScreen(), // 80 Consumed Stocks Report
    AddPurchaseOrderScreen(), // 81 Purchase Order Screen
    CreatePurchaseOrderScreen(), // 82 Create Purchase Order Screen
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
    ExpenseListScreen(), // 93
    CreateExpenseScreen(), // 94
    ViewExpenseScreen(), // 95
    OfflineDataPage(), // 96 Offline Data
    RestaurantPage(
      allowCounterBillingFromAttender: true,
      defaultCounterBillingMode: true,
      storeMode: true,
    ), // 97 Store Billing Page (restaurant UI, summary-only order panel)
    StockReportScreen(), // 98 Stock Report Screen
    PurchaseReturnListScreen(), // 99 Purchase Return List
    CreatePurchaseReturnScreen(), // 100 Create Purchase Return
    OrdersToReviewPage(), // 101
  ];
}
