class APPUrl {
  static const String defaultBaseURL = String.fromEnvironment('BASE_URL',
      defaultValue: 'https://eeezeeerp.cloudposai.com');
  static String baseURL = defaultBaseURL;
  static const String findDomainUrl =
      'https://cloudposai.com/api/v1/find-domain';

  static String normalizeBaseUrl(String url) {
    return url.trim().replaceFirst(RegExp(r'/*$'), '');
  }

  static void updateBaseURL(String url) {
    final normalizedUrl = normalizeBaseUrl(url);
    if (normalizedUrl.isEmpty) {
      return;
    }
    baseURL = normalizedUrl;
  }

  static String get verifyApiKey => '$baseURL/api/v1/verify-api-key';
  static String get categoryListUrl =>
      '$baseURL/api/v1/category/list-category?type=sellable';
  static String get getSellableCategoryListUrl =>
      '$baseURL/api/v1/category/list-category?type=sellable';
  static String get getRawCategoryListUrl =>
      '$baseURL/api/v1/category/list-category';
  static String get viewCategoryListUrl => '$baseURL/api/v1/category-details';
  static String get addCategoryUrl => '$baseURL/api/v1/category/add-category';
  static String get editCategoryUrl => '$baseURL/api/v1/category/edit-category';
  static String get fetchCategoryProps =>
      '$baseURL/api/v1/product/fetch-prop-values';

  static String get getSellableProductUrl =>
      '$baseURL/api/v1/product/executive/list-products';
  static String get getAllProductsUrl =>
      '$baseURL/api/v1/product/executive/list-products';
  static String get getRawProductUrl =>
      '$baseURL/api/v1/product/executive/list-products';
  static String get addToCartUrl => '$baseURL/api/v1/cart/add-to-cart';
  static String get listRoles => '$baseURL/api/v1/roles/list';
  static String get listLanguages => '$baseURL/api/v1/languages';
  static String get translateText => '$baseURL/api/v1/translate';
  static String get removeFromCartUrl =>
      '$baseURL/api/v1/cart/remove-from-cart';
  static String get listCartUrl =>
      '$baseURL/api/v1/cart/executive/list-cart-items';
  static String get updateCartItemPriceUrl =>
      '$baseURL/api/v1/cart/change-cart-item-price';
  static String get addToOrderUrl => '$baseURL/api/v1/order/add-to-order';
  static String get updateOrderUrl => '$baseURL/api/v1/order/update-order';
  static String get addToOrderConfirmUrl =>
      '$baseURL/api/v1/order/confirm-order';
  static String get cancelOrderUrl => '$baseURL/api/v1/order/cancel-order';
  static String get getListOrder =>
      '$baseURL/api/v1/order/executive/list-orders';
  static String get searchListOrder => '$baseURL/api/v1/order-searchbar';
  static String get getListOrderDetails =>
      '$baseURL/api/v1/order/executive/order-details';
  static String get salesReturn => '$baseURL/api/v1/order/sales-return';
  static String get listSalesReturn =>
      '$baseURL/api/v1/order/list-return-orders';
  static String get listSalesReturnItems =>
      '$baseURL/api/v1/order/list-return-order-items';
  static String get completeSalesReturn =>
      '$baseURL/api/v1/order/complete-return-order';

  static String get listSavedOrders =>
      '$baseURL/api/v1/order/list-saved-orders';

  static String get loginUrl => '$baseURL/api/v1/user/signin';
  static String get forgotPasswordUrl => '$baseURL/api/v1/user/forgot';
  static String get resetPasswordUrl => '$baseURL/api/v1/user/reset';

  static String get logoutUrl => '$baseURL/api/v1/user/signout';
  static String get dashBoardUrl => '$baseURL/api/v1/dashboard';
  static String get dashBoardGraphUrl => '$baseURL/api/v1/dashboard/orders';
  static String get salesStatsUrl => '$baseURL/api/v1/dashboard/sales-stats';
  static String get addCustomerUrl => '$baseURL/api/v1/customer/add-customer';
  static String get updateCustomerUrl =>
      '$baseURL/api/v1/customer/customer-edit';
  static String get customerListUrl =>
      '$baseURL/api/v1/customer/customer-searchbar';
  static String get userDetailsUrl => '$baseURL/api/v1/user/get-user-details';
  static String get executiveAddAddressUrl =>
      '$baseURL/api/v1/customer/executive-add-address';
  static String get executiveUpdateAddressUrl =>
      '$baseURL/api/v1/customer/executive-update-address';
  static String get findCustomerByPhone => '$baseURL/api/v1/search-user-by-key';

  static String get createProductUrl =>
      '$baseURL/api/v1/product/create-product';
  static String get addProductUrl =>
      '$baseURL/api/v1/product/add-product-general-item';
  static String get addProductNameUrl =>
      '$baseURL/api/v1/product/add-product-name';
  static String get addProductPropsUrl =>
      '$baseURL/api/v1/product/add-product-props';
  static String get addProductImageUrl =>
      '$baseURL/api/v1/product/add-product-image';

  static String get editProductUrl =>
      '$baseURL/api/v1/product/edit-product-general-item';
  static String get editProductNameUrl =>
      '$baseURL/api/v1/product/edit-product-name';
  static String get editProductPropsUrl =>
      '$baseURL/api/v1/product/edit-product-props';
  static String get editProductImageUrl =>
      '$baseURL/api/v1/product/edit-product-image';
  static String get listFilesForImageUrl => '$baseURL/api/v1/file/list-files';

  static String get getStores => '$baseURL/api/v1/stores/get-stores?store_name';
  static String get getSuppliers => '$baseURL/api/v1/get-suppliers';
  static String get addSupplier => '$baseURL/api/v1/add-supplier';
  static String get updateSupplier => '$baseURL/api/v1/update-suppliers';
  static String get listPurchases =>
      '$baseURL/api/v1/purchases/list-purchase-order';
  static String get listPurchaseVoucher =>
      '$baseURL/api/v1/purchases/voucher-searchbar';
  static String get addToPurchaseItem =>
      '$baseURL/api/v1/purchases/add-purchase-item';
  static String get addToPurchase =>
      '$baseURL/api/v1/purchases/add-to-purchase';
  static String get finishPurchaseOrder =>
      '$baseURL/api/v1/product/complete-purchase';
  static String get addToStock => '$baseURL/api/v1/product/add-stock';
  static String get addBulkStock => '$baseURL/api/v1/product/add-stock';
  static String get getTaxtDetails => '$baseURL/api/v1/tax/get-category-tax';
  static String get addPurchaseStock => '$baseURL/api/v1/purchases/add-stock';
  static String get listStock => '$baseURL/api/v1/product/list-stocks';
  static String get updateStockDetails =>
      '$baseURL/api/v1/product/update-stock';
  static String get detailsOfStock => '$baseURL/api/v1/product/stock-details';
  static String get listPurchaseItems =>
      '$baseURL/api/v1/purchases/list-purchase-items';

  static String get removePurchaseitem =>
      '$baseURL/api/v1/purchases/remove-purchase-item';
  static String get addInvoiceorVoucher =>
      '$baseURL/api/v1/transaction/add-transaction';

  static String get listUser => '$baseURL/api/v1/user/get-users';
  static String get listInvoiceAccountType =>
      '$baseURL/api/v1/transaction/get-account-types?type=invoice';
  static String get listVoucherAccountType =>
      '$baseURL/api/v1/transaction/get-account-types?type=voucher';
  static String get listTransactionType =>
      '$baseURL/api/v1/transaction/get-payment-methods';
  static String get listUnits => '$baseURL/api/v1/product/list-units';
  static String get detailsOfTransaction =>
      '$baseURL/api/v1/transaction/transaction-details';
  static String get listAllTransaction =>
      '$baseURL/api/v1/transaction/list-transactions';
  static String get listAllInvoices => '$baseURL/api/v1/invoice/list-invoices';
  static String get listAllReceipts => '$baseURL/api/v1/receipt/list-receipts';
  static String get createReceipt => '$baseURL/api/v1/receipt/create-receipt';
  static String get detailsOfReceipt =>
      '$baseURL/api/v1/receipt/receipt-details';
  static String get detailsOfInvoice =>
      '$baseURL/api/v1/invoice/invoice-details';
  static String get createInvoice => '$baseURL/api/v1/invoice/invoice-create';
  static String get listCustomerVouchers =>
      '$baseURL/api/v1/voucher/vouchers-list';
  static String get createCustomerVoucher =>
      '$baseURL/api/v1/voucher/vouchers-create';
  static String get listSupplierVouchers =>
      '$baseURL/api/v1/suppliers/list-supplier-voucher';
  static String get createSupplierVoucher =>
      '$baseURL/api/v1/suppliers/create-supplier-voucher';
  static String get listStates => '$baseURL/api/v1/location/get-states';
  static String get listDistricts => '$baseURL/api/v1/location/get-district';
  static String get listPincodes => '$baseURL/api/v1/location/list-pincodes';

  static String get customerAccountBook =>
      '$baseURL/api/v1/reports/customer-account-book';
  static String get customerLastPurchases =>
      '$baseURL/api/v1/customer/customer-last-purchases';
  static String get productSalesReport =>
      '$baseURL/api/v1/reports/product-sales-report';
  static String get salesReport => '$baseURL/api/v1/reports/sales-report';
  static String get supplierSalesReport =>
      '$baseURL/api/v1/reports/supplier-sales-report';
  static String get applyCoupon => '$baseURL/api/v1/discount/apply-coupon';
  static String get listDiscounts => '$baseURL/api/v1/discount/list-discounts';
  static String get listFaqs => '$baseURL/api/v1/faq/faqs/company/1';
  static String get getGeneralSettings => '$baseURL/api/v1/general';
  static String get getAppSettings => '$baseURL/api/v1/website-settings';
  static String get adminSettings => '$baseURL/api/v1/admin-settings';

  static String get getDeliveryMethods =>
      '$baseURL/api/v1/logistics/list-delivery-methods';
  static String get getPaymentGateways =>
      '$baseURL/api/v1/payment-gateway/list-payment-gateways';
  static String get getBanks => '$baseURL/api/v1/get-banks';

  static String get listSalesExecutives =>
      '$baseURL/api/v1/list-sales-executives';
  static String get getRacksDataValues =>
      '$baseURL/api/v1/master-data-values?code=RACKS';
  static String get getMasterDataValues => '$baseURL/api/v1/master-data-values';
  static String get getTableList =>
      '$baseURL/api/v1/master-data-values?code=TABLE_LIST';
  static String get getPaymentMethods =>
      '$baseURL/api/v1/master-data-values?code=PAYMENT_METHOD';
  static String get documentConfigs =>
      '$baseURL/api/v1/document/document-configs';
  static String get supplierTransactions =>
      '$baseURL/api/v1/suppliers/list-transactions';
  static String get supplierTransactionsV2 =>
      '$baseURL/api/v1/suppliers/supplier-transactions';
  static String get customerTransactions =>
      '$baseURL/api/v1/transaction/customer-transactions';
  static String get calculateTax => '$baseURL/api/v1/calculate-tax';
  static String get getCartItemStatuses =>
      '$baseURL/api/v1/cart/cart-item-statuses';
  static String get updateCartItemStatus =>
      '$baseURL/api/v1/cart/update-cart-item-status';
  static String get generateBarcode =>
      '$baseURL/api/v1/product/generate-barcode';
  static String get updateAllOrderItemsStatus =>
      '$baseURL/api/v1/order/update-order-items-status';

  static String get getSalesExecutiveReport =>
      '$baseURL/api/v1/sales-executive-report';
  static String get getCompanyaccounts =>
      '$baseURL/api/v1/accounts/company-accounts';

  static String get companyOverview =>
      '$baseURL/api/v1/dashboard/company-overview';
  static String get ordersGraph => '$baseURL/api/v1/dashboard/orders-graph';
  static String get customersGraph =>
      '$baseURL/api/v1/dashboard/customers-graph';
  static String get executivesOverview =>
      '$baseURL/api/v1/dashboard/executives-overview';
  static String get salesGraph =>
      '$baseURL/api/v1/dashboard/executive-sales-graph';
  static String get customerStats => '$baseURL/api/v1/dashboard/customer-stats';
  static String get productsStats => '$baseURL/api/v1/dashboard/products-stats';

  static String get zatcaPhase1InvoicePrint =>
      '$baseURL/api/v1/zatca/phase1/invoice/print';
  static String get zatcaPhase2InvoicePrint =>
      '$baseURL/api/v1/zatca/phase2/invoice/print';
  static String get zatcaPhase2InvoiceResync =>
      '$baseURL/api/v1/zatca/phase2/invoice/resync';
  static String get zatcaBulkSend => '$baseURL/api/v1/zatca/bulk-send';

  static String get zatcaPhase2VoucherPrint =>
      '$baseURL/api/v1/zatca/phase2/voucher/print';
  static String get zatcaPhase2VoucherResync =>
      '$baseURL/api/v1/zatca/phase2/voucher/resync';

  static String get suppliersOverview =>
      '$baseURL/api/v1/dashboard/suppliers-overview';
  static String get suppliersPurchaseGraph =>
      '$baseURL/api/v1/dashboard/suppliers-purchase-graph';
  static String get supplierTransactionsGraph =>
      '$baseURL/api/v1/dashboard/supplier-transactions-graph';
  static String get supplierCreditBalance =>
      '$baseURL/api/v1/dashboard/supplier-credit-balance';
  static String get nonStockReportUrl => '$baseURL/api/v1/non-stock-report';
  static String get listDailySalesClose =>
      '$baseURL/api/v1/daily-sales-close/list';
  static String get dailySalesCloseSummary =>
      '$baseURL/api/v1/daily-sales-close/summary';
  static String get dailySalesCloseCreate =>
      '$baseURL/api/v1/daily-sales-close/create';
  static String get adjustStock => '$baseURL/api/v1/stocks/adjust';
  static String get moveStock => '$baseURL/api/v1/stocks/move';
  static String get withdrawStock => '$baseURL/api/v1/stocks/withdraw';
  static String get consumedStocksReport =>
      '$baseURL/api/v1/consumed-stocks-report';
}
