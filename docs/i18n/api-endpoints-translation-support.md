# API Endpoints — Translation Support (Backend Handoff)

**Audience:** Backend developers  
**Client:** `eposmob` Flutter POS (billing / checkout focus)  
**Supported app locales today:** `en`, `ar` (more may be added via `/api/v1/languages`)  
**Base URL pattern:** `{BASE_URL}/api/v1/...`

---

## 1. Goal

Static UI strings are already translated in the app (`lib/resources/i18n/en.json`, `ar.json`).

**Dynamic tenant data** (payment methods, delivery methods, units, product names, etc.) comes from APIs and is shown **as a single language** today. Billing checkout, product grid, cart, orders, and receipts need **locale-aware labels** while keeping **stable codes/IDs** for business logic and payloads.

---

## 2. Global contract (apply to all endpoints below)

### 2.1 Locale selection

Support **one** of these (prefer both):

| Mechanism | Example |
| --- | --- |
| Query param | `?language=ar` or `?locale=ar` |
| Header | `Accept-Language: ar` |

When present, human-facing fields (`name`, `label`, `description`, `coupon_name`, etc.) should return the **requested locale**, with sensible fallback (`ar` → `en` → first available).

`store_id` is already sent on many calls; keep supporting it.

### 2.2 Response shape (backward compatible)

Keep existing fields. Add optional `translations` where labels are shown in the UI.

```json
{
  "id": 3200,
  "value": "CASH",
  "code": "CASH",
  "description": "نقد",
  "label": "نقد",
  "translations": {
    "en": "Cash",
    "ar": "نقد"
  }
}
```

**Rules:**

| Field | Rule |
| --- | --- |
| `id`, `value`, `code`, `slug`, `coupon_code`, SKU, barcode | **Never translate** — used for matching, checkout, and storage |
| `name`, `label`, `description`, `coupon_name` | Localized for current request locale |
| `translations` | Full map `{ "en": "...", "ar": "..." }` so POS can switch language offline without refetch |

Alternative shape already used for categories (also acceptable if consistent):

```json
"names": [
  { "code": "en", "name": "Cash" },
  { "code": "ar", "name": "نقد" }
]
```

Pick **one** list pattern per entity type; POS can parse either `translations` map or `names[]`.

### 2.3 Write APIs

Create/update endpoints for master data must **accept** the same translation payload (not only return it), e.g.:

```json
{
  "code": "CASH",
  "translations": { "en": "Cash", "ar": "نقد" }
}
```

or

```json
{
  "names": [
    { "language_id": 1, "name": "Cash" },
    { "language_id": 2, "name": "نقد" }
  ]
}
```

(`language_id` from `GET /api/v1/languages`.)

### 2.4 Order / cart payloads

On **read** APIs, prefer:

- Storing and returning **codes/IDs** (`payment_method`, `delivery_method_id`, `delivery_method_code`)
- Returning **`product_names` / `names`** object on line items (already done in some responses)

Avoid returning only a frozen English `name` with no way to resolve Arabic at display time.

---

## 3. Priority legend

| Priority | Meaning |
| --- | --- |
| **P0** | Checkout blockers — payment, delivery, units, tables, KOT |
| **P1** | Catalog display in billing (products, categories, taxes, variants) |
| **P2** | Orders, cart, quotations, discounts (read paths) |
| **P3** | Print, tax, settings, ancillary lists |
| **P4** | Write/admin APIs so tenants can maintain translations |

---

## 4. Endpoint list

### 4.1 P0 — Checkout master data (highest priority)

| # | Method | Endpoint | Query / body params | Fields to localize | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | GET | `/api/v1/master-data-values` | `code=PAYMENT_METHOD`, `store_id` | `description`, `label`; add `translations` | **Primary** checkout payment list. Used by `MasterDataProvider.fetchPaymentMethods()`. |
| 2 | GET | `/api/v1/transaction/get-payment-methods` | `store_id` | `description` (per `value`); add `translations` | **Duplicate** legacy path; must stay **in sync** with #1. Used by `InvoiceProvider.listAllPaymentList()`. |
| 3 | GET | `/api/v1/logistics/list-delivery-methods` | `store_id` | `name`; add `translations` | Delivery tiles, charges, saved-order restore. |
| 4 | GET | `/api/v1/product/list-units` | `store_id` (if used) | Unit **display names** in `data` map values | Today `data` is `{ "1": "Kilogram", ... }`. Need per-locale values or nested `translations` per unit id. |
| 5 | GET | `/api/v1/master-data-values` | `code=TABLE_LIST`, `store_id` | `name` / `description` | Restaurant table picker. |
| 6 | GET | `/api/v1/master-data-values` | `code=KOT_ITEM_NOTE_OPTIONS`, `store_id` | `description` | Quick-select kitchen/cart notes. |
| 7 | GET | `/api/v1/master-data-values` | `code=CASH_DENOMINATIONS`, `store_id` | `description` | Cash tendering UI. |
| 8 | GET | `/api/v1/cart/cart-item-statuses` | `store_id` | `description` | KOT flow: New / Started / Ready / Served. `value` stays machine code. |
| 9 | GET | `/api/v1/discount/list-discounts` | `store_id` | `coupon_name` | `coupon_code` must not change per locale. |
| 10 | GET | `/api/v1/payment-gateway/list-payment-gateways` | `store_id` | `name`, `label` | Pine Labs / online gateway tiles. |

**Generic master-data endpoint (covers #1, #5–#7 and more):**

| Method | Endpoint | `code` values used in billing |
| --- | --- | --- |
| GET | `/api/v1/master-data-values?code={CODE}` | `PAYMENT_METHOD`, `TABLE_LIST`, `KOT_ITEM_NOTE_OPTIONS`, `CASH_DENOMINATIONS`, `STOCK_GROUPING_FIELDS`, `RACKS` |

For `STOCK_GROUPING_FIELDS` and `RACKS`, labels are lower priority but same contract applies if shown in UI.

---

### 4.2 P1 — Catalog (partially implemented; billing UI still uses default `name`)

| # | Method | Endpoint | Query params | Fields to localize | Current state |
| --- | --- | --- | --- | --- | --- |
| 11 | GET | `/api/v1/product/executive/list-products` | `type=sellable`, `store_id`, pagination | `name` + `names` object (`en`, `ar`, `hi`) | **Partial** — `names` exists; ensure always populated for all sellable products |
| 12 | GET | `/api/v1/category/list-category` | `type=sellable`, `store_id`, `page` | `name` + `names[]` with `code`/`name` | **Partial** — used for billing category chips |
| 13 | GET | `/api/v1/category-details` | category id | `names` | Category view/edit |
| 14 | GET | `/api/v1/product/list-product-properties` | — | `label`, option `values[]` | Variant/property picker on add product |
| 15 | GET | `/api/v1/product/fetch-prop-values` | prop filters | option labels | Property dropdown values |
| 16 | GET | `/api/v1/tax/list-tax` | `active_only` | tax `name` | Product details, totals |
| 17 | GET | `/api/v1/tax/get-category-tax` | `category_id`, `product_id`, `retail_price`, `tax_include`, `store_id` | tax name in response (if any) | Mostly numeric; localize labels if returned |

**Nested fields inside product list (#11) — also need translation:**

| JSON path | Field | Notes |
| --- | --- | --- |
| `sale_units[].unit_name` | Unit label on cart | Or resolve via unit id + #4 |
| `taxes[].name` | Tax row label | |
| `product_props[].label` | Property label | |
| `product_props[].master_value` | Display value (e.g. warranty text) | |
| `variants[].attributes` | Attribute keys/values (Color, Size, Red) | Prefer `{ "en": {...}, "ar": {...} }` or translated value map |

---

### 4.3 P2 — Cart, orders, quotations (read APIs)

Return localized names **or** stable codes + `names` / `product_names` on every line item.

| # | Method | Endpoint | Fields to localize |
| --- | --- | --- | --- |
| 18 | GET | `/api/v1/cart/executive/list-cart-items` | Product `names`, unit, tax names on items |
| 19 | GET | `/api/v1/order/executive/list-orders` | Product names, payment/delivery labels, status text |
| 20 | GET | `/api/v1/order/executive/order-details` | `product_names`, delivery method name, payment labels |
| 21 | GET | `/api/v1/order/list-saved-orders` | Same as orders list |
| 22 | GET | `/api/v1/order-searchbar` | Search result labels |
| 23 | GET | `/api/v1/quotations` | Product names, delivery method |
| 24 | GET | `/api/v1/quotations/{id}` | Full quotation line labels |
| 25 | GET | `/api/v1/invoice/proforma-invoices` | If used from quotation checkout |
| 26 | GET | `/api/v1/invoice/proforma-invoices/{id}` | Line item names |

**Write APIs (response messages only — lower priority but helpful):**

| Method | Endpoint | Notes |
| --- | --- | --- |
| POST | `/api/v1/cart/add-to-cart` | Error/success `message` |
| POST | `/api/v1/order/add-to-order` | |
| POST | `/api/v1/order/update-order` | |
| POST | `/api/v1/order/confirm-order` | |
| POST | `/api/v1/discount/apply-coupon` | Validation messages |
| POST | `/api/v1/cart/update-cart-item-status` | |

Checkout **request bodies** should continue to send **codes/IDs**, not translated labels.

---

### 4.4 P3 — Print, document config, settings (billing-adjacent)

| # | Method | Endpoint | Status | Action |
| --- | --- | --- | --- | --- |
| 27 | GET | `/api/v1/document/document-configs` | **Done** | Already supports `type` + `language` + `store_id`. Keep as reference implementation. |
| 28 | POST | `/api/v1/calculate-tax` | Partial | Localize tax names in breakdown if returned |
| 29 | GET | `/api/v1/website-settings` | Review | `defaultPaymentMethod` / `defaultDeliveryMethod` must remain **codes**, not translated strings |
| 30 | GET | `/api/v1/general` | Low | Only if setting values are user-visible sentences |
| 31 | GET | `/api/v1/get-banks` | Medium | Bank `name` on card/bank flows |
| 32 | GET | `/api/v1/stores/get-stores` | Low | Store `name` on header/receipt |
| 33 | GET | `/api/v1/languages` | **Done** | Language catalog for admin forms |
| 34 | POST | `/api/v1/translate` | **Done** | Machine translation helper when creating content |

---

### 4.5 P4 — Write / admin APIs (maintain translations)

Needed so tenants can enter Arabic + English when creating master data (not only at read time).

| # | Method | Endpoint | Entity |
| --- | --- | --- | --- |
| 35 | POST | `/api/v1/product/add-product-name` | Product names per `language_id` — **exists** |
| 36 | POST | `/api/v1/product/edit-product-name` | Product names — **exists** |
| 37 | POST | `/api/v1/category/add-category` | Category names — **exists** (EN/AR/HI fields) |
| 38 | POST | `/api/v1/category/edit-category` | Category names — **exists** |
| 39 | *TBD* | Payment method create/update | Must accept `translations` / `names[]` |
| 40 | *TBD* | Delivery method create/update | Must accept `translations` / `names[]` |
| 41 | *TBD* | Unit create/update | Must accept `translations` per unit |
| 42 | *TBD* | Master data admin (TABLE_LIST, KOT notes, etc.) | Same contract as GET |

Confirm exact admin routes with your ERP admin module; POS only **consumes** GET paths listed above.

---

## 5. Reference — current client usage (no API change, for context)

| Endpoint | Used for |
| --- | --- |
| `GET /api/v1/master-data-values?code=PAYMENT_METHOD` | `MasterDataProvider`, checkout modals, mobile payment sheet |
| `GET /api/v1/transaction/get-payment-methods` | Store bootstrap, invoice flows, offline sync |
| `GET /api/v1/logistics/list-delivery-methods` | `DeliveryMethodsProvider`, checkout modal |
| `GET /api/v1/product/list-units` | Store bootstrap, add product, sale units |
| `GET /api/v1/master-data-values?code=TABLE_LIST` | `TableProvider`, dining selection |
| `GET /api/v1/product/executive/list-products` | Billing product grid (offline sync) |
| `GET /api/v1/category/list-category?type=sellable` | Category sidebar / chips |
| `GET /api/v1/document/document-configs` | Receipt labels (already localized) |

---

## 6. Example — payment method (target response)

```json
{
  "status": "success",
  "data": [
    {
      "id": 3200,
      "value": "CASH",
      "code": "CASH",
      "description": "نقد",
      "label": "نقد",
      "enabled": true,
      "sort_order": 0,
      "icon_key": "cash",
      "behavior": "collected",
      "translations": {
        "en": "Cash",
        "ar": "نقد"
      }
    },
    {
      "id": 3201,
      "value": "CARD",
      "code": "CARD",
      "description": "بطاقة",
      "label": "بطاقة",
      "enabled": true,
      "sort_order": 1,
      "translations": {
        "en": "Card",
        "ar": "بطاقة"
      }
    }
  ]
}
```

Request: `GET /api/v1/master-data-values?code=PAYMENT_METHOD&store_id=1`  
Header: `Accept-Language: ar`

---

## 7. Example — delivery method (target response)

```json
{
  "status": "success",
  "data": [
    {
      "id": "11",
      "code": "STORE_TAKEAWAY",
      "name": "استلام من المتجر",
      "translations": {
        "en": "Store Takeaway",
        "ar": "استلام من المتجر"
      },
      "prices": [
        { "id": "1", "delivery_method_id": "11", "price": 0 }
      ]
    }
  ]
}
```

Request: `GET /api/v1/logistics/list-delivery-methods?store_id=1`

---

## 8. Example — product names (already expected shape)

```json
{
  "id": 101,
  "name": "Horlicks",
  "names": {
    "en": "Horlicks",
    "ar": "هورليكس"
  }
}
```

Billing will read `names[locale]` with fallback to `name`.

---

## 9. Example — category names (already expected shape)

```json
{
  "id": 5,
  "name": "Beverages",
  "names": [
    { "code": "en", "name": "Beverages" },
    { "code": "ar", "name": "مشروبات" }
  ]
}
```

---

## 10. What must NOT be translated

- Payment method **codes** (`CASH`, `CARD`, `DEBIT`, `UPI`, `COD`, custom codes)
- Delivery method **id** / **code**
- Coupon **codes**
- Product **id**, SKU, barcode, HSN
- Currency codes, numeric amounts
- Customer name, phone, address (user-entered)
- `store_id`, `company_id`, order numbers

---

## 11. Suggested backend delivery order

1. **Sprint 1 (P0):** #1–#3 (payment + delivery + units) + global `Accept-Language` / `translations` contract  
2. **Sprint 2 (P0):** #5–#10 (tables, KOT notes, denominations, cart statuses, coupons, gateways)  
3. **Sprint 3 (P1):** Ensure #11–#12 always return complete `names`; nested product fields (#16 path table)  
4. **Sprint 4 (P2):** Order/cart/quotation read APIs (#18–#26)  
5. **Sprint 5 (P4):** Admin write APIs for payment/delivery/unit translations  

---

## 12. Acceptance criteria (per endpoint)

- [ ] With `Accept-Language: ar`, primary display field is Arabic when translation exists  
- [ ] With `Accept-Language: en`, primary display field is English  
- [ ] Missing translation falls back to `en`, then any available language  
- [ ] `translations` (or `names[]`) includes all configured tenant languages  
- [ ] Stable `code` / `value` / `id` unchanged across locales  
- [ ] `store_id` scoping unchanged  
- [ ] Legacy clients ignoring `translations` still work (localized top-level field only)

---

## 13. Contact / client repo references

- URL constants: `lib/resources/app_url.dart`
- Offline sync endpoint list: `lib/providers/offline_sync_endpoints.dart`
- Payment parsing: `lib/models/payment_method.dart`, `lib/models/master_data.dart`
- Delivery parsing: `lib/models/delivery_method.dart`
- Category translations: `lib/models/category_list.dart`
- Product names: `lib/models/get_product.dart` (`Names` class)
- Document config (reference): `lib/providers/document_config_provider.dart` (`?language=`)

---

*Generated for backend handoff — eposmob billing i18n. Update this doc when admin write routes are confirmed.*
