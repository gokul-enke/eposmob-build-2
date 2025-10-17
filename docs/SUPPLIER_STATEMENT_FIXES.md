# Supplier Statement Configuration - Issues Fixed

## Overview
This document outlines the issues found in your Supplier Statement implementation and the fixes applied.

---

## ❌ Issues Found

### 1. **ResolvedLabels Field Mismatch**
**Problem:** Your API returns `"item"` in resolved_labels, but your model was looking for `"item_name"`.

**API Response:**
```json
"resolved_labels": {
  "sl_number": "SL",
  "date": "Date",
  "item": "Item",        // ← API sends "item"
  "debit": "Debit",
  "credit": "Credit",
  "status": "Status"
}
```

**Old Model Code:**
```dart
itemName: json["item_name"],  // ← Was looking for "item_name"
```

**Impact:** The `item` label would always be `null` for Supplier Statement.

---

### 2. **Standard PDF Ignoring Display Configuration for Totals**
**Problem:** The `_buildCartTotalRow` method in `supplier_transaction_report_print_standard.dart` was always showing Total Credit, Total Debit, and Balance without checking the display configuration visibility flags.

**Old Code:**
```dart
// ❌ ALWAYS shows these - doesn't check displayConfig
pw.Text('Total Credit: ', ...),
pw.Text('Total Debit: ', ...),
pw.Text('Balance: ', ...),
```

**Comparison with Thermal Printer:**
```dart
// ✅ Thermal printer was correctly checking visibility
if (displayConfig?['showTotalCredit']?.visible == true) {
  bytes += generator.text('Total Credit: Rs. ${totalCredit.toStringAsFixed(2)}', ...);
}
```

**Impact:** Users couldn't hide these fields even if they set them to invisible in the API.

---

### 3. **Hardcoded Column Labels**
**Problem:** Both thermal and standard printers were hardcoding table header labels instead of using the `resolved_labels` from the API.

**Old Code:**
```dart
// Hardcoded labels
tableHeaders.add(pw.Text('SL', style: headerStyle));
tableHeaders.add(pw.Text('Date', style: headerStyle));
tableHeaders.add(pw.Text('Debit', style: headerStyle));
```

**Impact:** Users couldn't customize column names via the API (e.g., change "SL" to "No." or "Date" to "Transaction Date").

---

## ✅ Fixes Applied

### Fix 1: Added Support for "item" Field in ResolvedLabels
**File:** `lib/models/document_configurations.dart`

**Changes:**
1. Added `final String? item;` field to `ResolvedLabels` class
2. Added parsing: `item: json["item"]`
3. Added to constructor and `toJson()` method

**Code:**
```dart
class ResolvedLabels {
  // ... existing fields ...
  
  // Supplier Statement specific fields (aliased from 'item' in API)
  final String? item;

  factory ResolvedLabels.fromJson(Map<String, dynamic> json) => ResolvedLabels(
    // ... existing fields ...
    item: json["item"], // Supplier Statement uses 'item' instead of 'item_name'
  );
}
```

---

### Fix 2: Standard PDF Now Respects Display Configuration
**File:** `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print_standard.dart`

**Changes:**
Refactored `_buildCartTotalRow` to check visibility flags before showing each total:

```dart
// ✅ Now checks visibility flags
if (displayConfig?['showTotalCredit']?.visible == true) {
  summaryItems.add(/* Total Credit widget */);
}

if (displayConfig?['showTotalDebit']?.visible == true) {
  summaryItems.add(/* Total Debit widget */);
}

if (displayConfig?['showBalance']?.visible == true) {
  summaryItems.add(/* Balance widget */);
}

// Only show the container if at least one summary item is visible
if (summaryItems.isEmpty) {
  return pw.SizedBox.shrink();
}
```

**Benefit:** Now consistent with thermal printer behavior and respects API configuration.

---

### Fix 3: Using Resolved Labels from API
**Files:** 
- `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print_thermal.dart`
- `lib/screens/reports/supplier_transaction_report/supplier_transaction_report_print_standard.dart`

**Changes:**
1. Added `_getLabel()` helper method to both printers:

```dart
String _getLabel(DocumentConfig? config, String field, String fallback) {
  final resolvedLabels = config?.resolvedLabels;
  if (resolvedLabels == null) return fallback;
  
  switch (field) {
    case 'sl_number':
      return resolvedLabels.slNumber ?? fallback;
    case 'date':
      return resolvedLabels.date ?? fallback;
    case 'item':
      return resolvedLabels.item ?? fallback;
    case 'debit':
      return resolvedLabels.debit ?? fallback;
    case 'credit':
      return resolvedLabels.credit ?? fallback;
    case 'status':
      return resolvedLabels.status ?? fallback;
    default:
      return fallback;
  }
}
```

2. Updated table headers to use resolved labels:

```dart
// ✅ Now uses API labels with fallback
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'sl_number', 'SL'), style: headerStyle));
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'date', 'Date'), style: headerStyle));
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'item', 'Type'), style: headerStyle));
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'debit', 'Debit'), style: headerStyle));
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'credit', 'Credit'), style: headerStyle));
tableHeaders.add(pw.Text(_getLabel(billDocumentConfig, 'status', 'Status'), style: headerStyle));
```

**Benefit:** Column names are now customizable via the API while maintaining sensible defaults.

---

## 📊 Summary of Changes

| Issue | Severity | Files Changed | Status |
|-------|----------|---------------|--------|
| Missing "item" field in ResolvedLabels | High | `document_configurations.dart` | ✅ Fixed |
| Standard PDF ignoring visibility flags | Medium | `supplier_transaction_report_print_standard.dart` | ✅ Fixed |
| Hardcoded column labels | Low | Both print files | ✅ Fixed |

---

## ✅ What's Working Correctly

Your implementation already had these aspects correct:

1. **Model Structure** - `DocumentConfig` correctly parses the API response
2. **Provider Loading** - `DocumentConfigProvider` correctly fetches and stores configurations
3. **Config Retrieval** - Print screens correctly load config with `getDocumentConfig("Supplier Statement")`
4. **Thermal Printer Visibility Checks** - Already properly checking display configuration flags
5. **Fallback Configuration** - Both printers have fallback configs when API data is missing

---

## 🧪 Testing Recommendations

After these fixes, test the following scenarios:

### Test 1: Custom Labels
1. Update your API to return custom labels:
```json
"resolved_labels": {
  "sl_number": "No.",
  "date": "Transaction Date",
  "item": "Description",
  "debit": "Dr",
  "credit": "Cr",
  "status": "Payment Status"
}
```
2. Generate a supplier statement
3. Verify the custom labels appear in the print output

### Test 2: Hide Totals
1. Update display configuration to hide balance:
```json
"display_configuration": {
  "showTotalCredit": {"visible": true, "value": null},
  "showTotalDebit": {"visible": true, "value": null},
  "showBalance": {"visible": false, "value": null}
}
```
2. Generate a PDF supplier statement
3. Verify balance is not shown (but credit/debit totals are)

### Test 3: Hide All Totals
1. Set all totals to invisible:
```json
"showTotalCredit": {"visible": false, "value": null},
"showTotalDebit": {"visible": false, "value": null},
"showBalance": {"visible": false, "value": null}
```
2. Generate a PDF supplier statement
3. Verify the entire totals section is hidden

---

## 📝 Notes

- All changes maintain backward compatibility with fallback values
- The thermal printer was already implemented correctly for visibility checks
- Standard printer is now consistent with thermal printer behavior
- Custom labels work with both thermal (80mm/58mm) and standard (A4/A5) formats
