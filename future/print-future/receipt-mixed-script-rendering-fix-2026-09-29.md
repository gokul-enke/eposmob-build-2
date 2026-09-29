# Mixed Arabic/English caption rendering

Branch: `integrate/b2b-plus-gokul-dev`.

The confirmed client bug joined a configured caption such as `Tel Phone عربي`
and the store phone into one bidirectional text run. The renderer could place
the phone between the English and Arabic portions of that caption.

Captions and business values now retain explicit boundaries through PDF and
thermal rendering. Arabic captions and Arabic values receive their own text
direction; phone numbers, identifiers, dates and other Latin values retain LTR
ordering. PDF separators are also drawn independently. When a field cannot fit
inline, its caption and value stack and wrap. Customer/order PDF captions can
wrap beyond two lines instead of being clipped.

| Area | Coverage |
| --- | --- |
| PDF | All six registered layout families, including Classic. |
| Thermal | Standard, Premium and Premium 2 Bilingual; all other registered themes delegate to the shared Standard renderer. |
| Store fields | Address, phone, email, VAT and CR registration captions remain separate from store values. |
| Other fields | Bank fields, comments, item/quantity counts, saved amounts, dates, tokens, invoice prefixes, VAT and order-number footers use separate runs where they previously joined text. Existing customer, financial and return rows already use separate caption/value cells. |
| Documents | Bill, Bill A4, Sales and Return Bill, Sales and Return Bill A4, Return Bill. |
| Source rules | English/Arabic configuration selection, missing-English suppression, visibility and business-value sources are preserved. A mixed-language caption remains the configured caption; its English fragment is not treated as a second configuration slot. |

## Verification

All verification below passed. The matrix covers all six PDF themes and all
17 registered thermal themes using controlled business data.

| Configuration case | PDF variants | Thermal variants | Result |
| --- | ---: | ---: | --- |
| English, A4 / 80 mm | 18 | 51 | Passed |
| Arabic, A4 / 80 mm | 18 | 51 | Passed |
| English + Arabic, A4 / 80 mm | 18 | 51 | Passed |
| English cleared, Arabic retained, A4 / 80 mm | 18 | 51 | Passed; no synthetic English-caption markers appeared. |
| English + Arabic, A5 / 58 mm | 18 | 51 | Passed |
| User-supplied Bill A4 configuration | 6 | — | Passed |
| Final literal-prefix spacing follow-up, Arabic and bilingual | 36 | — | Passed |
| **Total** | **132** | **255** | **387 generated variants** |

- 52 shared receipt and rendering tests passed, including a pixel comparison
  proving a phone beside a mixed caption paints identically to a standalone
  LTR phone.
- 16 return control, supplier, amount, heading and words tests passed.
- A PDF glyph-coordinate check confirmed that every phone digit lies outside
  the complete caption's horizontal bounds.
- Dedicated long-field samples were painted at widths 240, 384 and 576 pixels.
- The user's supplied Bill A4 configuration generated successfully in all six
  PDF themes with controlled business data. This is configuration rendering
  verification, not a new live transaction.
- Every inspected PDF glyph remained within page bounds. Thermal themes
  delegating to Standard produced identical PNG files for each matching
  language, document and paper case.
- The new field model, PDF helper and rendering test passed targeted static
  analysis with no issues. Broader print analysis has existing lint findings;
  no compilation errors were reported.

The final invoice-prefix check also preserves spacing when the literal prefix
ends with a space, which the PDF Arabic shaper can otherwise discard. This
follow-up was checked across all six themes and all three PDF document groups.

The running Windows app accepted a Marionette hot reload after the client
changes. Physical printer transport was not invoked during verification.

Local evidence is in `build/receipt_field_rendering/` and
`build/receipt_live_render_render_fix*/`, with test logs in
`build/receipt_field_tests_final.log` and
`build/receipt_render_return_tests.log`. The generated-file audit is recorded in
`build/receipt_field_rendering/verification_summary.json`.

No backend or admin configuration data was changed. These results do not close
the API/source gaps or the physical-printer verification listed in
[FUTURE_WORKS.md](FUTURE_WORKS.md). Long captions can require extra height or
another page; preserving complete content takes priority over clipping it.

## Bilingual centered title-band arrangement

The Bilingual Centered Tax Invoice layout places store CR registration to the
left of the invoice title and store VAT registration to its right. Those two
fields are omitted from the top header to avoid duplicates. Extra Heading 2
and FSSAI configuration text now belong to the top header and follow the same
Arabic/English column selection as Extra Heading 1 and the other header fields.
Each field retains its existing visibility and value source.

The supplied Bill A4 configuration rendered successfully in all six PDF
themes after this change; the affected layout also passed targeted static
analysis. Preview: `build/receipt_field_rendering/cr_vat_title_band.png`.
