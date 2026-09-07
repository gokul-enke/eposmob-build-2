# Translation — Live API Status Report

**Date:** 2026-09-04
**From:** Flutter/POS client
**To:** Backend
**Tested against:** `https://eposdemo.yougoit.in`, tenant `DEMO_FUNZCART`, company 2, store 2
**Contract:** `TRANSLATION_AGREED_SCOPE.md` (the eight resolved items)

I called every localized endpoint twice — once with no locale, once with
`?locale=ar` — and diffed the responses. This is what is actually on the wire
today, what already works, and the four things still blocking us.

Reproduction (fill in your own tenant/token):

```bash
S=https://eposdemo.yougoit.in
curl -s "$S/api/v1/master-data-values?code=PAYMENT_METHOD&store_id=2&locale=ar" \
  -H "X-Tenant: $TENANT" -H "Authorization: Bearer $TOKEN"
```

---

## Summary

Of the six localized endpoints, **only `list-delivery-methods` localizes
anything**. The rest ignore the locale entirely.

| Endpoint | `?locale=ar` vs no locale |
|---|---|
| `logistics/list-delivery-methods` | **differs** — `name` correctly resolved to Arabic |
| `master-data-values` (12 codes tested) | identical apart from `meta.requested_language` echoing `"ar"` |
| `product/list-units` | byte-identical |
| `cart/cart-item-statuses` | byte-identical |
| `website-settings` | byte-identical |
| `languages` | byte-identical |

`Accept-Language: ar` on its own behaves the same as `?locale=ar` on both
endpoints that respond to either, so there is no precedence conflict to worry
about right now. Good.

---

## What already works — no action needed

1. **`code` is populated on delivery methods.** `car-delivery`,
   `door-delivery`, `store-takeaway`, `third-party-logistics`, `toyou`,
   `hungerstation`, `dine-in`. This was the single hard dependency in the
   original handoff and it has shipped. Car-number and address validation now
   survive an Arabic session. Thank you — this was the one that could have
   broken checkout.
2. **`name` is correctly server-resolved per locale on delivery methods.**
   `Car Delivery` with no locale, `التوصيل بالسيارة` with `?locale=ar`.
3. **`master-data-values` `value` is frozen across locales**, and the additive
   `code` / `label` fields have shipped. This is exactly the governing rule from
   the scope doc being honoured.
4. **`product/list-units` no longer swaps `data`.** The feared behaviour — `PCS`
   becoming `قطعة` inside `data` and breaking unit resolution on the product,
   stock and purchase forms — is **not** happening. `data` is identical in both
   locales.
5. **`?locale=ml` degrades cleanly** to the base language rather than erroring.

---

## Blocking item 1 — `translations` on delivery methods is the raw table, not a map

This is the highest-value fix on the list.

**What you send:**

```json
"translations": [
  {
    "id": 200, "company_id": 2,
    "entity_type": "delivery_method", "entity_id": 147,
    "language_id": 4, "locale": "ar", "key": "name", "value": "تويو",
    "created_at": "2026-09-03 11:41:00", "updated_at": "2026-09-03 11:41:00",
    "language": {
      "id": 4, "name": "Arabic", "code": "ar", "type": "rtl", "active": 1,
      "created_at": "2025-12-18 23:36:18", "updated_at": "2025-12-18 23:36:18",
      "deleted_at": null
    }
  }
]
```

**What the contract specified:**

```json
"translations": { "en": "Car Delivery", "ar": "التوصيل بالسيارة" }
```

Two consequences:

- **It was being silently discarded.** The client's parser took `if (raw is not a
  Map) return {}`, so every delivery method came back with zero translations and
  the label fell through to the server-resolved `name`. Offline language
  switching — the entire reason the map ships inline — was dead. *We have now
  shipped a client-side parser for your row shape, so this is no longer broken
  in the field.* It is still worth fixing for the next point.
- **The payload is roughly 4× larger than it needs to be.** Every row repeats a
  complete `language` object — id, name, code, type, active and three
  timestamps — for a single string. We sync this to local storage for offline
  use, so the size is not free.

**Ask:** collapse to `{locale: value}` for the `name` column. If the row shape is
structurally easier on your side, we can live with it — but please at minimum
drop the nested `language` object and the timestamps.

### 1b. There is no `en` row

Every delivery method carries an `ar` translation and nothing else. The scope doc
(item 3) asked for the base language always to be emitted:

```json
"translations": { "en": "Car Delivery", "ar": "التوصيل بالسيارة" }
```

Right now this is survivable only because `code` is populated and the client
resolves identity from it. It leaves no second line of defence for a tenant
method whose code we do not recognise.

---

## Blocking item 2 — `master-data-values?locale=` does nothing

The parameter is accepted and echoed back, but no field changes.

```jsonc
// ?locale=ar
{
  "meta": { "requested_language": "ar" },   // <- only difference
  "data": [
    { "id": 7973, "value": "CARD", "description": "card",
      "code": "CARD", "label": "card", "translations": [] }
  ]
}
```

Two separate problems:

**(a) `translations` is `[]` on every row of every code.** I checked all twelve
codes the app consumes — `PAYMENT_METHOD`, `RACKS`, `TABLE_LIST`,
`PRODUCT_UNITS`, `CASH_DENOMINATIONS`, `EXPENSE_CATEGORY`, `CART_ITEM_STATUS`,
`STOCK_GROUPING_FIELDS`, `KOT_ITEM_NOTE_OPTIONS`, `DELIVERY_STATUS`,
`PAYMENT_STATUS`, `CURRENCIES` — 96 rows in total, 96 empty arrays. Nothing has
been seeded. It is also an array rather than `{}` (scope item 2, still open).

**(b) `description` / `label` are not locale-resolved.** Even once translations
exist, the pre-resolved label needs to follow the requested locale the way
`list-delivery-methods.name` already does.

**Ask:** seed the translation rows, cast to `(object)` before encoding, and make
`?locale=` resolve `description`/`label`.

Until both land, the client keeps `master-data-values` on its
"not yet localized" list. There is nothing to gain by switching it on early —
per-language cache keys would just double the cache for identical payloads.

---

## Blocking item 3 — `available_languages` is still dirty, and disagrees with `/languages`

`master-data-values` `meta`:

```json
"available_languages": ["ar", "en", "en-ar", "ml", "03", "ur"]
```

`GET /api/v1/languages`:

```json
{ "id": 7, "name": "tamil",           "code": "03",    "type": "ltr", "active": 1 }
{ "id": 8, "name": "English + Arabic","code": "en_ar", "type": "rtl", "active": 1 }
```

Three things:

- `"03"` is not a language code. It is stored against a language named *tamil* —
  presumably `ta` was intended.
- `"en_ar"` is not valid BCP-47, and it is not really a language — it looks like
  a bilingual print/display mode that has been filed in the language table.
- The two endpoints spell the same record differently: `en_ar` from
  `/languages`, `en-ar` from master-data `meta`. Whatever the resolution, they
  need to agree.

**Ask:** validate language codes at write time, and filter to known-good codes
before returning (scope item 4).

---

## Non-blocking, in priority order

### 4. `product/list-units` has no `labels` map

`data` is correctly frozen — thank you — but there is still no additive
`labels`, so units stay in the base language. Scope item 1:

```json
{
  "data":   { "1989": "KG",  "6953": "PCS" },
  "labels": { "1989": "كجم", "6953": "قطعة" }
}
```

### 5. Delivery methods have no capability flags

`requires_car_number`, `requires_address`, `icon_key`, `sort_order` are all
absent (scope item 5). The client currently infers behaviour from `code`, which
works for the four seeded standard methods but not for tenant-added ones —
`toyou`, `hungerstation` and `dine-in` all fall through to "requires nothing".
With the flags, a tenant can add a new delivery method without an app release.

### 6. `cart/cart-item-statuses` and `website-settings` ignore the locale

Both return byte-identical responses with and without `?locale=ar`.
`cart-item-statuses` already has the `translations` field in place, empty:

```json
{"id":2019,"value":"READY","description":"Ready","translations":[]}
```

### 7. Response headers

No `Content-Language`, and `vary` is `Accept-Encoding` only. Scope item 7 asked
for `Content-Language: <resolved>` so the client can detect that a fallback
occurred, and `Vary: Accept-Language, X-Tenant` if anything is cached at the
edge. `ETag` / `Cache-Control` for cheap `304`s on store switch is still a
nice-to-have.

### 8. Payload bloat

Every `master-data-values` row repeats the identical `master_data` object:

```json
"master_data": { "id":16, "name":"Payment Methods", "code":"PAYMENT_METHOD",
                 "type":"LST", "company_id":2,
                 "created_at":"...", "updated_at":"...", "deleted_at":null }
```

For the 27-row `PRODUCT_UNITS` response that is 27 copies of one object. Moving
it to `meta` once (scope item 7) would cut these payloads substantially, and we
sync them for offline use.

### 9. Master-data labels are lowercase

`PAYMENT_METHOD` returns `"description": "card"` / `"cash"` but `"UPI"`. The UI
renders these verbatim, so the payment buttons currently read "card" and "cash".
This is a data-entry tidy-up in the master-data admin rather than an API change.

---

## One question we need answered

**Is Malayalam in scope for master data?**

`GET /api/v1/languages` now returns:

```json
{ "id": 9, "name": "Malayalam", "code": "ml", "type": "ltr", "active": 1,
  "created_at": "2026-09-04 02:43:00" }
```

`TRANSLATION_AGREED_SCOPE.md` was negotiated as **en/ar only**, and the client's
wire-language allowlist is still `{en, ar}` — so a Malayalam session currently
requests `en` from the API and shows Malayalam UI chrome with English payment,
delivery and unit labels.

We need to know which it is:

- **In scope** → seed `ml` translation rows alongside `ar`, and we add `ml` to
  the allowlist.
- **Out of scope** → Malayalam stays UI-chrome-only, and we leave the allowlist
  alone. This is a perfectly reasonable answer; we just need it recorded so QA
  does not file the English labels as a bug.

---

## Client readiness — what happens when you push

The client half is **done and shipped**, built defensively so it behaves
identically against today's API and starts working the moment yours does. You
should not need to coordinate a release with us.

| Your change | What the app does |
|---|---|
| Seed master-data `translations` | Labels start resolving immediately. Parsed by `MasterDataValue`/`PaymentMethod`, which already read `translations` and re-resolve at render time. |
| `translations` as `{}` instead of `[]` | No-op — both shapes already parse, as does your delivery-method row shape. |
| Make `?locale=` resolve `description`/`label` | No-op — every master-data request already carries `?locale=` **and** `Accept-Language`, and caches are keyed per language. |
| Add delivery capability flags | Picked up automatically; `requires_car_number` / `requires_address` / `icon_key` / `sort_order` already override our inference. |
| Add `labels` to `list-units` | One line to delete on our side (`product/list-units` is the last entry in our not-yet-localized list). `UnitsResponse` already parses `labels` with a per-entry fallback to `data`. |
| Clean `available_languages` | No-op — we never consumed the dirty list. |

Two things to know:

- **We now request `ml` (Malayalam) as well as `en` and `ar`.** Verified that
  `?locale=ml` falls back cleanly to the base language today, so this is safe
  before you seed anything. See the question below.
- **We send `?locale=` and `Accept-Language` with the same value on every
  localized request**, so the resolved language is identical under either
  precedence rule. No transition window to coordinate when you make `?locale=`
  authoritative.

Verified against this tenant on 2026-09-04: all endpoints return `200` under
`en`/`ar`/`ml`, and the machine `value` fields are byte-identical across all
three locales for `PAYMENT_METHOD`, `RACKS`, `TABLE_LIST`, `PRODUCT_UNITS` and
`CASH_DENOMINATIONS` (52 rows). Please keep it that way — that freeze is what
makes the rest of this safe.

## Suggested order

| # | Item | Why first |
|---|---|---|
| 1 | Seed master-data translations + make `?locale=` resolve `description`/`label` | Unblocks the entire master-data half of the feature |
| 2 | `translations` → `{}` object, always including the base language | Same fix serves both master data and delivery methods |
| 3 | Clean `available_languages`; reconcile `en_ar` vs `en-ar` | Small, and stops us shipping junk codes to the picker |
| 4 | `labels` on `list-units` | Units are visible on every product row |
| 5 | Capability flags on delivery methods | Removes the need for an app release per new method |
| 6 | Headers, bloat, lowercase labels | Cleanup |

Items 1–3 are what the client is waiting on. Everything else we can absorb.

Happy to jump on a call if any of this is more expensive than it looks — as
before, the only non-negotiable is that **the label the user sees must never be
the thing the app branches on**.
