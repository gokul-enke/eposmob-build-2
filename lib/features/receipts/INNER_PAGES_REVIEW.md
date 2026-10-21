# Receipt Create and Details review

Scope: architecture only, originally started from `mubashir-dev` at `798ba40c`, on `mubashir/receipt-inner-pages-architecture`. The PR branch was rebased onto `staging` to exclude the unrelated voucher-dashboard commit. No UI redesign, business-rule change or provider/API change.

## Review evidence

1. Compared the extracted Create build tree and Details content with the original source. They match after ignoring formatting, provably redundant nullable expressions, const/style lint cleanup and mounted checks. Payload mapping retains the original keys, values, number parsing and defaults.
2. Ran the same 16 form/repository/details tests against the extracted editor and a temporary copy of the original editor: both passed. Tests cover customer names, payment defaults, saved/draft totals, add/edit/remove, customer-change Cancel/Continue, invoice filtering and balance checks, request payloads, failed submission retry, missing authentication/customer, cancellation during lookup/submission and Details fallbacks.
3. A separate diagnostic comparison reproduced all four P2 issues below on both implementations. Both also produced the same 5.9px horizontal RenderFlex overflow at 600px width. These temporary diagnostic/baseline files were removed, rather than shipping tests that require broken behavior.
4. Focused analyzer passed. All 17 permanent inner-page tests passed, including the 740px-width form test. The broader receipt/invoice regression suite passed 89 tests.
5. On 2026-10-12, checked native desktop Receipt List, Create and existing Details. Using the app's virtual keyboard, created demo receipt `RCP1001900` for customer `testerenke`: one General Payment described as `qa`, amount `10.25`, method cash. Adding the row changed the total to `10.25`; submitting once returned to the list. Reopened Details and verified the same customer, amount, paid status, date and CASH method. This live check covers one General Payment flow; multi-row editing and Invoice Payment submission still require manual validation.
6. The live customer API for store 2 returned 221 records, with 191 populated names and 30 null names. The first dropdown entries use the existing `Unnamed customer` fallback for those null records; named customers appear farther down. The original and extracted selectors use the same lookup and fallback.

No new P0/P1/P2/P3 regression was identified in these checks. This is evidence about the exercised cases, not a guarantee for every backend response or interaction.

## Findings fixed during staging review

The four P2 issues this extraction reproduced were fixed on top of it, each with a regression test in `receipt_inner_pages_test.dart`:

| Severity | Trigger | Fix |
| --- | --- | --- |
| P2 | Press Submit twice while its first request is pending. | `_submitReceipt` ignores a second call until the first finishes. |
| P2 | Add two payments of 15 for an invoice whose balance is 20. | Add and Submit compare the running total for that invoice against its balance. |
| P2 | In Edit, clear the selected invoice (previously threw `StateError`). | The editor resets the invoice and balance amounts instead of looking up null. |
| P2 | In Edit, select an invoice with a different balance and Save. | `_saveItemEditor` also copies `balanceAmountController`. |

## Unchanged findings

| Severity | Trigger and result | Current location |
| --- | --- | --- |
| P3 | At 600px viewport width, the existing Create layout overflows horizontally by 5.9px. Original and extracted editors reproduce it. | `receipt_create_dialog.dart`, existing layout |

Additional existing validation boundaries: Submit does not require a saved row; amounts are not checked for positivity/finiteness and unparsable text maps to zero; a cleared/unavailable payment method maps to null. Missing authentication leaves lookup loading labels active, and a null payment-method response does not clear its loading label. A HTTP 200 body is treated as submission success without inspecting its business status. Whether the server rejects these payloads or prevents duplicates has not been verified. These rules were retained under the instruction not to change logic or UI.

## Manual checks

Hot restart before checking the extracted code.

1. Open Create Receipt. Confirm customer names, balance, payment method and date look unchanged.
2. Select a demo customer. Add General Payment: description `Mubashir receipt QA`, amount `10.25`. Confirm the saved total is `10.25`; typing a draft amount should not change it until Add.
3. Add another General Payment of `5.50`. Confirm total `15.75`. Edit the first to `12.25` (total `17.75`), then remove the second (total `12.25`).
4. Switch customer: Cancel must retain rows; Continue must clear rows and reset total. Cancel and reopen the main dialog to confirm a fresh form.
5. Select Invoice Payment for the chosen customer. Confirm the invoice number, amount and balance, then check that an amount above its balance is rejected when adding.
6. If submitting in the demo, use one valid saved payment and press Submit once. Confirm the receipt appears in the list. Open Details and check number, customer, company, amount, status, reference, payment date, method and invoice/general description. Close and reopen an existing receipt too.

The P3 layout overflow and the validation boundaries above are not resolved by this extraction.
