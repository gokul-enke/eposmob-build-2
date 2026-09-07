# Multi-Language / Translation System - Backend Handoff & Design Review

**Status:** Proposal, awaiting backend review
**Author:** Flutter side (EPOS Mobile / `pos_machine`)
**App version at time of writing:** 1.0.48+60

---

## 0. What I need from you

This document proposes how translations should flow from the API into the POS app.
**Please review it and tell me whether the approach is correct**, or whether it
creates complications on your side — especially in the **database structure**.
There is a list of specific open questions in [Section 9](#9-open-questions-for-backend).

The short version of the proposal:

- **Master / reference data** (payment methods, delivery methods, units, order
  statuses, taxes, racks) → return **all active languages inline** in one payload.
- **Tenant free text** (product names, category names, customer names) → return a
  **single negotiated language** via the `Accept-Language` header.
- Every master-data row must carry a **stable machine `code`** that never changes
  per language, because the app branches on it.

---

## 1. Current state

### 1.1 Static UI strings — already working

The app ships JSON bundles and translates with GetX.

- `lib/resources/i18n/en.json`, `lib/resources/i18n/ar.json`
- Loaded at startup by `lib/resources/localization_service.dart`, flattened from
  nested JSON into dot-notation keys (`billing.cash`, `common.select`).
- Registered on `GetMaterialApp` in `lib/main.dart`.
- ~5,255 `.tr` call sites project-wide, 217 inside the billing feature.

**No backend involvement needed here.** This part is done.

### 1.2 Language master data — exists, but only used for data entry

```http
GET /api/v1/languages
```

Parsed by `lib/providers/language_provider.dart` into
`lib/models/language.dart` → `{ id, name, code, type (ltr|rtl), active }`.

```http
POST /api/v1/translate
Body: { "target_lang": "ar", "text": "Beverages" }
```

Used only in the **Add/Edit Category** screens, where an admin types a name and
presses a button to machine-translate it into the other languages
(`lib/screens/category/category_form_mixin.dart`).

**Important gap:** neither of these drives the app's runtime language list.
`LocalizationService.supportedLocales` is currently **hardcoded** to `[en, ar]`,
and the language picker in Settings hardcodes two radio buttons. So whatever
languages you mark active in the backend are currently ignored by the POS.

### 1.3 Master data — single language, no translation at all

| Data | Endpoint | Model / shape |
|---|---|---|
| Payment methods | `GET /api/v1/transaction/get-payment-methods` | `{ id, value, description }` |
| Delivery methods | `GET /api/v1/logistics/list-delivery-methods` | `{ id, name, prices[] }` |
| Units | `GET /api/v1/product/list-units` | `{ id, name, ... }` |
| Racks | `GET /api/v1/master-data-values?code=RACKS` | `{ id, value, description }` |

The generic master-data shape is `MasterDataValue { id, value, description }`
(`lib/models/master_data.dart`), where:

- `value` = machine code (`CASH`, `CARD`, `UPI`)
- `description` = human label

**There is exactly one label, in one language, per row.**

### 1.4 No language is ever sent on a request

A grep across the whole Flutter codebase finds **zero** occurrences of
`Accept-Language` or a `lang` query parameter. Headers are hand-built in 46
separate files and currently only carry `X-Tenant`, `Content-Type` and
`Authorization`.

---

## 2. The problem on the app side (we will fix this first)

Before any translated label can be shipped, the app has a bug that must be fixed:
**64 places compare against the English display name.**

```dart
// lib/features/billing/presentation/pages/billing_page.dart:6681
if (deliveryMethod == "Car Delivery" && _carNumberController.text == "") { ... }

// lib/features/billing/presentation/widgets/checkout_modal.dart:2589
if (_lDeliveryMethod == "Car Delivery") ...

// lib/features/billing/presentation/widgets/quick_access_bar.dart:50
final icon = dm == "Store Takeaway" ? ... : dm == "Car Delivery" ? ...

// lib/providers/billing_provider.dart:1858
if (_deliveryMethod == "Car Delivery" && _carNumber.isEmpty) { ... }
```

The moment the API returns `"توصيل بالسيارة"`, car-number validation stops firing,
delivery icons fall back to the default, and delivery-charge lookup mismatches.

The rule we will enforce app-side:

> **`id` / `code` for logic, persistence and the wire.
> `label` for pixels only.**

Payment methods already do this correctly — `lib/models/payment_method.dart`
uppercases `value` into a `code` field and branches on a `behavior` enum.
**Delivery methods and units need the same treatment from your side.**

Note that `DeliveryMethod` in `lib/models/delivery_method.dart` **already has a
`code` field** — the API just never sends it, so it is always `null`.

---

## 3. Three classes of translatable string

They need different mechanisms, and the difference matters because the POS runs
**offline** and caches data in local storage.

| Class | Examples | Volume | Proposed mechanism |
|---|---|---|---|
| **A. Static UI** | "Checkout", "Add to cart" | Fixed | Shipped in app JSON — **no backend work** |
| **B. Master / reference data** | Payment methods, delivery methods, units, statuses, taxes | 5–30 rows | **All languages inline**, one payload |
| **C. Tenant free text** | Product names, category names, customer names | Thousands of rows | **`Accept-Language` negotiation**, single language |

**Why the split:** master data is cached per store in local storage. If we cache
only the active language, switching language while offline shows stale labels.
Master data is small enough that shipping all languages costs a few KB. Products
are not — we cannot afford N copies of every product name in one payload.

---

## 4. Proposed contract — Class B (master data)

### 4.1 Payment methods

**Request**

```http
GET /api/v1/transaction/get-payment-methods?store_id=12
Host: {tenant}.enkepos.com
X-Tenant: {api_key}
Authorization: Bearer {access_token}
Accept: application/json
Accept-Language: ar-SA, ar;q=0.9, en;q=0.5
X-App-Version: 1.0.48
```

We will still send `Accept-Language` (it decides the pre-resolved `label` and the
fallback chain), but for master data the client does **not** depend on it.

**Response headers**

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Content-Language: ar
Vary: Accept-Language, X-Tenant
ETag: "pm-12-a3f9c1"
Cache-Control: private, max-age=300, stale-while-revalidate=86400
X-Available-Languages: en,ar,hi
X-Default-Language: en
```

`ETag` + `Cache-Control` matter: the app already does a cache / force-refresh
dance per store, and a `304 Not Modified` on `If-None-Match` makes store switching
cheap.

**Response body**

```json
{
  "status": "success",
  "message": "Payment methods fetched",
  "meta": {
    "default_language": "en",
    "available_languages": ["en", "ar", "hi"],
    "requested_language": "ar",
    "translation_version": 47
  },
  "data": [
    {
      "id": 3200,
      "value": "CASH",
      "code": "CASH",
      "description": "نقدي",
      "label": "نقدي",
      "translations": {
        "en": "Cash",
        "ar": "نقدي",
        "hi": "नकद"
      },
      "enabled": true,
      "sort_order": 1,
      "icon_key": "cash",
      "behavior": "collected",
      "requires_reference": false
    },
    {
      "id": 3201,
      "value": "CARD",
      "code": "CARD",
      "description": "بطاقة",
      "label": "بطاقة",
      "translations": { "en": "Card", "ar": "بطاقة", "hi": "कार्ड" },
      "enabled": true,
      "sort_order": 2,
      "icon_key": "card",
      "behavior": "collected",
      "requires_reference": false
    },
    {
      "id": 3204,
      "value": "DEBIT",
      "code": "DEBIT",
      "description": "آجل",
      "label": "آجل",
      "translations": { "en": "Credit", "ar": "آجل", "hi": "उधार" },
      "enabled": true,
      "sort_order": 99,
      "icon_key": "credit",
      "behavior": "credit",
      "requires_reference": false
    }
  ]
}
```

**Why this is safe to ship:**

1. `value` and `description` stay exactly where they are — every existing consumer
   keeps parsing unchanged.
2. `description` / `label` are **pre-resolved by the server** to the requested
   language, so older app builds that ignore `translations` still show the right
   language.
3. `translations` is purely **additive**. New builds switch language instantly
   with no network call, which is what makes offline language switching work.

`behavior` is an existing app concept, not new — it is one of
`collected` | `credit` | `terminal`, and the app already infers it from the code
when absent. Sending it explicitly is optional but preferred.

### 4.2 Delivery methods

Same shape, **plus the missing `code` and capability flags**.

```http
GET /api/v1/logistics/list-delivery-methods?store_id=12
```

```json
{
  "status": "success",
  "data": [
    {
      "id": "1",
      "code": "STORE_TAKEAWAY",
      "name": "استلام من المتجر",
      "translations": { "en": "Store Takeaway", "ar": "استلام من المتجر" },
      "icon_key": "store",
      "requires_car_number": false,
      "requires_address": false,
      "sort_order": 1,
      "prices": []
    },
    {
      "id": "2",
      "code": "CAR_DELIVERY",
      "name": "توصيل بالسيارة",
      "translations": { "en": "Car Delivery", "ar": "توصيل بالسيارة" },
      "icon_key": "car",
      "requires_car_number": true,
      "requires_address": false,
      "sort_order": 2,
      "prices": [{ "id": "9", "delivery_method_id": "2", "price": 5.0 }]
    },
    {
      "id": "3",
      "code": "DOOR_DELIVERY",
      "name": "توصيل للمنزل",
      "translations": { "en": "Door Delivery", "ar": "توصيل للمنزل" },
      "icon_key": "home",
      "requires_car_number": false,
      "requires_address": true,
      "sort_order": 3,
      "prices": [{ "id": "10", "delivery_method_id": "3", "price": 10.0 }]
    }
  ]
}
```

`requires_car_number` and `requires_address` are the **real** fix for the 64
string comparisons. Branching on `code` is the minimum; branching on capability
flags is what scales when a tenant adds "Drone Delivery" or "Pickup Point".

Orders already send `delivery_method_id` on the wire
(`lib/features/billing/domain/quotation_checkout.dart`), so **the order payload
format does not change**. Only display and UI branching are affected.

### 4.3 Units — nested, because two fields are translated

```http
GET /api/v1/product/list-units?store_id=12
```

```json
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "code": "KG",
      "name": "كيلوجرام",
      "short_name": "كجم",
      "symbol": "kg",
      "translations": {
        "en": { "name": "Kilogram", "short_name": "kg" },
        "ar": { "name": "كيلوجرام", "short_name": "كجم" }
      },
      "decimal_places": 3,
      "allow_fraction": true
    },
    {
      "id": 6,
      "code": "PCS",
      "name": "قطعة",
      "short_name": "حبة",
      "translations": {
        "en": { "name": "Pieces", "short_name": "pcs" },
        "ar": { "name": "قطعة", "short_name": "حبة" }
      },
      "decimal_places": 0,
      "allow_fraction": false
    }
  ]
}
```

**`symbol` must stay untranslated and immutable.** It is the canonical identity
used for embedded-barcode weight parsing
(`lib/features/billing/domain/barcode_sale_unit.dart`) and must not vary by locale.

### 4.4 Fallback rule (must be implemented server-side)

Resolution order for any label:

1. Requested language (`Accept-Language`)
2. Tenant default language
3. `en`
4. The raw machine `code`

**Never return `null` or an empty string for a label.** If a fallback was used,
please say so, so the tenant admin can be told what is untranslated:

```json
{
  "id": 3210,
  "code": "CHEQUE",
  "label": "Cheque",
  "translations": { "en": "Cheque" },
  "_fallback": { "requested": "ar", "served": "en" }
}
```

### 4.5 Languages endpoint — needs two extra fields

```http
GET /api/v1/languages?store_id=12
```

```json
{
  "status": "success",
  "data": [
    { "id": 1, "name": "English", "native_name": "English", "code": "en", "type": "ltr", "active": true,  "is_default": true,  "completion": 100 },
    { "id": 2, "name": "Arabic",  "native_name": "العربية", "code": "ar", "type": "rtl", "active": true,  "is_default": false, "completion": 96 },
    { "id": 3, "name": "Hindi",   "native_name": "हिन्दी",  "code": "hi", "type": "ltr", "active": false, "is_default": false, "completion": 40 }
  ]
}
```

- `native_name` — a language picker should read "العربية", not "Arabic".
- `is_default` — drives the fallback chain above.
- `completion` (optional) — lets us warn an admin before they enable a language.

`type: ltr|rtl` already exists and is already parsed (`Language.isRtl`); it is
just not used at runtime yet. We will wire it up.

---

## 5. Proposed contract — Class C (products, categories, customers)

Inline translations are too expensive here. Use content negotiation.

```http
GET /api/v1/product/list-products?store_id=12&page=1&per_page=200
Accept-Language: ar
X-Tenant: {api_key}
Authorization: Bearer {access_token}
```

```http
HTTP/1.1 200 OK
Content-Language: ar
Vary: Accept-Language, X-Tenant
X-Translation-Fallback-Count: 12
```

```json
{
  "status": "success",
  "data": [
    {
      "id": 88,
      "sku": "BRD-001",
      "name": "خبز عربي",
      "name_original": "Arabic Bread",
      "translated": true,
      "unit_id": 6,
      "unit_code": "PCS"
    },
    {
      "id": 89,
      "sku": "MLK-002",
      "name": "Fresh Milk 1L",
      "name_original": "Fresh Milk 1L",
      "translated": false
    }
  ]
}
```

`translated: false` plus `X-Translation-Fallback-Count` let us show the tenant
admin "12 products are missing Arabic names" — which is exactly what the existing
`POST /api/v1/translate` machine-translate button is for.

**Offline caveat (app side, noted for context):** the app's offline sync
(`lib/providers/offline_sync_endpoints.dart`) pulls products, categories, units
and racks into local storage. With header negotiation, the local cache holds one
language, so we will key the product cache by language
(`products_cache_{storeId}_{langCode}`) and sync once per active language.

---

## 6. Database structure implications (please sanity-check this)

This is the part most likely to be complicated on your side. The usual shape is a
sibling translations table per translatable entity:

```
payment_methods            payment_method_translations
-----------------          ---------------------------------
id            PK           id                 PK
code          UNIQUE       payment_method_id  FK
enabled                    language_code      (or language_id FK)
sort_order                 label
icon_key                   UNIQUE (payment_method_id, language_code)
behavior
```

Same pattern for `delivery_methods`, `units` (two translated columns), and any
generic `master_data_values`.

Points worth deciding together:

1. **Generic master data.** `master_data_values` is a shared table
   (`{ id, value, description }`) serving payment methods, racks, KOT notes and
   more. One `master_data_value_translations` table keyed by
   `(master_data_value_id, language_code)` covers all of them at once, rather than
   one table per concept. Does that fit your current schema?
2. **Existing `description` column.** Keep it as the tenant-default-language
   value so nothing breaks, and treat the translations table as an overlay. Or
   migrate `description` into the translations table as the `en` row and make the
   column a generated/derived field. Your call — I only need the API shape to stay
   as described.
3. **Global vs tenant-scoped translations.** Payment methods and units are largely
   the same for every tenant, so their translations could be seeded globally and
   overridden per tenant. Delivery methods and categories are tenant-owned. Does
   your master data already distinguish global rows from tenant rows?
4. **Where does `code` come from for existing delivery-method rows?** They only
   have a name today. Backfilling `code` from the English name
   (`"Car Delivery"` → `CAR_DELIVERY`) is the obvious migration, but existing
   tenants may have renamed them. See question 3 in Section 9.
5. **`translation_version`.** A single integer bumped whenever any translation for
   a tenant changes would let the app skip refetching master data entirely. Cheap
   to add if you already have a settings/version row; skip it if not.

---

## 7. App-side work (for context — no backend action needed)

1. Add a shared `ApiHeaders` helper and send `Accept-Language` on every request
   (headers are currently hand-built in 46 files).
2. Replace all 64 English-name comparisons with `code` / capability-flag checks.
3. Add a `LocalizedLabel` mixin so models resolve `label` at render time from the
   `translations` map — a language switch then needs no network call.
4. Drive `LocalizationService.supportedLocales` and the Settings language picker
   from `GET /api/v1/languages` instead of the hardcoded `[en, ar]`.
5. Wire up RTL from `Language.type`.
6. Language-suffixed offline cache keys for products/categories.

---

## 8. Suggested rollout order

| # | Change | Side | Breaking? |
|---|---|---|---|
| 1 | Add `code` + `requires_car_number` / `requires_address` to delivery methods | Backend | No — additive |
| 2 | Replace 64 name comparisons with code/flag checks | App | No — no visible change |
| 3 | Add `translations` + `meta` to all master-data endpoints | Backend | No — additive |
| 4 | `Accept-Language` on every request | App | No |
| 5 | Add `native_name` / `is_default` to `/languages`; drive locales from API | Both | No |
| 6 | `Accept-Language` negotiation on products/categories/customers | Both | No |

**Steps 1 and 2 must land before step 3.** Shipping translated master data before
the app stops comparing English names will silently break checkout validation
(car number, delivery address, delivery charges).

---

## 9. Open questions for backend

Please answer these — they decide how much of the above is realistic.

1. **Is the "all languages inline" approach acceptable for master data**, or does
   your ORM / serializer make that awkward? If inline is a problem, the fallback
   is a separate `GET /api/v1/translations?entity=payment_method&lang=ar` bundle
   endpoint that the app caches — tell me if you'd prefer that.
2. **Do you already have a translations table for anything other than
   categories?** The Flutter side only sees per-language name fields in the
   Add/Edit Category screens, so I'm assuming categories are the only entity with
   translation storage today.
3. **Do delivery methods have a stable machine identifier in the DB**, or is
   `name` the only distinguishing column? If tenants can rename them freely, we
   need a `code` column plus a migration, and I need to know what the safe backfill
   rule is for existing rows.
4. **Are payment-method rows global or per-tenant?** This decides whether
   translations can be seeded once or must be authored per tenant.
5. **Do you support `ETag` / `If-None-Match` today?** If not, ignore that part —
   it is an optimization, not a requirement.
6. **How is `POST /api/v1/translate` billed / rate-limited?** If it calls an
   external MT provider, we should not call it at runtime — only from the admin
   "translate" button, as today.
7. **Is `Accept-Language` viable across your stack**, or would you rather we send
   an explicit `?lang=ar` query parameter? Either works for the app; I prefer the
   header because it applies uniformly, but a query param is easier to log and
   cache in some setups.
8. **Language codes:** plain ISO 639-1 (`ar`, `en`, `hi`) or full tags
   (`ar-SA`, `en-IN`)? The app currently keys everything on the short code. If you
   need regional variants, say so now — it affects the cache keys and the JSON
   bundle filenames.
9. **What happens to already-placed orders?** Orders store `delivery_method_id`,
   which is language-safe. But if any historical order stored the delivery method
   as a display string, those rows need a backfill. Can you check?

---

## 10. Summary

- Static UI translation is already done in the app and needs nothing from you.
- Master data needs a **stable `code`** and a **`translations` map**; everything
  else stays as it is, so the change is additive and non-breaking.
- Free text (products, categories, customers) needs **`Accept-Language`
  negotiation** plus a flag saying whether a fallback was used.
- The one hard dependency is `code` on delivery methods — without it, the app
  cannot stop comparing English strings, and translated labels will break checkout.

If any of this is wrong or expensive on your side, tell me which part and I'll
adapt the app to whatever shape is cheapest for you. The only non-negotiable is
that **labels the user sees must never be the thing the app branches on.**
