# Remaining print work

Based on verification completed on 29 September 2026 on
`integrate/b2b-plus-gokul-dev`. These are remaining work items and verification
gates, not a claim that the entire app or every API path is correct.

The rendered matrix passed: 4,980 PDF switch variants and 14,365 thermal
variants across sales, returns, combined prints and all five language cases.
Client fixes listed in the [final report](receipt-verification-final-2026-09-29.md)
were retested. Backend code was not changed, and physical printer delivery was
not verified.

The subsequently reported mixed-script caption/value rendering bug has a
separate [fix and verification report](receipt-mixed-script-rendering-fix-2026-09-29.md).
The earlier matrix above did not detect that visual issue.

| Work item | Confirmed gap / limitation | Next action | Acceptance check |
| --- | --- | --- | --- |
| Bill / Bill A4 bank captions | Saved bank heading, bank name, account holder, account number, IBAN and SWIFT captions are missing from the captured API display options for records 1102 / 802. | Investigate the admin-save to API-response mapping and ensure typed captions reach the client. The precise backend cause has not been established in this repository. | Distinct configured English and Arabic markers survive the API response and appear in PDF/thermal output. Bank/account values still come from bank data, independently of the labels. |
| Bilingual configured text | Captures omit some configured English header/subheader/footer text, combined return titles and Return Bill metadata captions. | Correct the missing configuration text in the response. Distinguish typed English from generic resolved defaults; verify the response contract before changing client handling. | Both-filled, English-cleared and selected-English-table cases print exactly the supplied captions. Cleared English fields do not acquire generated English captions. |
| Remarks and rich terms bodies | Captured remarks/rich Terms body data is incomplete. A heading alone is not a body. | Identify and supply the actual body and its language source; map client fields only where required by the agreed response contract. | Each supplied body prints with the expected priority and visibility. Missing bodies remain missing rather than being replaced with unrelated order comments or invented text. |
| Real return financial allocations | Tested real return records lack some tax rate, tax amount, taxable value, subtotal and discount allocations. Synthetic arithmetic passed, but cannot certify those real records. | Supply returned-item allocations and confirm that they describe the returned quantities and discounts, rather than the original full sale. | Known zero and signed finite amounts are preserved; unknown allocations stay blank; fully supplied rows and aggregate totals reconcile on a real existing return. |
| Supplier state and customer place of supply | The inspected shared return-print section has no populated value rows for these fields. This is also a client mapping gap if these fields are required. | Confirm the intended data source and map/render state/state-code and place-of-supply values when supplied. Do not infer them from free-text addresses. | Actual supplied values and correct language captions appear consistently in applicable return PDF and thermal layouts; missing values are handled explicitly. |
| Physical printer output | Rendered files passed checks, but actual paper delivery was not tested. | Test representative actual printers/paper widths with sales, return and combined receipts in all requested language modes. | Arabic is readable; margins, wrapping and columns do not clip; QR codes scan; each job reaches the intended printer with the expected paper behavior. |
| Revalidation after source/mapping changes | Current output evidence uses captured configuration snapshots and controlled business fixtures. | After any API or client mapping fix, refresh the configurations and rerun the affected language/field and financial checks. Broaden only if the change affects shared behavior. | Retesting confirms the fixed source values reach printing without reintroducing visibility, bilingual suppression, item-value, total or QR regressions. |

The [label/value source guide](document-configuration-label-value-sources.md)
documents which configuration, store setting, order value, return allocation
or fallback each field currently uses. The
[detailed report](receipt-verification-2026-09-29.md) preserves evidence and
historical limits.

The separate [offline identity and returns request](backend-offline-receipt-identity-and-returns.md)
is retained for integration follow-up. Its broader backend completion is not
established by this print audit. Older proposals and completed fix notes in this
folder are reference material, not automatically new requirements.
