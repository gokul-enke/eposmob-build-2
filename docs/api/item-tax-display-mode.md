# Item tax columns

Document configurations now control two independent item-table columns through
`display_configuration`. The same contract applies to Quotation, Bill, Bill A4
and combined sales/return documents:

```json
{
  "type": "Bill A4",
  "display_configuration": {
    "showTaxHeader": {
      "visible": true,
      "value": "ضريبة الوحدة",
      "default": "Unit Tax"
    },
    "showRowTotalTaxHeader": {
      "visible": true,
      "value": "إجمالي ضريبة الصنف",
      "default": "Row Total Tax"
    },
    "showTax": {
      "visible": true,
      "value": "الضريبة",
      "default": "VAT"
    }
  },
  "resolved_labels": {
    "tax": "ضريبة الوحدة",
    "tax_default": "Unit Tax",
    "row_total_tax": "إجمالي ضريبة الصنف"
  }
}
```

- `showTaxHeader`: per-unit tax from the item's `tax_amount_unit`. If absent
  or invalid, display `tax_amount / quantity`; an absent, invalid or nonpositive
  quantity yields zero. An explicit API unit-tax zero is retained.
- `showRowTotalTaxHeader`: the item's existing full-quantity `tax_amount`.
- Either, both or neither item column can be visible. Each has its own caption.
- `showTax`: the separate document total-tax summary, unchanged by item-column
  visibility. It is not a master switch for the item columns.

Presence of `showRowTotalTaxHeader`, including `visible: false`, identifies the
new contract. It makes `showTaxHeader` a per-unit column regardless of a stale
top-level `item_tax_display_mode`. The API should return both item-column
options explicitly, even when hidden.

For older API responses and offline caches without `showRowTotalTaxHeader`,
the original single-column behavior is retained: `item_tax_display_mode: unit`
shows unit tax and `row_total` (or a missing/invalid mode) shows full row tax.
The legacy mode is no longer needed for new configurations.

Quotation details use the Quotation configuration and react to refreshed
visibility and labels. Every production A4/A5 PDF and thermal renderer uses
the configuration already selected for its document and paper size. Sales use
Bill/Bill A4 or the selected combined sales/return configuration. Return-item
columns retain their existing behavior. Both columns and labels survive the
existing Hive and preferences caches.

This changes display only. Full-row tax, rates, discounts, subtotal and payable
remain unchanged. Quotation total tax continues to use API `data.tax`; sales
retain their existing API total-tax source. Existing fallback sums continue to
sum full-row amounts, never per-unit taxes.

In the document-template admin page, expose two independent switches or
checkboxes in **Cart Settings**: **Show Unit Tax** (`showTaxHeader`) and
**Show Row Total Tax** (`showRowTotalTaxHeader`). Both may be selected. Give
each its own English and Arabic caption fields in **Table Header Texts**.
Refresh Flutter document configurations after saving the admin configuration.
