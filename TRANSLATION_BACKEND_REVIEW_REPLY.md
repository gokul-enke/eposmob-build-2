# Translation API — Flutter Review & Reply

**Re:** `TRANSLATION_FLUTTER_GUIDE.md` (backend commit `541d37f8`)
**From:** Flutter / POS client
**Status:** Approach accepted. 4 blocking items, 5 follow-ups.

---

## Summary

The overall design is correct and we can build on it. Tenant-scoped polymorphic
translations keyed by (entity, tenant, language, field) is a standard, sound
structure — we see no problem in the DB design itself.

These choices are right and we want them kept:

- `code` + `label` + `translations` on master-data values. Our existing
  `PaymentMethod.fromJson` already parses `code`, `label`, `enabled`,
  `sort_order`, `icon_key`, `behavior` and `requires_reference` with safe
  defaults, so this endpoint needs **zero client model changes**.
- The documented fallback chain: exact locale → base language → `en` → original.
- `meta.available_languages` / `meta.requested_language`.
- `code` explicitly **not** translated on delivery methods.
- The warning not to cache a localized response without the locale in the cache key.

Four items below block integration. Please confirm or correct each.

---

## BLOCKING

### B1. Product units — this is a breaking change, not an additive one

The guide states:

> With a locale, the value is the translated description; without a locale, it
> is the original unit value.

That silently changes the **meaning** of the map values, and it breaks us.

Our client resolves a product's stored unit by matching the stored string
against **both the key and the value** of that map
(`lib/features/billing/domain/add_product_form_helpers.dart`):

```dart
final normalizedUnit = trimmedUnit.toLowerCase();
for (final entry in unitList.entries) {
  if (entry.key.toLowerCase() == normalizedUnit ||
      entry.value.toLowerCase() == normalizedUnit) {
    return entry.key;   // resolved unit id
  }
}
return trimmedUnit;     // <-- unresolved fallback
```

A product saved with unit `PCS` matches today via `entry.value`. Once that value
becomes `قطعة`, the match fails, we hit the unresolved fallback, and the unit
dropdown on the product / stock / purchase forms renders blank or wrong.

The current shape (`Map<String, String>` of id → string) also has nowhere to put
`code`, `short_name`, `symbol`, or `decimal_places`, all of which we need.
`symbol` in particular must stay untranslated and stable — we parse it for
embedded-weight barcodes.

**Requested:** never overload one field with two meanings. Either:

*(a) preferred — return objects:*

```json
{
  "status": "success",
  "message": "Units found",
  "data": [
    {
      "id": 1,
      "code": "PCS",
      "value": "PCS",
      "label": "قطعة",
      "short_label": "حبة",
      "symbol": "pcs",
      "decimal_places": 0,
      "allow_fraction": false,
      "translations": {
        "en": { "label": "Pieces", "short_label": "pcs" },
        "ar": { "label": "قطعة",   "short_label": "حبة" }
      }
    }
  ]
}
```

*(b) minimum viable — keep the map, add a parallel one:*

```json
"data":   { "1": "PCS",  "2": "KG" },
"labels": { "1": "قطعة", "2": "كيلوغرام" }
```

Either way, `data` must keep returning the **original untranslated value**
regardless of `?locale=`. If you ship (a), tell us and we will version the parser.

---

### B2. Payment methods — master-data code mismatch

Your guide uses:

```
GET /api/v1/master-data-values?code=PAYMENT_METHODS
```

The app calls (`lib/resources/app_url.dart`):

```
GET /api/v1/master-data-values?code=PAYMENT_METHOD
```

Singular vs plural. **Which is the real seeded code?** If it changed, this is a
silent production break — payment methods come back empty and checkout falls to
the `CASH`-only default.

---

### B3. Casing of `value` and `code`

Your example returns lowercase:

```json
{ "value": "cash", "code": "cash", "label": "نقدي" }
```

We need to know whether this is real or just doc formatting.

- `PaymentMethod.fromJson` uppercases `code`, so **payment methods survive** either way.
- But `MasterDataValue.value` is consumed **raw** elsewhere — racks, table list,
  cart-item statuses, and stock grouping fields (`PRICE`, `MRP`,
  `PURCHASE_PRICE`, `UNIT`, `HSN_CODE`, `TAX_RATE`, `WHOLESALE_PRICE`,
  `WHOLESALE_MIN_UNIT`). Those are matched as UPPERCASE today.

**Requested:** confirm `value` casing is unchanged from before this commit. If
the translation layer lowercases it, that is a regression we need reverted.

---

### B4. `translations` map keys must be resolvable by base language

You normalize `ar_SA` → `ar-sa` and say the map is *"keyed by normalized locale."*

Our client looks up by Flutter's `Locale.languageCode`, which is `ar` — never
`ar-sa`. So if a tenant stores translations under `ar-SA`:

- your server-side `label` resolves correctly (good), but
- our client-side `translations['ar']` **misses**,

which defeats the entire purpose of shipping the map. We ship it so the user can
switch language **offline**, from cache, with no refetch — a hard requirement for
a POS that must keep billing when the network is down.

**Requested:** in the `translations` map, always key by **base language**
(`ar`, `en`, `hi`), collapsing regional variants. If you need region fidelity,
send both:

```json
"translations": { "ar": "نقدي", "ar-sa": "نقدي", "en": "Cash" }
```

Please also confirm `meta.available_languages` uses the same base-language keys.

---

## FOLLOW-UPS (not blocking this round)

### F1. Delivery methods — we need the real seeded codes, and capability flags

Your example shows `code: "standard-delivery"`, which matches none of the three
methods our billing flow branches on.

The client currently has **64 sites** comparing against the English display name
(`deliveryMethod == "Car Delivery"`, `== "Store Takeaway"`, `== "Door Delivery"`),
plus this in `DeliveryMethodsProvider`:

```dart
(method) => method.name.toLowerCase().contains('store takeaway')
```

Under Arabic that match fails and we fall back to a hardcoded
`DeliveryMethod(id: "11", name: "Store Takeaway")` — wrong id, wrong store.

**Please send the exact `code` values seeded for the existing methods** so we can
rewrite those 64 comparisons against `code` instead of `name`.

Better still, add the capability flags we originally asked for, so we branch on
behaviour rather than on identity:

```json
{
  "id": 2,
  "code": "car-delivery",
  "name": "توصيل بالسيارة",
  "translations": { "en": "Car Delivery", "ar": "توصيل بالسيارة" },
  "requires_car_number": true,
  "requires_address": false,
  "icon_key": "car",
  "sort_order": 2,
  "status": "Y",
  "prices": []
}
```

Without these we still hardcode — just on a safer key. With them, a tenant can
add "Drone Delivery" and the app needs no release.

Note on `status: "Y"` — please confirm the truthy set (`Y`/`N` only, or also
`1`/`0`/`true`/`false`), since we parse leniently.

### F2. Products, categories and customers are not covered at all

The guide covers website settings plus four reference lists. It does not mention
**products** — and in a POS the product name is the single most visible string on
screen. Same for category and customer names.

This is the larger half of the work and it is still open. Our proposal
(section 5 of `TRANSLATION_BACKEND_REQUIREMENTS.md`) was content negotiation
rather than inline `translations`, because inline is too heavy for thousands of rows:

```
GET /api/v1/product/list-products?store_id=12&locale=ar
```

```json
{
  "data": [
    { "id": 88, "sku": "BRD-001", "name": "خبز عربي",
      "name_original": "Arabic Bread", "translated": true },
    { "id": 89, "sku": "MLK-002", "name": "Fresh Milk 1L",
      "name_original": "Fresh Milk 1L", "translated": false }
  ]
}
```

**Please confirm whether this is planned, and roughly when.**

### F3. `/api/v1/languages` is unchanged

We want to drive the app's supported-locale list and language picker from the API
instead of the current hardcoded `[en, ar]`. For that we need two more fields on
the existing response:

- `native_name` — a language picker should read "العربية", not "Arabic".
- `is_default` — the tenant's default language. Without it, our client-side
  fallback chain is guesswork.

`code`, `type` (`ltr`/`rtl`) and `active` are already there and are enough otherwise.

### F4. Make `?locale=` always authoritative

Your precedence table is inconsistent:

| Endpoint | `?locale=` | `Accept-Language` |
|---|---|---|
| Website settings | yes | ignored |
| Master-data values | yes | **overrides** |
| Cart-item statuses | yes | ignored |
| Delivery methods | yes | **overrides** |
| Product units | yes | ignored |

We are adding `Accept-Language` to a shared header builder used by every request.
With this table, the header would silently win on 2 of 5 endpoints and be ignored
on the other 3 — producing bugs that are very hard to trace.

**Requested:** `?locale=` always wins when present; `Accept-Language` is only a
fallback when it is absent. Uniform across all endpoints.

Minor, while you are in there:

- Return `Content-Language: <resolved>` so we can detect that a fallback occurred.
- Add `Vary: Accept-Language, X-Tenant` if anything is cached at the edge.
- `ETag` + `Cache-Control` on the reference lists would let us do cheap
  `304 Not Modified` revalidation on store switch.

### F5. Per-row fallback signal (nice to have)

`meta.requested_language` tells us what we asked for, but not **which rows**
actually fell back to English. We want to surface "12 products are missing Arabic
names" to the tenant admin — that is what drives them to use the existing
`POST /api/v1/translate` button.

Either a per-row flag:

```json
{ "id": 3210, "code": "CHEQUE", "label": "Cheque",
  "translations": { "en": "Cheque" },
  "_fallback": { "requested": "ar", "served": "en" } }
```

or a count in `meta` / a response header (`X-Translation-Fallback-Count: 12`).

### F6. Cart-item statuses and website settings have no `translations` map

Only master-data values and delivery methods ship the map. Cart-item statuses and
website settings are server-resolved only, so those two cannot switch language
offline — they would need a refetch.

Probably acceptable for cart-item statuses (they are rarely user-facing chrome),
but flagging it so it is a deliberate decision rather than an oversight.

---

## What we are doing on the client meanwhile

Independent of your answers, we are starting:

1. Rewriting the 64 English-name comparisons to branch on delivery-method `code`
   (needed no matter how F1 is answered).
2. Adding a shared header/query builder so every request carries the locale.
3. Adding the locale to every cache key, per your checklist.

We will **not** enable localized master data in the app until B1–B4 are resolved,
because turning it on before then breaks unit resolution (B1) and delivery
validation (F1).

---

## Quick answer checklist

Please reply inline:

- [ ] **B1** — units: option (a) objects, or (b) parallel `labels` map?
- [ ] **B2** — `PAYMENT_METHOD` or `PAYMENT_METHODS`?
- [ ] **B3** — is `value` casing unchanged (still UPPERCASE)?
- [ ] **B4** — will `translations` be keyed by base language?
- [ ] **F1** — actual seeded `code` values for delivery methods, and can you add the flags?
- [ ] **F2** — are products / categories / customers planned? When?
- [ ] **F3** — can `native_name` and `is_default` be added to `/languages`?
- [ ] **F4** — can `?locale=` be made authoritative everywhere?
