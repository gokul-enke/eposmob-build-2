# Receipt configuration API gaps found through live admin tests

These findings concern the admin-to-API path. The backend source is not present
in this checkout, so the precise persistence or serialization fault is not yet
established. Do not replace these failures with generic-label fallback tests.

## Expected language behavior

For English, use configured English content. For Arabic, use configured Arabic
content. For bilingual, use Arabic content from the bilingual configuration and
English content from the English configuration. An empty English field must not
introduce a generic English label. If only selected English table headings are
filled, those must be the only configured English labels printed.

Item names, customer values, phone numbers, account identifiers, and currency
codes are data; their script alone does not prove a configured-label leak.

## Confirmed missing values

| Document and case | Input saved through admin | Observed API/output | Evidence |
| --- | --- | --- | --- |
| Return Bill 28, both sources filled | English `ER26X` credit-note number, `ER20X` customer name, `ER51X` amount-in-words heading, and other metadata | Bilingual resolved labels have the Arabic text, while their `_default` fields contain generic English text instead of the configured markers. All six PDFs omit the configured English values. | `build/receipt_live_audit/return_bilingual_both_filled.json`; `return_bilingual_pdf_audit.json` |
| Return Bill 28, selected English headings | Six headings including `ER40X` Grand Total | Five markers print. `grand_total_header_default` is `Grand Total`, not `ER40X`. | `return_bilingual_table_english.json`; same PDF audit |
| Bill A4 802, English fields filled | Six bank/account labels `A4E37X` through `A4E42X` | `showBankInfo`, `showBankName`, `showAccountName`, `showAccountNumber`, `showIBAN`, and `showSwiftCode` are visible but their values are null. All six PDFs lack the typed labels. | `bill_a4_english_filled.json`; `bill_a4_pdf_audit.json` |
| Bill A4 802, bilingual both filled | English header `A4E1X` and subheader `A4E2X` | Only the active bilingual header/subheader are supplied; English markers are absent from every PDF. Bank-label failures also remain. | `bill_a4_bilingual_both_filled.json`; same PDF audit |

All evidence files in the table are under `build/receipt_live_audit/`. They are
local test artifacts, not source fixtures committed to a public repository.

## Required API distinction

The client needs configured English text separately from a built-in English
default. Existing display options often already supply this as `default` next
to the active-language `value`; the failing fields must receive equivalent
typed-source information. In contrast, `resolved_labels.*_default` currently
contains built-in captions even when the English configuration is blank. Those
fields cannot safely be treated as configured English content.

Header/subheader need an explicit English source as well as the active source.
The backend and client should agree on that representation before adding new
field names. An empty source must stay distinguishable from a missing built-in
translation. No print operation should temporarily change the admin's active
language to retrieve a second source.

## Additional data coverage still under investigation

- Return remarks text (`ER54X`) was populated in the admin, but is absent from
  the captured payload; the remarks heading is present. Verify saving and
  serialization separately.
- Supplier/company overrides and customer place of supply need a confirmed
  data source before they can be printed accurately. Customer tax ID alone is
  now supported through the existing customer VAT field.
- Live `list-return-orders` inspection for test order `ORD-004682` supplies
  `order.customer.user` with only `id` and `name`; the customer object has
  only `id`, `user_id`, `laravel_through_key`, and `user`. The Sales Return
  list print route therefore cannot forward phone/address/tax data from that
  response alone. A detail fetch or an enriched response is needed for that
  route; adding nullable model fields by guessing does not restore the data.
- That same response does include original `order_number` and `order_date`,
  and item `cart_item.tax_rate` / `tax_amount`. These are confirmed available
  sources, but return quantity, tax basis, and original-invoice versus credit-note
  identity still need to be carried and checked through the print flow.
- Return tax columns, tax summaries, original invoice identity/date, and HSN
  require end-to-end source/model/renderer checks. Their absence from rendered
  output is not automatically proof of a backend-only fault.
- Store-address/phone/email controls are described as overrides in the admin,
  while existing renderer contracts treat them as labels plus store data.
  The requested semantics are awaiting clarification; do not silently redefine
  them to make marker tests pass.

## Retest gate

After fixing the source mapping, repeat the saved live admin sequence and run
`tool/verify_live_return_bilingual_output.py` and
`tool/verify_live_bill_a4_output.py`. Both intentionally fail today. Confirm
configured Arabic values and visual output separately; these scripts verify
English marker presence/absence only. Then repeat the remaining documents,
visibility switches, data cases, and PDF/thermal output checks in the progress
ledger. The full verification goal is not complete.

## Admin theme restoration limitation

Sales and Return Bill A4 (843) currently has `theme: null`. The client maps null
PDF themes to Classic. Its admin editor instead selects Simplified Tax Invoice
and offers neither an unset nor Classic option. Saving translation tests would
therefore change the persistent layout, with no observed UI path to restore it.
The 843 editor was inspected but not saved in this continuation. Provide a
backend-supported restore path or an agreed final theme before that live edit
sequence. Return Bill 28 already incurred this normalization earlier; it remains
an explicitly recorded restoration exception.

Sales and Return Bill (27) has the same unset API theme and nonempty UI theme
selection. Its editor was inspected without saving. Its thermal factory uses
the standard fallback; the live translation test must still preserve its
original configuration or have an agreed final theme.

## Return financial and classification source audit

The current live `list-return-orders` response was inspected read-only for ten
returns. A redacted numeric projection is stored in
`build/receipt_live_audit/return_financial_source_audit.json`.

- Cart `tax_amount` is the original line tax, before the order discount in the
  observed discounted case. Return 717 has original line 25, original tax 3.814,
  order discount 5, and refund 20; order-level tax is 3.050. Copying 3.814 into
  the return tax would therefore be wrong.
- Return 758 is partial: quantity 2 of 7 sold, returned value 360, original line
  value 1260, original tax 192.203. Full original tax cannot be printed as the
  partial-return tax. A verified return-specific discount/tax allocation is
  needed, including mixed-rate cases and rounding.
- Return 772 stores return quantity 14 and line value 1445 at unit price 100;
  the original quantity is 14.450. The API return quantity and line value do
  not reconcile. Do not silently infer a new quantity or overwrite the refund.
- The list response does not include `refund_breakdown`, delivery-refund choice,
  or return-specific tax allocation. Existing backend change-request markdown
  describes a desired breakdown; it is not evidence that the live GET provides it.
- Confirmed `cart_item.product.hsn_code` and `cart_item.tax_rate` are available
  in the return-list schema. Client mapping now preserves these when supplied;
  absent rates stay absent and explicit zero prints as 0%.
- Read-only `order/executive/order-details/ORD-004682` returns cart line
  `line_discount`, `discounted_total`, `discounted_base_amount`, and
  `discounted_tax_amount`, but no HSN/tax-rate fields. Its `order_returns`
  items contain only id/product_name/quantity/reason, without cart_item_id.
  This separate print route still needs enrichment or backend fields to provide
  classification/rate and identify returned variants reliably.
