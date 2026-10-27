# CloudPOS Postman collection update report

Date: 2026-10-27. Source of truth: `lib/resources/app_url.dart` plus the providers and payload classes that call each endpoint (branch gokul-dev). Verified against the FunzCart demo tenant (`https://erpdemo.cloudposai.com`, store 2) with the app's saved session.

Output: `docs/postman/cloudpos.updated.postman_collection.json` (same `_postman_id` and name as the current collection, Postman v2.1, `{collection:{...}}` wrapper). Nothing was uploaded to Postman.

## Counts

| | Requests | Run live, 2xx | Run live, error status | Not run |
|---|---|---|---|---|
| Added | 65 | 38 | 11 | 16 |
| Fixed | 131 | 74 | 14 | 43 |
| Unchanged (headers/description/example only) | 24 | 11 | 2 | 11 |
| Moved to Legacy | 40 | 14 | 17 | 9 |

- Requests in the updated collection: 260 plus the 5 untouched Whatsapp requests (was 197 including Whatsapp).
- Saved examples added: 181 (137 with 2xx, the rest document the real error the backend returns). Examples are trimmed to 2 array items and secret-looking fields are `<redacted>`; Laravel stack traces are replaced with `<trimmed>`.
- Collection level: variables `server`, `tenant_key`, `token`, `store_id`, `locale`; auth Bearer `{{token}}`; the pre-request script now takes `X-Tenant` from the environment's `apiKey` or, if absent, from `tenant_key` (upsert, so no duplicate header).
- Every added or fixed request carries `X-Tenant: {{tenant_key}}`, `Accept: application/json`, `Accept-Language: {{locale}}` and inherits Bearer `{{token}}`. Sign-in, forgot, reset, find-domain and broadcasting/auth are `noauth`, as in the app.
- Requests kept because the app doesn't use them, and requests moved to Legacy, still use their original `{{executive_token}}` auth.
- Whatsapp folder: byte-identical to the original (checked by script).
- Secrets: 5 kept requests had literal bearer tokens, X-Tenant keys or passwords in the URL/body. They now use `{{token}}`, `{{tenant_key}}` or `{{password}}`: Cart / add-to-cart Bulk; User / change-password; Customer / update-profile; Root / Change Password; Dashboard Copy / dashboard. Requests rebuilt from the app lost their literal headers too. The output contains no session token or API key (checked by script).
- Renamed: Folder "Payment Copy" -> "Payment" (it is the only payment folder, not a duplicate); Order / change order status Copy -> change order status. The four day-close requests moved from Report to the new Daily Sales Close folder.

## Real app-vs-backend mismatches (likely bugs)

- `GET /api/v1/discount/apply-coupon` returns **500** "product id field is required when cart id is not present". `providers/cart_provider.dart:1355` sends only `price`, `coupon_code`, `store_id`. The same call with `product_id=12419` returns 200 with the discount. So server-side coupon validation always fails from the app.
- `GET /api/v1/transaction/get-payment-methods` returns **404**. `providers/invoice_provider.dart:990` and `providers/offline_sync_endpoints.dart:71,196` call it, so the offline sync dataset for it always fails.
- `GET /api/v1/transaction/get-account-types?type=invoice|voucher` returns **404**. Called by `invoice_provider.dart:1210,1262` and offline sync.
- `GET /api/v1/user/get-users` returns **404**. Called by `invoice_provider.dart:1310` and offline sync. `GET /api/v1/user/users` works (User / Search user by phone).
- `GET /api/v1/file/list-files` returns **404**. The backend route is `GET /api/v1/files/list-files` (plural), which returns 200. App: `grid_provider.dart:1231`.
- `GET /api/v1/faq/faqs/company/1` returns **404**. The backend has `GET /api/v1/faqs` (200). App: `company_provider.dart:32`, `screens/kiosk/faq.dart:51`.
- `GET /api/v1/company/subscription-status` returns **404**. App: `features/subscription/presentation/subscription_provider.dart:122`. It falls back to the COMPANY_SUBSCRIPTION_* settings.
- `GET /api/v1/dashboard/orders` returns **404**. App: `dashboard_provider.dart:60` (legacy dashboard graph).
- `POST /api/v1/order/executive/order-details` (no order number) returns **404**. Restaurant order panel: `cart_provider.dart:1471` via `order_panel.dart:831,4655`. The route is `GET .../order-details/{order_number}`.
- `POST /api/v1/product/executive/list-products` returns **405**. Legacy product wizard refresh: `grid_provider.dart:394`. GET only, and that call sends the tenant as an `api_key` header.
- `GET /api/v1/purchase/receive-purchase-order/{id}` returns **405**. Purchase details: `purchase_api_orders.dart:9`. POST only. The app falls back to the list row's items.
- `GET /api/v1/accounts/company-accounts/{accountName}` returns **404**. App: `company_account_provider.dart:492`. Only the index route exists; the `?account_name=` form works.
- The legacy product wizard (Add/Edit product tabs) calls 8 routes that all return **404**. The routes: `product/add-product-general-item`, `add-product-name`, `add-product-props`, `add-product-image`, `edit-product-general-item`, `edit-product-name`, `edit-product-props`, and `product/fetch-prop-values`. The wizard is still reachable (`screens/product/tabbar_for_*`). The name calls also swap `[en]`/`[ar]`.
- Legacy purchase, transaction and report screens call routes that return **404**. `purchases/*` (list-purchase-order, voucher-searchbar, list-purchase-items, add/remove-purchase-item, add-stock), `transaction/add-transaction`, and `reports/sales-report`, `reports/supplier-sales-report`, `reports/customer-account-book`.
- `POST /api/v1/customer/executive-add-address` returns **500** "The pincode id field is required" when `pincode_id` is null. The app sends null when no pincode is picked (`customer_address_controller.dart`). It worked with a real pincode id (4861).

Backend-side problems seen while verifying (no app change needed):

- **Debug mode is on for the demo.** Every 404/500 on erpdemo returns the Laravel exception class, server file path and full stack trace (`APP_DEBUG=true`).
- **Not-found returns 500.** `transaction-details/{id}`, `receipt-details/{id}`, `invoice-details/{id}` and `list-cart-items` answer 500 for a missing record, sometimes with `data: 404`.
- **Unhandled exception on unknown orders.** `list-return-order-items?order_number=<unknown>` returns 500 "Attempt to read property name on null".
- **Missing controller method.** `GET /api/v1/master-data/{code}` returns 500 (`UserController::getMasterDataByCode()` does not exist).
- **Routes without auth (from the route files, not tested).** `customer/customer-last-purchases`, `accounts/company-accounts`, `master-data-values` and `sync/changes` are outside `auth:sanctum`.

Expected by permission, not bugs: `sales-report`, `discount-sales-report` and `sales-executive-report-admin` return **403** for the session's role. The saved examples show that 403.

## Endpoints not verified

These were documented from the app code but not executed, as required. Each item's description says "Not executed during verification (side effects)".

- **Never called (forbidden list):**
  - `zatca/*` (5 print/resync calls plus bulk-send, and the URL-less compliance item)
  - `user/signin`, `user/signout`, `user/forgot`, `user/reset`, `customer/change-password`
  - `order/cancel-order`, `product/delete-product`
  - `stocks/adjust`, `stocks/move`, `stocks/withdraw`
  - `daily-sales-close/create`, `daily-sales-close/open`
  - payment-gateway create/verify, logistics waybill/create-order
- **Other writes (route existence checked only):** add-to-cart, change-cart-item-price, remove-from-cart, add-to-order (sale and save), update-order, confirm-order, order-change-status, order-change-payment-status, update-cart-item-status, update-order-items-status, acknowledge-kot-print, sales-return, complete-return-order, quotation create/update-status/convert, packing, external-delivery, category add/edit, product create/edit, update-stock, add-stock, complete-purchase, purchase order add/receive, purchase return create, supplier voucher create, general-payment create, receipt create, invoice create, voucher create.
  - How they were checked: a GET to the path, which never runs the write handler. 405 means the POST route exists; 404 means there is no route.
  - For `quotations/update-status`, `quotations/convert-to-order`, `purchase/returns` and `order/packing/{no}`, the GET hit a different route, so the check is inconclusive. The POST routes exist in the backend route files.
- **Run with test data (all on the demo tenant):**
  - add-customer, customer-edit, executive-add-address and executive-update-address on a new **Docs Demo Customer** (customer id 2768, address id 109).
  - add-supplier and update-suppliers on a new **Docs Demo Supplier** (id 388).
  - translate, customer-last-purchases, find-domain and broadcasting/auth (403 for a dummy socket, as expected).

## Decisions for you

1. **Demo records:** delete the Docs Demo Customer (2768) and Docs Demo Supplier (388) from FunzCart demo if you don't want them. Deletes were not allowed during verification.
2. **Legacy screens:** the legacy product wizard, legacy purchase cart, legacy vouchers and legacy reports still call 404 routes. Either remove those screens and their APPUrl getters, or ask the backend to restore the routes. Until then they stay in their normal folders with a WARNING in the description.
3. **Auth variables:** 159 older requests use `{{executive_token}}` (plus `{{customer_token}}`, `{{token}}`). Switch them to inherit the collection's `{{token}}` if you want a single variable.
4. **Rotate leaked secrets:** the currently uploaded collection still contains the literal bearer tokens, X-Tenant keys and passwords listed above. Rotate them after replacing the collection.
5. **Non-app requests that work:** these were kept in place (not used by the app) rather than moved to Legacy. Move them if you want the collection app-only:
   - Offer Products, Customer-Listing new, Search user by phone, update-profile, delivery-charge
   - add-payment, track-order, add-to-cart Bulk, Company Terms (prop-names), payment-gateway create/verify, Delhivery waybill/shipment

## Backend message (ready to forward)

```
Hi, while documenting the POS API on erpdemo we found a few issues:
1) APP_DEBUG seems on: 404/500 responses include stack traces and server paths.
2) The app calls these, but they 404: transaction/get-payment-methods, transaction/get-account-types, user/get-users, company/subscription-status, faq/faqs/company/1, dashboard/orders. Can we restore them or confirm the replacements?
3) discount/apply-coupon requires product_id or cart_id; the POS sends only price + coupon_code. Can it accept an order-level price check?
4) Not-found on transaction/receipt/invoice details returns 500 (should be 404), and master-data/{code} 500s (getMasterDataByCode missing).
```

## Added requests (65)

| Folder | Request | Method | Path | Change | Verified |
|---|---|---|---|---|---|
| Order | add-to-order (save order, status=saved) | POST | `/api/v1/order/add-to-order` | new (A5) | not run (route exists: GET probe 405) |
| Order | Change order payment status | POST | `/api/v1/order/order-change-payment-status` | new (A9) | not run (route exists: GET probe 405) |
| Order | Order search bar (unused) | GET | `/api/v1/order-searchbar` | new (A12) | 404 |
| Restaurant | Order details (restaurant POST variant) | POST | `/api/v1/order/executive/order-details` | new (A14) | 404 |
| Packing & Delivery | List external logistics | GET | `/api/v1/order/external-logistics` | new (A15) | 200 |
| Packing & Delivery | List external logistic warehouses | GET | `/api/v1/order/external-logistics/{external_logistic_id}/warehouses` | new (A16) | 200 |
| Packing & Delivery | Create external delivery job | POST | `/api/v1/order/order-details/{order_number}/external-delivery` | new (A17) | not run (route exists: GET probe 405) |
| Packing & Delivery | Save packing (multipart) | POST | `/api/v1/order/packing/{order_number}` | new (A18) | not run (GET probe 200, inconclusive) |
| Packing & Delivery | List packing staff | GET | `/api/v1/order/packing-staff` | new (A19) | 200 |
| Packing & Delivery | Download delivery note PDF | GET | `/api/v1/order/documents/delivery-note/{order_number}` | new (A20) | 200 |
| Packing & Delivery | Download delivery invoice PDF | GET | `/api/v1/order/documents/delivery-invoice/{order_number}` | new (A21) | 200 |
| Restaurant | Acknowledge KOT print | POST | `/api/v1/order/acknowledge-kot-print` | new (A27) | not run (route exists: GET probe 405) |
| Quotation | Convert quotation to order | POST | `/api/v1/quotations/convert-to-order` | new (A32) | not run (GET probe 500, inconclusive) |
| Proforma Invoice | List proforma invoices | GET | `/api/v1/invoice/proforma-invoices` | new (A33) | 200 |
| Proforma Invoice | Proforma invoice details | GET | `/api/v1/invoice/proforma-invoices/{id}` | new (A34) | 200 |
| Offers | POS offer sync | GET | `/api/v1/offers/pos-sync` | new (A40) | 200 |
| Payment | Transaction payment methods | GET | `/api/v1/transaction/get-payment-methods` | new (A46) | 404 |
| Category | List purchasable categories | GET | `/api/v1/category/list-category` | new (B1) | 200 |
| Category | List all categories | GET | `/api/v1/category/list-category` | new (B2) | 200 |
| Category | Category details by slug | GET | `/api/v1/category/slug/{slug}` | new (B3) | 200 |
| Product | List products (grid / filters) | GET | `/api/v1/product/executive/list-products` | new (B7) | 200 |
| Product | List quick-access products | GET | `/api/v1/product/executive/list-products` | new (B8) | 200 |
| Product | List products (legacy POST) | POST | `/api/v1/product/executive/list-products` | new (B9) | 405 |
| Product | Realtime catalog refresh | GET | `/api/v1/product/executive/list-products` | new (B11) | 200 |
| Product | Add product general item (legacy) | POST | `/api/v1/product/add-product-general-item` | new (B14) | not run (no route: GET probe 404) |
| Product | Delete product | POST | `/api/v1/product/delete-product` | new (B23) | not run (side effects) |
| Product | Generate SKU | GET | `/api/v1/product/generate-sku` | new (B26) | 200 |
| Tax | List active taxes | GET | `/api/v1/tax/list-tax` | new (B29) | 200 |
| Stocks | Adjust stock | POST | `/api/v1/stocks/adjust/{id}` | new (B36) | not run (side effects) |
| Stocks | Move stock to another store | POST | `/api/v1/stocks/move/{id}` | new (B37) | not run (side effects) |
| Stocks | Withdraw stock | POST | `/api/v1/stocks/withdraw/{id}` | new (B38) | not run (side effects) |
| Purchase | Get purchase order details (GET on receive URL) | GET | `/api/v1/purchase/receive-purchase-order/{purchaseId}` | new (C1) | 405 |
| Purchase / Old | Add purchase stock (legacy) | POST | `/api/v1/purchases/add-stock` | new (C11) | not run (no route: GET probe 404) |
| Purchase Returns | List purchase returns | GET | `/api/v1/purchase/returns` | new (C13) | 200 |
| Purchase Returns | Purchase return details | GET | `/api/v1/purchase/returns/{id}` | new (C14) | 200 |
| Purchase Returns | Returnable items for a purchase voucher | GET | `/api/v1/purchase/{purchaseVoucherId}/returnable-items` | new (C15) | 200 |
| Purchase Returns | Create purchase return | POST | `/api/v1/purchase/returns` | new (C16) | not run (GET probe 200, inconclusive) |
| Expenses | List general payments (expenses) | GET | `/api/v1/general-payment/list-general-payments` | new (C24) | 200 |
| Expenses | General payment account options | GET | `/api/v1/general-payment/account-options` | new (C25) | 200 |
| Expenses | Create general payment (expense) | POST | `/api/v1/general-payment/create-general-payment` | new (C26) | not run (route exists: GET probe 405) |
| Zatca | ZATCA bulk send | POST | `/api/v1/zatca/bulk-send` | new (D19) | not run (side effects) |
| Customer | Customers delta sync (updated_at_range) | GET | `/api/v1/customer/customer-searchbar` | new (D26) | 200 |
| Customer | Add customer address | POST | `/api/v1/customer/executive-add-address` | new (D28) | 200 |
| Data List / Location | List pincodes | GET | `/api/v1/location/list-pincodes` | new (D33) | 200 |
| Transactions | Company account with transactions | GET | `/api/v1/accounts/company-accounts` | new (D36) | 200 |
| Transactions | Company account by name (path) | GET | `/api/v1/accounts/company-accounts/{accountName}` | new (D37) | 404 |
| Tenant | Find tenant domain (API key lookup) | POST | `/api/v1/find-domain` | new (E0) | 200 |
| Auth | Company subscription status | GET | `/api/v1/company/subscription-status` | new (E3) | 404 |
| Dashboard | Dashboard orders graph (legacy) | GET | `/api/v1/dashboard/orders` | new (E17) | 404 |
| Dashboard | Sales stats | GET | `/api/v1/dashboard/sales-stats` | new (E18) | 200 |
| Dashboard | Orders widget | GET | `/api/v1/dashboard/orders-widget` | new (E21) | 200 |
| Dashboard | Latest orders | GET | `/api/v1/dashboard/latest-orders` | new (E22) | 200 |
| Dashboard | Customer transactions summary | GET | `/api/v1/dashboard/customer-transactions-summary` | new (E23) | 200 |
| Dashboard | Suppliers graph | GET | `/api/v1/dashboard/suppliers-graph` | new (E24) | 200 |
| Dashboard | Revenue stats | GET | `/api/v1/dashboard/revenue-stats` | new (E25) | 200 |
| Dashboard | ZATCA overview | GET | `/api/v1/dashboard/zatca-overview` | new (E29) | 200 |
| Dashboard | Customer stats | GET | `/api/v1/dashboard/customer-stats` | new (E30) | 200 |
| Dashboard | Products stats | GET | `/api/v1/dashboard/products-stats` | new (E31) | 200 |
| Report | Sales report (web-style) | GET | `/api/v1/sales-report` | new (E41) | 403 |
| Report | Discount sales report | GET | `/api/v1/discount-sales-report` | new (E42) | 403 |
| Report | Stock report | GET | `/api/v1/stock-report` | new (E44) | 200 |
| Daily Sales Close | Day close pending status | GET | `/api/v1/daily-sales-close/pending-status` | new (E48) | 200 |
| Daily Sales Close | Open shift | POST | `/api/v1/daily-sales-close/open` | new (E51) | not run (side effects) |
| Sync | Realtime sync delta feed | GET | `/api/v1/sync/changes` | new (E52) | 200 |
| Sync | Realtime channel auth (Reverb) | POST | `/api/broadcasting/auth` | new (E53) | 403 |

## Fixed requests (131)

| Folder | Request | Method | Path | Change | Verified |
|---|---|---|---|---|---|
| Purchase / Old | Add purchase item | POST | `/api/v1/purchases/add-purchase-item` | path /api/purchases/add-purchase-item -> /api/v1/purchases/add-purchase-item; body formdata -> urlencoded; body keys aligned with app (7 keys) | not run (no route: GET probe 404) |
| Purchase / Old | List purchase item | GET | `/api/v1/purchases/list-purchase-items` | path /api/purchases/list-purchase-items -> /api/v1/purchases/list-purchase-items; query params added: store_id | 404 |
| Purchase / Old | Remove purchase item | POST | `/api/v1/purchases/remove-purchase-item` | path /api/purchases/remove-purchase-item -> /api/v1/purchases/remove-purchase-item; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Purchase / Old | List purchase order | GET | `/api/v1/purchases/list-purchase-order` | path /api/purchases/list-purchase-order -> /api/v1/purchases/list-purchase-order; query params added: page, store_id | 404 |
| Purchase / Old | List Voucher Search | GET | `/api/v1/purchases/voucher-searchbar` | path /api/purchases/voucher-searchbar -> /api/v1/purchases/voucher-searchbar; query params added: store_id | 404 |
| Purchase | Add Purchase Order | POST | `/api/v1/purchase/add-purchase-order` | body keys aligned with app (9 keys) | not run (route exists: GET probe 405) |
| Purchase | Receive Purchase | POST | `/api/v1/purchase/receive-purchase-order/:purchaseId` | body keys aligned with app (5 keys) | not run (route exists: GET probe 405) |
| Purchase | List Purchase Order | GET | `/api/v1/purchase/list-purchase-order` | query params added: date_from, date_to, page, store_id | 200 |
| Order | add-to-order | POST | `/api/v1/order/add-to-order` | body keys aligned with app (36 keys) | not run (route exists: GET probe 405) |
| Order | confirm-order | POST | `/api/v1/order/confirm-order` | body formdata -> JSON; body keys aligned with app (14 keys) | not run (route exists: GET probe 405) |
| Order | list-order | GET | `/api/v1/order/executive/list-orders` | query params added: page, store_id | 200 |
| Order | list-delivery-methods | GET | `/api/v1/logistics/list-delivery-methods` | query params added: locale, store_id | 200 |
| Order | order_details | GET | `/api/v1/order/executive/order-details/:order_number` | query params added: store_id | 200 |
| Order | change order status | POST | `/api/v1/order/order-change-status` | path /api/v1/api/v1/order/order-change-status -> /api/v1/order/order-change-status; query params the app does not send removed/replaced: order_id, status; body none -> JSON; body keys aligned with app (6 keys) | not run (route exists: GET probe 405) |
| Order | update order | POST | `/api/v1/order/update-order` | body keys aligned with app (24 keys) | not run (route exists: GET probe 405) |
| Order | track-order | GET | `/api/v1/order/track-order` | The item previously had no URL; set to the backend route GET /api/v1/order/track-order (enkepos/routes/api/OrderRoutes.php:30). | 200 |
| Order | saved-order | GET | `/api/v1/order/list-saved-orders` | query params added: store_id; body removed (the app sends none) | 200 |
| Order | cancel order | POST | `/api/v1/order/cancel-order` | body formdata -> JSON | not run (side effects) |
| Product | Create Product | POST | `/api/v1/product/create-product` | body keys aligned with app (18 keys) | not run (route exists: GET probe 405) |
| Product | Edit Product | POST | `/api/v1/product/edit-product/:id` | body keys aligned with app (17 keys) | not run (route exists: GET probe 405) |
| Product | Edit-Product-General-Item | POST | `/api/v1/product/edit-product-general-item` | path /api/product/edit-product-general-item -> /api/v1/product/edit-product-general-item; body formdata -> JSON | not run (no route: GET probe 404) |
| Product | Add-product-name | POST | `/api/v1/product/add-product-name` | path /api/product/add-product-name -> /api/v1/product/add-product-name; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Product | Edit-product-name | POST | `/api/v1/product/edit-product-name` | path /api/product/edit-product-name -> /api/v1/product/edit-product-name; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Product | Add-product-props | POST | `/api/v1/product/add-product-props` | path /api/product/add-product-props -> /api/v1/product/add-product-props; body formdata -> JSON; body keys aligned with app (5 keys) | not run (no route: GET probe 404) |
| Product | Edit-product-props | POST | `/api/v1/product/edit-product-props` | path /api/product/edit-product-props -> /api/v1/product/edit-product-props; body formdata -> JSON; body keys aligned with app (5 keys) | not run (no route: GET probe 404) |
| Product | Add-product-image | POST | `/api/v1/product/add-product-image` | path /api/product/add-product-image -> /api/v1/product/add-product-image; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Product | translate | POST | `/api/v1/translate` | body formdata -> JSON | 200 |
| Product | list-products | GET | `/api/v1/product/executive/list-products` | query params added: page, store_id, type | 200 |
| Product | languages | GET | `/api/v1/languages` | query params added: store_id | 200 |
| Product | Genarate Barcode | GET | `/api/v1/product/generate-barcode` | query params added: store_id | 200 |
| Transaction | Get Voucher Account Types | GET | `/api/v1/transaction/get-account-types` | path /api/transaction/get-account-types -> /api/v1/transaction/get-account-types; query params added: store_id | 404 |
| Transaction | Get Payment Methods | GET | `/api/v1/master-data-values` | query params added: locale | 200 |
| Transaction | Add Invoice | POST | `/api/v1/transaction/add-transaction` | path /api/transaction/add-transaction -> /api/v1/transaction/add-transaction; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Transaction | Add Voucher | POST | `/api/v1/transaction/add-transaction` | path /api/transaction/add-transaction -> /api/v1/transaction/add-transaction; body formdata -> urlencoded | not run (no route: GET probe 404) |
| Transaction | Add Receipt | POST | `/api/v1/receipt/create-receipt` | body keys aligned with app (5 keys) | not run (route exists: GET probe 405) |
| Transaction | List Transaction (all) | GET | `/api/v1/transaction/list-transactions` | query params added: date_from, date_to, page, store_id | 200 |
| Category | Add-Category | POST | `/api/v1/category/add-category` | body keys aligned with app (12 keys) | not run (route exists: GET probe 405) |
| Category | Edit-category | POST | `/api/v1/category/edit-category/:id` | path /api/category/edit-category/11 -> /api/v1/category/edit-category/:id; body keys aligned with app (8 keys) | not run (route exists: GET probe 405) |
| Category | Fetch prop | GET | `/api/v1/product/fetch-prop-values` | path /api/product/fetch-prop-values -> /api/v1/product/fetch-prop-values; query params added: store_id | 404 |
| Category | search-category | GET | `/api/v1/category/list-category` | query params added: page, store_id, type | 200 |
| Stock | update-stock | POST | `/api/v1/product/update-stock/:id` | body formdata -> JSON | not run (route exists: GET probe 405) |
| Stock | complete-stock | POST | `/api/v1/product/complete-purchase` | body keys aligned with app (3 keys) | not run (route exists: GET probe 405) |
| Cart | add-to-cart | POST | `/api/v1/cart/add-to-cart` | body formdata -> JSON | not run (route exists: GET probe 405) |
| Cart | change-cart-item-price | POST | `/api/v1/cart/change-cart-item-price` | body formdata -> JSON; body keys aligned with app (2 keys) | not run (route exists: GET probe 405) |
| Cart | remove-from-cart | POST | `/api/v1/cart/remove-from-cart` | body formdata -> JSON; body keys aligned with app (1 keys) | not run (route exists: GET probe 405) |
| Cart | list-carts-items | GET | `/api/v1/cart/executive/list-cart-items` | query params added: store_id | 200 |
| Cart | update-cart-status | POST | `/api/v1/cart/update-cart-item-status` | query params added: store_id | not run (route exists: GET probe 405) |
| Cart | cart-item-status | GET | `/api/v1/cart/cart-item-statuses` | query params added: store_id | 200 |
| User | change-password | POST | `/api/v1/customer/change-password` | Passwords moved from the URL into the form body and replaced with {{password}} | not run (side effects) |
| User | Get User List | GET | `/api/v1/user/get-users` | path /api/user/get-users -> /api/v1/user/get-users; query params added: store_id | 404 |
| User | Get User Details | GET | `/api/v1/user/get-user-details/:customerId` | path /api/user/get-user-details/6 -> /api/v1/user/get-user-details/:customerId; query params added: store_id | 200 |
| User | forgot password | POST | `/api/v1/user/forgot` | path /api/user/forgot -> /api/v1/user/forgot; query params the app does not send removed/replaced: email; body formdata -> JSON; body keys aligned with app (1 keys) | not run (side effects) |
| User | reset password | POST | `/api/v1/user/reset` | path /api/user/reset -> /api/v1/user/reset; query params the app does not send removed/replaced: code, password, password_confirmation; body formdata -> JSON; body keys aligned with app (3 keys) | not run (side effects) |
| Customer | Customer-List | GET | `/api/v1/customer/customer-searchbar` | query params added: page, per_page, sort_asc, store_id | 200 |
| Customer | Customer-List-Search | GET | `/api/v1/customer/customer-searchbar` | query params the app does not send removed/replaced: sort_asc; query params added: store_id | 200 |
| Customer | Customer-Transactions | GET | `/api/v1/transaction/customer-transactions` | query params added: customer_id, date_from, date_to, page, per_page, store_id | 200 |
| Customer | Add-Customer | POST | `/api/v1/customer/add-customer` | body formdata -> JSON; body keys aligned with app (15 keys) | 201 |
| Customer | Get Last Purchase | POST | `/api/v1/customer/customer-last-purchases` | query params the app does not send removed/replaced: customer_id, product_id; body formdata -> JSON; body keys aligned with app (2 keys) | 200 |
| Customer | Customer Edit Executive | POST | `/api/v1/customer/customer-edit` | body formdata -> JSON; body keys aligned with app (3 keys) | 200 |
| Customer | Create Customer Voucher | POST | `/api/v1/voucher/vouchers-create` | body keys aligned with app (8 keys) | not run (route exists: GET probe 405) |
| Customer | Create Customer Invoice | POST | `/api/v1/invoice/invoice-create` | body keys aligned with app (11 keys) | not run (route exists: GET probe 405) |
| Customer | Get Customer Vouchers | GET | `/api/v1/voucher/vouchers-list` | query params added: date_from, date_to, page, per_page, store_id; body removed (the app sends none) | 200 |
| Report | Sales Report | GET | `/api/v1/reports/sales-report` | path /api/reports/sales-report -> /api/v1/reports/sales-report; query params added: from_date, store_id, to_date | 404 |
| Report | Account Book | GET | `/api/v1/reports/customer-account-book` | path /api/reports/customer-account-book -> /api/v1/reports/customer-account-book; query params added: from_date, store_id, to_date | 404 |
| Report | Supplier Sales Report | GET | `/api/v1/reports/supplier-sales-report` | path /api/reports/supplier-sales-report -> /api/v1/reports/supplier-sales-report; query params added: from_date, store_id, to_date | 404 |
| Report | Product Sales Report | GET | `/api/v1/product-sales-report` | path /api/reports/product-sales-report -> /api/v1/product-sales-report; query params the app does not send removed/replaced: amount; query params added: category_id, from, page, per_page, to | 200 |
| Report | sales-executive-reports | GET | `/api/v1/sales-executive-report` | query params added: dateFilter, dateFrom, dateTo, store_id | 200 |
| Report | sales-executive-report-admin | GET | `/api/v1/sales-executive-report-admin` | query params added: dateFilter, dateFrom, dateTo, store_id | 403 |
| Report | Non Stock Report | GET | `/api/v1/non-stock-report` | query params added: page, store_id | 200 |
| Daily Sales Close | Create Day Close | POST | `/api/v1/daily-sales-close/create` | query params added: store_id; body none -> JSON; body keys aligned with app (16 keys); moved to folder Daily Sales Close | not run (side effects) |
| Daily Sales Close | Day Close Summary | GET | `/api/v1/daily-sales-close/summary` | query params added: business_date; moved to folder Daily Sales Close | 200 |
| Daily Sales Close | List Day Close | GET | `/api/v1/daily-sales-close/list` | query params the app does not send removed/replaced: date; query params added: end_date, page, start_date; moved to folder Daily Sales Close | 200 |
| Report | Consumed Stocks Report | GET | `/api/v1/consumed-stocks-report` | query params added: from, page, store_id, until | 200 |
| Dashboard | dashboard | GET | `/api/v1/dashboard` | query params added: store_id | 200 |
| Dashboard | Company Overview | GET | `/api/v1/dashboard/company-overview` | query params added: end_date, start_date, store_id | 200 |
| Dashboard | Orders Graph | GET | `/api/v1/dashboard/orders-graph` | query params added: store_id | 200 |
| Dashboard | Customers Graph | GET | `/api/v1/dashboard/customers-graph` | query params added: store_id | 200 |
| Dashboard | Executives Overview | GET | `/api/v1/dashboard/executives-overview` | query params added: store_id | 200 |
| Dashboard | Executive Sales Graph | GET | `/api/v1/dashboard/executive-sales-graph` | query params the app does not send removed/replaced: end_date, start_date | 200 |
| Dashboard | Suppliers Overview | GET | `/api/v1/dashboard/suppliers-overview` | query params added: store_id | 200 |
| Dashboard | Suppliers Purchase Graph | GET | `/api/v1/dashboard/suppliers-purchase-graph` | query params added: store_id | 200 |
| Dashboard | Supplier Transactions Graph | GET | `/api/v1/dashboard/supplier-transactions-graph` | query params added: store_id | 200 |
| Dashboard | Supplier Credit Balance | GET | `/api/v1/dashboard/supplier-credit-balance` | query params added: store_id | 200 |
| Tax | tax calculate | GET | `/api/v1/calculate-tax` | query params added: store_id | 200 |
| Supplier | Get Supplier | GET | `/api/v1/get-suppliers` | query params added: store_id | 200 |
| Supplier | Get Supplier Voucher | GET | `/api/v1/suppliers/list-supplier-voucher` | URL pointed at get-suppliers; the supplier voucher list is GET /api/v1/suppliers/list-supplier-voucher; path /api/v1/get-suppliers -> /api/v1/suppliers/list-supplier-voucher; query params added: page, per_page, store_id | 200 |
| Supplier | Add Supplier | POST | `/api/v1/add-supplier` | body keys aligned with app (10 keys) | 200 |
| Supplier | Update Supplier | POST | `/api/v1/update-suppliers` | body keys aligned with app (9 keys) | 200 |
| Supplier | Supplier Transaction | GET | `/api/v1/suppliers/supplier-transactions` | query params added: date_from, date_to, page, per_page, supplier_id | 200 |
| Supplier | Create Supplier Voucher | POST | `/api/v1/suppliers/create-supplier-voucher` | body keys aligned with app (8 keys) | not run (route exists: GET probe 405) |
| Discount | apply coupon | GET | `/api/v1/discount/apply-coupon` | path /api/discount/apply-coupon -> /api/v1/discount/apply-coupon; query params the app does not send removed/replaced: total_amount; query params added: price, store_id | 500 |
| Discount | list Discounts | GET | `/api/v1/discount/list-discounts` | query params added: store_id | 200 |
| Company Props | List Company Faq | GET | `/api/v1/faq/faqs/company/1` | path /api/faq/faqs/company/1 -> /api/v1/faq/faqs/company/1; query params added: store_id | 404 |
| Company Props | List Company Terms and Privacy | GET | `/api/v1/company/prop-names` | Old path /api/company/company/prop-names returned 404; fixed to /api/v1/company/prop-names. | 200 |
| Data List / Location | Get States | GET | `/api/v1/location/get-states` | path /api/location/get-states -> /api/v1/location/get-states; query params added: store_id | 200 |
| Data List / Location | Get Districts | GET | `/api/v1/location/get-district` | path /api/location/get-district -> /api/v1/location/get-district; query params added: store_id | 200 |
| Data List | List Unit | GET | `/api/v1/product/list-units` | query params added: store_id | 200 |
| Data List | List Bank | GET | `/api/v1/get-banks` | query params added: store_id | 200 |
| Data List | List Document Configs | GET | `/api/v1/document/document-configs` | query params the app does not send removed/replaced: type; query params added: store_id | 200 |
| Data List | List Document Templates | GET | `/api/v1/document/document-configs` | query params added: language, store_id | 200 |
| Data List | Get stores | GET | `/api/v1/stores/get-stores` | query params added: store_id | 200 |
| Data List | Get Racks | GET | `/api/v1/master-data-values` | code=RACKS; path /api/v1/get-stores -> /api/v1/master-data-values; query params added: code, locale, store_id | 200 |
| Data List | Get supplier | GET | `/api/v1/get-suppliers` | query params added: store_id | 200 |
| Data List | list file | GET | `/api/v1/file/list-files` | path /api/file/list-files -> /api/v1/file/list-files; query params added: store_id | 404 |
| Data List | Get Invoice Account Types | GET | `/api/v1/transaction/get-account-types` | path /api/transaction/get-account-types -> /api/v1/transaction/get-account-types; query params added: store_id | 404 |
| Data List | master data | GET | `/api/v1/master-data-values` | code=STOCK_GROUPING_FIELDS; path /api/v1/master-data-values/ -> /api/v1/master-data-values; query params added: locale | 200 |
| Data List | Dining Area | GET | `/api/v1/master-data-values` | code was PAYMENT_METHOD; the app's dining tables come from code=TABLE_LIST; path /api/v1/master-data-values/ -> /api/v1/master-data-values; query params added: locale | 200 |
| Data List | Sales Users List | GET | `/api/v1/list-sales-executives` | query params added: store_id | 200 |
| Transactions | list-transactions | GET | `/api/v1/transaction/list-transactions` | query params added: date_from, date_to, page, store_id | 200 |
| Transactions | Transaction Details | GET | `/api/v1/transaction/transaction-details/:id` | query params added: store_id | 200 |
| Transactions | List Receipts | GET | `/api/v1/receipt/list-receipts` | query params added: date_from, date_to, page, per_page, store_id | 200 |
| Transactions | Receipt details | GET | `/api/v1/receipt/receipt-details/:id` | query params added: store_id | 200 |
| Transactions | Invoice details | GET | `/api/v1/invoice/invoice-details/:id` | query params added: store_id | 200 |
| Transactions | list-invoices | GET | `/api/v1/invoice/list-invoices` | query params added: order_number, page, per_page, store_id | 200 |
| Transactions | supplier-transactions | GET | `/api/v1/suppliers/list-transactions` | query params added: list_all, page, store_id | 200 |
| Transactions | list-company-accounts | GET | `/api/v1/accounts/company-accounts` | query params added: page, per_page, sort_asc, store_id | 200 |
| Payment Copy | list payment gateways | GET | `/api/v1/payment-gateway/list-payment-gateways` | query params added: store_id | 200 |
| Zatca | Phase-1 Print | POST | `/api/v1/zatca/phase1/invoice/print` | query params the app does not send removed/replaced: id; body none -> urlencoded; body keys aligned with app (1 keys) | not run (side effects) |
| Zatca | Invoice Send to Zatca | POST | `/api/v1/zatca/phase2/invoice/print` | query params the app does not send removed/replaced: id, type; body none -> urlencoded; body keys aligned with app (1 keys) | not run (side effects) |
| Zatca | Credit Note Send & Print | POST | `/api/v1/zatca/phase2/voucher/print` | query params the app does not send removed/replaced: id; body none -> urlencoded; body keys aligned with app (1 keys) | not run (side effects) |
| Zatca | resync voucher | POST | `/api/v1/zatca/phase2/voucher/resync` | query params the app does not send removed/replaced: id; body none -> urlencoded; body keys aligned with app (1 keys) | not run (side effects) |
| Zatca | resync invoice | POST | `/api/v1/zatca/phase2/invoice/resync` | query params the app does not send removed/replaced: id; body none -> urlencoded; body keys aligned with app (1 keys) | not run (side effects) |
| Roles | Role list | GET | `/api/v1/roles/list` | query params added: store_id | 200 |
| Sales Return | Create Sales Return | POST | `/api/v1/order/sales-return` | body formdata -> JSON; body keys aligned with app (6 keys) | not run (route exists: GET probe 405) |
| Sales Return | Sales Return items | GET | `/api/v1/order/list-return-order-items` | query params added: page, store_id | 200 |
| Sales Return | List Sales Return | GET | `/api/v1/order/list-return-orders` | query params the app does not send removed/replaced: customer_id; query params added: page, store_id | 200 |
| Quotation | list Quotation | GET | `/api/v1/quotations` | query params added: page, store_id | 200 |
| Quotation | Quotation Create | POST | `/api/v1/quotations` | body keys aligned with app (11 keys) | not run (GET probe 200, inconclusive) |
| Root | signin | POST | `/api/v1/user/signin` | body formdata -> JSON | not run (side effects) |
| Root | Get Website Settings | GET | `/api/v1/website-settings` | query params added: store_id | 200 |
| Root | Get General Settings | GET | `/api/v1/general` | query params added: store_id | 200 |

## Moved to Legacy (not used by the app) (40)

| Folder | Request | Method | Path | Change | Verified |
|---|---|---|---|---|---|
| Purchase / Old | Finish purchase order | POST | `/api/purchases/add-purchase-order` | POST /api/purchases/add-purchase-order: no such route (GET probe on /api/v1/purchases/add-purchase-order returns 404; the /api/ path without v1 is not an API route). The app creates purchase orders with POST /api/v1/purchase/add-purchase-order. | not run (side effects) |
| Purchase / Old | List purchase order Search | GET | `/api/purchases/purchase-searchbar` | GET /api/purchases/purchase-searchbar returns 401 without /v1 and 404 with /api/v1. Not used by the app. | 401 |
| Purchase / Old | List Voucher | GET | `/api/purchases/list-purchase-voucher` | GET /api/purchases/list-purchase-voucher returns 401 without /v1 and 404 with /api/v1. Not used by the app. | 401 |
| Purchase / Old | Add Stock | POST | `/api/v1/product/add-stock` | Duplicate of Stock / add-stock (same POST /api/v1/product/add-stock). | not run (side effects) |
| Order | merge-items | GET | `/api/v1/order/executive/list-orders` | Duplicate of Order / list-order (same GET /api/v1/order/executive/list-orders, no merge-specific params). | 200 |
| Order | list-order-search | GET | `/api/order-searchbar` | GET /api/order-searchbar returns 404 (also 404 as /api/v1/order-searchbar). APPUrl.searchListOrder still defines it but nothing calls it; the app filters with list-orders query params. | 404 |
| Order | update order status | POST | `/api/v1/order/update-order-items-status` | Duplicate of Order / update order items status (same POST /api/v1/order/update-order-items-status). | not run (side effects) |
| Order | change order status Copy 2 | POST | `/api/v1/api/v1/order/order-change-status` | Duplicate (Copy 2) of Order / change order status; its URL had a doubled /api/v1/api/v1/ prefix. | not run (side effects) |
| Product | Edit-product-image | POST | `/api/product/edit-product-image` | POST /api/v1/product/edit-product-image does not exist on the backend (GET probe 404) and APPUrl.editProductImageUrl has no live caller. | not run (side effects) |
| Product | change-product-status | POST | `/api/product/change-product-status` | POST /api/product/change-product-status: no route with or without /v1 (GET probe 404 for both). Not used by the app. | not run (side effects) |
| Product | search-product | GET | `/api/product-searchbar` | GET /api/product-searchbar returns 404 (also with /api/v1). Not used by the app; product search uses list-products query params. | 404 |
| Product | list-products Copy | GET | `/api/v1/product/executive/list-products` | Duplicate (Copy) of Product / list-products. | 200 |
| Transaction | List Transaction (Invoice) | GET | `/api/transaction/list-transaction` | GET /api/transaction/list-transaction returns 404 (also with /api/v1). The app uses GET /api/v1/transaction/list-transactions (Transactions / list-transactions). | 404 |
| Transaction | List Transaction (Voucher) | GET | `/api/transaction/list-transaction` | GET /api/transaction/list-transaction returns 404 (also with /api/v1). The app uses GET /api/v1/transaction/list-transactions. | 404 |
| Transaction | Transaction Details | GET | `/api/transaction/transaction-details` | GET /api/transaction/transaction-details?id= returns 404. The app uses GET /api/v1/transaction/transaction-details/{id} (Transactions / Transaction Details). | 404 |
| Stock | List stock search | GET | `/api/stock-searchbar` | GET /api/stock-searchbar returns 404 (also with /api/v1). Not used by the app. | 404 |
| Stock | Stock Details | GET | `/api/product/stock-details` | GET /api/v1/product/stock-details returns 404, and APPUrl.detailsOfStock (stock_provider.callStockDetails) has no live caller. | 404 |
| Stock | Stock info | GET | `/api/product/stock-info` | GET /api/product/stock-info returns 404 (also with /api/v1). Not used by the app. | 404 |
| User | master-data | GET | `/api/v1/master-data/PRODUCT_UNITS` | GET /api/v1/master-data/PRODUCT_UNITS returns 500 (backend: Call to undefined method UserController::getMasterDataByCode()). Not used by the app; units come from GET /api/v1/product/list-units. | 500 |
| Customer | Customer-balance | GET | `/api/v1/customer/customer-searchbar` | Duplicate of Customer / Customer-List (same GET customer-searchbar?sort_asc=true). | 200 |
| Tax | Get Category Tax | GET | `/api/tax/get-category-tax` | GET /api/v1/tax/get-category-tax returns 404 and APPUrl.getTaxtDetails (models/tax.dart getCategoryTax) has no live caller; the app uses GET /api/v1/calculate-tax. | 404 |
| Tax | tax calculate Copy | GET | `/api/v1/calculate-tax` | Duplicate (Copy) of Tax / tax calculate. | 200 |
| Company Props | List Company Props | GET | `/api/company/get-company-props` | GET /api/company/get-company-props returns 404 (also with /api/v1). Not used by the app; company props reach the app through GET /api/v1/website-settings. | 404 |
| Delhivery Api | Pincode Servicebility | GET | `/api/company/get-company-props` | URL was a copy of List Company Props (GET /api/company/get-company-props, 404). Not used by the app. | 404 |
| Zatca | compliance | GET | `/api/v1/zatca/compliance` | The item had no URL. There is no ZATCA compliance route in the API (enkepos/routes/api/ZatcaRoutes.php has only print/resync/bulk-send; compliance runs in the admin onboarding). URL set to /api/v1/zatca/compliance for reference only. Not executed (zatca/ calls are never made during verification). | not run (side effects) |
| Root | Change Password | POST | `/api/v1/user/signin` | Mislabelled: this item POSTs to /api/v1/user/signin (it is a sign-in, not a password change). The POS app has no change-password call. Not executed (sign-in is never called during verification). | not run (side effects) |
| Dashboard Copy | dashboard | GET | `/api/v1/dashboard` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Dashboard Graph | GET | `/api/dashboard/orders` | Duplicate (Dashboard Copy folder); GET /api/dashboard/orders returns 404 | 404 |
| Dashboard Copy | Company Overview | GET | `/api/v1/dashboard/company-overview` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Orders Graph | GET | `/api/v1/dashboard/orders-graph` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Customers Graph | GET | `/api/v1/dashboard/customers-graph` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Executives Overview | GET | `/api/v1/dashboard/executives-overview` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Executive Sales Graph | GET | `/api/v1/dashboard/executive-sales-graph` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Suppliers Overview | GET | `/api/v1/dashboard/suppliers-overview` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Suppliers Purchase Graph | GET | `/api/v1/dashboard/suppliers-purchase-graph` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Supplier Transactions Graph | GET | `/api/v1/dashboard/supplier-transactions-graph` | Duplicate (Dashboard Copy folder) | 200 |
| Dashboard Copy | Supplier Credit Balance | GET | `/api/v1/dashboard/supplier-credit-balance` | Duplicate (Dashboard Copy folder) | 200 |
| (new) | Add to purchase (unused) | POST | `/api/v1/purchases/add-to-purchase` | APPUrl.addToPurchase is defined but never called; /api/v1/purchases/add-to-purchase returns 404 (GET probe). | not run (no route: GET probe 404) |
| (new) | Search user by key (unused) | GET | `/api/v1/search-user-by-key` | APPUrl.findCustomerByPhone is defined but never called; GET /api/v1/search-user-by-key returns 404. | 404 |
| (new) | Verify API key (unused) | GET | `/api/v1/verify-api-key` | APPUrl.verifyApiKey is defined but never called; GET /api/v1/verify-api-key returns 404. | 404 |

## Unchanged requests (headers, description and example only) (24)

| Folder | Request | Method | Path | Change | Verified |
|---|---|---|---|---|---|
| Order | add-payment | POST | `/api/v1/order/add-payment` | kept (not used by the app) | not run (side effects) |
| Order | update order items status | POST | `/api/v1/order/update-order-items-status` | headers/description only | not run (route exists: GET probe 405) |
| Product | Offer Products | GET | `/api/v1/product/offer-products` | kept (not used by the app) | 200 |
| Product | product properties | GET | `/api/v1/product/list-product-properties` | headers/description only | 200 |
| Stock | add-stock | POST | `/api/v1/product/add-stock` | headers/description only | not run (route exists: GET probe 405) |
| Stock | List stock | GET | `/api/v1/product/list-stocks` | headers/description only | 200 |
| Cart | add-to-cart Bulk | POST | `/api/v1/cart/add-to-cart` | kept (not used by the app) | not run (side effects) |
| User | Search user by phone | GET | `/api/v1/user/users` | kept (not used by the app) | 200 |
| Customer | Customer-Listing new | GET | `/api/v1/customer/customer-list` | kept (not used by the app) | 200 |
| Customer | update-profile | GET | `/api/v1/customer/profile` | kept (not used by the app) | 500 |
| Customer | Update Address | POST | `/api/v1/customer/executive-update-address/:id` | headers/description only | 200 |
| Daily Sales Close | List Day Close details | GET | `/api/v1/daily-sales-close/view/:id` | moved to folder Daily Sales Close | 200 |
| Delhivery Api | Waybill | GET | `/api/v1/logistics/fetch-waybill` | kept (not used by the app) | not run (side effects) |
| Delhivery Api | Shipment Creation | GET | `/api/v1/logistics/create-order` | kept (not used by the app) | not run (side effects) |
| Data List | List Properties | GET | `/api/v1/product/list-product-properties` | headers/description only | 200 |
| Data List | Get Printer Settings | GET | `/api/v1/document/printer-settings` | headers/description only | 200 |
| Payment Copy | Create Order payment | POST | `/api/v1/payment-gateway/create-order` | kept (not used by the app) | not run (side effects) |
| Payment Copy | verify | POST | `/api/v1/payment-gateway/verify-payment` | kept (not used by the app) | not run (side effects) |
| logistics | delivery-charge | GET | `/api/v1/logistics/delivery-charge` | kept (not used by the app) | 500 |
| Sales Return | Complete Sales Return | POST | `/api/v1/order/complete-return-order` | headers/description only | not run (route exists: GET probe 405) |
| Quotation | Quotation update status | POST | `/api/v1/quotations/update-status` | headers/description only | not run (GET probe 500, inconclusive) |
| Quotation | Quotation details | GET | `/api/v1/quotations/:id` | headers/description only | 200 |
| Root | signout | POST | `/api/v1/user/signout` | headers/description only | not run (side effects) |
| Root | Get Admin Settings | GET | `/api/v1/admin-settings` | headers/description only | 200 |

Spec ids (A0, B12, …) refer to the extraction notes in the session scratchpad. Each request's description carries the same information: app screen, call site, required params and notes.
