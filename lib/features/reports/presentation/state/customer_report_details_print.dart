part of '../pages/customer_report_details_page.dart';

/// Existing details behavior, separated without changing its implementation.
mixin CustomerReportDetailsPrint<T extends StatefulWidget>
    on State<T>, CustomerReportDetailsState<T> {
  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: 'customer_transaction_report.preparing_report'.tr,
      );
    }

    // Show loading state
    setState(() {
      initLoading = true;
    });

    // Fetch customer details
    String customerName = _customerController.text;
    String customerPhone = "";
    String customerEmail = "";
    String customerAddress = "";

    if (customerName.isNotEmpty) {
      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          // Try to find customer by name
          debugPrint("Attempting to fetch customer details for: $customerName");
          final customerResponse =
              await CustomerRepository().findByName(accessToken, customerName);
          debugPrint("Customer API response: $customerResponse");

          if (customerResponse['status'] == 'success' &&
              customerResponse['data'] != null &&
              customerResponse['data'].isNotEmpty) {
            // Get the first matching customer
            final customerData = customerResponse['data'][0];
            debugPrint("Raw customer data received: $customerData");
            final customer = CustomerListModelData.fromJson(customerData);

            customerPhone = customer.phone ?? "";
            customerEmail = customer.email ?? "";

            // Debug individual address components
            debugPrint("Address components:");
            debugPrint("  address: ${customer.address}");
            debugPrint("  city: ${customer.city}");
            debugPrint("  state: ${customer.state}");
            debugPrint("  pincode: ${customer.pincode}");
            debugPrint("  country: ${customer.country}");

            // Check if all address components are null
            if (customer.address == null &&
                customer.city == null &&
                customer.state == null &&
                customer.pincode == null &&
                customer.country == null) {
              debugPrint(
                  "WARNING: All address components are NULL for this customer");
            }

            // Build complete address
            List<String> addressParts = [];
            if (customer.address != null && customer.address!.isNotEmpty) {
              addressParts.add(customer.address!);
            }
            if (customer.city != null && customer.city!.isNotEmpty) {
              addressParts.add(customer.city!);
            }
            if (customer.state != null && customer.state!.isNotEmpty) {
              addressParts.add(customer.state!);
            }
            if (customer.pincode != null && customer.pincode!.isNotEmpty) {
              addressParts.add(customer.pincode!);
            }
            if (customer.country != null && customer.country!.isNotEmpty) {
              addressParts.add(customer.country!);
            }

            customerAddress = addressParts.join(", ");
            debugPrint("Final constructed address: '$customerAddress'");
            debugPrint("Is final address empty? ${customerAddress.isEmpty}");
          } else {
            debugPrint("Customer API returned no data or error status");
            if (customerResponse['status'] != 'success') {
              debugPrint("Customer API error: ${customerResponse['message']}");
            }
            if (customerResponse['data'] == null ||
                customerResponse['data'].isEmpty) {
              debugPrint("Customer API returned empty data array");
            }
          }
        } else {
          debugPrint("Access token is null, cannot fetch customer details");
        }
      } catch (e, stackTrace) {
        debugPrint("Error fetching customer details: $e");
        debugPrint("Stack trace: $stackTrace");
        // Continue with just the name if we can't fetch details
      }
    } else {
      debugPrint("Customer name is empty, skipping customer details fetch");
    }

    // Hide loading state
    setState(() {
      initLoading = false;
    });

    // Create a list of cart items from the filtered transactions
    List<ListTransaction> cartItems = filteredTransactions ?? [];

    // Calculate totals
    double totalCredit = 0.0;
    double totalDebit = 0.0;

    for (var transaction in filteredTransactions ?? []) {
      double amount = double.tryParse(transaction.amount ?? "0.00") ?? 0.0;
      String type = transaction.type ?? "";

      if (type.toLowerCase() == 'credit') {
        totalCredit += amount;
      } else if (type.toLowerCase() == 'debit') {
        totalDebit += amount;
      }
    }

    // Calculate total amount (for backwards compatibility)
    double totalAmount = totalCredit - totalDebit;

    // Calculate saved amount (for this report, we'll set it to 0)
    double savedAmount = 0.0;

    // Get current date and time for the report
    String orderDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateHelper.now());
    String orderNumber =
        "TXN-REPORT-${DateHelper.now().millisecondsSinceEpoch}";

    // Get date range values
    String? fromDate =
        _fromDateController.text.isNotEmpty ? _fromDateController.text : null;
    String? toDate =
        _toDateController.text.isNotEmpty ? _toDateController.text : null;

    // Navigate to the print page with the transaction data
    debugPrint("Customer data being passed to print:");
    debugPrint("  Name: '$customerName'");
    debugPrint("  Phone: '$customerPhone'");
    debugPrint("  Email: '$customerEmail'");
    debugPrint("  Address: '$customerAddress'");
    debugPrint("  From Date: '$fromDate'");
    debugPrint("  To Date: '$toDate'");

    Get.to(() => TransactionReportPrintPage(
          cartItems: cartItems,
          formattedTotal: totalAmount.toStringAsFixed(2),
          savedTotal: savedAmount.toStringAsFixed(2),
          orderDate: orderDate,
          orderNumber: orderNumber,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          customerAddress: customerAddress,
          fromDate: fromDate,
          toDate: toDate,
          isFromLocalStorage: false,
        ));

    // Show a message that the print process has started
    if (mounted) {
      AppToast.info(
          context, 'customer_transaction_report.preparing_report_printing'.tr);
    }
  }
}
