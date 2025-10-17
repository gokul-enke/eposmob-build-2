# Transaction Report Print - Debug Guide

## Overview
Comprehensive debug logging has been added to track the entire flow from clicking print to generating the report.

## Debug Locations

### 1. Customer Transactions Widget (`customer_transactions_widget.dart`)

**When**: Triggered when user clicks the print button in Customer Profile > Transactions

**Debug Output Includes**:
```
===== CUSTOMER TRANSACTIONS WIDGET - PRINT REPORT DEBUG =====
Starting print report generation...
Total transactions: X
Filtered transactions: Y

--- Customer Details ---
Customer Name: 'John Doe'
Customer Phone: '9876543210'
Customer Email: 'john@example.com'
Customer Address: 'Street, City, State, Pincode, Country'

--- Converting Transactions to Map Format ---
Transaction 0:
  - ID: 316
  - Order ID: 149
  - Order Number: 'EPORD-000081'
  - Date: 2025-10-10
  - Type: Debit
  - Transaction Type: Invoice
  - Amount: 454.000
  - Status: SUCC

--- Calculating Totals ---
Total Credit: 3000.00
Total Debit: 5250.00
Balance: 2250.00

--- Date Range ---
From Date: 2025-10-01
To Date: 2025-10-13

--- Navigating to Print Page ---
Cart Items Count: 2
Total Amount: 2250.00
Order Number: TXN-REPORT-1728812345678
===== END CUSTOMER TRANSACTIONS WIDGET DEBUG =====
```

### 2. Transaction Report Print Page (`transaction_report_print.dart`)

**When**: When the print page loads and document configuration is being retrieved

**Debug Output Includes**:
```
===== LOADING DOCUMENT CONFIGURATIONS =====
Loading document configurations from provider...
✅ SUCCESS: Customer Statement document configuration loaded from provider
Document Config ID: 13
Document Config Type: Customer Statement
Has Display Config: true

📋 DISPLAY CONFIGURATION OPTIONS:
Total options: 14
Available keys: [showHeader, showSubheader, showFooter, ...]

  • showHeader: visible=true, value=null
  • showSubheader: visible=true, value=null
  • showFooter: visible=true, value=null
  • showTax: visible=false, value=null
  • showStatus: visible=false, value=null
  • showOrderNumber: visible=true, value=null
===== END LOADING DOCUMENT CONFIGURATIONS =====

===== HANDLE PRINTING =====
Selected Paper Size: A4
Customer Care Number: +1234567890
Customer Care Email: support@example.com
✅ Document configuration is available
Routing to PDF printer...
===== END HANDLE PRINTING =====
```

### 3. Thermal Printer (`transaction_report_print_thermal.dart`)

**Existing Debug Output**:
- Transaction report items building
- Customer details
- Column width calculations
- Date formatting
- Running balance calculations

### 4. PDF Printer (`transaction_report_print_standard.dart`)

**Existing Debug Output**:
- PDF generation steps
- Document configuration validation
- Customer details rendering
- Table building

## How to Use Debug Logs

### 1. **Run in Debug Mode**
```bash
flutter run
```

### 2. **View Console Output**
In VS Code:
- Open **Debug Console** (Ctrl+Shift+Y)
- Or view **Terminal** output

### 3. **Filter Debug Output**
Search for specific sections:
- `CUSTOMER TRANSACTIONS WIDGET` - Print button click
- `LOADING DOCUMENT CONFIGURATIONS` - Config loading
- `HANDLE PRINTING` - Print routing
- `BUILD TRANSACTION REPORT ITEMS` - Thermal printing
- `PDF GENERATION DEBUG` - PDF printing

## Common Issues & Debug Checks

### Issue 1: Order Number Not Showing
**Check Debug For**:
```
Transaction 0:
  - Order Number: 'EPORD-000081'  ✅ Should show actual order number
```
**If it shows**: `Order Number: 'null'` or `Order Number: 'N/A'`
- The API is not returning order_number field
- Or the model parsing is incorrect

### Issue 2: Tax/Status Column Still Showing
**Check Debug For**:
```
📋 DISPLAY CONFIGURATION OPTIONS:
  • showTax: visible=false, value=null  ✅ Should be false
  • showStatus: visible=false, value=null  ✅ Should be false
```
**If visible=true**:
- Your API response has them enabled
- Update the document configuration via admin panel

### Issue 3: Customer Details Not Showing
**Check Debug For**:
```
--- Customer Details ---
Customer Name: ''  ❌ Empty
Customer Phone: ''  ❌ Empty
```
**Solution**: Ensure customer data is properly loaded in the customer provider

### Issue 4: Configuration Not Loading
**Check Debug For**:
```
⚠️ WARNING: Customer Statement document configuration not found in provider
🔄 Fetching document configurations from API...
```
**This means**: The configuration needs to be fetched from API first
- Ensure you're logged in
- Check network connectivity
- Verify API endpoint is accessible

## Expected Flow

**Successful Print Flow**:
1. ✅ User clicks Print button
2. ✅ Customer data collected and logged
3. ✅ Transactions converted to Map format
4. ✅ Totals calculated correctly
5. ✅ Navigate to Print Page
6. ✅ Document configuration loaded
7. ✅ Display options validated
8. ✅ Print method selected (Thermal/PDF)
9. ✅ Report generated successfully

## Troubleshooting Steps

1. **Clear App Data** (if configuration seems cached):
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Force Refresh Configuration**:
   - Log out and log back in
   - This will reload document configurations

3. **Check API Response**:
   - Look for the section showing order_number in transaction logs
   - Verify it matches your API response format

4. **Verify Model Parsing**:
   - Check that `orderNumber` field is being set correctly
   - Debug output should show the actual value, not null

## Debug Output Example (Full Flow)

```
===== CUSTOMER TRANSACTIONS WIDGET - PRINT REPORT DEBUG =====
Starting print report generation...
Total transactions: 5
Filtered transactions: 2

--- Customer Details ---
Customer Name: 'Ragi raj'
Customer Phone: '9878765410'
Customer Email: 'null'
Customer Address: ''

--- Converting Transactions to Map Format ---
Transaction 0:
  - ID: 316
  - Order ID: 149
  - Order Number: 'EPORD-000081'
  - Date: 2025-10-10
  - Type: Debit
  - Transaction Type: Invoice
  - Amount: 454.000
  - Status: SUCC
Transaction 1:
  - ID: 317
  - Order ID: 149
  - Order Number: 'EPORD-000081'
  - Date: 2025-10-10
  - Type: Credit
  - Transaction Type: Receipt
  - Amount: 454.000
  - Status: SUCC

--- Calculating Totals ---
Total Credit: 454.00
Total Debit: 454.00
Balance: 0.00

--- Date Range ---
From Date: Not set
To Date: Not set

--- Navigating to Print Page ---
Cart Items Count: 2
Total Amount: 0.00
Order Number: TXN-REPORT-1728812345678
===== END CUSTOMER TRANSACTIONS WIDGET DEBUG =====

===== LOADING DOCUMENT CONFIGURATIONS =====
Loading document configurations from provider...
✅ SUCCESS: Customer Statement document configuration loaded from provider
Document Config ID: 13
Document Config Type: Customer Statement
Has Display Config: true

📋 DISPLAY CONFIGURATION OPTIONS:
Total options: 14
Available keys: [showHeader, showSubheader, showFooter, showDates, showCustomerName, showCustomerEmail, showCustomerPhone, showCustomerAddress, showTotalCredit, showTotalDebit, showBalance, showOrderNumber, showStatus, showTax]

  • showHeader: visible=true, value=null
  • showSubheader: visible=true, value=null
  • showFooter: visible=true, value=null
  • showTax: visible=false, value=null
  • showStatus: visible=false, value=null
  • showOrderNumber: visible=true, value=null
===== END LOADING DOCUMENT CONFIGURATIONS =====

===== HANDLE PRINTING =====
Selected Paper Size: A4
Customer Care Number: +1234567890
Customer Care Email: support@eposenke.com
✅ Document configuration is available
Routing to PDF printer...
===== END HANDLE PRINTING =====

===== PDF GENERATION DEBUG INFO =====
Customer data received:
  Name: Ragi raj
  Phone: 9878765410
  Email: null
  Address: 
===== END PDF GENERATION DEBUG INFO =====
```

## Summary

With these debug statements, you can now:
- ✅ Track the complete print flow
- ✅ Verify order numbers are correctly mapped
- ✅ Check document configuration loading
- ✅ Validate display options (showTax, showStatus)
- ✅ Monitor customer data flow
- ✅ Debug transaction conversion
- ✅ Verify totals calculation

**Next Steps**: Run the app, click Print on a customer transaction, and review the console output!
