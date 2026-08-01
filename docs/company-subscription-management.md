# Company Subscription Management

## Objective

Manage a company’s subscription status in the app and ensure that subscription warnings or restrictions are consistently applied during billing and order confirmation.

## Subscription statuses

| Status | App access | Billing and order confirmation | User message |
|---|---|---|---|
| **Active** | Full access | Allowed without warning | No message required |
| **Warning** | Full access | Allowed, but show a warning every time the user confirms or saves an order | Display the warning configured by the backend |
| **Blocked** | App can be opened for account and subscription management | Billing/order confirmation is blocked | Explain that the subscription is blocked and provide the next action |

## Warning behavior

When the company is in **Warning** status, show a warning message for every billing/order confirmation action, including:

- Confirm order
- Save and print
- Online checkout
- Create invoice/order
- Desktop and mobile billing flows

Example:

> Your subscription expires in 3 days. Please renew your subscription to avoid interruption.

The user may select **Continue** and complete the order while the subscription remains in Warning status.

## Blocked behavior

When the company is **Blocked**:

- Prevent order confirmation and online checkout.
- Prevent save-and-print if it creates or confirms an order.
- Preserve the current cart and entered data.
- Show the backend-provided reason.
- Provide a **Manage Subscription** or **Contact Administrator** action.
- Allow users to open settings, account information, and subscription-management screens.

Example:

> Your company subscription is blocked. Renew your subscription to continue creating orders.

## Backend requirements

The subscription status should be returned after login and whenever the app refreshes company data.

Suggested response:

```json
{
  "company_id": 10,
  "subscription_status": "warning",
  "message": "Your subscription expires in 3 days.",
  "valid_until": "2026-08-04T23:59:59Z",
  "manage_subscription_url": "https://example.com/subscription"
}
```

Allowed values:

```text
active
warning
blocked
```

The order-confirmation API must also enforce the status server-side. If a blocked company attempts to confirm an order, return HTTP `403`:

```json
{
  "code": "SUBSCRIPTION_BLOCKED",
  "message": "Company subscription is blocked."
}
```

Client-side checks are required for immediate feedback, but backend enforcement is mandatory for security and data integrity.

## App requirements

Create one shared subscription state/service used by both desktop and mobile billing.

Before every billing confirmation action:

1. Read the current company subscription status.
2. If status is `blocked`, stop the action and show the blocking message.
3. If status is `warning`, show the warning dialog.
4. If the user chooses **Continue**, proceed with the action.
5. If status is `active`, proceed normally.

The status should be refreshed:

- After login
- When the app starts
- When the app resumes from the background
- Before online order confirmation, when practical
- After subscription renewal or payment completion

## Acceptance criteria

- Active companies can create and confirm orders normally.
- Warning companies see the warning on every billing/order confirmation attempt.
- Warning users can continue after acknowledging the warning.
- Blocked companies cannot confirm or create online orders.
- Blocked users see a clear reason and next action.
- The current cart is not lost when an order is blocked.
- The behavior is identical on desktop and mobile.
- The backend rejects blocked-company order requests even if the client check is bypassed.
- Subscription status changes are reflected without requiring a full reinstall or manual cache clearing.
- API failures do not silently grant access to blocked functionality; the app should show a retry or unable-to-verify message.

## Suggested implementation scope

### Phase 1: Core enforcement

- Add subscription status API response.
- Add shared subscription provider/state.
- Add guards to all billing confirmation paths.
- Add backend `403` enforcement.
- Add Active, Warning, and Blocked UI states.

### Phase 2: Subscription management

- Add subscription details screen.
- Show plan, renewal date, payment status, and company identifier.
- Add renewal/payment link.
- Add administrator contact information.

### Phase 3: Notifications and reporting

- Add expiry reminders before Warning status.
- Add audit logs for blocked confirmation attempts.
- Add product/admin reporting for companies in Warning or Blocked status.

## Product decisions required

- How many days before expiry should a company enter Warning status?
- Should Warning status allow all order types, including invoices and quotations?
- Should blocked users be allowed to save offline drafts?
- Who can manage the subscription: company owner, administrator, or all users?
- What support or payment URL should be shown for blocked companies?
- What should happen if the app cannot verify subscription status because the network is unavailable?
