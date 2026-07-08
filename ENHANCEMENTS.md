# Enhancements & Architecture Review

Living notes on structural/UX gaps found while implementing the product-variant
system and auditing cart/billing flows (2026-07). Intended as durable context
for whoever (human or agent) picks up the next pass — each point names the
concrete files involved so a fresh agent doesn't have to re-derive them.

Related: `docs/cart_billing_flows_analysis.csv` (F01–F48, per-flow business
scenarios + current handling + gaps) and `PRODUCT_VARIANTS_API.md` (variant API
contract).

---

## 1. Consistency debt — the same behavior is implemented more than once

The codebase grew by accretion: a given action (e.g. "add product to cart")
has multiple independent implementations that drifted apart over time instead
of one owned code path everyone calls.

- **Two competing add-to-cart entry points.** `lib/helpers/product_cart_helper.dart`
  (`ProductCartHelper.handleProductSelection`) is the real, actively-used path —
  it has sellable checks, variant-OOS oversell confirmation, zero-price
  handling, stock-modal handling. `lib/helpers/stock_selection_helper.dart`
  (`handleAddProductToCart`) duplicated the same job without any of those
  guards and had **zero callers** anywhere in `lib/` — deleted 2026-07-07.
  If a new screen is ever wired to a "convenient" helper instead of
  `ProductCartHelper`, this class of bug reappears. **There should be exactly
  one add-to-cart function**, and screens should not implement ad hoc
  alternatives.
- **Variant out-of-stock handling was inconsistent across entry points**
  before this session's fixes: the grid tap path, the barcode-scan path
  (`lib/features/billing/domain/product_variant_selection.dart`), and the
  variant picker sheet (`lib/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart`)
  each had their own OOS logic. Now unified around "always resolve, let
  `ProductCartHelper` ask for oversell confirmation" — but this pattern
  (parallel logic across barcode/grid/picker) is a recurring failure mode
  worth grepping for elsewhere (e.g. sale-unit resolution, zero-price entry).
- **Recommendation:** establish one canonical "line-item builder" module that
  every entry point (grid tap, barcode scan, variant picker, quick-add,
  quantity stepper) calls into, instead of each surface re-implementing
  stock/variant/price resolution.

---

## 2. Silent failure culture (historically)

Before this session's fixes, many "the sale can't proceed as-is" moments in
`lib/helpers/product_cart_helper.dart` failed **silently** — no toast, no
dialog, just a `return` — leaving the cashier unsure whether tapping "add"
did anything:

- Stock-selection modal dismissed → previously silent, now shows
  `BillingMobileErrorMessages.stockNotSelected` toast.
- Zero-price quick-entry cancelled → previously silent, now shows
  `BillingMobileErrorMessages.zeroPriceEntryCancelled` toast.
- OOS variant / insufficient sale-unit stock → previously a hard block with
  no path forward; now `showSellAnywayConfirmDialog`
  (`lib/components/build_dialog_box.dart`) offers an explicit oversell
  confirmation instead of failing at all.
- `LocalProductProvider.addToCart` (`lib/providers/local_product_provider.dart`)
  used a `firstWhere` on `productId` that could throw on an unsynced product
  — now falls back safely via `getProductById(...) ?? product`.

**Audit needed:** grep the rest of the app (purchase flow, customer
create/edit, discount/coupon apply, held-order restore) for bare `return;`
after a validation failure with no `showScaffoldError`/`showScaffold` call.
This pattern likely repeats outside billing.

---

## 3. API contract ambiguity between backend and mobile

- `lib/models/product_property.dart` (parses
  `GET /api/v1/product/list-product-properties`, wired up in
  `lib/providers/product_provider.dart` `fetchProductProperties()`) was
  written **defensively against a guessed response shape** — the API doc
  (`PRODUCT_VARIANTS_API.md`) doesn't show this endpoint's payload. It
  tolerates a bare list or several possible wrapper keys, and LST/MLT values
  as either plain strings or `{id,value}` maps. **This needs verification
  against a real API response**; if the live shape differs from all the
  guessed variants, the variant-editor attribute dropdowns in
  `lib/widgets/add_product_modal.dart` and `lib/widgets/product_details_dialog.dart`
  will silently render empty with no error surfaced to the admin.
- More broadly: `Stock.productVariantId` (`lib/models/get_product.dart`),
  the `PRODUCT_VARIANT_ENABLED` setting parsing in
  `lib/models/get_app_settings.dart`, and the `variants[]` create/edit
  payload builder (`lib/features/products/domain/variant_form_payload.dart`)
  were all implemented purely from the written API doc, not a live contract
  test against the actual backend. **Recommendation:** an integration
  smoke-test hitting a real (or recorded/mocked-from-real) backend response
  would catch drift that unit tests against hand-written fixtures cannot.

---

## 4. No shared design system / component library

UI is hand-built per screen: raw `Container` + `BoxDecoration` + manually
chosen `Colors.grey.shadeNNN` / hardcoded paddings, rather than a shared
component library with tokens for spacing, color, typography, and touch
targets. Concrete evidence from this repo:

- Currency symbol was hardcoded `SAR` in multiple product-card/cart widgets
  even for an INR tenant, fixed ad hoc per-widget rather than via a single
  currency-formatting utility (see prior session's `MOBILE_PARITY_REVIEW.md`
  fix log, referenced in memory).
  the resources dir. `lib/resources/color_manager.dart`,
  `lib/resources/font_manager.dart`, `lib/resources/style_manager.dart` exist
  and are used, but as a raw values file, not encapsulated components — every
  screen re-derives its own `Container`/`InkWell`/`ElevatedButton` styling
  inline (see the `_buildSquareActionButtonStyle()`, `_buildTextField(...)`
  helpers duplicated per-modal in `lib/widgets/add_product_modal.dart` and
  presumably `lib/widgets/product_details_dialog.dart`, rather than shared
  widgets).
- Widespread use of the deprecated `Color.withOpacity(...)` instead of
  `.withValues()` across many files (flagged by the analyzer during this
  session in `lib/widgets/add_product_modal.dart`,
  `lib/screens/sales/widgets/buid_order_details_widget.dart`,
  `lib/screens/sales_return/sales_return.dart`, and others) — cosmetically
  harmless today but a sign there's no lint-enforced style baseline being
  kept current.
- Touch target sizes (44px accessibility minimum) had drifted below spec on
  some mobile cart controls and needed a manual pass to fix (see
  `test/mobile_accessibility_test.dart` and the 2026-07-01 fix log in
  project memory) — a shared button/row component with an enforced minimum
  size would make this a non-issue by construction.

**Recommendation:** extract a small internal widget kit (buttons, form
fields, section headers, bottom-sheet chrome, dialog chrome) used by every
screen, so visual/behavioral consistency (spacing, touch targets, currency
formatting, color) is enforced structurally instead of by convention +
manual review.

---

## 5. Receipts are a second, drifting source of truth

The on-screen order-details/sales-return views and the printed
receipt/thermal pipeline read from **different models**, so a feature can
land on screen without landing on paper:

- On-screen: `lib/models/order_details.dart`
  (`OrderDetailsModelDataCartItem`, `OrderReturnItem`) and
  `lib/models/list_sales_return_items.dart` (`SalesReturnCart`) now carry
  `productVariantId` / `variantAttributes` and render them
  (`lib/screens/sales/widgets/buid_order_details_widget.dart`,
  `lib/screens/sales_return/sales_return.dart`).
- Printed receipts: sourced from a **separate receipt-params pipeline**
  (not yet located/updated — flagged but deliberately not touched this
  session because it's "gnarly" per the implementing subagent's report).
  Variant attributes ("Red | L") are therefore invisible on a printed
  receipt even though they're shown in-app, which will confuse
  exchange/return reconciliation at the counter.
- **Action needed:** locate the receipt/print template code (search for
  wherever `order_details.dart`/checkout data is transformed into
  print/PDF/thermal text — likely under a `lib/screens/.../print` or
  `lib/services/` receipt builder) and either (a) make it consume the same
  models as the on-screen views, or (b) explicitly thread
  `variantAttributes` into whatever intermediate receipt-line struct it
  uses today. This is flow **F41/F42/F47** in
  `docs/cart_billing_flows_analysis.csv`.

---

## 6. Stock-selection modal doesn't label variant-scoped batches

`lib/widgets/stock_selection_modal.dart` (`StockSelectionModal`) shows
pricing-group batches (`groupStocksByPricing`,
`lib/providers/local_product_provider.dart`) to the cashier when a product
has multiple stock groups, but doesn't indicate *which variant* each batch
belongs to now that `Stock.productVariantId`
(`lib/models/get_product.dart`) exists. For a multi-variant product with
several variant-scoped batches, a cashier picking a batch has no visual cue
which variant it's for. Flow **F48** in the CSV. Cosmetic/UX gap, not a
correctness bug — filtering itself is correct
(`LocalProductProvider.filterStocksForVariant`).

---

## 7. Prioritized fix list (as of 2026-07-07)

1. ~~Delete dead `lib/helpers/stock_selection_helper.dart`~~ — **done**.
2. Verify `list-product-properties` real response shape against
   `lib/models/product_property.dart` / `lib/providers/product_provider.dart`
   and surface a fetch-failure toast in the variant editors
   (`lib/widgets/add_product_modal.dart`, `lib/widgets/product_details_dialog.dart`)
   instead of silently rendering an empty attribute list.
3. Thread variant attributes into the printed-receipt pipeline (location TBD
   — needs discovery pass) so paper receipts match on-screen order details.
4. Label variant-scoped batches in `lib/widgets/stock_selection_modal.dart`.
5. Audit non-billing flows (purchase, customer, discount/coupon, held-order
   restore) for the same silent-`return`-on-failure pattern found and fixed
   in `lib/helpers/product_cart_helper.dart` (§2 above).
6. Longer-term: extract a shared widget kit (§4) and a single canonical
   line-item/add-to-cart contract (§1) — both are multi-day refactors, scope
   with the user before starting.

---

## How to use this file

When asking a future agent to continue this work, point it at this file plus
`docs/cart_billing_flows_analysis.csv` — between the two it has the full
picture (what flows exist, how they're handled today, and what structural
issues were already identified) without needing to re-read the whole
codebase from scratch.
