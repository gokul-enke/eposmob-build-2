import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Store current filtered invoices (pre-pagination)
  List<Invoice> _filteredInvoices = [];
  List<Invoice> get filteredInvoices => _filteredInvoices;

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
  String? _filterOrderNumber;
  String? _filterPhone;
  String? _filterEmail;

  // Receipt pagination properties
  int _receiptCurrentPage = 1;
  int _receiptTotalPages = 1;
  int _receiptItemsPerPage = 20;
  String? _receiptFilterName;
  String? _receiptFilterReceiptNumber;
  String? _receiptFilterStatus;
  String? _receiptFilterPaymentReference;
  String? _receiptFilterPaymentMethod;
  String? _receiptfilterPhone;
  String? _receiptfilterEmail;

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

    applyFiltersLocally(
      filterName: _filterName,
      filterInvoiceNumber: _filterInvoiceNumber,
      filterFromDate: _filterFromDate,
      filterToDate: _filterToDate,
      filterStatus: _filterStatus,
      filterOrderNumber: _filterOrderNumber,
      filterPhone: _filterPhone,
      filterEmail: _filterEmail,
      page: page,
    );
  }

  //          *********************** CUSTOMER TRANSACTIONS API ***************************************************
  Future<dynamic> listCustomerTransactions({
    required String accessToken,
    String? customerId,
    String? dateFrom,
    String? dateTo,
    String? transactionType, // invoice, voucher, receipt, sales return
    String? type, // credit | debit
    int? perPage,
    int? page,
  }) async {
    // Build query parameters
    final queryParams = <String, String>{
      if (customerId != null && customerId.isNotEmpty)
        'customer_id': customerId,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (transactionType != null && transactionType.isNotEmpty)
        'transaction_type': transactionType,
      if (type != null && type.isNotEmpty) 'type': type,
      'per_page': (perPage ?? 20).toString(),
      'page': (page ?? 1).toString(),
    };

    final uri = Uri.parse(APPUrl.customerTransactions)
        .replace(queryParameters: queryParams);

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Parse into existing model for UI consumption
        try {
          final listModel = ListTransactionModel.fromJson(jsonData);
          transactionListDetails = listModel.data?.transactions;
          notifyListeners();
        } catch (e) {
          debugPrint('Error parsing customer transactions: $e');
        }
        return jsonData;
      } else {
        throw Exception(
            'Failed to load customer transactions: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  //          *********************** ZATCA PHASE 2 INVOICE RESYNC ***************************************************
  Future<dynamic> zatcaPhase2InvoiceResync({
    required int id,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaPhase2InvoiceResync);

    debugPrint('[ZATCA][Provider] Phase2 Resync URL: $uri');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final maskedHeaders = {
        'Authorization':
            'Bearer ${accessToken.length > 10 ? accessToken.substring(0, 6) + '...' : '***'}',
        'X-Tenant': apiKey,
      };
      debugPrint('[ZATCA][Provider] Headers: $maskedHeaders');
      debugPrint('[ZATCA][Provider] Body: {id: $id} (POST)');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: {'id': id.toString()},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return response.body;
        }
      } else {
        debugPrint(
            '[ZATCA][Provider] HTTP ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  //          *********************** ZATCA PHASE 2 INVOICE PRINT ***************************************************
  Future<dynamic> zatcaPhase2InvoicePrint({
    required int id,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaPhase2InvoicePrint);

    debugPrint('[ZATCA][Provider] Phase2 Print URL: $uri');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final headers = {
        'Authorization':
            'Bearer ${accessToken.length > 10 ? accessToken.substring(0, 6) + '...' : '***'}',
        'X-Tenant': apiKey,
      };
      debugPrint('[ZATCA][Provider] Headers: $headers');
      debugPrint('[ZATCA][Provider] Body: {id: $id} (POST)');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: {'id': id.toString()},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return response.body;
        }
      } else {
        debugPrint(
            '[ZATCA][Provider] HTTP ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  //          *********************** ZATCA BULK SEND ***************************************************
  Future<dynamic> zatcaBulkSend({
    required List<int> ids,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaBulkSend);

    debugPrint('[ZATCA][Provider] Bulk Send URL: $uri (POST)');
    debugPrint('[ZATCA][Provider] Sending IDs: ${ids.join(',')}');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'X-Tenant': apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 40));

      debugPrint(
          '[ZATCA][Provider] Bulk Send Response Status: ${response.statusCode}');
      debugPrint('[ZATCA][Provider] Bulk Send Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'message':
              'Failed with status ${response.statusCode}: ${response.body}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] Bulk Send ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] Bulk Send EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
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
      String? phone,
      String? email,
      String? orderNumber,
      int page = 1}) {
    _filterName = name;
    _filterInvoiceNumber = invoiceNumber;
    _filterFromDate = fromDate;
    _filterToDate = toDate;
    _filterStatus = status;
    _filterOrderNumber = orderNumber;
    _filterPhone = phone;
    _filterEmail = email;
    _currentPage = page;
    applyFiltersLocally(
      filterName: name,
      filterInvoiceNumber: invoiceNumber,
      filterOrderNumber: orderNumber,
      filterPhone: phone,
      filterEmail: email,
      filterFromDate: fromDate,
      filterToDate: toDate,
      filterStatus: status,
      page: page,
    );
  }

  void applyReceiptFilters(
      {String? name,
      String? receiptNumber,
      String? paymentReference,
      String? receiptStatus,
      String? paymentMethod,
      String? phone,
      String? email,
      int page = 1}) {
    _receiptFilterName = name;
    _receiptFilterStatus = receiptStatus;
    _receiptFilterPaymentReference = paymentReference;
    _receiptFilterPaymentMethod = paymentMethod;
    _receiptFilterReceiptNumber = receiptNumber;
    _receiptfilterPhone = phone;
    _receiptfilterEmail = email;

    _receiptCurrentPage = page;
    applyReceiptFiltersLocally(
        filterName: name,
        filterReceiptNumber: receiptNumber,
        filterPaymentReference: paymentReference,
        filterStatus: receiptStatus,
        filterPaymentMethod: paymentMethod,
        filterPhone: phone,
        filterEmail: email,
        page: page);
  }

  void resetFilters() {
    _filterName = null;
    _filterInvoiceNumber = null;
    _filterFromDate = null;
    _filterToDate = null;
    _filterStatus = null;
    _filterOrderNumber = null;
    _filterPhone = null;
    _filterEmail = null;
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
      String? filterOrderNumber,
      String? filterPhone,
      String? filterEmail,
      int page = 1}) {
    debugPrint("[DEBUG] applyFiltersLocally CALLED. Current Filter State:");
    debugPrint(
        " - Name: $filterName, Number: $filterInvoiceNumber, Status: $filterStatus");
    debugPrint(
        " - Total Invoices in Memory (_allInvoices): ${_allInvoices?.length ?? 0}");

    if (_allInvoices == null || _allInvoices!.isEmpty) {
      debugPrint("[DEBUG] No invoices in memory. Aborting filter.");
      _filteredInvoices = [];
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
    // Apply date range filter
    if (filterFromDate != null && filterFromDate.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return _isDateAfterOrEqual(invoice.invoiceDate, filterFromDate);
      }).toList();
      debugPrint(
          "After from date filter: ${filteredInvoices.length} invoices after '$filterFromDate'");
    }

    if (filterToDate != null && filterToDate.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return _isDateBeforeOrEqual(invoice.invoiceDate, filterToDate);
      }).toList();
      debugPrint(
          "After to date filter: ${filteredInvoices.length} invoices before '$filterToDate'");
    }

    // Apply status filter
    if (filterStatus != null && filterStatus.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.status.toLowerCase() == filterStatus.toLowerCase();
      }).toList();
    }
    //     if (filterOrderNumber != null && filterOrderNumber.isNotEmpty) {
    //   filteredInvoices = filteredInvoices.where((invoice) {
    //     // Assuming you have an orderNumber field in your Invoice model
    //     // If not, you'll need to add it to the model first
    //     return invoice.orderNumber != null &&
    //            invoice.orderNumber.toLowerCase().contains(filterOrderNumber.toLowerCase());
    //   }).toList();
    //   debugPrint(
    //       "After order number filter: ${filteredInvoices.length} invoices match '$filterOrderNumber'");
    // }
    // Apply phone filter
    if (filterPhone != null && filterPhone.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.customer.user.phone != null &&
            invoice.customer.user.phone.contains(filterPhone);
      }).toList();
      debugPrint(
          "After phone filter: ${filteredInvoices.length} invoices match '$filterPhone'");
    }

    // Apply email filter
    if (filterEmail != null && filterEmail.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) {
        return invoice.customer.user.email != null &&
            invoice.customer.user.email
                .toLowerCase()
                .contains(filterEmail.toLowerCase());
      }).toList();
      debugPrint(
          "After email filter: ${filteredInvoices.length} invoices match '$filterEmail'");
    }

    _filteredInvoices = filteredInvoices;

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
  void applyReceiptFiltersLocally(
      {String? filterName,
      String? filterReceiptNumber,
      String? filterPaymentReference,
      String? filterStatus,
      String? filterPaymentMethod,
      String? filterPhone,
      String? filterEmail,
      int page = 1}) {
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
    if (filterPhone != null && filterPhone.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.customer.user.phone != null &&
            receipt.customer.user.phone.contains(filterPhone);
      }).toList();
      debugPrint(
          "After phone filter: ${filteredReceipts.length} invoices match '$filterPhone'");
    }

    // Apply email filter
    if (filterEmail != null && filterEmail.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.customer.user.email != null &&
            receipt.customer.user.email
                .toLowerCase()
                .contains(filterEmail.toLowerCase());
      }).toList();
      debugPrint(
          "After email filter: ${filteredReceipts.length} invoices match '$filterEmail'");
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
        return receipt.receiptStatus.toLowerCase() ==
            filterStatus.toLowerCase();
      }).toList();
    }

    // Apply payment method filter
    if (filterPaymentMethod != null && filterPaymentMethod.isNotEmpty) {
      filteredReceipts = filteredReceipts.where((receipt) {
        return receipt.paymentMethod.toLowerCase() ==
            filterPaymentMethod.toLowerCase();
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

  // Update a single invoice's ZATCA status locally (both paginated view and cache)
  void updateInvoiceZatcaStatus(int id, String status) {
    // Helper to clone invoice with new status
    Invoice _cloneWithStatus(Invoice inv, String s) {
      return Invoice(
        id: inv.id,
        userId: inv.userId,
        customerId: inv.customerId,
        invoiceNumber: inv.invoiceNumber,
        type: inv.type,
        companyId: inv.companyId,
        amount: inv.amount,
        invoiceDate: inv.invoiceDate,
        dueDate: inv.dueDate,
        status: inv.status,
        createdBy: inv.createdBy,
        createdAt: inv.createdAt,
        updatedAt: inv.updatedAt,
        customer: inv.customer,
        zatcaStatus: s,
      );
    }

    bool updated = false;

    if (invoiceListDetails != null && invoiceListDetails!.isNotEmpty) {
      for (var i = 0; i < invoiceListDetails!.length; i++) {
        if (invoiceListDetails![i].id == id) {
          invoiceListDetails![i] =
              _cloneWithStatus(invoiceListDetails![i], status);
          updated = true;
          break;
        }
      }
    }

    if (_allInvoices != null && _allInvoices!.isNotEmpty) {
      for (var i = 0; i < _allInvoices!.length; i++) {
        if (_allInvoices![i].id == id) {
          _allInvoices![i] = _cloneWithStatus(_allInvoices![i], status);
          updated = true;
          break;
        }
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  // Re-apply current filters and page using in-memory cache only.
  // This triggers UI update without fetching from network or resetting pagination.
  void reapplyCurrentFilters() {
    applyFiltersLocally(
      filterName: _filterName,
      filterInvoiceNumber: _filterInvoiceNumber,
      filterFromDate: _filterFromDate,
      filterToDate: _filterToDate,
      filterStatus: _filterStatus,
      filterOrderNumber: _filterOrderNumber,
      filterPhone: _filterPhone,
      filterEmail: _filterEmail,
      page: _currentPage,
    );
  }

  //          *********************** LIST ALL PAYMENT LIST  API ***************************************************

  Future<void> listAllPaymentList(
    String accessToken,
  ) async {
    debugPrint("[InvoiceProvider] listAllPaymentList called");

    final url = Uri.parse(APPUrl.listTransactionType);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[InvoiceProvider] API key not found");
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      debugPrint("[InvoiceProvider] Fetching payment methods from: $url");
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      debugPrint(
          "[InvoiceProvider] Payment methods response: ${response.statusCode}");
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint("[InvoiceProvider] Payment methods data: $jsonData");
        GetPaymentMethodsModel getPaymentMethodsModel =
            GetPaymentMethodsModel.fromJson(jsonData);

        // Use paymentListAsMap for backwards compatibility with Map<String, String>
        paymentList = getPaymentMethodsModel.paymentListAsMap;
        debugPrint("[InvoiceProvider] Payment list parsed: $paymentList");

        notifyListeners();
      } else {
        debugPrint("[InvoiceProvider] Payment methods error: ${response.body}");
      }
    } catch (e) {
      debugPrint("[InvoiceProvider] Payment methods exception: $e");
    }
  }

  //          *********************** ZATCA PHASE 1 INVOICE PRINT ***************************************************
  Future<dynamic> zatcaPhase1InvoicePrint({
    required int id,
    required String accessToken,
  }) async {
    final uri = Uri.parse(APPUrl.zatcaPhase1InvoicePrint);

    debugPrint('[ZATCA][Provider] Phase1 Print URL: $uri');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final headers = {
        'Authorization':
            'Bearer ${accessToken.length > 10 ? accessToken.substring(0, 6) + '...' : '***'}',
        'X-Tenant': apiKey,
      };
      debugPrint('[ZATCA][Provider] Headers: $headers');
      debugPrint('[ZATCA][Provider] Body: {id: $id} (POST)');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
        body: {'id': id.toString()},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return response.body;
        }
      } else {
        debugPrint(
            '[ZATCA][Provider] HTTP ${response.statusCode}: ${response.body}');
        return {
          'status': 'error',
          'message': 'Failed with status ${response.statusCode}'
        };
      }
    } on TimeoutException catch (_) {
      debugPrint('[ZATCA][Provider] ERROR: Request timed out');
      return {'status': 'error', 'message': 'Request timed out'};
    } catch (e) {
      debugPrint('[ZATCA][Provider] EXCEPTION: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }
  //          *********************** LIST ALL INVOICE ACCOUNT TYPES  API ***************************************************

  Future<void> listAllInvoiceAccountTypes(
    String accessToken,
  ) async {
    debugPrint("[InvoiceProvider] listAllInvoiceAccountTypes called");

    final url = Uri.parse(APPUrl.listInvoiceAccountType);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("[InvoiceProvider] API key not found");
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      debugPrint("[InvoiceProvider] Fetching account types from: $url");
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      debugPrint(
          "[InvoiceProvider] Account types response: ${response.statusCode}");
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint("[InvoiceProvider] Account types data: $jsonData");
        GetInvoiceAccountTypesModel getInvoiceAccountTypesModel =
            GetInvoiceAccountTypesModel.fromJson(jsonData);

        getInvoiceAccountTypesModelData =
            getInvoiceAccountTypesModel.getInvoiceAccountTypesModelData;
        debugPrint(
            "[InvoiceProvider] Account types parsed: $getInvoiceAccountTypesModelData");

        notifyListeners();
      } else {
        debugPrint("[InvoiceProvider] Account types error: ${response.body}");
      }
    } catch (e) {
      debugPrint("[InvoiceProvider] Account types exception: $e");
    }
  }
  //          *********************** LIST VOUCHER ACCOUNT TYPE  API ***************************************************

  Future<void> listVoucherAccountType(
    String accessToken,
  ) async {
    // debugPrint("LIST ALL listVoucherAccountType ");

    final url = Uri.parse(APPUrl.listVoucherAccountType);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.post(url, body: apiBodyData, headers: {
        // 'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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

  //          *********************** CREATE INVOICE API ***************************************************

  Future<dynamic> createInvoice({
    required int customerId,
    required String type,
    required String dueDate,
    required String invoiceDate,
    required double amount,
    required String status,
    required int paymentMethod,
    required List<Map<String, dynamic>> invoiceItems,
    required String accessToken,
    // Discount fields
    String? couponId,
    double? flatDiscount,
    double? percentageDiscount,
    double? discountAmount,
  }) async {
    // Build request body
    final Map<String, dynamic> apiBodyData = {
      "customer_id": customerId,
      "type": type,
      "due_date": dueDate,
      "invoice_date": invoiceDate,
      "amount": amount,
      "status": status,
      "payment_method": paymentMethod,
      "invoice_items": invoiceItems,
      // Discount data
      if (couponId != null) "coupon_id": couponId,
      if (flatDiscount != null && flatDiscount > 0)
        "flat_discount": flatDiscount,
      if (percentageDiscount != null && percentageDiscount > 0)
        "percentage_discount": percentageDiscount,
      if (discountAmount != null && discountAmount > 0)
        "discount_amount": discountAmount,
    };

    debugPrint(
        "[InvoiceProvider] createInvoice called with body: $apiBodyData");

    final url = Uri.parse(APPUrl.createInvoice);

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      debugPrint(
          "[InvoiceProvider] createInvoice response: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = json.decode(response.body);
        debugPrint("[InvoiceProvider] createInvoice success: $responseBody");
        return responseBody;
      } else {
        debugPrint("[InvoiceProvider] createInvoice error: ${response.body}");
        try {
          return json.decode(response.body);
        } catch (_) {
          return {
            'status': 'error',
            'message': 'Failed with status ${response.statusCode}'
          };
        }
      }
    } catch (e) {
      debugPrint("[InvoiceProvider] createInvoice exception: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }

  //          *********************** LIST ALL TRANSACTION API ***************************************************

  Future<dynamic> listAllTransaction({
    String? type,
    required String accessToken,
    String? customerId,
    String? customerName,
    String? transactionType,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) async {
    // Build query parameters
    Map<String, String> queryParams = {};

    if (type != null) queryParams['type'] = type;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (customerName != null) queryParams['customer_name'] = customerName;
    if (transactionType != null)
      queryParams['transaction_type'] = transactionType;
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    if (page != null) queryParams['page'] = page.toString();

    // Build URL with query parameters
    Uri url = Uri.parse(APPUrl.listAllTransaction);
    if (queryParams.isNotEmpty) {
      url = Uri.parse(APPUrl.listAllTransaction)
          .replace(queryParameters: queryParams);
    }
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        //'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
      });
      // debugPrint('inside ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Detect new grouped structure: data.data is a List of customer groups each having 'transactions'
        try {
          final data = jsonData['data'];
          if (data is Map &&
              data['data'] is List &&
              (data['data'] as List).isNotEmpty &&
              (data['data'][0] is Map) &&
              (data['data'][0] as Map).containsKey('transactions')) {
            // New grouped response detected. Do not parse into old model here.
            // Optionally, we could flatten transactions if needed by legacy callers.
            // For safety, leave transactionListDetails unchanged and just return json.
            notifyListeners();
            return jsonData;
          }
        } catch (_) {
          // Fallback to old behavior
        }

        // Old flat transactions response: parse into model for backward compatibility
        ListTransactionModel listTransactionModel =
            ListTransactionModel.fromJson(jsonData);
        transactionListDetails = listTransactionModel.data?.transactions;
        notifyListeners();
        return jsonData;
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

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        //'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        ListInvoiceModel listInvoiceModel = ListInvoiceModel.fromJson(jsonData);

        // Store all invoices for local filtering
        _allInvoices = listInvoiceModel.data.invoices;
        debugPrint(
            "[DEBUG][InvoiceProvider] API returned ${listInvoiceModel.data.total} total invoices.");
        debugPrint(
            "[DEBUG][InvoiceProvider] Received ${_allInvoices?.length ?? 0} invoices in the current batch.");

        // Set filter name if provided
        if (name != null) {
          _filterName = name;
        }

        // Apply filters based on current state with all parameters
        applyFiltersLocally(
          filterName: _filterName,
          filterInvoiceNumber: _filterInvoiceNumber,
          filterFromDate: _filterFromDate,
          filterToDate: _filterToDate,
          filterStatus: _filterStatus,
          filterOrderNumber: _filterOrderNumber,
          filterPhone: _filterPhone,
          filterEmail: _filterEmail,
          page: page ?? 1,
        );

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

    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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

  // Refresh a single invoice from server using the list-all-invoices API,
  // but only merge the updated invoice into the in-memory lists without
  // changing filters, pagination or loading flags.
  Future<void> refreshSingleInvoiceFromServer({
    required String accessToken,
    required int invoiceId,
  }) async {
    try {
      final queryParams = {
        'page': '1',
        'per_page': '1000',
      };

      final uri = Uri.parse(APPUrl.listAllInvoices)
          .replace(queryParameters: queryParams);
      debugPrint(
          'refreshSingleInvoiceFromServer: fetching invoices for merge from: $uri');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint(
            'refreshSingleInvoiceFromServer: API key missing, skipping merge');
        return;
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
            'refreshSingleInvoiceFromServer: HTTP ${response.statusCode}, skipping merge');
        return;
      }

      final jsonData = json.decode(response.body);
      ListInvoiceModel listInvoiceModel = ListInvoiceModel.fromJson(jsonData);
      final List<Invoice> fetchedInvoices = listInvoiceModel.data.invoices;

      final updated = fetchedInvoices
          .where((inv) => inv.id == invoiceId)
          .cast<Invoice?>()
          .toList();

      if (updated.isEmpty) {
        debugPrint(
            'refreshSingleInvoiceFromServer: invoice $invoiceId not found in response');
        return;
      }

      final Invoice updatedInvoice = updated.first!;

      // Merge into _allInvoices
      if (_allInvoices != null && _allInvoices!.isNotEmpty) {
        for (var i = 0; i < _allInvoices!.length; i++) {
          if (_allInvoices![i].id == invoiceId) {
            _allInvoices![i] = updatedInvoice;
            break;
          }
        }
      }

      // Merge into paginated view
      if (invoiceListDetails != null && invoiceListDetails!.isNotEmpty) {
        for (var i = 0; i < invoiceListDetails!.length; i++) {
          if (invoiceListDetails![i].id == invoiceId) {
            invoiceListDetails![i] = updatedInvoice;
            break;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('refreshSingleInvoiceFromServer: exception $e');
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
      // Get API key from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException("API key not found. Please restart the app.");
      }
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
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
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Tenant': apiKey,
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

  //          *********************** ADD RECEIPT API ***************************************************
  Future<dynamic> addReceipt({
    required String customerId,
    required String receiptStatus,
    required List<Map<String, dynamic>> receiptItems,
    required String accessToken,
    String? paymentReference,
  }) async {
    final Map<String, dynamic> apiBodyData = {
      'customer_id': customerId,
      'receipt_status': receiptStatus,
      'receipt_items': receiptItems,
    };

    // Add payment_reference if provided
    if (paymentReference != null && paymentReference.isNotEmpty) {
      apiBodyData['payment_reference'] = paymentReference;
    }

    final url = Uri.parse(APPUrl.createReceipt);
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');

    if (apiKey == null || apiKey.isEmpty) {
      throw const HttpException("API key not found. Please restart the app.");
    }

    try {
      debugPrint(
          '📨 [InvoiceProvider] Sending receipt request to ${url.toString()}');
      debugPrint(
          '📨 [InvoiceProvider] Request body: ${json.encode(apiBodyData)}');
      final response = await http.post(
        url,
        body: json.encode(apiBodyData),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
          '📥 [InvoiceProvider] Response status: ${response.statusCode}');
      debugPrint('📥 [InvoiceProvider] Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create receipt: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating receipt: $e');
    }
  }

  List<String> getStatusOptions() {
    if (_allInvoices == null || _allInvoices!.isEmpty) {
      return ["All Status"];
    }

    final uniqueStatuses = _allInvoices!
        .map((invoice) => invoice.status)
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    uniqueStatuses.sort();
    return ["All Status", ...uniqueStatuses];
  }

  List<String> getReceiptStatusOptions() {
    if (_allReceipts == null || _allReceipts!.isEmpty) {
      return ["All Status"];
    }

    final uniqueStatuses = _allReceipts!
        .map((receipt) => receipt.receiptStatus)
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    uniqueStatuses.sort();
    return ["All Status", ...uniqueStatuses];
  }

  List<String> getPaymentMethodOptions() {
    if (_allReceipts == null || _allReceipts!.isEmpty) {
      return ["All Payment Methods"];
    }

    final uniqueMethods = _allReceipts!
        .map((receipt) => receipt.paymentMethod)
        .where((method) => method != null && method.isNotEmpty)
        .map((method) => method!)
        .toSet()
        .toList();

    uniqueMethods.sort();
    return ["All Payment Methods", ...uniqueMethods];
  }
}

bool _isDateAfterOrEqual(String invoiceDate, String compareDate) {
  try {
    // Parse dates in DD/MM/YYYY format
    List<String> invoiceParts = invoiceDate.split('/');
    List<String> compareParts = compareDate.split('/');

    DateTime invoiceDateTime = DateTime(
      int.parse(invoiceParts[2]), // year
      int.parse(invoiceParts[1]), // month
      int.parse(invoiceParts[0]), // day
    );

    DateTime compareDateTime = DateTime(
      int.parse(compareParts[2]), // year
      int.parse(compareParts[1]), // month
      int.parse(compareParts[0]), // day
    );

    return invoiceDateTime.isAfter(compareDateTime) ||
        invoiceDateTime.isAtSameMomentAs(compareDateTime);
  } catch (e) {
    debugPrint("Error parsing dates: $e");
    return false;
  }
}

bool _isDateBeforeOrEqual(String invoiceDate, String compareDate) {
  try {
    // Parse dates in DD/MM/YYYY format
    List<String> invoiceParts = invoiceDate.split('/');
    List<String> compareParts = compareDate.split('/');

    DateTime invoiceDateTime = DateTime(
      int.parse(invoiceParts[2]), // year
      int.parse(invoiceParts[1]), // month
      int.parse(invoiceParts[0]), // day
    );

    DateTime compareDateTime = DateTime(
      int.parse(compareParts[2]), // year
      int.parse(compareParts[1]), // month
      int.parse(compareParts[0]), // day
    );

    return invoiceDateTime.isBefore(compareDateTime) ||
        invoiceDateTime.isAtSameMomentAs(compareDateTime);
  } catch (e) {
    debugPrint("Error parsing dates: $e");
    return false;
  }
}
