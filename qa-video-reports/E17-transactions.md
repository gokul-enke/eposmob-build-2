# E17 — Transactions

Status: Needs follow-up

## Scope

Read-only coverage of the Transactions submenu: Invoice List, Receipts, Customer Voucher, and Supplier Voucher (Purchase Entry). The recording inspects list filters, create entry points, row summaries, and pagination without opening, creating, editing, printing, or posting a financial record.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\17-transactions-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 61.6 seconds
- Sanitization: profile/sidebar region and the main data region were redacted before sharing
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E17-transactions-approved\`

## Observations

- Invoice List exposes filters and a create-invoice entry point.
- Receipts exposes filters and a create-receipt entry point.
- Customer Voucher and Supplier Voucher expose list views with existing-record summaries.
- All four list surfaces expose pagination or list navigation affordances.
- No mutation was attempted because the current data is not confirmed as disposable QA data.

## Edge case / blocker

The safe edge case was a read-only inspection of populated lists and their filter/create controls. Create, edit, print, post, void, and reconciliation paths remain unverified until an authorized disposable fixture and explicit mutation approval are available.

## Runtime errors

The Invoice List route reproduced the known Flutter error: `InvoiceProvider.resetFilters()` notifies listeners from `_InvoiceListScreenState.dispose()` while the widget tree is locked. This is a P1 stability defect and is tracked in the index.

## Follow-up

Provide a disposable QA invoice/receipt/voucher fixture and mutation authorization, then verify create/edit/post/void/print behavior, duplicate submission guards, filtering, pagination, and reconciliation in the relevant reports.
