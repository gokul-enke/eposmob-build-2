# CLOUDPOS QA rerun report — 2026-08-02

## Outcome

The authorized testing-account rerun completed across the 11 requested QA episodes plus supplemental POST-form and refund/payment-reversal episodes. The Flutter test suite passes with 774 tests and no failures. The main client defects found during the rerun were fixed and rechecked in the running Windows app.

The recordings are valid H.264 MP4 files and were finalized cleanly, but the Windows compositor intermittently captured Chrome/WhatsApp instead of the CLOUDPOS window even when Marionette showed the correct app UI. Because some captures also contain private desktop or diagnostic data, all rerun videos remain local and unshared. No Cloudflare links were created.

## Code fixes included

- Removed provider notifications during widget disposal and build-phase initialization.
- Added mounted/lifecycle guards around billing, stock, report, and async form flows.
- Corrected partial-payment handling so an unpaid remainder is rejected unless credit is explicitly selected.
- Added variant-required stock validation and preserved public settings getters for testable overselling/multi-unit behavior.
- Fixed autocomplete, user-switcher, and kitchen layout assertions/overflows.
- Made customer POST forms use the shared `CustomerProvider`, the active store, and a post-mutation refresh. The created QA customer is now searchable in the live Customers page.
- Made quotation and sales-return response parsing tolerant of nested, flat, nullable, and alternate backend response shapes.
- Changed the sales-return detail modal to fetch the item endpoint and render a stable responsive table. The previously blank completed-return line now renders correctly.
- Hardened the sales-return item endpoint model against string IDs, boolean variants, alternate item keys, and nested product names.
- Removed active debug logging of full or partial access tokens; request diagnostics now report only whether a token is present.

## Automated verification

- `flutter test`: **774 passed, 0 failed** after the final security-log cleanup.
- Focused post-fix suite: **28 passed, 0 failed**.
- `git diff --check`: clean after the final edits.
- `flutter analyze --no-pub`: repository-wide lint command exits nonzero because the project currently reports 4,030 existing info/warning diagnostics. No analyzer compile error was reported; the full Flutter test build passed. The changed-file analysis reported 336 info/warning diagnostics and no compile error.

## Episode results

| Episode | Functional result | Authorized POST/mutation coverage | Recording result |
|---|---|---|---|
| 01 Login/store/sync/day-close | Passed for login, store bootstrap, sync/settings inspection, and day-close surface | No destructive close or real credential disclosure | Local only; diagnostic settings values and compositor contamination make it unshareable |
| 02 Basic sale/payment | Checkout and exact-cash validation passed; partial payment was correctly rejected | Cart/payment validation exercised; no unapproved real sale retained | Local only; sampled clean app frames were not sufficient to approve the whole file |
| 03 Pricing/variants/stock/quantity | Passed | Added stock for `QA-VIDEO-20260802-REPAINT`, quantity 3; verified stock list and pricing | Local only; early sample includes a desktop notification |
| 04 Customers/discounts/coupons/delivery | Passed after fix | Created/search-verified `QA POSTFIX CUSTOMER`; applied a safe flat discount in checkout preview; delivery address/charge preview verified; no delivery was dispatched | Local only; customer/contact and desktop contamination present |
| 05 Saved orders/returns/refunds/quotations | Quotation, return, and saved-order resume/print-route paths passed; refund/payment reversal is covered by Episode 13 | Created `QTN-00113` with known customer ID; completed a safe return for `ORD-003969`; return detail now shows `kitkat`, 1.0, SAR 2.00, Returned | Local only; final postfix file is contaminated by Chrome/WhatsApp |
| 06 Catalog/units/variants/barcodes | Passed | Created QA category/product, unit/pricing/stock data, and barcode `9902026080211`; barcode PDF generated | Local only; later frame includes T3/desktop context |
| 07 Purchases/suppliers/vouchers/expenses | Purchase-order, supplier-voucher, and expense POST paths passed | Created/received a purchase order with voucher `QA-VIDEO-PO2-20260802`, invoice ref `QA-VIDEO-INV2-20260802`, quantity 3, payment SAR 6.50; standalone supplier voucher and expense details were also verified | Local only; app frames from the PO flow are usable for private review |
| 08 Invoices/receipts/reports/transactions | Passed for invoice, receipt, and report surfaces | Created receipt `RCP1001258`, amount SAR 1.00, ref `QA-VIDEO-RECEIPT-20260802`; verified detail and multiple reports | Local only; raw recording has possible desktop contamination |
| 09 Restaurant/attender/kitchen | Passed | Updated kitchen items on `ORD-003352` to READY and refreshed orders; fixed both responsive overflow paths | Local only; sampled frames contain old desktop/red-marker context |
| 10 Settings/printers/offline/realtime sync | Settings and printer surfaces passed; offline mode was returned to live internet status | Test Print control exercised; Offline Data inspected without clearing; Offline Mode toggled off and verified as “Uses live internet status” | Local only; native capture did not reliably target CLOUDPOS |
| 11 Negative/permission/responsive/keyboard/accessibility | Functional checks passed, including required-field validation and responsive kitchen fixes | No unsafe mutation | Local only; recording contains desktop/browser content |
| 12 Supplemental POST forms/saved-order route | Passed for saved-order save/resume/print route, customer voucher, supplier voucher, and expense | Saved a disposable order and resumed it; opened printer-selection route without printing hardware; created customer voucher `1000489`, supplier voucher `SVCH-1000307`, and expense `EXP00106`; verified each list/detail result | Local only; all sampled frames show unrelated desktop/browser content and must not be shared |
| 13 Refund/payment reversal | Passed live through Marionette; media retained privately with a native repaint limitation | Cancelled confirmed order `ORD-003968` using CASH and SAR 2.00 refund; order detail verified `CANCELLED` and `REFUNDED` | Local only; MP4 is valid and CLOUDPOS-targeted, but native pixels stayed on an earlier finalize modal |

## Mutation log

Only synthetic or already-designated QA data was used. The report intentionally omits login credentials, tenant keys, phone numbers, email addresses, and diagnostic tokens.

- Product: `QA-VIDEO-20260802-REPAINT`.
- Category: `QA-VIDEO-20260802-CATEGORY-REPAINT`.
- Barcode: `9902026080211`.
- Stock: QA product stock quantity 3; verified against the resulting stock rows.
- Customers: `QA-VIDEO-20260802-CUSTOMER2 TEST` and `QA POSTFIX CUSTOMER`.
- Quotation: `QTN-00113` created with a known-ID customer and verified in list/detail. Earlier `QTN-00112` used a null-ID “No Name” fixture and displayed no customer; this is a fixture/data-integrity case, not a generic known-customer failure.
- Sales return: completed return for `ORD-003969`, reason label `QA-VIDEO-RETURN-20260802-RERUN`.
- Purchase: voucher `QA-VIDEO-PO2-20260802`, invoice reference `QA-VIDEO-INV2-20260802`, received quantity 3, payment SAR 6.50.
- Saved order: disposable order `ORD-1` saved, opened through the printer-selection route, and resumed in the billing cart; no physical print was sent.
- Customer voucher: `1000489`, type `other`, customer Test Default, paid SAR 1.00; list/detail verified.
- Supplier voucher: `SVCH-1000307`, type `other`, supplier Supplier 1FUNZCART, paid SAR 1.00; list/detail verified.
- Expense: `EXP00106`, synthetic description, SAR 1.00, Transportation category, Indirect Expense Account debit, Cash Account credit, status `SUCC`; list/detail verified.
- Receipt: `RCP1001258`, reference `QA-VIDEO-RECEIPT-20260802`.
- Kitchen: order `ORD-003352` item status updates to READY.
- Refund: confirmed order `ORD-003968` cancelled with CASH refund SAR 2.00; detail verified `CANCELLED` and `REFUNDED`.

## Remaining defects and limitations

1. **External/P1 privacy blocker — Screencast MCP window targeting on this Windows session.** `window:CLOUDPOS` sometimes resolves the correct title but the sampled pixels are Chrome/WhatsApp or the desktop. Raw files must not be uploaded. The app itself was inspected with Marionette screenshots, which showed the expected CLOUDPOS UI.
2. **Resolved — refund/payment-reversal flow.** Episode 13 cancelled confirmed order `ORD-003968` with CASH and SAR 2.00 refund; the order detail verified `CANCELLED` and `REFUNDED`. A clean visual recording remains blocked by the native capture repaint issue described above.
3. **P2 hardware limitation — printer test.** The Test Print control was exercised, but no physical printer was available to verify paper output.
4. **P2 fixture integrity — null customer quotation.** A quotation created from a “No Name” selection with no customer ID remains blank by design/backend data. A known-ID customer quotation (`QTN-00113`) now persists and renders correctly.

## Runtime-error summary

- No new Flutter runtime error was observed after the final source fixes.
- The earlier InvoiceProvider disposal notification, report build-phase notification, sales-executive lifecycle error, and kitchen overflow were fixed and covered by the final test run/live rerun.
- A few driver-only Marionette messages occurred while searching/scrolling (`Widget not found after scroll attempts` and `No element is currently focused`). They did not correspond to Flutter framework errors and did not stop the tested flows.

## Local video paths

All paths below are private raw captures. They are listed for local QA review only and are not approved for public sharing:

```text
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\01-login-store-sync-day-close-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\02-basic-sale-payment-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\03-product-stock-pricing-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\04-customers-discounts-coupons-delivery-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\04-customers-postfix.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\05-saved-orders-returns-refunds-quotations-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\05-quotations-return-postfix.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802b\06-categories-products-units-variants-barcodes-fixed.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\07-purchases-suppliers-vouchers-expenses-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\08-invoices-receipts-reports-transactions-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\09-restaurant-attender-kitchen-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\10-settings-printers-offline-sync-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\11-negative-permission-responsive-accessibility-fixed-screen.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\12-remaining-post-forms-final.mp4
C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\13-refund-payment-reversal.mp4
```

Metadata verified for the current postfix recording: 1,292.933 seconds, 1920×1080, H.264, approximately 14.098 fps, no audio, 47,348,315 bytes. It is not shareable because its sampled frames show Chrome/WhatsApp.
Metadata verified for supplemental episode 12: 980.8 seconds, 1920×1080, H.264, approximately 14.778 fps, no audio, 15,502,330 bytes. All four sampled frames show unrelated desktop/browser content; the raw file is private and has no Cloudflare link.

Metadata verified for episode 13: 194.533 seconds, 2060×1192, H.264, approximately 6.297 fps, no audio, 942,474 bytes, gracefully finalized. The live Marionette tree showed the final refund detail, but sampled native window pixels remained on the earlier finalize modal; the file is private functional evidence and is not approved as a final-state visual recording.

## Recommended follow-up

- Keep the refund/payment-reversal result covered by Episode 13 and add a clean completed-sale fixture when the native capture compositor is reliable.
- Re-run the 11 episodes with a clean Windows capture target or an isolated VM/virtual display, sample every final file, redact profile areas, then publish only sanitized copies through a temporary allow-listed Cloudflare folder.
- Add backend/API fixtures for null customer IDs and alternate return-item response shapes to prevent regressions.
- Treat repository-wide analyzer cleanup as a separate maintenance task; it is not required to validate this rerun because the full test suite is green.
