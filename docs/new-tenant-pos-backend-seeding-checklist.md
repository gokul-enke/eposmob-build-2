# New Tenant POS Backend Seeding Checklist

## Purpose

This document defines the backend data and settings required to provision this
Flutter POS for a brand-new tenant.

It covers:

- tenant discovery and login
- company, user, role, and store setup
- general and website settings
- customers, payments, delivery methods, units, categories, and products
- inventory and product variants
- restaurant tables and kitchen statuses
- shift/day-close data
- optional purchase, expense, invoice, ZATCA, and Pine Labs dependencies
- clean-install acceptance testing

This is based on the contracts currently consumed by the Flutter client. It is
not a generic ERP seeding guide.

---

## 1. Executive Summary

A new tenant needs more than settings.

The minimum usable POS setup consists of:

1. A tenant API key mapped to the correct HTTPS backend domain.
2. A company record.
3. A login user with a supported role.
4. At least one real store assigned to that user.
5. Role and permission data for the user.
6. A structurally valid general-settings response.
7. Explicit website settings for predictable behavior.
8. A walk-in/default customer.
9. A real delivery method.
10. A real `CASH` payment method with a positive backend ID.
11. At least one unit, sellable category, and sellable product.
12. Store-scoped stock rows when stock management is enabled.

Important distinctions:

- `GET /api/v1/website-settings` may technically return `{"data":[]}` and
  still parse. However, missing settings use inconsistent defaults across
  different screens, so all recognized settings should be seeded explicitly.
- `GET /api/v1/general` must return `stock_enabled` as a real JSON boolean.
- IDs such as customer, store, payment method, delivery method, product,
  category, supplier, and cart-item status must be real positive backend IDs.
- ID `0` is treated as missing or synthetic in several Flutter models. Do not
  use `0` for real seeded records.
- Store is the primary POS scope. The Flutter client has no separate operational
  branch ID.

Primary implementation references:

- `lib/main.dart`
- `lib/providers/store_session_provider.dart`
- `lib/providers/app_settings_provider.dart`
- `lib/models/get_app_settings.dart`
- `lib/providers/general_settings_provider.dart`
- `lib/models/get_general_settings.dart`
- `lib/providers/master_data_provider.dart`
- `lib/models/master_data.dart`
- `lib/features/billing/presentation/pages/billing_page.dart`
- `lib/screens/billing/restaurant/restaurant_page.dart`

---

## 2. Recommended Initial Profiles

### 2.1 Retail Starter

Use this when the tenant does not yet have reliable stock records.

```json
{
  "stock_enabled": false,
  "confirm_oversell_on_zero_stock": false
}
```

Recommended behavior:

- auto-assign a seeded walk-in customer
- default payment method: `CASH`
- default delivery method: `STORE_TAKEAWAY`
- stock management: off
- product variants: off
- multiple sale units: off
- discounts: off until configured
- shift/day-close enforcement: off
- restaurant/KOT settings: off
- ZATCA: off unless applicable
- Pine Labs: off until terminal integration is configured

`ALLOW_OVERSELL=true` is acceptable in this profile because stock management is
disabled.

### 2.2 Retail With Inventory

Use this only after every sellable stock-managed product has valid store-scoped
stock.

```json
{
  "stock_enabled": true,
  "confirm_oversell_on_zero_stock": false
}
```

Recommended behavior:

- `ALLOW_OVERSELL=false`
- every stock row has a real ID, store, quantity, unit, price, and MRP
- variants remain off unless complete variant-specific stock exists
- multiple sale units remain off unless all conversion and price data exists

### 2.3 Restaurant

Start from the Retail Starter profile and add:

- restaurant user role
- `STORE_TAKEAWAY`
- `DINE_IN`
- real `TABLE_LIST` rows
- `START`, `READY`, and `SERVED` cart-item statuses
- `ENABLE_SEND_TO_KITCHEN_BUTTON=true`
- `ENABLE_KOT_PRINT=false` until a KOT printer is configured

Enable KOT + Bill settings only after that workflow has been tested.

---

## 3. Tenant Discovery

The API key is resolved through:

```text
POST https://cloudposai.com/api/v1/find-domain
```

Header:

```http
X-Tenant-Key: <tenant-api-key>
Accept: application/json
```

Expected response:

```json
{
  "status": 200,
  "message": "Tenant found",
  "data": {
    "domain": "https://tenant-api.example.com"
  }
}
```

Requirements:

- top-level `status` must be numeric `200`
- `data.domain` must be non-empty
- the domain must be a valid HTTP or HTTPS URL
- production should use HTTPS
- the resolved server must accept the same tenant key in the `X-Tenant` header

The client saves:

- `api_key`
- `app_url`
- `show_default_domain_warning=false`

`/api/v1/verify-api-key` is declared in the Flutter client but is not the current
effective verification path. Domain discovery performs that role.

Evidence:

- `lib/services/tenant_domain_service.dart`
- `lib/screens/login/api_key_screen.dart`
- `lib/screens/login/base_url_wrapper.dart`

---

## 4. Login, Company, User, Role, and Store

### 4.1 Login Endpoint

```text
POST /api/v1/user/signin
```

Headers:

```http
Content-Type: application/json
Accept: application/json
X-Tenant: <tenant-api-key>
```

Body:

```json
{
  "email": "cashier@example.com",
  "password": "<password>"
}
```

Recommended successful response:

```json
{
  "status": "success",
  "message": "Login successful",
  "data": {
    "access_token": "<token>",
    "token_type": "Bearer",
    "user_id": 101,
    "name": "Main Cashier",
    "company_id": 10,
    "company_name": "Example Retail",
    "user_role": "sales_executive",
    "time_zone": "Asia/Kolkata",
    "country": {
      "name": "India"
    },
    "stores": [
      {
        "store_id": 1,
        "store_name": "Main Store",
        "code": "MAIN",
        "location": "Main Branch",
        "email": "store@example.com",
        "phone": "9999999999",
        "state_id": 1,
        "district_id": 1,
        "pincode_id": 1,
        "local_location_id": 1,
        "store_open_time": "08:00:00"
      }
    ]
  }
}
```

Required operational fields:

- `access_token`: non-empty string
- `user_id`: positive integer
- `company_id`: positive integer
- `user_role`: supported role string
- `stores`: non-empty list
- `stores[].store_id`: real positive integer
- `stores[].store_name`: non-empty string

Strongly recommended:

- `company_name`
- `time_zone` as a valid IANA timezone
- country name
- store code
- store location
- `store_open_time`

If the user has no assigned stores, login succeeds but the application refuses
to continue.

### 4.2 Supported Role Strings

The initial page is selected using exact role strings:

- `sales_executive` — normal billing
- `restaurant_sales` — restaurant billing
- `attender` — restaurant/table workflow
- `kitchen_master` — kitchen screen
- `company_admin` — dashboard

Seed:

- the role record
- its permissions
- user-to-role assignment
- user-to-store assignment

### 4.3 Store Scope

After store selection, the client persists `active_store_id` and sends it to
most subsequent APIs.

Do not return a null store ID. The current client can convert a null store ID to
`0`, which is not a valid production scope.

There is no separate branch identifier in the current POS client. Treat the
store as the branch/location scope.

Evidence:

- `lib/models/executive.dart`
- `lib/screens/login/login.dart`
- `lib/screens/login/store_selection_screen.dart`
- `lib/providers/store_session_provider.dart`

---

## 5. General Settings

Endpoint:

```text
GET /api/v1/general?store_id=<active-store-id>
```

Header:

```http
X-Tenant: <tenant-api-key>
```

The endpoint may return a flat object:

```json
{
  "stock_enabled": false,
  "confirm_oversell_on_zero_stock": false
}
```

or a wrapped object:

```json
{
  "data": {
    "stock_enabled": false,
    "confirm_oversell_on_zero_stock": false
  }
}
```

### 5.1 Field Contract

| Field | Type | Required | Safe initial value | Notes |
|---|---|---:|---:|---|
| `stock_enabled` | JSON boolean | Yes | `false` | Missing, null, string, or numeric values can make parsing fail. |
| `confirm_oversell_on_zero_stock` | JSON boolean | No | `false` | Parsed but currently has no behavior outside the model. |

Never return these values as strings:

```json
{
  "stock_enabled": "false"
}
```

The direct Dart boolean cast rejects that shape.

### 5.2 Stock Policy

If `stock_enabled=false`:

- product base prices are used
- store stock selection is not required
- overselling settings are mostly irrelevant

If `stock_enabled=true`:

- seed store-scoped stock rows before go-live
- set `ALLOW_OVERSELL=false` for conservative enforcement
- ensure product unit, price, MRP, and quantity are valid
- ensure variant products have exact variant-scoped stock

Evidence:

- `lib/models/get_general_settings.dart`
- `lib/providers/general_settings_provider.dart`
- `lib/helpers/product_cart_helper.dart`

---

## 6. Website Settings API Contract

Endpoint:

```text
GET /api/v1/website-settings?store_id=<active-store-id>
```

Header:

```http
X-Tenant: <tenant-api-key>
```

No bearer token is currently sent.

Expected envelope:

```json
{
  "data": [
    {
      "code": "CURRENCY",
      "status": true,
      "value": "INR"
    }
  ]
}
```

### 6.1 Parsing Rules

- `data` must be a JSON list.
- Setting codes are case-sensitive.
- `status` should be a JSON boolean.
- `status` also accepts numeric `0`/`1` and strings `"true"`, `"false"`, and
  `"1"`, but booleans are preferred.
- A present row with `status: null` becomes `false`.
- A missing row uses the client default.
- `value` should always be a JSON string.
- `value: null` becomes an empty string.
- Duplicate setting codes are last-write-wins.

Although an empty list parses, seed every recognized code explicitly to avoid
different screens using different fallback values.

---

## 7. Recommended Website Settings Seed

The following is the conservative Retail Starter seed.

| Code | Status | Value | Requirement | Purpose |
|---|---:|---|---|---|
| `BARCODE_SALES` | `false` | `""` | Optional | Enable only when product barcodes are reliable. |
| `COMPANY_CUSTOMER_CARE_PHONE` | `true` | Tenant phone | Recommended | Printed support/contact details. |
| `COMPANY_CUSTOMER_CARE_EMAIL` | `true` | Tenant email | Recommended | Printed support/contact details. |
| `PRINT_TITLE` | `true` | Legal/trading name | Recommended | Receipt and company title. |
| `SHOW_CUSTOMER_LAST_BUYED_PRICE_LIST` | `false` | `""` | Optional | Customer purchase-price history. |
| `ASK_DELIVERY_DATE` | `false` | `""` | Optional | Delivery date/time controls. |
| `PRICE_ROUND_OFF` | `false` | `""` | Recommended initial value | Enable only with an agreed accounting rule. |
| `DISCOUNT_AND_COUPON` | `false` | `""` | Optional | Requires discount/coupon data and APIs. |
| `AUTO_ASSIGN_DEFAULT_CUSTOMER` | `true` | Exact walk-in phone | Operationally required | Auto-selects the default customer. |
| `CURRENCY` | `true` | Tenant currency, e.g. `INR` | Operationally required | Prevents inconsistent INR/SAR/blank fallbacks. |
| `WORKING_TIME` | `true` | `08:00 - 22:00` | Optional | Parsed by day-close code; currently informational. |
| `ZATCA_PHASE_1` | `false` | `""` | Feature | Saudi Phase 1 only. |
| `ZATCA_PHASE_2` | `false` | `""` | Feature | Saudi Phase 2 only. |
| `SHOW_TAX_POS` | `false` | `""` | Optional | Shows tax amount. |
| `SHOW_MRP_POS` | `true` | `""` | Recommended | Shows MRP/reference price. |
| `SHOW_TAXRATE_POS` | `false` | `""` | Optional | Shows tax percentage. |
| `SHOW_CONFIRM_ORDER_BUTTON` | `true` | `""` | Required for normal flow | Keeps Confirm available. |
| `SHOW_CONFIRM_ORDER_AND_PRINT_BUTTON` | `true` | `""` | Required for normal flow | Keeps Confirm & Print available. |
| `ENABLE_KOT_PRINT` | `false` | `""` | Restaurant feature | Enable only after KOT printer setup. |
| `DEFAULT_DELIVERY_METHOD` | `true` | `STORE_TAKEAWAY` | Operationally required | Must match a real delivery method ID, name, or code. |
| `DEFAULT_PAYMENT_METHOD` | `true` | `CASH` | Operationally required | Current default logic expects a core uppercase code. |
| `POS_PRINT_DOUBLE_BILL` | `false` | `""` | Optional | Prints a second bill copy. |
| `SKIP_CUSTOMER_SELECTION` | `false` | `""` | Recommended | Skipping the UI does not consistently remove customer validation. |
| `HIDE_DEFAULT_PHONE` | `true` | `""` | Recommended | Hides walk-in phone on supported receipts. |
| `FREE_DELIVERY_MINIMUM_AMOUNT` | `false` | `"0"` | Optional | Status enables delivery charge rules; value is free threshold. |
| `ITEM_CODE_ENABLED` | `true` | `""` | Recommended | Shows item code when catalog supplies it. |
| `B2B` | `false` | `""` | Feature | Customer type, VAT, CR, and B2B fields. |
| `ENABLE_SEND_TO_KITCHEN_BUTTON` | `false` | `""` | Restaurant feature | Set true for restaurant workflows. |
| `ENABLE_KOT_BILL_BUTTON` | `false` | `""` | Restaurant feature | Combined KOT + Bill. |
| `KOT_BILL_AUTO_MARK_SERVED` | `false` | `""` | Restaurant feature | Auto-applies `SERVED`. |
| `KOT_BILL_ALLOWED_FOR_DINE_IN` | `false` | `""` | Restaurant feature | Allows KOT + Bill for table orders. |
| `PINELAB_PAYMENT` | `false` | `""` | Terminal feature | Requires `ONLINE` payment behavior and device integration. |
| `SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT` | `false` | `""` | Recommended initial value | Keep false until defaults are proven. |
| `COMPULSORY_DAY_CLOSE_REGISTER` | `false` | `""` | Feature | Adds pending day-close dependency. |
| `PRODUCT_VARIANT_ENABLED` | `false` | `""` | Feature | Requires complete variant and variant-stock data. |
| `MULTI_SALE_UNIT_ENABLED` | `false` | `""` | Feature | Requires complete sale-unit conversion and pricing. |
| `ALLOW_OVERSELL` | `true` | `""` | Profile-specific | Use true when stock is off; false when stock is strictly managed. |
| `COMPULSORY_SHIFT_OPEN_` | `false` | `""` | Feature | Trailing underscore is required. |

### 7.1 Copyable Retail Starter Payload

Replace placeholders before seeding:

```json
{
  "data": [
    {"code":"BARCODE_SALES","status":false,"value":""},
    {"code":"COMPANY_CUSTOMER_CARE_PHONE","status":true,"value":"<tenant-phone>"},
    {"code":"COMPANY_CUSTOMER_CARE_EMAIL","status":true,"value":"<tenant-email>"},
    {"code":"PRINT_TITLE","status":true,"value":"<tenant-trading-name>"},
    {"code":"SHOW_CUSTOMER_LAST_BUYED_PRICE_LIST","status":false,"value":""},
    {"code":"ASK_DELIVERY_DATE","status":false,"value":""},
    {"code":"PRICE_ROUND_OFF","status":false,"value":""},
    {"code":"DISCOUNT_AND_COUPON","status":false,"value":""},
    {"code":"AUTO_ASSIGN_DEFAULT_CUSTOMER","status":true,"value":"<exact-walk-in-customer-phone>"},
    {"code":"CURRENCY","status":true,"value":"<currency-code>"},
    {"code":"WORKING_TIME","status":true,"value":"08:00 - 22:00"},
    {"code":"ZATCA_PHASE_1","status":false,"value":""},
    {"code":"ZATCA_PHASE_2","status":false,"value":""},
    {"code":"SHOW_TAX_POS","status":false,"value":""},
    {"code":"SHOW_MRP_POS","status":true,"value":""},
    {"code":"SHOW_TAXRATE_POS","status":false,"value":""},
    {"code":"SHOW_CONFIRM_ORDER_BUTTON","status":true,"value":""},
    {"code":"SHOW_CONFIRM_ORDER_AND_PRINT_BUTTON","status":true,"value":""},
    {"code":"ENABLE_KOT_PRINT","status":false,"value":""},
    {"code":"DEFAULT_DELIVERY_METHOD","status":true,"value":"STORE_TAKEAWAY"},
    {"code":"DEFAULT_PAYMENT_METHOD","status":true,"value":"CASH"},
    {"code":"POS_PRINT_DOUBLE_BILL","status":false,"value":""},
    {"code":"SKIP_CUSTOMER_SELECTION","status":false,"value":""},
    {"code":"HIDE_DEFAULT_PHONE","status":true,"value":""},
    {"code":"FREE_DELIVERY_MINIMUM_AMOUNT","status":false,"value":"0"},
    {"code":"ITEM_CODE_ENABLED","status":true,"value":""},
    {"code":"B2B","status":false,"value":""},
    {"code":"ENABLE_SEND_TO_KITCHEN_BUTTON","status":false,"value":""},
    {"code":"ENABLE_KOT_BILL_BUTTON","status":false,"value":""},
    {"code":"KOT_BILL_AUTO_MARK_SERVED","status":false,"value":""},
    {"code":"KOT_BILL_ALLOWED_FOR_DINE_IN","status":false,"value":""},
    {"code":"PINELAB_PAYMENT","status":false,"value":""},
    {"code":"SKIP_CHECKOUT_ON_CONFIRM_AND_PRINT","status":false,"value":""},
    {"code":"COMPULSORY_DAY_CLOSE_REGISTER","status":false,"value":""},
    {"code":"PRODUCT_VARIANT_ENABLED","status":false,"value":""},
    {"code":"MULTI_SALE_UNIT_ENABLED","status":false,"value":""},
    {"code":"ALLOW_OVERSELL","status":true,"value":""},
    {"code":"COMPULSORY_SHIFT_OPEN_","status":false,"value":""}
  ]
}
```

---

## 8. Walk-in/Default Customer

Seed at least one store-visible walk-in customer:

```json
{
  "id": 1001,
  "company_id": 10,
  "store_id": 1,
  "name": "Walk-in Customer",
  "phone": "9999999999",
  "balance": 0,
  "customer_type": "B2C"
}
```

Set the exact same phone in:

```json
{
  "code": "AUTO_ASSIGN_DEFAULT_CUSTOMER",
  "status": true,
  "value": "9999999999"
}
```

Important:

- comparison is exact string equality
- there is no phone-number normalization
- country code, spaces, punctuation, and leading zeros must match exactly
- the customer must be visible from the active store's customer endpoint

Customer endpoint:

```text
GET /api/v1/customer/customer-searchbar
    ?page=1
    &per_page=1000
    &store_id=<active-store-id>
```

The default customer is effectively required because several desktop, mobile,
and restaurant confirmation paths still require a customer ID or phone.

`SKIP_CUSTOMER_SELECTION=true` only skips a checkout step; it does not reliably
remove the final customer requirement.

---

## 9. Delivery Methods

Endpoint:

```text
GET /api/v1/logistics/list-delivery-methods?store_id=<active-store-id>
```

Recommended minimum:

```json
{
  "status": "success",
  "data": [
    {
      "id": 11,
      "code": "STORE_TAKEAWAY",
      "name": "Store Takeaway",
      "prices": []
    }
  ]
}
```

The example ID `11` is not mandatory. Use the real backend ID.

Do not depend on Flutter's fabricated fallback delivery ID `"11"` unless a real
backend delivery method actually has that ID.

`DEFAULT_DELIVERY_METHOD.value` can match:

- delivery method ID
- exact case-insensitive name
- stable code

Prefer the code:

```text
STORE_TAKEAWAY
```

### 9.1 Delivery Method Fields

```json
{
  "id": 14,
  "code": "DOOR_DELIVERY",
  "name": "Door Delivery",
  "prices": [
    {
      "id": 1,
      "delivery_method_id": 14,
      "price": 50.0,
      "created_at": null,
      "updated_at": null
    }
  ]
}
```

### 9.2 Exact Names With Client Behavior

- `Store Takeaway` — preferred fallback/default display
- `Car Delivery` — makes car number required
- `Door Delivery` — enables delivery-address behavior in legacy paths
- `Dine In` or code `DINE_IN` — recognized as dine-in after normalization

### 9.3 Delivery Charge Warning

`FREE_DELIVERY_MINIMUM_AMOUNT` has unusual semantics:

- status `false` disables delivery charging in the current helper
- status `true` enables delivery method base price
- the value is the threshold at which delivery becomes free
- an invalid value parses as zero

Keep it disabled until delivery pricing has been tested.

---

## 10. Payment Methods

Generic master-data endpoint:

```text
GET /api/v1/master-data-values
    ?code=PAYMENT_METHOD
    &store_id=<active-store-id>
```

Canonical minimum response:

```json
{
  "status": "success",
  "message": "OK",
  "data": [
    {
      "id": 3200,
      "value": "CASH",
      "description": "Cash",
      "code": "CASH",
      "label": "Cash",
      "enabled": true,
      "sort_order": 1,
      "icon_key": "cash",
      "behavior": "collected",
      "requires_reference": false
    }
  ]
}
```

The ID `3200` is only an example. Use a real positive backend ID.

### 10.1 Payment Field Rules

- `id`: real positive integer
- `value`: stable uppercase machine code
- `description`: display label
- `code`: optional; defaults to `value`
- `label`: optional; defaults to `description`
- `enabled`: defaults to true
- `sort_order`: integer
- `icon_key`: optional
- `behavior`: `collected`, `credit`, or `terminal`
- `requires_reference`: boolean

### 10.2 Recommended Codes

| Code | Behavior | Required |
|---|---|---|
| `CASH` | `collected` | Yes |
| `CARD` | `collected` | As used |
| `UPI` | `collected` | As used |
| `COD` | `collected` | As used |
| `DEBIT` or `CREDIT` | `credit` | For customer-credit sales |
| `ONLINE` | `terminal` | For Pine Labs/terminal flows |

Use stable uppercase codes.

### 10.3 Cross-endpoint Consistency

The same payment records should be exposed consistently from:

```text
/api/v1/master-data-values?code=PAYMENT_METHOD
/api/v1/transaction/get-payment-methods
```

Billing frequently posts real master-data IDs. Legacy purchase or transaction
screens may still use codes or map keys. Keep IDs, codes, and labels aligned.

The Flutter UI can synthesize a fallback `CASH` option with an empty ID. This
keeps the UI visible but does not guarantee backend order acceptance. Always
seed a real payment method.

---

## 11. Generic Master Data

Canonical response:

```json
{
  "status": "success",
  "message": "OK",
  "data": [
    {
      "id": 1,
      "value": "MACHINE_CODE",
      "description": "Display label"
    }
  ]
}
```

Field rules:

- `status` should equal `"success"`
- `data` should be a JSON list
- `id` should be a positive JSON integer
- `value` should be a string
- `description` should be a string

Do not use ID `0`.

### 11.1 Generic Codes Actually Requested

The Flutter client requests only these generic master-data families:

| Code | Scope | Required when |
|---|---|---|
| `PAYMENT_METHOD` | Store | All sales/payment flows |
| `STOCK_GROUPING_FIELDS` | Store | Optional inventory configuration |
| `RACKS` | Store | Purchase/product stock workflows |
| `CASH_DENOMINATIONS` | Store | Shift and day-close cash breakdown |
| `TABLE_LIST` | Store | Restaurant table service |
| `EXPENSE_CATEGORY` | Store | Expense module |
| `EXPENSE_CATEGORIES` | Store | Legacy expense alias only |

Stores, units, taxes, suppliers, shifts, customers, and transaction account
types are not generic master-data codes in the current client. They use separate
endpoints or workflows.

### 11.2 Stock Grouping Fields

Supported exact values:

- `PRICE`
- `MRP`
- `PURCHASE_PRICE`
- `UNIT`
- `HSN_CODE`
- `TAX_RATE`
- `WHOLESALE_PRICE`
- `WHOLESALE_MIN_UNIT`

Recommended initial list:

```json
[
  {"id": 1, "value": "PRICE", "description": "Price"},
  {"id": 2, "value": "UNIT", "description": "Unit"}
]
```

If the list is empty or unavailable, Flutter falls back to price plus unit.

### 11.3 Racks

Racks are optional for retail sales.

Because different purchase/product consumers use the value and description
inconsistently, use the same stable token for both:

```json
{
  "id": 1,
  "value": "RACK_A",
  "description": "RACK_A"
}
```

---

## 12. Units

Units are fetched from a separate endpoint:

```text
GET /api/v1/product/list-units?store_id=<active-store-id>
```

Expected shape:

```json
{
  "status": "success",
  "message": "OK",
  "data": {
    "PCS": "PCS",
    "KG": "KG",
    "LTR": "LTR"
  }
}
```

The model expects `data` to be a string-to-string map.

Use stable unit keys. Using the same token as key and display value avoids
legacy key/display inconsistencies.

Every seeded product should use a unit resolvable from this endpoint.

Malformed unit responses can abort store bootstrap.

---

## 13. Categories and Products

### 13.1 Category Endpoints

Store bootstrap loads three category scopes:

```text
GET /api/v1/category/list-category?type=sellable
GET /api/v1/category/list-category
GET /api/v1/category/list-category?type=purchasable
```

Each receives:

- `page`
- `store_id`

Seed at least one sellable category for a sales tenant.

Recommended category fields:

```json
{
  "id": 1,
  "name": "General",
  "slug": "general",
  "names": [],
  "image_url": null,
  "icon_url": null,
  "parent": null
}
```

### 13.2 Product Endpoint

```text
GET /api/v1/product/executive/list-products
    ?page=<page>
    &store_id=<active-store-id>
```

The client requests pages in concurrent batches.

Recommended minimum product:

```json
{
  "product_id": 1,
  "category_id": 1,
  "product_name": "Test Product",
  "product_slug": "test-product",
  "barcode": "10000001",
  "item_code": "ITEM-001",
  "unit": "PCS",
  "currency": "INR",
  "price": {
    "price": "100.00"
  },
  "mrp": "100.00",
  "taxes": [],
  "stock": [],
  "sale_units": [],
  "variants": [],
  "sellable": true,
  "purchasable": true,
  "sort_order": 1
}
```

Operational requirements:

- positive product ID
- valid category ID
- non-empty product name
- `sellable=true`
- valid unit
- valid selling price

If the resolved price is zero, Flutter prompts the cashier to enter a price
when adding the product.

### 13.3 Taxes

Taxes are not loaded from a standalone generic tax master.

The product catalog may return:

```json
{
  "taxes": [
    {
      "id": 1,
      "name": "VAT",
      "code": "VAT",
      "rate": "5.00",
      "source": "category"
    }
  ]
}
```

For taxable tenants:

- seed category/product tax relationships
- ensure `/api/v1/calculate-tax` works
- return product tax data in the catalog
- ensure order calculations and printed totals agree

If tax calculation fails in some stock-creation paths, the client can continue
with zero tax. That is not safe for taxable jurisdictions.

---

## 14. Stock and Product Variants

### 14.1 Stock-disabled Tenant

Recommended for initial setup:

```json
{
  "stock_enabled": false
}
```

Products can transact using base price without store stock rows.

### 14.2 Stock-enabled Tenant

Every sellable stock-managed product should return at least one stock row for
the active store.

Required stock concepts:

- real stock ID
- product ID
- store ID
- quantity
- price
- MRP
- unit
- optional purchase price
- optional HSN code
- optional tax rate

Do not enable stock globally before this data is complete.

### 14.3 Variants

Only enable:

```json
{
  "code": "PRODUCT_VARIANT_ENABLED",
  "status": true,
  "value": ""
}
```

when every applicable product has:

- stable variant IDs
- active flags
- attributes
- SKU and/or barcode
- variant pricing
- exact store-scoped variant stock

For a non-variant product:

```text
product_variant_id = null
```

For a variant product, each stock row must use the exact variant ID.

Do not let variant sales consume:

- general product stock
- another variant's stock

### 14.4 Multiple Sale Units

Enable `MULTI_SALE_UNIT_ENABLED` only when products include complete:

- sale-unit IDs
- unit names
- conversion rates
- optional barcodes
- unit-specific or resolved prices

---

## 15. Restaurant Seeding

### 15.1 Delivery Methods

Recommended restaurant delivery set:

```json
[
  {
    "id": 11,
    "code": "STORE_TAKEAWAY",
    "name": "Store Takeaway",
    "prices": []
  },
  {
    "id": 12,
    "code": "DINE_IN",
    "name": "Dine In",
    "prices": []
  },
  {
    "id": 13,
    "code": "CAR_DELIVERY",
    "name": "Car Delivery",
    "prices": []
  },
  {
    "id": 14,
    "code": "DOOR_DELIVERY",
    "name": "Door Delivery",
    "prices": []
  }
]
```

Use real backend IDs.

### 15.2 Tables

Tables come from:

```text
GET /api/v1/master-data-values
    ?code=TABLE_LIST
    &store_id=<active-store-id>
```

Example:

```json
{
  "status": "success",
  "message": "OK",
  "data": [
    {
      "id": 1,
      "value": "TABLE_1",
      "description": "Table 1"
    },
    {
      "id": 2,
      "value": "TABLE_2",
      "description": "Table 2"
    }
  ]
}
```

Important:

- Flutter uses `value`, such as `TABLE_1`, as the submitted `table_id`
- it does not submit the numeric master-data ID
- table values must remain stable

If the API fails, the current table provider fabricates mock IDs such as `T1`.
Those are development fallbacks and must not be relied on in production.

### 15.3 Kitchen Statuses

Endpoint:

```text
GET /api/v1/cart/cart-item-statuses
```

Required full kitchen workflow:

```json
{
  "status": "success",
  "message": "OK",
  "data": [
    {
      "id": 1,
      "value": "START",
      "description": "Start Cooking"
    },
    {
      "id": 2,
      "value": "READY",
      "description": "Ready"
    },
    {
      "id": 3,
      "value": "SERVED",
      "description": "Served"
    }
  ]
}
```

Exact values matter:

- `START` enables the start-cooking transition
- `READY` enables the ready transition
- `SERVED` enables served/complete behavior

Missing `SERVED` explicitly breaks Mark Served and KOT + Bill auto-serve.

### 15.4 Restaurant Settings

Recommended initial values:

```json
[
  {
    "code": "ENABLE_SEND_TO_KITCHEN_BUTTON",
    "status": true,
    "value": ""
  },
  {
    "code": "ENABLE_KOT_PRINT",
    "status": false,
    "value": ""
  },
  {
    "code": "ENABLE_KOT_BILL_BUTTON",
    "status": false,
    "value": ""
  },
  {
    "code": "KOT_BILL_AUTO_MARK_SERVED",
    "status": false,
    "value": ""
  },
  {
    "code": "KOT_BILL_ALLOWED_FOR_DINE_IN",
    "status": false,
    "value": ""
  }
]
```

Enable KOT printing only after printer/device configuration is complete.

Restaurant menu selling uses the normal category and product catalog. The
current `MenuProvider` is not a separate production menu-data contract.

---

## 16. Shift and Day Close

There is no separate shift master-data list consumed by Flutter.

Opening a shift creates a day-close/opening record dynamically, linked to:

- authenticated user
- active store
- business date
- opening date/time
- opening cash
- optional denomination breakdown

Defaults:

- shift name: `Shift`
- opening time: store `store_open_time`
- fallback opening time: `08:00:00`

### 16.1 Settings

Keep these off until the backend workflow is ready:

```json
[
  {
    "code": "COMPULSORY_SHIFT_OPEN_",
    "status": false,
    "value": ""
  },
  {
    "code": "COMPULSORY_DAY_CLOSE_REGISTER",
    "status": false,
    "value": ""
  }
]
```

The trailing underscore in `COMPULSORY_SHIFT_OPEN_` is intentional.

When enabled, the client depends on the day-close pending/open APIs and valid
user/store IDs.

### 16.2 Cash Denominations

Code:

```text
CASH_DENOMINATIONS
```

Example:

```json
[
  {"id":1,"value":"500","description":"500"},
  {"id":2,"value":"200","description":"200"},
  {"id":3,"value":"100","description":"100"},
  {"id":4,"value":"50","description":"50"},
  {"id":5,"value":"20","description":"20"},
  {"id":6,"value":"10","description":"10"},
  {"id":7,"value":"5","description":"5"},
  {"id":8,"value":"1","description":"1"}
]
```

Values must parse as numbers. The client sorts them numerically in descending
order.

`WORKING_TIME` should use:

```text
HH:mm - HH:mm
```

However, the current Flutter code parses the start time without applying it to
day-close submission, so it is presently informational.

---

## 17. Purchase and Stock-intake Data

Sales-only tenants do not require suppliers or racks.

Purchase-enabled tenants need:

- real store
- real supplier
- purchasable category
- product
- unit
- purchase price
- retail price
- optional rack
- payment method when recording payment

Supplier requirements:

- positive supplier ID
- user/name
- phone and/or email
- tenant/company association
- store visibility as required

The purchase provider inserts a synthetic “Select Supplier” row with ID `0`.
Do not use ID `0` for a real supplier.

Recommended rack:

```json
{
  "id": 1,
  "value": "RACK_A",
  "description": "RACK_A"
}
```

Purchase payloads may use payment codes while other modules use payment IDs.
Keep payment records consistent across both APIs.

---

## 18. Expense, Invoice, and Voucher Features

### 18.1 Expenses

Seed only when the expense module is enabled:

- `EXPENSE_CATEGORY`
- `PAYMENT_METHOD`
- expense/debit accounts
- payment/credit accounts

The client first probes:

```text
EXPENSE_CATEGORY
```

and then the legacy alias:

```text
EXPENSE_CATEGORIES
```

Expense submission uses:

- category master-data ID
- payment method ID
- expense account ID
- payment account ID
- hard-coded status `SUCC`

### 18.2 Invoice/Voucher Transaction Screens

These are separate endpoints, not generic master-data codes:

```text
GET /api/v1/transaction/get-account-types?type=invoice
GET /api/v1/transaction/get-account-types?type=voucher
GET /api/v1/transaction/get-payment-methods
GET /api/v1/user/get-users
```

Return valid maps/lists even if the feature has no initial records. Some legacy
models do not safely parse null or malformed `data`.

### 18.3 Banks

Banks are optional for basic cash sales.

Seed store-linked active bank/account records when using:

- bank reports
- vouchers
- bank account selection
- QR/payment gateway printing
- expense payment accounts

---

## 19. ZATCA

Keep both flags off for non-Saudi tenants:

```json
[
  {
    "code": "ZATCA_PHASE_1",
    "status": false,
    "value": ""
  },
  {
    "code": "ZATCA_PHASE_2",
    "status": false,
    "value": ""
  }
]
```

Before enabling ZATCA, seed and return:

- country
- company legal identity
- `cr_number`
- `vat_number`
- `zatca_company_name`
- applicable ZATCA endpoint configuration
- document configuration
- customer VAT/CR details for B2B invoices where required

Enabling the flags without the complete compliance setup exposes actions that
cannot complete correctly.

---

## 20. Pine Labs / Terminal Payments

Keep disabled initially:

```json
{
  "code": "PINELAB_PAYMENT",
  "status": false,
  "value": ""
}
```

Before enabling:

- seed an `ONLINE` payment method
- set behavior to `terminal`
- set `requires_reference=true`
- configure the device-side terminal integration
- validate transaction-reference handling

The current Flutter settings and backend contracts do not contain a tenant
`terminal_id` master. Pine Labs credentials/configuration are not modeled as a
generic tenant terminal record in this client.

---

## 21. Store Bootstrap Endpoint Checklist

After selecting a store, the Flutter client loads data in this approximate
awaited order:

1. Roles and permissions
2. Delivery methods
3. General settings
4. Website/app settings
5. Customers
6. Admin branding
7. Banks
8. Invoice account types
9. Transaction payment methods
10. Master-data payment methods
11. Stock grouping fields
12. Voucher account types
13. Users
14. Store details
15. Suppliers
16. Units
17. Racks
18. Document configurations
19. Category scopes
20. Product catalog

Endpoint checklist:

```text
GET /api/v1/roles/list
GET /api/v1/logistics/list-delivery-methods
GET /api/v1/general
GET /api/v1/website-settings
GET /api/v1/customer/customer-searchbar
GET /api/v1/admin-settings
GET /api/v1/get-banks
GET /api/v1/transaction/get-account-types?type=invoice
GET /api/v1/transaction/get-payment-methods
GET /api/v1/master-data-values?code=PAYMENT_METHOD
GET /api/v1/master-data-values?code=STOCK_GROUPING_FIELDS
GET /api/v1/transaction/get-account-types?type=voucher
GET /api/v1/user/get-users
GET /api/v1/stores/get-stores
GET /api/v1/get-suppliers
GET /api/v1/product/list-units
GET /api/v1/master-data-values?code=RACKS
GET /api/v1/document/document-configs
GET /api/v1/category/list-category?type=sellable
GET /api/v1/category/list-category
GET /api/v1/category/list-category?type=purchasable
GET /api/v1/product/executive/list-products
```

Feature-entry requests:

```text
GET /api/v1/master-data-values?code=TABLE_LIST
GET /api/v1/cart/cart-item-statuses
GET /api/v1/master-data-values?code=CASH_DENOMINATIONS
GET /api/v1/master-data-values?code=EXPENSE_CATEGORY
```

Optional modules should still return valid HTTP 200 JSON in their expected
shape, even when their data is empty.

Some bootstrap calls are not individually guarded against malformed responses.
A parse exception can leave the user on store selection instead of opening the
main POS.

---

## 22. Scope Model

### Control-plane Scope

- tenant key to domain mapping
- `/find-domain`

### Tenant Scope

- all tenant server requests use `X-Tenant`
- company identity
- company-level properties/settings

### Store Scope

`store_id` scopes most POS data:

- settings
- delivery methods
- categories
- products
- stock
- customers
- payment methods
- suppliers
- units
- racks
- tables
- banks
- document configurations
- orders

### User Scope

- login
- role and permissions
- assigned stores
- shift/day-close ownership

### Local Device Scope

These are not backend seed records:

- selected tenant key
- discovered base URL
- selected store
- printer configuration
- Pine Labs device integration
- cached products/categories/customers
- offline orders
- local UI dimensions/preferences
- local locale and keyboard preferences

### Missing Scopes

The app/general settings requests do not include:

- user ID
- device ID
- terminal ID
- restaurant ID
- location ID

Restaurant behavior is driven by:

- active store
- user role
- website flags
- delivery method codes/names
- `TABLE_LIST`
- kitchen statuses

---

## 23. Known Client-side Risks Backend Must Design Around

### 23.1 Duplicate Settings Fetches

`AppSettingsProvider` and `GeneralSettingsProvider` automatically fetch when
constructed, then store bootstrap fetches them again.

The calls may overlap and neither provider has an in-flight request guard.

### 23.2 Stale Cross-store Settings

On a failed store refresh, the settings providers do not clear their previous
models. Settings from the prior store can remain active.

Backend settings responses should therefore be:

- reliably available
- correctly store-scoped
- fast enough to avoid unnecessary races
- structurally consistent

### 23.3 Customer Selection

`SKIP_CUSTOMER_SELECTION=true` does not consistently remove customer
validation. Seed a walk-in customer instead of depending on anonymous checkout.

### 23.4 Delivery Fallback ID

When delivery methods are unavailable, the client can fabricate:

```text
id = 11
name = Store Takeaway
```

This may submit a nonexistent foreign key. Always seed a real delivery method.

### 23.5 Payment Fallback

The client can fabricate a `CASH` option with an empty ID. Always seed a real
positive payment-method ID.

### 23.6 Mock Restaurant Tables

When table loading fails, mock table IDs can appear. Never use that fallback as
production data.

### 23.7 Currency Fallbacks

Missing currency is displayed inconsistently as:

- blank
- `INR`
- `SAR`

Always seed `CURRENCY`.

### 23.8 Null Status Is Not Omission

A setting row with:

```json
{
  "status": null
}
```

becomes false, including for flags whose missing-code default is true. Return
explicit booleans.

### 23.9 Unknown Default Payment

Default selection currently recognizes core codes such as:

- `CASH`
- `CARD`
- `UPI`
- `COD`

Do not configure a dynamic method ID as `DEFAULT_PAYMENT_METHOD`.

### 23.10 Dead or Partially Implemented Settings

- `confirm_oversell_on_zero_stock` is parsed but currently unused.
- `WORKING_TIME` is parsed during day close but currently does not affect the
  submitted opening time.
- `COMPULSORY_DAY_CLOSE_REGISTER` presents a pending-day-close dialog, but the
  current UI still permits declining it.

---

## 24. Clean-install Acceptance Test

Perform this test with no existing local cache.

### 24.1 Retail Test

1. Enter the tenant API key.
2. Verify the correct domain is discovered.
3. Sign in with the seeded POS user.
4. Confirm at least one assigned store appears.
5. Select the store.
6. Confirm store bootstrap completes without parse or HTTP errors.
7. Confirm the walk-in customer is automatically selected.
8. Confirm at least one sellable category is visible.
9. Confirm at least one sellable product is visible.
10. Add the product to the cart.
11. Open checkout.
12. Confirm the real Store Takeaway delivery method is selected.
13. Confirm the real Cash payment method is selected.
14. Confirm the order.
15. Verify the backend receives:
    - real `store_id`
    - real customer ID or accepted phone
    - real payment method ID/code
    - real delivery method ID
    - valid product IDs
16. Fetch order details.
17. Print a receipt.

### 24.2 Inventory Test

Repeat the retail test with:

- `stock_enabled=true`
- `ALLOW_OVERSELL=false`

Verify:

- correct store stock is selected
- quantity is reduced
- insufficient stock invokes the intended policy
- no stock from another store or variant is consumed

### 24.3 Restaurant Test

1. Sign in as `restaurant_sales` or `attender`.
2. Select the store.
3. Confirm real tables load from `TABLE_LIST`.
4. Select a table or delivery method.
5. Add menu products from the normal product catalog.
6. Select the walk-in customer.
7. Send the order to kitchen.
8. Verify the kitchen screen receives the order.
9. Move items through:
    - `START`
    - `READY`
    - `SERVED`
10. Confirm and bill the order.
11. Verify table ID, delivery ID, customer, payments, and product IDs in the
    backend payload.

### 24.4 Optional Feature Tests

Test only enabled modules:

- discount/coupon
- delivery charges
- product variants
- multiple sale units
- purchase orders
- expenses
- shift/day close
- B2B
- ZATCA
- Pine Labs

---

## 25. Backend Provisioning Sign-off

A tenant is ready when:

- [ ] tenant key resolves to the intended HTTPS domain
- [ ] tenant server accepts `X-Tenant`
- [ ] login returns a non-empty access token
- [ ] user ID is positive
- [ ] company ID is positive
- [ ] user has a supported role
- [ ] user has at least one assigned positive-ID store
- [ ] roles and permissions load
- [ ] `/general` returns real booleans
- [ ] all recognized website settings have explicit values
- [ ] currency is correct
- [ ] walk-in customer exists and its exact phone matches the setting
- [ ] real Store Takeaway delivery method exists
- [ ] real Cash payment method exists
- [ ] payment endpoints expose consistent IDs and codes
- [ ] units endpoint returns a valid map
- [ ] at least one sellable category exists
- [ ] at least one sellable product exists
- [ ] product price is valid
- [ ] product unit resolves
- [ ] stock rows are complete if stock is enabled
- [ ] variant stock is exact if variants are enabled
- [ ] document configuration is available for predictable printing
- [ ] store bootstrap completes on a clean installation
- [ ] a complete sale succeeds
- [ ] a receipt prints correctly
- [ ] restaurant tables/statuses pass if restaurant mode is enabled
- [ ] shift/day-close passes if enforcement is enabled
- [ ] tax/ZATCA passes if applicable

---

## 26. Core Referential Relationships

The backend seeder must preserve these relationships:

```text
tenant API key
    -> tenant domain

login user
    -> company
    -> role
    -> assigned stores[]

active store_id
    -> settings
    -> customers
    -> delivery methods
    -> payment methods
    -> categories
    -> products
    -> stock
    -> suppliers
    -> units
    -> tables
    -> document configs

AUTO_ASSIGN_DEFAULT_CUSTOMER.value
    == exact customer.phone

DEFAULT_DELIVERY_METHOD.value
    == delivery method id, name, or preferably stable code

DEFAULT_PAYMENT_METHOD.value
    == uppercase payment method code

product.category_id
    -> category.id

stock.product_id
    -> product.product_id

stock.store_id
    -> active store_id

variant stock.product_variant_id
    -> exact product variant.id

TABLE_LIST.value
    -> order table_id

cart item status numeric id
    -> START / READY / SERVED value
```

These links should be checked as part of the tenant seed transaction, not fixed
manually after first login.

