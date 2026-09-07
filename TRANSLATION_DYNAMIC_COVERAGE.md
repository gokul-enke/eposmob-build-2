# Translation — Dynamic API Coverage

**Date:** 2026-09-04  
**App evidence:** Marionette walk of the live debug session (Malayalam), plus client models in `lib/resources/app_url.dart`, `lib/models/master_data.dart`, `lib/models/get_product.dart`.  
**Contracts:** `TRANSLATION_AGREED_SCOPE.md` (in-scope vs out-of-scope), `TRANSLATION_BACKEND_STATUS.md` (what live `eposdemo` actually returns today).

This is the configure list for **100% translated fields**. App chrome is GetX (`en.json` / `ar.json` / `ml.json`). Everything below is **API / tenant data**.

**Governing rule:** freeze `id` / `code` / `value` / SKU / document numbers. Localize display text only. `?locale=` wins over `Accept-Language`. `translations` must be a JSON object `{ "en": "...", "ar": "..." }` (never `[]`), and must include the base language.

---

## What is *not* an API job

These stay English (or OS-language) even after every endpoint below is localized:

- Printer device names (`HP Desk`, `Microsoft`, `Print to PDF`)
- Document numbers (`INV-…`, `ORD-…`, `RCP…`, `PR-RCPT-…`)
- Currency *codes* (`SAR`) unless you treat them as `CURRENCIES` master data

Hardcoded billing chrome (`Categories`, `Products`, `Add Product`, empty-state resync copy) is app i18n, not backend.

---

## Scope split

The 2026-09-02 contract **does not** require product / category / customer names to localize. An Arabic (or Malayalam) session with English product tiles is accepted for that phase.

**Visual 100%** on billing still needs those catalog names — they dominate the product grid. Sections B and C are that extra work.

---

## A. Contracted reference data (in-scope 100%)

Live `https://eposdemo.yougoit.in` currently localizes **only** delivery-method `name`. The rest echo `?locale=` and return identical payloads.

| Endpoint | Query | Localize | Freeze |
|---|---|---|---|
| `GET /api/v1/master-data-values` | `code={CODE}&store_id=` | `description`, `label`, `translations` | `id`, `value`, `code` |
| `GET /api/v1/logistics/list-delivery-methods` | `?locale=` | `name`; `translations` as `{locale: text}` (include `en`) | `id`, `code` |
| `GET /api/v1/product/list-units` | `?locale=` | additive `labels` map | `data` (unit strings used for matching) |
| `GET /api/v1/cart/cart-item-statuses` | `?locale=` | `description`, `translations` | `id`, `value` (`READY`, …) |
| `GET /api/v1/website-settings` | `?locale=` | user-facing `value` (`printTitle`, subscription `message`, …) | codes, booleans, phone/email, **and** `defaultDeliveryMethod` / `defaultPaymentMethod` (those are codes) |
| `GET /api/v1/general` | `?locale=` | same class of display `value`s | same freeze set |
| `GET /api/v1/languages` | — | `name` | `id`, `code` (real BCP-47; drop `03` / `en_ar`) |

### Master-data `code=` values the app consumes

Seed `translations` and make `description` / `label` follow `?locale=` for every row:

1. `PAYMENT_METHOD` — Cash, Card, UPI, …
2. `RACKS`
3. `TABLE_LIST`
4. `PRODUCT_UNITS` (display only; matching still uses `list-units.data`)
5. `CASH_DENOMINATIONS`
6. `EXPENSE_CATEGORY` and `EXPENSE_CATEGORIES`
7. `CART_ITEM_STATUS`
8. `STOCK_GROUPING_FIELDS` (`PRICE`, `UNIT`, … — field codes; localize only if shown as labels)
9. `KOT_ITEM_NOTE_OPTIONS` (`LESS SUGAR`, `NO ICE`, `EXTRA SPICY`)
10. `DELIVERY_STATUS`
11. `PAYMENT_STATUS`
12. `CURRENCIES`

### Units — required `labels` shape

`data` is already frozen (do not translate it). Missing piece:

```json
{
  "data":   { "1989": "KG",  "6953": "PCS" },
  "labels": { "1989": "كجم", "6953": "قطعة" }
}
```

That is why the product grid still shows `/ PC`, `/ PCS`, `/ PACK`, `/ DZ`, `/ KG`, `/ NOS`, `/ FT`.

Until A lands, the client keeps these calls on `ApiLocale.notYetLocalized` so it does not double-cache identical payloads.

---

## B. Catalog names (visual 100%; currently out of agreed scope)

Marionette leftovers on billing were almost entirely this layer: `Water gun`, `7 DAYS CROISSANT`, `Hayfa Velazquez Test New`, `Test Default`.

| Endpoint | Localize | Freeze |
|---|---|---|
| `GET /api/v1/product/executive/list-products` (and sellable / all / raw variants) | `product_name` / `name` / `title`; nested `category.name`; unit **display** (or `list-units.labels`); `sale_units[].name`; variant attribute names/values | `id`, SKU, barcode, prices, unit machine value |
| `GET /api/v1/product/list-stocks` | `product_name`, `category_name`, `store_name`, `supplier`, `rack` | `id`, `sku` |
| `GET /api/v1/product/stock-details` | same nested names | ids / sku |
| `GET /api/v1/category/list-category` (sellable / purchasable / raw / details) | `name` | `id`, `slug` |
| `GET /api/v1/customer/customer-searchbar`, add/update customer, `search-user-by-key` | `name` / `customer_name` | `id`, phone |
| `GET /api/v1/get-suppliers` | supplier `name` | `id` |
| `GET /api/v1/stores/get-stores` | `store_name` | `id` |
| product-properties / variant attributes | attribute name and option values | ids |

`POST /api/v1/translate` can **seed** names. List/detail GETs must **return** the locale-resolved string (or a `translations` map). Seeding admin without serving it on read does not clear the product grid.

---

## C. Nested copies on transactional GETs

Localizing list-products alone leaves orders/invoices/reports in English. Resolve on read, or snapshot a translations map at write time.

| Endpoint | Nested display fields |
|---|---|
| `GET /api/v1/order/executive/list-orders`, order-details, order-searchbar, saved orders, KOT | `product_name`, `customer_name`, delivery-method **name**, payment **label**, cart-item **status** description, table/rack labels, KOT notes |
| quotations / proforma | same product + customer + unit labels |
| `GET /api/v1/invoice/list-invoices`, invoice details | customer, product lines, tax **name**, account **name** |
| `GET /api/v1/receipt/list-receipts`, receipt details | customer, payment method label |
| customer/supplier vouchers | account names, party names |
| purchases, purchase orders/items, purchase returns | product, supplier, unit, rack |
| `GET /api/v1/general-payment/list-general-payments` | `expense_account_name` / `debit_account_name`, `payment_account_name`, category name, status |
| `GET /api/v1/reports/sales-report`, product sales, supplier sales, non-stock, stock-report, consumed-stocks | product / category / store / supplier names |
| customer/supplier transaction ledgers | party names, account names |
| dashboard stats/graphs | category/product labels in series names |

---

## D. Accounts, tax, print, other display lists

| Endpoint | Localize | Freeze |
|---|---|---|
| `GET /api/v1/general-payment/account-options` | `name` / `label` / `account_name` on `expense_accounts` and `payment_accounts` (`Bank Account`, `Cash Account`, `Direct Expense Account`, `Import Duty`, …) | `id` |
| `GET /api/v1/transaction/get-account-types?type=invoice\|voucher` | account type display name | `id` / code |
| `GET /api/v1/accounts/company-accounts` (and account details) | `name` | `id` |
| `GET /api/v1/tax/list-tax` | tax display name | `id`, rate |
| `GET /api/v1/tax/get-category-tax` | tax **name** if present | numeric amounts |
| `GET /api/v1/document/document-configs` | `resolved_labels.*` (`tax`, `tax_name`, item/unit/price/amount names, header/footer titles) and per-field `default` display strings | field keys, layout ids |
| printer-settings payload | any user-facing label | device binding ids |
| `GET /api/v1/payment-gateway/list-payment-gateways` | gateway `name` / `label` | `code` |
| `GET /api/v1/get-banks` | bank `name` | `id` / code |
| `GET /api/v1/discount/list-discounts` | coupon/discount `name` / `title` | `id`, `code` |
| `GET /api/v1/roles/list` | role display name | role code (`sales_executive`, …) |
| `GET /api/v1/user/get-users`, `get-user-details` | display `name`; role **label** | email, ids |
| `GET /api/v1/faq/faqs/company/{id}` | question / answer | ids |
| `GET /api/v1/location/get-states`, `get-district` | place names if shown | ids |

Print is a separate track from app chrome: receipts use document-config labels, not `ar.json`. Until `document-configs` is locale-aware, printed paper stays in the tenant base language.

---

## Configure order

1. Seed `master-data-values` translations for the 12 codes above; resolve `description`/`label` from `?locale=`.
2. Add `labels` on `product/list-units` (clears `/ PC` on every tile).
3. Localize `cart-item-statuses` and website-settings display `value`s the same way.
4. Collapse delivery `translations` to a map and include `en`.
5. For visual 100%: serve localized `product_name` / category / customer / store / supplier / account names on catalog GETs **and** the nested transactional GETs in C.
6. Localize document-config `resolved_labels` if printed receipts must match the UI language.
