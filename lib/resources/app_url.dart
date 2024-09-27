class APPUrl {
  static const String baseURL = "https://epos.enke.in";
  // static const String baseURL = "http://13.212.33.222";

  // static const String categoryListUrl = '$baseURL/api/list-category';
  static const String categoryListUrl = '$baseURL/api/category-searchbar';
  static const String viewCategoryListUrl = '$baseURL/api/category-details';
  static const String addCategoryUrl = '$baseURL/api/category/add-category';
  static const String editCategoryUrl = '$baseURL/api/category/edit-category';
  static const String fetchCategoryProps =
      '$baseURL/api/product/fetch-prop-values';

  // static const String getProcductUrl = '$baseURL/api/list-products';
  static const String getProcductUrl = '$baseURL/api/product-searchbar';
  static const String addToCartUrl = '$baseURL/api/cart/add-to-cart';
  static const String removeFromCartUrl = '$baseURL/api/cart/remove-from-cart';
  static const String listCartUrl = '$baseURL/api/cart/list-carts';
  static const String addToOrderUrl = '$baseURL/api/order/add-to-order';
  // static const String getListOrder = '$baseURL/api/order/list-orders';
  static const String getListOrder = '$baseURL/api/order-searchbar';
  static const String searchListOrder = '$baseURL/api/order-searchbar';
  static const String getListOrderDetails = '$baseURL/api/order/order-details';

  static const String loginUrl = '$baseURL/api/user/signin';
  static const String forgotPasswordUrl = '$baseURL/api/user/forgot';
  static const String resetPasswordUrl = '$baseURL/api/user/reset';

  static const String logoutUrl = '$baseURL/api/user/signout';
  static const String dashBoardUrl = '$baseURL/api/sales/dashboard';
  static const String dashBoardGraphUrl = '$baseURL/api/dashboard/orders';
  static const String addCustomerUrl = '$baseURL/api/sales/add-customer';
  // static const String customerListUrl = '$baseURL/api/sales/list-customer';
  static const String customerListUrl =
      '$baseURL/api/customer/customer-searchbar';
  static const String userDetailsUrl = '$baseURL/api/user/get-user-details';
  static const String findCustomerByPhone = '$baseURL/api/search-user-by-key';

  static const String addProductUrl =
      '$baseURL/api/product/add-product-general-item';
  static const String addProductNameUrl =
      '$baseURL/api/product/add-product-name';
  static const String addProductPropsUrl =
      '$baseURL/api/product/add-product-props';
  static const String addProductImageUrl =
      '$baseURL/api/product/add-product-image';

  static const String editProductUrl =
      '$baseURL/api/product/edit-product-general-item';
  static const String editProductNameUrl =
      '$baseURL/api/product/edit-product-name';
  static const String editProductPropsUrl =
      '$baseURL/api/product/edit-product-props';
  static const String editProductImageUrl =
      '$baseURL/api/product/edit-product-image';
  static const String listFilesForImageUrl = '$baseURL/api/file/list-files';

  static const String getStores = '$baseURL/api/stores/get-stores?store_name';
  static const String getSuppliers =
      '$baseURL/api/suppliers/get-suppliers?supplier_name';
  // static const String listPurchases =
  //     '$baseURL/api/purchases/list-purchase-order';
  static const String listPurchases =
      '$baseURL/api/purchases/purchase-searchbar';
  static const String listPurchaseVoucher =
      '$baseURL/api/purchases/voucher-searchbar';
  static const String addToPurchaseItem =
      '$baseURL/api/purchases/add-purchase-item';
  static const String addToPurchase = '$baseURL/api/purchases/add-to-purchase';
  static const String finishPurchaseOrder =
      '$baseURL/api/purchases/add-purchase-order';
  static const String addToStock = '$baseURL/api/product/add-stock';
  static const String getTaxtDetails = '$baseURL/api/tax/get-category-tax';
  static const String addPurchaseStock = '$baseURL/api/purchases/add-stock';
  // static const String listStock = '$baseURL/api/product/list-stocks';
  static const String listStock = '$baseURL/api/stock-searchbar';
  static const String detailsOfStock = '$baseURL/api/product/stock-details';
  static const String listPurchaseItems =
      '$baseURL/api/purchases/list-purchase-items';

  static const String removePurchaseitem =
      '$baseURL/api/purchases/remove-purchase-item';
  static const String addInvoiceorVoucher =
      '$baseURL/api/transaction/add-transaction';

  static const String listUser = '$baseURL/api/user/get-users';
  static const String listInvoiceAccountType =
      '$baseURL/api/transaction/get-account-types?type=invoice';
  static const String listVoucherAccountType =
      '$baseURL/api/transaction/get-account-types?type=voucher';
  static const String listTransactionType =
      '$baseURL/api/transaction/get-payment-methods';
  static const String listUnits = '$baseURL/api/product/list-units';
  static const String detailsOfTransaction =
      '$baseURL/api/transaction/transaction-details';
  static const String listAllTransaction =
      '$baseURL/api/transaction/list-transaction';
  static const String listStates = '$baseURL/api/location/get-states';
  static const String listDistricts = '$baseURL/api/location/get-district';

  static const String customerAccountBook =
      '$baseURL/api/reports/customer-account-book';
  static const String productSalesReport =
      '$baseURL/api/reports/product-sales-report';
  static const String salesReport = '$baseURL/api/reports/sales-report';
  static const String supplierSalesReport =
      '$baseURL/api/reports/supplier-sales-report';
  static const String applyCoupon = '$baseURL/api/discount/apply-coupon';
  static const String listFaqs = '$baseURL/api/faq/faqs/company/1';
}
