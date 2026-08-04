# E18 — Reports

Status: Needs follow-up

## Scope

Read-only coverage of the Reports submenu: My Sales Report, Sales Executive Reports, Customer Transactions Report, Supplier Transactions Report, Stock Report, and Non-Stock Report. Each screen was inspected through its visible filters and report layout without exporting, editing, or posting data.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\18-reports-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 98.5 seconds
- Sanitization: profile/sidebar region and the main report region were redacted before sharing
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E18-reports-approved\`

## Observations

- Reports submenu exposes sales, customer, supplier, stock, and non-stock report entry points.
- My Sales and transaction reports expose date/customer filters and reset controls.
- Stock report exposes product and stock-level filters.
- Report tables expose summary columns and action/layout regions.
- No export or financial mutation was attempted.

## Defect

Opening Supplier Transactions Report reproduced a P1 Flutter stability error: `SupplierProvider.fetchSuppliers()` calls `notifyListeners()` during the build phase from `_SupplierTransactionReportScreenState.initState()` / `loadInitData()`. The report still rendered, but the framework assertion should be fixed and re-tested across report routes.

## Edge case / blocker

Date filtering, reset behavior, export/print, and report reconciliation remain unverified because the visible data is not confirmed as disposable QA data and no export was authorized.

## Runtime errors

- P1: SupplierProvider `setState() or markNeedsBuild() called during build` on Supplier Transactions Report.
- No other new runtime error was isolated in this episode.
