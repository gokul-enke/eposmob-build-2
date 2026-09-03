# Translation — Agreed Scope & Decision Record

**Date:** 2026-09-02
**Parties:** Backend dev + Flutter/POS client
**Supersedes:** the open questions in `TRANSLATION_BACKEND_REVIEW_REPLY.md`
**Context:** backend commit `541d37f8`, documented in `TRANSLATION_FLUTTER_GUIDE.md`

All eight review items are resolved. This document is the agreed contract.

---

## Scope of this phase

**In scope — translated:**

- Static app UI (already done: `en.json` / `ar.json` + GetX `.tr`)
- Master-data values (payment methods, racks, table list, etc.)
- Delivery methods
- Product units
- Cart-item statuses
- Website settings

**Explicitly out of scope — will remain in the tenant's base language:**

- Product names
- Category names
- Customer names

**Languages:** `en` and `ar` only. The client's supported-locale list stays
hardcoded; adding a third language requires an app release.

### Known consequence, accepted

An Arabic session shows Arabic UI chrome, Arabic payment/delivery/unit labels,
and **English product names**. The product grid is the largest visual surface on
the billing screen, so an Arabic user sees a mostly-English product list inside
an Arabic shell. This is a deliberate decision, not a defect — please do not file
it as a bug during QA.

Tenants who want Arabic product names can use the existing
`POST /api/v1/translate` button in the admin to fill them in manually, but the
API will not serve them per-locale.

---

## The governing rule

> **Adding a new field is always safe. Changing the meaning or the type of an
> existing field is never safe.**

Old app builds in the field parse responses strictly. A new key they don't know
about is ignored harmlessly; a key whose type or meaning changed causes a hard
parse failure, not a degraded screen. Every item below respects this.

---

## Backend action list

### 1. Product units — freeze `data`, add `labels`  *(BLOCKING)*

`GET /api/v1/product/list-units?locale=ar`

```json
{
  "status": "success",
  "message": "Units found",
  "data":   { "1": "PCS",  "2": "KG" },
  "labels": { "1": "قطعة", "2": "كيلوغرام" }
}
```

- `data` returns the **original machine values**, identical for every locale,
  permanently. It must **never** vary with `?locale=`.
- `labels` is new, locale-resolved display text.
- New clients read `labels`, falling back to `data` when a key is missing.

**Why `data` must be frozen:** old builds parse it as
`Map<String, String>.from(json['data'])` and match a product's stored unit
against both the keys and the values of that map. Translating the values makes
unit resolution fail on the product, stock and purchase forms. Old clients are
currently safe only because they happen not to send a locale — that is an
accident, not a guarantee. Freezing `data` makes it a guarantee.

If the richer shape (`symbol`, `decimal_places`, `short_label`,
`allow_fraction`) is wanted later, ship it as a **new endpoint** or a
`?format=detailed` variant — not by mutating this one.

### 2. `translations` must be a JSON object, never an array  *(BLOCKING)*

Currently returns `"translations": []` when empty — PHP's `json_encode` emitting
an empty associative array as `[]`. Cast to `(object)` before encoding so it is
always `{}`.

```json
"translations": {}
```

The client will defensively accept both, but the type should be stable.

### 3. `translations` keys — include base language  *(BLOCKING)*

Always emit the **base-language** key. Add the regional key as well when it
differs:

```json
"translations": { "ar": "نقدي", "ar-sa": "نقدي", "en": "Cash" }
```

The client looks up by base language (`ar`) and would otherwise miss a
region-qualified key, which would break offline language switching — the whole
reason the map is shipped inline.

`meta.available_languages` should use the same base-language keys.

### 4. Clean up `available_languages`  *(BLOCKING)*

Current live response returns:

```json
"available_languages": ["ar", "en", "en-ar", "03", "ur"]
```

`"03"` is not a language code and `"en-ar"` is not valid BCP-47. Validate
language codes at write time, and filter to known-good codes before returning.

### 5. Delivery methods — stable codes + capability flags

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

- Send the exact seeded `code` values for the existing methods.
- Add `requires_car_number`, `requires_address`, `icon_key`, `sort_order`.
- Confirm the truthy set for `status` (`Y`/`N` only, or also `1`/`0`/`true`/`false`).

The client currently has 64 sites branching on the English display name. With
capability flags we branch on behaviour instead, so a tenant adding a new
delivery method needs no app release.

### 6. `?locale=` is authoritative everywhere

Uniform across all five endpoints:

1. `?locale=` when present — always wins.
2. `Accept-Language` only as a fallback when the param is absent.
3. Tenant default, then `en`, then the record's original value.

### 7. Nice to have

- `Content-Language: <resolved>` response header, so the client can detect that
  a fallback occurred.
- `Vary: Accept-Language, X-Tenant` if anything is cached at the edge.
- `ETag` + `Cache-Control` on the reference lists, for cheap `304` revalidation
  on store switch.
- A per-row fallback signal (`_fallback`, or `X-Translation-Fallback-Count`) so
  the admin can be nudged about untranslated records.
- Consider moving the repeated `master_data` object out of every row and into
  `meta` — it is identical for every row and inflates a payload we sync offline.

---

## Resolved, no action needed

| Item | Resolution |
|---|---|
| Payment-methods master code | `PAYMENT_METHOD` (singular) is correct. The guide's plural was a typo. No client change. |
| `value` / `code` casing | Confirmed UPPERCASE in the live response (`CASH`, `CARD`, `UPI`). The lowercase in the guide was doc formatting. No regression. |

Minor, non-API: `description` / `label` come back lowercase (`"cash"`, `"card"`)
because that is how the master data was entered. The UI will render "cash" not
"Cash". Worth a tidy-up pass in the master-data admin.

---

## Client action list

1. Rewrite the 64 English-name delivery comparisons to branch on `code` and the
   new capability flags. **Prerequisite for everything else** — must land before
   localized master data is switched on.
2. Add a shared header/query builder so every request carries `?locale=`.
3. Add the locale to every cache key (`payment_methods_cache_<store>_<locale>`, etc).
4. Parse `translations` defensively, accepting both `{}` and `[]`.
5. Resolve labels at render time from the cached `translations` map, so a
   language switch needs no refetch and works offline.
6. Read `labels` from `list-units` with a fallback to `data`.
7. Keep `supportedLocales` hardcoded to `[en, ar]`; only ever request those two.

**Client will not enable localized master data until backend items 1–4 ship**,
because switching it on earlier breaks unit resolution and delivery validation.

---

## Sequencing

| Step | Owner | Blocks |
|---|---|---|
| Client items 1–3 | Flutter | nothing — starting now |
| Backend items 1–4 | Backend | client items 4–6 |
| Backend item 5 | Backend | client item 1 completing |
| Backend item 6 | Backend | client item 2 |
| Client items 4–7 | Flutter | backend 1–4 |
| Enable in production | both | all of the above |
