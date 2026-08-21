# Receipt Template Normalization Plan

## Objective

Make every supported thermal receipt theme obey one shared document contract:

- English-only (`en`)
- Arabic-only (`ar`)
- English + Arabic (`en_ar` and supported aliases)
- all 61 Bill `display_configuration` keys
- strict visibility and stable section order
- dynamic values from the correct store, order, calculation, bank, and ZATCA sources
- correct LTR/RTL column order
- predictable 58mm, 80mm, and 112mm behavior
- a common visibility preview and, where supported, an exact theme preview

The content contract must be shared. A template should define visual styling only:
spacing, typography, dividers, boxes, alignment, and decoration.

## Audit Baseline (2026-08-20)

Implementation note: the production thermal factory now routes every legacy
theme identifier through the normalized Standard renderer adapter. Premium and
Premium 2 Bilingual retain their own renderers because they already consume
the contract directly. The old clone files remain available for visual
reference/custom registration, but they are no longer allowed to bypass the
shared contract through the production factory.

The audit covered all 17 registered thermal themes. Coverage counts are effective
estimates against the supplied 61-key Bill response; `showInvoiceTitleB2b` is
resolved indirectly by `ReceiptLayoutParams`.

| Theme | Effective keys | EN | AR | EN + AR | Priority finding |
| --- | ---: | --- | --- | --- | --- |
| Premium 2 Bilingual | 61/61 | Ready | Ready | Ready | Reference implementation; needs broader regression tests |
| Standard | ~51/61 | Partial | Incorrect dual output | Incorrect single-value output | Best first legacy migration |
| Premium | ~51/61 | Partial | Conflated with bilingual | Not normalized | Missing dynamic groups |
| Classic | ~51/61 | Partial | Partial | Collapses to Arabic/value | Missing dynamic groups |
| Premium 1 | ~49/61 | Partial | Conflated with bilingual | Not normalized | Also missing extra headings |
| Premium 2 | ~49/61 | Partial | Conflated with bilingual | Not normalized | Also missing extra headings |
| Arabic & English | ~50/61 | English label leakage | Incorrect dual output | Inconsistent | Missing 11 integrations |
| Arabic & English 2 | ~51/61 | English label leakage | Incorrect dual output | Inconsistent | Near-clone of Arabic & English 3 |
| Arabic & English 3 | ~51/61 | English label leakage | Incorrect dual output | Inconsistent | Consolidate with sibling implementation |
| Bilingual | ~51/61 | English label leakage | Incorrect dual output | Inconsistent | Missing dynamic groups |
| Supermarket | ~51/61 | Partial | Incorrect dual output | Inconsistent | VAT footer depends on QR |
| Supermarket 2 | ~52/61 | Partial | Incorrect dual output | Inconsistent | Delivery-phone label/data confusion |
| Supermarket 2 Bilingual | ~52/61 | Mostly correct | Mostly correct | Mostly correct | Document-level language leakage |
| Supermarket 3 | ~48/61 | Partial | Incorrect dual output | Inconsistent | Hardcoded invoice/date row and weakest coverage |
| Multi Store | ~52/61 | Partial | Incorrect dual output | Inconsistent | Delivery phone uses store hotline semantics |
| Mobile Shop Tax Invoice | ~50/61 | Mostly correct | Mostly correct | Mostly correct | Document-level leakage; missing dynamic groups |
| Supermarket EN | ~49/61 | English only | Unsupported | Unsupported | Retire, keep explicitly EN-only, or migrate last |

### Current Production Readiness

The table above is the pre-migration audit snapshot. In the current code,
`ReceiptLayoutFactory` routes every one of those 17 IDs through the shared
contract adapter (except the dedicated Premium and Premium 2 Bilingual
renderers, which now consume the same contract). Therefore the active thermal
path supports EN, AR, and EN+AR semantics and all 61 keys for every registered
ID. The historical clone files are intentionally retained as non-production
visual references until a separate skin is migrated behind the contract.

## Confirmed Cross-Cutting Defects

- Legacy language checks do not consistently recognize `en_ar`, `ar_en`,
  `EN/AR`, `AR/EN`, or `bilingual`.
- Several templates treat `ar` as bilingual, so genuine Arabic-only output is
  unavailable.
- Several English paths read `DisplayOption.value`, which contains Arabic in
  the current API contract, causing cross-language leakage.
- Raw `header`, `subheader`, `number_prefix`, `terms`, and `footer` can leak into
  the wrong language.
- Most templates omit store VAT/CR, delivery phone, warranty, and the bank
  master/detail group.
- Some fields default to visible when a key is absent instead of requiring
  `visible == true`.
- Several delivery-phone implementations confuse the configured label with the
  order-supplied phone value.
- Most legacy templates make the VAT footer dependent on successful QR/ZATCA
  rendering.
- Date placement is inconsistent and often appears in the footer rather than
  invoice metadata.
- 112mm renders at 832 pixels but is sent through an 80mm ESC/POS profile.
- Legacy source classes still contain empty `buildPdf()` stubs, but production
  factory layouts now route through a real shared PDF fallback.
- Native-print implementations delegate to bitmap printing.
- Most layouts have no direct renderer tests.

## Canonical Receipt Contract

### Language

- Normalize once into `english`, `arabic`, or `bilingual`.
- Accept documented aliases without template-specific comparisons.
- English label priority: `default` -> English resolved label -> safe fallback.
- Arabic label priority: `value` -> Arabic resolved label -> safe fallback.
- Never use text containing only the opposite script as a single-language
  fallback.
- Document-level header/subheader/prefix/terms/footer use the same mode-aware
  resolver as display-option labels.
- English uses LTR. Arabic uses RTL. Bilingual direction and language order are
  explicit theme style options, not inferred from `language == ar`.

### Visibility

- A configured field prints only when its canonical option resolves to
  `visible == true`.
- Missing keys are hidden unless the contract explicitly marks a mandatory
  structural row.
- Parent switches, such as `showBankInfo`, gate their children.
- QR and VAT footer are independent switches.
- Labels and dynamic values are resolved separately.

### Dynamic Value Sources

| Source | Examples |
| --- | --- |
| Store/tax profile | store name, address, phone, email, VAT, CR |
| Order | invoice/date/token, customer, payment, comments, delivery, warranty |
| Calculated | subtotal, tax, discount, net total, balances, counts, amount in words |
| Bank | bank name, account name/number, IBAN, SWIFT |
| ZATCA/payment gateway | QR payload and payment QR fallback |
| Configuration | translated labels and direct headings/messages only |

No production renderer may print fake amounts, placeholder loyalty values,
hardcoded tax totals, or configured labels as business data.

### Canonical Section Order

1. Logo/icon
2. Extra headings
3. Store identity and tax registration
4. Invoice title and invoice metadata
5. Customer, payment, delivery, and comment details
6. Item-table header and item rows
7. Warranty/variant/item detail rows
8. Item and quantity counts
9. Totals, payment breakdown, balances, and amount in words
10. Returns, when present, followed by final summary
11. Bank details
12. QR code
13. VAT footer
14. Terms, thank-you message, configured footer, order reference, barcode

Themes may style or group sections differently, but may not silently reorder
business meaning or duplicate a field.

## Implementation Workstreams

### Phase 0 - Audit and Inventory

- [x] Capture the supplied 61-key Bill configuration.
- [x] Audit all 17 registered thermal themes in parallel families.
- [x] Identify language, visibility, data, ordering, paper, PDF, and test gaps.
- [x] Select Premium 2 Bilingual as the semantic reference.
- [ ] Convert the audit into a machine-readable theme capability matrix.

### Phase 1 - Shared Contract Foundation

- [x] Add `ReceiptLanguageMode` and one canonical alias normalizer.
- [x] Replace `ReceiptLayoutParams.isEnglish/isRtl/isBilingual` with the shared
  normalized mode while retaining compatibility getters.
- [x] Add a registry for all 61 canonical keys and accepted aliases.
- [x] Add shared strict visibility and parent/child resolution.
- [x] Add a mode-aware display-option label resolver.
- [x] Add a mode-aware document header/subheader/prefix/terms/footer resolver.
- [ ] Add typed dynamic-source resolvers for store, order, totals, bank, and QR.
- [ ] Add a canonical ordered receipt-content model independent of visual rows.
- [ ] Add explicit template capabilities: exact preview, thermal widths, PDF,
  native ESC/POS, bilingual direction/order.
- [x] Make unsupported output paths explicit instead of returning empty PDFs.

### Phase 2 - Reference Renderer

- [x] Refactor Premium 2 Bilingual to consume the shared contract without
  changing its printed appearance.
- [x] Preserve its correct VAT/CR, delivery phone, warranty, bank, VAT-footer,
  and language behavior.
- [ ] Add structural snapshots for all three language modes.
- [x] Add one-key-at-a-time visibility tests for all 61 keys.
- [x] Add all-visible, all-hidden, missing-key, empty-value, and alias tests.
- [x] Lock canonical ordering with renderer call-order tests.
- [x] Assert every canonical key is referenced by each active thermal renderer
  family (with the B2B title alias resolved upstream).

### Phase 3 - Template Migration Waves

#### Wave A: closest general-purpose layouts

- [x] Standard
- [x] Premium
- [x] Classic (production factory adapter)

#### Wave B: Premium variants

- [x] Premium 2 (production factory adapter)
- [x] Premium 1 (production factory adapter)

#### Wave C: duplicated bilingual family

- [x] Arabic & English (production factory adapter)
- [x] Arabic & English 2 (production factory adapter)
- [x] Arabic & English 3 (production factory adapter)
- [x] Bilingual (production factory adapter)
- [ ] Consolidate clones behind shared style definitions where visually safe.

#### Wave D: supermarket family

- [x] Supermarket 3 (production factory adapter)
- [x] Supermarket 2 (production factory adapter)
- [x] Supermarket (production factory adapter)
- [x] Supermarket 2 Bilingual (production factory adapter)

#### Wave E: specialized layouts

- [x] Multi Store, preserving active-store data precedence (production factory
  adapter uses the shared active-store params).
- [x] Mobile Shop Tax Invoice (production factory adapter; specialized clone is
  retained for future skin work).
- [x] Supermarket EN is migrated to the same three-mode contract through the
  production factory rather than remaining English-only.

For each migrated theme:

The production factory and all direct legacy entry points now use the shared
renderer/delegate. The historical clone bodies remain for visual reference and
are not treated as migrated skins until they pass the same checks.

- [ ] Remove direct/raw language comparisons.
- [ ] Replace local label selection with the shared resolver.
- [ ] Enforce strict visibility.
- [ ] Integrate every applicable dynamic group.
- [ ] Remove placeholder/hardcoded business values.
- [ ] Use canonical section ordering.
- [ ] Verify LTR/RTL column order.
- [ ] Verify no document-level language leakage.
- [ ] Register accurate capabilities.
- [ ] Add contract and renderer tests before marking ready.

### Phase 4 - Paper and Output Paths

- [x] Define supported raster widths and printer profiles for 58/80/112mm.
- [x] Confirm `esc_pos_utils_plus` 2.0.4 exposes only 58/72/80mm `PaperSize`
  values.  The shared `ThermalPaperProfile` marks 112mm as raster-only at
  832 dots and prevents native text paths from silently using mm80.
- [ ] Confirm the target printer accepts an 832-dot raster and add a per-device
  capability check if a model rejects that width.
- [ ] Test long Arabic/English product names and row wrapping at each width.
- [ ] Test large orders and part-one/part-two image splitting.
- [ ] Test logo, QR, barcode, drawer, feed, and cut behavior.
- [x] Keep A4/A5 in the standard PDF output path.  The six supported
  standard-PDF IDs now route through `ContractStandardPdfLayout`, with the
  remaining historical direct classes guarded by the same delegate.
- [x] Remove empty `buildPdf()` success paths for production thermal layouts;
  thermal output uses the shared adapter and A4/A5 output uses the maintained
  contract PDF renderer.
- [x] Document that 112mm native ESC/POS text is not supported by the current
  dependency; bitmap-backed output is used for the actual 832-dot width.

### Phase 5 - Preview and Settings

- [x] Provide a common configuration visibility preview for every theme.
- [x] Provide EN/AR/EN+AR preview controls.
- [x] Show all synced fields, sources, and visibility states.
- [ ] Move exact-preview support behind a generic layout capability/interface.
- [ ] Add exact previews as themes migrate to the shared renderer.
- [ ] Label common visibility previews separately from pixel-exact previews.
- [ ] Add a per-theme readiness/capability indicator in development mode.

### Phase 6 - Automated and Physical QA

- [x] Contract test: exactly 61 unique canonical Bill keys.
- [x] Contract toggle matrix: each key disabled individually, all disabled, all
  enabled.
- [x] Three language modes for every migrated thermal and A4/A5 theme path
  (EN, AR, and EN+AR aliases).
- [ ] Missing `default`, missing `value`, wrong-script value, and empty dynamic
  data cases.
- [ ] B2C, B2B, default customer, delivery, multi-payment, returns, warranty,
  bank, and ZATCA scenarios.
- [ ] 58mm, 80mm, and supported 112mm structural/golden tests.
- [ ] Real-printer matrix covering representative printer models.
- [ ] Final analyzer, unit, widget, renderer, and regression suite.
- [x] Publish the initial per-theme readiness matrix (this document); physical
  printer and golden-render approval remain pending.

## Definition of Done for One Theme

A theme is complete only when:

- it uses the shared language and configuration contract;
- EN contains no Arabic-only labels, AR contains no English-only labels, and
  bilingual contains both in the documented order;
- all 61 keys are either visibly supported or explicitly documented as not
  applicable;
- every visible dynamic field reads the correct runtime data source;
- every hidden field is absent, including when adjacent fields are visible;
- field order matches the canonical receipt order;
- RTL/LTR table columns and numeric direction are correct;
- QR, VAT footer, bank, warranty, and delivery behavior are independent and
  tested;
- missing data produces omission or an approved fallback, never placeholders;
- supported paper sizes render without clipping;
- preview capability is reported honestly;
- contract and renderer tests pass;
- a representative physical print has been approved.

## Execution Rule

Do not patch 17 large renderers independently. The production factory now
ensures that every legacy ID uses the shared contract renderer; a visual skin
may be reintroduced only after it passes the same contract tests. Complete the
shared contract and reference renderer first, then migrate one family at a
time. A migration wave is not complete until its tests are added and the
readiness matrix is updated.

## A4/A5 PDF Follow-up (separate migration track)

The standard PDF factory has six registered themes.  They now share the same
language, visibility, dynamic-data, bank, warranty, QR, VAT-footer, and section
ordering contract as thermal output.  The factory and every historical direct
class entry point delegate to `ContractStandardPdfLayout`; no caller can obtain
the old empty-document path accidentally.

The contract test matrix covers six themes × 3 language modes × A4/A5 (36
non-empty PDF documents), strict all-61-key visibility, aliases, and direct
legacy delegation.  This is functional coverage, not pixel-equivalent
reproduction of each historical skin: the active IDs intentionally share a
maintainable reference renderer until a visual skin is reintroduced behind the
same contract.

Remaining A4/A5 work is visual and device QA: render/golden review, long
Arabic/English wrapping, representative printer output, and any requested
theme-specific styling.  The common printer-settings preview remains a
configuration-visibility preview; it should only be called pixel-exact after
the selected renderer has a matching preview capability.
