# Backend handoff: company subscription enforcement

The Flutter POS frontend now expects the backend contract below. The frontend
is fail-closed for order creation/confirmation when it cannot verify the
subscription, but backend enforcement remains mandatory.

## Temporary app-settings fallback

Until the refresh endpoint is available, the frontend can verify subscription
state from the existing tenant-scoped `GET /api/v1/website-settings` response.
Add these setting rows:

| Code | Required value |
| --- | --- |
| `COMPANY_SUBSCRIPTION_STATUS` | `active`, `warning`, or `blocked` |
| `COMPANY_SUBSCRIPTION_MESSAGE` | User-facing message; required for warning/blocked |
| `COMPANY_SUBSCRIPTION_VALID_UNTIL` | Optional ISO-8601 timestamp with timezone |
| `COMPANY_SUBSCRIPTION_MANAGE_URL` | Optional absolute HTTPS URL |

Example:

```json
{
  "data": [
    {
      "name": "Company Subscription Status",
      "code": "COMPANY_SUBSCRIPTION_STATUS",
      "status": true,
      "value": "warning"
    },
    {
      "name": "Company Subscription Message",
      "code": "COMPANY_SUBSCRIPTION_MESSAGE",
      "status": true,
      "value": "Your subscription expires in 3 days. Please renew it."
    },
    {
      "name": "Company Subscription Valid Until",
      "code": "COMPANY_SUBSCRIPTION_VALID_UNTIL",
      "status": true,
      "value": "2026-08-07T23:59:59Z"
    },
    {
      "name": "Company Subscription Management URL",
      "code": "COMPANY_SUBSCRIPTION_MANAGE_URL",
      "status": true,
      "value": "https://example.com/subscription"
    }
  ]
}
```

The `status` property on each row enables the setting. The actual subscription
state is the `value` of `COMPANY_SUBSCRIPTION_STATUS`. If that row is disabled,
or missing, fallback enablement defaults to `false` and the frontend treats the
tenant as active so existing users are not interrupted during rollout. If the
row is enabled but its value is invalid, verification fails closed. A settings
request that cannot be completed also fails closed. A valid dedicated
subscription API response always takes precedence over this fallback.

## 1. Subscription object

Return this object as `data.subscription` from the refresh endpoint:

```json
{
  "company_id": 10,
  "subscription_status": "warning",
  "message": "Your subscription expires in 3 days. Please renew your subscription to avoid interruption.",
  "valid_until": "2026-08-07T23:59:59Z",
  "manage_subscription_url": "https://example.com/subscription"
}
```

Required fields:

- `company_id`: authenticated tenant/company identifier.
- `subscription_status`: exactly `active`, `warning`, or `blocked`.
- `message`: backend-owned user-facing explanation. It may be empty only for
  `active`.

Optional fields:

- `valid_until`: ISO-8601 timestamp including timezone.
- `manage_subscription_url`: absolute HTTPS URL. When absent, the app displays
  a `Contact Administrator` action.

For rollout compatibility the frontend also accepts the same fields directly
inside `data`, but `data.subscription` is the canonical shape.

## 2. Login sequence

`POST /api/v1/user/signin` does not need to include subscription information.
Keep the existing successful login response unchanged. After saving the access
token, tenant key, and company id, the frontend immediately calls the refresh
endpoint described below and waits for subscription verification before
continuing.

The frontend still tolerates a subscription object in the login response for
compatibility, but the backend does not need to implement or maintain that
duplicate payload.

## 3. Refresh endpoint

Implement:

```text
GET /api/v1/company/subscription-status
Authorization: Bearer <token>
X-Tenant: <company-api-key>
Accept: application/json
```

Successful response:

```json
{
  "status": "success",
  "data": {
    "subscription": {
      "company_id": 10,
      "subscription_status": "blocked",
      "message": "Your subscription has expired. Renew it to continue creating orders.",
      "valid_until": "2026-08-03T23:59:59Z",
      "manage_subscription_url": "https://example.com/subscription"
    }
  }
}
```

The endpoint must derive the company from the authenticated tenant context and
must not accept an arbitrary company id from the client.

## 4. Status rules

- `active`: subscription is valid and outside the warning window.
- `warning`: subscription is valid but inside the configured expiry-warning
  window. The current frontend product default is seven days.
- `blocked`: expired, suspended, inactive, administratively blocked, missing a
  required subscription, or otherwise forbidden from creating orders.

Existing companies must be backfilled or explicitly grandfathered before
enforcement is enabled. A missing subscription must not accidentally block all
legacy tenants during rollout.

## 5. Mandatory server-side enforcement

Apply one shared backend guard/middleware to every endpoint that creates,
confirms, or converts an order, including at minimum:

- `POST /api/v1/order/add-to-order`
- `POST /api/v1/order/confirm-order`
- `POST /api/v1/order/update-order` when it creates/confirms a sale
- `POST /api/v1/order/save-confirmed-order`
- quotation-to-order conversion
- invoice creation when it represents a sale
- restaurant/KOT flows that create an order
- online checkout/order creation endpoints

Do not block read-only account/settings/subscription routes. Draft-only storage
that does not create or confirm a sale may remain available.

For a blocked request return HTTP `403` with this stable shape:

```json
{
  "status": "failure",
  "code": "SUBSCRIPTION_BLOCKED",
  "message": "Your company subscription is blocked. Renew it to continue creating orders.",
  "manage_subscription_url": "https://example.com/subscription"
}
```

The `code` value is an API contract and must not be translated. The `message`
is user-facing and may be localized by the backend.

Warning subscriptions must be accepted by order APIs after normal validation;
the acknowledgement dialog is a frontend concern. Active subscriptions proceed
normally.

## 6. Consistency and tests

- Calculate status from server time, not device time.
- Use the same resolver for login, refresh, and order middleware.
- Renewal/payment completion must be immediately visible to the refresh
  endpoint.
- Test active, warning, expired, suspended, inactive, missing-subscription,
  cross-tenant, and renewal transitions.
- Test that bypassing the Flutter UI still produces `403` for blocked tenants.
- Log blocked attempts with company id, user id, endpoint, and timestamp, but do
  not log access tokens or tenant API keys.
