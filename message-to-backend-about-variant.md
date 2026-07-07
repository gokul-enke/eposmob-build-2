# Questions for Backend — Product Variants

Written 2026-07-07 while implementing the full product-variant system on
mobile per `PRODUCT_VARIANTS_API.md`. Everything below is implemented and
tests pass (589/589), but a few things in the doc were either unspecified or
had to be guessed defensively on the client. Need these confirmed/clarified
before we can trust the variant system in production.

---

## 1. `GET /api/v1/product/list-product-properties` — exact response shape

This is the biggest unknown. The API doc doesn't show a sample response for
this endpoint, so `lib/models/product_property.dart` parses **defensively**
against several possible shapes:

- Response could be a bare JSON array, or wrapped under `data` /
  `product_props` / `properties` / similar key — client currently tries all
  of these.
- For `LST`/`MLT` type properties, the allowed `values` could be a plain
  list of strings, or a list of `{id, value}` objects, or a keyed map —
  client tries all of these too.

**Please send:** a real sample JSON response for this endpoint (ideally one
`LST`, one `MLT`, and one `TXT` property in the sample so we can confirm all
three shapes). If the real shape doesn't match what the client guesses, the
attribute dropdowns in the variant editor will silently render empty with no
error — we'd rather fix the parser now than discover this in the field.

---

## 2. `PRODUCT_VARIANT_ENABLED` setting — value format

Confirm the exact format this arrives in from the settings API — is it:
- `"1"` / `"0"` (string)
- `true` / `false` (boolean)
- a nested status object like other flags

We mirrored the same parsing pattern used for existing boolean settings
(e.g. `itemCodeEnabled`) in `lib/models/get_app_settings.dart`, but please
confirm this setting is actually wired up server-side and sent in the normal
settings payload — if it's never sent, we default to `true` (variants stay
enabled), which may or may not be the intended default. **What should the
default be when the setting is absent from the response?**

---

## 3. `product_stocks.product_variant_id` — is it actually populated?

The API doc says stock rows carry `product_variant_id` when scoped to a
variant. Please confirm:

- This field is present on stock rows returned by the normal product-list /
  product-detail endpoints (not just documented, but actually populated
  today for tenants using variants).
- For **existing** stock rows created before variants existed on a product,
  is `product_variant_id` simply `null` (meaning "general stock"), or is
  there a migration step needed to scope old batches to variants?

If this field isn't populated yet, our variant-scoped stock filtering will
silently fall back to general/product-level stock for every sale — safe, but
it means variant-level stock accuracy won't actually work until this is
confirmed live.

---

## 4. Variant SKU auto-generation on edit

The doc says (§1, Create): `sku: null` auto-generates from product SKU +
attributes when creating a variant. Please confirm this **also** applies
when a **new** variant row (no `id`) is added to an existing product via the
**edit** endpoint (§2) — or does auto-generation only happen on the
create-product endpoint?

---

## 5. Attribute replace-on-edit — confirm full delete+recreate

Doc says (§2): "On every update the variant's attributes are fully replaced
(delete + recreate)". Client always sends the **complete** attribute set for
every variant on every edit (never a partial diff), matching this. Please
confirm this is genuinely destructive-and-recreate server-side and not, say,
an upsert-by-`product_prop_id` — if a client ever sends an incomplete
attribute set, we want to know the server will drop the missing attributes
rather than silently keep stale ones.

---

## 6. Sales return — variant stock restoration target

Doc §5 says returns operate on the original order item, which already
carries `product_variant_id`, and "stock is restored to the correct variant."
Please confirm restoration targets the **same variant-scoped stock batch**
(matching `product_variant_id` on the stock row) the sale was drawn from,
not general/product-level stock — otherwise variant-level stock counts will
drift over time as returns "leak" back into the wrong bucket.

---

## 7. Add-to-order with both `product_variant_id` AND a sale unit

Doc §4 shows `product_variant_id` and `sale_unit_id` as independent optional
fields on an order line. Please confirm the interaction is well-defined
server-side: e.g. scanning a CASE-unit barcode for a product that also has
variants — does stock validation apply the sale-unit conversion **on top
of** the variant-scoped stock, or does variant scoping only apply to
base-unit sales? We've implemented this client-side as "conversion rate
applies to whichever stock (variant-scoped or general) was resolved," but
would like this confirmed as the intended server behavior too.

---

## Not blocking, just FYI

- We default `PRODUCT_VARIANT_ENABLED` to `true` client-side when absent —
  see item 2, we'd like this confirmed either way.
- Printed/thermal receipts do not yet show variant attributes (on-screen
  order details and returns do) — this is a client-side follow-up, not a
  backend question, noted here for completeness. See `ENHANCEMENTS.md`
  §5 in the mobile repo.
