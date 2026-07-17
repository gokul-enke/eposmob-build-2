# Customers Feature Specification

This document explains how the Flutter application interprets and presents the
backend Customer API. It is intentionally understandable without knowledge of
Flutter or Laravel.

## Current scope

Documented here:

- Customer list
- Search filters
- Pagination
- Desktop table
- Narrow-width customer cards
- Customer profile navigation
- Customer creation/edit endpoint references
- Executive address endpoint references

The shared create-customer form is not being redesigned in the current frontend
refactor.

## API operations

| Purpose | Method | Endpoint |
|---|---|---|
| Search/list customers | GET | `/api/v1/customer/customer-searchbar` |
| Create customer | POST | `/api/v1/customer/add-customer` |
| Edit customer | POST | `/api/v1/customer/customer-edit` |
| Add address | POST | `/api/v1/customer/executive-add-address` |
| Update address | POST | `/api/v1/customer/executive-update-address/{id}` |

All operations use:

- `Authorization: Bearer <token>`
- `X-Tenant: <tenant key>`
- `Content-Type: application/json` for JSON requests

The complete field-level contract is in
`contracts/openapi/customers.yaml`.

## List request

Flutter currently sends these query parameters:

| Parameter | When sent | Notes |
|---|---|---|
| `page` | Always | Starts at 1 |
| `per_page` | Load-all mode | Flutter sends `1000`; backend currently caps at `100` |
| `sort_asc` | Optional | Sent as `true` |
| `filter_name` | Name is not empty | Partial match |
| `filter_email` | Email is not empty | Partial match |
| `filter_phone` | Phone is not empty | Matches primary or alternate phone |
| `filter_age_range` | Optional legacy usage | Format such as `18-30` |
| `store_id` | Active store exists | Store scope |

## Frontend filtering behavior

The current Customers page requests customers and then performs local filtering
and pagination through `CustomerProvider`.

| Filter | Behavior |
|---|---|
| Name | Case-insensitive contains |
| Email | Case-insensitive contains |
| Phone | Contains primary phone or alternate phone |
| Balance: Positive | `balance > 0` |
| Balance: Negative | `balance < 0` |
| Balance: Zero | `balance == 0` |
| Balance: All | No balance restriction |

Typing runs the filter immediately. Pressing Enter also runs the filter.

Keyboard Tab order:

`Name → Email → Phone → Balance → Reset`

The first three transitions are covered by focused widget tests.

## Pagination

- Frontend local page size: 20 customers.
- Page numbering starts at 1.
- Row/card numbering continues across pages.
- Previous is unavailable on page 1.
- Next is unavailable on the final page.

Example:

| Page | Display numbers |
|---|---|
| 1 | 1–20 |
| 2 | 21–40 |
| 3 | 41–60 |

## Desktop table

| UI column | API/model field | Display rule |
|---|---|---|
| No | Calculated | Continues across pages |
| Name | `name` | Empty string if unavailable |
| Balance | `balance` | Two decimal places |
| Phone No. | `phone` | Empty string if unavailable |
| Customer Type | `customer_type` / current backend `customerType` | B2B or B2C badge |
| Action | — | Opens selected customer profile |

## Narrow-width customer card

Cards display:

- Customer initial
- Customer name
- Continuous display number
- Balance
- Phone
- Customer type badge
- View Profile button

## Formatting and colors

| Condition | Presentation |
|---|---|
| Balance `>= 0` | Success/green color |
| Balance `< 0` | Red color |
| Customer type `B2B` | Green badge |
| Other/missing customer type | Blue `B2C` badge |

## Responsive behavior

- Screen width below 700 uses `CustomersMobileView`.
- Within the desktop page, content width below 640 uses customer cards.
- Wider content uses the desktop table.

## UI states

| State | UI behavior |
|---|---|
| Loading | Adaptive progress indicator |
| Empty result | “No customers found” and filter-adjustment guidance |
| Refresh | Pull/refresh reloads customer data |
| Missing authentication token | Snackbar message |

## Known contract mismatches

These were found by comparing the current backend and frontend implementations:

1. Backend `customer-searchbar` returns a Laravel paginator inside the top-level
   `data` property. The current Flutter `CustomerListModel` expects the top-level
   `data` property itself to be a list.
2. Backend search items currently return `customerType`; Flutter parses
   `customer_type`.
3. Backend transformed search items currently omit `id`; Flutter model and
   customer profile selection expect customer identity.
4. Flutter load-all mode requests `per_page=1000`; backend caps `per_page` at
   100, so local filtering may not include every customer.
5. The backend accepts `filter_alt_phone` in its filter collection but does not
   independently apply that parameter.

These should be resolved through a coordinated API change, not hidden in the
frontend.

## Change rule

When adding a backend field:

1. Update backend `contracts/openapi/customers.yaml`.
2. Synchronize the frontend copy.
3. Decide whether the field is displayed, filtered, stored only, or ignored.
4. Update the table/card mapping in this document.
5. Update tests and `CHANGELOG.md`.

