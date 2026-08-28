# Print Template and PDF Layout Audit

**Project:** `eposmob`  
**Audit date:** 2026-08-27  
**Scope:** Standard PDF templates, thermal templates, sales printing/sharing, return printing, printer settings, previews, document configuration, and direct printer commands.

## Executive verdict

The A4/A5 print routing is mostly correct, and `usePrinterSettings: false` is the correct setting for normal A4/A5 PDF invoices. Barcode/label printing can keep `usePrinterSettings: true`.

The template feature is not fully correct. The selected renderer is often reached, but several renderers do not consistently honor the document configuration, language, visibility, customer privacy, returns, totals, payment breakdown, bank, QR, or footer settings.

The reported physical A4 side-cropping is not caused by an obvious PDF-generation crop in the current standard print path. The generated PDF page is being sent as A4. The most likely cause is the physical printer queue, media size, orientation, printable margins, or scaling mode.

This report separates code-confirmed defects from printer-driver behavior that requires physical-device verification.

## Evidence and limitations

- Focused tests passed: `00:05 +24: All tests passed!`
- The focused tests cover factory registration, basic PDF generation, aliases, visibility semantics, preview basics, and printer matching.
- They do not exercise every option in every renderer or verify output on a physical printer.
- A broad analyzer run exited with `505 issues found`; most were warnings, deprecations, unused imports, and style findings, but the analyzer is not clean.
- The source tree was clean before this Markdown report was added.
- A per-template parallel audit was attempted, but the available thread pool prevented additional agent threads; the remaining template and cross-path checks were completed locally.

## 1. Standard PDF template routing

Factory: [standard_pdf_layout_factory.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/standard_pdf_layout_factory.dart:19)

| Selected template | Actual renderer | Result |
|---|---|---|
| `classic` | `ClassicStandardPdfLayout` → `ContractStandardPdfLayout` | Best implementation, but still has shared-contract defects |
| `simplified_tax_invoice` | `SimplifiedTaxInvoiceStandardPdfLayout` | Dedicated renderer with configuration defects |
| `centered_simplified_tax_invoice` | `CenteredSimplifiedTaxInvoiceStandardPdfLayout` | Dedicated renderer with configuration defects |
| `bilingual_centered_tax_invoice` | `BilingualCenteredTaxInvoiceStandardPdfLayout` | Dedicated renderer with configuration defects |
| `boxed_bilingual_tax_invoice` | `BoxedBilingualTaxInvoiceStandardPdfLayout` | Dedicated renderer with configuration defects |
| `boxed_header_tax_invoice` | `BoxedHeaderTaxInvoiceStandardPdfLayout` | Dedicated renderer with configuration defects and an unreachable copied branch |

The six standard PDF IDs are selected correctly by the factory in the normal `PrintPage` and themed PDF-sharing paths. However, only `classic` uses the strict shared configuration contract. The other five files duplicate configuration and data logic.

The comment in [contract_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/contract_standard_pdf_layout.dart:223) describes one production renderer for every standard theme, but the factory actually returns five separate custom renderers.

## 2. Thermal template routing

Factory: [receipt_layout_factory.dart](D:/Projects/ENKE/eposmob/lib/screens/print/layouts/receipt_layout_factory.dart:19)

### Distinct active thermal renderers

| Template ID | Active renderer |
|---|---|
| `premium` | `PremiumReceiptLayout` |
| `premium2_bilingual` | `Premium2BilingualReceiptLayout` |
| `standard` | `StandardReceiptLayout` |

### Thermal IDs sharing one renderer

The following 14 IDs route through `ContractReceiptLayout` to the same `StandardReceiptLayout` implementation:

- `classic`
- `premium1`
- `premium2`
- `supermarket_en`
- `arabic_and_english`
- `arabic_english_table_headers`
- `arabic_and_english_3`
- `supermarket`
- `supermarket2`
- `supermarket2_bilingual`
- `supermarkerrecpt3`
- `bilingual`
- `multi_store`
- `mobile_shop_tax_invoice`

Therefore, 15 of the 17 thermal template names currently produce the same visual thermal layout. If the product requirement is 17 visually different templates, the requirement is not currently met.

Older files such as `premium1_receipt_layout.dart`, `premium2_receipt_layout.dart`, `supermarket_receipt_layout.dart`, `multi_store_receipt_layout.dart`, and the other legacy layout files are not selected by the production factory. They are retained as reference/legacy implementations.

## 3. Factory and routing defects

### 3.1 Unknown templates silently become Classic

Both factories fall back to Classic when the saved/API theme is null or unknown.

Consequences:

- A spelling error in `active_theme` does not fail visibly.
- A thermal theme selected while printing A4 silently becomes the Classic PDF layout.
- The user may believe a different template was printed.

### 3.2 Registration normalization is inconsistent

`getLayout()` lowercases and trims the theme ID, but `registerLayout()` lowercases without trimming. `hasTheme()` also does not trim.

For example, a custom theme registered as `" custom "` may not be found using the normal lookup path.

Duplicate registrations overwrite existing IDs without warning.

### 3.3 Thermal template names do not guarantee different output

The factory preserves the old IDs for compatibility, but most IDs no longer select their original layout classes. This creates a UI/template mismatch: the dropdown contains many names, while the output is shared.

### 3.4 Thermal PDF fallback always uses Classic PDF

[receipt_pdf_builder.dart](D:/Projects/ENKE/eposmob/lib/screens/print/layouts/receipt_pdf_builder.dart:13) always calls:

```dart
StandardPdfLayoutFactory.getLayout('classic').buildPdfDocument(params)
```

Therefore, `PremiumReceiptLayout`, `Premium2BilingualReceiptLayout`, and `StandardReceiptLayout` do not produce their own PDF visual when their `buildPdf()` interface is used. Their PDF fallback is Classic standard PDF.

### 3.5 Dead legacy standard-printer code remains

`StandardPrinter.generateAndPrintPDF()` and the older `generatePDFForSharing()` implementation in [print_standard.dart](D:/Projects/ENKE/eposmob/lib/screens/print/print_standard.dart:122) contain a separate legacy PDF builder that does not use the standard PDF factory.

Current search shows the active Sales sharing path uses `generateThemedPDFForSharing()`, so the old methods appear unreferenced by the current sales route. They remain a future regression risk if another caller uses them.

## 4. Configuration-contract defects

The shared contract is defined in [receipt_configuration_contract.dart](D:/Projects/ENKE/eposmob/lib/screens/print/layouts/receipt_configuration_contract.dart:31) and contains 61 canonical keys plus aliases.

### 4.1 Only Classic consistently uses the contract

The Classic standard PDF renderer resolves visibility and labels through `ReceiptLayoutParams` and the shared contract. The five custom standard PDF renderers frequently read `displayConfig` directly.

This causes the same API configuration to behave differently depending on the selected template.

### 4.2 Missing visibility defaults are treated as visible

The strict contract uses:

```dart
option?.visible == true
```

The custom PDF renderers frequently use:

```dart
option?.visible != false
```

or:

```dart
option?.visible ?? true
```

Consequences:

- Missing configuration options print by default.
- Incomplete API responses can expose customer, payment, balance, and total fields.
- A missing option behaves differently from an explicitly hidden option.
- The same template data can show more fields in a custom renderer than in Classic.

### 4.3 Alias handling is inconsistent

The shared aliases include:

- `showTotalMRP` → `showMRPTotal`
- `showTaxableAmount` → `showSubTotal`
- `showNetTotal` → `showNetAmount`
- `showPaymentBreakdown` → `showPaymentBreaked`
- `showCustomerOldBalance` → `showCustomerPrevBalance`
- `showCustomerCurrentBalance` → `showCustomerBalance`
- `showPaidAmount` → `showCustomerPaidAmount`
- bank-detail aliases
- `showTerms` → `showTermsConditions`
- `showInvoiceTitleB2B` → `showInvoiceTitleB2b`

Many custom renderers use raw keys instead of the alias resolver. As a result, alias-only API payloads can be ignored.

### 4.4 Noncanonical keys are used by the UI or renderers

These keys are not consistently part of the canonical contract:

- `showPaymentMethod`
- `showOrderComment`
- `showCartTotal`
- `showRoundOff`
- `showDiscountColumn`

The UI exposes some of these keys, while different renderers read different names. A setting can therefore be changed without affecting the selected output.

The item discount column is controlled by `showDiscountColumn`, while the canonical contract contains `showDiscount`. This is a direct template-setting mismatch.

### 4.5 Alias-only values can fail in the canonical matrix

The alias resolver is one-directional. Some renderers iterate only the canonical list and never ask for the alias key. If only the newer alias exists in the payload, the canonical matrix can still treat the field as hidden.

## 5. Language and RTL defects

### 5.1 Custom PDF renderers only recognize exact Arabic values

The custom PDF files mainly check whether the raw language equals exact `ar`.

These values can be mishandled:

- `arabic`
- `english_arabic`
- `arabic_english`
- `en_ar`
- `ar_en`
- `dual`
- `dual_language`

The shared contract supports these variants, but the custom renderers do not consistently use it.

### 5.2 Arabic PDF page structure remains LTR

Several custom layouts translate labels but keep the page and table direction left-to-right. Arabic text can appear inside an LTR document rather than as a true RTL invoice.

### 5.3 Preview language logic differs from renderer logic

The preview maps only exact `en` and `ar`; every other value becomes bilingual. The renderer normalizer treats unknown values as English.

Consequently, an unknown or unusual language value can show bilingual in the UI preview but English in the final PDF.

### 5.4 Arabic filtering can remove Latin-only values

`ReceiptConfigurationContract.documentText()` filters text according to the selected script. In Arabic mode, a value containing only Latin characters or numbers can become empty.

Possible affected values include:

- Invoice numbers such as `INV-010428`
- Phone numbers
- URLs
- English-only store names
- Alphanumeric VAT/CR identifiers

## 6. Configuration options not correctly honored by custom PDFs

| Option/feature | Classic | Simplified | Centered | Bilingual | Boxed bilingual | Boxed header |
|---|---:|---:|---:|---:|---:|---:|
| `showDeliveryPhone` | Works | Ignored | Ignored | Ignored | Ignored | Ignored |
| `showTokenNumber` | Works | Ignored | Ignored | Ignored | Ignored | Ignored |
| `showOrderNumberInFooter` | Works | Ignored | Ignored | Ignored | Ignored | Ignored |
| `showWarranty` | Works | Ignored | Ignored | Ignored | Ignored | Ignored |
| `showVATFooter` | Works | Works | Works | Ignored | Ignored | Ignored |
| `showVatNumber` | Works | Ignored | Ignored | Ignored | Ignored | Read incorrectly |
| `showCRNumber` | Works | Ignored | Ignored | Ignored | Ignored | Read without visibility check |
| `showPaymentBreaked` | Works | Partial | Partial | Helper not called | Helper not called | Helper not called |

The custom files are:

- [simplified_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/simplified_tax_invoice_standard_pdf_layout.dart:46)
- [centered_simplified_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/centered_simplified_tax_invoice_standard_pdf_layout.dart:46)
- [bilingual_centered_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/bilingual_centered_tax_invoice_standard_pdf_layout.dart:46)
- [boxed_bilingual_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/boxed_bilingual_tax_invoice_standard_pdf_layout.dart:35)
- [boxed_header_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/boxed_header_tax_invoice_standard_pdf_layout.dart:35)

## 7. Invoice title and header defects

- Several custom layouts render the invoice title even when `showInvoiceTitle.visible` is false.
- Boxed layouts are fail-open: a missing title option can still display the title.
- Some active custom headers use configured option text as if it were the actual store name.
- Some layouts use `showExtraHeading2` and `showFssaiInfo` text in the title/header area instead of consistently rendering the runtime seller VAT/CR values.
- Seller VAT and CR visibility is missing in most custom templates.
- Boxed Header reads seller VAT/CR values without checking visibility.
- If runtime seller values are missing, Boxed Header can use configured label text as the actual seller identifier.
- Boxed Bilingual always includes invoice due-date metadata even though no due-date field or visibility option exists; it duplicates the invoice date.
- Header, subheader, terms, footer, and seller contact data do not have identical behavior across templates.

## 8. Customer and privacy defects

- `showCustomerNameAndPhone` acts as a master switch for address, payment, comment, VAT/CR, and delivery fields in several layouts.
- Custom standard PDFs do not consistently honor `isDefaultCustomer`.
- Default-customer phone hiding is not reliably applied in the Classic standard PDF contract renderer.
- Alternate phone values can be appended even when delivery-phone display is disabled.
- Alternate phone values are not consistently masked.
- Return documents can print customer name, address, and phone without the normal customer visibility rules.
- Return customer phone can be printed unmasked.
- Sales PDF-sharing calls do not pass `isDefaultCustomer`, so the sharing renderer receives its default `false` value.

## 9. Per-template defects

### 9.1 Simplified Tax Invoice

File: [simplified_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/simplified_tax_invoice_standard_pdf_layout.dart:46)

- Uses raw language checks instead of the shared language contract.
- Arabic page remains structurally LTR.
- Missing delivery phone, token, footer order number, warranty, seller VAT, and seller CR controls.
- Invoice title visibility is ignored.
- Customer and totals sections default to visible when options are missing.
- `showSubTotal` incorrectly falls back to `showMRPTotal`.
- `showMRPTotal` and subtotal semantics are inconsistent.
- Item discount column uses noncanonical `showDiscountColumn`.
- Map items read `discount` but not `discount_amount`.
- Payment breakdown helper is called, but visibility is fail-open and not alias-aware.
- Malformed payment breakdown data can throw and cause payment lines to disappear.
- All-zero payment breakdown data can suppress the normal payment method.
- Payment method labels are not consistently localized.
- VAT text falls back to hardcoded `TOTAL VAT 15%`.
- Bank labels are hardcoded/partially localized.
- Branch, IFSC, bank phone, and bank email have no independent canonical controls.
- UPI QR uses hardcoded `cu=INR` and lacks URL encoding.
- Date/time uses fixed IST conversion.
- Invoice number formatting can remove prefixes and leading zeroes.
- Long item names can be clipped by a fixed line limit.
- Invalid numeric values silently become zero.
- Return values use exact-name matching or pro-rata estimation.
- Duplicate product names can produce wrong return amounts.
- Return reason value is blank.
- Return net amount duplicates return total.
- Return columns use parent bill configuration instead of return configuration.
- `retVis()` is dead code.
- Final amount is derived from formatted total minus reconstructed returns.

### 9.2 Centered Simplified Tax Invoice

File: [centered_simplified_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/centered_simplified_tax_invoice_standard_pdf_layout.dart:46)

It has the same configuration, language, visibility, privacy, tax, QR, item, date, invoice-number, return, and final-total defects as Simplified Tax Invoice.

Additional observations:

- It has its own duplicated payment and return logic.
- Its item map branch has the same `discount` versus `discount_amount` mismatch.
- Its return helper defines `retVis()` but does not use it.

### 9.3 Bilingual Centered Tax Invoice

File: [bilingual_centered_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/bilingual_centered_tax_invoice_standard_pdf_layout.dart:46)

- `_buildPaymentBreakdownLines()` is defined at line 1420 but is never called in the active PDF body.
- `showPaymentBreaked` therefore has no effect.
- Missing seller VAT/CR visibility.
- Missing delivery phone, token, footer order number, warranty, and VAT footer.
- Customer phone/privacy handling is incomplete.
- Header runtime store contact data is not consistently included.
- VAT percentage text can be hardcoded as 15%.
- Map item discount uses `discount` but not `discount_amount`.
- Return configuration is ignored for return-column visibility.
- Return reason value is blank.
- Return net amount duplicates return total.
- Final return math is based on name matching/pro-rata estimation.
- Arabic output remains structurally LTR.

### 9.4 Boxed Bilingual Tax Invoice

File: [boxed_bilingual_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/boxed_bilingual_tax_invoice_standard_pdf_layout.dart:35)

- The active branch is a special reference/boxed branch around line 705; a second fallback body below it is unreachable for this class.
- Missing delivery phone, token, footer order number, warranty, seller CR visibility, seller VAT visibility, and VAT footer.
- Payment breakdown helper is defined but not called.
- Buyer box does not include all configured customer fields.
- Buyer phone is not consistently displayed or controlled.
- Seller VAT is passed to the seller box unconditionally.
- Due date is always shown and duplicates the invoice date.
- Item discount uses noncanonical `showDiscountColumn`.
- Item tax labels can fall back to hardcoded `VAT 15%`.
- Bank labels are only partially localized.
- IFSC can be labelled as SWIFT.
- Only the primary bank/account is supported.
- Return columns use parent bill configuration.
- `retVis()` is dead code.
- Return reason is blank.
- Return net amount equals return total.
- Final total uses derived return calculations.
- Long item names can be clipped.

### 9.5 Boxed Header Tax Invoice

File: [boxed_header_tax_invoice_standard_pdf_layout.dart](D:/Projects/ENKE/eposmob/lib/screens/print/standard_layouts/boxed_header_tax_invoice_standard_pdf_layout.dart:35)

- Contains a copied conditional checking `layoutId == 'boxed_bilingual_tax_invoice'`.
- Because the real ID is `boxed_header_tax_invoice`, that branch is unreachable.
- The renderer falls through to a different duplicated fallback body.
- Seller VAT/CR values are read without visibility checks.
- Configured label text can be used as a seller VAT/CR value when runtime data is absent.
- Missing delivery phone, token, footer order number, warranty, and VAT footer.
- Payment breakdown helper is defined but not called.
- Output filename uses the `BoxedBilingualTaxInvoice_` prefix instead of the Boxed Header prefix.
- Has the same language, privacy, hardcoded VAT, QR, bank, item, return, and total defects as the other custom layouts.

## 10. Totals and financial-calculation defects

These affect multiple renderers.

### 10.1 MRP does not mean the same thing everywhere

Some layouts calculate:

```text
sum(item MRP × quantity)
```

Other layouts label `netExcTax + discount` as gross/MRP. Therefore, `showMRPTotal` does not represent the same amount in every template.

### 10.2 Subtotal does not mean the same thing everywhere

Some layouts calculate subtotal as:

```text
formatted total + discount
```

Others use net-excluding-tax values. The same setting can display different financial values depending on the selected template.

### 10.3 VAT percentage is hardcoded

Several templates display `VAT 15%` even if the actual tax rate is different. The tax amount may be dynamic while the printed percentage is not.

### 10.4 Tax-per-unit assumptions can be wrong

Several renderers calculate:

```text
rate excluding tax = unit price - tax / quantity
```

This assumes that unit price includes tax and that tax is a line total. If the API sends tax per unit or the price is already tax-exclusive, the displayed rate is wrong.

### 10.5 Invalid numbers silently become zero

Unexpected or malformed numeric values are generally converted to zero instead of producing a validation error. The PDF can look valid while containing incorrect amounts.

### 10.6 Comma-formatted totals can break QR totals

[receipt_layout_params.dart](D:/Projects/ENKE/eposmob/lib/screens/print/layouts/receipt_layout_params.dart:361) parses `formattedTotal` directly with `double.tryParse()`.

For example, `1,234.50` may parse as zero. This can affect ZATCA QR totals.

### 10.7 Map tax fields are inconsistent

For map-based items, `ReceiptLayoutParams.totalTax` primarily reads `tax_amount`. A map containing only `taxAmount` or `tax` may calculate zero tax unless `apiTotalTax` is supplied.

## 11. Payment-breakdown defects

- Simplified and Centered layouts call a payment-breakdown helper, but their helper visibility is fail-open.
- Bilingual Centered, Boxed Bilingual, and Boxed Header define payment-breakdown helpers but do not call them in the active body.
- `showPaymentBreaked` and `showPaymentBreakdown` are not consistently treated as aliases.
- Malformed `amounts` data can throw during casting.
- All-zero structured payment data can suppress the ordinary payment method fallback.
- Payment method IDs can print instead of human-readable names.
- Payment method names are not consistently localized.
- Sales sharing does not pass the structured payment breakdown even when it is available.

## 12. Bank-information defects

The shared helper in [receipt_layout_params.dart](D:/Projects/ENKE/eposmob/lib/screens/print/layouts/receipt_layout_params.dart:421) only provides canonical visibility for:

- Bank name
- Account name
- Account number
- IBAN
- SWIFT

Available bank data without independent canonical controls includes:

- Branch/head office
- IFSC
- Bank phone
- Bank email

Other problems:

- Some labels are hardcoded English.
- Boxed layouts can label IFSC as SWIFT.
- Only the primary active bank/account is printed.
- Custom renderers do not consistently use the shared alias resolver.

## 13. QR and ZATCA defects

- UPI QR URLs hardcode `cu=INR`.
- UPI IDs and order numbers are not URL encoded.
- Comma-formatted totals may become zero in QR calculations.
- ZATCA credential validation is only a non-empty check; whitespace can pass.
- Return params do not load/pass `zatcaCrNumber`.
- Share params do not pass `apiTotalTax`, so QR tax may be recalculated from incomplete item data.
- QR display depends on both visibility and having a usable link; enabled QR settings do not guarantee a QR image.

## 14. Footer and hardcoded-content defects

- `showVATFooter` often prints only the ZATCA VAT number rather than arbitrary configured footer content.
- Terms/thank-you option values are sometimes treated as body content rather than only labels.
- Several custom PDF layouts always render hardcoded signature blocks.
- Signature visibility is not controlled by a canonical configuration key.
- Custom and legacy code can add a barcode without a dedicated barcode visibility setting.
- Footer invoice numbers can lose prefixes and leading zeroes.

## 15. Date and invoice-number defects

- Multiple custom/legacy renderers convert dates using fixed IST behavior rather than the client/store timezone.
- Simplified and related custom layouts can show both a date row and a separate time row with inconsistent labels.
- Invoice-number formatting in custom/legacy renderers can strip prefixes and leading zeroes. For example, an order such as `ORD-000430` can become something like `INV-430`.
- Classic’s contract renderer preserves the configured prefix and original order number more reliably.

## 16. Return-document defects

Return parameter construction: [return_bill_layout_params_builder.dart](D:/Projects/ENKE/eposmob/lib/screens/print/return_bill_layout_params_builder.dart:69)

- Return configuration is passed, but custom renderers use parent bill configuration for return-column visibility.
- `retVis()` is defined but unused in several renderers.
- Hidden return headings can still appear.
- Return reason values are blank in several custom layouts.
- Return customer fields bypass normal visibility/privacy rules.
- Return customer phone can be unmasked.
- `isDefaultCustomer` is not passed to the return params builder.
- `zatcaCrNumber` is not loaded/passed by the return builder.
- Token, payment method, delivery phone, comment, paid amount, and old balance are not included in return params.
- If original cart items are unavailable, synthetic items are created from the aggregate return total.
- Synthetic items lose original item price, tax, discount, MRP, and exact line totals.
- Exact product-name matching fails with duplicate names.
- Missing matches fall back to pro-rata calculations.
- A zero calculated rate can be treated as not found.
- Return net amount is often equal to return total instead of being independently calculated.
- Final total is derived from reconstructed return amounts instead of authoritative backend values.
- Classic return item total cells are blank; only the aggregate return total is populated.

## 17. Sales printing and sharing data-path defects

### 17.1 Normal Sales auto-print

The auto-print path in [sales_order_details.dart](D:/Projects/ENKE/eposmob/lib/screens/sales/widgets/sales_order_details.dart:475) correctly passes most important values:

- Selected paper size
- Selected theme
- Token
- Payment breakdown
- Paid amount
- Current balance
- API tax
- Returns
- Customer KYC
- Store name

It does not pass:

- Customer old balance
- A separate delivery phone

It passes the alternate phone as a possible delivery fallback.

### 17.2 Manual PrintPage printing

The manual path in [print.dart](D:/Projects/ENKE/eposmob/lib/screens/print/print.dart:1097) passes the richer parameter set and calls the selected standard factory. The route is structurally correct, but configuration-refresh and renderer-contract defects still apply.

### 17.3 Sales PDF sharing

The Sales PDF-sharing path in [sales.dart](D:/Projects/ENKE/eposmob/lib/screens/sales/sales.dart:355) correctly resolves the PDF-sharing profile and calls the standard PDF factory.

However, the share method in [print_standard.dart](D:/Projects/ENKE/eposmob/lib/screens/print/print_standard.dart:2749) does not accept/pass all fields supported by normal printing.

Missing or incomplete share data includes:

- Payment breakdown from Sales callers
- Paid amount
- Customer old balance
- Customer current balance
- `isDefaultCustomer`
- Token number
- Delivery phone
- API total tax
- Return document configuration
- `isReturnOnly`
- Store name in the Sales callers

Consequences:

- Shared PDF can differ from directly printed PDF.
- Payment breakdown can disappear.
- Balances can disappear.
- Token can disappear.
- Delivery phone can disappear.
- Return templates can use the normal bill configuration.
- Tax can be recalculated from incomplete item data.
- Store name can fall back to a generic/configured value.

The same omissions exist in the order-detail sharing path at [sales_order_details.dart](D:/Projects/ENKE/eposmob/lib/screens/sales/widgets/sales_order_details.dart:888).

### 17.4 Sharing can use an A4 configuration while the selected share paper is A5

The Sales PDF-sharing config resolver prefers `Bill A4`/`Sales and Return Bill A4`, while the later PDF-sharing profile can select A5. If the backend has distinct A5 configuration records, the share route does not select them.

## 18. Transaction sharing bypasses the standard template factory

[share_helper.dart](D:/Projects/ENKE/eposmob/lib/screens/transactions/widgets/share_helper.dart:232) still uses:

- `InvoiceTemplatePdfBuilder`
- `ReceiptTemplatePdfBuilder`

Those builders do not use `StandardPdfLayoutFactory`.

Therefore, transaction invoice/receipt sharing can ignore the selected standard PDF template completely.

## 19. Paper-size and document-configuration defects

### 19.1 PrintPage does not reload configuration after paper-size change

[print.dart](D:/Projects/ENKE/eposmob/lib/screens/print/print.dart:1299) saves the new paper size but does not re-resolve the loaded document configuration.

Example:

1. PrintPage opens with a thermal size.
2. It loads the thermal `Bill` configuration.
3. The user changes the size to A4.
4. The page sends an A4 PDF using the previously loaded thermal configuration.

The page size changes, but the document configuration may not.

### 19.2 Paper-size normalization is duplicated and inconsistent

- `PrintPage` routing checks exact strings.
- `ReceiptLayoutParams.isThermal` trims and normalizes.
- Standard PDF renderers treat only exact `A5` as A5.
- Direct printer service uppercases but does not trim.
- The document resolver recognizes only exact `A4` and `A5`.

Values such as `a5`, `A5 `, `80 mm`, and `A4 ` can produce different routing, configuration, and page-format results.

### 19.3 No A5-specific document configuration support

The resolver supports records such as:

- `Bill A4`
- `Sales and Return Bill A4`

but does not support equivalent A5-specific records. If separate A5 configurations exist on the backend, they are not selected.

### 19.4 Invalid cross-mode themes silently become Classic

If a saved thermal theme remains selected while paper is A4/A5, the standard PDF factory does not recognize it and returns Classic.

### 19.5 Billing thermal and Billing PDF themes share one preference

For Billing, thermal and standard PDF themes use the same billing theme preference key.

When switching between thermal and A4/A5:

- The available theme list changes.
- The current theme may be reset to Classic.
- Selecting an A4 theme can overwrite the thermal theme.
- Selecting a thermal theme can overwrite the A4 theme.

PDF Sharing has separate preferences, but Billing physical printing does not preserve separate thermal and standard-PDF template selections.

## 20. Printer-settings UI defects

Printer sizes and theme lists are in [printer_settings.dart](D:/Projects/ENKE/eposmob/lib/screens/print/printer_settings.dart:59).

### 20.1 No F4 option

The available sizes are:

```text
112mm, 80mm, 58mm, A5, A4
```

There is no F4 support. An F4-like value passed into the direct service is effectively treated as A4 because every non-A5 value maps to A4.

### 20.2 No standard A4/A5 test print

The Test Print action is hidden for standard PDF sizes. The underlying sample method generates only 58mm or 80mm ESC/POS output, not a real A4/A5 PDF sample.

### 20.3 Configuration workspace is not available for every profile

The detailed configuration workspace is displayed only for Billing. PDF Sharing and Quotation do not receive the same workspace/preview experience.

### 20.4 UI exposes duplicate and unsupported settings

The workspace exposes both canonical and legacy names, including:

- `showPaymentMethod` and `showPayment`
- `showOrderComment` and `showComment`
- `showTotalMRP` and `showMRPTotal`
- `showTaxableAmount` and `showSubTotal`
- `showNetTotal` and `showNetAmount`
- `showRoundOff`, which has no complete renderer support

This makes the template configuration difficult to understand and easy to misconfigure.

## 21. Preview defects

Preview implementation: [receipt_configuration_workspace.dart](D:/Projects/ENKE/eposmob/lib/screens/print/widgets/receipt_configuration_workspace.dart:949)

### 21.1 Preview does not render the selected template

The preview always calls:

```dart
Premium2BilingualReceiptLayout().renderPreviewPng(params)
```

at line 1024, regardless of whether the selected theme is Classic, Simplified, Centered, Boxed, or Boxed Header.

### 21.2 A4/A5 preview uses an 80mm canvas

For A4/A5, the preview forcibly changes the sample paper size to `80mm`.

It therefore does not represent:

- A4 width
- A5 width
- A4/A5 margins
- A4/A5 pagination
- A4/A5 table wrapping
- A4/A5 footer placement

### 21.3 Preview and final output can disagree

The UI itself warns that the shared preview may differ from the selected template’s styling and spacing. This is a confirmed product-behavior mismatch, not merely a visual-quality concern.

## 22. Direct printer and A4 cropping analysis

Direct service: [standard_pdf_direct_print_service.dart](D:/Projects/ENKE/eposmob/lib/services/standard_pdf_direct_print_service.dart:38)

The current standard behavior is correct:

```dart
usePrinterSettings = false
```

Normal standard PDF calls use the default `false`. Barcode printing explicitly uses:

```dart
usePrinterSettings: true
```

at [barcode_printer_service.dart](D:/Projects/ENKE/eposmob/lib/screens/print/barcode_printer_service.dart:992).

For normal A4/A5 printing, keep `usePrinterSettings: false`. Enabling it allows the installed driver’s saved media configuration to override the requested PDF size and can make a mismatch worse.

The standard service sends:

- A4 page format for normal A4
- A5 page format for A5
- `dynamicLayout: false`
- Printer-driver settings disabled

The source does not show an application-side crop of the PDF.

The most likely physical causes are:

- Printer driver configured for Letter, Legal, F4, or another paper size
- Wrong orientation
- `Actual size`/100% scaling instead of `Fit` or `Shrink to printable area`
- Physical printer non-printable side margins
- Wrong Windows printer queue or driver
- Printing through a PDF viewer with its own scaling
- A printer that is not designed for full A4 pages

Microsoft Print to PDF showing the entire page is expected. It is a virtual printer and does not have the physical printer’s non-printable margins.

## 23. Thermal command behavior

The active thermal layouts send hardcoded commands including:

- Barcode when an order number exists
- Paper feed
- Cash-drawer kick
- Paper cut

There are no UI settings for disabling those commands. This may be intentional, but it is not configurable per printer/template.

## 24. What is currently correct

- Manual standard printing calls `StandardPdfLayoutFactory`.
- Automatic standard printing calls `StandardPdfLayoutFactory`.
- Sales themed PDF sharing calls `StandardPdfLayoutFactory`.
- The six standard PDF IDs are registered.
- A4/A5 are included in the UI.
- `usePrinterSettings: false` is the correct default for standard A4/A5 PDFs.
- Barcode printing keeps `usePrinterSettings: true`.
- Focused factory and printer-service tests pass.

## 25. Recommended priority order

1. Centralize all standard PDF templates behind one strict visibility, alias, language, privacy, and data contract.
2. Fix the five custom PDF renderers’ missing fields, returns, payment breakdown, totals, language, bank, QR, and footer behavior.
3. Fix the Sales PDF-sharing parameter omissions.
4. Route transaction sharing through the standard PDF factory.
5. Fix return configuration and authoritative return/final-total calculations.
6. Make the preview render the selected renderer and actual A4/A5 page size.
7. Reload document configuration when paper size changes.
8. Validate paper size and theme together before printing.
9. Keep separate Billing thermal and Billing A4/A5 template preferences, or clearly document that PDF Sharing is a separate profile.
10. Add a real A4/A5 test print or an explicit printer-settings instruction.
11. Keep `usePrinterSettings: false` for normal A4/A5 and configure the physical printer for A4, portrait, and fit/shrink-to-printable-area.
