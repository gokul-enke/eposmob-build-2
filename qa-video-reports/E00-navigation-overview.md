# E00 — Navigation overview

Status: Needs follow-up

## Purpose

Exercise the visible desktop navigation, expandable menu groups, representative pages, and logout without creating or modifying business data.

## Coverage

- Home and Billing
- Dashboard
- Restaurant, Attender, and Kitchen Master
- Sales and its visible submenus
- Quotations, Category, Product, Purchase, and Reports
- Transactions and its visible submenus
- Party Accounts, Customers, Suppliers, Printer, Settings, and Logout

## Result

- Navigation taps completed for the visible menu entries.
- Dashboard rendered KPI/account sections after loading.
- Logout returned to the login screen and displayed a success message.
- No order, inventory, customer, payment, or configuration mutation was intentionally performed.

## Runtime error

One Flutter runtime error was captured while leaving the Invoice page:

```text
setState() or markNeedsBuild() called when widget tree was locked.
InvoiceProvider.resetFilters()
InvoiceListScreen._resetInvoiceFilters()
InvoiceListScreen.dispose()
```

Severity: P1 follow-up. Navigation still completed, but provider notification from `dispose()` is unsafe and should be fixed or verified after the next code change.

## Video evidence

- Sanitized video: `C:\Users\jim\.screencast-mcp\recordings\00-navigation-overview-sanitized.mp4`
- Duration: 174.67 seconds
- Resolution: 2560×1440
- Codec: H.264
- Audio: none
- Video metadata and final sampled frame verified.
- The unsanitized source is not for sharing because it includes account/UI notification content.

## Follow-up

1. Move invoice filter reset out of `InvoiceListScreen.dispose()` or defer it safely, then rerun E00/E17.
2. Recheck the clean-session runtime-error stream after the fix.

