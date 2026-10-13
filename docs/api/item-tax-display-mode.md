# Item-row tax display

Each object in `document_configurations` accepts the optional top-level field
`item_tax_display_mode`:

```json
{
  "status": "success",
  "document_configurations": {
    "Quotation": {
      "type": "Quotation",
      "item_tax_display_mode": "unit"
    },
    "Bill": {
      "type": "Bill",
      "item_tax_display_mode": "row_total"
    },
    "Bill A4": {
      "type": "Bill A4",
      "item_tax_display_mode": "unit"
    }
  }
}
```

- `row_total`: display the original item's `tax_amount` for all its quantity.
- `unit`: display `tax_amount_unit`. If absent or invalid, display
  `tax_amount / quantity`; an absent/invalid/nonpositive quantity yields zero.
  An explicit unit-tax zero is retained.
- Missing, null, blank or unrecognized modes default to `row_total`.

Quotation details and every production PDF/thermal renderer use this setting.
Quotation details use the Quotation configuration; prints use the configuration
already selected for that document and paper size. Sales use Bill/Bill A4 or
the selected combined sales/return configuration. Return-item columns retain
their existing behavior.

`showTaxHeader` still controls the item's Tax column visibility and caption.
`showTax` still controls the document's total-tax row. The new mode does not
change full-row tax, rates, discounts, subtotal, payable or total tax. Quotation
total tax continues to use API `data.tax`; sales retain their existing API
total-tax source. Existing fallback sums continue to sum full-row amounts.

Expose this as an **Item row tax display** dropdown inside **Cart Settings**,
below the current switches and above **Table Header Texts**. Options:
**Per unit** and **Full row (all quantities)**. It is independent of header text
and document language. Refresh the Flutter document configurations after an
admin change; the chosen mode persists in the existing offline caches.
