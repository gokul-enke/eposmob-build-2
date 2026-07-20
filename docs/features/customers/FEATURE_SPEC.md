# Customers Feature

This document describes the customer list page.

## Scope

Included:

- Customer search and balance filters
- Pagination
- Desktop table and mobile cards
- Customer profile navigation

The shared create-customer form is unchanged.

## API

The page loads customers with:

```text
GET /api/v1/customer/customer-searchbar
```

Requests use the bearer token and tenant headers. The backend owns the full
request and response contract.

The frontend may send `page`, `per_page`, `filter_name`, `filter_email`,
`filter_phone`, `filter_age_range`, and `store_id`.

## Filters

- Name, email, and phone use case-insensitive partial matching.
- Phone checks the primary and alternate phone when available.
- Balance can be positive, negative, zero, or unrestricted.
- Filtering happens while typing and when Enter is pressed.
- Tab order: `Name → Email → Phone → Balance → Reset`.

## Pagination

- 20 customers per page.
- Numbering starts at 1 and continues across pages.
- Previous is disabled on the first page.
- Next is disabled on the last page.

## Layout

- Below 700px screen width: mobile view.
- Narrow content: customer cards.
- Wider content: desktop table.

The table shows:

- Number
- Name
- Balance
- Phone
- Customer type
- Profile action

Cards show the same information plus a customer initial and a View Profile
button.

## Display rules

- Balance is shown with two decimal places.
- Zero or positive balance is green.
- Negative balance is red.
- `B2B` uses a green badge.
- Other or missing types display as `B2C` with a blue badge.

## States

- Loading: show a progress indicator.
- No results: show “No customers found” and filter guidance.
- Refresh: reload the customer list.
- Missing token: show a snackbar.

## Known API issues

These need backend/frontend coordination:

- The response pagination shape does not match the Flutter parser.
- The backend returns `customerType`; Flutter expects `customer_type`.
- Search results do not currently include the customer `id`.
- The frontend requests up to 1,000 records, but the backend caps requests at 100.
- Alternate-phone filtering is not applied independently by the backend.
