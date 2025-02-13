class APPUrl {
  // static const String baseURL = "https://epos.enke.ae";
  // static const String baseURL = "https://epos.mevcakes.com";
  static const String baseURL = "https://epos.enke.ae";
  // static const String baseURL = "https://three-places-cover.loca.lt";

  // static const String categoryListUrl = '$baseURL/api/v1/list-category';
  static const String categoryListUrl =
      '$baseURL/api/v1/category/list-category';
  static const String viewCategoryListUrl = '$baseURL/api/v1/category-details';
  static const String addCategoryUrl = '$baseURL/api/v1/category/add-category';
  static const String editCategoryUrl =
      '$baseURL/api/v1/category/edit-category';
  static const String fetchCategoryProps =
      '$baseURL/api/v1/product/fetch-prop-values';

  // static const String getProcductUrl = '$baseURL/api/v1/list-products';
  static const String getProductUrl =
      '$baseURL/api/v1/product/executive/list-products';
  static const String addToCartUrl = '$baseURL/api/v1/cart/add-to-cart';
  static const String removeFromCartUrl =
      '$baseURL/api/v1/cart/remove-from-cart';
  static const String listCartUrl =
      '$baseURL/api/v1/cart/executive/list-cart-items';
  static const String updateCartItemPriceUrl =
      '$baseURL/api/v1/cart/change-cart-item-price';
  static const String addToOrderUrl = '$baseURL/api/v1/order/add-to-order';
  static const String addToOrderConfirmUrl =
      '$baseURL/api/v1/order/confirm-order';
  // static const String getListOrder = '$baseURL/api/v1/order/list-orders';
  static const String getListOrder =
      '$baseURL/api/v1/order/executive/list-orders';
  // static const String getListOrder = '$baseURL/api/v1/order-searchbar';
  static const String searchListOrder = '$baseURL/api/v1/order-searchbar';
  static const String getListOrderDetails =
      '$baseURL/api/v1/order/executive/order-details';
  static const String salesReturn = '$baseURL/api/v1/order/sales-return';
  static const String listSalesReturn =
      '$baseURL/api/v1/order/list-return-orders';

  static const String loginUrl = '$baseURL/api/v1/user/signin';
  static const String forgotPasswordUrl = '$baseURL/api/v1/user/forgot';
  static const String resetPasswordUrl = '$baseURL/api/v1/user/reset';

  static const String logoutUrl = '$baseURL/api/v1/user/signout';
  static const String dashBoardUrl = '$baseURL/api/v1/dashboard';
  static const String dashBoardGraphUrl = '$baseURL/api/v1/dashboard/orders';
  static const String addCustomerUrl = '$baseURL/api/v1/customer/add-customer';
  // static const String customerListUrl = '$baseURL/api/v1/sales/list-customer';
  static const String customerListUrl =
      '$baseURL/api/v1/customer/customer-searchbar';
  static const String userDetailsUrl = '$baseURL/api/v1/user/get-user-details';
  static const String findCustomerByPhone =
      '$baseURL/api/v1/search-user-by-key';

  static const String addProductUrl =
      '$baseURL/api/v1/product/add-product-general-item';
  static const String addProductNameUrl =
      '$baseURL/api/v1/product/add-product-name';
  static const String addProductPropsUrl =
      '$baseURL/api/v1/product/add-product-props';
  static const String addProductImageUrl =
      '$baseURL/api/v1/product/add-product-image';

  static const String editProductUrl =
      '$baseURL/api/v1/product/edit-product-general-item';
  static const String editProductNameUrl =
      '$baseURL/api/v1/product/edit-product-name';
  static const String editProductPropsUrl =
      '$baseURL/api/v1/product/edit-product-props';
  static const String editProductImageUrl =
      '$baseURL/api/v1/product/edit-product-image';
  static const String listFilesForImageUrl = '$baseURL/api/v1/file/list-files';

  static const String getStores =
      '$baseURL/api/v1/stores/get-stores?store_name';
  static const String getSuppliers =
      '$baseURL/api/v1/suppliers/get-suppliers?supplier_name';
  // static const String listPurchases =
  //     '$baseURL/api/v1/purchases/list-purchase-order';
  static const String listPurchases =
      '$baseURL/api/v1/purchases/purchase-searchbar';
  static const String listPurchaseVoucher =
      '$baseURL/api/v1/purchases/voucher-searchbar';
  static const String addToPurchaseItem =
      '$baseURL/api/v1/purchases/add-purchase-item';
  static const String addToPurchase =
      '$baseURL/api/v1/purchases/add-to-purchase';
  static const String finishPurchaseOrder =
      '$baseURL/api/v1/purchases/add-purchase-order';
  static const String addToStock = '$baseURL/api/v1/product/add-stock';
  static const String getTaxtDetails = '$baseURL/api/v1/tax/get-category-tax';
  static const String addPurchaseStock = '$baseURL/api/v1/purchases/add-stock';
  // static const String listStock = '$baseURL/api/v1/product/list-stocks';
  static const String listStock = '$baseURL/api/v1/stock-searchbar';
  static const String detailsOfStock = '$baseURL/api/v1/product/stock-details';
  static const String listPurchaseItems =
      '$baseURL/api/v1/purchases/list-purchase-items';

  static const String removePurchaseitem =
      '$baseURL/api/v1/purchases/remove-purchase-item';
  static const String addInvoiceorVoucher =
      '$baseURL/api/v1/transaction/add-transaction';

  static const String listUser = '$baseURL/api/v1/user/get-users';
  static const String listInvoiceAccountType =
      '$baseURL/api/v1/transaction/get-account-types?type=invoice';
  static const String listVoucherAccountType =
      '$baseURL/api/v1/transaction/get-account-types?type=voucher';
  static const String listTransactionType =
      '$baseURL/api/v1/transaction/get-payment-methods';
  static const String listUnits = '$baseURL/api/v1/product/list-units';
  static const String detailsOfTransaction =
      '$baseURL/api/v1/transaction/transaction-details';
  static const String listAllTransaction =
      '$baseURL/api/v1/transaction/list-transactions';
  static const String listAllInvoices = '$baseURL/api/v1/invoice/list-invoices';
  static const String listAllReceipts = '$baseURL/api/v1/receipt/list-receipts';
  static const String detailsOfReceipt =
      '$baseURL/api/v1/receipt/receipt-details';
  static const String detailsOfInvoice =
      '$baseURL/api/v1/invoice/invoice-details';
  static const String listStates = '$baseURL/api/v1/location/get-states';
  static const String listDistricts = '$baseURL/api/v1/location/get-district';

  static const String customerAccountBook =
      '$baseURL/api/v1/reports/customer-account-book';
  static const String productSalesReport =
      '$baseURL/api/v1/reports/product-sales-report';
  static const String salesReport = '$baseURL/api/v1/reports/sales-report';
  static const String supplierSalesReport =
      '$baseURL/api/v1/reports/supplier-sales-report';
  static const String applyCoupon = '$baseURL/api/v1/discount/apply-coupon';
  static const String listFaqs = '$baseURL/api/v1/faq/faqs/company/1';
  static const String getGeneralSettings = '$baseURL/api/v1/general';
  static const String getAppSettings = '$baseURL/api/v1/website-settings';
}
