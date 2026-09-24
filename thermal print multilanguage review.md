# Thermal Print Multilanguage Review

## Scope

This review covers the Arabic-English thermal receipt output for the `supermarket2` Bill configuration, the supplied Postman response, and the receipt screenshots reviewed on 11 September 2026.

Although the originally referenced file was `lib/screens/print/layouts/supermarket2_receipt_layout.dart`, registered thermal themes—including `supermarket2`—are routed through the shared receipt contract and the active `StandardReceiptLayout`. The fixes were therefore made in the shared/standard production path so they apply consistently instead of changing only a legacy layout entry point.

## Problems observed

1. Arabic and English labels in the payment summary were drawn as separate lines and could overlap neighboring totals.
2. Customer-information labels such as Customer, Phone, and Delivery occupied two lines unnecessarily.
3. Visible `/` separators were not wanted between Arabic and English.
4. Customer-information labels contained redundant trailing colons while their values were already placed in separate columns.
5. Previous balance, paid amount, and current balance labels were also split across two lines.
6. The invoice number was displayed as `4531`, although the API supplied `number_prefix: "ع-"`.
7. Missing secondary-language values were being replaced by generated Arabic fallbacks, making it impossible to intentionally show English only for one field in an `en_ar` receipt.

## Agreed bilingual presentation

Configured Arabic and English labels are combined into one visual row with exactly one ordinary space between them:

```text
العميل Customer
المجموع الفرعي E-SUBTOTAL
الرصيد الحالي E-CURRENT-BAL
```

There is no visible slash and no colon in customer-information labels.

Unicode directional-isolate characters are placed invisibly around each language run. These keep the Arabic and English portions in the correct reading order without adding a visible separator.

## Customer-information section

The following customer labels now use the single-row bilingual format:

- Customer
- Phone
- Payment
- Address
- Comment
- Delivery method
- Delivery phone
- Customer VAT number
- Customer CR number

Trailing colons are removed from both configured language lines before the label is made inline.

For bilingual receipts, the customer row uses approximately 45% of its width for the value and 55% for the label. The value gets its own text direction, while the bilingual label uses RTL layout with isolated Arabic and English runs. The customer address now follows the same label/value row structure instead of appearing as an unlabeled standalone line.

## Payment summary box

All bilingual summary labels are normalized to one line. The summary box now reserves separate, non-overlapping areas:

- 34% for the currency and amount
- 4% as a safe gutter
- 62% for the bilingual label

The amount and label are measured independently. The row height uses the taller measurement, and text scales down when required. This prevents labels such as Subtotal, Tax Total, and Net from being painted over one another.

## Customer balance section

The following labels now use the same one-row bilingual treatment:

- Previous balance (`showCustomerPrevBalance`)
- Paid amount (`showCustomerPaidAmount`)
- Current balance (`showCustomerCurrentBalance`)

For the supplied configuration, an example is rendered as one label row:

```text
الرصيد الحالي E-CURRENT-BAL    238.00
```

The table-column renderer is limited to one visual line and can scale long text down to fit the available width.

## Label-source and fallback rules

The API fields have different meanings depending on the document language mode.

| Document language | Primary label source | Secondary label source | Fallback behavior |
| --- | --- | --- | --- |
| `en` | `value` | None | English primary fallback is allowed |
| `ar` | `value` | None | Arabic primary fallback is allowed |
| `en_ar` / `ar_en` | English from `default` | Secondary language from `value` | English primary fallback is allowed; secondary fallback is not allowed |

The main rule is:

> A primary language may use a fallback. An optional secondary language prints only when its `value` is explicitly supplied.

### Bilingual field with both languages

```json
{
  "visible": true,
  "value": "العميل",
  "default": "Customer"
}
```

Expected label:

```text
العميل Customer
```

### Bilingual field intentionally showing English only

```json
{
  "visible": true,
  "value": null,
  "default": "Customer"
}
```

Expected label:

```text
Customer
```

An empty or whitespace-only `value` has the same effect. The renderer no longer supplies the secondary label from `resolved_labels` or a hardcoded Arabic translation.

### English-only configuration

English-only API responses may place the primary English text in `value` without sending `default`:

```json
{
  "visible": true,
  "value": "Customer"
}
```

This remains supported. If that primary text is absent, the normal English fallback is allowed.

### Visibility

`visible: false` hides the entire configured field. It is separate from leaving the optional secondary-language `value` empty.

## Renderer-owned bilingual text

Text created inside the renderer—such as Cash, Card, or UPI—is not an optional admin-panel secondary translation. It continues to use both supplied renderer translations in bilingual mode. This path was kept separate from the new optional `value` rule.

## Invoice number prefix

The supplied API response contains:

```json
"number_prefix": "ع-"
```

The prefix disappeared because it was previously sent through the translated display-label resolver for `showInvoiceNumber`. Since that option had `value: null`, the optional-secondary rule correctly returned no secondary label, but it also left the number without its independent document prefix.

Number prefixes are now treated as literal document configuration rather than translatable field labels:

- A configured `number_prefix` is preserved exactly once.
- `showInvoiceNumber.visible` remains the switch that shows or hides the invoice number.
- `showInvoiceNumber.value: null` does not suppress `number_prefix`.
- If `number_prefix` is empty, the renderer uses the primary language's invoice-prefix fallback.

With the supplied response, the logical invoice text now contains:

```text
ع-4531
```

## Files changed

- `lib/screens/print/layouts/common/layout_rows.dart`
  - Added one-row bilingual-label normalization.
  - Added per-language trailing-colon removal.
  - Reworked boxed-total measurement and non-overlapping column allocation.
- `lib/screens/print/layouts/standard_receipt_layout.dart`
  - Applied inline labels to customer information, totals, and customer balances.
  - Removed customer-label colons.
  - Reworked bilingual customer label/value rows.
  - Restored the configured invoice number prefix through the literal-prefix resolver.
- `lib/screens/print/layouts/receipt_configuration_contract.dart`
  - Made bilingual `value` an optional secondary label with no fallback.
  - Retained primary-language fallback behavior.
  - Added literal invoice-number-prefix resolution.
- `lib/screens/print/layouts/receipt_layout_params.dart`
  - Kept renderer-owned text bilingual independently of optional configured labels.
- `test/standard_bilingual_inline_layout_test.dart`
  - Covers space-only bilingual labels, absence of `/`, colon removal, totals, and balance labels.
- `test/receipt_configuration_contract_test.dart`
  - Covers optional bilingual secondary labels, primary fallbacks, configured secondary labels, English-only `value`, and literal number prefixes.

## Verification

The final focused receipt suite completed with 39 passing tests. It covered:

- The shared receipt configuration contract
- Inline bilingual thermal labels
- All 17 registered thermal theme routes
- All six standard PDF themes
- English, Arabic, and bilingual configuration modes
- Invoice number prefix behavior

Static analysis reported no errors. It reported only the existing informational lints in `standard_receipt_layout.dart`, primarily braces-style notices and one asynchronous `BuildContext` notice; these were unrelated to the multilingual changes.

## Expected result after regeneration

- Customer labels: Arabic and English on one row, one space, no slash, no colon.
- Payment summary labels: Arabic and English on one row without overlap.
- Balance labels: Arabic and English on one row.
- A bilingual field with empty `value`: English only.
- Invoice number: includes the configured `number_prefix`, such as `ع-4531`.

