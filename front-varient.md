# Frontend (Flutter) Product Variants — Implementation Audit

Scope: `lib/` Flutter app, audited against `PRODUCT_VARIANTS_API.md`.

## Summary

| # | Area | Status |
|---|---|---|
| 1 | Product create | Implemented, minor issue |
| 2 | Product edit (id/_delete semantics) | Implemented correctly |
| 3 | Variant list/detail parsing | Implemented, `images` field missing |
| 4 | Billing/cart | **Implemented only on mobile counter billing** — desktop and restaurant billing never resolve variants |
| 5 | Order details / receipts | Implemented correctly |
| 6 | Sales return | Implemented correctly |
| 7 | `PRODUCT_VARIANT_ENABLED` gating | Read correctly, default inconsistency |

---

## 1. Product Create — implemented, minor issue

`add_product_modal.dart:2790-2812` builds `variants[]` via `buildCreateVariantsPayload()` (`lib/features/products/domain/variant_form_payload.dart:83-89`), matching spec shape (`sku`, `barcode`, `price`, `mrp`, `purchase_price`, `active`, `attributes: [{product_prop_id, value}]`). Properties fetched from `GET /product/list-product-properties` per spec (`lib/providers/product_provider.dart:34-71`). Gated by `PRODUCT_VARIANT_ENABLED` (line 2192-2196).

**Minor gap:** `buildVariantJson` (`variant_form_payload.dart:70`) hardcodes `map['active'] = true` — there's no UI control to create a variant as inactive, even though the spec allows `active: false` on create.

---

## 2. Product Edit — implemented correctly

`product_details_dialog.dart:594-605` → `buildEditVariantsPayload(_variantController.toEditInputs())`. `VariantEditorController.toEditInputs()` (`variant_editor_section.dart:156-163`) emits `{id, markedForDeletion: true}` for removed rows, and `buildEditVariantsPayload` (`variant_form_payload.dart:94-107`) correctly turns these into `{id, _delete: true}`, plain `{...}` for new rows, `{id, ...}` for edits. Full attribute sets are always resent (matches spec's "fully replaced" rule).

No bugs found.

---

## 3. Variant list/detail display — implemented, one field missing

`lib/models/get_product.dart` `ProductVariant.fromJson` (line 1049) parses `id, sku, barcode, price, mrp, purchase_price, quantity, active, attributes` with matching names and defensive num/string coercion. `_parseVariantAttributes()` (line 21-54) correctly treats a `Map` as `{CODE: value}` per spec, though it also carries unused fallback logic for a `List` shape the spec never defines for this endpoint (harmless, but worth pruning once confirmed unnecessary against real responses).

**Bug: `images` not modeled at all.** The spec's variant object includes `images: [{url, alt, title}]`, but `ProductVariant` has no `images` field — variant-specific images are silently dropped, and the UI always falls back to product-level images (`mobile_variant_picker_sheet.dart:72-75` uses `product.attachment`, never variant images).

---

## 4. Billing/cart — implemented only on mobile counter billing

**Where it works:** `lib/features/billing/domain/add_product_with_variant.dart` resolves a variant (auto-pick single active variant, barcode match, or picker sheet), computes variant→product price/mrp precedence (`product_variant_selection.dart:86-110`), and forwards `selectedVariant` into `ProductCartHelper.handleProductSelection` (`lib/helpers/product_cart_helper.dart:70-208`), which:
- applies variant price/mrp precedence when no explicit override (line 183-191)
- scopes stock rows to the variant (`local_product_provider.dart:4166-4179`)
- builds the add-to-order payload with `product_variant_id` (`local_product_provider.dart:1313, 1341`)

This path is only reached from mobile counter-billing call sites: `product_autocomplete_list_mobile.dart:190`, `billing_mobile_controller.dart:545`, `market_product_grid.dart:57,89`.

**Bug/gap — desktop and restaurant billing never resolve a variant:** every other add-to-cart call site calls `ProductCartHelper.handleProductSelection` **directly**, so `selectedVariant` is always `null`:
- `lib/screens/billing/billing_page_desktop.dart:736`
- `lib/features/billing/presentation/pages/billing_page.dart:1513`
- `lib/widgets/product_autocomplete_list.dart:212`
- `lib/widgets/sidebar_product_list.dart:164`
- `lib/widgets/horizontal_product_view_local.dart:136`
- `lib/screens/billing/restaurant/restaurant_page.dart:3071`
- `lib/screens/billing/billing_page_restaurant.dart:1524,1655`

Consequence: for a variant-enabled product added via desktop or restaurant/table billing, no picker appears, `product_variant_id` is never sent, stock is checked only at general-product level (wrong when stock is variant-scoped), and price uses the plain product price instead of the variant's. The existing `RESTAURANT_MOBILE_UI_CHANGES_NEEDED.md` notes flag the restaurant-mobile gap as a known old-codepath issue, but **desktop billing has the identical gap and isn't mentioned there** — it never had variant resolution built in the first place.

**Fix:** route all the call sites above through the same variant-resolution flow used by mobile counter billing (`add_product_with_variant.dart`) before calling `handleProductSelection`.

---

## 5. Order details / receipts — implemented correctly

`lib/models/order_details.dart`: `OrderDetailsModelDataCartItem` parses `product_variant_id` (line 542) and `variant_attributes` (line 543, handles Map or JSON-string). Displayed in `lib/screens/sales/widgets/buid_order_details_widget.dart:1002-1005,1123-1125` via `formattedVariantAttributes`. Matches spec's snapshot behavior.

---

## 6. Sales Return — implemented correctly

`SalesReturnCart` (`lib/models/list_sales_return_items.dart:63-143`) parses and displays `product_variant_id`/`variant_attributes` (`lib/screens/sales_return/sales_return.dart:1803-1806`). Per spec, the return submission itself needs no extra variant fields — confirmed nothing extra is sent in `sales_return.dart`/`sales_provider.dart`. Correct.

---

## 7. `PRODUCT_VARIANT_ENABLED` gating — read correctly, default inconsistency

`lib/models/get_app_settings.dart:56,95,201,420` defines `productVariantEnabled`, gating the properties fetch and variant editor visibility in both `add_product_modal.dart` and `product_details_dialog.dart`.

**Inconsistency:** the model field defaults to `false` (`get_app_settings.dart:95`), but every consuming call site defaults missing/null to `true` (`?? true`, e.g. `add_product_modal.dart:2193`, `product_details_dialog.dart:1679`, `add_product_with_variant.dart:33-34`). Not a crash risk, but if settings fetch fails or races, variant UI could show for a tenant that has it disabled.

**Fix:** standardize on one default (recommend `false`/closed, matching the model) across all call sites.

---

## Priority fix list

1. **High** — Wire desktop billing and restaurant/table billing through variant resolution (same flow as mobile counter billing) so `product_variant_id`, variant pricing, and variant stock scoping work everywhere, not just mobile counter billing.
2. **Medium** — Add `images` parsing/display to `ProductVariant` model so variant-specific images aren't dropped.
3. **Low** — Allow creating a variant as inactive (remove hardcoded `active: true` in `variant_form_payload.dart:70`).
4. **Low** — Standardize `productVariantEnabled` default across model and call sites.
