# Implementation Report: Business Date Filter & Defensive Error Handling in Sales List

**Author**: Antigravity AI  
**Date**: July 27, 2026  
**Status**: Ready for Review

---

## 1. Executive Summary

This implementation adds a new **Business Date** filter to the Sales/Orders List page alongside the existing calendar **Date** filter. It enables POS operators to query transactions by the POS shift's operational business date (important for transactions occurring past midnight during an open shift). 

Additionally, the implementation resolves a backend edge case where querying with conflicting filters (i.e. different calendar date and business date) caused the API to return an HTTP 500 status code with a `"No Orders Found"` message, resulting in client-side crashes or generic error notifications. The client now intercepts this response and gracefully renders a standard empty list.

---

## 2. Component Details

### A. API Provider Layer (`sales_provider.dart`)
* **Path**: [sales_provider.dart](file:///c:/Users/Mubashir/eposmob/lib/providers/sales_provider.dart)
* **API Endpoint**: `GET .../api/v1/order/executive/list-orders`
* **Changes**:
  1. Extended the signature of `fetchOrders()` to accept an optional `String? businessDate` parameter.
  2. Mapped `businessDate` to the HTTP query parameter `'business_date'`.
  3. Added defensive response handling inside the HTTP error block to check for `statusCode == 500` with the response body `{"status": "failed", "message": "No Orders Found", "data": []}`. In this specific scenario, it clears the orders list (`_orders = []`), resets the page/pagination variables, notifies listeners, and returns gracefully instead of throwing an error.

### B. UI Screen Layer (`sales.dart`)
* **Path**: [sales.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/sales/sales.dart)
* **Changes**:
  1. Added state variables `DateTime? selectedBusinessDate` and `Key businessCalendarPickerKey = UniqueKey();` to handle the date selection state and allow widget key resets.
  2. Included the new `businessDate` formatted parameter (`yyyy-MM-dd`) in `searchOrders()`'s `orderProvider.fetchOrders()` API call.
  3. Updated `resetSearch()` to reset `selectedBusinessDate = null` and generate a new `businessCalendarPickerKey` key to clear the placeholder UI text back to "Select Date".
  4. Rendered a new `CalendarPickerTableCell` under a Column labeled **"Business Date"** inside the desktop layout's second row of filters next to the "Status" dropdown.

### C. Mobile Filter Layer (`mobile_filters.dart`)
* **Path**: [mobile_filters.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/sales/widgets/mobile_filters.dart)
* **Changes**:
  1. Extended the `MobileFilters` constructor and parameters to accept `selectedBusinessDate`, `businessCalendarPickerKey`, and `onBusinessDateSelected` callback.
  2. Added the "Business Date" calendar selector directly into both the narrow and wide mobile layouts.

---

## 3. Code Modifications (Diffs)

### 1. `lib/providers/sales_provider.dart`

```diff
@@ -191,6 +191,7 @@
     String? orderNumber,
     String? filterName,
     String? date,
+    String? businessDate,
     int? customerId,
     int? productId,
     String? filterStatus,
@@ -217,6 +217,7 @@
     if (orderNumber != null) queryParameters['number'] = orderNumber;
     if (filterName != null) queryParameters['filter_name'] = filterName;
     if (date != null) queryParameters['order_date'] = date;
+    if (businessDate != null) queryParameters['business_date'] = businessDate;
     if (customerId != null) {
       queryParameters['customer_id'] = customerId.toString();
     }
@@ -411,6 +411,24 @@
         debugPrint('=== HTTP ERROR ===');
         debugPrint('Status Code: ${response.statusCode}');
         debugPrint('Response Body: ${response.body}');
+        if (response.statusCode == 500 && response.body.isNotEmpty) {
+          try {
+            final jsonBody = json.decode(response.body);
+            if (jsonBody is Map &&
+                jsonBody['status'] == 'failed' &&
+                jsonBody['message'] == 'No Orders Found') {
+              _orders = [];
+              currentPage = 1;
+              totalPages = 1;
+              paginationFrom = 1;
+              notifyListeners();
+              debugPrint('=== DEFENSIVE HANDLING: Treated 500 "No Orders Found" as empty list ===');
+              return;
+            }
+          } catch (e) {
+            debugPrint('Failed to parse 500 error response: $e');
+          }
+        }
         throw Exception('Failed to load orders: HTTP ${response.statusCode}');
       }
```

### 2. `lib/screens/sales/sales.dart`

```diff
@@ -74,6 +74,8 @@
   GetStoreModelData? storeSelected;
   DateTime? selectedDate;
   Key calendarPickerKey = UniqueKey();
+  DateTime? selectedBusinessDate;
+  Key businessCalendarPickerKey = UniqueKey();
 
   bool isInitLoading = false;
   String orderNumber = "";
@@ -1131,6 +1131,8 @@
           'filterPhone': phoneController.text.trim(),
         if (selectedDate != null)
           'date': DateFormat('yyyy-MM-dd').format(selectedDate!),
+        if (selectedBusinessDate != null)
+          'businessDate': DateFormat('yyyy-MM-dd').format(selectedBusinessDate!),
         if (activeStoreId != null) 'filterStore': activeStoreId,
         if (selectedStatus != null && selectedStatus != 'all')
           'filterStatus': selectedStatus!.trim(), // Add status filter
@@ -1146,6 +1148,7 @@
         filterEmail: filters['filterEmail'],
         filterPhone: filters['filterPhone'],
         date: filters['date'],
+        businessDate: filters['businessDate'],
         filterStore: filters['filterStore'],
         filterStatus: filters['filterStatus'],
         page: int.tryParse(filters['page'] ?? '1') ?? 1,
@@ -1182,6 +1185,8 @@
       selectedStatus = null;
       selectedDate = null;
       calendarPickerKey = UniqueKey();
+      selectedBusinessDate = null;
+      businessCalendarPickerKey = UniqueKey();
     });
     searchOrders(1); // Trigger fresh search after reset
@@ -2431,6 +2436,14 @@
                               searchOrders(1);
                             },
                             onReset: resetSearch,
+                            selectedBusinessDate: selectedBusinessDate,
+                            businessCalendarPickerKey: businessCalendarPickerKey,
+                            onBusinessDateSelected: (DateTime date) {
+                              setState(() {
+                                selectedBusinessDate = date;
+                              });
+                              searchOrders(1);
+                            },
                           )
@@ -2748,6 +2761,45 @@
                                   ),
                                   const SizedBox(width: 15),
 
+                                  // Business Date
+                                  Expanded(
+                                    flex: 1,
+                                    child: Column(
+                                      crossAxisAlignment:
+                                          CrossAxisAlignment.start,
+                                      children: [
+                                        Padding(
+                                          padding: const EdgeInsets.all(8.0),
+                                          child: Text(
+                                            "Business Date",
+                                            style: buildCustomStyle(
+                                              FontWeightManager.regular,
+                                              FontSize.s14,
+                                              0.27,
+                                              Colors.black.withOpacity(0.6),
+                                            ),
+                                          ),
+                                        ),
+                                        BuildBoxShadowContainer(
+                                          circleRadius: 7,
+                                          height: 45,
+                                          child: Center(
+                                            child: CalendarPickerTableCell(
+                                              key: businessCalendarPickerKey,
+                                              onDateSelected: (DateTime date) {
+                                                setState(() {
+                                                  selectedBusinessDate = date;
+                                                });
+                                                searchOrders(1);
+                                              },
+                                            ),
+                                          ),
+                                        ),
+                                      ],
+                                    ),
+                                  ),
+                                  const SizedBox(width: 15),
+
                                   // Reset button
                                   Expanded(
                                     flex: 1,
```

### 3. `lib/screens/sales/widgets/mobile_filters.dart`

```diff
@@ -28,6 +28,9 @@
   final Function(String?) onStatusChanged;
   final Function(DateTime) onDateSelected;
   final VoidCallback onReset;
+  final DateTime? selectedBusinessDate;
+  final Key? businessCalendarPickerKey;
+  final Function(DateTime)? onBusinessDateSelected;
 
   const MobileFilters({
     super.key,
@@ -48,6 +51,9 @@
     required this.onStatusChanged,
     required this.onDateSelected,
     required this.onReset,
+    this.selectedBusinessDate,
+    this.businessCalendarPickerKey,
+    this.onBusinessDateSelected,
   });
@@ -208,6 +214,21 @@
                 ),
               ),
               const SizedBox(height: 12),
+              _buildFilterField(
+                label: "Business Date",
+                child: BuildBoxShadowContainer(
+                  circleRadius: 10,
+                  height: 45,
+                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
+                  child: Center(
+                    child: CalendarPickerTableCell(
+                      key: businessCalendarPickerKey ?? UniqueKey(),
+                      onDateSelected: onBusinessDateSelected ?? (date) {},
+                    ),
+                  ),
+                ),
+              ),
+              const SizedBox(height: 12),
               _buildTextFilter(
                 label: "Price",
                 hint: 'Price',
@@ -286,6 +307,30 @@
               ],
             ),
             const SizedBox(height: 12),
+            Row(
+              crossAxisAlignment: CrossAxisAlignment.start,
+              children: [
+                Expanded(
+                  child: _buildFilterField(
+                    label: "Business Date",
+                    child: BuildBoxShadowContainer(
+                      circleRadius: 10,
+                      height: 45,
+                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
+                      child: Center(
+                        child: CalendarPickerTableCell(
+                          key: businessCalendarPickerKey ?? UniqueKey(),
+                          onDateSelected: onBusinessDateSelected ?? (date) {},
+                        ),
+                      ),
+                    ),
+                  ),
+                ),
+                const SizedBox(width: 10),
+                const Expanded(child: SizedBox.shrink()),
+              ],
+            ),
+            const SizedBox(height: 12),
             _buildTextFilter(
               label: "Price",
               hint: 'Price',
```

---

## 4. Verification

1. **Compilation**: Ran `flutter clean`, `flutter pub get`, and successfully compiled/analyzed without syntax or configuration errors.
2. **Behavior Verification**: 
   * Confirmed that selecting **Date** only filters by `order_date` using format `yyyy-MM-dd`.
   * Confirmed that selecting **Business Date** only filters by `business_date` using format `yyyy-MM-dd`.
   * Confirmed that conflicting criteria (returning HTTP 500 `"No Orders Found"`) are caught by the defensive handler in the provider layer and correctly render the "No orders found" UI empty state instead of crashing.
