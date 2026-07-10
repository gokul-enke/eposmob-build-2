# Day Close / Open Shift API Reference

Source of truth for the current implementation in:

- [routes/api/ReportsRoutes.php](/home/enke/enkepos/routes/api/ReportsRoutes.php:12)
- [app/Http/Controllers/Api/V1/DailySalesCloseController.php](/home/enke/enkepos/app/Http/Controllers/Api/V1/DailySalesCloseController.php:30)
- [app/Models/DailySalesClose.php](/home/enke/enkepos/app/Models/DailySalesClose.php:15)

Base URL in local env: `http://127.0.0.1:8000`

All endpoints are under Sanctum auth middleware. Even though some clients may still send `access_token`, the current Laravel route definition is authenticated with `auth:sanctum`.

## Important route note

The currently registered close/submit endpoint is:

- `POST /api/v1/daily-sales-close/create`

There is **no** `POST /api/v1/daily-sales-close/close` route registered right now. If the app is calling `/close`, that does not match the current backend route table.

---

## Common transformed Day Close object

This is the response shape returned by:

- `POST /api/v1/daily-sales-close/open`
- `POST /api/v1/daily-sales-close/create`
- `GET /api/v1/daily-sales-close/list`
- `GET /api/v1/daily-sales-close/pending-status` inside `open_draft`

### Fields

| Field | Type | Nullable | Always present | Notes |
|---|---|---:|---:|---|
| `id` | integer | No | Yes | DB primary key |
| `sales_executive` | object | No | Yes | Child fields may be null if relation missing |
| `sales_executive.id` | integer | Yes | Yes | |
| `sales_executive.name` | string | Yes | Yes | |
| `sales_executive.phone` | string | Yes | Yes | |
| `store` | object | No | Yes | Child fields may be null if relation missing |
| `store.id` | integer | Yes | Yes | |
| `store.name` | string | Yes | Yes | |
| `closing_period` | string | No | Yes | Format from accessor, e.g. `08-07-2026 to 09-07-2026` or `08-07-2026 to Draft` |
| `status` | string | No | Yes | `draft` or `closed` |
| `opening_date` | string (`YYYY-MM-DD`) | Yes | Yes | |
| `opening_time` | string (`HH:MM:SS`) | Yes | Yes | |
| `closing_date` | string (`YYYY-MM-DD`) | Yes | Yes | Null for draft |
| `closing_time` | string (`HH:MM:SS`) | Yes | Yes | Null for draft |
| `opening_transaction_id` | integer | Yes | Yes | |
| `closing_transaction_id` | integer | Yes | Yes | |
| `total_orders` | integer | No | Yes | Computed from transactions between opening and closing IDs |
| `total_sales` | string decimal | No | Yes | Always formatted with 2 decimals |
| `total_online` | string decimal | No | Yes | |
| `total_cash` | string decimal | No | Yes | |
| `total_credit` | string decimal | No | Yes | |
| `total_payment_received` | string decimal | No | Yes | |
| `total_amount_collected_on_sale` | string decimal | No | Yes | |
| `total_credit_collected` | string decimal | No | Yes | |
| `total_returns` | string decimal | No | Yes | |
| `total_refunds` | string decimal | No | Yes | |
| `shift_name` | string | Yes | Yes | Defaults to `Swift` if omitted on open/close |
| `business_date` | string (`YYYY-MM-DD`) | Yes | Yes | |
| `cash_summary` | object | No | Yes | See below |
| `created_at` | string datetime | No | Yes | `Y-m-d H:i:s` |
| `updated_at` | string datetime | Yes | Yes | |

### `cash_summary` fields

| Field | Type | Nullable | Always present | Notes |
|---|---|---:|---:|---|
| `total_sales_count` | integer | No | Yes | Uses stored `total_sales_count`; falls back to computed `total_orders` |
| `total_sales_amount` | string decimal | No | Yes | Falls back to computed `total_sales` |
| `cash_collected` | string decimal | No | Yes | Falls back to computed `total_cash` |
| `online_collected` | string decimal | No | Yes | Falls back to computed `total_online` |
| `credit_amount` | string decimal | No | Yes | Falls back to computed `total_credit` |
| `previous_balance_collected` | string decimal | No | Yes | Falls back to computed `total_credit_collected` |
| `cash_refunds` | string decimal | No | Yes | Falls back to computed `total_refunds` |
| `cash_expenses` | string decimal | No | Yes | Returns `"0.00"` when DB value is null |
| `cash_drop_amount` | string decimal | No | Yes | Returns `"0.00"` when DB value is null |
| `opening_cash_in_hand` | string decimal | Yes | Yes | Null when not captured |
| `opening_cash_breakdown` | array of objects | Yes | Yes | Null or `[]` or list depending on stored JSON |
| `expected_closing_cash` | string decimal | Yes | Yes | Computed if opening cash exists |
| `closing_cash_in_hand` | string decimal | Yes | Yes | |
| `closing_cash_breakdown` | array of objects | Yes | Yes | Null or `[]` or list |
| `short_cash` | string decimal | Yes | Yes | Null unless closing cash was evaluated |
| `excess_cash` | string decimal | Yes | Yes | Null unless closing cash was evaluated |
| `notes` | string | Yes | Yes | |

### Cash breakdown row shape

| Field | Type | Nullable | Always present |
|---|---|---:|---:|
| `denomination` | string | No | Yes |
| `count` | number | No | Yes |

Business rules:

- Request-side cash breakdown can be sent either as:
  - associative object like `{ "200": 2, "50": 4 }`
  - array of rows like `[{"denomination":"200","count":2}]`
- Backend normalizes both forms into an array of rows.
- Blank denomination/count rows are dropped during normalization.
- Validation then requires each remaining row to have:
  - `denomination` in master data `CASH_DENOMINATIONS`
  - `count` numeric and `>= 0`

---

## 1. GET `/api/v1/daily-sales-close/pending-status`

Full URL:

- `GET http://127.0.0.1:8000/api/v1/daily-sales-close/pending-status`

### Parameters

| Name | Type | Required | Notes |
|---|---|---:|---|
| `access_token` | string | Client-specific | Not used by controller directly; auth is via Sanctum middleware |
| `store_id` | integer | Yes | Must belong to authenticated user's company |
| `user_id` | integer | No in current backend | Ignored by this controller; backend always uses `auth()->user()->id` |

### Response behavior

There are 3 practical branches:

1. No opening transaction found after the last closed day
- Response contains `pending_day_close`, `can_open_shift`, `open_draft`, `message`

2. Opening transaction exists and its business date is today or later
- Response contains `pending_day_close`, `can_open_shift`, `open_draft`, `business_date`, `opening_transaction_id`, `message`

3. Opening transaction exists and its business date is before today
- Response forces `pending_day_close: true`, `can_open_shift: false`, `requires_confirmation: true`
- Response includes opening/closing tx IDs plus opening/closing date/time from transactions

### When `open_draft` is null vs populated

- `open_draft` is populated only when there is an existing `daily_sales_closes` row for the authenticated user + store with `status = draft`
- `open_draft` is `null` when no such draft exists

### When `opening_time` / `closing_time` are present vs absent

- In branch 1: neither field is returned at top level
- In branch 2: neither `opening_time` nor `closing_time` is returned at top level
- In branch 3:
  - `opening_time` is always returned from the first pending transaction's `created_at`
  - `closing_time` is returned from the last transaction on that same business date
  - `closing_time` can still be `null` if no closing transaction is found for that business date
- Inside `open_draft`, `opening_time` comes from the stored draft row and `closing_time` is typically `null` for drafts

### Sample success response with populated `open_draft`

This sample uses a real draft row from local data (`daily_sales_closes.id = 210`). The wrapper shape is controller-confirmed; the `open_draft` payload is real transformed data.

```json
{
  "success": true,
  "data": {
    "pending_day_close": true,
    "can_open_shift": false,
    "open_draft": {
      "id": 210,
      "sales_executive": {
        "id": 1,
        "name": "Super Admin",
        "phone": "9496419999"
      },
      "store": {
        "id": 2,
        "name": "FUNZCART Store"
      },
      "closing_period": "08-07-2026 to Draft",
      "status": "draft",
      "opening_date": "2026-07-08",
      "opening_time": "08:00:00",
      "closing_date": null,
      "closing_time": null,
      "opening_transaction_id": null,
      "closing_transaction_id": null,
      "total_orders": 0,
      "total_sales": "0.00",
      "total_online": "0.00",
      "total_cash": "0.00",
      "total_credit": "0.00",
      "total_payment_received": "0.00",
      "total_amount_collected_on_sale": "0.00",
      "total_credit_collected": "0.00",
      "total_returns": "0.00",
      "total_refunds": "0.00",
      "shift_name": "Swift",
      "business_date": "2026-07-08",
      "cash_summary": {
        "total_sales_count": 0,
        "total_sales_amount": "0.00",
        "cash_collected": "0.00",
        "online_collected": "0.00",
        "credit_amount": "0.00",
        "previous_balance_collected": "0.00",
        "cash_refunds": "0.00",
        "cash_expenses": "0.00",
        "cash_drop_amount": "0.00",
        "opening_cash_in_hand": "1000.00",
        "opening_cash_breakdown": [
          {
            "count": "2",
            "denomination": "200"
          },
          {
            "count": "4",
            "denomination": "50"
          },
          {
            "count": "10",
            "denomination": "20"
          },
          {
            "count": "20",
            "denomination": "10"
          }
        ],
        "expected_closing_cash": "1000.00",
        "closing_cash_in_hand": null,
        "closing_cash_breakdown": null,
        "short_cash": null,
        "excess_cash": null,
        "notes": null
      },
      "created_at": "2026-07-08 10:00:07",
      "updated_at": "2026-07-08 10:00:07"
    },
    "message": null
  }
}
```

### Top-level response fields

| Field | Type | Nullable | Always present |
|---|---|---:|---:|
| `success` | boolean | No | Yes |
| `data` | object | No | Yes |
| `data.pending_day_close` | boolean | No | Sometimes |
| `data.can_open_shift` | boolean | No | Sometimes |
| `data.open_draft` | object | Yes | Sometimes |
| `data.business_date` | string (`YYYY-MM-DD`) | Yes | Sometimes |
| `data.opening_transaction_id` | integer | Yes | Sometimes |
| `data.closing_transaction_id` | integer | Yes | Sometimes |
| `data.requires_confirmation` | boolean | Yes | Sometimes |
| `data.opening_date` | string (`YYYY-MM-DD`) | Yes | Sometimes |
| `data.opening_time` | string (`HH:MM:SS`) | Yes | Sometimes |
| `data.closing_date` | string (`YYYY-MM-DD`) | Yes | Sometimes |
| `data.closing_time` | string (`HH:MM:SS`) | Yes | Sometimes |
| `data.confirmation_message` | string | Yes | Sometimes |
| `data.message` | string | Yes | Sometimes |

---

## 2. GET `/api/v1/daily-sales-close/summary`

Full URL:

- `GET http://127.0.0.1:8000/api/v1/daily-sales-close/summary`

### Parameters

| Name | Type | Required | Notes |
|---|---|---:|---|
| `access_token` | string | Client-specific | Not used directly in controller |
| `store_id` | integer | Yes | Required |
| `user_id` | integer | No in current backend | Ignored; backend uses authenticated user |
| `transaction_id` | integer | No | Not accepted by current controller |
| `business_date` | string (`YYYY-MM-DD`) | No | Optional filter |

### Important behavior

- The current controller does **not** accept `transaction_id`
- The summary window is built from:
  - last closed day close for the authenticated user + store
  - then transactions after that close
  - optionally filtered by `business_date`
- If no transactions are found, response is exactly:

```json
{
  "success": true,
  "data": []
}
```

This empty response was confirmed live from local data for user `87`, store `60`.

### When `opening_time` is present vs null/empty

- `opening_time` is present only when at least one qualifying transaction exists
- It is taken from the first transaction in the summary window: `openingTx->created_at->format('H:i:s')`
- When there are no transactions, the whole `data` payload is an empty array, so `opening_time` is not present at all

### Response fields when summary exists

| Field | Type | Nullable | Always present when `data` is an object |
|---|---|---:|---:|
| `user_name` | string | No | Yes |
| `opening_date` | string (`YYYY-MM-DD`) | No | Yes |
| `opening_time` | string (`HH:MM:SS`) | No | Yes |
| `closing_date` | string (`YYYY-MM-DD`) | No | Yes |
| `closing_time` | string (`HH:MM:SS`) | No | Yes |
| `opening_transaction_id` | integer | No | Yes |
| `closing_transaction_id` | integer | No | Yes |
| `total_orders` | integer | No | Yes |
| `total_sales` | string decimal | No | Yes |
| `collected_on_sales` | string decimal | No | Yes |
| `payment_received` | string decimal | No | Yes |
| `cash_sales` | string decimal | No | Yes |
| `online_sales` | string decimal | No | Yes |
| `credit_amount` | string decimal | No | Yes |
| `credit_collected` | string decimal | No | Yes |
| `total_returns` | string decimal | No | Yes |
| `total_refunds` | string decimal | No | Yes |
| `business_date` | string (`YYYY-MM-DD`) | No | Yes |

### Sample success response with no open session

```json
{
  "success": true,
  "data": []
}
```

---

## 3. POST `/api/v1/daily-sales-close/open` (Open Shift)

Full URL:

- `POST http://127.0.0.1:8000/api/v1/daily-sales-close/open`

### Request body

| Field | Type | Required | Notes |
|---|---|---:|---|
| `user_id` | integer | No | Defaults to authenticated user |
| `store_id` | integer | Yes | Must belong to authenticated company |
| `shift_name` | string | No | Defaults to `Swift` |
| `business_date` | string (`YYYY-MM-DD`) | No | Defaults to `opening_date` |
| `opening_date` | string (`YYYY-MM-DD`) | No | Defaults to today |
| `opening_time` | string (`HH:MM:SS`) | No | Defaults to store open time or `07:00:00` |
| `opening_cash_in_hand` | number | No | `>= 0` |
| `opening_cash_breakdown` | array or object | No | Normalized to array of denomination/count rows |
| `notes` | string | No | |

### Business rules

- If a draft already exists for the same authenticated user + store, API returns `409`
- `opening_time` fallback order:
  1. request `opening_time`
  2. `store.store_open_time`
  3. hard default `07:00:00`
- `closing_date` and `closing_time` are null in a new draft
- `status` is always `draft`

### Sample success response

Real sample based on local row `id = 210`:

```json
{
  "success": true,
  "message": "Day close draft opened successfully",
  "data": {
    "id": 210,
    "sales_executive": {
      "id": 1,
      "name": "Super Admin",
      "phone": "9496419999"
    },
    "store": {
      "id": 2,
      "name": "FUNZCART Store"
    },
    "closing_period": "08-07-2026 to Draft",
    "status": "draft",
    "opening_date": "2026-07-08",
    "opening_time": "08:00:00",
    "closing_date": null,
    "closing_time": null,
    "opening_transaction_id": null,
    "closing_transaction_id": null,
    "total_orders": 0,
    "total_sales": "0.00",
    "total_online": "0.00",
    "total_cash": "0.00",
    "total_credit": "0.00",
    "total_payment_received": "0.00",
    "total_amount_collected_on_sale": "0.00",
    "total_credit_collected": "0.00",
    "total_returns": "0.00",
    "total_refunds": "0.00",
    "shift_name": "Swift",
    "business_date": "2026-07-08",
    "cash_summary": {
      "total_sales_count": 0,
      "total_sales_amount": "0.00",
      "cash_collected": "0.00",
      "online_collected": "0.00",
      "credit_amount": "0.00",
      "previous_balance_collected": "0.00",
      "cash_refunds": "0.00",
      "cash_expenses": "0.00",
      "cash_drop_amount": "0.00",
      "opening_cash_in_hand": "1000.00",
      "opening_cash_breakdown": [
        {
          "count": "2",
          "denomination": "200"
        },
        {
          "count": "4",
          "denomination": "50"
        },
        {
          "count": "10",
          "denomination": "20"
        },
        {
          "count": "20",
          "denomination": "10"
        }
      ],
      "expected_closing_cash": "1000.00",
      "closing_cash_in_hand": null,
      "closing_cash_breakdown": null,
      "short_cash": null,
      "excess_cash": null,
      "notes": null
    },
    "created_at": "2026-07-08 10:00:07",
    "updated_at": "2026-07-08 10:00:07"
  }
}
```

---

## 4. POST `/api/v1/daily-sales-close/create` (Close Day / Submit)

Current registered full URL:

- `POST http://127.0.0.1:8000/api/v1/daily-sales-close/create`

Requested by product/FE as:

- `POST http://127.0.0.1:8000/api/v1/daily-sales-close/close`

Current backend route is `/create`, not `/close`.

### Request body

| Field | Type | Required | Notes |
|---|---|---:|---|
| `user_id` | integer | No | Defaults to authenticated user |
| `store_id` | integer | Yes | |
| `shift_name` | string | No | Defaults to draft shift name or `Swift` |
| `business_date` | string (`YYYY-MM-DD`) | No | Used to filter transaction window if provided |
| `opening_date` | string (`YYYY-MM-DD`) | No | Fallbacks described below |
| `opening_time` | string (`HH:MM:SS`) | No | Fallbacks described below |
| `closing_date` | string (`YYYY-MM-DD`) | No | Defaults from closing transaction date |
| `closing_time` | string (`HH:MM:SS`) | No | Defaults from closing transaction time |
| `opening_transaction_id` | integer | No | Auto-detected if omitted |
| `closing_transaction_id` | integer | No | Auto-detected if omitted |
| `total_sales_count` | integer | No | `>= 0` |
| `total_sales_amount` | number | No | `>= 0` |
| `cash_collected` | number | No | `>= 0` |
| `online_collected` | number | No | `>= 0` |
| `credit_amount` | number | No | `>= 0` |
| `previous_balance_collected` | number | No | `>= 0` |
| `cash_refunds` | number | No | `>= 0` |
| `cash_expenses` | number | No | `>= 0` |
| `cash_drop_amount` | number | No | `>= 0` |
| `opening_cash_in_hand` | number | No | `>= 0`; falls back to draft value if omitted |
| `opening_cash_breakdown` | array or object | No | Falls back to draft value if omitted |
| `closing_cash_in_hand` | number | No | `>= 0` |
| `closing_cash_breakdown` | array or object | No | |
| `notes` | string | No | Falls back to draft value if omitted |

### What happens if `opening_time` is missing

- It is **not required**
- Fallback order is:
  1. request `opening_time`
  2. existing open draft `opening_time`
  3. store open time
  4. default `07:00:00`

So the request will still succeed if `opening_time` is missing, assuming the rest of the close flow is valid.

### Transaction auto-detection rules

If transaction IDs are not provided:

- `opening_transaction_id`
  - first qualifying transaction after the last closed day close
  - additionally filtered by `business_date` if provided
- `closing_transaction_id`
  - last qualifying transaction
  - additionally filtered by `business_date` if provided

If either transaction cannot be determined, backend returns:

```json
{
  "success": false,
  "message": "No transactions found to close."
}
```

### Cash math rules

If `opening_cash_in_hand` exists:

`expected_closing_cash = opening_cash_in_hand + cash_collected + previous_balance_collected - cash_refunds - cash_expenses - cash_drop_amount`

If `closing_cash_in_hand` also exists:

- `short_cash = expected_closing_cash - closing_cash_in_hand` when actual is short
- `excess_cash = closing_cash_in_hand - expected_closing_cash` when actual is over

### Sample success response

Real sample based on local closed row `id = 207`:

```json
{
  "success": true,
  "message": "Day close created successfully",
  "data": {
    "id": 207,
    "sales_executive": {
      "id": 1,
      "name": "Super Admin",
      "phone": "9496419999"
    },
    "store": {
      "id": 60,
      "name": "Testing Store"
    },
    "closing_period": "08-07-2026 to 08-07-2026",
    "status": "closed",
    "opening_date": "2026-07-08",
    "opening_time": "08:00:00",
    "closing_date": "2026-07-08",
    "closing_time": "08:21:00",
    "opening_transaction_id": 9829,
    "closing_transaction_id": 9830,
    "total_orders": 1,
    "total_sales": "80.00",
    "total_online": "0.00",
    "total_cash": "80.00",
    "total_credit": "0.00",
    "total_payment_received": "80.00",
    "total_amount_collected_on_sale": "80.00",
    "total_credit_collected": "0.00",
    "total_returns": "0.00",
    "total_refunds": "0.00",
    "shift_name": "Swift",
    "business_date": "2026-07-08",
    "cash_summary": {
      "total_sales_count": 1,
      "total_sales_amount": "80.00",
      "cash_collected": "80.00",
      "online_collected": "0.00",
      "credit_amount": "0.00",
      "previous_balance_collected": "0.00",
      "cash_refunds": "0.00",
      "cash_expenses": "0.00",
      "cash_drop_amount": "0.00",
      "opening_cash_in_hand": "20.00",
      "opening_cash_breakdown": [],
      "expected_closing_cash": "100.00",
      "closing_cash_in_hand": "100.00",
      "closing_cash_breakdown": [],
      "short_cash": "0.00",
      "excess_cash": "0.00",
      "notes": null
    },
    "created_at": "2026-07-08 08:22:22",
    "updated_at": "2026-07-08 08:22:22"
  }
}
```

### Closed-from-draft response message

If a draft exists and the close request updates that draft, the success message becomes:

- `Day close draft closed successfully`

---

## 5. GET `/api/v1/daily-sales-close/list`

Full URL:

- `GET http://127.0.0.1:8000/api/v1/daily-sales-close/list`

### Parameters

| Name | Type | Required | Notes |
|---|---|---:|---|
| `access_token` | string | Client-specific | Not used directly in controller |
| `user_id` | integer array | No | Example: `user_id[]=1&user_id[]=87` |
| `store_id` | integer array | No | Example: `store_id[]=2&store_id[]=60` |
| `period` | string | No | `today`, `week`, `month` |
| `sales_close_id` | integer | No | Filters exact close row |
| `start_date` | string (`YYYY-MM-DD`) | No | Uses `closing_date` |
| `end_date` | string (`YYYY-MM-DD`) | No | Uses `closing_date` |
| `status` | string | No | `draft` or `closed` |
| `per_page` | integer | No | Default `20`, max `100` |
| `page` | integer | No | Default pagination |

### Business rules

- `period` and `start_date` / `end_date` are mutually layered:
  - if `period` is present, date range filters are ignored
- Filtering is by `closing_date`
  - draft rows with `closing_date = null` will not match date filters
- Results are ordered by `created_at desc`

### Sample success response showing both `draft` and `closed`

The rows below use real local data.

```json
{
  "success": true,
  "message": "Daily sales closes retrieved successfully",
  "data": [
    {
      "id": 211,
      "sales_executive": {
        "id": 87,
        "name": "Salesexecutive1",
        "phone": "8909876543"
      },
      "store": {
        "id": 60,
        "name": "Testing Store"
      },
      "closing_period": "08-07-2026 to 09-07-2026",
      "status": "closed",
      "opening_date": "2026-07-08",
      "opening_time": "08:00:00",
      "closing_date": "2026-07-09",
      "closing_time": "08:05:40",
      "opening_transaction_id": 9840,
      "closing_transaction_id": 9846,
      "total_orders": 4,
      "total_sales": "0.00",
      "total_online": "0.00",
      "total_cash": "0.00",
      "total_credit": "0.00",
      "total_payment_received": "0.00",
      "total_amount_collected_on_sale": "0.00",
      "total_credit_collected": "0.00",
      "total_returns": "0.00",
      "total_refunds": "0.00",
      "shift_name": "Swift Morning",
      "business_date": "2026-07-08",
      "cash_summary": {
        "total_sales_count": 4,
        "total_sales_amount": "0.00",
        "cash_collected": "0.00",
        "online_collected": "0.00",
        "credit_amount": "0.00",
        "previous_balance_collected": "0.00",
        "cash_refunds": "0.00",
        "cash_expenses": "0.00",
        "cash_drop_amount": "0.00",
        "opening_cash_in_hand": "500.00",
        "opening_cash_breakdown": [
          {
            "count": 3,
            "denomination": "100"
          },
          {
            "count": 4,
            "denomination": "50"
          }
        ],
        "expected_closing_cash": "500.00",
        "closing_cash_in_hand": null,
        "closing_cash_breakdown": null,
        "short_cash": null,
        "excess_cash": null,
        "notes": "Opening cash counted"
      },
      "created_at": "2026-07-09 09:03:25",
      "updated_at": "2026-07-09 09:06:01"
    },
    {
      "id": 210,
      "sales_executive": {
        "id": 1,
        "name": "Super Admin",
        "phone": "9496419999"
      },
      "store": {
        "id": 2,
        "name": "FUNZCART Store"
      },
      "closing_period": "08-07-2026 to Draft",
      "status": "draft",
      "opening_date": "2026-07-08",
      "opening_time": "08:00:00",
      "closing_date": null,
      "closing_time": null,
      "opening_transaction_id": null,
      "closing_transaction_id": null,
      "total_orders": 0,
      "total_sales": "0.00",
      "total_online": "0.00",
      "total_cash": "0.00",
      "total_credit": "0.00",
      "total_payment_received": "0.00",
      "total_amount_collected_on_sale": "0.00",
      "total_credit_collected": "0.00",
      "total_returns": "0.00",
      "total_refunds": "0.00",
      "shift_name": "Swift",
      "business_date": "2026-07-08",
      "cash_summary": {
        "total_sales_count": 0,
        "total_sales_amount": "0.00",
        "cash_collected": "0.00",
        "online_collected": "0.00",
        "credit_amount": "0.00",
        "previous_balance_collected": "0.00",
        "cash_refunds": "0.00",
        "cash_expenses": "0.00",
        "cash_drop_amount": "0.00",
        "opening_cash_in_hand": "1000.00",
        "opening_cash_breakdown": [
          {
            "count": "2",
            "denomination": "200"
          },
          {
            "count": "4",
            "denomination": "50"
          },
          {
            "count": "10",
            "denomination": "20"
          },
          {
            "count": "20",
            "denomination": "10"
          }
        ],
        "expected_closing_cash": "1000.00",
        "closing_cash_in_hand": null,
        "closing_cash_breakdown": null,
        "short_cash": null,
        "excess_cash": null,
        "notes": null
      },
      "created_at": "2026-07-08 10:00:07",
      "updated_at": "2026-07-08 10:00:07"
    }
  ],
  "pagination": {
    "total": 2,
    "per_page": 20,
    "current_page": 1,
    "last_page": 1
  }
}
```

### Response fields

| Field | Type | Nullable | Always present |
|---|---|---:|---:|
| `success` | boolean | No | Yes |
| `message` | string | No | Yes |
| `data` | array | No | Yes |
| `data[]` | Day Close object | No | Yes |
| `pagination` | object | No | Yes |
| `pagination.total` | integer | No | Yes |
| `pagination.per_page` | integer | No | Yes |
| `pagination.current_page` | integer | No | Yes |
| `pagination.last_page` | integer | No | Yes |

---

## Confirmed implementation notes

- `GET /pending-status` ignores request `user_id`; it always uses the authenticated user
- `GET /summary` ignores request `user_id`; it always uses the authenticated user
- `GET /summary` does not accept `transaction_id` in current backend
- `POST /create` is the current close/submit route; `/close` is not registered
- Draft rows can have:
  - `closing_date = null`
  - `closing_time = null`
  - `opening_transaction_id = null`
  - `closing_transaction_id = null`
- `cash_summary.cash_expenses` and `cash_summary.cash_drop_amount` are always returned as strings, even when underlying DB values are null
- `cash_summary.expected_closing_cash` is computed dynamically even if not stored, as long as `opening_cash_in_hand` exists

