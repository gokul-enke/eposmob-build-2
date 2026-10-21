part of '../pages/supplier_report_details_page.dart';

/// Print preparation and navigation are retained from the original View.
mixin SupplierReportDetailsPrint<T extends StatefulWidget> on State<T> {
  bool get initLoading;
  set initLoading(bool value);
  String get selectedSupplierName;
  List<SupplierTransaction> get filteredTransactions;
  TextEditingController get _fromDateController;
  TextEditingController get _toDateController;

  void _printReport() async {
    // Show loading indicator
    if (mounted) {
      showScaffold(
        context: context,
        message: 'supplier_transaction_report.preparing_supplier_report'.tr,
      );
    }

    // Show loading state
    setState(() {
      initLoading = true;
    });

    // Fetch supplier details
    String supplierName = selectedSupplierName;
    String supplierPhone = "";
    String supplierEmail = "";
    String supplierAddress = "";

    if (supplierName.isNotEmpty) {
      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        if (accessToken != null) {
          final supplierProvider =
              Provider.of<SupplierProvider>(context, listen: false);

          // Find supplier by name
          debugPrint("Attempting to fetch supplier details for: $supplierName");
          final supplier = supplierProvider.supplierList?.firstWhere(
            (s) => s.name == supplierName,
            orElse: () => Supplier(
              id: 0,
              name: '',
              email: '',
              phone: '',
              productCategories: '',
              address: '',
              balance: 0.0,
              paymentType: '',
              companyId: 0,
              currentBalance: 0.0,
              balanceStatus: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              userId: 0,
              transactions: [],
              purchases: [],
            ),
          );

          if (supplier != null && supplier.name.isNotEmpty) {
            supplierPhone = supplier.phone;
            supplierEmail = supplier.email;
            supplierAddress = supplier.address;

            debugPrint("Supplier details found:");
            debugPrint("  Name: $supplierName");
            debugPrint("  Phone: $supplierPhone");
            debugPrint("  Email: $supplierEmail");
            debugPrint("  Address: $supplierAddress");
          } else {
            debugPrint("Supplier not found in provider list");
          }
        } else {
          debugPrint("Access token is null, cannot fetch supplier details");
        }
      } catch (e, stackTrace) {
        debugPrint("Error fetching supplier details: $e");
        debugPrint("Stack trace: $stackTrace");
        // Continue with just the name if we can't fetch details
      }
    } else {
      debugPrint("Supplier name is empty, skipping supplier details fetch");
    }

    // Hide loading state
    setState(() {
      initLoading = false;
    });

    // Create a list of cart items from the filtered transactions
    List<SupplierTransaction> cartItems = filteredTransactions;

    // Calculate total amount
    double totalAmount = 0.0;
    for (var transaction in cartItems) {
      double amount = double.tryParse(transaction.amount) ?? 0.0;
      totalAmount += amount;
    }

    String formattedTotal = totalAmount.toStringAsFixed(2);

    // Navigate to print screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupplierTransactionReportPrint(
            cartItems: cartItems,
            formattedTotal: formattedTotal,
            savedTotal: formattedTotal,
            orderDate: DateTime.now().toIso8601String(),
            orderNumber: "SUPP-${DateTime.now().millisecondsSinceEpoch}",
            isFromLocalStorage: false,
            supplierName: supplierName,
            supplierPhone: supplierPhone,
            supplierEmail: supplierEmail,
            supplierAddress: supplierAddress,
            fromDate: _fromDateController.text,
            toDate: _toDateController.text,
          ),
        ),
      );
    }
  }
}
