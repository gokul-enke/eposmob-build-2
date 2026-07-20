# Customers TODO

Track detailed ownership and deadlines in Jira.

## Must fix

| ID | Work | Priority | Status |
|---|---|---:|---|
| CUST-001 | Include customer `id` in search results. | P0 | Open |
| CUST-002 | Standardize `customer_type` in the API. | P1 | Open |
| CUST-003 | Align the paginated response with Flutter. | P0 | Open |
| CUST-004 | Move filtering and pagination to the backend. | P1 | Open |
| CUST-005 | Resolve the `per_page=1000` versus backend limit. | P1 | Open |

## Follow-up

| ID | Work | Priority | Status |
|---|---|---:|---|
| CUST-006 | Fix or remove alternate-phone filtering. | P2 | Open |
| CUST-007 | Implement or remove `sort_asc`. | P2 | Open |
| CUST-008 | Add backend API contract tests. | P1 | Open |
| CUST-009 | Add Flutter parsing tests after the API is final. | P1 | Blocked |
| CUST-010 | Standardize API response shapes. | P2 | Open |
| CUST-011–013 | Split provider, models, and customer profile work. | P2 | Blocked |

## Rule

When an API task is complete, update the backend contract, sync the frontend,
add tests, update `FEATURE_SPEC.md`, and record the change in `CHANGELOG.md`.
