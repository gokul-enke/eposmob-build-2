class APPUrl {
  // static String baseURL = "https://epos.enke.ae";
  // static String baseURL = "https://hypersouq.enke.in";
  // static String baseURL = "https://epos.mevcakes.com";
  // static String baseURL = "https://kmstoys.enke.in";
  //  static String baseURL = "https://stagingepos.enke.ae";
  // static String baseURL = "https://tenant.hypersouq.in";
  static String baseURL = "https://eposdemo.hypersouq.in";
  // static String baseURL = "https://epos.hypersouq.in";
  //  static String baseURL = "https://epos.yougoit.in";
  // static String baseURL = "https://open-poems-sneeze.loca.lt";
  // static String baseURL = "http://localhost:8000";
  // static String baseURL = "https://icy-goats-brake.loca.lt";
  // static void setBaseUrl(String url) {
  //   baseURL = url;
  // }

  static String verifyApiKey = '$baseURL/api/v1/verify-api-key';
  static String categoryListUrl = '$baseURL/api/v1/category/list-category';
  static String viewCategoryListUrl = '$baseURL/api/v1/category-details';
  static String addCategoryUrl = '$baseURL/api/v1/category/add-category';
  static String editCategoryUrl = '$baseURL/api/v1/category/edit-category';
  static String fetchCategoryProps =
      '$baseURL/api/v1/product/fetch-prop-values';

  // static String getProcductUrl = '$baseURL/api/v1/list-products';
  static String getProductUrl =
      '$baseURL/api/v1/product/executive/list-products';
  static String addToCartUrl = '$baseURL/api/v1/cart/add-to-cart';
  static String removeFromCartUrl = '$baseURL/api/v1/cart/remove-from-cart';
  static String listCartUrl = '$baseURL/api/v1/cart/executive/list-cart-items';
  static String updateCartItemPriceUrl =
      '$baseURL/api/v1/cart/change-cart-item-price';
  static String addToOrderUrl = '$baseURL/api/v1/order/add-to-order';
  static String updateOrderUrl = '$baseURL/api/v1/order/update-order';
  static String addToOrderConfirmUrl = '$baseURL/api/v1/order/confirm-order';
  // static String getListOrder = '$baseURL/api/v1/order/list-orders';
  static String getListOrder = '$baseURL/api/v1/order/executive/list-orders';
  // static String getListOrder = '$baseURL/api/v1/order-searchbar';
  static String searchListOrder = '$baseURL/api/v1/order-searchbar';
  static String getListOrderDetails =
      '$baseURL/api/v1/order/executive/order-details';
  static String salesReturn = '$baseURL/api/v1/order/sales-return';
  static String listSalesReturn = '$baseURL/api/v1/order/list-return-orders';
  static String listSalesReturnItems =
      '$baseURL/api/v1/order/list-return-order-items';
  static String completeSalesReturn =
      '$baseURL/api/v1/order/complete-return-order';

  static String listSavedOrders = '$baseURL/api/v1/order/list-saved-orders';

  static String loginUrl = '$baseURL/api/v1/user/signin';
  static String forgotPasswordUrl = '$baseURL/api/v1/user/forgot';
  static String resetPasswordUrl = '$baseURL/api/v1/user/reset';

  static String logoutUrl = '$baseURL/api/v1/user/signout';
  static String dashBoardUrl = '$baseURL/api/v1/dashboard';
  static String dashBoardGraphUrl = '$baseURL/api/v1/dashboard/orders';
  static String addCustomerUrl = '$baseURL/api/v1/customer/add-customer';
  static String updateCustomerUrl = '$baseURL/api/v1/customer/customer-edit';
  // static String customerListUrl = '$baseURL/api/v1/sales/list-customer';
  static String customerListUrl = '$baseURL/api/v1/customer/customer-searchbar';
  static String userDetailsUrl = '$baseURL/api/v1/user/get-user-details';
  static String findCustomerByPhone = '$baseURL/api/v1/search-user-by-key';

  static String createProductUrl = '$baseURL/api/v1/product/create-product';
  static String addProductUrl =
      '$baseURL/api/v1/product/add-product-general-item';
  static String addProductNameUrl = '$baseURL/api/v1/product/add-product-name';
  static String addProductPropsUrl =
      '$baseURL/api/v1/product/add-product-props';
  static String addProductImageUrl =
      '$baseURL/api/v1/product/add-product-image';

  static String editProductUrl =
      '$baseURL/api/v1/product/edit-product-general-item';
  static String editProductNameUrl =
      '$baseURL/api/v1/product/edit-product-name';
  static String editProductPropsUrl =
      '$baseURL/api/v1/product/edit-product-props';
  static String editProductImageUrl =
      '$baseURL/api/v1/product/edit-product-image';
  static String listFilesForImageUrl = '$baseURL/api/v1/file/list-files';

  static String getStores = '$baseURL/api/v1/stores/get-stores?store_name';
  static String getSuppliers = '$baseURL/api/v1/get-suppliers';
  // static String listPurchases =
  //     '$baseURL/api/v1/purchases/list-purchase-order';
  static String addSupplier = '$baseURL/api/v1/add-supplier';
  static String listPurchases = '$baseURL/api/v1/purchases/list-purchase-order';
  static String listPurchaseVoucher =
      '$baseURL/api/v1/purchases/voucher-searchbar';
  static String addToPurchaseItem =
      '$baseURL/api/v1/purchases/add-purchase-item';
  static String addToPurchase = '$baseURL/api/v1/purchases/add-to-purchase';
  static String finishPurchaseOrder =
      '$baseURL/api/v1/product/complete-purchase';
  static String addToStock = '$baseURL/api/v1/product/add-stock';
  static String addBulkStock = '$baseURL/api/v1/product/add-stock';
  static String getTaxtDetails = '$baseURL/api/v1/tax/get-category-tax';
  static String addPurchaseStock = '$baseURL/api/v1/purchases/add-stock';
  static String listStock = '$baseURL/api/v1/product/list-stocks';
  static String updateStockDetails = '$baseURL/api/v1/product/update-stock';
  // static String listStock = '$baseURL/api/v1/stock-searchbar';
  static String detailsOfStock = '$baseURL/api/v1/product/stock-details';
  static String listPurchaseItems =
      '$baseURL/api/v1/purchases/list-purchase-items';

  static String removePurchaseitem =
      '$baseURL/api/v1/purchases/remove-purchase-item';
  static String addInvoiceorVoucher =
      '$baseURL/api/v1/transaction/add-transaction';

  static String listUser = '$baseURL/api/v1/user/get-users';
  static String listInvoiceAccountType =
      '$baseURL/api/v1/transaction/get-account-types?type=invoice';
  static String listVoucherAccountType =
      '$baseURL/api/v1/transaction/get-account-types?type=voucher';
  static String listTransactionType =
      '$baseURL/api/v1/transaction/get-payment-methods';
  static String listUnits = '$baseURL/api/v1/product/list-units';
  static String detailsOfTransaction =
      '$baseURL/api/v1/transaction/transaction-details';
  static String listAllTransaction =
      '$baseURL/api/v1/transaction/list-transactions';
  static String listAllInvoices = '$baseURL/api/v1/invoice/list-invoices';
  static String listAllReceipts = '$baseURL/api/v1/receipt/list-receipts';
  static String detailsOfReceipt = '$baseURL/api/v1/receipt/receipt-details';
  static String detailsOfInvoice = '$baseURL/api/v1/invoice/invoice-details';
  static String listStates = '$baseURL/api/v1/location/get-states';
  static String listDistricts = '$baseURL/api/v1/location/get-district';
  static String listPincodes = '$baseURL/api/v1/location/list-pincodes';

  static String customerAccountBook =
      '$baseURL/api/v1/reports/customer-account-book';
  static String customerLastPurchases =
      '$baseURL/api/v1/customer/customer-last-purchases';
  static String productSalesReport =
      '$baseURL/api/v1/reports/product-sales-report';
  static String salesReport = '$baseURL/api/v1/reports/sales-report';
  static String supplierSalesReport =
      '$baseURL/api/v1/reports/supplier-sales-report';
  static String applyCoupon = '$baseURL/api/v1/discount/apply-coupon';
  static String listFaqs = '$baseURL/api/v1/faq/faqs/company/1';
  static String getGeneralSettings = '$baseURL/api/v1/general';
  static String getAppSettings = '$baseURL/api/v1/website-settings';

  static String getDeliveryMethods =
      '$baseURL/api/v1/logistics/list-delivery-methods';
  static String getPaymentGateways =
      '$baseURL/api/v1/payment-gateway/list-payment-gateways';

  static String listSalesExecutives = '$baseURL/api/v1/list-sales-executives';
  static String getRacksDataValues =
      '$baseURL/api/v1/master-data-values?code=RACKS';
  static String getMasterDataValues = '$baseURL/api/v1/master-data-values';
  static String getTableList =
      '$baseURL/api/v1/master-data-values?code=TABLE_LIST';
  static String documentConfigs = '$baseURL/api/v1/document/document-configs';
  static String supplierTransactions =
      '$baseURL/api/v1/suppliers/list-transactions';
  static String calculateTax = '$baseURL/api/v1/calculate-tax';
  static String getCartItemStatuses = '$baseURL/api/v1/cart/cart-item-statuses';
  static String updateCartItemStatus =
      '$baseURL/api/v1/cart/update-cart-item-status';
  static String generateBarcode = '$baseURL/api/v1/product/generate-barcode';

  static String getSalesExecutiveReport =
      '$baseURL/api/v1/sales-executive-report';
  static String getCompanyaccounts =
      '$baseURL/api/v1/accounts/company-accounts';



  static String companyOverview =
      '$baseURL/api/v1/dashboard/company-overview';   
  static String ordersGraph =
      '$baseURL/api/v1/dashboard/orders-graph'; 
  static String customersGraph =
      '$baseURL/api/v1/dashboard/customers-graph';      
  static String executivesOverview =
      '$baseURL/api/v1/dashboard/executives-overview';
  static String salesGraph =
      '$baseURL/api/v1/dashboard/executive-sales-graph';    

}
