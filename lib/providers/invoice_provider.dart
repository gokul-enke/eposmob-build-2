import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:pos_machine/models/get_invoice_account_type.dart';
import 'package:pos_machine/models/get_voucher_account_type.dart';
import 'package:pos_machine/models/invoice_details.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/models/list_receipt.dart' as receipt_list;
import 'package:pos_machine/models/receipt_details.dart';

import '../models/get_payment_method.dart';

import '../models/get_users.dart';

import '../models/list_transaction.dart';
import '../resources/app_url.dart';

class InvoiceProvider extends ChangeNotifier {
  bool _isLoading = false;
  ListTransaction? listTransaction;
  Invoice? listInvoice;
  InvoiceDetails? invoiceDetails;
  List<receipt_list.Receipt>? receiptListDetails;
  ReceiptDetails? receiptDetails;
  List<ListTransaction>? transactionListDetails;
  List<Invoice>? invoiceListDetails;

  // Store all invoices for local filtering and pagination
  List<Invoice>? _allInvoices;
  List<Invoice>? get allInvoices => _allInvoices;

  // Store all receipts for local filtering and pagination
  List<receipt_list.Receipt>? _allReceipts;
  List<receipt_list.Receipt>? get allReceipts => _allReceipts;
  receipt_list.ReceiptData? _receiptData;
  receipt_list.ReceiptData? get receiptData => _receiptData;

  Map<String, String>? paymentList;
  Map<String, String>? getVoucherAccountTypesModelData = {};
  Map<String, String>? getInvoiceAccountTypesModelData = {};
  List<GetUsersModelData>? getUsersList = [];
  ListTransaction? get getListTransaction => listTransaction;
  Invoice? get getListInvoice => listInvoice;
  List<receipt_list.Receipt>? get getListReceipt => receiptListDetails;
  InvoiceDetails? get getInvoiceDetails => invoiceDetails;
  ReceiptDetails? get getReceiptDetails => receiptDetails;
  List<GetUsersModelData>? get getUsersListAPI => getUsersList;
  Map<String, String>? get getVoucherAccountTypes =>
      getVoucherAccountTypesModelData;
  Map<String, String>? get getInvoiceAccountTypes =>
      getInvoiceAccountTypesModelData;
  Map<String, String>? get getPaymentType => paymentList;

  // Pagination properties
  int _currentPage = 1;
  int _totalPages = 1;
  int _itemsPerPage = 20;
  String? _filterName;
  String? _filterInvoiceNumber;
  String? _filterFromDate;
  String? _filterToDate;
  String? _filterStatus;

  // Receipt pagination properties
  int _receiptCurrentPage = 1;
  int _receiptTotalPages = 1;
  int _receiptItemsPerPage = 20;
  String? _receiptFilterName;
  String? _receiptFilterReceiptNumber;
  String? _receiptFilterStatus;
  String? _receiptFilterPaymentReference;
  String? _receiptFilterPaymentMethod;

  // Getters for pagination
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get itemsPerPage => _itemsPerPage;
  bool get isLoading => _isLoading;

  // Getters for receipt pagination
  int get receiptCurrentPage => _receiptCurrentPage;
  int get receiptTotalPages => _receiptTotalPages;
  int get receiptItemsPerPage => _receiptItemsPerPage;

  // Navigation methods
  void goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    applyFiltersLocally(filterName: _filterName, page: page);
  }

  // Receipt navigation methods
  void goToReceiptPage(int page) {
    if (page < 1 || page > _receiptTotalPages) return;

    applyReceiptFiltersLocally(filterName: _receiptFilterName, page: page);
  }

  void applyFilters(
      {String? name,
      String? invoiceNumber,
      String? fromDate,
      String? toDate,
      String? status,
      int page = 1}) {
    _filterName = name;
    _filterInvoiceNumber = invoiceNumber;
    _filterFromDate = fromDate;
    _filterToDate = toDate;
    _filterStatus = status;
    _currentPage = page;
    applyFiltersLocally(
        filterName: name,
        filterInvoiceNumber: invoiceNumber,
        filterFromDate: fromDate,
        filterToDate: toDate,
        filterStatus: status,
        page: page);
  }

  void applyReceiptFilters({
    String? name,
    String? receiptNumber,
    String? paymentReference,
    String? receiptStatus,
    String? paymentMethod,
    int page = 1
    }) {
    _receiptFilterName = name;
    _receiptFilterStatus = receiptStatus;
    _receiptFilterPaymentReference = paymentReference;
    _receiptFilterPaymentMethod = paymentMethod;
    _receiptFilterReceiptNumber = receiptNumber;

    _receiptCurrentPage = page;
    applyReceiptFiltersLocally(
      filterName: name, 
      filterReceiptNumber: receiptNumber,
      filterPaymentReference: paymentReference,
      filterStatus: receiptStatus,
      filterPaymentMethod: paymentMethod,
      page: page
      );
  }

  void resetFilters() {
    _filterName = null;
    _filterInvoiceNumber = null;
    _filterFromDate = null;
    _filterToDate = null;
    _filterStatus = null;
    _currentPage = 1;
    applyFiltersLocally(page: 1);
  }

  void resetReceiptFilters() {
    _receiptFilterName = null;
    _receiptFilterReceiptNumber = null;
    _receiptFilterStatus = null;
    _receiptFilterPaymentReference = null;
    _receiptFilterPaymentMethod = null;
    _receiptCurrentPage = 1;
    applyReceiptFiltersLocally(page: 1);
  }

  // Apply filters locally
  void applyFiltersLocally(
      {String? filterName,
      String? filterInvoiceNumber,
      String? filterFromDate,
      String? filterToDate,
      String? filterStatus,
      int page = 1}) {
    debugPrint("applyFiltersLocally: filterName=$filterName, page=$page");
    debugPrint("_allInvoices: ${_allInvoices?.length ?? 0} invoices");

    if (_allInvoices == null || _allInvoices!.isEmpty) {
      debugPrint("No invoices available for filtering");
      invoiceListDetails = [];
      _currentPage = 1;
      _totalPages = 1;
      notifyListeners();
      return;
    }

    // Filter invoices
    List<Invoice> filteredInvoices = [..._allInvoices!];
    debugPrint("Starting with ${filteredInvoices.length} invoices");

    // search by name
    if (filterName != null && filterName.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        final bool matchesName = invoice.customer.user.name
            .toLowerCase()
            .contains(filterName.toLowerCase());
        return matchesName;
      }).toList();
      debugPrint(
          "After name filter: ${filteredInvoices.length} invoices match '$filterName'");
    }

    // Apply invoice number filter
    if (filterInvoiceNumber != null && filterInvoiceNumber.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.invoiceNumber
            .toLowerCase()
            .contains(filterInvoiceNumber.toLowerCase());
      }).toList();
    }

    // Apply date range filter
    if (filterFromDate != null && filterFromDate.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.invoiceDate.compareTo(filterFromDate) >= 0;
      }).toList();
    }

    if (filterToDate != null && filterToDate.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.invoiceDate.compareTo(filterToDate) <= 0;
      }).toList();
    }

    // Apply status filter
    if (filterStatus != null && filterStatus.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.status.toLowerCase() == filterStatus.toLowerCase();
      }).toList();
    }

    // Update total pages
    _totalPages = (filteredInvoices.length / _itemsPerPage).ceil();
    _totalPages = _totalPages == 0 ? 1 : _totalPages;
    debugPrint(
        "Total pages: $_totalPages (${filteredInvoices.length} items / $_itemsPerPage per page)");

    // Adjust current page if it's out of bounds
    if (page > _totalPages) {
      _currentPage = _totalPages;
      debugPrint("Adjusted current page to $_currentPage (was $page)");
    } else {
      _currentPage = page;
      debugPrint("Set current page to $_currentPage");
    }

    // Paginate
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    debugPrint("Pagination: startIndex=$startIndex, endIndex=$endIndex");

    if (startIndex >= filteredInvoices.length) {
      // If start index is out of bounds, show empty list
      debugPrint("Start index out of bounds, showing empty list");
      invoiceListDetails = [];
    } else {
      // Ensure end index doesn't exceed list length
      endIndex = endIndex > filteredInvoices.length
          ? filteredInvoices.length
          : endIndex;
      debugPrint("Taking items $startIndex to $endIndex");
      invoiceListDetails = filteredInvoices.sublist(startIndex, endIndex);
      debugPrint("Final list has ${invoiceListDetails?.length ?? 0} invoices");
    }

    notifyListeners();
  }

  // Apply receipt filters locally
  void applyReceiptFiltersLocally({
    String? filterName,
    String? filterReceiptNumber,
    String? filterPaymentReference,
    String? filterStatus,
    String? filterPaymentMethod, 
    int page = 1
    }) {
    debugPrint(
        "applyReceiptFiltersLocally: filterName=$filterName, page=$page");
    debugPrint("_allReceipts: ${_allReceipts?.length ?? 0} receipts");

    if (_allReceipts == null || _allReceipts!.isEmpty) {
      debugPrint("No receipts available for filtering");
      receiptListDetails = [];
      _receiptCurrentPage = 1;
      _receiptTotalPages = 1;
      notifyListeners();
      return;
    }

    // Filter receipts
    List<receipt_list.Receipt> filteredReceipts = [..._allReceipts!];
    debugPrint("Starting with ${filteredReceipts.length} receipts");

    if (filterName != null && filterName.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        final bool matchesName = receipt.customer.user.name
            .toLowerCase()
            .contains(filterName.toLowerCase());
        return matchesName;
      }).toList();
      debugPrint(
          "After name filter: ${filteredReceipts.length} receipts match '$filterName'");
    }

    // Apply receipt number filter
    if (filterReceiptNumber != null && filterReceiptNumber.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.receiptNumber
            .toLowerCase()
            .contains(filterReceiptNumber.toLowerCase());
      }).toList();
    }

    // Apply payment reference filter
    if (filterPaymentReference != null && filterPaymentReference.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.paymentReference
            .toLowerCase()
            .contains(filterPaymentReference.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (filterStatus != null && filterStatus.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.receiptStatus.toLowerCase() == filterStatus.toLowerCase();
      }).toList();
    }

    // Apply payment method filter
    if (filterPaymentMethod != null && filterPaymentMethod.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.paymentMethod.toLowerCase() == filterPaymentMethod.toLowerCase();
      }).toList();
    }

    // Update total pages
    _receiptTotalPages =
        (filteredReceipts.length / _receiptItemsPerPage).ceil();
    _receiptTotalPages = _receiptTotalPages == 0 ? 1 : _receiptTotalPages;
    debugPrint(
        "Total pages: $_receiptTotalPages (${filteredReceipts.length} items / $_receiptItemsPerPage per page)");

    // Adjust current page if it's out of bounds
    if (page > _receiptTotalPages) {
      _receiptCurrentPage = _receiptTotalPages;
      debugPrint("Adjusted current page to $_receiptCurrentPage (was $page)");
    } else {
      _receiptCurrentPage = page;
      debugPrint("Set current page to $_receiptCurrentPage");
    }

    // Paginate
    int startIndex = (_receiptCurrentPage - 1) * _receiptItemsPerPage;
    int endIndex = startIndex + _receiptItemsPerPage;
    debugPrint("Pagination: startIndex=$startIndex, endIndex=$endIndex");

    if (startIndex >= filteredReceipts.length) {
      // If start index is out of bounds, show empty list
      debugPrint("Start index out of bounds, showing empty list");
      receiptListDetails = [];
    } else {
      // Ensure end index doesn't exceed list length
      endIndex = endIndex > filteredReceipts.length
          ? filteredReceipts.length
          : endIndex;
      debugPrint("Taking items $startIndex to $endIndex");
      receiptListDetails = filteredReceipts.sublist(startIndex, endIndex);
      debugPrint("Final list has ${receiptListDetails?.length ?? 0} receipts");
    }

    // Update receipt data for pagination controls
    if (_receiptData != null) {
      _receiptData?.currentPage = _receiptCurrentPage;
      _receiptData?.lastPage = _receiptTotalPages;
      _receiptData?.perPage = _receiptItemsPerPage;
      _receiptData?.total = filteredReceipts.length;
    }

    notifyListeners();
  }

  // Update pagination info from response
  void updatePaginationFromResponse(dynamic response) {
    if (response != null && response['status'] == 'success') {
      final data = response['data'];
      if (data != null) {
        _currentPage = data['current_page'] ?? 1;
        _totalPages = data['last_page'] ?? 1;
        _itemsPerPage = data['per_page'] ?? 20;
        notifyListeners();
      }
    }
  }

  String? getUserUpOnId(int value) {
    var user = getUsersList!.firstWhere((e) => e.id == value,
        // sample data
        // orElse: () => GetUsersModelData(id: 0, name: "Unknown"));
        orElse: () => GetUsersModelData(id: 0, name: "Super Admin"));

    return user.name;
  }

  void callListTransactionDetails({required transactionId}) {
    ListTransaction transaction = transactionListDetails!
        .firstWhere((element) => element.id == transactionId);
    listTransaction = transaction;
    notifyListeners();
  }

  String? getInvoiceNameUpOnId(int value, String type) {
    var accountTypes = getInvoiceAccountTypes;
    var accountVoucherTypes = getVoucherAccountTypesModelData;
    if (accountTypes != null && accountVoucherTypes != null) {
      // return accountTypes[value];
      String? accountTypeName = type == 'Cr'
          ? accountTypes['$value']
          : accountVoucherTypes['$value']; // Retrieve payment type with key '1'
      // debugPrint(accountTypeName);
      return accountTypeName;
    }
    return null;
  }

  String? getVoucherNameUpOnId(int value) {
    var accountTypes = getVoucherAccountTypesModelData;
    if (accountTypes != null) {
      return accountTypes[value];
    }
    return null;
  }

  InvoiceProvider();

  //          *********************** LIST ALL PAYMENT LIST  API ***************************************************

  Future<void> listAllPaymentList(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL listAllPaymentList ");

    final url = Uri.parse(APPUrl.listTransactionType);
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        GetPaymentMethodsModel getPaymentMethodsModel =
            GetPaymentMethodsModel.fromJson(jsonData);

        paymentList = getPaymentMethodsModel.paymentList;

        notifyListeners();
      } else {}
    } finally {}
  }
  //          *********************** LIST ALL INVOICE ACCOUNT TYPES  API ***************************************************

  Future<void> listAllInvoiceAccountTypes(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL listAllInvoiceAccountTypes ");

    final url = Uri.parse(APPUrl.listInvoiceAccountType);
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetInvoiceAccountTypesModel getInvoiceAccountTypesModel =
            GetInvoiceAccountTypesModel.fromJson(jsonData);

        getInvoiceAccountTypesModelData =
            getInvoiceAccountTypesModel.getInvoiceAccountTypesModelData;

        notifyListeners();
      } else {}
    } finally {}
  }
  //          *********************** LIST VOUCHER ACCOUNT TYPE  API ***************************************************

  Future<void> listVoucherAccountType(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL listVoucherAccountType ");

    final url = Uri.parse(APPUrl.listVoucherAccountType);
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        //   // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetVoucherAccountTypesModel getVoucherAccountTypesModel =
            GetVoucherAccountTypesModel.fromJson(jsonData);
        getVoucherAccountTypesModelData =
            getVoucherAccountTypesModel.getVoucherAccountTypesModelData;
        notifyListeners();
      } else {}
    } finally {}
  }
  //          *********************** LIST USERS LIST  API ***************************************************

  Future<void> listUsersList(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL listUsersList ");

    final url = Uri.parse(APPUrl.listUser);
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        //   // debugPrint(response.body.toString());
        final jsonData = json.decode(response.body);
        GetUsersModel getUsersModel = GetUsersModel.fromJson(jsonData);
        getUsersList = getUsersModel.data;
        notifyListeners();
      } else {}
    } finally {}
  }

  //          *********************** ADD VOUCHER / INVOICE  API ***************************************************

  Future<dynamic> addVoucher({
    required String accountType,
    required String paymentMethod,
    required String paymentMethodRef,
    required String amount,
    required String toUserID,
    required String type,
    required String comment,
    required String particular,
    required String accessToken,
  }) async {
    // debugPrint("$comment $particular");
    final Map<String, dynamic> apiBodyData = type == "invoice"
        ? {
            'type': type,
            "from_id": toUserID,
            'amount': amount,
            'payment_method_ref': paymentMethodRef,
            'payment_method': paymentMethod,
            'account_type': accountType,
            'comment': comment,
            'particulars': particular
          }
        : {
            'type': type,
            'to_id': toUserID,
            'amount': amount,
            'payment_method_ref': paymentMethodRef,
            'payment_method': paymentMethod,
            'account_type': accountType,
            'comment': comment,
            'particulars': particular
          };
    // debugPrint("voucher and invoice $apiBodyData");
    final url = Uri.parse(APPUrl.addInvoiceorVoucher);
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());

        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  //          *********************** LIST ALL TRANSACTION API ***************************************************

  Future<dynamic> listAllTransaction({
    String? type,
    required String accessToken,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'type': type,
    };
    // debugPrint(apiBodyData.toString());
    final url = type == null
        ? Uri.parse(APPUrl.listAllTransaction)
        : type == "Cr"
            ? Uri.parse("${APPUrl.listAllTransaction}?type=Cr")
            : Uri.parse("${APPUrl.listAllTransaction}?type=Dr");
    try {
      final response = await http.get(url, headers: {
        //'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        ListTransactionModel listTransactionModel =
            ListTransactionModel.fromJson(jsonData);

        transactionListDetails = listTransactionModel.data?.transactions;
        notifyListeners();
        return json.decode(response.body);
      } else {}
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }
  //          *********************** CALL DETAILS OF TRANSACTION / INVOICE/ VOUCHER  API ***************************************************

  Future<void> callDetailsOfTransaction({
    required int id,
    required String accessToken,
  }) async {
    // debugPrint("CALL DETAILS OF TRANSACTION / INVOICE/ VOUCHER  API");
    final url = Uri.parse("${APPUrl.detailsOfTransaction}/$id");

    try {
      final response = await http.get(url, headers: {
        //'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        // debugPrint(json.decode(response.body).toString());
        final jsonData = json.decode(response.body);
        ListTransaction listTransactionModel =
            ListTransaction.fromJson(jsonData["data"]);

        listTransaction = listTransactionModel;
        notifyListeners();
      } else {}
    } finally {}
  }

  //          *********************** LIST ALL INVOICE API ***************************************************

  Future<dynamic> listAllInvoices({
    required String accessToken,
    String? name,
    int? page,
    int? perPage,
  }) async {
    debugPrint("listAllInvoices called: name=$name, page=$page");
    _isLoading = true;
    notifyListeners();

    final queryParams = {
      'page': '1', // Always fetch all invoices for local pagination
      'per_page': '1000', // Get a large number for local filtering
    };

    final uri =
        Uri.parse(APPUrl.listAllInvoices).replace(queryParameters: queryParams);
    debugPrint("Fetching invoices from: $uri");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        ListInvoiceModel listInvoiceModel = ListInvoiceModel.fromJson(jsonData);

        // Store all invoices for local filtering
        _allInvoices = listInvoiceModel.data.invoices;
        debugPrint("Received ${_allInvoices?.length ?? 0} invoices from API");

        // Set filter name if provided
        if (name != null) {
          _filterName = name;
          debugPrint("Setting filter name to: $name");
        }

        // Apply filters based on current state
        applyFiltersLocally(filterName: _filterName, page: page ?? 1);

        _isLoading = false;
        notifyListeners();
        return jsonData;
      } else {
        debugPrint("Error fetching invoices: ${response.statusCode}");
        _isLoading = false;
        notifyListeners();
        return {'status': 'error', 'message': 'Failed to fetch invoices'};
      }
    } catch (e) {
      debugPrint("Exception fetching invoices: $e");
      _isLoading = false;
      notifyListeners();
      return {'status': 'error', 'message': e.toString()};
    }
  }

  //          *********************** CALL DETAILS OF INVOICE API ***************************************************

  Future<void> callDetailsOfInvoice({
    required int id,
    required String accessToken,
  }) async {
    // debugPrint("CALL DETAILS OF INVOICE API");
    final url = Uri.parse("${APPUrl.detailsOfInvoice}/$id");

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        InvoiceDetails invoiceDetailsData =
            InvoiceDetails.fromJson(jsonData["data"]);
        invoiceDetails = invoiceDetailsData;
        notifyListeners();
      } else {
        // debugPrint("Error fetching invoice details: ${response.reasonPhrase}");
        // Handle error responses accordingly
      }
    } catch (e) {
      // debugPrint("Exception occurred: $e");
      // Handle exceptions accordingly
    }
  }

  //          *********************** LIST ALL RECEIPT API ***************************************************
  Future<dynamic> listAllReceipts({
    required String accessToken,
    int page = 1,
    bool loadAll = false, // Add parameter to load all receipts
  }) async {
    _isLoading = true;
    notifyListeners();

    debugPrint(
        "🔍 Calling listAllReceipts with page: $page, loadAll: $loadAll");

    final queryParameters = <String, String>{
      'page': page.toString(),
      // If loadAll is true, request a large page size to get all receipts
      if (loadAll) 'per_page': '1000',
    };

    final url = Uri.parse(APPUrl.listAllReceipts)
        .replace(queryParameters: queryParameters);
    debugPrint("🔍 URL: $url");

    try {
      debugPrint(
          "🔍 Token: ${accessToken.substring(0, min(10, accessToken.length))}...");
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      debugPrint("🔍 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        debugPrint(
            "🔍 Response body preview: ${response.body.substring(0, min(100, response.body.length))}...");
        final jsonData = json.decode(response.body);
        receipt_list.ReceiptResponse receiptResponse =
            receipt_list.ReceiptResponse.fromJson(jsonData);

        if (loadAll) {
          // Store all receipts for local filtering and pagination
          _allReceipts = receiptResponse.data.data;
          _receiptData = receiptResponse.data;
          applyReceiptFiltersLocally(page: 1);
        } else {
          receiptListDetails = receiptResponse.data.data;
          _receiptData = receiptResponse.data;

          // Update pagination info
          _receiptCurrentPage = receiptResponse.data.currentPage;
          _receiptTotalPages = receiptResponse.data.lastPage;
          _receiptItemsPerPage = receiptResponse.data.perPage.toInt();
        }

        _isLoading = false;
        notifyListeners();
        return jsonData;
      } else {
        _isLoading = false;
        notifyListeners();
        debugPrint("❌ Error fetching receipts: ${response.reasonPhrase}");
        debugPrint("❌ Error body: ${response.body}");
        return {'status': 'error', 'message': 'Failed to fetch receipts'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("❌ Exception in listAllReceipts: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Load all receipts for local filtering and pagination
  Future<void> loadAllReceipts(String accessToken) async {
    await listAllReceipts(
      accessToken: accessToken,
      loadAll: true,
    );
  }

  //          *********************** CALL DETAILS OF RECEIPT API ***************************************************

  Future<void> callDetailsOfReceipt({
    required int id,
    required String accessToken,
  }) async {
    // debugPrint("CALL DETAILS OF RECEIPT API");
    final url = Uri.parse(
        "${APPUrl.detailsOfReceipt}/$id"); // Update the URL to point to receipt details

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
      });
      // debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // debugPrint(jsonData.toString());
        ReceiptDetails receiptDetailsData = ReceiptDetails.fromJson(
            jsonData); // Update to use ReceiptDetails model
        receiptDetails = receiptDetailsData;
        notifyListeners();
      } else {
        // debugPrint("Error fetching receipt details: ${response.reasonPhrase}");
        // Handle error responses accordingly
      }
    } catch (e) {
      // debugPrint("Exception occurred: $e");
      // Handle exceptions accordingly
    }
  }
}
